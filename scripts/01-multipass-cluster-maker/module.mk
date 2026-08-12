# 01-multipass-cluster-maker - make hedefleri
#
# Kok Makefile bu dosyayi otomatik include eder. Buradaki tum degiskenler
# komut satirindan ezilebilir:
#   make cluster CPUS=4 MEMORY=8G DISK=20G
#   make singlenode RELEASE=22.04

##@ 01-multipass-cluster-maker (Multipass ile Ubuntu VM lab)

MPCM_DIR := $(REPO_ROOT)/scripts/01-multipass-cluster-maker

# --- Ayarlanabilir degiskenler ---------------------------------------------
RELEASE       ?= 24.04
CPUS          ?= 2
MEMORY        ?= 4G
DISK          ?= 10G
VM_USER       ?= cluster
VM_PASS       ?= cluster
CLUSTER_NODES ?= master worker datanode
SINGLE_NODE   ?= singlenode

# Modulun yonettigi tum makine adlari (clean bu kumeyi hedefler)
MANAGED_NODES ?= $(CLUSTER_NODES) $(SINGLE_NODE)

# preflight profili; cluster/singlenode hedefleri kendi degeriyle cagirir
PROFILE ?= cluster

# FORCE=1     -> preflight uyarilarini yok say (hatalari degil)
# RECREATE=1  -> var olan makineleri silip yeniden kur
# YES=1       -> onay sorularini atla
MPCM_FORCE    := $(if $(filter 1 yes true,$(FORCE)),--force,)
MPCM_RECREATE := $(if $(filter 1 yes true,$(RECREATE)),--force,)
MPCM_YES      := $(if $(filter 1 yes true,$(YES)),--yes,)

MPCM_VM_ARGS := --cpus '$(CPUS)' --memory '$(MEMORY)' --disk '$(DISK)' \
                --release '$(RELEASE)' --user '$(VM_USER)' --pass '$(VM_PASS)'

.PHONY: preflight
preflight: ## Sistem gereksinimlerini denetler (cluster/singlenode oncesi zorunlu)
	@$(MPCM_DIR)/preflight.sh --profile '$(PROFILE)' \
		--nodes '$(if $(filter singlenode,$(PROFILE)),$(SINGLE_NODE),$(CLUSTER_NODES))' \
		$(MPCM_VM_ARGS) $(MPCM_FORCE)

.PHONY: install-deps
install-deps: ## Eksik bagimliliklari kurar (multipass vb., sudo ister)
	@$(MPCM_DIR)/install-deps.sh $(MPCM_YES)

.PHONY: cluster
cluster: PROFILE := cluster
cluster: preflight ## 3 makinelik cluster kurar (master + worker + datanode)
	@$(MPCM_DIR)/vm-up.sh --profile cluster --nodes '$(CLUSTER_NODES)' \
		$(MPCM_VM_ARGS) $(MPCM_RECREATE) $(MPCM_YES)

.PHONY: singlenode
singlenode: PROFILE := singlenode
singlenode: preflight ## Tek makine kurar (singlenode)
	@$(MPCM_DIR)/vm-up.sh --profile singlenode --nodes '$(SINGLE_NODE)' \
		$(MPCM_VM_ARGS) $(MPCM_RECREATE) $(MPCM_YES)

.PHONY: status
status: ## Kurulu makinelerin durumunu ve kaynaklarini gosterir
	@$(MPCM_DIR)/vm-info.sh --mode status --nodes '$(MANAGED_NODES)' --user '$(VM_USER)'

.PHONY: ssh-info
ssh-info: ## Makinelere SSH ile baglanma bilgilerini yazdirir
	@$(MPCM_DIR)/vm-info.sh --mode ssh --nodes '$(MANAGED_NODES)' \
		--user '$(VM_USER)' --pass '$(VM_PASS)'

.PHONY: clean
clean: ## Bu modulun olusturdugu tum makineleri kalici olarak siler
	@$(MPCM_DIR)/vm-clean.sh --nodes '$(MANAGED_NODES)' $(MPCM_YES)
