# cagatayuresin/scripts - kok Makefile
#
# Bu dosya yalnizca ortak altyapiyi tutar. Isleri yapan hedefler
# scripts/<NN-modul-adi>/module.mk dosyalarinda tanimlanir ve asagidaki
# include satiri ile otomatik olarak toplanir. Yeni bir modul eklemek icin
# bu dosyaya dokunmak gerekmez.

SHELL := /bin/bash
.DEFAULT_GOAL := help

# REPO_ROOT include'lardan ONCE hesaplanmali; sonrasinda MAKEFILE_LIST'in son
# elemani module.mk olurdu.
REPO_ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
LIB_DIR   := $(REPO_ROOT)/lib

export REPO_ROOT
export LIB_DIR

# Renkler (NO_COLOR=1 ile kapatilir)
ifdef NO_COLOR
  C_RESET :=
  C_BOLD  :=
  C_DIM   :=
  C_BLUE  :=
  C_CYAN  :=
  C_GREEN :=
else
  C_RESET := $(shell printf '\033[0m')
  C_BOLD  := $(shell printf '\033[1m')
  C_DIM   := $(shell printf '\033[2m')
  C_BLUE  := $(shell printf '\033[34m')
  C_CYAN  := $(shell printf '\033[36m')
  C_GREEN := $(shell printf '\033[32m')
endif

MODULE_DIRS := $(sort $(wildcard $(REPO_ROOT)/scripts/*/))
SH_FILES    := $(shell find $(REPO_ROOT)/scripts $(REPO_ROOT)/lib -name '*.sh' 2>/dev/null)

# Depo geneli bayraklar. Anlamlari her modulde ayni oldugu icin bunlar
# namespace'siz kalir; module ozel olan her sey 'mp-' gibi bir onek tasir.
# YES=1 -> onay sorularini atla
YES_FLAG := $(if $(filter 1 yes true,$(YES)),--yes,)

# Kok Makefile'a ait, modullerin kullanamayacagi hedef adlari.
RESERVED_TARGETS := help modules lint fmt fix-perms check-perms

# Moduller hedeflerini MODULE_TARGETS degiskenine ekler; asagidaki denetim
# ayni adin iki modulde kullanilmasini yakalar.
MODULE_TARGETS :=

# --- Modul hedefleri -------------------------------------------------------
include $(wildcard $(REPO_ROOT)/scripts/*/module.mk)

# --- Catisma denetimi ------------------------------------------------------
# make ayni hedefi iki kez gorurse yalnizca "warning: overriding recipe" basip
# SON tanimi calistirir; ciktinin basinda kaybolan bu uyari, yanlis modulun
# silme islemini calistirmasina yol acabilir. Bu yuzden hata ile duruyoruz.
DUPLICATE_TARGETS := $(strip $(shell printf '%s\n' $(MODULE_TARGETS) | sort | uniq -d))
ifneq ($(DUPLICATE_TARGETS),)
  $(error Hedef adi catismasi: $(DUPLICATE_TARGETS). Her modul hedeflerini kendi onekiyle adlandirmali (01 modulu mp-, 02 modulu ornegin yedek-). Bkz. CONTRIBUTING.md)
endif

CLASHING_RESERVED := $(strip $(filter $(RESERVED_TARGETS),$(MODULE_TARGETS)))
ifneq ($(CLASHING_RESERVED),)
  $(error Modul, kok Makefile hedefini eziyor: $(CLASHING_RESERVED). Bu adlar rezervedir: $(RESERVED_TARGETS))
endif

# --- Ortak hedefler --------------------------------------------------------

##@ Genel

.PHONY: help
help: ## Bu yardim ekranini gosterir
	@printf '\n$(C_BOLD)$(C_CYAN)cagatayuresin/scripts$(C_RESET) $(C_DIM)- kisisel bash script koleksiyonu$(C_RESET)\n'
	@printf '$(C_DIM)Kullanim: make <hedef> [DEGISKEN=deger]$(C_RESET)\n'
	@awk 'BEGIN { FS = ":.*##" } \
		/^##@/ { printf "\n  $(C_BOLD)%s$(C_RESET)\n", substr($$0, 5); next } \
		/^[a-zA-Z0-9_-]+:.*##/ { printf "    $(C_GREEN)%-16s$(C_RESET) %s\n", $$1, $$2 }' \
		$(wildcard $(REPO_ROOT)/scripts/*/module.mk) $(REPO_ROOT)/Makefile
	@printf '\n  $(C_BOLD)Dokumantasyon$(C_RESET)\n'
	@printf '    https://cagatayuresin.github.io/scripts/\n\n'

.PHONY: modules
modules: ## Depodaki script modullerini listeler
	@printf '\n$(C_BOLD)Moduller$(C_RESET)\n'
	@for d in $(MODULE_DIRS); do \
		name=$$(basename "$$d"); \
		doc="docs/$$(echo "$$name" | sed 's/^\([0-9]\+\)-/\1_/').md"; \
		printf '  $(C_GREEN)%-32s$(C_RESET) %s\n' "$$name" "$$doc"; \
	done
	@printf '\n'

##@ Bakim

.PHONY: lint
lint: ## shellcheck + shfmt ile scriptleri denetler
	@printf '$(C_BLUE)▸ shellcheck$(C_RESET)\n'
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck --external-sources $(SH_FILES) && printf '  ✔ shellcheck temiz\n'; \
	else \
		printf '  ⚠ shellcheck kurulu degil, atlaniyor (sudo apt install shellcheck)\n'; \
	fi
	@printf '$(C_BLUE)▸ shfmt$(C_RESET)\n'
	@if command -v shfmt >/dev/null 2>&1; then \
		shfmt --diff -i 2 -ci $(SH_FILES) && printf '  ✔ bicimlendirme temiz\n'; \
	else \
		printf '  ⚠ shfmt kurulu degil, atlaniyor (sudo snap install shfmt)\n'; \
	fi
	@printf '$(C_BLUE)▸ bash -n$(C_RESET)\n'
	@for f in $(SH_FILES); do bash -n "$$f" || exit 1; done
	@printf '  ✔ sozdizimi temiz\n'

.PHONY: fmt
fmt: ## shfmt ile scriptleri bicimlendirir (dosyalari degistirir)
	@command -v shfmt >/dev/null 2>&1 || { printf '  ✖ shfmt kurulu degil\n'; exit 1; }
	@shfmt -w -i 2 -ci $(SH_FILES)
	@printf '  ✔ bicimlendirildi\n'

.PHONY: fix-perms
fix-perms: ## Tum .sh dosyalarini calistirilabilir yapar (chmod +x)
	@chmod +x $(SH_FILES)
	@printf '  ✔ calistirilabilir bit ayarlandi ($(words $(SH_FILES)) dosya)\n'

.PHONY: check-perms
check-perms: ## Calistirilabilir biti eksik script var mi kontrol eder (CI)
	@missing=$$(find $(REPO_ROOT)/scripts $(REPO_ROOT)/lib -name '*.sh' ! -perm -u+x); \
	if [ -n "$$missing" ]; then \
		printf '  ✖ calistirilabilir biti eksik dosyalar:\n%s\n' "$$missing"; \
		printf '  ↳ duzeltmek icin: make fix-perms\n'; \
		exit 1; \
	fi
	@printf '  ✔ tum scriptler calistirilabilir\n'
