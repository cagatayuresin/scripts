# Değişiklik Günlüğü

Bu dosya [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/) biçimini,
sürümler [Semantic Versioning](https://semver.org/lang/tr/) kurallarını izler.

## [Yayınlanmamış]

## [1.0.0] - 2026-08-12

### Eklendi

- Depo iskeleti: modüler `Makefile` (`scripts/*/module.mk` dosyalarını otomatik toplar),
  paylaşılan `lib/common.sh` kütüphanesi, GitHub Actions (CI + Pages) ve
  Jekyll tabanlı `docs/` yapısı.
- Hedef adlandırma kuralı: her modülün tüm hedefleri ve değişkenleri kendi önekini taşır
  (01. modül için `mp-` / `MP_`). Kök Makefile aynı hedefi iki modül tanımlarsa derlemeyi
  hata ile durdurur — make'in varsayılan davranışı olan sessiz "overriding recipe"
  uyarısı, yanlış modülün silme işleminin çalışmasına yol açabilirdi.
- **01-multipass-cluster-maker** modülü:
  - `make mp-preflight` — CPU, RAM, disk, KVM, Multipass ve imaj denetimi; renkli
    `[ TAMAM ] / [ UYARI ] / [ HATA ]` tablosu.
  - `make mp-cluster` — 2 vCPU / 4 GB RAM / 10 GB diskli `master`, `worker`, `datanode`
    makineleri (Ubuntu 24.04).
  - `make mp-singlenode` — aynı profilde tek `singlenode` makinesi.
  - `make mp-status`, `make mp-ssh-info` — durum ve bağlantı bilgileri.
  - `make mp-clean` — makineleri `--purge` ile siler, `known_hosts` kayıtlarını temizler.
  - cloud-init ile `cluster` kullanıcısı, parola ile SSH girişi, parolasız `sudo`
    ve düğümler arası `/etc/hosts` senkronizasyonu.
