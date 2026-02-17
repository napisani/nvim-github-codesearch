local MiniTest = require("mini.test")
local expect = MiniTest.expect
local config = require("nvim-github-codesearch.config")

local T = MiniTest.new_set()

T["resolve"] = MiniTest.new_set()

T["resolve"]["uses token from user config"] = function()
  local cfg, err = config.resolve({ github_auth_token = "my-token" })
  expect.equality(err, nil)
  expect.equality(cfg.github_auth_token, "my-token")
end

T["resolve"]["falls back to GITHUB_AUTH_TOKEN env var"] = function()
  local original = os.getenv("GITHUB_AUTH_TOKEN")
  vim.env.GITHUB_AUTH_TOKEN = "env-token"

  local cfg, err = config.resolve({})
  expect.equality(err, nil)
  expect.equality(cfg.github_auth_token, "env-token")

  -- Restore
  vim.env.GITHUB_AUTH_TOKEN = original
end

T["resolve"]["returns error when no token available"] = function()
  local original = os.getenv("GITHUB_AUTH_TOKEN")
  vim.env.GITHUB_AUTH_TOKEN = nil

  local cfg, err = config.resolve({})
  expect.equality(cfg, nil)
  expect.equality(type(err), "string")

  vim.env.GITHUB_AUTH_TOKEN = original
end

T["resolve"]["user config token takes priority over env var"] = function()
  local original = os.getenv("GITHUB_AUTH_TOKEN")
  vim.env.GITHUB_AUTH_TOKEN = "env-token"

  local cfg, err = config.resolve({ github_auth_token = "config-token" })
  expect.equality(err, nil)
  expect.equality(cfg.github_auth_token, "config-token")

  vim.env.GITHUB_AUTH_TOKEN = original
end

T["resolve"]["sets default github_api_url"] = function()
  local cfg = config.resolve({ github_auth_token = "t" })
  expect.equality(cfg.github_api_url, "https://api.github.com")
end

T["resolve"]["respects custom github_api_url"] = function()
  local cfg = config.resolve({ github_auth_token = "t", github_api_url = "https://custom.api" })
  expect.equality(cfg.github_api_url, "https://custom.api")
end

T["resolve"]["sets default cache_dir from stdpath"] = function()
  local cfg = config.resolve({ github_auth_token = "t" })
  local expected = vim.fn.stdpath("cache") .. "/nvim-github-codesearch"
  expect.equality(cfg.cache_dir, expected)
end

T["resolve"]["respects custom cache_dir"] = function()
  local cfg = config.resolve({ github_auth_token = "t", cache_dir = "/tmp/custom-cache" })
  expect.equality(cfg.cache_dir, "/tmp/custom-cache")
end

T["resolve"]["defaults use_telescope to false"] = function()
  local cfg = config.resolve({ github_auth_token = "t" })
  expect.equality(cfg.use_telescope, false)
end

T["resolve"]["defaults use_snacks_picker to false"] = function()
  local cfg = config.resolve({ github_auth_token = "t" })
  expect.equality(cfg.use_snacks_picker, false)
end

T["resolve"]["passes through use_telescope flag"] = function()
  local cfg = config.resolve({ github_auth_token = "t", use_telescope = true })
  expect.equality(cfg.use_telescope, true)
end

T["resolve"]["passes through use_snacks_picker flag"] = function()
  local cfg = config.resolve({ github_auth_token = "t", use_snacks_picker = true })
  expect.equality(cfg.use_snacks_picker, true)
end

return T
