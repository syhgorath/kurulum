# kurulum

[sshpocket](https://github.com/syhgorath/sshpocket) paketi: sunucuya **Docker taban kurulumu, nginx, MariaDB ve Redis** kurar (her biri **native** ya da **Docker** modunda), önizleyerek, sürümü sabitleyerek ve **veriyi silmeden**. Menüdeki adı **"Kurulum merkezi"**dir (paket kimliği `kurulum`).

> **Durum: v0.1.0 (yayın öncesi).** Aşağıdaki "Neyin denendiği" tablosu gerçeği söyler: LAB (Ubuntu 26.04 arm64 konteyner) testleri tamam; **gerçek VM turu (Ubuntu 26.04 amd64) büyük ölçüde yapıldı**, hardening'li iki sıralı tur bekliyor ve yayın için tamamlanması şarttır ([docs/vm-turu.md](docs/vm-turu.md)). Debian 13 henüz hiçbir ortamda denenmedi.

## Profiller
| Profil | Durum | Not |
|---|---|---|
| `ubuntu-26.04` | supported | LAB'da (arm64 konteyner) ve **kısmen gerçek VM'de** (amd64, ubuntutest, doğrudan playbook, hardening'siz) denendi; VM turu sürüyor, ayrıntı aşağıda |
| `debian-13` | planned | Playbook çalışır olmalı ama **hiçbir yerde denenmedi** (ne konteyner ne VM). VM turunda doğrulanınca `supported` yapılır |

Proxmox VE bilerek reddedilir (`/usr/bin/pveversion` ya da `/etc/pve` varsa `--check` dahil durur); Raspberry Pi kapsam dışı.

## Eylemler
| Eylem | Etki | Onay | Ne yapar |
|---|---|---|---|
| `durum` | salt okunur | – | Ana klasör işareti, Docker durumu, kurulu yazılımlar ve portlar: `ana_durum=… docker=… kurulu=… portlar=…` |
| `preview` | salt okunur (`--check --diff`) | – | `kur`'un aynı görevleri `--check` ile; `degisen=<N> yukseltme=evet\|hayir` |
| `kur` | `installs-package`, `changes-config` | `yes-no`, `preview` ön koşul | Seçili yazılımı kurar. İkinci çalıştırma `changed=0`. **Sürümü sessizce değiştirmez** |
| `yukselt` | + `destructive` | `type-server-name`, `preview` ön koşul | Yalnızca **docker** modunda, daha **yeni** sürüme; önce döküm/yedek. **Geri düşürme yok** |
| `kaldir` | `changes-config` | `yes-no`, `preview` ön koşul | Servisi durdurur/kaldırır; **veriye dokunmaz** |

Çıktı tek satırdır: `SSHPOCKET_RESULT kurulum.<eylem> yazilim=… mod=… surum=… port=… degisen=… yukseltme=… gizli=<üretilen parola sayısı>`. Parola değeri hiçbir satıra yazılmaz.

## Değişkenler (bugünkü sshpocket ile çalışır; katalog/form sshpocket tarafında sonra gelir)
| Değişken | Tür | Varsayılan | Anlamı |
|---|---|---|---|
| `kurulum_yazilim` | enum | `docker` | `docker` (taban) · `nginx` · `mariadb` · `redis`. Eylemler seçili yazılım için çalışır |
| `kurulum_mod` | enum | `native` | `native` (apt) · `docker`. `docker` yazılımı için yok sayılır. Bir yazılım için **tek mod** |
| `kurulum_ana_klasor` | path | `/srv/homelab` | Docker uygulamalarının klasörü; sunucu başına bir kez (aşağıda) |
| `kurulum_docker_kaynak` | enum | `resmi` | `resmi` (download.docker.com) · `dagitim` (docker.io) |
| `kurulum_dis_erisim` | bool | `false` | `false` = `127.0.0.1`; `true` = `0.0.0.0` (**uyarı çıkar**, ufw'ye yazılmaz) |
| `kurulum_<yz>_port` | int | 8080 / 3306 / 6379 | Sunucuya yayınlanan port |
| `kurulum_<yz>_surum` | enum | 1.30.6 / 11.4.13 / 7.4.12 | Küratörlü imaj sürümü (docker modu; **latest yok**) |
| `kurulum_<yz>_imaj_ozel` | string | boş | Listede olmayan sürüm: `nginx:1.31.8`. **Denenmemiştir**; `latest`/etiketsiz reddedilir |

Küratörlü sürümler (artan; paket sürümüyle gelir): nginx `1.30.6`, `1.31.8` · mariadb `10.11.19`, `11.4.13`, `11.8.9` · redis `7.2.17`, `7.4.12`, `8.2.11`, `8.4.8`. Parola/anahtar değişkeni **yoktur**.

## Nasıl çalışır (kısa)
- **Docker kontrolü:** kurulu değil → `kurulum_yazilim=docker` ile kurulur; apt'ten kurulu (docker-ce ya da docker.io) → **dokunulmaz**; snap/paket dışı → uyarı, dokunulmaz ve Docker modu çalışmaz. Kullanıcı `docker` grubuna **eklenmez** (root-eşdeğeri); komutlar sudo ile. `daemon.json` ve `/var/lib/docker` değişmez. Docker modu için Docker önceden kurulu olmalı (uygulama kurulumu Docker'ı kendiliğinden kurmaz).
- **Docker kaynağı:** varsayılan Docker'ın resmi apt deposu. Depo anahtarı pakette gelir (`roles/docker_taban/files/docker.asc`), parmak izi sabit (`9DC8 5822 9FC7 DD38 854A E2D8 8D81 803C 0EBF CD88`, testle denetlenir); ağdan anahtar indirilmez. Yedek yol `kurulum_docker_kaynak=dagitim`.
- **Ana klasör:** sunucuda `/etc/kurulum/ana` (yol) ve `<ana>/.kurulum` (JSON işaret: kurulu yazılımlar, mod, sürüm, port, veri yolu) **gerçek kaynaktır**. Yerel `kurulum_ana_klasor` farklıysa değiştiren eylemler **durur** ("ana klasör sunucuda X, yerelde Y"), sessiz düzeltme yok. Yol kuralları: mutlak, boşluk/özel karakter yok, `/ /etc /usr /var /srv …` kökleri ve `/var/lib/docker` altı yasak, tmpfs değil, dizin 0750 root. Sonradan taşıma v0.1'de yok.
- **Docker modu:** `<ana>/<yazılım>/compose.yml` şablondan, `docker compose config` ile doğrulanır; veri `<ana>/<yazılım>/data` (bind-mount; adlandırılmış volume ve `down -v` yok); ortak ağ `kurulum`; port varsayılanı `127.0.0.1`. Konteyner adı `kurulum-<yazılım>`.
- **Gizli değerler:** `<ana>/<yazılım>/.env` (0600); parola **sunucuda** `/dev/urandom`'dan, yalnızca yoksa üretilir; `no_log`. `<ana>/.env` yalnızca gizli olmayan bağlantı anahtarlarını taşır (`NGINX_HOST`, `MARIADB_PORT`, `REDIS_HOST_PORT` …): native `127.0.0.1`, docker servis adı.
- **Native:** nginx (kendi sitesi `sites-available/kurulum`, dağıtım varsayılan **bağı** devre dışı, dosya silinmez), MariaDB (`99-kurulum.cnf`: bind/port; root `unix_socket`, parola yok), Redis (`redis.conf` satırları yedekli; parola `requirepass`). Veri dağıtım yerinde (`/var/lib/mysql`, `/var/lib/redis`, `/var/www/html`). Zaten kurulu ama kayıtsız paket varsa **durur**. Paketin kurulum betiği servisi varsayılan portta (80/3306/6379) kısaca başlatır; o port doluysa kurulum başlamadan durur.
- **Port çakışması:** `ss` + işaret dosyası; "3306 portu mariadb uygulamasına verilmiş, boş port önerisi: 3307".
- **Eşzamanlılık:** sunucuda `/run/kurulum.lock` üzerinde `flock`; ikinci koşu durur. Tutucu süreç en geç 30 dk sonra kendiliğinden düşer.

## Native ve Docker modu: farklar (gerçek VM'de görüldü)
- **Modlar arası veri taşıma YOKTUR.** Docker modunun verisi `<ana>/<yazılım>/data`, native modun verisi dağıtım yerindedir (`/var/lib/mysql`, `/var/lib/redis`). `kaldir` ile modu değiştirince eski modun verisi **kullanılmaz** (silinmez, orada durur); taşımayı kendiniz yaparsınız.
- **Sürümler aynı değildir:** native, dağıtım paketinin sürümünü verir (Ubuntu 26.04 VM'de nginx 1.28.3, MariaDB 11.8.6, Redis 8.0.5); docker modu küratörlü sabit etiketi (örn. Redis 7.4.12). Aynı yazılımın iki modu aynı sürümü vermez.
- **Ortak `.env` anahtarları aynı, değerleri moda göre değişir:** `NGINX_HOST`/`_PORT` docker modunda servis adı ve konteyner portu (`nginx`, `80`), native modda `127.0.0.1` ve yayınlanan port (`8080`). Yayınlanan port her iki modda `<YZ>_HOST_PORT`'tur. Mod değişince tüketicilerin bu değerleri yeniden okuması gerekir.
- **`kaldir` ortak `<ana>/.env`'deki o yazılımın bağlantı anahtarlarını siler** (`<YZ>_HOST`, `_PORT`, `_HOST_PORT`; sır değil); yeniden `kur` yazar. Gizli `<ana>/<yazılım>/.env` (parola) silinmez: yeniden kur ve mod değişimi aynı parolayı kullanır.

## ufw ve linux-hardening
`kurulum` ufw'ye **yazmaz** (tek sahibi linux-hardening). `kurulum_dis_erisim=true` yapıldığında çıktı, `servers/<ad>/linux-hardening.vars` içindeki `hardening_ufw_extra_allow_host` listesine eklenecek kuralı **önerir** (`from <yönetim ağı> to any port N proto tcp`, `any` değil). Ansible liste değişkenlerini birleştirmez, üzerine yazar: öneriyi mevcut listeye siz eklersiniz. **Docker yayınlanan portu ufw'yi atlayarak açar** (LAB'da Docker 29.1.3 ile doğrulandı); `DOCKER-USER` ile kısıtlama denenmedi. Varsayılan `127.0.0.1` yayınında kural gerekmez. Hardening'le birlikte kullanım **VM'de denenmedi** (docs/vm-turu.md "Hardening turları"): `hardening_kernel_modules_disabled=true` Docker'ı bozar (kurulum sonra); `hardening_ufw_outgoing_deny` açıksa `apt` ve `docker pull` kapanır; `/tmp` noexec ve AppArmor'un MariaDB'ye etkisi doğrulanmadı.

## Yükseltme, kaldırma ve geri alma kapsamı (dürüstçe)
- **Yükseltme (`yukselt`)** yalnızca docker modunda ve daha yeni sürüme: önce döküm/yedek (`<ana>/<yazılım>/yedek/<tarih>/`, dizin 0700, dosya 0600; MariaDB `mariadb-dump --all-databases`, Redis `SAVE` + veri kopyası, nginx web kökü ve compose.yml), sonra yeni imaj çekilir, sonra compose güncellenir. **Geri düşürme yoktur**; eski sürüme dönmek için yedeği kendiniz geri yüklersiniz (bu paket geri yüklemeyi yapmaz). **Native sürüm yükseltme v0.1'de yok** (apt'i kendiniz yönetin).
- **Kaldır (`kaldir`)** veriye dokunmaz: docker modunda `compose down` (`-v` yok); veri klasörü, `.env` (parola) ve `compose.yml` kalır. Native'de servis durur/devre dışı kalır, paket `apt remove` ile çıkar (**purge yok**), yapılandırma ve veri kalır. Kaldırılan yazılım işarette `kaldirilan` altında kalır; yeniden `kur` aynı veriyi ve aynı parolayı kullanır. Docker taban kaldırma v0.1'de yok.
- **Geri almaz:** kurulan Docker/apt paketlerini, çekilmiş imajları, oluşturulan `kurulum` Docker ağını. Zamanlayıcılı geri alma güvenlik ağı yoktur (ssh/ufw/PAM'a dokunulmaz, erişimi kesmez).

## Neyin denendiği
Ayrıntı sonuçlar CHANGELOG'dadır. Özet:
| Ne | Sonuç |
|---|---|
| `component_validate.py . --strict --unsigned` (`git archive` arşivi) | temiz |
| LAB (Colima + systemd'li `ubuntu:26.04` arm64 konteyneri, iç içe Docker): `lab-docker.bats` / `lab-native.bats` / `lab-preview.bats` | 21/21, 11/11 ve 8/8: idempotans, yükseltmede veri duruyor, kaldır veriyi bırakır, parola sızmıyor (ayrıntı CHANGELOG) |
| `test/run-all.sh` (statik desen denetimi, release betikleri, tutarlılık) | yeşil |
| **Gerçek VM** ubuntutest (Ubuntu 26.04 **amd64**, hardening'siz, doğrudan playbook) | ✅ Docker taban (kur, ikinci kur changed=0); docker modu nginx/MariaDB/Redis kur + ikinci kur changed=0, parola sızıntısı 0 eşleşme, **yükseltme** (MariaDB 10.11.19→11.4.13 veri duruyor, Redis 7.2.17→7.4.12 anahtar duruyor, nginx 1.30.6→1.31.8), **kaldır** (veri/.env/compose kalır; Redis yeniden kur veri ve parolayı korudu); **native** nginx/MariaDB/Redis kur + ikinci kur changed=0. Ayrıntı CHANGELOG |
| Gerçek VM: hardening'li iki sıralı tur, native Redis'te yeni parola üretimi, düzeltilmiş native Redis `preview`, sshpocket menüsü | **denenmedi** |
| Debian 13 (konteyner dahil); `kurulum_docker_kaynak=dagitim` | **denenmedi** (yalnızca Debian deposunun varlığı `apt -s` ile görüldü). Profil `planned` kalır; v0.1.0 yalnızca Ubuntu 26.04 içindir |
| amd64 (LAB arm64) | **denenmedi** |

## Geliştirme
```bash
python3.13 -m venv .venv && .venv/bin/pip install --require-hashes --only-binary :all: -r requirements.txt
python3 -I tools/validate/component_validate.py . --strict --unsigned
test/run-all.sh
LAB_CA_FILE=<gerekirse kök sertifika.pem> bats test/e2e/lab-docker.bats test/e2e/lab-native.bats test/e2e/lab-preview.bats   # Colima/Docker gerekir
```
LAB notu: iç içe Docker için `/var/lib/docker` ve `/var/lib/containerd` ayrı volume'dür (yalnızca LAB; gerçek VM'de gerekmez). Ağda TLS'i araya giren bir güvenlik yazılımı varsa kök sertifikası yalnızca LAB konteynerine eklenir (`LAB_CA_FILE`); doğrulama kapatılmaz, paket buna bağımlı değildir.
Yayın: `scripts/release.sh` / `release-publish.sh` (imza anahtarı ve yayın **kullanıcıdadır**). Kilit PR'ı: `scripts/lock-component.sh kurulum <sürüm> --repo syhgorath/kurulum` (sshpocket oturumu).
