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

local read_to_str = function(file)
	local f = assert(io.open(file, "rb"))
	local content = f:read("*all")
	f:close()
	return content
end

---@param config Config the configuration object
M.setup = function(config)
	if not config then
		return
	end
	github_api_url = config.github_api_url or "https://api.github.com"
	github_auth_token = config.github_auth_token or os.getenv("GITHUB_AUTH_TOKEN")
	if not github_auth_token then
		error(
			"github api token not found. please set it in the config or in the GITHUB_AUTH_TOKEN environment variable or configure the github_auth_token when calling setup(...)"
		)
		return
	end
	lib_gh_search = require("libgithub_search")
end

local function select_with_native_ui(results)
	local names = {}
	for _, result_item in ipairs(results) do
		table.insert(names, result_item["result_entry_full_name"])
	end
	-- table.sort(names)
	vim.ui.select(names, { prompt = "Select github result: " }, function(selected)
		if selected then
			print(selected)
			-- M.set_current(selected)
		end
	end)
end

local search_cb_jump = function(self, bufnr, query)
  if not query then
    return
  end
  vim.api.nvim_buf_call(bufnr, function()
    pcall(vim.fn.matchdelete, self.state.hl_id, self.state.winid)
    vim.cmd "norm! gg"
    vim.fn.search(query, "W")
    vim.cmd "norm! zz"

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
						value = item.result_entry_full_name,
						ordinal = item.result_entry_full_name,
						display = item.result_entry_full_name,
						item = item
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
					-- local download_result = lib_gh_search.download({
					-- 	download_url = item.url,
					-- 	filename = item.name,
					-- 	token = github_auth_token,
					-- })
					-- if download_result == nil then
					-- 	error("an unknown error occurred while downloading file from github")
					-- 	return
					-- end
					-- if download_result["error"] ~= nil then
					-- 	error(results["error"])
					-- 	return
					-- end
					conf.buffer_previewer_maker(item.downloaded_local_path, self.state.bufnr, {
						bufname = self.state.bufname,
						callback = function(bufnr)
              
              search_cb_jump(self, bufnr, item.original_search_term)
						end,
					})
				end,
			}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					if selection then
						-- print(vim.inspect(selection))
						-- M.set_current(selection.value)
					end
				end)
				return true
			end,
		})
		:find()
end

M.search = function(query)
	local results = lib_gh_search.request_codesearch({
		query = query,
		token = github_auth_token,
		url = github_api_url,
	})
	if results == nil then
		error("an unknown error occurred while searching github code")
		return
	end
	if results["error"] ~= nil then
		error(results["error"])
		return
	end
	select_with_telescope(results)
	return results
	-- vim.ui.input({ prompt = 'Search GitHub code:' }, function(input)
	--   print(input)
	-- end)
end

return M
