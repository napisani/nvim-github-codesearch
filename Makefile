.PHONY: deps-snacks deps-telescope deps-plenary test-qf test-telescope test-snacks

LOCAL_PACK_DIR := .local-plugins/pack/vendor/start

deps-snacks:
	@mkdir -p $(LOCAL_PACK_DIR)
	@if [ ! -d $(LOCAL_PACK_DIR)/snacks.nvim ]; then \
		git clone https://github.com/folke/snacks.nvim $(LOCAL_PACK_DIR)/snacks.nvim; \
	fi

deps-telescope:
	@mkdir -p $(LOCAL_PACK_DIR)
	@if [ ! -d $(LOCAL_PACK_DIR)/telescope.nvim ]; then \
		git clone https://github.com/nvim-telescope/telescope.nvim $(LOCAL_PACK_DIR)/telescope.nvim; \
	fi

deps-plenary:
	@mkdir -p $(LOCAL_PACK_DIR)
	@if [ ! -d $(LOCAL_PACK_DIR)/plenary.nvim ]; then \
		git clone https://github.com/nvim-lua/plenary.nvim $(LOCAL_PACK_DIR)/plenary.nvim; \
	fi

test-qf:
	./scripts/test-plugin.sh

test-telescope: deps-telescope deps-plenary
	NVIM_GITHUB_CODESEARCH_USE_TELESCOPE=1 ./scripts/test-plugin.sh

test-snacks: deps-snacks
	NVIM_GITHUB_CODESEARCH_USE_SNACKS=1 ./scripts/test-plugin.sh
