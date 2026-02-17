local MiniTest = require("mini.test")
local expect = MiniTest.expect
local query = require("nvim-github-codesearch.query")

local T = MiniTest.new_set()

T["parse_search_term"] = MiniTest.new_set()

T["parse_search_term"]["returns plain text query unchanged"] = function()
  local term, err = query.parse_search_term("useState")
  expect.equality(err, nil)
  expect.equality(term, "useState")
end

T["parse_search_term"]["returns multi-word query unchanged"] = function()
  local term, err = query.parse_search_term("foo bar baz")
  expect.equality(err, nil)
  expect.equality(term, "foo bar baz")
end

T["parse_search_term"]["extracts term before single qualifier"] = function()
  local term, err = query.parse_search_term("useState language:typescript")
  expect.equality(err, nil)
  expect.equality(term, "useState")
end

T["parse_search_term"]["extracts term before multiple qualifiers"] = function()
  local term, err = query.parse_search_term("foo bar language:rust user:napisani")
  expect.equality(err, nil)
  expect.equality(term, "foo bar")
end

T["parse_search_term"]["handles qualifier with hyphens"] = function()
  local term, err = query.parse_search_term("search term my-key:value")
  expect.equality(err, nil)
  expect.equality(term, "search term")
end

T["parse_search_term"]["returns error for nil input"] = function()
  local term, err = query.parse_search_term(nil)
  expect.equality(term, nil)
  expect.equality(type(err), "string")
end

T["parse_search_term"]["returns error for empty string"] = function()
  local term, err = query.parse_search_term("")
  expect.equality(term, nil)
  expect.equality(type(err), "string")
end

T["parse_search_term"]["trims whitespace from result"] = function()
  local term, err = query.parse_search_term("  hello world  ")
  expect.equality(err, nil)
  expect.equality(term, "hello world")
end

return T
