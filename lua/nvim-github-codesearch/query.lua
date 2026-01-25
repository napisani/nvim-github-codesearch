local M = {}

local function trim(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.parse_search_term(query)
  if not query or query == "" then
    return nil, "search query is empty"
  end

  local term = query:match("^(.-)%s*[%w%-_]+:%S+")
  if not term or term == "" then
    term = query
  end

  term = trim(term)
  if term == "" then
    return nil, "failed to parse search term"
  end

  return term
end

return M
