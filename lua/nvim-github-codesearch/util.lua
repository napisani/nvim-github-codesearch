local M = {}

function M.notify(message, level_in)
  if not message or message == "" then
    return false
  end
  local level = vim.log.levels[level_in or "ERROR"]
  vim.notify(message, level, { title = "nvim-github-codesearch" })
  return true
end

function M.hash(value)
  local ok, digest = pcall(vim.fn.sha256, value)
  if ok and digest and digest ~= "" then
    return digest
  end
  local fallback = tostring(vim.fn.localtime()) .. tostring(#value)
  return fallback
end

return M
