# scripts

[![CI](https://github.com/cagatayuresin/scripts/actions/workflows/ci.yml/badge.svg)](https://github.com/cagatayuresin/scripts/actions/workflows/ci.yml)
[![Dokümantasyon](https://img.shields.io/badge/Dok%C3%BCmantasyon-GitHub_Pages-222222?style=flat&logo=githubpages&logoColor=white)](https://cagatayuresin.github.io/scripts/)
![Bash](https://img.shields.io/badge/Bash-5.x-4EAA25?style=flat&logo=gnubash&logoColor=white)
![GNU Make](https://img.shields.io/badge/GNU-Make-A42E2B?style=flat&logo=gnu&logoColor=white)
![Linux](https://img.shields.io/badge/Platform-Linux-FCC624?style=flat&logo=linux&logoColor=black)
[![License: MIT](https://img.shields.io/badge/License-MIT-10B981?style=flat)](LICENSE)

Günlük işleri kolaylaştıran kişisel **bash script** koleksiyonu. Her iş kendi numaralı
klasöründe yaşar, tek bir `make` komutuyla çalışır ve `docs/` altında Türkçe olarak belgelenir.

📖 **Dokümantasyon:** <https://cagatayuresin.github.io/scripts/>

## Hızlı başlangıç

```bash
git clone https://github.com/cagatayuresin/scripts.git
cd scripts
make help
```

Scriptler depoda çalıştırılabilir (`755`) tutulur; klonladıktan sonra `chmod` gerekmez.

## Modüller

| No | Modül | Ne işe yarar | Ana komutlar | Kılavuz |
|:--|:--|:--|:--|:--|
| 01 | `multipass-cluster-maker` | Multipass ile Ubuntu 24.04 test laboratuvarı: 3 makinelik cluster (master + worker + datanode) veya tek makine | `make mp-cluster`, `make mp-singlenode`, `make mp-clean` | [docs](https://cagatayuresin.github.io/scripts/01_multipass-cluster-maker) |
| 02 | `kind-lab` | kind ile ~40 saniyede tek kullanımlık Kubernetes cluster'ı + yerel imaj deposu (`kind load` gerekmez) | `make kind-up`, `make kind-status`, `make kind-down` | [docs](https://cagatayuresin.github.io/scripts/02_kind-lab) |
| 03 | `dev-disk` | Geliştirme makinesinde biriken çöpü ölçer ve güvenli temizler; Docker volume'lara asla dokunmaz | `make disk-report`, `make disk-clean` | [docs](https://cagatayuresin.github.io/scripts/03_dev-disk) |

## Örnek

```bash
make mp-preflight     # sistemde eksik var mı? (hiçbir şey kurmaz)
make mp-cluster       # 2 vCPU / 4 GB RAM / 10 GB diskli 3 Ubuntu 24.04 makinesi
make mp-ssh-info      # ssh cluster@<ip>  (parola: cluster)
make mp-clean         # makineleri hiç var olmamış gibi siler
```

```text
──────────────────────────────────────────────────────────────────────────────
  MAKINE         DURUM        IP                 BAGLANTI
──────────────────────────────────────────────────────────────────────────────
  master         Running      10.126.184.129     ssh cluster@10.126.184.129
  worker         Running      10.126.184.222     ssh cluster@10.126.184.222
  datanode       Running      10.126.184.150     ssh cluster@10.126.184.150
──────────────────────────────────────────────────────────────────────────────
```

## Depo düzeni

```text
.
├── Makefile                        # tek giriş noktası; scripts/*/module.mk dosyalarını toplar
├── lib/
│   └── common.sh                   # tüm modüllerin paylaştığı bash kütüphanesi
├── scripts/
│   └── 01-multipass-cluster-maker/ # her iş kendi numaralı klasöründe
│       ├── module.mk               # bu modülün make hedefleri
│       ├── preflight.sh            # sistem gereksinim denetimi
│       ├── install-deps.sh         # eksik araçları kurar
│       ├── vm-up.sh                # makineleri oluşturur
│       ├── vm-clean.sh             # makineleri siler
│       ├── vm-info.sh              # durum ve SSH bilgileri
│       └── cloud-init/node.yaml    # makine şablonu
├── docs/                           # GitHub Pages (Jekyll + just-the-docs)
│   ├── index.md
│   ├── 00_kurulum.md
│   └── 01_multipass-cluster-maker.md
└── .github/workflows/              # CI (lint) + Pages (docs yayını)
```

Kural basit: `scripts/NN-modul-adi/` klasörünün kılavuzu `docs/NN_modul-adi.md` dosyasıdır.

## Yeni script ekleme

1. `scripts/NN-modul-adi/` klasörünü aç.
2. Scriptleri yaz; ortak log/renk/tablo yardımcıları için `lib/common.sh` dosyasını `source` et.
3. `module.mk` içinde hedeflerini tanımla ve `##` yorumlarıyla belgele — `make help`
   bunları kendiliğinden listeler, kök `Makefile`'a dokunmak gerekmez.
   **Tüm hedefler ve değişkenler modül önekini taşır** (01. modül `mp-` / `MP_`), böylece
   iki modül aynı adı kullanamaz; kök Makefile çakışmayı yakalayıp derlemeyi durdurur.
4. `docs/NN_modul-adi.md` kılavuzunu yaz, rozetlerini ekle.
5. `make fix-perms && make lint`

Ayrıntılar: [CONTRIBUTING.md](CONTRIBUTING.md)

## Gereksinimler

- Linux (Ubuntu/Debian üzerinde test edilir)
- `bash` 4.4+, `make`, `awk`, `sed`, `grep`
- Modüle özel araçlar ilgili modülün `make mp-install-deps` hedefiyle kurulur

## Dokümantasyonu yayınlama (tek seferlik ayar)

Depo ayarlarında **Settings → Pages → Build and deployment → Source** seçeneği
**GitHub Actions** olarak ayarlanmalıdır. Sonrasında `docs/` altındaki her değişiklik
otomatik olarak yayınlanır.

## Lisans

[MIT](LICENSE) © cagatayuresin
