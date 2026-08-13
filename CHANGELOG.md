# Değişiklik Günlüğü

Bu dosya [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/) biçimini,
sürümler [Semantic Versioning](https://semver.org/lang/tr/) kurallarını izler.

## [Yayınlanmamış]

### Eklendi

- **04-ollama-lab** modülü: yerel Ollama için envanter, disk, sağlık ve hız araçları
  (tüm hedefler salt okunur).
  - `make llm-list` — yerel/cloud model ayrımı, boyutlar, bellekte tutulan modeller.
  - `make llm-disk` — manifest katmanlarını benzersizleştirerek **gerçek** disk
    kullanımını hesaplar. `ollama list` toplamı ile diskteki gerçek boyut arasındaki
    farkı (paylaşılan katmanlar) ve "bu modeli silersen ne kazanırsın" sorusunun
    doğru cevabını verir — varyantlar için bu çoğu zaman sıfırdır.
  - `make llm-smoke` — API, model varlığı, üretim ve embedding uçlarının hızlı testi.
  - `make llm-bench` — soğuk başlangıç, ilk token gecikmesi (TTFT) ve token/s;
    yükleme maliyetini görmek için iki ardışık çağrı ölçülür.
  - `make llm-embed` — embedding vektör boyutu ve gecikme ölçümü (RAG için).
  - `make llm-rm` / `make llm-purge` — seçili veya tüm yerel modelleri siler; silmeden
    önce diskte gerçekten boşalacak yeri hesaplar (tek varyant çoğu zaman 0 GB),
    `DRY=1` ile denenebilir ve onay ister.

- **03-dev-disk** modülü: geliştirme makinesinde biriken çöpü ölçer ve temizler.
  - `make disk-report` — Docker build cache/imaj/volume, journald, APT önbelleği,
    eski snap sürümleri ve çöp kutusu için kategorili kazanç tablosu (salt okunur).
  - `make disk-clean` — yalnızca yeniden üretilebilir olanları siler; `DRY=1` ile
    tek satır silmeden çalıştırılacak komutları listeler.
  - `make disk-clean-all` — ek olarak kullanılmayan Docker imajları (uyarılı).
  - Docker volume'ları **hiçbir modda silinmez**, yalnızca raporlanır: durmuş bir
    veritabanı konteynerinin verisi orada olabilir.

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
