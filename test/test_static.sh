#!/usr/bin/env bash
# Statik denetim (konteyner gerektirmez): veri güvenliği ve ufw ilkesi desenleri playbook/rollerde YOK. Kural: taslak §2, §6.
. "$(dirname "$0")/lib.sh"
SRC=$(find "$ROOT/playbooks" "$ROOT/roles" -type f \( -name '*.yml' -o -name '*.j2' \) | sort)
yok() {  # ad, desen
  local hit; hit=$(grep -nE -- "$2" $SRC | grep -vE '^[^:]+:[0-9]+:\s*#' | grep -vE "(msg|fail_msg|description): " || true)
  if [ -z "$hit" ]; then ok "$1"; else bad "$1: $hit"; fi
}
yok "compose down -v yok" 'compose[^|#]* down[^|#]*(-v|--volumes)'
yok "apt purge yok (purge: true / apt-get purge)" 'purge: *(true|yes)|apt(-get)? +purge'
yok "latest etiketi yok" ':latest|image: *[a-z]+ *$'
yok "adlandırılmış volume yok (volumes: üst düzey)" '^volumes:'
yok "ufw'ye yazılmıyor (ufw modülü/komutu)" 'community\.general\.ufw|ansible\.builtin\.ufw|ufw +(allow|deny|limit|enable|insert|delete|route)'
yok "docker grubuna kullanıcı eklenmiyor" 'groups: *docker|usermod .*docker|append: *true.*docker'
yok "docker.sock mount yok" 'docker\.sock'
yok "privileged konteyner yok" 'privileged: *true'
# gizli değer: parola üreten ve yazan görevler no_log
n=$(grep -c 'no_log: true' "$ROOT/roles/env_dosyalari/tasks/gizli.yml")
if [ "$n" -ge 4 ]; then ok "gizli.yml görevleri no_log"; else bad "gizli.yml no_log sayısı $n (<4)"; fi
if grep -q 'lookup(.password' $SRC; then bad "controller'da parola üretimi (lookup password) var"; else ok "parola controller'da üretilmiyor"; fi
# compose şablonlarında parola yok, env_file kullanılıyor
for t in mariadb redis; do
  if grep -qiE 'PASSWORD: *[^"$ ]|PASSWORD=[A-Za-z0-9]' "$ROOT/roles/$t/templates/compose.yml.j2"; then bad "$t compose şablonunda sabit parola"; else ok "$t compose şablonunda parola yok"; fi
done
# Docker anahtar parmak izi
fp=$(docker run --rm -i ubuntu:26.04 bash -c 'apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq gnupg >/dev/null 2>&1; gpg --show-keys --with-colons /dev/stdin 2>/dev/null' < "$ROOT/roles/docker_taban/files/docker.asc" 2>/dev/null | awk -F: '/^fpr/{print $10; exit}')
if [ -n "$fp" ]; then expect_eq "Docker depo anahtarı parmak izi" "9DC858229FC7DD38854AE2D88D81803C0EBFCD88" "$fp"; else echo "  atlandı: Docker yok, parmak izi doğrulanamadı"; fi
finish
