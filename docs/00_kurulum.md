---
title: "00 · Kurulum"
parent: Script Kılavuzları
nav_order: 0
---

# Kurulum ve Genel Kullanım

![Bash](https://img.shields.io/badge/Bash-5.x-4EAA25?style=flat&logo=gnubash&logoColor=white) ![GNU Make](https://img.shields.io/badge/GNU-Make-A42E2B?style=flat&logo=gnu&logoColor=white) ![Linux](https://img.shields.io/badge/Platform-Linux-FCC624?style=flat&logo=linux&logoColor=black) ![Git](https://img.shields.io/badge/Git-F05032?style=flat&logo=git&logoColor=white)

Bu sayfa, depoyu ilk kez kullanacaklar içindir. Her modülün kendi gereksinimleri
ilgili kılavuz sayfasında ayrıca listelenir.

## Gereksinimler

| Araç | Neden gerekli | Kurulum |
|:--|:--|:--|
| `bash` 4.4+ | Scriptler bash dizilerini ve `mapfile` kullanır | Tüm modern dağıtımlarda hazır |
| `make` | Tüm işlerin giriş noktası | `sudo apt install make` |
| `git` | Depoyu klonlamak için | `sudo apt install git` |
| `awk`, `sed`, `grep` | Çıktı ayrıştırma | Dağıtımla birlikte gelir |

Modüle özel araçlar (örneğin Multipass) ilgili modülün `make install-deps` hedefiyle kurulur.

## Depoyu klonlama

```bash
git clone https://github.com/cagatayuresin/scripts.git
cd scripts
make help
```

`make help` çıktısı, depodaki tüm modülleri ve hedefleri gruplanmış olarak listeler:

```text
cagatayuresin/scripts - kisisel bash script koleksiyonu
Kullanim: make <hedef> [DEGISKEN=deger]

  01-multipass-cluster-maker (Multipass ile Ubuntu VM lab)
    preflight         Sistem gereksinimlerini denetler (cluster/singlenode oncesi zorunlu)
    install-deps      Eksik bagimliliklari kurar (multipass vb., sudo ister)
    cluster           3 makinelik cluster kurar (master + worker + datanode)
    singlenode        Tek makine kurar (singlenode)
    status            Kurulu makinelerin durumunu ve kaynaklarini gosterir
    ssh-info          Makinelere SSH ile baglanma bilgilerini yazdirir
    clean             Bu modulun olusturdugu tum makineleri kalici olarak siler

  Genel
    help              Bu yardim ekranini gosterir
    modules           Depodaki script modullerini listeler

  Bakim
    lint              shellcheck + shfmt ile scriptleri denetler
    fmt               shfmt ile scriptleri bicimlendirir (dosyalari degistirir)
    fix-perms         Tum .sh dosyalarini calistirilabilir yapar (chmod +x)
    check-perms       Calistirilabilir biti eksik script var mi kontrol eder (CI)
```

## Çalıştırılabilirlik

Scriptler depoda `755` izniyle tutulur, yani klonladıktan sonra doğrudan çalışırlar:

```bash
./scripts/01-multipass-cluster-maker/preflight.sh --help
```

Herhangi bir sebeple izinler bozulursa:

```bash
make fix-perms
```

## Değişkenlerle çalışma

Modül hedefleri değişkenlerle özelleştirilebilir; komut satırında verilen değer
varsayılanı ezer:

```bash
make cluster CPUS=4 MEMORY=8G DISK=20G
make singlenode RELEASE=22.04
```

## Renkli çıktı

Çıktılar terminalde renkli, dosyaya veya boruya (pipe) yönlendirildiğinde düz metindir.
Renkleri tamamen kapatmak için standart `NO_COLOR` değişkeni kullanılabilir:

```bash
NO_COLOR=1 make preflight
```

Scriptler doğrudan çağrıldığında `--no-color` seçeneğini de kabul eder.

## Ortak seçenekler

Tüm modül scriptleri aynı arayüzü paylaşır:

| Seçenek | Anlamı |
|:--|:--|
| `-h`, `--help` | Scriptin kendi yardımını gösterir |
| `--yes` | Onay sorularını atlar (otomasyon için) |
| `--no-color` | Renkli çıktıyı kapatır |

Make tarafında ise `YES=1` onayları, `FORCE=1` preflight engellerini atlar.
