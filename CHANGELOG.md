# Changelog

Biçim [Keep a Changelog](https://keepachangelog.com/) esas alınmıştır.

## [Unreleased]

### Düzeltilen
- `release-publish.sh` 6) indeks adımı `index-publish.sh`'e `--yes` geçirir (betiğin başındaki y/N zaten yayın onayı; ikinci onay etkileşimsiz pencerede düşüyordu). Yeniden çalıştırma komutu ve `--dry-run` planı da `--yes` gösterir. Gerçek `index-publish.sh` ile **denenmedi**.

### Değişti
- `scripts/release-publish.sh`: Release ve özet doğrulamasından sonra imzalı paket indeksini günceller (`SSHPOCKET_INDEX_DIR/scripts/index-publish.sh`, `--dry-run` listesinde 6. adım); indeks hatası yayımlanmış Release'i geçersiz kılmaz, betik tek başına yeniden çalıştırılabilir. Normal sürümde `components.lock` PR'ı gerekmez. Yayın betiği değişikliği; paket sürümü değişmez. `index-publish.sh` henüz yok: testler sahte betikle yapıldı, gerçek betikle **denenmedi**.

## [0.1.0] - 2026-11-06

İlk sürüm. Yalnızca **Ubuntu 26.04** supported; Debian 13 planned (denenmedi). **Dürüst not:** sürüm, gerçek VM turu tamamlanmadan çıkarıldı (karar kullanıcıda). V01–V05 düzeltmeleri (native Redis preview, kaldır sonrası ortak .env, apt indeks toparlama, saat sapması uyarısı, nginx healthcheck) gerçek VM'de **doğrulanmadı**, yalnızca LAB'da sınandı; hardening'li iki sıralı VM turu, Debian 13 ve amd64 LAB dışı yollar da denenmedi (aşağıda "Denenmedi").

