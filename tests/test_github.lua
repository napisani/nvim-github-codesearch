local MiniTest = require("mini.test")
local expect = MiniTest.expect
local helpers = require("helpers")

local T = MiniTest.new_set()

local github
local original_run_cmd
local call_log

local function setup()
  -- Force reload to get a clean module
  package.loaded["nvim-github-codesearch.github"] = nil
  github = require("nvim-github-codesearch.github")
  original_run_cmd = github._run_cmd
  call_log = {}
end

local function teardown()
  github._run_cmd = original_run_cmd
end

T["search"] = MiniTest.new_set({
  hooks = {
    pre_case = setup,
    post_case = teardown,
  },
})

T["search"]["returns parsed results with correct fields"] = function()
  local search_response = helpers.make_search_response()
  local download_meta = helpers.make_download_meta_response()
  local call_count = 0

  github._run_cmd = function(args)
    call_count = call_count + 1
    table.insert(call_log, args)

    -- First call: search API
    -- Subsequent odd calls: download metadata, even calls: actual file download
    local is_search = false
    for _, arg in ipairs(args) do
      if type(arg) == "string" and arg:find("/search/code") then
        is_search = true
        break
      end
    end

    if is_search then
      return helpers.cmd_result(helpers.curl_response(search_response))
    end

    -- Check if this is a download (has -o flag)
    local is_download = false
    for _, arg in ipairs(args) do
      if arg == "-o" then
        is_download = true
        break
      end
    end

    if is_download then
      -- Find the output path and write a dummy file
      for i, arg in ipairs(args) do
        if arg == "-o" and args[i + 1] then
          local f = io.open(args[i + 1], "w")
          if f then
            f:write("-- downloaded content\n")
            f:close()
          end
          break
        end
      end
      return helpers.cmd_result("200")
    end

    -- Otherwise it's a metadata fetch
    return helpers.cmd_result(helpers.curl_response(download_meta))
  end

  local config = helpers.make_config()
  local results, err = github.search("useState language:typescript", config)

  expect.equality(err, nil)
  expect.equality(type(results), "table")
  expect.equality(#results, 2)

  -- First result
  expect.equality(results[1].name, "init.lua")
  expect.equality(results[1].path, "lua/init.lua")
  expect.equality(results[1].display_name, "org/repo: lua/init.lua")
  expect.equality(results[1].original_search_term, "useState")
  expect.equality(type(results[1].downloaded_local_path), "string")

  -- Second result
  expect.equality(results[2].name, "utils.lua")
  expect.equality(results[2].display_name, "other/project: lua/utils.lua")

  -- Cleanup
  helpers.cleanup_cache(config.cache_dir)
end

T["search"]["formats display_name as owner/repo: path"] = function()
  local search_response = helpers.make_search_response({
    items = {
      {
        name = "main.go",
        path = "cmd/main.go",
        sha = "aaa",
        url = "https://api.github.com/repos/acme/tool/contents/cmd/main.go?ref=aaa",
        git_url = "https://api.github.com/repos/acme/tool/git/blobs/aaa",
        html_url = "https://github.com/acme/tool/blob/main/cmd/main.go",
        score = 1.0,
        repository = { full_name = "acme/tool", name = "tool" },
      },
    },
  })
  local download_meta = helpers.make_download_meta_response()

  github._run_cmd = function(args)
    for _, arg in ipairs(args) do
      if type(arg) == "string" and arg:find("/search/code") then
        return helpers.cmd_result(helpers.curl_response(search_response))
      end
    end
    local is_download = false
    for _, arg in ipairs(args) do
      if arg == "-o" then
        is_download = true
        break
      end
    end
    if is_download then
      for i, arg in ipairs(args) do
        if arg == "-o" and args[i + 1] then
          local f = io.open(args[i + 1], "w")
          if f then f:write("package main\n") f:close() end
          break
        end
      end
      return helpers.cmd_result("200")
    end
    return helpers.cmd_result(helpers.curl_response(download_meta))
  end

  local config = helpers.make_config()
  local results, err = github.search("main", config)

  expect.equality(err, nil)
  expect.equality(results[1].display_name, "acme/tool: cmd/main.go")
  expect.equality(results[1].result_entry_full_name, "acme/tool: cmd/main.go")

  helpers.cleanup_cache(config.cache_dir)
end

T["search"]["returns error on API error response"] = function()
  github._run_cmd = function()
    local error_body = { message = "Bad credentials" }
    return helpers.cmd_result(helpers.curl_response(error_body, 401))
  end

  local config = helpers.make_config()
  local results, err = github.search("test", config)

  expect.equality(results, nil)
  expect.equality(type(err), "string")
  expect.equality(err:find("Bad credentials") ~= nil, true)
end

T["search"]["returns error on malformed JSON"] = function()
  github._run_cmd = function()
    return helpers.cmd_result("not json at all\n200")
  end

  local config = helpers.make_config()
  local results, err = github.search("test", config)

  expect.equality(results, nil)
  expect.equality(type(err), "string")
end

T["search"]["returns error on curl failure"] = function()
  github._run_cmd = function()
    return helpers.cmd_result("", 7, "curl: (7) Failed to connect")
  end

  local config = helpers.make_config()
  local results, err = github.search("test", config)

  expect.equality(results, nil)
  expect.equality(type(err), "string")
  expect.equality(err:find("curl failed") ~= nil, true)
end

T["search"]["marks individual items with error on download failure"] = function()
  local search_response = helpers.make_search_response()
  local call_count = 0

  github._run_cmd = function(args)
    for _, arg in ipairs(args) do
      if type(arg) == "string" and arg:find("/search/code") then
        return helpers.cmd_result(helpers.curl_response(search_response))
      end
    end
    -- All download-related calls fail
    return helpers.cmd_result("", 7, "connection refused")
  end

  local config = helpers.make_config()
  local results, err = github.search("test", config)

  expect.equality(err, nil)
  expect.equality(#results, 2)
  -- Each item should have an error field
  expect.equality(type(results[1].error), "string")
  expect.equality(type(results[2].error), "string")

  helpers.cleanup_cache(config.cache_dir)
end

T["search"]["passes query parse error through"] = function()
  local config = helpers.make_config()
  local results, err = github.search("", config)

  expect.equality(results, nil)
  expect.equality(type(err), "string")
end

T["cleanup"] = MiniTest.new_set()

T["cleanup"]["removes cache directory"] = function()
  local dir = vim.fn.tempname() .. "/cleanup-test"
  vim.fn.mkdir(dir, "p")
  local f = io.open(dir .. "/test.txt", "w")
  if f then f:write("x") f:close() end

  expect.equality(vim.loop.fs_stat(dir) ~= nil, true)
  github.cleanup(dir)
  expect.equality(vim.loop.fs_stat(dir), nil)
end

T["cleanup"]["does not error on missing directory"] = function()
  -- Should not throw
  github.cleanup("/tmp/nonexistent-dir-" .. tostring(vim.loop.hrtime()))
end

return T
