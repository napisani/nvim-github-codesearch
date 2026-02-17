## nvim-github-codesearch

A pure Lua Neovim plugin that sends queries to the GitHub Code Search API and displays results in a quickfix list, Telescope, or snacks.nvim picker.

### Demo
![Demo](https://github.com/napisani/nvim-github-codesearch/blob/main/demo.gif)

### Features
- Search GitHub code directly from Neovim
- Display results in quickfix, Telescope, or snacks.nvim picker
- File preview with syntax highlighting for each result
- Downloads matching files into a local cache for previews and edits
- Pure Lua -- no build step required

### Requirements
- Neovim 0.9+
- `curl`
- A GitHub personal access token (set via `GITHUB_AUTH_TOKEN` env var or `github_auth_token` in `setup`)

Optional dependencies (only needed if you want to use them as a picker):
- [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) + [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (when `use_telescope = true`)
- [folke/snacks.nvim](https://github.com/folke/snacks.nvim) (when `use_snacks_picker = true`)

### Installation
Using [lazy.nvim](https://github.com/folke/lazy.nvim):
```lua
{ "napisani/nvim-github-codesearch" }
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):
```lua
use { "napisani/nvim-github-codesearch" }
```

### Configuration
```lua
local gh_search = require("nvim-github-codesearch")
gh_search.setup({
  -- GitHub personal access token. Falls back to GITHUB_AUTH_TOKEN env var if not set.
  github_auth_token = "<YOUR GITHUB TOKEN>",

  -- Base URL for the GitHub API (default: "https://api.github.com")
  github_api_url = "https://api.github.com",

  -- Use Telescope as the picker (requires telescope.nvim + plenary.nvim)
  use_telescope = false,

  -- Use snacks.nvim as the picker (requires snacks.nvim)
  use_snacks_picker = false,
})
```

When both `use_telescope` and `use_snacks_picker` are `false` (the default), results are shown in the quickfix list.

### Commands

| Command | Description |
|---------|-------------|
| `:GhSearch {query}` | Search GitHub code with the given query |
| `:GhSearchPrompt` | Open an input prompt, then search with the entered query |
| `:GhSearchCleanup` | Remove all cached files downloaded by the plugin |

### Lua API
```lua
local gh_search = require("nvim-github-codesearch")

-- Open an input prompt and search
gh_search.prompt()

-- Search directly with a query string
gh_search.search("join_all language:rust")

-- Remove cached files
gh_search.cleanup()
```

### Query format
The query string is sent directly to the GitHub Code Search API. Combine free-text terms with qualifier key-value pairs:

```
join_all language:rust
System.out.println user:napisani in:readme
```

Full list of supported qualifiers: https://docs.github.com/en/rest/search?apiVersion=2022-11-28#search-code

---

## Testing

All test infrastructure lives in the `tests/` directory and uses [mini.test](https://github.com/echasnovski/mini.test) as the test framework. Optional plugin dependencies are cloned automatically into `.local-plugins/` (gitignored) when you run test targets.

### Unit tests

Unit tests cover the pure-logic modules with no external dependencies:

| File | What it tests |
|------|---------------|
| `tests/test_query.lua` | Query string parsing -- extracting the search term from qualifier strings |
| `tests/test_config.lua` | Config resolution -- token priority, env var fallback, defaults |
| `tests/test_util.lua` | Utility functions -- hashing, notification helper |

Run them with:
```bash
make test-unit
```

### Integration tests

Integration tests verify the GitHub client (with HTTP stubbed via a replaceable `_run_cmd` function) and all three picker implementations. Picker tests spawn an isolated child Neovim process and assert on the data passed to each picker.

| File | What it tests |
|------|---------------|
| `tests/test_github.lua` | GitHub search + download with stubbed curl responses |
| `tests/test_picker_qf.lua` | Quickfix list population, display text, title |
| `tests/test_picker_telescope.lua` | Telescope picker invocation, entry_maker output, fallback |
| `tests/test_picker_snacks.lua` | Snacks picker invocation, item shape, confirm callback, fallback |

Run them with:
```bash
make test-integration
```

### Run all tests
```bash
make test
```

### Manual testing

Manual test targets launch Neovim with a clean runtimepath, the plugin loaded, and the chosen picker configured. Optional plugin dependencies are cloned automatically.

**Quickfix list (default picker):**
```bash
export GITHUB_AUTH_TOKEN=ghp_yourtoken
make test-qf
```

**Telescope picker:**
```bash
export GITHUB_AUTH_TOKEN=ghp_yourtoken
make test-telescope
```

**Snacks picker:**
```bash
export GITHUB_AUTH_TOKEN=ghp_yourtoken
make test-snacks
```

Once Neovim opens, run `:GhSearchPrompt` to enter a search query and verify the results are displayed in the configured picker. You can also run `:GhSearch <query>` directly.

Optional environment variables for manual testing:
- `NVIM_BIN` -- path to a specific Neovim binary
- `NVIM_GITHUB_CODESEARCH_API_URL` -- override the GitHub API URL
