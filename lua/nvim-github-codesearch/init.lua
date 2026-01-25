local config = require("nvim-github-codesearch.config")
local github = require("nvim-github-codesearch.github")
local picker = require("nvim-github-codesearch.picker")
local util = require("nvim-github-codesearch.util")

local M = {}
local resolved_config = nil

local function get_config()
  if resolved_config then
    return resolved_config
  end

  local cfg, err = config.resolve({})
  if err then
    util.notify(err)
    return nil, err
  end

  resolved_config = cfg
  return resolved_config
end

function M.setup(user_config)
  local cfg, err = config.resolve(user_config)
  if err then
    error(err)
  end
  resolved_config = cfg
end

function M.search(query)
  local cfg, err = get_config()
  if err then
    return nil
  end

  local results, search_error = github.search(query, cfg)
  if search_error then
    util.notify(search_error)
    return nil
  end

  picker.pick(results, cfg)

  return results
end

function M.prompt()
  local input = vim.fn.input("Search GitHub code: ")
  if not input or input == "" then
    return
  end
  return M.search(input)
end

function M.cleanup()
  local cfg = resolved_config
  if cfg then
    github.cleanup(cfg.cache_dir)
  else
    github.cleanup()
  end
end

return M
