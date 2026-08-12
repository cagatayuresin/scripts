# 01-multipass-cluster-maker - make hedefleri
#
# Kok Makefile bu dosyayi otomatik include eder.
#
# Isimlendirme kurali: bu modulun TUM hedefleri ve degiskenleri 'mp-' / 'MP_'
# onekini tasir. Boylece 02, 03 ... modulleri ayni adi (clean, status, CPUS gibi)
# kullansa bile catisma olmaz. Kok Makefile ayni hedefi iki modul tanimlarsa
# derlemeyi hata ile durdurur.
#
# Ornekler:
#   make mp-cluster MP_CPUS=4 MP_MEMORY=8G MP_DISK=20G
#   make mp-singlenode MP_RELEASE=22.04

##@ 01-multipass-cluster-maker (Multipass ile Ubuntu VM lab)

MP_DIR := $(REPO_ROOT)/scripts/01-multipass-cluster-maker

# --- Ayarlanabilir degiskenler ---------------------------------------------
MP_RELEASE       ?= 24.04
MP_CPUS          ?= 2
MP_MEMORY        ?= 4G
MP_DISK          ?= 10G
MP_USER          ?= cluster
MP_PASS          ?= cluster
MP_CLUSTER_NODES ?= master worker datanode
MP_SINGLE_NODE   ?= singlenode

# Modulun yonettigi tum makine adlari (mp-clean bu kumeyi hedefler)
MP_MANAGED_NODES ?= $(MP_CLUSTER_NODES) $(MP_SINGLE_NODE)

# preflight profili; mp-cluster/mp-singlenode kendi degeriyle cagirir
MP_PROFILE ?= cluster

# MP_FORCE=1     -> preflight engellerine ragmen devam et
# MP_RECREATE=1  -> var olan makineleri silip yeniden kur
# YES=1          -> onay sorularini atla (depo geneli bayrak, kok Makefile'da)
MP_FORCE_FLAG    := $(if $(filter 1 yes true,$(MP_FORCE)),--force,)
MP_RECREATE_FLAG := $(if $(filter 1 yes true,$(MP_RECREATE)),--force,)

MP_VM_ARGS := --cpus '$(MP_CPUS)' --memory '$(MP_MEMORY)' --disk '$(MP_DISK)' \
              --release '$(MP_RELEASE)' --user '$(MP_USER)' --pass '$(MP_PASS)'

# Catisma denetimi icin hedefleri kok Makefile'a bildir.
MODULE_TARGETS += mp-preflight mp-install-deps mp-cluster mp-singlenode \
                  mp-status mp-ssh-info mp-clean

.PHONY: mp-preflight
mp-preflight: ## Sistem gereksinimlerini denetler (kurulumdan once zorunlu calisir)
	@$(MP_DIR)/preflight.sh --profile '$(MP_PROFILE)' \
		--nodes '$(if $(filter singlenode,$(MP_PROFILE)),$(MP_SINGLE_NODE),$(MP_CLUSTER_NODES))' \
		$(MP_VM_ARGS) $(MP_FORCE_FLAG)

.PHONY: mp-install-deps
mp-install-deps: ## Eksik bagimliliklari kurar (multipass vb., sudo ister)
	@$(MP_DIR)/install-deps.sh $(YES_FLAG)

.PHONY: mp-cluster
mp-cluster: MP_PROFILE := cluster
mp-cluster: mp-preflight ## 3 makinelik cluster kurar (master + worker + datanode)
	@$(MP_DIR)/vm-up.sh --profile cluster --nodes '$(MP_CLUSTER_NODES)' \
		$(MP_VM_ARGS) $(MP_RECREATE_FLAG) $(YES_FLAG)

.PHONY: mp-singlenode
mp-singlenode: MP_PROFILE := singlenode
mp-singlenode: mp-preflight ## Tek makine kurar (singlenode)
	@$(MP_DIR)/vm-up.sh --profile singlenode --nodes '$(MP_SINGLE_NODE)' \
		$(MP_VM_ARGS) $(MP_RECREATE_FLAG) $(YES_FLAG)

.PHONY: mp-status
mp-status: ## Kurulu makinelerin durumunu ve kaynaklarini gosterir
	@$(MP_DIR)/vm-info.sh --mode status --nodes '$(MP_MANAGED_NODES)' --user '$(MP_USER)'

.PHONY: mp-ssh-info
mp-ssh-info: ## Makinelere SSH ile baglanma bilgilerini yazdirir
	@$(MP_DIR)/vm-info.sh --mode ssh --nodes '$(MP_MANAGED_NODES)' \
		--user '$(MP_USER)' --pass '$(MP_PASS)'

.PHONY: mp-clean
mp-clean: ## Bu modulun olusturdugu tum makineleri kalici olarak siler
	@$(MP_DIR)/vm-clean.sh --nodes '$(MP_MANAGED_NODES)' $(YES_FLAG)
