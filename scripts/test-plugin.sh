#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NVIM_BIN="${NVIM_BIN:-nvim}"

if ! command -v "$NVIM_BIN" >/dev/null 2>&1; then
	echo "Error: could not find neovim executable '$NVIM_BIN'. Set NVIM_BIN or adjust PATH." >&2
	exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
	echo "Error: curl is required to run GitHub requests." >&2
	exit 1
fi

if [ -z "${GITHUB_AUTH_TOKEN:-}" ]; then
	cat >&2 <<'EOF'
Warning: GITHUB_AUTH_TOKEN is not set. Requests to GitHub will fail until a token is provided.
EOF
fi

TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t nvim_github_codesearch)"
cleanup() {
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT

INIT_LUA="$TMP_DIR/init.lua"

cat >"$INIT_LUA" <<'EOF'
vim.g.mapleader = " "

local repo = vim.fn.expand("$NVIM_GITHUB_CODESEARCH_DEV_REPO")
vim.opt.runtimepath:append(repo)

local ok, plugin = pcall(require, "nvim-github-codesearch")
if not ok then
  vim.notify("Failed to require nvim-github-codesearch from " .. repo, vim.log.levels.ERROR)
  return
end

local use_telescope = vim.env.NVIM_GITHUB_CODESEARCH_USE_TELESCOPE == "1"
if use_telescope then
  local telescope_ok = pcall(require, "telescope")
  if not telescope_ok then
    vim.notify("Telescope not available; falling back to quickfix", vim.log.levels.WARN)
    use_telescope = false
  end
end

plugin.setup({
  github_auth_token = vim.env.GITHUB_AUTH_TOKEN,
  github_api_url = vim.env.NVIM_GITHUB_CODESEARCH_API_URL,
  use_telescope = use_telescope,
})

vim.api.nvim_create_user_command("GhSearchPrompt", function()
  plugin.prompt()
end, {})

vim.api.nvim_create_user_command("GhSearch", function(opts)
  if not opts.args or opts.args == "" then
    vim.notify("Provide a GitHub code search query", vim.log.levels.WARN)
    return
  end
  plugin.search(opts.args)
end, { nargs = "+" })

vim.keymap.set("n", "<leader>gp", plugin.prompt, { desc = "GitHub Code Search prompt" })
vim.keymap.set("n", "<leader>gs", function()
  local query = vim.fn.input("GitHub code query: ")
  if query ~= nil and query ~= "" then
    plugin.search(query)
  end
end, { desc = "GitHub Code Search query" })

vim.keymap.set("n", "<leader>gc", plugin.cleanup, { desc = "GitHub Code Search cleanup" })
EOF

export NVIM_GITHUB_CODESEARCH_DEV_REPO="$REPO_ROOT"

exec "$NVIM_BIN" --clean -u "$INIT_LUA" "$@"
