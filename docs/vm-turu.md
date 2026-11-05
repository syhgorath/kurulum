# Gerçek VM turu (kullanıcı yapar)

> Bu tur henüz **yapılmadı**. Her satırı sonuç günlüğüne yazın (`yazılım | mod | platform | durum | not`); denenmeyen satırı "denendi" yazmayın. **Yayın için bu turun (ve yükseltme testinin) geçmesi şarttır.**
> Önce her VM'de **snapshot alın**. Komutlar sshpocket menüsü yerine doğrudan playbook ile çalışır (menü turu kilit PR'ından sonradır; onay/ön koşul kapıları o zaman devreye girer).

## Hazırlık
- Kontrol makinesi: `~/Developer/kurulum` (venv: `python3.13 -m venv .venv && .venv/bin/pip install --require-hashes --only-binary :all: -r requirements.txt`).
- Sunucular: `ubuntutest` (Ubuntu 26.04; IP DHCP ile gezer, `server.env`'e bakın) ve **düz Debian 13 VM** (`debiantest`). Üçüncü olarak linux-hardening'li bir VM (aşağıda "Hardening turları").
- Envanter (IP/kullanıcıyı kendinize göre yazın; gizli değer yok):
```bash
printf 'kurulum:\n  hosts:\n    vm:\n      ansible_host: 192.168.1.183\n      ansible_user: KULLANICI\n' > /tmp/kurulum-inv.yml
```
- ssh anahtarınız parolalıysa önce `ssh-add` (Ansible parola soramaz). Komutlardaki `-e ansible_become_exe=/usr/bin/sudo.ws` **yalnızca Ubuntu 26.04** içindir; Debian 13'te kaldırın.
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
ssh KULLANICI@IP 'sudo cat /srv/homelab/.kurulum; sudo ls -la /srv/homelab /srv/homelab/nginx; sudo docker ps; ss -ltn | grep -E ":(8080|3306|6379) "; curl -sI http://127.0.0.1:8080 | head -1'
```
İkinci önizleme/kur `changed=0` olmalı:
```bash
$AP playbooks/preview.yml --check --diff -e kurulum_yazilim=nginx -e kurulum_mod=docker
$AP playbooks/kur.yml -e kurulum_yazilim=nginx -e kurulum_mod=docker
```
Parola sızıntı kontrolü: kur çıktısını kaydedip (`| tee /tmp/kur.log`) sunucudaki parolanın **kaydında bulunmadığını** doğrulayın (parolayı komut satırına yazmadan, sunucuda): `ssh KULLANICI@IP 'sudo sh -c "pw=\$(grep ^MARIADB_ROOT_PASSWORD= /srv/homelab/mariadb/.env | cut -d= -f2-); grep -cF -- \"\$pw\" /dev/stdin"' < /tmp/kur.log` → `0` beklenir.

## Yükseltme testi (kabul ölçütü: geçmeden yayın yok)
1. Eski sürümü kur: `-e kurulum_yazilim=mariadb -e kurulum_mod=docker -e kurulum_mariadb_surum=10.11.19`.
2. Veri yaz (sunucuda): `sudo docker exec kurulum-mariadb sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "CREATE DATABASE t; CREATE TABLE t.k(a int); INSERT INTO t.k VALUES (42)"'`.
3. Yeni sürüme yükselt: `$AP playbooks/yukselt.yml -e kurulum_yazilim=mariadb -e kurulum_mod=docker -e kurulum_mariadb_surum=11.4.13`.
4. Veri duruyor mu: `sudo docker exec kurulum-mariadb sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -N -e "SELECT a FROM t.k"'` → `42`; döküm: `sudo ls -l /srv/homelab/mariadb/yedek/*/` (dizin 0700, dosya 0600).
5. Aynısını `redis` (`7.2.17` → `7.4.12`, `SET k v` / `GET k`) ve `nginx` (`1.30.6` → `1.31.8`) için yapın.
6. Tekrar `kur` (yeni sürümle) `changed=0`.

## Kaldır (veri kalmalı)
```bash
$AP playbooks/kaldir.yml -e kurulum_yazilim=redis -e kurulum_mod=docker -e kurulum_redis_surum=7.4.12
ssh KULLANICI@IP 'sudo ls -la /srv/homelab/redis /srv/homelab/redis/data; sudo docker ps -a'
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
