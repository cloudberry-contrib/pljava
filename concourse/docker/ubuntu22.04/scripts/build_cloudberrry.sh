#!/usr/bin/env bash
set -euo pipefail

# Ubuntu 22.04 Cloudberry build script (pxf-style).
# - assumes sources are already mounted at ~/workspace/cloudberry
# - builds + installs into /usr/local/cloudberry-db
# - creates a demo cluster (with standby) for pg_regress health checks

log() { echo "[build_cloudberrry][$(date '+%F %T')] $*"; }
die() { log "ERROR: $*"; exit 1; }

WORKSPACE="${WORKSPACE:-/home/gpadmin/workspace}"
CLOUDBERRY_SRC="${CLOUDBERRY_SRC:-${WORKSPACE}/cloudberry}"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local/cloudberry-db}"

if [ ! -d "${CLOUDBERRY_SRC}" ]; then
  die "Cloudberry source not found at ${CLOUDBERRY_SRC} (did you mount/checkout cloudberry?)"
fi

if [ "${FORCE_CLOUDBERRY_BUILD:-}" != "true" ] && \
   [ -f "${INSTALL_PREFIX}/cloudberry-env.sh" ] && \
   [ -f "${CLOUDBERRY_SRC}/gpAux/gpdemo/gpdemo-env.sh" ]; then
  log "Cloudberry already installed and demo cluster exists; skipping build (set FORCE_CLOUDBERRY_BUILD=true to rebuild)"
  exit 0
fi

log "install base packages"
sudo apt-get update
sudo apt-get install -y sudo git locales openssh-server iproute2 \
  bison bzip2 cmake curl flex gcc g++ make pkg-config rsync wget tar \
  libapr1-dev libbz2-dev libcurl4-gnutls-dev libevent-dev libkrb5-dev libipc-run-perl \
  libldap2-dev libpam0g-dev libprotobuf-dev libreadline-dev libssl-dev libuv1-dev \
  liblz4-dev libxerces-c-dev libxml2-dev libyaml-dev libzstd-dev libperl-dev \
  protobuf-compiler python3-dev python3-pip python3-setuptools libsnappy-dev

sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8

log "setup ssh keys for gpadmin"
mkdir -p /home/gpadmin/.ssh
if [ ! -f /home/gpadmin/.ssh/id_rsa ]; then
  ssh-keygen -t rsa -b 2048 -C 'apache-cloudberry-dev' -f /home/gpadmin/.ssh/id_rsa -N ""
fi
cat /home/gpadmin/.ssh/id_rsa.pub >> /home/gpadmin/.ssh/authorized_keys
chmod 700 /home/gpadmin/.ssh
chmod 600 /home/gpadmin/.ssh/authorized_keys
chmod 644 /home/gpadmin/.ssh/id_rsa.pub

log "configure resource limits"
sudo tee /etc/security/limits.d/90-db-limits.conf >/dev/null <<'EOF'
gpadmin soft core unlimited
gpadmin hard core unlimited
gpadmin soft nofile 524288
gpadmin hard nofile 524288
gpadmin soft nproc 131072
gpadmin hard nproc 131072
EOF

log "prepare install prefix ${INSTALL_PREFIX}"
sudo rm -rf "${INSTALL_PREFIX}"
sudo mkdir -p "${INSTALL_PREFIX}"
sudo chown -R gpadmin:gpadmin "${INSTALL_PREFIX}"

log "configure Cloudberry"
cd "${CLOUDBERRY_SRC}"
./configure --prefix="${INSTALL_PREFIX}" \
            --disable-external-fts \
            --enable-debug \
            --enable-cassert \
            --enable-debug-extensions \
            --enable-gpcloud \
            --enable-ic-proxy \
            --enable-mapreduce \
            --enable-orafce \
            --enable-orca \
            --disable-pax \
            --enable-pxf \
            --enable-tap-tests \
            --with-gssapi \
            --with-ldap \
            --with-libxml \
            --with-lz4 \
            --with-pam \
            --with-perl \
            --with-pgport=5432 \
            --with-python \
            --with-pythonsrc-ext \
            --with-ssl=openssl \
            --with-uuid=e2fs \
            --with-includes=/usr/include/xercesc

log "build + install Cloudberry"
make -j"$(nproc)" -C "${CLOUDBERRY_SRC}"
make -j"$(nproc)" -C "${CLOUDBERRY_SRC}/contrib"
make install -C "${CLOUDBERRY_SRC}"
make install -C "${CLOUDBERRY_SRC}/contrib"

log "create demo cluster"
# shellcheck disable=SC1091
source "${INSTALL_PREFIX}/cloudberry-env.sh"
make create-demo-cluster -C "${CLOUDBERRY_SRC}"
# shellcheck disable=SC1091
source "${CLOUDBERRY_SRC}/gpAux/gpdemo/gpdemo-env.sh"

psql -P pager=off template1 -c "select version()"
psql -P pager=off template1 -c "select * from gp_segment_configuration order by dbid"

log "Cloudberry demo cluster ready (PGPORT=${PGPORT:-})"

