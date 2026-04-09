#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.microsandbox/bin:$PATH"

# Helper: start dockerd inside msb and wait for it
# Usage: paste this as a preamble inside each msb run block
DOCKERD_PREAMBLE='
    export DOCKER_HOST=unix:///var/run/docker.sock

    dockerd \
        --storage-driver=vfs \
        --bridge=none \
        --iptables=false \
        --ip6tables=false \
        --log-level=warn \
        >/dev/null 2>/tmp/dockerd.log &
    DPID=$!

    for i in $(seq 1 30); do
        [ -S /var/run/docker.sock ] && docker info >/dev/null 2>&1 && break
        sleep 1
    done

    if ! docker info >/dev/null 2>&1; then
        echo "DOCKERD: FAILED TO START"
        cat /tmp/dockerd.log
        exit 1
    fi
    echo "DOCKERD: RUNNING (PID=$DPID)"
'

echo "=== Test 1: Is docker compose available? ==="
msb run docker:dind -- sh -c "
    docker compose version 2>&1 || echo 'docker compose: NOT AVAILABLE'
"

echo ""
echo "=== Test 2: docker compose up with two services ==="
msb run docker:dind -- sh -c '
    export DOCKER_HOST=unix:///var/run/docker.sock

    dockerd \
        --storage-driver=vfs \
        --bridge=none \
        --iptables=false \
        --ip6tables=false \
        --log-level=warn \
        >/dev/null 2>/tmp/dockerd.log &

    for i in $(seq 1 30); do
        [ -S /var/run/docker.sock ] && docker info >/dev/null 2>&1 && break
        sleep 1
    done

    if ! docker info >/dev/null 2>&1; then
        echo "DOCKERD: FAILED TO START"
        cat /tmp/dockerd.log
        exit 1
    fi
    echo "DOCKERD: RUNNING"

    # Create a compose project with two alpine services
    mkdir -p /tmp/compose-test
    cat > /tmp/compose-test/compose.yaml <<YAML
services:
  app:
    image: alpine:latest
    command: sh -c "echo hello-from-app && sleep 5"
    network_mode: host
  worker:
    image: alpine:latest
    command: sh -c "echo hello-from-worker && sleep 5"
    network_mode: host
YAML

    echo "--- pulling images ---"
    docker pull alpine:latest 2>&1

    echo ""
    echo "--- docker compose up -d ---"
    cd /tmp/compose-test
    docker compose up -d 2>&1

    echo ""
    echo "--- docker compose ps ---"
    docker compose ps 2>&1

    echo ""
    echo "--- docker compose logs ---"
    sleep 3
    docker compose logs 2>&1

    echo ""
    echo "--- docker compose down ---"
    docker compose down 2>&1 && echo "COMPOSE DOWN: OK" || echo "COMPOSE DOWN: FAILED"
'

echo ""
echo "=== Test 3: docker compose build (custom image) ==="
msb run docker:dind -- sh -c '
    export DOCKER_HOST=unix:///var/run/docker.sock

    dockerd \
        --storage-driver=vfs \
        --bridge=none \
        --iptables=false \
        --ip6tables=false \
        --log-level=warn \
        >/dev/null 2>/tmp/dockerd.log &

    for i in $(seq 1 30); do
        [ -S /var/run/docker.sock ] && docker info >/dev/null 2>&1 && break
        sleep 1
    done

    if ! docker info >/dev/null 2>&1; then
        echo "DOCKERD: FAILED TO START"
        cat /tmp/dockerd.log
        exit 1
    fi
    echo "DOCKERD: RUNNING"

    # Create a compose project that builds a custom image
    mkdir -p /tmp/compose-build/myapp
    cat > /tmp/compose-build/myapp/Dockerfile <<DOCKERFILE
FROM alpine:latest
RUN echo "compose-built" > /marker.txt
CMD cat /marker.txt
DOCKERFILE

    cat > /tmp/compose-build/compose.yaml <<YAML
services:
  myapp:
    build:
      context: ./myapp
      network: none
    network_mode: host
YAML

    echo "--- docker compose build ---"
    cd /tmp/compose-build
    DOCKER_BUILDKIT=1 docker compose build --no-cache 2>&1 || { echo "COMPOSE BUILD: FAILED"; exit 1; }
    echo "COMPOSE BUILD: OK"

    echo ""
    echo "--- docker compose up (run built image) ---"
    docker compose up --abort-on-container-exit 2>&1 || true

    echo ""
    echo "--- docker compose down ---"
    docker compose down 2>&1 && echo "COMPOSE DOWN: OK" || echo "COMPOSE DOWN: FAILED"
'

echo ""
echo "=== Test 4: docker compose with depends_on and healthcheck ==="
msb run docker:dind -- sh -c '
    export DOCKER_HOST=unix:///var/run/docker.sock

    dockerd \
        --storage-driver=vfs \
        --bridge=none \
        --iptables=false \
        --ip6tables=false \
        --log-level=warn \
        >/dev/null 2>/tmp/dockerd.log &

    for i in $(seq 1 30); do
        [ -S /var/run/docker.sock ] && docker info >/dev/null 2>&1 && break
        sleep 1
    done

    if ! docker info >/dev/null 2>&1; then
        echo "DOCKERD: FAILED TO START"
        cat /tmp/dockerd.log
        exit 1
    fi
    echo "DOCKERD: RUNNING"

    mkdir -p /tmp/compose-health
    cat > /tmp/compose-health/compose.yaml <<YAML
