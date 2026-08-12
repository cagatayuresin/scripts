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

## Yeni modül ekleme

```bash
mkdir -p scripts/02-yeni-is
```

`scripts/02-yeni-is/module.mk`:

```make
##@ 02-yeni-is (Kisa aciklama)

YENI_DIR := $(REPO_ROOT)/scripts/02-yeni-is

BIR_DEGISKEN ?= varsayilan

.PHONY: bir-hedef
bir-hedef: ## Bu aciklama `make help` ciktisinda gorunur
	@$(YENI_DIR)/bir-script.sh --secenek '$(BIR_DEGISKEN)'
```

Script iskeleti:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../../lib/common.sh disable=SC1091
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
- Hedef isimleri depo genelinde benzersiz olmalıdır (`clean`, `status` gibi genel adlar
  ilk kullanan modülde kalır; ikinci modül `foo-clean` gibi ön ek kullanır).

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
