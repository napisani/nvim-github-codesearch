## nvim-github-codesearch

nvim-github-codesearch is a neovim plugin that allows you to submit searches against the Github Code Search API and display the results within neovim. The results can be displayed either as a quickfix list or within Telescope (telescope is entirely optional).

### Demo
![Demo](https://github.com/napisani/nvim-github-codesearch/blob/main/demo.gif)

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
  github_api_url = "https://api.github.com",

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

## What to enter into the prompt

the text that is captured from the prompt will get parsed and urlencoded, then sent directly to the Github code search API.

The first part of the query is just the search terms, followed by key-value pairs of restrictions. 
IE: 

`join_all language:rust`

`System.out.println user:napisani in:readme`

Acceptable search terms are well documented here:
https://docs.github.com/en/rest/search?apiVersion=2022-11-28#search-code



## Dependencies

As of right now, the current version nvim-github-codesearch assumes that the machine its being installed on already has cargo/rust installed and available on the PATH.
If you don't already have rust setup on your machine, please run the one-liner shell command available on the official rust docs to install it before installing nvim-github-codesearch:
https://www.rust-lang.org/tools/install
