local MiniTest = require("mini.test")
local expect = MiniTest.expect

local T = MiniTest.new_set()

local child = MiniTest.new_child_neovim()

T["quickfix picker"] = MiniTest.new_set({
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

T["quickfix picker"]["populates quickfix list with correct items"] = function()
  child.lua([[
    local helpers = require("helpers")
    local picker = require("nvim-github-codesearch.picker")
    local results, cache_dir = helpers.make_picker_results({ count = 3 })
    local config = { use_telescope = false, use_snacks_picker = false }
    picker.pick(results, config)
    _G._test_cache_dir = cache_dir

    local list = vim.fn.getqflist({ items = 1, title = 1, context = 1 })
    _G._qf_count = #list.items
    _G._qf_title = list.title
    _G._qf_context = list.context
    _G._qf_texts = vim.tbl_map(function(item) return item.text end, list.items)
    _G._qf_filenames = vim.tbl_map(function(item)
      return item.filename or vim.fn.bufname(item.bufnr)
    end, list.items)
  ]])

  expect.equality(child.lua_get("_G._qf_count"), 3)
  expect.equality(type(child.lua_get("_G._qf_title")), "string")
  expect.equality(child.lua_get("_G._qf_title"):find("github results") ~= nil, true)
  expect.equality(child.lua_get("_G._qf_context").source, "nvim-github-codesearch")

  local texts = child.lua_get("_G._qf_texts")
  expect.equality(texts[1], "owner1/repo1: lua/file1.lua")
  expect.equality(texts[2], "owner2/repo2: lua/file2.lua")
  expect.equality(texts[3], "owner3/repo3: lua/file3.lua")

  local filenames = child.lua_get("_G._qf_filenames")
  for _, fname in ipairs(filenames) do
    expect.equality(fname:find("hash") ~= nil, true)
  end

  child.lua([[ require("helpers").cleanup_cache(_G._test_cache_dir) ]])
end

T["quickfix picker"]["handles empty results"] = function()
  child.lua([[
    local picker = require("nvim-github-codesearch.picker")
    picker.pick({}, { use_telescope = false, use_snacks_picker = false })
    _G._qf_count = #vim.fn.getqflist()
  ]])

  expect.equality(child.lua_get("_G._qf_count"), 0)
end

T["quickfix picker"]["items with errors still appear in list"] = function()
  child.lua([[
    local picker = require("nvim-github-codesearch.picker")
    local results = {
      {
        display_name = "org/repo: file.lua",
        result_entry_full_name = "org/repo: file.lua",
        downloaded_local_path = nil,
        error = "download failed",
      },
    }
    picker.pick(results, { use_telescope = false, use_snacks_picker = false })
    _G._qf_count = #vim.fn.getqflist()
  ]])

  expect.equality(child.lua_get("_G._qf_count"), 1)
end

return T
