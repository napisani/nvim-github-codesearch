local M = {}

M.defaults = {
  github_auth_token = nil,
  github_api_url = "https://api.github.com",
  use_telescope = false,
  use_snacks_picker = false,
  cache_dir = nil,
}

function M.resolve(user_config)
  local config = vim.tbl_deep_extend("force", {}, M.defaults, user_config or {})
  if not config.github_auth_token or config.github_auth_token == "" then
    config.github_auth_token = os.getenv("GITHUB_AUTH_TOKEN")
  end

  if not config.github_auth_token or config.github_auth_token == "" then
    return nil,
      "github api token not found. set GITHUB_AUTH_TOKEN or configure github_auth_token in setup(...)"
  end

  if not config.cache_dir or config.cache_dir == "" then
    config.cache_dir = vim.fn.stdpath("cache") .. "/nvim-github-codesearch"
  end

  return config
end

return M
