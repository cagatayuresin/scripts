# 03-dev-disk

Geliştirme makinesinde biriken çöpü ölçer ve güvenli şekilde temizler.

```bash
make disk-report        # ne kadar yer nerede? (hiçbir şey silmez)
make disk-clean DRY=1   # ne silinecek? (kuru çalışma)
make disk-clean         # güvenli temizlik
make disk-clean-all     # + kullanılmayan tüm docker imajları
```

**Asla silinmeyenler:** Docker volume'ları (veri kaybı riski — sadece raporlanır),
konteynerler, kullanılan imajlar.

| Değişken | Varsayılan | Anlamı |
|:--|:--|:--|
| `DRY` | — | `DRY=1`: sadece göster, silme |
| `DISK_JOURNAL_KEEP` | `7d` | journald saklama süresi |
| `DISK_SNAP_RETAIN` | `2` | Saklanacak snap sürümü |
| `DISK_NO_SUDO` | — | sudo adımlarını atla |

📖 Tam kılavuz: <https://cagatayuresin.github.io/scripts/03_dev-disk>
