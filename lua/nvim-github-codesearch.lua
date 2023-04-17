local M = {}
---@class Config
---@field public github_auth_token string the github api token to use for each request.
---@field public github_api_url string the base url to use for github api requests. the default is "https://api.github.com"
---@field public use_telescope boolean whether to use telescope for user interaction or not. the default is false.
local Config = {}

local github_auth_token
local github_api_url
local use_telescope = false
local lib_gh_search = require("libgithub_search")

---@param config Config the configuration object
M.setup = function(config)
  if not config then
    return
  end
  github_api_url = config.github_api_url or "https://api.github.com"
  github_auth_token = config.github_auth_token or os.getenv("GITHUB_AUTH_TOKEN")
  if config.use_telescope ~= nil then
    use_telescope = config.use_telescope
  end
  if not github_auth_token then
    error(
      "github api token not found. please set it in the config or in the GITHUB_AUTH_TOKEN environment variable or configure the github_auth_token when calling setup(...)"
    )
    return
  end
  lib_gh_search = require("libgithub_search")
end

local function result_item_to_qflist_entry(item)
  return {
    -- bufnr = entry.bufnr,
    filename = item.downloaded_local_path,
    lnum = 1,
    col = 1,
    text = item.result_entry_full_name,
  }
end
local function send_all_to_qf(results)
  local qf_entries = {}
  for _, result_item in ipairs(results) do
    table.insert(qf_entries, result_item_to_qflist_entry(result_item))
  end
  vim.fn.setqflist(qf_entries, ' ')
  local qf_title = string.format([[github results: (%s)]], 'term')
  vim.fn.setqflist({}, "a", { title = qf_title })
  vim.cmd("copen")
end
local telescope_search_cb_jump = function(self, bufnr, query)
  if not query then
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
local function notify(err, level_in)
  if err then
    if level_in == nil then
      level_in = "ERROR"
    end
    local level = vim.log.levels[level_in]
    vim.notify(err, level, {
      title = "nvim-github-codesearch",
    })
    return true
  end
  return false
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
-- search github for the given query. If use_telescope is true, use telescope to display results. 
-- Otherwise, display results in the quickfix list.
-- @param query string the search term + restrictions to use
M.search = function(query)
  local results = lib_gh_search.request_codesearch({
    query = query,
    token = github_auth_token,
    url = github_api_url,
  })
  if results == nil then
    notify("an unknown error occurred while searching github code")
    return
  end
  if results["error"] ~= nil then
    notify(results["error"])
    return
  end
  if use_telescope then
    select_with_telescope(results)
  else
    send_all_to_qf(results)
  end
  return results
end
-- prompt the user for a search term + restrictions. Then, search github and display results.
M.prompt = function()
  local input = vim.fn.input("Search GitHub code: ")
  if input == nil or input == "" then
    return
  end
  M.search(input)
end
-- clean up any tempfiles created by nvim-github-codesearch
M.cleanup = function()
  lib_gh_search.cleanup()
end

return M
