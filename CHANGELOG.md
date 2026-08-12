# Değişiklik Günlüğü

Bu dosya [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/) biçimini,
sürümler [Semantic Versioning](https://semver.org/lang/tr/) kurallarını izler.

## [Yayınlanmamış]

### Eklendi

- **02-kind-lab** modülü: kind ile ~40 saniyede tek kullanımlık Kubernetes cluster'ı.
  - `make kind-up` — 1 control-plane + N worker; birlikte yerel imaj deposu
    (`localhost:5001`) kurulur ve tüm node'ların containerd yapılandırmasına tanıtılır,
    böylece `kind load docker-image` gerekmez.
  - `make kind-status`, `make kind-list`, `make kind-reset`, `make kind-down`.
  - Kurulum öncesi inotify limiti denetimi ve kurulum sonrası çökmüş sistem pod'u
    kontrolü: kind'in en sık takıldığı `wait-control-plane` / `too many open files`
    durumu artık sebebiyle birlikte raporlanıyor.
  - `make kind-down` kubeconfig'deki context/cluster/user girdilerini de temizler;
    yerel imaj deposu bilinçli olarak korunur (`--purge-registry` ile silinir).

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
