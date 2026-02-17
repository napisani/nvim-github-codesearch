local MiniTest = require("mini.test")
local expect = MiniTest.expect

local T = MiniTest.new_set()

local child = MiniTest.new_child_neovim()

T["snacks picker"] = MiniTest.new_set({
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

T["snacks picker"]["is invoked with correct items when use_snacks_picker is true"] = function()
  local has_snacks = child.lua_get('pcall(require, "snacks")')
  if not has_snacks then
    return
  end

  child.lua([[
    local helpers = require("helpers")
    local snacks = require("snacks")

    _G._snacks_captured = nil
    local original_pick = snacks.picker.pick
    snacks.picker.pick = function(opts)
      _G._snacks_captured = {
        source = opts.source,
        item_count = opts.items and #opts.items or 0,
        has_format = opts.format ~= nil,
        has_confirm = opts.confirm ~= nil,
        items = {},
      }
      for _, item in ipairs(opts.items or {}) do
        table.insert(_G._snacks_captured.items, {
          text = item.text,
          file = item.file,
          _path = item._path,
        })
      end
    end

    local picker = require("nvim-github-codesearch.picker")
    local results, cache_dir = helpers.make_picker_results({ count = 3 })
    picker.pick(results, { use_telescope = false, use_snacks_picker = true })
    _G._test_cache_dir = cache_dir
  ]])

  local captured = child.lua_get("_G._snacks_captured")

  expect.equality(type(captured), "table")
  expect.equality(captured.source, "github-code-search")
  expect.equality(captured.item_count, 3)
  expect.equality(captured.has_format, true)
  expect.equality(captured.has_confirm, true)

  expect.equality(captured.items[1].text, "owner1/repo1: lua/file1.lua")
  expect.equality(captured.items[2].text, "owner2/repo2: lua/file2.lua")
  expect.equality(captured.items[3].text, "owner3/repo3: lua/file3.lua")

  expect.equality(captured.items[1]._path:find("hash1") ~= nil, true)
  expect.equality(captured.items[1].file:find("hash1") ~= nil, true)

  child.lua([[ require("helpers").cleanup_cache(_G._test_cache_dir) ]])
end

T["snacks picker"]["confirm callback opens correct path"] = function()
  local has_snacks = child.lua_get('pcall(require, "snacks")')
  if not has_snacks then
    return
  end

  child.lua([[
    local helpers = require("helpers")
    local snacks = require("snacks")

    _G._snacks_confirm_fn = nil
    _G._snacks_items = nil
    snacks.picker.pick = function(opts)
      _G._snacks_confirm_fn = opts.confirm
      _G._snacks_items = opts.items
    end

    local picker = require("nvim-github-codesearch.picker")
    local results, cache_dir = helpers.make_picker_results({ count = 1 })
    picker.pick(results, { use_telescope = false, use_snacks_picker = true })

    -- Simulate selecting the first item
    _G._snacks_confirm_fn(nil, _G._snacks_items[1])
    _G._opened_bufname = vim.fn.expand("%:p")
    _G._test_cache_dir = cache_dir
  ]])

  local opened = child.lua_get("_G._opened_bufname")

  expect.equality(opened:find("hash1") ~= nil, true)
  expect.equality(opened:find("file1.lua") ~= nil, true)

  child.lua([[ require("helpers").cleanup_cache(_G._test_cache_dir) ]])
end

T["snacks picker"]["falls back to quickfix when snacks not available"] = function()
  child.lua([[
    local helpers = require("helpers")

    package.loaded["snacks"] = nil
    package.preload["snacks"] = function() error("not found") end

    vim.notify = function() end

    package.loaded["nvim-github-codesearch.picker"] = nil
    local picker_mod = require("nvim-github-codesearch.picker")
    local results, cache_dir = helpers.make_picker_results({ count = 2 })
    picker_mod.pick(results, { use_telescope = false, use_snacks_picker = true })
    _G._qf_count = #vim.fn.getqflist()
    _G._test_cache_dir = cache_dir
  ]])

  expect.equality(child.lua_get("_G._qf_count"), 2)

  child.lua([[ require("helpers").cleanup_cache(_G._test_cache_dir) ]])
end

T["snacks picker"]["items with errors have no file path"] = function()
  local has_snacks = child.lua_get('pcall(require, "snacks")')
  if not has_snacks then
    return
  end

  child.lua([[
    local helpers = require("helpers")
    local snacks = require("snacks")

    _G._snacks_captured_items = {}
    snacks.picker.pick = function(opts)
      for _, item in ipairs(opts.items or {}) do
        table.insert(_G._snacks_captured_items, {
          text = item.text,
          file = item.file,
          has_error = item._error ~= nil,
        })
      end
    end

    local picker = require("nvim-github-codesearch.picker")
    local results = {
      {
        display_name = "org/repo: broken.lua",
        result_entry_full_name = "org/repo: broken.lua",
        downloaded_local_path = nil,
        error = "download failed",
      },
    }
    picker.pick(results, { use_telescope = false, use_snacks_picker = true })
  ]])

  local items = child.lua_get("_G._snacks_captured_items")

  expect.equality(#items, 1)
  expect.equality(items[1].text, "org/repo: broken.lua")
  expect.equality(items[1].file == nil or items[1].file == vim.NIL, true)
  expect.equality(items[1].has_error, true)
end

return T
