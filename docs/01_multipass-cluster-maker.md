---
title: "01 · multipass-cluster-maker"
parent: Script Kılavuzları
nav_order: 1
---

# 01-multipass-cluster-maker · Kullanım Kılavuzu

![Bash](https://img.shields.io/badge/Bash-5.x-4EAA25?style=flat&logo=gnubash&logoColor=white) ![GNU Make](https://img.shields.io/badge/GNU-Make-A42E2B?style=flat&logo=gnu&logoColor=white) ![Multipass](https://img.shields.io/badge/Multipass-1.10%2B-E95420?style=flat&logo=canonical&logoColor=white) ![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?style=flat&logo=ubuntu&logoColor=white) ![cloud-init](https://img.shields.io/badge/cloud--init-user--data-0E8420?style=flat&logo=cloudinit&logoColor=white) ![QEMU](https://img.shields.io/badge/QEMU%2FKVM-hypervisor-FF6600?style=flat&logo=qemu&logoColor=white) ![OpenSSH](https://img.shields.io/badge/OpenSSH-parola_ile_giris-000000?style=flat&logo=openssh&logoColor=white)

## Amaç

Yerel makinede, tek komutla, **Ubuntu 24.04 LTS** tabanlı bir test laboratuvarı kurar.
Kurulan makineler birbirini adıyla görür, parola ile SSH kabul eder ve `sudo` yetkili bir
kullanıcıyla hazır gelir — yani gerçek bir sunucu gibi davranırlar.

İki senaryo vardır:

| Komut | Sonuç |
|:--|:--|
| `make mp-cluster` | 3 makine: **master**, **worker**, **datanode** |
| `make mp-singlenode` | 1 makine: **singlenode** |

Her makinenin varsayılan profili: **2 vCPU · 4 GB RAM · 10 GB disk**.

## Gereksinimler

| Gereksinim | Not |
|:--|:--|
| Multipass 1.10+ | `make mp-install-deps` ile kurulabilir (`sudo snap install multipass`) |
| KVM desteği | `/dev/kvm` erişilebilir olmalı; BIOS/UEFI'de VT-x veya AMD-V açık olmalı |
| Boş kaynak | Cluster için ~6 vCPU, ~13 GB kullanılabilir RAM, ~33 GB disk |
| `sshpass` (opsiyonel) | Kurulum sonunda parola ile SSH girişi otomatik test edilir |

Bu gereksinimlerin tümü `make mp-preflight` ile denetlenir ve `make mp-cluster` / `make mp-singlenode`
komutları preflight'ı **kendiliğinden, zorunlu olarak** çalıştırır — atlanamaz.

## Make hedefleri

| Hedef | Açıklama |
|:--|:--|
| `make mp-preflight` | Sistemi denetler, hiçbir şey kurmaz ve değiştirmez |
| `make mp-install-deps` | Eksik araçları kurar (sudo ister, onay alır) |
| `make mp-cluster` | preflight → 3 makine kurar |
| `make mp-singlenode` | preflight → 1 makine kurar |
| `make mp-status` | Kurulu makinelerin durumu, IP'si ve kaynak kullanımı |
| `make mp-ssh-info` | Kopyalanabilir SSH bağlantı komutları |
| `make mp-clean` | Makineleri kalıcı olarak siler, izlerini temizler |

## Parametreler

Tüm değişkenler komut satırından ezilebilir:

| Değişken | Varsayılan | Anlamı |
|:--|:--|:--|
| `MP_CPUS` | `2` | Makine başına vCPU |
| `MP_MEMORY` | `4G` | Makine başına RAM |
| `MP_DISK` | `10G` | Makine başına disk |
| `MP_RELEASE` | `24.04` | Ubuntu sürümü (`22.04`, `noble` vb.) |
| `MP_USER` | `cluster` | Oluşturulacak kullanıcı |
| `MP_PASS` | `cluster` | Kullanıcının parolası |
| `MP_CLUSTER_NODES` | `master worker datanode` | Cluster makine adları |
| `MP_SINGLE_NODE` | `singlenode` | Tek makine senaryosunun adı |
| `MP_FORCE` | — | `MP_FORCE=1`: preflight engellerine rağmen devam et |
| `MP_RECREATE` | — | `MP_RECREATE=1`: aynı adlı makineleri silip yeniden kur |
| `YES` | — | `YES=1`: onay sorularını atla |

Örnekler:

```bash
make mp-cluster MP_CPUS=4 MP_MEMORY=8G MP_DISK=20G     # daha güçlü makineler
make mp-singlenode MP_RELEASE=22.04              # farklı Ubuntu sürümü
make mp-cluster MP_CLUSTER_NODES="db app lb"     # kendi makine adların
make mp-cluster MP_RECREATE=1 YES=1              # var olanları silip baştan kur
```

## Çalıştırma

### 1. Sistemi denetle

```bash
make mp-preflight
```

```text
──────────────────────────────────────────────────────────────────────────────
 Preflight - sistem gereksinim denetimi
  profil: cluster
──────────────────────────────────────────────────────────────────────────────
  Kurulacak makineler : master worker datanode
  Makine basina       : 2 vCPU, 4G RAM, 10G disk (Ubuntu 24.04)
  Toplam ihtiyac      : 6 vCPU, 12.0 GiB RAM, 33.0 GiB disk (imaj payi dahil)

  DURUM     KONTROL                    BEKLENEN               BULUNAN
──────────────────────────────────────────────────────────────────────────────
  [ TAMAM ] Multipass istemcisi        >= 1.10.0              1.16.3
  [ TAMAM ] Multipass servisi          calisiyor              multipassd 1.16.3
  [ TAMAM ] Sanallastirma surucusu     qemu/libvirt           qemu
  [ TAMAM ] KVM cihazi                 okunur/yazilir         /dev/kvm
  [ TAMAM ] CPU sanallastirma          vmx veya svm           svm
  [ TAMAM ] CPU cekirdegi              6 vCPU                 12 cekirdek
  [ TAMAM ] Kullanilabilir bellek      >= 13.0 GiB            17.8 GiB
  [ TAMAM ] Bos disk alani             >= 33.0 GiB            189.2 GiB
  [ TAMAM ] Ubuntu imaji               24.04                  kullanilabilir
  [ TAMAM ] Makine adi cakismasi       yok                    temiz
──────────────────────────────────────────────────────────────────────────────
  Sonuc: 15 tamam, 0 uyari, 0 hata

  ✔ Sistem hazir. Kuruluma gecebilirsiniz.
```

Kontroller üç seviyede raporlanır:

- **`[ TAMAM ]`** — sorun yok.
- **`[ UYARI ]`** — kurulum yapılabilir ama dikkat edilmeli (örneğin RAM sıkışık,
  aynı adda makine zaten var). Kurulum devam eder.
- **`[ HATA ]`** — kurulum engellenir (örneğin Multipass kurulu değil, KVM yok).
  Çıkış kodu `1` olur ve `make mp-cluster` durur. Yine de denemek için `MP_FORCE=1`.

### 2. Kur

```bash
make mp-cluster
```

```text
▸ Makine olusturuluyor: master
    2 vCPU · 4G RAM · 10G disk · Ubuntu 24.04
  ✔ 'master' baslatiliyor (imaj indirilebilir, biraz surebilir) (48s)
  ✔ 'master' icinde cloud-init tamamlaniyor (12s)

▸ Dugumler arasi isim cozumleme (/etc/hosts)
  ✔ master: diger dugumler /etc/hosts icine yazildi
  ✔ worker: diger dugumler /etc/hosts icine yazildi
  ✔ datanode: diger dugumler /etc/hosts icine yazildi

▸ Dogrulama
  ✔ master: 'cluster' kullanicisi olusturuldu
  ✔ master: SSH servisi 22 portunu dinliyor
  ✔ master: parola ile SSH girisi calisiyor (cluster@10.126.184.10)

──────────────────────────────────────────────────────────────────────────────
 Kurulum tamamlandi
──────────────────────────────────────────────────────────────────────────────
  MAKINE         DURUM        IP                 BAGLANTI
──────────────────────────────────────────────────────────────────────────────
  master         Running      10.126.184.10      ssh cluster@10.126.184.10
  worker         Running      10.126.184.11      ssh cluster@10.126.184.11
  datanode       Running      10.126.184.12      ssh cluster@10.126.184.12
──────────────────────────────────────────────────────────────────────────────
```

### 3. Bağlan

```bash
make mp-ssh-info          # bağlantı bilgilerini göster
ssh cluster@10.126.184.10
# parola: cluster
```

Multipass'in kendi kabuğu da kullanılabilir:

```bash
multipass shell master
```

### 4. Sil

```bash
make mp-clean
```

Makineler `--purge` ile silinir, `multipass purge` çalıştırılır ve makinelerin IP
adreslerine ait kayıtlar `~/.ssh/known_hosts` dosyasından temizlenir. Böylece aynı
IP yeniden kullanıldığında `REMOTE HOST IDENTIFICATION HAS CHANGED` uyarısı alınmaz.

## Makinelerde ne var?

Her makine `cloud-init/node.yaml` şablonundan üretilir:

- **Kullanıcı:** `cluster` / parola `cluster`, `sudo` grubu, parolasız `sudo`
- **SSH:** parola ile giriş açık (`ssh_pwauth` + `/etc/ssh/sshd_config.d/60-cluster-lab.conf`)
- **Paketler:** `openssh-server`, `curl`, `vim`, `net-tools`, `ca-certificates`
- **Saat dilimi:** `Europe/Istanbul`
- **Hostname:** makine adı (`master`, `worker`, `datanode`, `singlenode`)
- **İsim çözümleme:** cluster senaryosunda tüm düğümler `/etc/hosts` içine yazılır

Multipass'in kendi `ubuntu` kullanıcısı korunur (`users: - default`), bu yüzden
`multipass shell` ve `multipass exec` çalışmaya devam eder.

```bash
ssh cluster@<master-ip> 'ping -c1 worker && ping -c1 datanode'
```

## Sorun giderme

| Belirti | Sebep / Çözüm |
|:--|:--|
| `[ HATA ] Multipass istemcisi` | `make mp-install-deps` veya `sudo snap install multipass` |
| `[ HATA ] Multipass servisi` | `sudo snap start multipass`, durum: `snap services multipass` |
| `[ HATA ] KVM cihazi` | BIOS/UEFI'de sanallaştırmayı açın; `sudo usermod -aG kvm $USER` |
| `[ UYARI ] Makine adi cakismasi` | Makine zaten var; `make mp-cluster MP_RECREATE=1` veya `make mp-clean` |
| `launch failed: timed out` | İmaj indirmesi yavaş olabilir; komutu tekrar çalıştırın |
| `cloud-init 'done' durumuna ulasamadi` | `multipass exec <ad> -- sudo cloud-init status --long` ile inceleyin |
| SSH parola sormadan reddediyor | `multipass exec <ad> -- sudo sshd -T \| grep passwordauth` ile kontrol edin |

## Notlar

- Makineler **NAT** arkasındaki Multipass ağındadır; IP'ler yeniden kurulumda değişebilir.
  Bu yüzden scriptler IP'yi her seferinde `multipass list` üzerinden okur.
- `make mp-clean` yalnızca bu modülün adlarını (`master`, `worker`, `datanode`, `singlenode`)
  hedefler; başka Multipass makineleriniz varsa onlara dokunmaz. Her şeyi silmek için
  `scripts/01-multipass-cluster-maker/vm-clean.sh --all` kullanılabilir.
- Parola ile SSH girişi bilinçli bir tercihtir: bu bir **yerel test laboratuvarıdır**.
  Aynı yapılandırmayı internete açık sunucularda kullanmayın.
- `cloud-init` yapılandırması Multipass'e dosya yolu yerine **stdin** ile verilir; snap
  paketlenmesi nedeniyle Multipass `/tmp` içindeki ve `~/.` ile başlayan gizli
  dizinlerdeki dosyaları okuyamaz.
