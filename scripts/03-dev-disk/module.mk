# 03-dev-disk - make hedefleri
#
# Gelistirme makinesinde biriken cop: docker build cache, sarkan imajlar,
# eski snap surumleri, journal kayitlari, paket onbellegi.
#
# Guvenlik ilkesi: varsayilan temizlik YALNIZCA yeniden uretilebilir seyleri siler.
#   * Docker volume'lara asla dokunulmaz (veritabani verisi olabilir) - sadece raporlanir
#   * Kullanilan imajlar ve calisan/durmus konteynerler korunur
#   * Kullanilmayan imajlari silmek ayri ve uyarili bir hedeftir (disk-clean-all)
#
# Isimlendirme kurali: hedefler 'disk-', degiskenler 'DISK_' onekli.

##@ 03-dev-disk (gelistirme makinesinde biriken copu olc ve temizle)

DEVDISK_DIR := $(REPO_ROOT)/scripts/03-dev-disk

# --- Ayarlanabilir degiskenler ---------------------------------------------
# journald icin saklanacak sure
DISK_JOURNAL_KEEP ?= 7d
# snap icin saklanacak surum sayisi
DISK_SNAP_RETAIN  ?= 2
# DISK_NO_SUDO=1 -> sudo gerektiren adimlari (apt, snap, journal) atla
DISK_NO_SUDO_FLAG := $(if $(filter 1 yes true,$(DISK_NO_SUDO)),--skip-sudo,)
# DRY=1 -> hicbir sey silme, yalnizca ne yapilacagini goster
DISK_DRY_FLAG     := $(if $(filter 1 yes true,$(DRY)),--dry-run,)

DISK_ARGS := --journal-keep '$(DISK_JOURNAL_KEEP)' --snap-retain '$(DISK_SNAP_RETAIN)' \
             $(DISK_NO_SUDO_FLAG) $(DISK_DRY_FLAG) $(YES_FLAG)

MODULE_TARGETS += disk-report disk-clean disk-clean-all

.PHONY: disk-report
disk-report: ## Neyin ne kadar yer kapladigini gosterir (hicbir sey silmez)
	@$(DEVDISK_DIR)/disk.sh --mode report $(DISK_ARGS)

.PHONY: disk-clean
disk-clean: ## Guvenli temizlik: build cache, sarkan imaj, apt/snap/journal, cop kutusu
	@$(DEVDISK_DIR)/disk.sh --mode clean $(DISK_ARGS)

.PHONY: disk-clean-all
disk-clean-all: ## Yukaridakiler + KULLANILMAYAN tum docker imajlari (yeniden build gerekir)
	@$(DEVDISK_DIR)/disk.sh --mode clean --aggressive $(DISK_ARGS)
