---
title: "02 · kind-lab"
parent: Script Kılavuzları
nav_order: 2
---

# 02-kind-lab · Kullanım Kılavuzu

![Bash](https://img.shields.io/badge/Bash-5.x-4EAA25?style=flat&logo=gnubash&logoColor=white) ![GNU Make](https://img.shields.io/badge/GNU-Make-A42E2B?style=flat&logo=gnu&logoColor=white) ![kind](https://img.shields.io/badge/kind-v0.25%2B-326CE5?style=flat&logo=kubernetes&logoColor=white) ![Kubernetes](https://img.shields.io/badge/Kubernetes-cluster-326CE5?style=flat&logo=kubernetes&logoColor=white) ![Docker](https://img.shields.io/badge/Docker-engine-2496ED?style=flat&logo=docker&logoColor=white) ![Registry](https://img.shields.io/badge/Registry-localhost%3A5001-0DB7ED?style=flat&logo=docker&logoColor=white)

## Amaç

Geliştirme makinesinde, **~40 saniyede** tek kullanımlık bir Kubernetes cluster'ı kurar.
Cluster'la birlikte bir **yerel imaj deposu** da ayağa kalkar; böylece geliştirdiğiniz
imajı `docker push` ile itip doğrudan cluster'da çalıştırabilirsiniz — her turda
`kind load docker-image` beklemek gerekmez.

## 01 ile arasındaki fark

| | **02-kind-lab** | **01-multipass-cluster-maker** |
|:--|:--|:--|
| Teknoloji | Docker konteyneri (kind) | Gerçek VM (Multipass + QEMU/KVM) |
| Kurulum süresi | ~40 saniye | ~2 dakika |
| Kaynak | Az (paylaşılan kernel) | 3 × (2 vCPU, 4 GB RAM, 10 GB disk) |
| Ne için | Günlük geliştirme döngüsü, hızlı test | kubeadm kurulumu, kernel modülü, node reboot, systemd, air-gapped simülasyonu |

Kısacası: **gün içinde kind, gerçek sunucu davranışı gerektiğinde Multipass.**

## Gereksinimler

| Araç | Not |
|:--|:--|
| `kind` | <https://kind.sigs.k8s.io/docs/user/quick-start/#installation> |
| `kubectl` | `sudo snap install kubectl --classic` |
| `docker` | Çalışır durumda olmalı (`docker info`) |

### inotify limitleri (önemli)

Bu, kind'in en sık takıldığı yerdir ve hata mesajı sebebi **söylemez**. Her node kendi
`kubelet`/`containerd` izleyicilerini açar; Ubuntu varsayılanları ikinci bir cluster için
yetmez. Belirtiler:

- `kind create cluster` → `error execution phase wait-control-plane` (zaman aşımı)
- Cluster kurulur ama `kube-proxy` **CrashLoopBackOff**'a düşer;
  log'da: `failed complete: too many open files`

Kalıcı çözüm:

```bash
printf 'fs.inotify.max_user_instances=512\nfs.inotify.max_user_watches=524288\n' \
  | sudo tee /etc/sysctl.d/99-kind.conf && sudo sysctl --system
```

`make kind-up` bu değerleri kurulumdan önce denetler ve düşükse uyarır; kurulumdan
sonra da çökmüş sistem pod'u olup olmadığına bakar. Limiti yükseltmeden geçici çözüm:
daha az node (`make kind-up KIND_WORKERS=0`).

Ne kadar yer kaldığını görmek için (limit dolmak üzereyse yeni cluster kurulamaz):

```bash
find /proc/*/fd -lname 'anon_inode:inotify' 2>/dev/null | wc -l   # açık instance sayısı
sysctl fs.inotify.max_user_instances                              # tavan
```

### Değişikliği geri alma

```bash
sudo rm /etc/sysctl.d/99-kind.conf && sudo sysctl --system
```

**Dikkat:** `sysctl --system` yalnızca yapılandırma dosyalarında *tanımlı* değerleri
yeniden uygular. Ubuntu'da `max_user_watches` başka bir dosyada (`30-localsearch.conf`)
tanımlı olduğu için eski değerine döner, ama `max_user_instances` hiçbir varsayılan
dosyada tanımlı değildir — bu yüzden çalışma anındaki yüksek değerini **yeniden
başlatmaya kadar korur**. Hemen düşürmek için:

```bash
sudo sysctl fs.inotify.max_user_instances=128
```

## Make hedefleri

| Hedef | Açıklama |
|:--|:--|
| `make kind-up` | Cluster + yerel imaj deposunu kurar |
| `make kind-status` | Node'lar, çalışmayan pod'lar, depo durumu |
| `make kind-list` | Makinedeki tüm kind cluster'ları (aktif olan işaretli) |
| `make kind-reset` | Siler ve aynı ayarlarla sıfırdan kurar |
| `make kind-down` | Siler; kubeconfig context/cluster/user girdilerini de temizler |

## Parametreler

| Değişken | Varsayılan | Anlamı |
|:--|:--|:--|
| `KIND_NAME` | `lab` | Cluster adı (context `kind-lab` olur) |
| `KIND_WORKERS` | `2` | Worker sayısı; `0` verilirse tek node'lu cluster |
| `KIND_K8S` | — | Node imajı/sürümü, örn. `v1.31.2` |
| `KIND_REGISTRY` | `1` | Yerel imaj deposu kurulsun mu |
| `KIND_REG_PORT` | `5001` | Deponun host portu |
| `KIND_INGRESS` | `0` | `1` ise ingress-nginx kurar ve 80/443'ü hosta açar |
| `KIND_HTTP_PORT` | `8080` | Ingress için host HTTP portu |
| `KIND_HTTPS_PORT` | `8443` | Ingress için host HTTPS portu |

```bash
make kind-up KIND_NAME=test KIND_WORKERS=3      # 3 worker'lı ikinci cluster
make kind-up KIND_WORKERS=0                     # tek node, en hızlı
make kind-up KIND_INGRESS=1                     # ingress-nginx ile
make kind-up KIND_K8S=v1.31.2                   # belirli Kubernetes sürümü
make kind-down KIND_NAME=test                   # sadece o cluster'ı sil
```

Aynı anda birden fazla cluster çalıştırabilirsiniz; `KIND_NAME` farklı olduğu sürece
birbirlerini etkilemezler ve hepsi aynı imaj deposunu kullanır.

## Çalıştırma

```bash
make kind-up
```

```text
──────────────────────────────────────────────────────────────────────────────
 kind lab
  cluster: lab · 1 control-plane + 2 worker
──────────────────────────────────────────────────────────────────────────────

▸ Yerel imaj deposu
  ✔ Imaj deposu olusturuluyor (localhost:5001) (2s)

▸ Cluster olusturuluyor
  ✔ kind cluster 'lab' kuruluyor (38s)

▸ Imaj deposu cluster'a baglaniyor
  ✔ localhost:5001 tum node'lara tanitildi

▸ Dogrulama
  ✔ Cluster erisilebilir (context: kind-lab)

  NAME                STATUS   ROLES           AGE   VERSION
  lab-control-plane   Ready    control-plane   32s   v1.31.2
  lab-worker          Ready    <none>          20s   v1.31.2
  lab-worker2         Ready    <none>          20s   v1.31.2
```

## İmajını cluster'a taşıma

Yerel depo, kind'in resmi
[local registry](https://kind.sigs.k8s.io/docs/user/local-registry/) yöntemiyle
kurulur: depo konteyneri `kind` ağına bağlanır ve her node'un containerd
yapılandırmasına `localhost:5001` adresi tanıtılır.

```bash
docker build -t localhost:5001/uygulama:dev .
docker push localhost:5001/uygulama:dev

kubectl run deneme --image=localhost:5001/uygulama:dev
```

Manifest içinde de aynı adres kullanılır:

```yaml
spec:
  containers:
    - name: uygulama
      image: localhost:5001/uygulama:dev
      imagePullPolicy: Always
```

`imagePullPolicy: Always` önerilir: aynı etiketi tekrar push ettiğinizde node'un
önbellekteki eski katmanı kullanmasını engeller.

## Ingress ile çalışma

```bash
make kind-up KIND_INGRESS=1
```

ingress-nginx kurulur, control-plane node'una `ingress-ready=true` etiketi verilir ve
konteynerin 80/443 portları hosta eşlenir. Ingress kaynaklarınıza
`http://localhost:8080` üzerinden erişirsiniz.

## Temizlik

```bash
make kind-down
```

Cluster silinir ve `~/.kube/config` içindeki `kind-lab` context/cluster/user girdileri
denetlenip temizlenir (çökmüş cluster'lardan artık kalmasın diye).

**Yerel imaj deposu bilinçli olarak korunur:** birden fazla cluster onu paylaşır ve
içindeki imajlar bir sonraki kurulumda hazır olur. Tamamen kaldırmak için:

```bash
./scripts/02-kind-lab/cluster-down.sh --purge-registry --yes
```

## Sorun giderme

| Belirti | Çözüm |
|:--|:--|
| `wait-control-plane` zaman aşımı | inotify limiti — yukarıdaki bölüme bakın; hızlı çare `KIND_WORKERS=0` |
| `kube-proxy` CrashLoopBackOff | Aynı sebep: `too many open files`. Limiti yükseltip `make kind-reset` |
| `Docker calismiyor gorunuyor` | `sudo systemctl start docker` |
| Pod `ImagePullBackOff`, imaj `localhost:5001/...` | Depo cluster'a bağlı mı: `make kind-status`. Gerekirse `make kind-reset` |
| `port is already allocated` (5001) | Başka bir servis portu tutuyor: `make kind-up KIND_REG_PORT=5002` |
| Ingress'e 8080'den erişilemiyor | Cluster `KIND_INGRESS=1` ile kurulmalı; sonradan açmak için `make kind-reset KIND_INGRESS=1` |
| `kubectl` başka cluster'a bakıyor | `kubectl config use-context kind-lab` (uyarıyı `make kind-status` da gösterir) |

## Notlar

- kind node'ları docker konteyneridir; `docker ps` çıktısında `lab-control-plane`,
  `lab-worker` gibi isimlerle görünürler.
- Cluster'lar makine yeniden başlatıldığında ayakta kalmaz sayılmalıdır — zaten
  tek kullanımlık olmaları amaçlanmıştır. Kalıcı bir ortam gerekiyorsa 01. modülü kullanın.
- Node imajları ve depodaki katmanlar disk yer kaplar; birikeni görmek ve temizlemek
  için `03-dev-disk` modülüne bakın.
