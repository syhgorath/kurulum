# Birleşik paket (v0.2.0): gerçek VM'de bakılacaklar

v0.2.0 gerçek VM'de **denenmedi**. Utility eylemlerinin v0.1.2 VM turu için [vm-turu-utility.md](vm-turu-utility.md), kurulum eylemleri için [vm-turu.md](vm-turu.md). Birleştirmeden gelen yeni noktalar (snapshot alın, doğrudan playbook; envanter grubu artık `utility`):

| Ne | Komut | Beklenen |
|---|---|---|
| `durum` anahtarları korunmuş | `$AP playbooks/durum.yml` | `timezone locale ntp_servis ntp_senkron offset_ms kaynak_sayisi sapma_ms secili_kaynak saat_sapma_kontrolcuye_gore_sn` aynı sırayla |
| `ntp_durum` | `$AP playbooks/ntp_durum.yml` | salt okunur, `hizmetler=…`, `proxmox=hayir` |
| `ntp_ayarla` | `$AP playbooks/ntp_ayarla.yml -e '{"utility_ntp_servers":["time.cloudflare.com"]}'`; ikinci koşu | ilk: `plan=…ntp…`; ikinci: `changed=0`; saat dilimi ve locale değişmez |
| chrony + timesyncd birlikte (Ubuntu 26.04, Debian 13) | `ntp_ayarla` sonrası `ntp_durum` | `hizmetler=` neyi gösteriyor? **Bu davranış denenmedi**; sonucu CHANGELOG'a işleyin |
| Proxmox reddi | (Proxmox VM varsa) `ntp_ayarla` | `--check` dahil durur, hiçbir şey değişmez; `ntp_durum` `proxmox=evet` |
| Kurulum eylemleri yeni adlarla | `$AP playbooks/kurulum_durum.yml`, `kurulum_onizle.yml`, `kur.yml` | sonuç satırı öneki `utility.*` |
