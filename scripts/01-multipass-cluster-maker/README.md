# 01-multipass-cluster-maker

Multipass ile yerel bir **Ubuntu 24.04** test laboratuvarı kurar.

```bash
make preflight     # sistemi denetle (hiçbir şey kurmaz)
make cluster       # master + worker + datanode
make singlenode    # tek makine
make status        # durum ve IP'ler
make ssh-info      # ssh cluster@<ip>  (parola: cluster)
make clean         # hepsini kalıcı olarak sil
```

Varsayılan profil: makine başına **2 vCPU · 4 GB RAM · 10 GB disk**, kullanıcı
`cluster` / parola `cluster`, parola ile SSH girişi açık.

| Dosya | Görevi |
|:--|:--|
| `module.mk` | Make hedefleri ve ayarlanabilir değişkenler |
| `preflight.sh` | CPU/RAM/disk/KVM/Multipass denetimi (salt okunur) |
| `install-deps.sh` | Eksik araçları kurar (sudo ister) |
| `vm-up.sh` | Makineleri oluşturur, `/etc/hosts` senkronu ve doğrulama |
| `vm-clean.sh` | Makineleri siler, `known_hosts` temizliği |
| `vm-info.sh` | `make status` ve `make ssh-info` çıktıları |
| `cloud-init/node.yaml` | Makine şablonu (kullanıcı, parola, SSH, paketler) |

📖 Tam kılavuz: <https://cagatayuresin.github.io/scripts/01_multipass-cluster-maker>
