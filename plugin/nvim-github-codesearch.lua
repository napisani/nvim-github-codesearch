vim.api.nvim_create_user_command("GhSearch", function(opts)
  local query = opts.args
  if not query or query == "" then
    vim.notify("Provide a GitHub code search query", vim.log.levels.WARN)
    return
  end
  require("nvim-github-codesearch").search(query)
end, { nargs = "+" })

vim.api.nvim_create_user_command("GhSearchPrompt", function()
  require("nvim-github-codesearch").prompt()
end, {})

vim.api.nvim_create_user_command("GhSearchCleanup", function()
  require("nvim-github-codesearch").cleanup()
end, {})
