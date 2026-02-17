local util = require("nvim-github-codesearch.util")

local M = {}

local function result_item_to_qflist_entry(item)
  return {
    filename = item.downloaded_local_path,
    lnum = 1,
    col = 1,
    text = item.display_name or item.result_entry_full_name,
  }
end

local function show_quickfix(results)
  local qf_entries = {}
  for _, result_item in ipairs(results) do
    table.insert(qf_entries, result_item_to_qflist_entry(result_item))
  end
  local qf_title = string.format([[github results: (%s)]], "term")
  vim.fn.setqflist({}, " ", {
    items = qf_entries,
    title = qf_title,
    context = { source = "nvim-github-codesearch" },
  })
  vim.o.quickfixtextfunc = "v:lua.require'nvim-github-codesearch.picker'.quickfix_textfunc"
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

local function show_telescope(results)
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
            text = item.display_name or item.result_entry_full_name,
            ordinal = item.display_name or item.result_entry_full_name,
            display = item.display_name or item.result_entry_full_name,
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

local function show_snacks(results)
  local snacks = require("snacks")
  local items = {}

  for idx, item in ipairs(results) do
    local entry = {
      text = tostring(item.display_name or item.result_entry_full_name or item.downloaded_local_path or ""),
      file = item.downloaded_local_path,
      _path = item.downloaded_local_path,
      _error = item.error,
      idx = idx,
    }

    table.insert(items, entry)
  end

  snacks.picker.pick({
    source = "github-code-search",
    items = items,
    format = function(entry)
      return { { entry.text or "" } }
    end,
    confirm = function(picker, selection)
      picker:close()
      if not selection then
        return
      end
      if selection._error then
        util.notify(selection._error)
        return
      end
      local path = selection._path or selection.file
      if path then
        vim.schedule(function()
          vim.cmd("edit " .. vim.fn.fnameescape(path))
        end)
      end
    end,
  })
end

local function format_default_qf_item(item)
  local filename = item.filename
  if (not filename or filename == "") and item.bufnr then
    filename = vim.fn.bufname(item.bufnr)
  end

  local lnum = tonumber(item.lnum or 0)
  local col = tonumber(item.col or 0)
  local text = item.text or ""

  if filename and filename ~= "" then
    if lnum > 0 then
      return string.format("%s|%d col %d|%s", filename, lnum, col, text)
    end
    return string.format("%s||%s", filename, text)
  end

  return text
end

function M.quickfix_textfunc(info)
  local list = vim.fn.getqflist({ id = info.id, items = 1, context = 1 })
  local context = list.context or {}
  local is_codesearch = context.source == "nvim-github-codesearch"
  local items = list.items or {}
  local lines = {}

  for i = info.start_idx, info.end_idx do
    local item = items[i]
    if not item then
      break
    end
    if is_codesearch then
      table.insert(lines, item.text or "")
    else
      table.insert(lines, format_default_qf_item(item))
    end
  end

  return lines
end

function M.pick(results, config)
  if config.use_snacks_picker then
    local ok = pcall(require, "snacks")
    if ok then
      show_snacks(results)
      return
    end
    util.notify("snacks.nvim not available; falling back to quickfix", "WARN")
  end

  if config.use_telescope then
    local ok = pcall(require, "telescope")
    if ok then
      show_telescope(results)
      return
    end
    util.notify("telescope not available; falling back to quickfix", "WARN")
  end

  show_quickfix(results)
end

return M
