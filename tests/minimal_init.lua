-- Minimal init for running mini.test test suite
-- Usage: nvim --headless --noplugin -u tests/minimal_init.lua -c "lua MiniTest.run()"

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
local local_pack = root .. "/.local-plugins/pack/vendor/start"

-- Add plugin itself to rtp
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:append(root .. "/after")

-- Add tests/ to Lua path so helpers can be required
package.path = root .. "/tests/?.lua;" .. root .. "/tests/?/init.lua;" .. package.path

-- Add local-plugins packpath so mini.test, snacks, telescope, plenary are available
vim.opt.packpath:prepend(root .. "/.local-plugins")

-- Load all packs
vim.cmd("packloadall")

-- Setup mini.test
local ok, mini_test = pcall(require, "mini.test")
if not ok then
  vim.notify("mini.test not found. Run 'make deps-mini-test' first.", vim.log.levels.ERROR)
  vim.cmd("cquit 1")
  return
end

mini_test.setup()
