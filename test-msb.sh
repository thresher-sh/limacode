#!/usr/bin/env bash
set -euo pipefail

# Install msb if needed: curl -fsSL https://install.microsandbox.dev | sh

echo "=== Test 1: Can we boot docker:dind in msb? ==="
msb run docker:dind -- sh -c "which docker && echo 'docker binary: OK'"

echo ""
echo "=== Test 2: Kernel features ==="
msb run docker:dind -- sh -c "
    echo 'cgroups:'; grep cgroup /proc/filesystems
    echo 'overlayfs:'; grep overlay /proc/filesystems || echo 'no overlay'
"

echo ""
echo "=== Test 3: Start dockerd (no bridge, vfs) ==="
msb run docker:dind -- sh -c '
    export DOCKER_HOST=unix:///var/run/docker.sock

    dockerd \
        --storage-driver=vfs \
        --bridge=none \
        --iptables=false \
        --ip6tables=false \
        --log-level=warn \
        >/dev/null 2>/tmp/dockerd.log &
    DPID=$!

    # Wait up to 30s for dockerd socket
    for i in $(seq 1 30); do
        if [ -S /var/run/docker.sock ] && docker info >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done

    if docker info >/dev/null 2>&1; then
        echo "DOCKERD: RUNNING (PID=$DPID)"
        docker info 2>&1 | grep -E "Storage Driver|Server Version|Cgroup|Operating System"
    else
        echo "DOCKERD: FAILED (PID=$DPID)"
        echo "--- dockerd log ---"
        cat /tmp/dockerd.log
        echo "--- end log ---"
    fi

    kill $DPID 2>/dev/null || true
'

echo ""
echo "=== Test 4: Run hello-world container inside sandbox ==="
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
        docker info >/dev/null 2>&1 && break
        sleep 1
    done

    if ! docker info >/dev/null 2>&1; then
        echo "DOCKERD: FAILED TO START"
        cat /tmp/dockerd.log
        exit 1
    fi

    echo "--- pulling hello-world ---"
    docker pull hello-world 2>&1

    echo ""
    echo "--- running hello-world (--network=none) ---"
    docker run --rm --network=none hello-world 2>&1 || echo "CONTAINER RUN: FAILED"
'

echo ""
echo "=== Test 5: docker build inside sandbox ==="
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
        docker info >/dev/null 2>&1 && break
        sleep 1
    done

    if ! docker info >/dev/null 2>&1; then
        echo "DOCKERD: FAILED TO START"
        cat /tmp/dockerd.log
        exit 1
    fi

    # Create a simple Dockerfile
    mkdir -p /tmp/testbuild
    cat > /tmp/testbuild/Dockerfile <<DOCKERFILE
FROM alpine:latest
RUN echo "build works" > /built.txt
CMD cat /built.txt
DOCKERFILE

    echo "--- docker build ---"
    docker build --network=host -t test-build /tmp/testbuild 2>&1 || echo "DOCKER BUILD: FAILED"

    echo ""
    echo "--- running built image ---"
    docker run --rm --network=none test-build 2>&1 || echo "BUILT CONTAINER RUN: FAILED"
'

echo ""
echo "=== Test 6: overlay2 storage driver ==="
echo "## This failes because this isn't supported inside msb"
msb run docker:dind -- sh -c '
    export DOCKER_HOST=unix:///var/run/docker.sock

    dockerd \
        --storage-driver=overlay2 \
        --bridge=none \
        --iptables=false \
        --ip6tables=false \
        --log-level=warn \
        >/dev/null 2>/tmp/dockerd.log &

    for i in $(seq 1 30); do
        docker info >/dev/null 2>&1 && break
        sleep 1
    done

    if docker info >/dev/null 2>&1; then
        echo "OVERLAY2: WORKS"
        docker info 2>&1 | grep "Storage Driver"
    else
        echo "OVERLAY2: FAILED"
        tail -5 /tmp/dockerd.log
    fi
'
