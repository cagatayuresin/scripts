# 02-kind-lab - make hedefleri
#
# kind (Kubernetes IN Docker) ile saniyeler icinde tek kullanimlik cluster.
# 01-multipass-cluster-maker gercek VM verir (kubeadm, kernel, reboot testleri);
# bu modul ise hizli ve tek kullanimliktir: kurulum ~40 sn, silme ~3 sn.
#
# Isimlendirme kurali: tum hedefler 'kind-', tum degiskenler 'KIND_' onekli.
#
# Ornekler:
#   make kind-up
#   make kind-up KIND_NAME=test KIND_WORKERS=3
#   make kind-up KIND_INGRESS=1
#   make kind-reset

##@ 02-kind-lab (kind ile saniyeler icinde tek kullanimlik cluster)

KINDLAB_DIR := $(REPO_ROOT)/scripts/02-kind-lab

# --- Ayarlanabilir degiskenler ---------------------------------------------
KIND_NAME       ?= lab
KIND_WORKERS    ?= 2
# Bos birakilirsa kind kendi varsayilan node imajini kullanir.
KIND_K8S        ?=
# Yerel imaj deposu: docker push localhost:5001/uygulama:dev
KIND_REGISTRY   ?= 1
KIND_REG_PORT   ?= 5001
# ingress-nginx kurulumu (internet gerektirir, ~30 sn ekler)
KIND_INGRESS    ?= 0
KIND_HTTP_PORT  ?= 8080
KIND_HTTPS_PORT ?= 8443

KIND_ARGS := --name '$(KIND_NAME)' --workers '$(KIND_WORKERS)' \
             --registry '$(KIND_REGISTRY)' --registry-port '$(KIND_REG_PORT)' \
             --ingress '$(KIND_INGRESS)' \
             --http-port '$(KIND_HTTP_PORT)' --https-port '$(KIND_HTTPS_PORT)' \
             $(if $(KIND_K8S),--k8s '$(KIND_K8S)',)

MODULE_TARGETS += kind-up kind-down kind-reset kind-status kind-list

.PHONY: kind-up
kind-up: ## Tek kullanimlik kind cluster'i kurar (yerel imaj deposu ile)
	@$(KINDLAB_DIR)/cluster-up.sh $(KIND_ARGS) $(YES_FLAG)

.PHONY: kind-down
kind-down: ## Cluster'i siler; kubeconfig context'ini de temizler
	@$(KINDLAB_DIR)/cluster-down.sh --name '$(KIND_NAME)' $(YES_FLAG)

.PHONY: kind-reset
kind-reset: ## Cluster'i silip ayni ayarlarla sifirdan kurar
	@$(KINDLAB_DIR)/cluster-down.sh --name '$(KIND_NAME)' --quiet --yes
	@$(KINDLAB_DIR)/cluster-up.sh $(KIND_ARGS) $(YES_FLAG)

.PHONY: kind-status
kind-status: ## Aktif cluster'in node, pod ve imaj deposu durumu
	@$(KINDLAB_DIR)/cluster-info.sh --mode status --name '$(KIND_NAME)' \
		--registry-port '$(KIND_REG_PORT)'

.PHONY: kind-list
kind-list: ## Makinedeki tum kind cluster'larini listeler
	@$(KINDLAB_DIR)/cluster-info.sh --mode list --registry-port '$(KIND_REG_PORT)'
