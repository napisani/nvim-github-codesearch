local query = require("nvim-github-codesearch.query")
local util = require("nvim-github-codesearch.util")

local M = {}

local function urlencode(value)
  return (value:gsub("([^%w%-%_%.%~])", function(char)
    return string.format("%%%02X", char:byte())
  end))
end

local function run_cmd(args)
  if vim.system then
    return vim.system(args, { text = true }):wait()
  end

  local stdout = vim.fn.system(args)
  local code = vim.v.shell_error
  return { code = code, stdout = stdout, stderr = "" }
end

local function build_headers(token)
  return {
    "Authorization: Bearer " .. token,
    "Accept: application/vnd.github+json",
    "X-GitHub-Api-Version: 2022-11-28",
    "User-Agent: nvim-github-codesearch",
  }
end

local function curl_json(url, headers)
  local args = { "curl", "-sS", "-L", "-w", "\n%{http_code}" }
  for _, header in ipairs(headers) do
    table.insert(args, "-H")
    table.insert(args, header)
  end
  table.insert(args, url)

  local result = run_cmd(args)
  if result.code ~= 0 then
    local err = result.stderr ~= "" and result.stderr or result.stdout
    return nil, "curl failed: " .. err
  end

  local body, status = result.stdout:match("^([%s%S]*)\n(%d%d%d)$")
  if not status then
    return nil, "failed to read http status from curl output"
  end

  local status_num = tonumber(status)
  if status_num and status_num >= 400 then
    local ok, payload = pcall(vim.json.decode, body)
    if ok and payload and payload.message then
      return nil, string.format("Github responded with an error: %s", payload.message)
    end
    return nil, string.format("Github responded with status %s", status)
  end

  local ok, payload = pcall(vim.json.decode, body)
  if not ok then
    return nil, "failed to parse github response"
  end

  return payload
end

local function ensure_cache_dir(cache_dir)
  vim.fn.mkdir(cache_dir, "p")
end

local function curl_download(url, headers, path)
  local args = { "curl", "-sS", "-L", "-o", path, "-w", "%{http_code}" }
  for _, header in ipairs(headers) do
    table.insert(args, "-H")
    table.insert(args, header)
  end
  table.insert(args, url)

  local result = run_cmd(args)
  if result.code ~= 0 then
    pcall(vim.loop.fs_unlink, path)
    local err = result.stderr ~= "" and result.stderr or result.stdout
    return nil, "curl failed: " .. err
  end

  local status = tonumber((result.stdout or ""):match("(%d%d%d)"))
  if status and status >= 400 then
    pcall(vim.loop.fs_unlink, path)
    return nil, string.format("Github responded with status %s", status)
  end

  return path
end

local function download_item(item, token, cache_dir)
  local headers = build_headers(token)
  local download_meta, err = curl_json(item.url, headers)
  if err then
    return nil, err
  end

  if not download_meta or not download_meta.download_url then
    return nil, "github response missing download_url"
  end

  ensure_cache_dir(cache_dir)
  local digest = util.hash(item.url)
  local filename = string.format("%s-%s", digest, item.name)
  local path = cache_dir .. "/" .. filename

  if vim.loop.fs_stat(path) then
    return path
  end

  return curl_download(download_meta.download_url, headers, path)
end

function M.cleanup(cache_dir)
  local target = cache_dir or (vim.fn.stdpath("cache") .. "/nvim-github-codesearch")
  if vim.loop.fs_stat(target) then
    pcall(vim.fn.delete, target, "rf")
  end
end

function M.search(query_string, config)
  local search_term, parse_error = query.parse_search_term(query_string)
  if parse_error then
    return nil, parse_error
  end

  local headers = build_headers(config.github_auth_token)
  local encoded = urlencode(query_string)
  local url = string.format("%s/search/code?q=%s", config.github_api_url, encoded)
  local payload, err = curl_json(url, headers)
  if err then
    return nil, err
  end

  if not payload or type(payload.items) ~= "table" then
    return nil, "github response missing results"
  end

  local results = {}
  for _, item in ipairs(payload.items) do
    local entry = {
      name = item.name,
      path = item.path,
      sha = item.sha,
      url = item.url,
      git_url = item.git_url,
      html_url = item.html_url,
      score = item.score,
      original_search_term = search_term,
      result_entry_full_name = string.format("%s: %s", item.repository.full_name, item.path),
    }

    local downloaded_path, download_error = download_item(item, config.github_auth_token, config.cache_dir)
    if download_error then
      entry.error = download_error
    else
      entry.downloaded_local_path = downloaded_path
    end

    table.insert(results, entry)
  end

  return results
end

return M
