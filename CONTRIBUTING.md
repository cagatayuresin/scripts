# Katkı Rehberi

Bu depo kişisel bir script koleksiyonudur; düzenin bozulmaması için birkaç basit kural vardır.

## Depo düzeni kuralları

1. **Her iş kendi klasöründe.** `scripts/NN-modul-adi/` — numara iki hanelidir ve sıradaki
   boş numarayı alır (`01-`, `02-`, ...). Klasör adı kebab-case olmalıdır.
2. **Her modülün bir kılavuzu var.** `docs/NN_modul-adi.md` — numara klasörle eşleşir,
   ayraç alt çizgidir (`01_multipass-cluster-maker.md`).
3. **Ortak kod `lib/` altındadır.** Renk, log, tablo, spinner gibi yardımcılar
   `lib/common.sh` içinde; modüller bunu `source` eder, kopyalamaz.
4. **Kök `Makefile` değişmez.** Modül hedefleri `scripts/NN-.../module.mk` içinde tanımlanır
   ve kök Makefile bunları `include $(wildcard scripts/*/module.mk)` ile kendiliğinden toplar.
5. **Her modülün kendi öneki vardır.** Modülün *tüm* hedefleri ve değişkenleri bu öneki
   taşır: 01. modül `mp-` / `MP_` kullanır. Önek kısa ve modülü çağrıştıran bir şey olmalı
   (`mp-cluster`, `yedek-clean` gibi).

### Neden önek zorunlu?

GNU make aynı hedefi iki dosyada görürse **hata vermez**: yalnızca
`warning: overriding recipe for target 'clean'` basıp *son* tanımı çalıştırır. Bu uyarı
çıktının başında kaybolur ve `make clean` sessizce yanlış modülün silme işlemini
çalıştırabilir. Bu yüzden kök Makefile çakışmaları yakalayıp derlemeyi durdurur:

```text
Makefile:60: *** Hedef adi catismasi: mp-clean. Her modul hedeflerini kendi
onekiyle adlandirmali (01 modulu mp-, 02 modulu ornegin yedek-). Stop.
```

Denetimin çalışması için her modül hedeflerini `MODULE_TARGETS` değişkenine bildirir:

```make
MODULE_TARGETS += yedek-backup yedek-clean
```

Şu adlar kök Makefile'a aittir, modüller kullanamaz:
`help`, `modules`, `lint`, `fmt`, `fix-perms`, `check-perms`.
`YES=1` gibi anlamı tüm depoda aynı olan bayraklar ise ortaktır, öneksiz kalır.

## Yeni modül ekleme

```bash
mkdir -p scripts/02-yeni-is
```

`scripts/02-yeni-is/module.mk`:

```make
##@ 02-yeni-is (Kisa aciklama)

# Onek secimi: bu modul 'yeni-' / 'YENI_' kullaniyor.
YENI_DIR := $(REPO_ROOT)/scripts/02-yeni-is

YENI_BIR_DEGISKEN ?= varsayilan

# Catisma denetimi icin hedefleri bildir.
MODULE_TARGETS += yeni-calistir yeni-clean

.PHONY: yeni-calistir
yeni-calistir: ## Bu aciklama `make help` ciktisinda gorunur
	@$(YENI_DIR)/bir-script.sh --secenek '$(YENI_BIR_DEGISKEN)'

.PHONY: yeni-clean
yeni-clean: ## Uretilenleri siler
	@$(YENI_DIR)/temizle.sh $(YES_FLAG)
```

`YES_FLAG` kök Makefile'da tanımlıdır (`YES=1` verildiğinde `--yes` olur), modüller
doğrudan kullanabilir.

Script iskeleti:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh disable=SC1091
source "${REPO_ROOT}/lib/common.sh"
enable_error_trap

banner "Baslik" "alt baslik"
log_step "Bir adim"
log_ok "Tamamlandi"
```

Son olarak:

```bash
make fix-perms      # yeni scriptleri calistirilabilir yap
make lint           # shellcheck + shfmt + bash -n
make help           # yeni hedefler gorunuyor mu?
```

Ve `docs/02_yeni-is.md` kılavuzunu yazıp `docs/index.md` ile `docs/kilavuzlar.md`
tablolarına bir satır ekleyin.

## Kodlama kuralları

- Her script `set -Eeuo pipefail` ve `enable_error_trap` ile başlar.
- Her script `-h/--help`, `--yes` ve `--no-color` seçeneklerini destekler.
- Yıkıcı işlemler (silme, üzerine yazma) **önce ne yapılacağını gösterir**, sonra onay ister;
  `--yes` verilmediyse ve terminal etkileşimli değilse işlem yapılmaz.
- Çıktılar Türkçe, açıklayıcı ve renklidir; renkler TTY yoksa veya `NO_COLOR` tanımlıysa
  otomatik kapanır.
- Girinti 2 boşluk, biçimlendirme `shfmt -i 2 -ci` ile uyumlu olmalıdır.
- Hedef ve değişken adları modül önekini taşır (`mp-clean`, `MP_CPUS`); öneksiz ad
  kullanılmaz. Hedefler `MODULE_TARGETS` değişkenine eklenir, aksi halde çakışma
  denetimi o hedefi göremez.

## Çalıştırılabilir bit

Scriptler depoda `755` ile tutulur, böylece klonlandığında doğrudan çalışırlar.
CI bunu denetler; eksikse iş başarısız olur.

```bash
make fix-perms      # düzeltir
make check-perms    # CI'nin yaptığı kontrol
```

## Commit ve PR

- Commit mesajları kısa ve açıklayıcı olsun (Türkçe veya İngilizce).
- PR açmadan önce `make lint` ve `make check-perms` çalıştırın.
- Yeni modül eklerken kılavuz sayfası olmadan PR açmayın; dokümantasyon bu deponun
  asıl çıktısıdır.
