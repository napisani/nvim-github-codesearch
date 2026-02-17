local MiniTest = require("mini.test")
local expect = MiniTest.expect

local T = MiniTest.new_set()

local child = MiniTest.new_child_neovim()

T["telescope picker"] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "tests/minimal_init.lua", "--headless" })
      child.lua([[
        vim.opt.runtimepath:prepend(".")
        package.path = "./tests/?.lua;./tests/?/init.lua;" .. package.path
      ]])
    end,
    post_case = function()
      child.stop()
    end,
  },
})

T["telescope picker"]["is invoked with correct data when use_telescope is true"] = function()
  local has_telescope = child.lua_get('pcall(require, "telescope")')
  if not has_telescope then
    return
  end

  child.lua([[
    local helpers = require("helpers")

    -- Intercept telescope.pickers.new to capture args
    _G._telescope_captured = nil
    local original_new = require("telescope.pickers").new
    require("telescope.pickers").new = function(opts, config)
      _G._telescope_captured = {
        prompt_title = config.prompt_title,
        has_finder = config.finder ~= nil,
        has_previewer = config.previewer ~= nil,
        has_sorter = config.sorter ~= nil,
      }
      return { find = function() end }
    end

    local picker = require("nvim-github-codesearch.picker")
    local results, cache_dir = helpers.make_picker_results({ count = 2 })
    picker.pick(results, { use_telescope = true, use_snacks_picker = false })
    _G._test_cache_dir = cache_dir
  ]])

  local captured = child.lua_get("_G._telescope_captured")

  expect.equality(type(captured), "table")
  expect.equality(type(captured.prompt_title), "string")
  expect.equality(captured.has_finder, true)
  expect.equality(captured.has_previewer, true)
  expect.equality(captured.has_sorter, true)

  child.lua([[ require("helpers").cleanup_cache(_G._test_cache_dir) ]])
end

T["telescope picker"]["entry_maker produces correct display and value"] = function()
  local has_telescope = child.lua_get('pcall(require, "telescope")')
  if not has_telescope then
    return
  end

  child.lua([[
    local helpers = require("helpers")

    _G._telescope_entries = {}

    -- Reload everything so the stubs take effect
    package.loaded["nvim-github-codesearch.picker"] = nil
    package.loaded["nvim-github-codesearch.util"] = nil
    package.loaded["telescope.pickers"] = nil
    package.loaded["telescope.actions"] = nil
    package.loaded["telescope.actions.state"] = nil
    package.loaded["telescope.previewers"] = nil
    package.loaded["telescope.finders"] = nil
    package.loaded["telescope.config"] = nil

    -- Create fake telescope modules with stubs
    package.loaded["telescope.pickers"] = {
      new = function(opts, config)
        local results_data = config.finder.results
        for _, item in ipairs(results_data) do
          local entry = config.finder.entry_maker(item)
          table.insert(_G._telescope_entries, {
            display = type(entry.display) == "function" and "function" or entry.display,
            ordinal = entry.ordinal,
            value = entry.value,
          })
        end
        return { find = function() end }
      end,
    }
    package.loaded["telescope.actions"] = { select_default = { replace = function() end } }
    package.loaded["telescope.actions.state"] = { get_selected_entry = function() end }
    package.loaded["telescope.previewers"] = { new_buffer_previewer = function() return {} end }
    package.loaded["telescope.finders"] = {
      new_table = function(opts) return opts end,
    }
    package.loaded["telescope.config"] = { values = { file_sorter = function() return function() end end, buffer_previewer_maker = function() end } }

    local picker = require("nvim-github-codesearch.picker")
    local results, cache_dir = helpers.make_picker_results({ count = 2 })
    picker.pick(results, { use_telescope = true, use_snacks_picker = false })
    _G._test_cache_dir = cache_dir
  ]])

  local entries = child.lua_get("_G._telescope_entries")

  expect.equality(#entries, 2)
  expect.equality(entries[1].display, "owner1/repo1: lua/file1.lua")
  expect.equality(entries[1].ordinal, "owner1/repo1: lua/file1.lua")
  expect.equality(entries[1].value:find("hash1") ~= nil, true)
  expect.equality(entries[2].display, "owner2/repo2: lua/file2.lua")

  child.lua([[ require("helpers").cleanup_cache(_G._test_cache_dir) ]])
end

T["telescope picker"]["falls back to quickfix when telescope not available"] = function()
  child.lua([[
    local helpers = require("helpers")

    package.loaded["telescope"] = nil
    package.loaded["telescope.pickers"] = nil
    package.preload["telescope"] = function() error("not found") end
    package.preload["telescope.pickers"] = function() error("not found") end

    vim.notify = function() end

    -- Force reload picker so it doesn't have a cached telescope require
    package.loaded["nvim-github-codesearch.picker"] = nil
    local picker_mod = require("nvim-github-codesearch.picker")
    local results, cache_dir = helpers.make_picker_results({ count = 2 })
    picker_mod.pick(results, { use_telescope = true, use_snacks_picker = false })
    _G._qf_count = #vim.fn.getqflist()
    _G._test_cache_dir = cache_dir
  ]])

  expect.equality(child.lua_get("_G._qf_count"), 2)

  child.lua([[ require("helpers").cleanup_cache(_G._test_cache_dir) ]])
end

return T
