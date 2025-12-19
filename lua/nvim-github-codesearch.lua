---@diagnostic disable: undefined-global
local uv = vim.loop

local M = {}

---@class Config
---@field public github_auth_token string|nil the github api token to use for each request
---@field public github_api_url string|nil the base url to use for github api requests. defaults to "https://api.github.com"
---@field public use_telescope boolean|nil whether to use telescope for user interaction. defaults to false

local github_auth_token
local github_api_url = "https://api.github.com"
local use_telescope = false

local function trim(str)
  if vim.trim then
    return vim.trim(str)
  end
  return (str:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function urlencode(str)
  return str:gsub("\n", "\r\n"):gsub("([^%w _%-%./])", function(c)
    return string.format("%%%02X", string.byte(c))
  end):gsub(" ", "+")
end

local function parse_search_query(query)
  local term = query
  local restrictions = {}
  for key, value in query:gmatch("([%w-_]+):([^%s]+)") do
    restrictions[key] = value
  end
  local restriction_start = query:find("[%w-_]+:[^%s]+")
  if restriction_start then
    term = trim(query:sub(1, restriction_start - 1))
  end
  if term == "" then
    term = query
  end
  return {
    search_term = term,
    restrictions = restrictions,
  }
end

local function ensure_temp_dir()
  local base = uv.os_tmpdir() or vim.fn.stdpath("cache")
  local dir = base .. "/nvimghs"
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  return dir
end

local function get_temp_dir()
  local base = uv.os_tmpdir() or vim.fn.stdpath("cache")
  return base .. "/nvimghs"
end

local function cleanup_temp_files()
  local dir = get_temp_dir()
  if vim.fn.isdirectory(dir) == 1 then
    vim.fn.delete(dir, "rf")
  end
end

local function decode_json(payload)
  local decoder = vim.json and vim.json.decode or vim.fn.json_decode
  local ok, decoded
  if decoder == vim.fn.json_decode then
    ok, decoded = pcall(decoder, payload)
  else
    ok, decoded = pcall(decoder, payload, { luanil = { object = true, array = true } })
  end
  if not ok then
    return nil, decoded
  end
  return decoded, nil
end

local function read_file(path)
  local fd = assert(io.open(path, "rb"))
  local content = fd:read("*a")
  fd:close()
  return content
end

local function normalize_headers(status, body)
  local message = string.format("github request failed with status %s", status or "unknown")
  if body and body ~= "" then
    local decoded, decode_err = decode_json(body)
    if decoded and decoded.message then
      message = string.format("Github responded with an error: %s", decoded.message)
    elseif decode_err then
      message = decode_err
    end
  end
  return message
end

local function http_request(url, token, opts)
  opts = opts or {}
  local tmp_body = vim.fn.tempname()
  local tmp_headers = vim.fn.tempname()
  local cmd = { "curl", "--silent", "--show-error", "--location", "--dump-header", tmp_headers, "--output", tmp_body }
  local method = opts.method or "GET"
  table.insert(cmd, "--request")
  table.insert(cmd, method)
  local accept = opts.accept or (opts.raw and "application/vnd.github.raw" or "application/vnd.github+json")
  local headers = {
    { "Accept", accept },
    { "X-GitHub-Api-Version", "2022-11-28" },
    { "User-Agent", "nvim-github-codesearch" },
  }
  if token and token ~= "" then
    table.insert(headers, { "Authorization", string.format("Bearer %s", token) })
  end
  for _, header in ipairs(headers) do
    table.insert(cmd, "--header")
    table.insert(cmd, string.format("%s: %s", header[1], header[2]))
  end
  table.insert(cmd, url)
  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error
  local status
  local header_file = io.open(tmp_headers, "r")
  if header_file then
    for line in header_file:lines() do
      local matched = line:match("HTTP/%d%.%d%s+(%d+)")
      if matched then
        status = tonumber(matched)
      end
    end
    header_file:close()
  end
  local ok, body = pcall(read_file, tmp_body)
  vim.fn.delete(tmp_body)
  vim.fn.delete(tmp_headers)
  if not ok then
    return nil, body
  end
  if exit_code ~= 0 then
    local err_msg = trim(output) ~= "" and trim(output) or string.format("curl exited with code %d", exit_code)
    return nil, err_msg, status
  end
  if status and status >= 200 and status < 300 then
    return body, nil, status
  end
  local err = normalize_headers(status, opts.raw and nil or body)
  return nil, err, status
end

local function download_file(url, filename, token)
  local metadata_payload, metadata_err = http_request(url, token, { accept = "application/vnd.github+json" })
  if not metadata_payload then
    return nil, metadata_err
  end
  local metadata, decode_err = decode_json(metadata_payload)
  if not metadata then
    return nil, decode_err
  end
  if not metadata.download_url then
    return nil, "missing download_url in github response"
  end
  local content, download_err = http_request(metadata.download_url, token, { raw = true, accept = "application/vnd.github.raw" })
  if not content then
    return nil, download_err
  end
  local dir = ensure_temp_dir()
  local digest = vim.fn.sha256 and vim.fn.sha256(url) or tostring(math.abs(vim.loop.hrtime()))
  local safe_name = filename:gsub("[/\\]", "_")
  local temp_file_name = string.format("%s-%s", digest:sub(1, 12), safe_name)
  local path = dir .. "/" .. temp_file_name
  if uv.fs_stat(path) then
    return path
  end
  local file, file_err = io.open(path, "wb")
  if not file then
    return nil, file_err
  end
  file:write(content)
  file:close()
  return path
end

local function request_codesearch(query, url, token)
  local encoded_query = urlencode(query)
  local full_url = string.format("%s/search/code?q=%s", url, encoded_query)
  local payload, err = http_request(full_url, token, { accept = "application/vnd.github+json" })
  if not payload then
    return nil, err
  end
  return decode_json(payload)
end

local function notify(message, level_in)
  if not message then
    return false
  end
  local level = vim.log.levels[level_in or "ERROR"]
  vim.notify(message, level, { title = "nvim-github-codesearch" })
  return true
end

local function ensure_requirements()
  if vim.fn.executable("curl") == 0 then
    return nil, "curl executable not found. please install curl to use nvim-github-codesearch"
  end
  if not github_auth_token or github_auth_token == "" then
    github_auth_token = vim.env.GITHUB_AUTH_TOKEN
  end
  if not github_auth_token or github_auth_token == "" then
    return nil, "github api token not found. set it via setup() or GITHUB_AUTH_TOKEN"
  end
  return true
end

local function build_results(query, token)
  local parsed_query = parse_search_query(query)
  local raw_results, err = request_codesearch(query, github_api_url, token)
  if not raw_results then
    return nil, err
  end
  local items = raw_results.items or {}
  local results = {}
  for _, item in ipairs(items) do
    local entry = {
      name = item.name,
      path = item.path,
      sha = item.sha,
      url = item.url,
      git_url = item.git_url,
      html_url = item.html_url,
      score = item.score,
      repository = item.repository,
      original_search_term = parsed_query.search_term,
      result_entry_full_name = string.format("%s: %s", item.repository.full_name, item.path),
    }
    local file_path, download_err = download_file(item.url, item.name, token)
    if download_err then
      entry.error = download_err
    else
      entry.downloaded_local_path = file_path
    end
    table.insert(results, entry)
  end
  return results, nil
end

local function result_item_to_qflist_entry(item)
  return {
    filename = item.downloaded_local_path,
    lnum = 1,
    col = 1,
    text = item.result_entry_full_name,
  }
end

local function send_all_to_qf(results, query)
  local qf_entries = {}
  for _, result_item in ipairs(results) do
    if result_item.downloaded_local_path then
      table.insert(qf_entries, result_item_to_qflist_entry(result_item))
    end
  end
  if #qf_entries == 0 then
    notify("no downloadable results returned from github", "WARN")
    return
  end
  vim.fn.setqflist(qf_entries, ' ')
  local qf_title = string.format([[github results: (%s)]], query)
  vim.fn.setqflist({}, "a", { title = qf_title })
  vim.cmd("copen")
end

local function telescope_search_cb_jump(self, bufnr, query)
  if not query or query == "" then
    return
  end
  vim.api.nvim_buf_call(bufnr, function()
    pcall(vim.fn.matchdelete, self.state.hl_id, self.state.winid)
    vim.cmd("norm! gg")
    vim.fn.search(query, "W")
    vim.cmd("norm! zz")
    self.state.hl_id = vim.fn.matchadd("TelescopePreviewMatch", query)
  end)
end

local function select_with_telescope(results)
  local pickers = require("telescope.pickers")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  pickers
    .new({}, {
      prompt_title = "Select github search result: ",
      finder = finders.new_table({
        results = results,
        entry_maker = function(item)
          return {
            value = item.downloaded_local_path,
            text = item.result_entry_full_name,
            ordinal = item.result_entry_full_name,
            display = item.result_entry_full_name,
            item = item,
          }
        end,
      }),
      sorter = conf.file_sorter({}),
      previewer = previewers.new_buffer_previewer({
        title = "Results",
        define_preview = function(self, entry)
          if not entry or not entry.item then
            return
          end
          local item = entry.item
          if item["error"] ~= nil then
            notify(item["error"])
            return
          end
          conf.buffer_previewer_maker(item.downloaded_local_path, self.state.bufnr, {
            bufname = self.state.bufname,
            callback = function(bufnr)
              telescope_search_cb_jump(self, bufnr, item.original_search_term)
            end,
          })
        end,
      }),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            if selection.item["error"] ~= nil then
              notify(selection.item["error"])
              return
            end
            vim.cmd(":edit " .. selection.item.downloaded_local_path)
          end
        end)
        return true
      end,
    })
    :find()
end

function M.setup(config)
  config = config or {}
  if config.github_api_url then
    github_api_url = config.github_api_url
  end
  if config.github_auth_token ~= nil then
    github_auth_token = config.github_auth_token
  end
  if config.use_telescope ~= nil then
    use_telescope = config.use_telescope
  end
  if not github_auth_token or github_auth_token == "" then
    github_auth_token = vim.env.GITHUB_AUTH_TOKEN
  end
  local deps_ok, deps_err = ensure_requirements()
  if not deps_ok then
    error(deps_err)
  end
end

function M.search(query)
  if not query or query == "" then
    notify("please provide a query to search")
    return
  end
  local deps_ok, deps_err = ensure_requirements()
  if not deps_ok then
    notify(deps_err)
    return
  end
  local results, err = build_results(query, github_auth_token)
  if not results then
    notify(err)
    return
  end
  if use_telescope then
    select_with_telescope(results)
  else
    send_all_to_qf(results, query)
  end
  return results
end

function M.prompt()
  local input = vim.fn.input("Search GitHub code: ")
  if not input or input == "" then
    return
  end
  M.search(input)
end

function M.cleanup()
  cleanup_temp_files()
end

return M
