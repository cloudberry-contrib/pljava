#!/usr/bin/env bash
set -euo pipefail

log() { echo "[entrypoint][$(date '+%F %T')] $*"; }
die() { log "ERROR: $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WORKSPACE="${WORKSPACE:-/home/gpadmin/workspace}"
PLJAVA_SRC="${PLJAVA_SRC:-${WORKSPACE}/pljava}"
CLOUDBERRY_SRC="${CLOUDBERRY_SRC:-${WORKSPACE}/cloudberry}"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local/cloudberry-db}"

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

setup_ssh() {
  log "start sshd"
  sudo mkdir -p /var/run/sshd
  sudo ssh-keygen -A >/dev/null 2>&1 || true
  sudo /usr/sbin/sshd || true
  mkdir -p /home/gpadmin/.ssh
  touch /home/gpadmin/.ssh/known_hosts
  ssh-keyscan -t rsa "$(hostname)" 2>/dev/null >> /home/gpadmin/.ssh/known_hosts || true
  chmod 600 /home/gpadmin/.ssh/known_hosts || true
}

build_cloudberry() {
  bash "${SCRIPT_DIR}/build_cloudberrry.sh"
}

source_cbdb_env() {
  if [ -f "${INSTALL_PREFIX}/cloudberry-env.sh" ]; then
    # shellcheck disable=SC1091
    source "${INSTALL_PREFIX}/cloudberry-env.sh"
  elif [ -f "${INSTALL_PREFIX}/greenplum_path.sh" ]; then
    # shellcheck disable=SC1091
    source "${INSTALL_PREFIX}/greenplum_path.sh"
  fi

  if [ -f "${CLOUDBERRY_SRC}/gpAux/gpdemo/gpdemo-env.sh" ]; then
    # shellcheck disable=SC1091
    source "${CLOUDBERRY_SRC}/gpAux/gpdemo/gpdemo-env.sh"
  fi
}

wait_for_cbdb() {
  log "wait for Cloudberry to accept connections (PGPORT=${PGPORT:-unset})"
  for _ in $(seq 1 120); do
    if psql -d template1 -v ON_ERROR_STOP=1 -c "select 1" >/dev/null 2>&1; then
      return 0
    fi
    sleep 5
  done
  die "Cloudberry did not become ready in time"
}

install_pljava_build_deps() {
  log "install PL/Java build deps"
  sudo apt-get update
  sudo apt-get install -y curl wget tar gcc g++ make libkrb5-dev openssl libssl-dev

  # PL/Java 1.6.x requires Java 9+, use the Cloudberry-aligned JDK 11 LTS.
  sudo apt-get install -y openjdk-11-jdk
}

setup_java() {
  local java_major="${JAVA_MAJOR:-11}"
  local java_home=""
  for candidate in /usr/lib/jvm/java-${java_major}-openjdk-*; do
    if [ -d "${candidate}" ]; then
      java_home="${candidate}"
      break
    fi
  done
  if [ -z "${java_home}" ]; then
    die "could not find Java ${java_major} under /usr/lib/jvm (is openjdk-${java_major}-jdk installed?)"
  fi

  export JAVA_HOME="${JAVA_HOME:-${java_home}}"
  export PATH="${JAVA_HOME}/bin:${PATH}"
  java -version
}

setup_maven() {
  local maven_version="3.9.6"
  if [ ! -x /usr/local/apache-maven/bin/mvn ]; then
    wget -nv "https://archive.apache.org/dist/maven/maven-3/${maven_version}/binaries/apache-maven-${maven_version}-bin.tar.gz" \
      -O "/tmp/apache-maven-${maven_version}-bin.tar.gz"
    tar xzf "/tmp/apache-maven-${maven_version}-bin.tar.gz" -C /tmp
    sudo rm -rf /usr/local/apache-maven
    sudo mv "/tmp/apache-maven-${maven_version}" /usr/local/apache-maven
  fi
  export PATH="/usr/local/apache-maven/bin:${PATH}"

  # Configure a Maven mirror/proxy to avoid network flakiness when reaching
  # Maven Central from some environments.
  local mirror_url="${MAVEN_MIRROR_URL:-https://maven.aliyun.com/repository/public}"
  mkdir -p /home/gpadmin/.m2
  cat > /home/gpadmin/.m2/settings.xml <<EOF
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 https://maven.apache.org/xsd/settings-1.0.0.xsd">
  <mirrors>
    <mirror>
      <id>${MAVEN_MIRROR_ID:-mirror}</id>
      <mirrorOf>central</mirrorOf>
      <url>${mirror_url}</url>
    </mirror>
  </mirrors>
</settings>
EOF
  log "configured Maven mirror: ${mirror_url}"

  mvn -version
}

configure_pljava_runtime() {
  # Point Cloudberry at libjvm.so for runtime.
  local libjvm
  libjvm="$(find "${JAVA_HOME}" -type f -name libjvm.so -path '*server*' | head -n 1 || true)"
  [ -n "${libjvm}" ] || die "Could not locate libjvm.so under JAVA_HOME=${JAVA_HOME}"

  local jvm_server_dir jvm_lib_dir jvm_jli_dir
  jvm_server_dir="$(dirname "${libjvm}")"
  jvm_lib_dir="$(dirname "${jvm_server_dir}")"
  jvm_jli_dir="${jvm_lib_dir}/jli"
  export LD_LIBRARY_PATH="${jvm_server_dir}:${jvm_lib_dir}:${jvm_jli_dir}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

  log "configure PL/Java runtime GUCs"
  gpconfig --skipvalidation -c pljava.libjvm_location -v "'${libjvm}'"
  local module_path="${PLJAVA_SRC}/target/pljava.jar:${PLJAVA_SRC}/target/pljava-api.jar"
  if [ -f "${PLJAVA_SRC}/target/examples.jar" ]; then
    module_path="${module_path}:${PLJAVA_SRC}/target/examples.jar"
  fi
  gpconfig --skipvalidation -c pljava.module_path -v "'${module_path}'"

  gpstop -arf
}

test_pljava() {
  log "run PL/Java built-in regression tests (make installcheck)"
  cd "${PLJAVA_SRC}"
  mkdir -p "${PLJAVA_SRC}/gpdb/tests/results"
  local installcheck_log="${PLJAVA_SRC}/gpdb/tests/results/installcheck.log"
  log "installcheck log: ${installcheck_log}"
  make installcheck REGRESS_DIR="${CLOUDBERRY_SRC}" 2>&1 | tee "${installcheck_log}"
}

build_pljava() {
  log "build + install PL/Java"
  cd "${PLJAVA_SRC}"
  make clean
  make
  make install
}

build_and_test_pljava() {
  build_pljava
  configure_pljava_runtime
  test_pljava
}

run_pljava_test_only() {
  source_cbdb_env
  wait_for_cbdb
  install_pljava_build_deps
  setup_java
  setup_maven
  configure_pljava_runtime
  test_pljava
}

run_pljava_build_only() {
  source_cbdb_env
  wait_for_cbdb
  install_pljava_build_deps
  setup_java
  setup_maven
  build_pljava
}

main() {
  setup_ssh
  build_cloudberry
  source_cbdb_env
  wait_for_cbdb
  install_pljava_build_deps
  setup_java
  setup_maven
  build_and_test_pljava
  log "done"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