services:
  db:
    image: alpine:latest
    command: sh -c "touch /tmp/healthy && sleep 30"
    network_mode: host
    healthcheck:
      test: ["CMD", "test", "-f", "/tmp/healthy"]
      interval: 2s
      timeout: 2s
      retries: 5
  app:
    image: alpine:latest
    command: sh -c "echo app-started && sleep 5"
    network_mode: host
    depends_on:
      db:
        condition: service_healthy
YAML

    echo "--- pulling images ---"
    docker pull alpine:latest 2>&1

    echo ""
    echo "--- docker compose up -d ---"
    cd /tmp/compose-health
    docker compose up -d 2>&1

    echo ""
    echo "--- waiting for healthy ---"
    for i in $(seq 1 20); do
        STATUS=$(docker compose ps --format json 2>/dev/null | head -1)
        echo "  check $i: $STATUS"
        docker compose ps 2>&1 | grep -q "healthy" && break
        sleep 2
    done

    echo ""
    echo "--- docker compose ps ---"
    docker compose ps 2>&1

    echo ""
    echo "--- docker compose logs ---"
    docker compose logs 2>&1

    echo ""
    echo "--- docker compose down ---"
    docker compose down 2>&1 && echo "COMPOSE DOWN: OK" || echo "COMPOSE DOWN: FAILED"
'

echo ""
echo "=== Test 5: docker compose with shared volume ==="
msb run docker:dind -- sh -c '
    export DOCKER_HOST=unix:///var/run/docker.sock

    dockerd \
        --storage-driver=vfs \
        --bridge=none \
        --iptables=false \
        --ip6tables=false \
        --log-level=warn \
        >/dev/null 2>/tmp/dockerd.log &

    for i in $(seq 1 30); do
        [ -S /var/run/docker.sock ] && docker info >/dev/null 2>&1 && break
        sleep 1
    done

    if ! docker info >/dev/null 2>&1; then
        echo "DOCKERD: FAILED TO START"
        cat /tmp/dockerd.log
        exit 1
    fi
    echo "DOCKERD: RUNNING"

    mkdir -p /tmp/compose-vol
    cat > /tmp/compose-vol/compose.yaml <<YAML
services:
  writer:
    image: alpine:latest
    command: sh -c "echo shared-data > /data/message.txt && echo writer-done"
    network_mode: host
    volumes:
      - shared:/data
  reader:
    image: alpine:latest
    command: sh -c "sleep 3 && cat /data/message.txt"
    network_mode: host
    depends_on:
      writer:
        condition: service_completed_successfully
    volumes:
      - shared:/data

volumes:
  shared:
YAML

    echo "--- pulling images ---"
    docker pull alpine:latest 2>&1

    echo ""
    echo "--- docker compose up ---"
    cd /tmp/compose-vol
    docker compose up --abort-on-container-exit 2>&1 || true

    echo ""
    echo "--- docker compose down -v ---"
    docker compose down -v 2>&1 && echo "COMPOSE DOWN: OK" || echo "COMPOSE DOWN: FAILED"
'

echo ""
echo "=== Test 6: container-to-container networking via host ==="
msb run docker:dind -- sh -c '
    export DOCKER_HOST=unix:///var/run/docker.sock

    dockerd \
        --storage-driver=vfs \
        --bridge=none \
        --iptables=false \
        --ip6tables=false \
        --log-level=warn \
        >/dev/null 2>/tmp/dockerd.log &

    for i in $(seq 1 30); do
        [ -S /var/run/docker.sock ] && docker info >/dev/null 2>&1 && break
        sleep 1
    done

    if ! docker info >/dev/null 2>&1; then
        echo "DOCKERD: FAILED TO START"
        cat /tmp/dockerd.log
        exit 1
    fi
    echo "DOCKERD: RUNNING"

    mkdir -p /tmp/compose-net
    cat > /tmp/compose-net/compose.yaml <<YAML
services:
  server:
    image: alpine:latest
    command: sh -c "echo HELLO-FROM-COMPOSE | nc -l -p 7777"
    network_mode: host
  client:
    image: alpine:latest
    command: sh -c "sleep 2 && nc 127.0.0.1 7777"
    network_mode: host
    depends_on:
      - server
YAML

    echo "--- pulling images ---"
    docker pull alpine:latest 2>&1 | tail -1

    echo ""
    echo "--- docker compose up ---"
    cd /tmp/compose-net
    OUTPUT=$(docker compose up --abort-on-container-exit 2>&1)
    echo "$OUTPUT"

    echo ""
    if echo "$OUTPUT" | grep -q "HELLO-FROM-COMPOSE"; then
        echo "NETWORK TEST: PASSED (containers communicated over localhost)"
    else
        echo "NETWORK TEST: FAILED"
    fi

    echo ""
    echo "--- docker compose down ---"
    docker compose down 2>&1 && echo "COMPOSE DOWN: OK" || echo "COMPOSE DOWN: FAILED"
'

echo ""
echo "=== All compose tests complete ==="
