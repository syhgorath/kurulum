#!/usr/bin/env bash
# LAB sunucusunu SIFIRDAN kurar: systemd'li konteyner (varsayılan Ubuntu 26.04), 127.0.0.1:${LAB_PORT:-2224}, kullanıcı 'tester' (anahtarla, parolasız sudo).
# LAB_BASE=debian:trixie ile Debian 13 KONTEYNERİ denenebilir (bu, gerçek Debian 13 VM doğrulaması DEĞİLDİR).
# Anahtarlar ve host key .state/ altındadır (git'e girmez); ~/.ssh/known_hosts'a dokunulmaz.
set -eu
cd "$(dirname "$0")"
PORT="${LAB_PORT:-2225}"; BASE="${LAB_BASE:-ubuntu:26.04}"; NAME=kurulum-lab; IMG="kurulum-lab:$(echo "$BASE" | tr ':/' '__')"; STATE="$PWD/.state"

command -v docker >/dev/null || { echo "docker bulunamadı (örn. brew install colima docker)"; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker çalışmıyor (Colima: 'colima start')."; exit 1; }

mkdir -p "$STATE/hostkey"
[ -f "$STATE/id_lab" ] || ssh-keygen -q -t ed25519 -N '' -C kurulum-lab -f "$STATE/id_lab"
[ -f "$STATE/hostkey/ssh_host_ed25519_key" ] || ssh-keygen -q -t ed25519 -N '' -C kurulum-lab-host -f "$STATE/hostkey/ssh_host_ed25519_key"
printf 'PORT=%s\nBASE=%s\n' "$PORT" "$BASE" > "$STATE/lab.env"

docker build -q --build-arg "BASE=$BASE" -t "$IMG" . >/dev/null
docker rm -f "$NAME" >/dev/null 2>&1 || true
# LAB-ÖZEL: konteyner içinde Docker (iç içe) overlayfs'i konteyner kök dosya sistemi üzerinde kuramaz; /var/lib/docker ve containerd ayrı volume'dür
# (gerçek VM'de gerekmez). Volume'ler her up.sh'te sıfırlanır.
docker volume rm -f "${NAME}-docker" "${NAME}-containerd" >/dev/null 2>&1 || true
docker run -d --name "$NAME" --privileged --cgroupns=host --tmpfs /run --tmpfs /run/lock \
    -v "${NAME}-docker:/var/lib/docker" -v "${NAME}-containerd:/var/lib/containerd" \
    -p "127.0.0.1:${PORT}:22" "$IMG" >/dev/null
st=""
for _ in $(seq 1 45); do
    st=$(docker exec "$NAME" systemctl is-system-running 2>/dev/null || true)
    case "$st" in running|degraded) break ;; esac
    sleep 2
done
case "$st" in running|degraded) ;; *) echo "⚠️  systemd 90 sn içinde hazır olmadı (durum: ${st:-?}). Log: docker logs $NAME"; exit 1 ;; esac

# LAB-ÖZEL: ağda TLS'i araya giren bir güvenlik yazılımı varsa (örn. ESET SSL filtresi) kök sertifikası LAB konteynerine güvenilir eklenir (doğrulama KAPATILMAZ).
if [ -n "${LAB_CA_FILE:-}" ]; then
    docker cp "$LAB_CA_FILE" "$NAME:/usr/local/share/ca-certificates/lab-ca.crt" && docker exec "$NAME" update-ca-certificates >/dev/null 2>&1
fi
docker exec -i "$NAME" sh -c 'cat > /home/tester/.ssh/authorized_keys && chown tester:tester /home/tester/.ssh/authorized_keys && chmod 600 /home/tester/.ssh/authorized_keys' < "$STATE/id_lab.pub"
docker cp "$STATE/hostkey/ssh_host_ed25519_key" "$NAME:/etc/ssh/ssh_host_ed25519_key"
docker cp "$STATE/hostkey/ssh_host_ed25519_key.pub" "$NAME:/etc/ssh/ssh_host_ed25519_key.pub"
docker exec "$NAME" sh -c 'chown root:root /etc/ssh/ssh_host_ed25519_key* && chmod 600 /etc/ssh/ssh_host_ed25519_key && chmod 644 /etc/ssh/ssh_host_ed25519_key.pub && (systemctl restart ssh || systemctl restart sshd)'
for _ in $(seq 1 30); do nc -z 127.0.0.1 "$PORT" 2>/dev/null && break; sleep 1; done
nc -z 127.0.0.1 "$PORT" 2>/dev/null || { echo "⚠️  sshd 127.0.0.1:$PORT üzerinde yanıt vermiyor"; exit 1; }
{ printf '[127.0.0.1]:%s ' "$PORT"; cut -d' ' -f1,2 "$STATE/hostkey/ssh_host_ed25519_key.pub"; } > "$STATE/kh"
cat > "$STATE/inventory.yml" <<INV
kurulum:
  hosts:
    lab:
      ansible_host: 127.0.0.1
      ansible_port: $PORT
      ansible_user: tester
      ansible_private_key_file: $STATE/id_lab
      ansible_ssh_common_args: "-o UserKnownHostsFile=$STATE/kh -o StrictHostKeyChecking=yes -o IdentitiesOnly=yes"
INV
echo "✅ Hazır: 127.0.0.1:${PORT}  kullanıcı=tester  ($BASE, systemd, parolasız sudo)"
echo "   Çalıştır: test/e2e/lab/run.sh durum   |  Testler: bats test/e2e/lab.bats"
