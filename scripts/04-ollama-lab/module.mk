# 04-ollama-lab - make hedefleri
#
# Yerel Ollama kurulumu icin gunluk arac seti: model envanteri, GERCEK disk
# kullanimi, saglik testi ve hiz olcumu.
#
# Isimlendirme kurali: hedefler 'llm-', degiskenler 'LLM_' onekli.

##@ 04-ollama-lab (yerel LLM: envanter, disk, saglik, hiz)

OLLAMA_DIR := $(REPO_ROOT)/scripts/04-ollama-lab

# --- Ayarlanabilir degiskenler ---------------------------------------------
LLM_HOST        ?= http://localhost:11434
# Bos birakilirsa ilk yerel (cloud olmayan) uretim modeli secilir
LLM_MODEL       ?=
LLM_EMBED_MODEL ?=
LLM_PROMPT      ?= Bir cumleyle kendini tanit.
LLM_TOKENS      ?= 64

# llm-rm icin silinecek modeller (bosluklarla ayrilir)
LLM_MODELS ?=

LLM_COMMON := --host '$(LLM_HOST)' $(if $(LLM_MODEL),--model '$(LLM_MODEL)',)
# DRY=1 -> hicbir sey silme, ne silinecegini goster
LLM_DRY_FLAG := $(if $(filter 1 yes true,$(DRY)),--dry-run,)

MODULE_TARGETS += llm-list llm-disk llm-smoke llm-bench llm-embed llm-rm llm-purge

.PHONY: llm-list
llm-list: ## Kurulu modeller: yerel/cloud ayrimi, boyut, bellekte olanlar
	@$(OLLAMA_DIR)/models.sh --mode list --host '$(LLM_HOST)'

.PHONY: llm-disk
llm-disk: ## GERCEK disk kullanimi: paylasilan katmanlari cozer, ne kazanacagini soyler
	@$(OLLAMA_DIR)/models.sh --mode disk --host '$(LLM_HOST)'

.PHONY: llm-smoke
llm-smoke: ## Ollama ayakta mi, model yanit veriyor mu (hizli saglik testi)
	@$(OLLAMA_DIR)/bench.sh --mode smoke $(LLM_COMMON)

.PHONY: llm-bench
llm-bench: ## Hiz olcumu: soguk baslangic, ilk token gecikmesi, token/s
	@$(OLLAMA_DIR)/bench.sh --mode bench $(LLM_COMMON) \
		--prompt '$(LLM_PROMPT)' --tokens '$(LLM_TOKENS)'

.PHONY: llm-embed
llm-embed: ## Embedding ucu: boyut ve gecikme olcumu (RAG icin)
	@$(OLLAMA_DIR)/bench.sh --mode embed --host '$(LLM_HOST)' \
		$(if $(LLM_EMBED_MODEL),--model '$(LLM_EMBED_MODEL)',)

.PHONY: llm-rm
llm-rm: ## Secili modelleri siler: make llm-rm LLM_MODELS="ad1 ad2"
	@$(OLLAMA_DIR)/models.sh --mode rm --host '$(LLM_HOST)' \
		--models '$(LLM_MODELS)' $(LLM_DRY_FLAG) $(YES_FLAG)

.PHONY: llm-purge
llm-purge: ## TUM yerel modelleri diskten siler (yeniden indirmek saatler surebilir)
	@$(OLLAMA_DIR)/models.sh --mode rm --host '$(LLM_HOST)' \
		--all $(LLM_DRY_FLAG) $(YES_FLAG)
