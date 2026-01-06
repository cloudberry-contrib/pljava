# Cloudberry PL/Java Docker (Ubuntu 22.04 / pxf-style)

This directory uses the upstream image `apache/incubator-cloudberry:cbdb-build-ubuntu22.04-latest`:

- **Sources are prepared externally** (CI checkout / local sibling directory mount), no `git clone` inside the container
- The container runs scripts to **build Cloudberry from source and create a demo cluster (with standby)**
- Then builds PL/Java and runs the built-in regression tests (`cbdb/tests`)

## Directory layout

```

<workspace>/
  cloudberry/
  pljava/
  
```

## Run locally

From `<workspace>/pljava`:

```sh
docker compose -f concourse/docker/ubuntu22.04/docker-compose.yml down -v || true
docker compose -f concourse/docker/ubuntu22.04/docker-compose.yml up -d

docker exec cbdb-pljava bash -lc "bash /home/gpadmin/workspace/pljava/concourse/docker/ubuntu22.04/scripts/entrypoint.sh"
```

Run PL/Java regression only (assumes Cloudberry + cluster + PL/Java are ready):

```sh
docker exec cbdb-pljava bash -lc "source /home/gpadmin/workspace/pljava/concourse/docker/ubuntu22.04/scripts/entrypoint.sh && run_pljava_test_only"
```
