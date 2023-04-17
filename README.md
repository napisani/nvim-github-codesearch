## nvim-github-codesearch

nvim-github-codesearch is a neovim plugin that allows you to submit searches against the Github Code Search API and display the results within neovim. The results can be displayed either as a quickfix list or within Telescope (telescope is entirely optional).

### Installation

Here is how to install nvim-github-codesearch using `packer`
```lua
  -- it is critical to have the 'run' key provided because this
  -- plugin is a combination of lua and rust, 
  -- with out this parameter the plugin will miss the compilation step entirely
  use {'napisani/nvim-github-codesearch', run = 'make'}
```

### Configuration + Usage
Here is how to setup this plugin:
```lua
gh_seach = require("nvim-github-codesearch")
gh_search.setup({
  -- an optional table entry to explicitly configure the API key to use for Github API requests.
  -- alternatively, you can configure this parameter by export an environment variable named "GITHUB_AUTH_TOKEN"
  github_auth_token = "<YOUR GITHUB API KEY>",

  -- this table entry is optional, if not provided "https://api.github.com" will be used by default
  -- otherwise this parameter can be used to configure a different Github API URL.
  github_api_url = "https://api.github.com"

  -- whether to use telescope to display the github search results or not
  use_telescope = false,
})

-- Usage

-- this will display a prompt to enter search terms
gh_search.prompt()

-- this will submit a search for the designated query without displaying a prompt
gh_search.search("some query")

-- removes any temp files created by nvim-github-codesearch
gh_search.cleanup()

```



