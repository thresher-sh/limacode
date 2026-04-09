#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.microsandbox/bin:$PATH"

echo "=== dockerd with DOCKER_HOST fix ==="
msb run docker:dind -- sh -c '
    export DOCKER_HOST=unix:///var/run/docker.sock

    dockerd \
        --storage-driver=vfs \
        --bridge=none \
        --iptables=false \
        --ip6tables=false \
        --log-level=warn \
        >/dev/null 2>&1 &

    for i in $(seq 1 20); do
        [ -S /var/run/docker.sock ] && docker info >/dev/null 2>&1 && break
        sleep 1
    done

    if docker info >/dev/null 2>&1; then
        echo "DOCKERD: RUNNING"
        docker info 2>&1 | grep -E "Storage|Version|Cgroup|OS"
    else
        echo "DOCKERD: FAILED"
        exit 1
    fi
'