### Eklendi
- Eylemler: `durum` (salt okunur), `preview` (`--check --diff`), `kur` (`yes-no`, `preview` ön koşul), `yukselt` (`type-server-name`, `preview` ön koşul), `kaldir` (`yes-no`).
- Yazılımlar: Docker taban (resmi apt deposu, anahtarı pakette, parmak izi sabit; yedek `docker.io`), nginx, MariaDB, Redis; her biri native (apt) ya da Docker (compose) modunda.
- Ana klasör: sunucuda `/etc/kurulum/ana` ve `<ana>/.kurulum` işareti gerçek kaynaktır; yerel değer farklıysa değiştiren eylemler durur. Yol kuralları, tmpfs ve boş yer denetimi.
- Docker uygulamaları: `compose.yml` şablondan (`docker compose config` ile doğrulanır), bind-mount veri, sabit imaj etiketi (küratörlü liste; `latest` yok), `127.0.0.1` varsayılan yayın, ortak Docker ağı.
- Gizli değerler sunucuda üretilir, `<ana>/<yazılım>/.env` 0600, `no_log`; sonuç satırları parola yazmaz.
- Port çakışması denetimi (`ss` + işaret dosyası, boş port önerisi), tek mod kuralı, yönetilmeyen paket koruması, sunucuda `flock` ile eşzamanlı koşu kilidi.
- Yükseltme: döküm/yedek (0700/0600) sonra yeni imaj; geri düşürme reddedilir. Kaldır: veri, `.env` ve compose.yml kalır; `apt purge` ve `compose down -v` yok (statik testle denetlenir).
- `kurulum_dis_erisim=true`: ufw'ye yazılmaz, `hardening_ufw_extra_allow_host` önerisi gösterilir.
- Profiller: `ubuntu-26.04` supported (LAB + kısmi gerçek VM turu; hardening'li tur denenmedi), `debian-13` planned (denenmedi).
- Release araçları utility'den alındı; LAB e2e (`test/e2e/lab-docker.bats`, `lab-native.bats`), statik denetim, tutarlılık betiği.

### Denendi
- LAB (Colima + systemd'li `ubuntu:26.04` **arm64** konteyneri, iç içe Docker 29.9.3 / Compose 5.7): `bats test/e2e/lab-docker.bats` **20/20**, `bats test/e2e/lab-native.bats` **10/10**. Kapsam: Docker taban (resmi apt deposu) kurulumu ve ikinci kur `changed=0`; nginx/MariaDB/Redis docker ve native kur, ikinci kur `changed=0`; `preview` dosya özetini değiştirmez; **yükseltme** (MariaDB 10.11.19→11.4.13 tablo verisi duruyor, Redis 7.2.17→7.4.12 anahtar duruyor, nginx 1.30.6→1.31.8 web kökü yedeği); geri düşürme ve sessiz sürüm değişimi reddedilir; kaldır veriyi/.env'i bırakır ve yeniden kur aynı veriyi bulur; port çakışması, tek mod, yönetilmeyen paket, dolu 80 portu, ana klasör uyuşmazlığı, yasak yollar, eşzamanlı koşu kilidi; **parola sızıntısı**: üretilen parolalar hiçbir koşu ekranında (`-v` dahil) ve sonuç satırında yok.
- `test/test_static.sh`: `down -v`, `purge`, `latest`, adlandırılmış volume, ufw yazımı, docker grubu, docker.sock, privileged desenleri yok; Docker anahtar parmak izi beklenen değer.
- Docker resmi apt deposunun Debian 13 (`trixie`) için varlığı ve `docker-ce` adayı `apt -s` ile görüldü; **gerçek kurulum denenmedi**.

- Gerçek VM (ubuntutest, Ubuntu 26.04 **amd64**, hardening'siz, doğrudan playbook, `sudo.ws`; koordinatörün bildirdiği sonuçlar): `durum` (temiz VM); Docker taban preview/kur (docker-ce 29.9.3, Compose v5.7.0, resmi depo `resolute`, anahtar paketten) ve ikinci kur `changed=0`; **docker modu**: nginx, MariaDB 10.11.19, Redis 7.2.17 kur, ikinci kur `changed=0`, parola sızıntı testi **0 eşleşme** (MariaDB ve Redis), **yükseltme** MariaDB 10.11.19→11.4.13 (dump alındı, veri `42` duruyor), Redis 7.2.17→7.4.12 (SAVE + veri kopyası, anahtar duruyor), nginx 1.30.6→1.31.8 (yedek, 200); yükseltme sonrası kur `changed=0`; **kaldır** üçü için (konteyner gitti, 3306/6379/8080 boş, `compose.yml`/`data`/`yedek`/`.env` kaldı, `kaldirilan` kaydı; ikinci kaldır `changed=0`), Redis kaldır + yeniden kur (veri ve parola korundu); **native modlar** nginx (nginx 1.28.3, `127.0.0.1:8080`, 200, varsayılan site devre dışı), MariaDB (11.8.6, root unix_socket, `99-kurulum.cnf`, veri yazıldı) ve Redis (8.0.5, `NOAUTH`, `SET/GET`; parola eski docker `.env`'den yeniden kullanıldı, yani **native Redis'te yeni parola üretimi VM'de denenmedi**) kur + ikinci kur `changed=0`; native Redis `preview` bu turda düştü (V01, düzeltildi, VM'de yeniden denenmedi). Hiçbir koşuda `[WARNING]` çıkmadı. Kaldır sonrası ara durumda `kaldirilan` kaydı ve `data/` doğrulandı (MariaDB/nginx/Redis için koordinatör raporu).

### Düzeltilen (V04: yeniden çalıştırmada toparlanma, V05: saat sapması)
- **V04:** depo/indeks bayat ya da boşsa `kur` kendini toparlamıyordu. Gerçek VM'de ilk `kur` Docker deposunu ekledi ama `apt update` saat sapmasıyla düştü; yeniden çalıştırmada depo görevi "değişmedi" olduğundan indeks güncellemesi atlandı ve `No package matching 'docker-ce'` ile düştü. Artık `docker-ce`/`docker.io`/`nginx`/`mariadb-server`/`redis-server` için `apt-cache policy` adayı yoksa indeks yenilenir (salt okunur sorgu, `--check`'te de çalışır; `--check`'te indeks yenilenmediğinden paket görevi atlanır). LAB'da (`test/e2e/lab-apt.bats`): indeks boşken native nginx/MariaDB/Redis ve "depo zaten ekli, docker-ce yok" Docker taban `kur` kendini toparladı. **Mutasyonla sınandı:** toparlama görevi devre dışı bırakılınca 3 test kırmızı oldu.
- **V05:** ön kontrol sunucu ve kontrol makinesi saatini karşılaştırır; fark `kurulum_saat_esigi_sn` (3600 sn) üstündeyse GERİDE/İLERİDE ve fark miktarıyla net **UYARI** + çözüm (`sudo date -u -s @<epoch>` ya da `chronyc makestep`, utility paketi NTP'yi yönetir) yazar. Koşuyu durdurmaz, hiçbir şey yazmaz, `--check`'te de çalışır; `durum` da `date_time` toplar. LAB'da sunucu saati **değiştirilmeden** yalnızca python sürecine `libfaketime` (-13 gün) verilerek sınandı.

### Düzeltilen (V02: kaldır sonrası ortak .env)
- `kaldir`, ortak `<ana>/.env`'deki o yazılımın bağlantı anahtarlarını (`<YZ>_HOST`, `_PORT`, `_HOST_PORT`) siler; önceden kaldırılmış servisin anahtarları kalıyor ve tüketiciler silinmiş servisi arıyordu. Gizli `.env` (parola) ve veri silinmez. Testle denetlenir (docker ve native). README'ye mod farkları ve "modlar arası veri taşıma yok" notu eklendi (V03).

### Düzeltilen (VM turu: V01-REDIS-NATIVE-PREVIEW ve nginx healthcheck)
- **Redis native `preview` temiz sunucuda düşüyordu** (`Destination /etc/redis/redis.conf does not exist`): `--check`'te apt paketi kurmaz, `lineinfile` olmayan dosyaya yazamaz (artık `<ana>/redis/.env` bulunduğunda, örn. kaldırılmış Redis sonrası). Menüde `kur` `preview` ön koşuludur, bu yüzden temiz sunucuda native Redis menüden kurulamazdı. nginx'teki kalıp Redis'e de eklendi.
- Yeni `test/e2e/lab-preview.bats`: her yazılım x mod için temiz sunucuda `preview` başarılı ve sunucuya yazmaz (dosya özeti, paket ve konteyner sayısı aynı). **Mutasyonla sınandı:** düzeltme geri alınınca "artık .env varken redis native preview" testi VM'deki hatayla kırmızı oldu. Not: temiz LAB'da (artık `.env` yokken) hata görünmezdi; önceki LAB testleri bu yüzden kaçırmıştı.
- nginx docker modunda healthcheck eklendi (mariadb/redis ile tutarlı); "Wait until healthy" artık nginx'te de gerçek sağlığı bekler. Mevcut nginx docker kurulumlarında bir sonraki `kur` compose.yml değişince konteyneri yeniden oluşturur (kısa kesinti).

### Düzeltilen (VM turu ve uyarı taraması)
- `env_dosyalari`: `include_role`'u döngüye sokmak iç döngülerin `item`ini gölgeliyordu (`[WARNING]: The variable 'item' is already in use`); döngü iki ayrı göreve çevrildi. Tüm koşuların çıktısında `[WARNING]`/`[DEPRECATION WARNING]` olmaması artık bats testidir; `ansible.cfg`'de `deprecation_warnings` açıldı.
- "Wait until healthy" görevi `shell` yerine `command`; yalnızca yükselt'te çalışan yedek/pull görevlerine `--check` koruması.
- `docs/vm-turu.md`: glob'lu yedek doğrulaması ve parola sızıntı kontrolü komutları (yetkisiz kabuk glob'u, `ssh -t` ile stdin) düzeltildi; `durum` için `--ask-become-pass` açıkça yazıldı.

### Düzeltilen (LAB'da bulundu)
- Yarım kalan koşu (örn. port çakışması) sunucuda yalnız `/etc/kurulum/ana` bırakıp işareti yazmıyordu; sonraki koşular "işaret yok" diye kilitleniyordu. İlk işaret artık ana klasörle birlikte yazılır.

### Denenmedi
- **Gerçek VM'de saat sapması senaryosu bir kez yaşandı (snapshot dönüşünde saat 13 gün geride); V04 ve V05 düzeltmeleri gerçek VM'de henüz denenmedi** (yalnızca LAB, faketime ile); gerçek saat değişimiyle uyarı VM'de görülmedi.
- Gerçek VM'de hardening'li iki sıralı tur (`/tmp` noexec, `docker pull`, ufw/AppArmor etkileşimi); debiantest ve Debian 13 (profil `planned` kalır; v0.1.0 yalnızca Ubuntu 26.04 için); native Redis'te yeni parola üretimi ve sızıntı testi; düzeltilmiş native Redis `preview`'ın VM'de yeniden denenmesi (konteyner dahil); amd64; sshpocket menüsünden uçtan uca; `kurulum_docker_kaynak=dagitim` (docker.io) yolu; `/tmp` noexec ile MariaDB/nginx/`docker pull`; AppArmor enforce ile native MariaDB; `DOCKER-USER` ile ufw kısıtlama; `kurulum_<yz>_imaj_ozel` ile listede olmayan sürüm; snap Docker algılaması (kodda var, test edilmedi).
