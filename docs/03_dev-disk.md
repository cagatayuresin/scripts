---
title: "03 · dev-disk"
parent: Script Kılavuzları
nav_order: 3
---

# 03-dev-disk · Kullanım Kılavuzu

![Bash](https://img.shields.io/badge/Bash-5.x-4EAA25?style=flat&logo=gnubash&logoColor=white) ![GNU Make](https://img.shields.io/badge/GNU-Make-A42E2B?style=flat&logo=gnu&logoColor=white) ![Docker](https://img.shields.io/badge/Docker-prune-2496ED?style=flat&logo=docker&logoColor=white) ![Snap](https://img.shields.io/badge/Snap-eski_s%C3%BCr%C3%BCmler-82BEA0?style=flat&logo=snapcraft&logoColor=white) ![systemd](https://img.shields.io/badge/systemd-journald-30B9DB?style=flat&logo=systemd&logoColor=white) ![Read-Only](https://img.shields.io/badge/disk--report-salt_okunur-10B981?style=flat) ![Destructive](https://img.shields.io/badge/disk--clean-y%C4%B1k%C4%B1c%C4%B1-DC2626?style=flat)

## Amaç

Geliştirme makinesinde sessizce biriken çöpü **önce ölçer**, sonra isterseniz temizler:
Docker build cache, sarkan imajlar, eski snap sürümleri, journald kayıtları, APT
önbelleği ve çöp kutusu.

Docker'la ve kind/Multipass gibi araçlarla çalışan bir makinede bu birikim hızlıdır —
tipik olarak birkaç GB.

## Güvenlik ilkesi

Bu modül, yıkıcı olabilecek şeyleri **varsayılan olarak yapmaz**:

| Kategori | Davranış | Neden |
|:--|:--|:--|
| Build cache, sarkan imajlar | Silinir | Yeniden üretilir, kayıp yok |
| APT önbelleği, journald, eski snap'ler, çöp kutusu | Silinir | Yeniden indirilir / eski kayıt |
| **Docker volume'ları** | **Asla silinmez** — yalnızca raporlanır | İçinde veritabanı/uygulama verisi olabilir |
| Konteynerler (durmuş olanlar dahil) | Dokunulmaz | Sizin işinize yarıyor olabilir |
| Kullanılmayan imajlar | Yalnızca `disk-clean-all` ile | Yerel build'ler yeniden build gerektirir |

Sarkan volume'lar için script size komutu gösterir ama silmeyi **size bırakır** —
`docker volume prune`'un geri dönüşü yoktur ve durmuş bir veritabanı konteynerinin
verisi orada olabilir.

## Make hedefleri

| Hedef | Açıklama |
|:--|:--|
| `make disk-report` | Neyin ne kadar yer kapladığını gösterir, **hiçbir şey silmez** |
| `make disk-clean` | Güvenli temizlik (yeniden üretilebilir olanlar) |
| `make disk-clean-all` | Yukarıdakiler + kullanılmayan tüm Docker imajları |

## Parametreler

| Değişken | Varsayılan | Anlamı |
|:--|:--|:--|
| `DRY` | — | `DRY=1`: hiçbir şey silmez, ne yapılacağını komutlarıyla gösterir |
| `YES` | — | `YES=1`: onay sorusunu atlar |
| `DISK_JOURNAL_KEEP` | `7d` | journald'de saklanacak süre |
| `DISK_SNAP_RETAIN` | `2` | snap'te saklanacak sürüm sayısı |
| `DISK_NO_SUDO` | — | `DISK_NO_SUDO=1`: sudo gerektiren adımları (APT, snap, journald) atlar |

## Çalıştırma

### 1. Önce ölç

```bash
make disk-report
```

```text
  KATEGORI                   KAZANC       NOT
──────────────────────────────────────────────────────────────────────────────
  Docker build cache         3.6 GiB      guvenli - yeniden uretilir
  Docker sarkan imajlar      0 MiB        guvenli - etiketsiz artiklar
  journald kayitlari         347 MiB      7d oncesi silinir
  APT paket onbellegi        10 MiB       guvenli - yeniden indirilir
  Eski snap surumleri        176 MiB      guvenli - son 2 surum kalir
  Cop kutusu                 1 MiB        guvenli
──────────────────────────────────────────────────────────────────────────────
  TOPLAM                     4.1 GiB       guvenli temizlik

  Ayri degerlendirilenler
──────────────────────────────────────────────────────────────────────────────
  Kullanilmayan imajlar      2.5 GiB      yeniden build gerekir
  Sarkan volume'lar          4.7 GiB      VERI KAYBI RISKI - silinmez
```

### 2. Ne olacağını gör (kuru çalışma)

```bash
make disk-clean DRY=1
```

Tek bir şey silmeden, çalıştırılacak komutları tek tek listeler:

```text
▸ Docker
  [kuru] Build cache temizleniyor
    docker builder prune -f
  [kuru] Sarkan imajlar temizleniyor
    docker image prune -f

▸ Sistem (sudo gerekir)
  [kuru] APT onbellegi temizleniyor
    sudo apt-get clean
  [kuru] journald 7d oncesine kadar kirpiliyor
    sudo journalctl --vacuum-time=7d
  [kuru] Eski snap siliniyor: spotify (rev 97)
    sudo snap remove spotify --revision=97
```

### 3. Temizle

```bash
make disk-clean
```

Önce raporu gösterir, onay ister, sonra adım adım temizler ve **sonunda raporu
yeniden basar** — böylece ne kadar yer kazandığınızı görürsünüz.

sudo gerektiren adımlar (APT, journald, snap) için parola sorulur. İstemiyorsanız:

```bash
make disk-clean DISK_NO_SUDO=1
```

### Geniş temizlik

```bash
make disk-clean-all
```

Ek olarak kullanılmayan **tüm** Docker imajlarını siler. Bu, yerel olarak build
ettiğiniz imajları da kapsar (kendi projeleriniz); onları yeniden build etmeniz gerekir.
Internet'ten gelen imajlar yeniden indirilir.

kind kullanıyorsanız `kindest/node` imajı da silinebilir — bu, sonraki
`make kind-up` çağrısını birkaç dakika yavaşlatır (imaj yeniden indirilir).

## Sarkan volume'lar

Rapor bunları gösterir ama silmez. Karar vermeden önce içeriklerine bakın:

```bash
docker volume ls -f dangling=true
docker volume inspect <ad> | head -20
```

Örneğin durmuş bir `postgres` konteynerine ait volume, veritabanınızı barındırıyor
olabilir. Emin olduktan sonra:

```bash
docker volume prune        # geri dönüşü yoktur
```

## Notlar

- `disk-report` tamamen salt okunurdur; istediğiniz zaman çalıştırabilirsiniz.
- Temizlik sonrası tekrar rapor basılır; "önce/sonra" farkını orada görürsünüz.
- Build cache silmek sonraki `docker build` işlemlerini bir kereliğine yavaşlatır
  (katmanlar yeniden üretilir), ama kalıcı bir kayıp değildir.
