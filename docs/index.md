---
title: Ana Sayfa
nav_order: 0
---

# scripts

![Bash](https://img.shields.io/badge/Bash-5.x-4EAA25?style=flat&logo=gnubash&logoColor=white) ![GNU Make](https://img.shields.io/badge/GNU-Make-A42E2B?style=flat&logo=gnu&logoColor=white) ![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?style=flat&logo=ubuntu&logoColor=white) ![Linux](https://img.shields.io/badge/Platform-Linux-FCC624?style=flat&logo=linux&logoColor=black) ![License](https://img.shields.io/badge/License-MIT-10B981?style=flat)

Günlük işleri kolaylaştıran kişisel **bash script** koleksiyonu. Her iş kendi klasöründe
yaşar, tek bir `make` komutuyla çalışır ve burada Türkçe olarak belgelenir.

## Hızlı başlangıç

```bash
git clone https://github.com/cagatayuresin/scripts.git
cd scripts
make help
```

Scriptler depoda çalıştırılabilir (`755`) olarak tutulur; klonladıktan sonra `chmod`
ile uğraşmanıza gerek yoktur.

## Script kılavuzları

| No | Modül | Ne işe yarar | Ana komutlar |
|:--|:--|:--|:--|
| 00 | [Kurulum]({{ site.baseurl }}/00_kurulum) | Depoyu klonlama, genel gereksinimler, `make` kullanımı | `make help` |
| 01 | [multipass-cluster-maker]({{ site.baseurl }}/01_multipass-cluster-maker) | Multipass ile Ubuntu 24.04 test laboratuvarı kurar (3 makinelik cluster veya tek makine) | `make mp-cluster`, `make mp-singlenode`, `make mp-clean` |
| 02 | [kind-lab]({{ site.baseurl }}/02_kind-lab) | kind ile ~40 saniyede tek kullanımlık Kubernetes cluster'ı + yerel imaj deposu | `make kind-up`, `make kind-status`, `make kind-down` |
| 03 | [dev-disk]({{ site.baseurl }}/03_dev-disk) | Geliştirme makinesinde biriken çöpü ölçer ve güvenli şekilde temizler (Docker cache, snap, journald) | `make disk-report`, `make disk-clean` |
| 04 | [ollama-lab]({{ site.baseurl }}/04_ollama-lab) | Yerel Ollama: model envanteri, gerçek disk kullanımı, sağlık ve hız testleri | `make llm-list`, `make llm-disk`, `make llm-bench` |

## Depo düzeni

```text
scripts/
├── Makefile                        # tek giriş noktası; modülleri otomatik toplar
├── lib/
│   └── common.sh                   # tüm modüllerin paylaştığı bash kütüphanesi
├── scripts/
│   └── 01-multipass-cluster-maker/ # her iş kendi numaralı klasöründe
│       ├── module.mk               # bu modülün make hedefleri
│       ├── preflight.sh
│       ├── vm-up.sh
│       ├── vm-clean.sh
│       └── cloud-init/
└── docs/
    └── 01_multipass-cluster-maker.md   # numarası modülle eşleşen kılavuz
```

## Yeni script eklerken

1. `scripts/NN-modul-adi/` klasörünü aç (numara sıradaki boş numara).
2. İçine scriptleri ve bir `module.mk` koy; hedeflerini `##` yorumlarıyla belgele —
   `make help` bunları kendiliğinden listeler.
3. `docs/NN_modul-adi.md` dosyasında Türkçe kılavuzu yaz, üstüne kullanılan
   teknolojilerin rozetlerini ekle.
4. Bu sayfadaki tabloya bir satır ekle.
5. `make fix-perms && make lint` çalıştır.

Ayrıntılar için depodaki `CONTRIBUTING.md` dosyasına bakabilirsiniz.
