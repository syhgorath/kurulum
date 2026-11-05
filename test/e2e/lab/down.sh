#!/usr/bin/env bash
# LAB konteynerini kaldırır. --clean: anahtarlar, host key (.state/) ve imajlar da silinir.
set -u
cd "$(dirname "$0")" || exit 1
docker rm -f kurulum-lab >/dev/null 2>&1 && echo "Konteyner kaldırıldı" || echo "Konteyner zaten yok"
docker volume rm -f kurulum-lab-docker kurulum-lab-containerd >/dev/null 2>&1 || true
if [ "${1:-}" = "--clean" ]; then
    rm -rf .state
    docker images --format '{{.Repository}}:{{.Tag}}' | grep '^kurulum-lab:' | xargs -r docker rmi >/dev/null 2>&1 || true
    echo ".state/ ve imajlar temizlendi"
fi
