# 02-kind-lab

kind ile saniyeler içinde tek kullanımlık Kubernetes cluster'ı.

```bash
make kind-up          # 1 control-plane + 2 worker + yerel imaj deposu
make kind-status      # node, pod ve depo durumu
make kind-reset       # sil, aynı ayarlarla yeniden kur
make kind-down        # sil (kubeconfig context'i dahil)
make kind-list        # makinedeki tüm kind cluster'ları
```

Yerel imaj deposu sayesinde `kind load docker-image` gerekmez:

```bash
docker build -t localhost:5001/uygulama:dev .
docker push localhost:5001/uygulama:dev
# manifest içinde: image: localhost:5001/uygulama:dev
```

| Değişken | Varsayılan | Anlamı |
|:--|:--|:--|
| `KIND_NAME` | `lab` | Cluster adı (context: `kind-lab`) |
| `KIND_WORKERS` | `2` | Worker sayısı (`0` = tek node) |
| `KIND_K8S` | — | Node imajı, örn. `v1.31.2` |
| `KIND_REGISTRY` | `1` | Yerel imaj deposu |
| `KIND_REG_PORT` | `5001` | Depo portu |
| `KIND_INGRESS` | `0` | ingress-nginx kurulumu |

**01 ile farkı:** kind konteyner tabanlıdır, ~40 saniyede kurulur ve günlük test
döngüsü içindir. Gerçek VM davranışı gerektiğinde (kubeadm kurulumu, kernel modülü,
node reboot, systemd) `01-multipass-cluster-maker` kullanılır.

📖 Tam kılavuz: <https://cagatayuresin.github.io/scripts/02_kind-lab>
