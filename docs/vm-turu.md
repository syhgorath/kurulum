# Gerçek VM turu (kullanıcı yapar)

> **Durum (v0.1.0):** Bu tur tam tamamlanmadan v0.1.0 çıkarıldı. Gerçek VM'de **doğrulanmayanlar:** V01 (native Redis preview), V02 (kaldır sonrası ortak .env), V04 (apt indeks toparlama), V05 (saat sapması uyarısı), nginx healthcheck, hardening'li iki sıralı tur, native Redis'te yeni parola üretimi, Debian 13. Bunlar yalnızca LAB'da sınandı. Bu turu yapınca sonuçları CHANGELOG'a işleyin.

> Bu tur v0.1.0 için yalnızca **kısmen yapıldı** (üstteki nota bakın). Her satırı sonuç günlüğüne yazın (`yazılım | mod | platform | durum | not`); denenmeyen satırı "denendi" yazmayın. **Yayın için bu turun (ve yükseltme testinin) geçmesi şarttır.**
> Önce her VM'de **snapshot alın**. Komutlar sshpocket menüsü yerine doğrudan playbook ile çalışır (menü turu kilit PR'ından sonradır; onay/ön koşul kapıları o zaman devreye girer).

## Hazırlık
- Kontrol makinesi: `~/Developer/kurulum` (venv: `python3.13 -m venv .venv && .venv/bin/pip install --require-hashes --only-binary :all: -r requirements.txt`).
- Sunucular: `ubuntutest` (Ubuntu 26.04; IP DHCP ile gezer, `server.env`'e bakın) ve **düz Debian 13 VM** (`debiantest`). Üçüncü olarak linux-hardening'li bir VM (aşağıda "Hardening turları").
- Envanter (IP/kullanıcıyı kendinize göre yazın; gizli değer yok):
```bash
printf 'kurulum:\n  hosts:\n    vm:\n      ansible_host: 192.168.1.183\n      ansible_user: KULLANICI\n' > /tmp/kurulum-inv.yml
```
- ssh anahtarınız parolalıysa önce `ssh-add` (Ansible parola soramaz). Komutlardaki `-e ansible_become_exe=/usr/bin/sudo.ws` **yalnızca Ubuntu 26.04** içindir; Debian 13'te kaldırın.
- **`durum` da sudo ister** (işaret dosyası root'a ait, 0640; ana klasör 0750): `--ask-become-pass` olmadan "sudo: interactive authentication is required" ile düşer. Bu yüzden `$AP` HER playbook'ta (durum dahil) `--ask-become-pass` taşır.
- sunucuda `sudo` ssh ile çalışıyorsa `ssh -t` kullanın (sudo parola için terminal ister); `*` içeren yollar **yetkisiz kabukta** açılır ve ana klasör 0750 root olduğundan boş/"No such file" döner: glob'lu komutları `sudo sh -c '...'` içinde çalıştırın.
- Aşağıdaki `$AP` kısaltması: `AP=".venv/bin/ansible-playbook -i /tmp/kurulum-inv.yml --ask-become-pass"` (Ubuntu için sonuna `-e ansible_become_exe=/usr/bin/sudo.ws` ekleyin).
- Sunucuda gizli değer ÜRETİLİR ve ekrana yazılmaz; bu tur boyunca parolayı kopyalamayın. Bağlanmanız gerekirse sunucuda `sudo` ile `.env` dosyasından okunur.

## Sıra (her yazılım ve mod için)
Aşağıda `nginx`/`docker` örneği; `mariadb`, `redis` için `kurulum_yazilim` değişir; native için `-e kurulum_mod=native`.
```bash
cd ~/Developer/kurulum
AP=".venv/bin/ansible-playbook -i /tmp/kurulum-inv.yml --ask-become-pass"
$AP playbooks/durum.yml
$AP playbooks/preview.yml --check --diff -e kurulum_yazilim=docker
```
Snapshot teyidinden sonra **önce Docker taban**, sonra uygulamalar:
```bash
$AP playbooks/kur.yml -e kurulum_yazilim=docker
$AP playbooks/kur.yml -e kurulum_yazilim=nginx -e kurulum_mod=docker
```
Bağımsız salt okunur doğrulama (ayrı ssh oturumu):
```bash
ssh -t KULLANICI@IP "sudo sh -c 'cat /srv/homelab/.kurulum; ls -la /srv/homelab /srv/homelab/nginx; docker ps'"
ssh KULLANICI@IP 'ss -ltn | grep -E ":(8080|3306|6379) "; curl -sI http://127.0.0.1:8080 | head -1'
```
İkinci önizleme/kur `changed=0` olmalı:
```bash
$AP playbooks/preview.yml --check --diff -e kurulum_yazilim=nginx -e kurulum_mod=docker
$AP playbooks/kur.yml -e kurulum_yazilim=nginx -e kurulum_mod=docker
```
Parola sızıntı kontrolü (kur çıktısını `$AP playbooks/kur.yml … | tee /tmp/kur-mariadb.log` ile kaydedin; parolayı komut satırına yazmadan, SUNUCUDA sayılır). `ssh -t` ile stdin yönlendirmesi çalışmaz (sudo terminal ister), bu yüzden günlük önce kopyalanır:
```bash
scp /tmp/kur-mariadb.log KULLANICI@IP:/tmp/kur-mariadb.log
ssh -t KULLANICI@IP "sudo sh -c 'pw=\$(grep ^MARIADB_ROOT_PASSWORD= /srv/homelab/mariadb/.env | cut -d= -f2-); echo eslesen_satir=\$(grep -cF -- \"\$pw\" /tmp/kur-mariadb.log)'; rm -f /tmp/kur-mariadb.log"
```
`eslesen_satir=0` beklenir (parola bulunamamalı).

## Yükseltme testi (kabul ölçütü; v0.1.0 bu madde VM'de tekrarlanmadan çıkarıldı: V01–V05 sonrası yükseltme VM'de yeniden denenmedi)
1. Eski sürümü kur: `-e kurulum_yazilim=mariadb -e kurulum_mod=docker -e kurulum_mariadb_surum=10.11.19`.
2. Veri yaz (sunucuda): `sudo docker exec kurulum-mariadb sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "CREATE DATABASE t; CREATE TABLE t.k(a int); INSERT INTO t.k VALUES (42)"'`.
3. Yeni sürüme yükselt: `$AP playbooks/yukselt.yml -e kurulum_yazilim=mariadb -e kurulum_mod=docker -e kurulum_mariadb_surum=11.4.13`.
4. Veri duruyor mu: `sudo docker exec kurulum-mariadb sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -N -e "SELECT a FROM t.k"'` → `42`; döküm: `ssh -t KULLANICI@IP "sudo sh -c 'ls -ld /srv/homelab/mariadb/yedek /srv/homelab/mariadb/yedek/*/; ls -l /srv/homelab/mariadb/yedek/*/'"` (yedek dizinleri `drwx------`, `dump.sql` `-rw-------`).
5. Aynısını `redis` (`7.2.17` → `7.4.12`, `SET k v` / `GET k`) ve `nginx` (`1.30.6` → `1.31.8`) için yapın.
6. Tekrar `kur` (yeni sürümle) `changed=0`.

## Kaldır (veri kalmalı)
```bash
$AP playbooks/kaldir.yml -e kurulum_yazilim=redis -e kurulum_mod=docker -e kurulum_redis_surum=7.4.12
ssh -t KULLANICI@IP "sudo sh -c 'ls -la /srv/homelab/redis /srv/homelab/redis/data; docker ps -a'"
$AP playbooks/kur.yml -e kurulum_yazilim=redis -e kurulum_mod=docker -e kurulum_redis_surum=7.4.12   # veri geri gelmeli
```
Native: `kaldir` paketi `apt remove` ile çıkarır; `/var/lib/mysql`, `/var/lib/redis`, `/etc/*` **kalır** (purge yok).

## Debian 13'te özellikle bakılacaklar
- Docker resmi deposu (`download.docker.com/linux/debian`, `trixie`): `kur -e kurulum_yazilim=docker` çalıştı mı; `docker --version`, `docker compose version`.
- Dağıtım yedeği: `-e kurulum_docker_kaynak=dagitim` (docker.io + `docker-compose`): yalnızca **ayrı, temiz** bir VM'de dene.
- `mariadb`/`redis`/`nginx` native paket adları ve servis adları (`mariadb`, `redis-server`, `nginx`) beklendiği gibi mi; MariaDB native `99-kurulum.cnf` yolu geçerli mi (`/etc/mysql/mariadb.conf.d/`).
- Not: `ansible_distribution_version` "13.7" gibi nokta sürümüdür; profil eşlemesi ana sürümle yapılır.

## Hardening turları (linux-hardening'li VM; sırayla iki ayrı tur, her biri için snapshot)
**(a) hardening apply SONRASI kurulum:** VM'ye linux-hardening uygulanmış; sonra `kurulum` ile Docker taban + nginx (docker) + mariadb (native ve docker) + redis.
**(b) kurulum SONRASI hardening apply:** önce `kurulum` ile aynıları; sonra linux-hardening `apply`; servisler ve konteynerler hâlâ çalışıyor mu (`durum`, `sudo docker ps`, `ss -ltn`).
İki turda da şunlara bakın ve sonuç günlüğüne yazın:
| Konu | Nasıl | Beklenen / Not |
|---|---|---|
| `/tmp` noexec | `findmnt /tmp` (ayrı tmpfs + noexec mi); mariadb native kurulumu | postinst'ler `/tmp`'ten çalışırsa takılabilir; takılırsa bulguyu yazın (DENENMEDİ) |
| `docker pull` | `sudo docker pull nginx:1.30.6` | `hardening_ufw_outgoing_deny` KAPALIYKEN çalışmalı; açıksa 443/tcp çıkışı gerekir |
| `hardening_kernel_modules_disabled` | varsayılan kapalı | açıksa Docker (`overlay`, `br_netfilter`) bozulur: kurulum **sonra** |
| ufw ve yayınlanan port | `kurulum_dis_erisim=true` ile redis docker; `sudo ufw status` | Docker ufw'yi atlar; paket ufw'ye YAZMAZ, öneri gösterir |
| AppArmor (enforce açıksa) | mariadb native + `99-kurulum.cnf` | reddedilirse `dmesg`/`journalctl -k` kaydı |
| auditd | `sudo ausearch -m EXECVE -ts recent` | Docker kuralları gürültü yapabilir (bilgi) |
| rp_filter / ip_forward | konteynerden dışarı bağlantı | hardening `ip_forward`'a yazmaz; Docker açar |
