local M = {}

-- A fake search API response with two items
function M.make_search_response(opts)
  opts = opts or {}
  local items = opts.items or {
    {
      name = "init.lua",
      path = "lua/init.lua",
      sha = "abc123",
      url = "https://api.github.com/repos/org/repo/contents/lua/init.lua?ref=abc123",
      git_url = "https://api.github.com/repos/org/repo/git/blobs/abc123",
      html_url = "https://github.com/org/repo/blob/main/lua/init.lua",
      score = 1.0,
      repository = { full_name = "org/repo", name = "repo" },
    },
    {
      name = "utils.lua",
      path = "lua/utils.lua",
      sha = "def456",
      url = "https://api.github.com/repos/other/project/contents/lua/utils.lua?ref=def456",
      git_url = "https://api.github.com/repos/other/project/git/blobs/def456",
      html_url = "https://github.com/other/project/blob/main/lua/utils.lua",
      score = 0.8,
      repository = { full_name = "other/project", name = "project" },
    },
  }

  return {
    total_count = #items,
    incomplete_results = false,
    items = items,
  }
end

-- A fake download metadata response (the first curl call per item)
function M.make_download_meta_response(opts)
  opts = opts or {}
  return {
    download_url = opts.download_url or "https://raw.githubusercontent.com/org/repo/main/lua/init.lua",
  }
end

-- Build a curl-style stdout string: JSON body + newline + HTTP status
function M.curl_response(json_table, status)
  status = status or 200
  return vim.json.encode(json_table) .. "\n" .. tostring(status)
end

-- Build a run_cmd result table
function M.cmd_result(stdout, code, stderr)
  return { code = code or 0, stdout = stdout or "", stderr = stderr or "" }
end

-- A minimal resolved config for tests
function M.make_config(overrides)
  local config = {
    github_auth_token = "test-token-abc123",
    github_api_url = "https://api.github.com",
    use_telescope = false,
    use_snacks_picker = false,
    cache_dir = vim.fn.tempname() .. "/nvim-github-codesearch-test",
  }
  if overrides then
    config = vim.tbl_deep_extend("force", config, overrides)
  end
  return config
end

-- Build mock picker results (already processed, as init.lua would pass to picker.pick)
function M.make_picker_results(opts)
  opts = opts or {}
  local count = opts.count or 3
  local cache_dir = opts.cache_dir or "/tmp/nvim-ghs-test"

  vim.fn.mkdir(cache_dir, "p")

  local results = {}
  for i = 1, count do
    local filename = string.format("file%d.lua", i)
    local path = cache_dir .. "/hash" .. i .. "-" .. filename
    -- Create a real temp file so previews / buffer opens don't fail
    local f = io.open(path, "w")
    if f then
      f:write(string.format("-- sample file %d\nlocal x = %d\nreturn x\n", i, i))
      f:close()
    end

    table.insert(results, {
      name = filename,
      path = "lua/" .. filename,
      sha = "sha" .. i,
      url = "https://api.github.com/repos/owner" .. i .. "/repo" .. i .. "/contents/lua/" .. filename,
      git_url = "https://api.github.com/repos/owner" .. i .. "/repo" .. i .. "/git/blobs/sha" .. i,
      html_url = "https://github.com/owner" .. i .. "/repo" .. i .. "/blob/main/lua/" .. filename,
      score = 1.0 - (i * 0.1),
      original_search_term = "test query",
      result_entry_full_name = "owner" .. i .. "/repo" .. i .. ": lua/" .. filename,
      display_name = "owner" .. i .. "/repo" .. i .. ": lua/" .. filename,
      downloaded_local_path = path,
    })
  end

  return results, cache_dir
end

-- Cleanup a cache dir created by make_picker_results
function M.cleanup_cache(cache_dir)
  if cache_dir and vim.loop.fs_stat(cache_dir) then
    pcall(vim.fn.delete, cache_dir, "rf")
  end
end

return M
