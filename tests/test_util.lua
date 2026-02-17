local MiniTest = require("mini.test")
local expect = MiniTest.expect
local util = require("nvim-github-codesearch.util")

local T = MiniTest.new_set()

T["hash"] = MiniTest.new_set()

T["hash"]["returns a string"] = function()
  local result = util.hash("hello")
  expect.equality(type(result), "string")
end

T["hash"]["returns non-empty string"] = function()
  local result = util.hash("hello")
  expect.equality(result ~= "", true)
end

T["hash"]["returns consistent results for same input"] = function()
  local a = util.hash("test-value")
  local b = util.hash("test-value")
  expect.equality(a, b)
end

T["hash"]["returns different results for different input"] = function()
  local a = util.hash("value-one")
  local b = util.hash("value-two")
  expect.equality(a ~= b, true)
end

T["notify"] = MiniTest.new_set()

T["notify"]["returns false for nil message"] = function()
  local result = util.notify(nil)
  expect.equality(result, false)
end

T["notify"]["returns false for empty string"] = function()
  local result = util.notify("")
  expect.equality(result, false)
end

T["notify"]["returns true for valid message"] = function()
  -- Capture vim.notify to avoid test output noise
  local original = vim.notify
  local captured = {}
  vim.notify = function(msg, level, opts)
    captured.msg = msg
    captured.level = level
    captured.opts = opts
  end

  local result = util.notify("test error")
  expect.equality(result, true)
  expect.equality(captured.msg, "test error")

  vim.notify = original
end

T["notify"]["defaults to ERROR level"] = function()
  local original = vim.notify
  local captured = {}
  vim.notify = function(msg, level, opts)
    captured.level = level
  end

  util.notify("some error")
  expect.equality(captured.level, vim.log.levels.ERROR)

  vim.notify = original
end

T["notify"]["respects custom level"] = function()
  local original = vim.notify
  local captured = {}
  vim.notify = function(msg, level, opts)
    captured.level = level
  end

  util.notify("some warning", "WARN")
  expect.equality(captured.level, vim.log.levels.WARN)

  vim.notify = original
end

return T
