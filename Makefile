.PHONY: deps-snacks deps-telescope deps-plenary deps-mini-test \
       test-qf test-telescope test-snacks \
       test test-unit test-integration

LOCAL_PACK_DIR := .local-plugins/pack/vendor/start
NVIM_BIN ?= nvim
TEST_CMD := $(NVIM_BIN) --headless --noplugin -u tests/minimal_init.lua

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

deps-snacks:
	@mkdir -p $(LOCAL_PACK_DIR)
	@if [ ! -d $(LOCAL_PACK_DIR)/snacks.nvim ]; then \
		git clone --filter=blob:none https://github.com/folke/snacks.nvim $(LOCAL_PACK_DIR)/snacks.nvim; \
	fi

deps-telescope:
	@mkdir -p $(LOCAL_PACK_DIR)
	@if [ ! -d $(LOCAL_PACK_DIR)/telescope.nvim ]; then \
		git clone --filter=blob:none https://github.com/nvim-telescope/telescope.nvim $(LOCAL_PACK_DIR)/telescope.nvim; \
	fi

deps-plenary:
	@mkdir -p $(LOCAL_PACK_DIR)
	@if [ ! -d $(LOCAL_PACK_DIR)/plenary.nvim ]; then \
		git clone --filter=blob:none https://github.com/nvim-lua/plenary.nvim $(LOCAL_PACK_DIR)/plenary.nvim; \
	fi

deps-mini-test:
	@mkdir -p $(LOCAL_PACK_DIR)
	@if [ ! -d $(LOCAL_PACK_DIR)/mini.test ]; then \
		git clone --filter=blob:none https://github.com/echasnovski/mini.test $(LOCAL_PACK_DIR)/mini.test; \
	fi

# ---------------------------------------------------------------------------
# Manual interactive testing (opens Neovim with plugin loaded)
# ---------------------------------------------------------------------------

test-qf:
	./scripts/test-plugin.sh

test-telescope: deps-telescope deps-plenary
	NVIM_GITHUB_CODESEARCH_USE_TELESCOPE=1 ./scripts/test-plugin.sh

test-snacks: deps-snacks
	NVIM_GITHUB_CODESEARCH_USE_SNACKS=1 ./scripts/test-plugin.sh

# ---------------------------------------------------------------------------
# Automated test suite (mini.test)
# ---------------------------------------------------------------------------

test: test-unit test-integration

test-unit: deps-mini-test
	$(TEST_CMD) -c "lua MiniTest.run_file('tests/test_query.lua')"
	$(TEST_CMD) -c "lua MiniTest.run_file('tests/test_config.lua')"
	$(TEST_CMD) -c "lua MiniTest.run_file('tests/test_util.lua')"

test-integration: deps-mini-test deps-snacks deps-telescope deps-plenary
	$(TEST_CMD) -c "lua MiniTest.run_file('tests/test_github.lua')"
	$(TEST_CMD) -c "lua MiniTest.run_file('tests/test_picker_qf.lua')"
	$(TEST_CMD) -c "lua MiniTest.run_file('tests/test_picker_telescope.lua')"
	$(TEST_CMD) -c "lua MiniTest.run_file('tests/test_picker_snacks.lua')"
