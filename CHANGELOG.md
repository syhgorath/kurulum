# Changelog

Biçim [Keep a Changelog](https://keepachangelog.com/) esas alınmıştır.

## [Unreleased]

## [0.1.0] - yayın öncesi (VM turu bekliyor)

İlk sürüm adayı. **Yayınlanmadı**; gerçek VM turu ve VM'de yükseltme testi geçmeden yayınlanmaz.

### Eklendi
- Eylemler: `durum` (salt okunur), `preview` (`--check --diff`), `kur` (`yes-no`, `preview` ön koşul), `yukselt` (`type-server-name`, `preview` ön koşul), `kaldir` (`yes-no`).
- Yazılımlar: Docker taban (resmi apt deposu, anahtarı pakette, parmak izi sabit; yedek `docker.io`), nginx, MariaDB, Redis; her biri native (apt) ya da Docker (compose) modunda.
- Ana klasör: sunucuda `/etc/kurulum/ana` ve `<ana>/.kurulum` işareti gerçek kaynaktır; yerel değer farklıysa değiştiren eylemler durur. Yol kuralları, tmpfs ve boş yer denetimi.
- Docker uygulamaları: `compose.yml` şablondan (`docker compose config` ile doğrulanır), bind-mount veri, sabit imaj etiketi (küratörlü liste; `latest` yok), `127.0.0.1` varsayılan yayın, ortak Docker ağı.
- Gizli değerler sunucuda üretilir, `<ana>/<yazılım>/.env` 0600, `no_log`; sonuç satırları parola yazmaz.
- Port çakışması denetimi (`ss` + işaret dosyası, boş port önerisi), tek mod kuralı, yönetilmeyen paket koruması, sunucuda `flock` ile eşzamanlı koşu kilidi.
- Yükseltme: döküm/yedek (0700/0600) sonra yeni imaj; geri düşürme reddedilir. Kaldır: veri, `.env` ve compose.yml kalır; `apt purge` ve `compose down -v` yok (statik testle denetlenir).
- `kurulum_dis_erisim=true`: ufw'ye yazılmaz, `hardening_ufw_extra_allow_host` önerisi gösterilir.
- Profiller: `ubuntu-26.04` supported (LAB'da denendi; VM turu bekliyor), `debian-13` planned (denenmedi).
- Release araçları utility'den alındı; LAB e2e (`test/e2e/lab-docker.bats`, `lab-native.bats`), statik denetim, tutarlılık betiği.

### Denendi
- LAB (Colima + systemd'li `ubuntu:26.04` **arm64** konteyneri, iç içe Docker 29.9.3 / Compose 5.7): `bats test/e2e/lab-docker.bats` **20/20**, `bats test/e2e/lab-native.bats` **10/10**. Kapsam: Docker taban (resmi apt deposu) kurulumu ve ikinci kur `changed=0`; nginx/MariaDB/Redis docker ve native kur, ikinci kur `changed=0`; `preview` dosya özetini değiştirmez; **yükseltme** (MariaDB 10.11.19→11.4.13 tablo verisi duruyor, Redis 7.2.17→7.4.12 anahtar duruyor, nginx 1.30.6→1.31.8 web kökü yedeği); geri düşürme ve sessiz sürüm değişimi reddedilir; kaldır veriyi/.env'i bırakır ve yeniden kur aynı veriyi bulur; port çakışması, tek mod, yönetilmeyen paket, dolu 80 portu, ana klasör uyuşmazlığı, yasak yollar, eşzamanlı koşu kilidi; **parola sızıntısı**: üretilen parolalar hiçbir koşu ekranında (`-v` dahil) ve sonuç satırında yok.
- `test/test_static.sh`: `down -v`, `purge`, `latest`, adlandırılmış volume, ufw yazımı, docker grubu, docker.sock, privileged desenleri yok; Docker anahtar parmak izi beklenen değer.
- Docker resmi apt deposunun Debian 13 (`trixie`) için varlığı ve `docker-ce` adayı `apt -s` ile görüldü; **gerçek kurulum denenmedi**.

### Düzeltilen (LAB'da bulundu)
- Yarım kalan koşu (örn. port çakışması) sunucuda yalnız `/etc/kurulum/ana` bırakıp işareti yazmıyordu; sonraki koşular "işaret yok" diye kilitleniyordu. İlk işaret artık ana klasörle birlikte yazılır.

### Denenmedi
- Gerçek VM (ubuntutest, debiantest), hardening'li iki sıralı tur, VM'de yükseltme testi; Debian 13 (konteyner dahil); amd64; sshpocket menüsünden uçtan uca; `kurulum_docker_kaynak=dagitim` (docker.io) yolu; `/tmp` noexec ile MariaDB/nginx/`docker pull`; AppArmor enforce ile native MariaDB; `DOCKER-USER` ile ufw kısıtlama; `kurulum_<yz>_imaj_ozel` ile listede olmayan sürüm; snap Docker algılaması (kodda var, test edilmedi).
