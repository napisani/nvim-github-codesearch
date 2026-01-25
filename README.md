## nvim-github-codesearch

nvim-github-codesearch is a pure Lua Neovim plugin that sends queries to the GitHub Code Search API and shows results in quickfix or Telescope.

### Demo
![Demo](https://github.com/napisani/nvim-github-codesearch/blob/main/demo.gif)

### Features
- GitHub code search results in quickfix, Telescope, or snacks.nvim picker
- Downloads matching files into a local cache for previews and edits
- Simple Lua-only setup, no build step

### Requirements
- Neovim 0.9+
- `curl`
- A GitHub token (set `GITHUB_AUTH_TOKEN` or `github_auth_token` in `setup`)

Optional dependencies:
- `nvim-telescope/telescope.nvim` (when `use_telescope = true`)
- `folke/snacks.nvim` (when `use_snacks_picker = true`)

### Installation
Using `lazy.nvim`:
```lua
  { "napisani/nvim-github-codesearch" }
```

Using `packer`:
```lua
  use { "napisani/nvim-github-codesearch" }
```

### Configuration
```lua
local gh_search = require("nvim-github-codesearch")
gh_search.setup({
  github_auth_token = "<YOUR GITHUB TOKEN>",
  github_api_url = "https://api.github.com",
  use_telescope = false,
  use_snacks_picker = false,
})
```

### Commands
- `:GhSearch {query}`
- `:GhSearchPrompt`
- `:GhSearchCleanup`

### Usage
```lua
-- prompt for a query
gh_search.prompt()

-- search without prompting
gh_search.search("join_all language:rust")

-- clean cached files
gh_search.cleanup()
```

### Query format
The query string is passed directly to GitHub Code Search. You can combine free text with qualifiers:

`join_all language:rust`

`System.out.println user:napisani in:readme`

Docs: https://docs.github.com/en/rest/search?apiVersion=2022-11-28#search-code

### Local testing
Use the dev script to launch Neovim with a clean runtimepath:

```bash
export GITHUB_AUTH_TOKEN=ghp_yourtoken
scripts/test-plugin.sh
```

Optional env vars:
- `NVIM_BIN` to override the Neovim binary
- `NVIM_GITHUB_CODESEARCH_USE_TELESCOPE=1` to preview results in Telescope
- `NVIM_GITHUB_CODESEARCH_USE_SNACKS=1` to preview results in snacks.nvim
- `NVIM_GITHUB_CODESEARCH_API_URL` to override the API URL
