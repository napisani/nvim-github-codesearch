local util = require("nvim-github-codesearch.util")

local M = {}

local function result_item_to_qflist_entry(item)
  return {
    filename = item.downloaded_local_path,
    lnum = 1,
    col = 1,
    text = item.result_entry_full_name,
  }
end

function M.quickfix(results)
  local qf_entries = {}
  for _, result_item in ipairs(results) do
    table.insert(qf_entries, result_item_to_qflist_entry(result_item))
  end
  vim.fn.setqflist(qf_entries, " ")
  local qf_title = string.format([[github results: (%s)]], "term")
  vim.fn.setqflist({}, "a", { title = qf_title })
  vim.cmd("copen")
end

local function telescope_search_cb_jump(self, bufnr, query)
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

function M.telescope(results)
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
          if item.error ~= nil then
            util.notify(item.error)
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
            if selection.item.error ~= nil then
              util.notify(selection.item.error)
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

return M
