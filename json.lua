--[[
	Pulp demands all strings be double-quoted, so double-quotes cannot exist in the input unless escaped.
	Presumably these turn into non-escaped double-quotes.

	Arguments are comma-separated. Types are inferred.
	An argument which can be coerced into a number is a number.
	An argument which is 'true' or 'false' is a boolean.
	An argument which is 'nil' creates nil.
	An argument surrounded in unescaped double or single-quotes is considered a string.
	An argument surrounded in square or curly braces is json, to be coerced into a table.
	Any other argument is implicitly coerced into a string, for convenience.

  UPDATE: But actually, instead of any of that, the input is wrapped in square braces
  and treated as a JSON array.
--]]

-------------------------------------------------------------------------------
-- Modified JSON Decoder - Accepts single-quoted strings and 'nil' literals.
-- The following section shamelessly ripped out and modified from rxi/json.lua
-- https://github.com/rxi/json.lua
-------------------------------------------------------------------------------

--
-- json.lua
--
-- Copyright (c) 2020 rxi
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--

local json = {}

local escape_char_map = {
  [ "\\" ] = "\\",
  [ "\"" ] = "\"",
  [ "\'" ] = "\'",
  [ "\b" ] = "b",
  [ "\f" ] = "f",
  [ "\n" ] = "n",
  [ "\r" ] = "r",
  [ "\t" ] = "t",
}

local escape_char_map_inv = { [ "/" ] = "/" }
for k, v in pairs(escape_char_map) do
  escape_char_map_inv[v] = k
end


local function escape_char(c)
  return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
end

local parse

local function create_set(...)
  local res = {}
  for i = 1, select("#", ...) do
    res[ select(i, ...) ] = true
  end
  return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")
local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars  = create_set("\\", "/", '"', "'", "b", "f", "n", "r", "t", "u")
local literals      = create_set("true", "false", "null", "nil")

local literal_map = {
  [ "true"  ] = true,
  [ "false" ] = false,
  [ "null"  ] = nil,
  [ "nil"   ] = nil,
}


local function next_char(str, idx, set, negate)
  for i = idx, #str do
    if set[str:sub(i, i)] ~= negate then
      return i
    end
  end
  return #str + 1
end


local function decode_error(str, idx, msg)
  local line_count = 1
  local col_count = 1
  for i = 1, idx - 1 do
    col_count = col_count + 1
    if str:sub(i, i) == "\n" then
      line_count = line_count + 1
      col_count = 1
    end
  end
  error( string.format("%s at line %d col %d", msg, line_count, col_count) )
end


local function codepoint_to_utf8(n)
  -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
  local f = math.floor
  if n <= 0x7f then
    return string.char(n)
  elseif n <= 0x7ff then
    return string.char(f(n / 64) + 192, n % 64 + 128)
  elseif n <= 0xffff then
    return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
  elseif n <= 0x10ffff then
    return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
                       f(n % 4096 / 64) + 128, n % 64 + 128)
  end
  error( string.format("invalid unicode codepoint '%x'", n) )
end


local function parse_unicode_escape(s)
  local n1 = tonumber( s:sub(1, 4),  16 )
  local n2 = tonumber( s:sub(7, 10), 16 )
   -- Surrogate pair?
  if n2 then
    return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
  else
    return codepoint_to_utf8(n1)
  end
end


local function parse_string(str, i)
  local res = ""
  local j = i + 1
  local k = j

  while j <= #str do
    local x = str:byte(j)

    if x < 32 then
      decode_error(str, j, "control character in string")

    elseif x == 92 then -- `\`: Escape
      res = res .. str:sub(k, j - 1)
      j = j + 1
      local c = str:sub(j, j)
      if c == "u" then
        local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
                 or str:match("^%x%x%x%x", j + 1)
                 or decode_error(str, j - 1, "invalid unicode escape in string")
        res = res .. parse_unicode_escape(hex)
        j = j + #hex
      else
        if not escape_chars[c] then
          decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
        end
        res = res .. escape_char_map_inv[c]
      end
      k = j + 1

    elseif x == 34 then -- `"`: End of string
      res = res .. str:sub(k, j - 1)
      return res, j + 1
    end

    j = j + 1
  end

  decode_error(str, i, "expected closing quote for string")
end

local function parse_string_single(str, i)
  local res = ""
  local j = i + 1
  local k = j

  while j <= #str do
    local x = str:byte(j)

    if x < 32 then
      decode_error(str, j, "control character in string")

    elseif x == 92 then -- `\`: Escape
      res = res .. str:sub(k, j - 1)
      j = j + 1
      local c = str:sub(j, j)
      if c == "u" then
        local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
                 or str:match("^%x%x%x%x", j + 1)
                 or decode_error(str, j - 1, "invalid unicode escape in string")
        res = res .. parse_unicode_escape(hex)
        j = j + #hex
      else
        if not escape_chars[c] then
          decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
        end
        res = res .. escape_char_map_inv[c]
      end
      k = j + 1

    elseif x == 39 then -- `'`: End of string
      res = res .. str:sub(k, j - 1)
      return res, j + 1
    end

    j = j + 1
  end

  decode_error(str, i, "expected closing quote for string")
end


local function parse_number(str, i)
  local x = next_char(str, i, delim_chars)
  local s = str:sub(i, x - 1)
  local n = tonumber(s)
  if not n then
    decode_error(str, i, "invalid number '" .. s .. "'")
  end
  return n, x
end


local function parse_literal(str, i)
  local x = next_char(str, i, delim_chars)
  local word = str:sub(i, x - 1)
  if not literals[word] then
    decode_error(str, i, "invalid literal '" .. word .. "'")
  end
  return literal_map[word], x
end


local function parse_array(str, i)
  local res = {}
  local n = 1
  i = i + 1
  while 1 do
    local x
    i = next_char(str, i, space_chars, true)
    -- Empty / end of array?
    if str:sub(i, i) == "]" then
      i = i + 1
      break
    end
    -- Read token
    x, i = parse(str, i)
    res[n] = x
    n = n + 1
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "]" then break end
    if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
  end
  return res, i
end


local function parse_object(str, i)
  local res = {}
  i = i + 1
  while 1 do
    local key, val
    i = next_char(str, i, space_chars, true)
    -- Empty / end of object?
    if str:sub(i, i) == "}" then
      i = i + 1
      break
    end
    -- Read key
    if not (str:sub(i, i) == '"' or str:sub(i, i) == "'") then
      decode_error(str, i, "expected string for key")
    end
    key, i = parse(str, i)
    -- Read ':' delimiter
    i = next_char(str, i, space_chars, true)
    if str:sub(i, i) ~= ":" then
      decode_error(str, i, "expected ':' after key")
    end
    i = next_char(str, i + 1, space_chars, true)
    -- Read value
    val, i = parse(str, i)
    -- Set
    res[key] = val
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "}" then break end
    if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
  end
  return res, i
end


local char_func_map = {
  [ '"' ] = parse_string,
  [ "'" ] = parse_string_single,
  [ "0" ] = parse_number,
  [ "1" ] = parse_number,
  [ "2" ] = parse_number,
  [ "3" ] = parse_number,
  [ "4" ] = parse_number,
  [ "5" ] = parse_number,
  [ "6" ] = parse_number,
  [ "7" ] = parse_number,
  [ "8" ] = parse_number,
  [ "9" ] = parse_number,
  [ "-" ] = parse_number,
  [ "t" ] = parse_literal,
  [ "f" ] = parse_literal,
  [ "n" ] = parse_literal,
  [ "[" ] = parse_array,
  [ "{" ] = parse_object,
}


parse = function(str, idx)
  local chr = str:sub(idx, idx)
  local f = char_func_map[chr]
  if f then
    return f(str, idx)
  end
  decode_error(str, idx, "unexpected character '" .. chr .. "'")
end


function json.decode(str)
  if type(str) ~= "string" then
    error("expected argument of type string, got " .. type(str))
  end
  local res, idx = parse(str, next_char(str, 1, space_chars, true))
  idx = next_char(str, idx, space_chars, true)
  if idx <= #str then
    decode_error(str, idx, "trailing garbage")
  end
  return res
end

----------------------------------------------

-- Argument Decoder
-- End of rxi/json.lua

----------------------------------------------

-- I've decided this is stupid, but I don't want to get rid of it entirely.
--[[
local frontiers = {['['] = ']', ['{'] = '}', ["'"] = "'", ['"'] = '"'}
local function generate_arguments(input)
	-- print(input .. "\n---")
	local args = {}
	local in_long, bracket, cat = false, nil, {}
	for argument in string.gmatch(input, "([^,]*%s*),?") do
		-- print('|' .. argument .. '|')
		local c
		if not in_long then
			argument = argument:gsub("^%s+", "") -- Strip leading spaces.
			-- Capture comma-less strings and tables.
			if string.match(argument, "^%b''") or string.match(argument, '^%b""') then
				args[#args+1] = string.sub(argument, 2, -2)
				-- print('is string ' .. string.sub(argument, 2, -2))
				goto continue
			end
			if string.match(argument, "^%b{}") or string.match(argument, "^%b[]") then
				args[#args+1] = json.decode(argument)
				-- print('table construct ' .. argument)
				goto continue
			end
			-- Otherwise, check for opening frontier and let the state machine begin.
			c = argument:sub(1, 1)
			-- print("a: |" .. argument .. "| c: |" .. c .. "|")
			if frontiers[c] then
				-- print("tstart")
				in_long = true
				bracket = c
				cat[#cat+1] = argument
				goto continue
			end
		else
			-- If we're in the table, check for a matching trailing frontier.
			local arg2 = argument:gsub("%s+$", "") -- Strip trailing spaces for testing.
			c = arg2:sub(-1, -1)
			-- print("endc: |" .. c .. "| f: " .. frontiers[bracket])
			if c == frontiers[bracket] then
				if c == "'" or c == '"' then -- is a string
					cat[#cat+1] = arg2
					local farg = table.concat(cat, ",")
					-- print("long string: " .. farg)
					args[#args+1] = farg
				else -- is a json, parse
					cat[#cat+1] = arg2
					local jsontxt = table.concat(cat, ",")
					-- print("table construct: " .. jsontxt)
					local farg = json.decode(jsontxt)
					args[#args+1] = farg
				end
				in_long = false
				bracket = nil
				cat = {}
				goto continue
			else
				-- Middle of the state machine, keep going.
				cat[#cat+1] = argument
				goto continue
			end
		end
		-- We're outside the state machine now, in the land of simple matching.
		argument = argument:gsub("%s+$", "") -- Strip trailing spaces.
		if argument == '' then
			error("empty argument")
		elseif argument == 'true' then
			args[#args+1] = true
			-- print "istrue"
		elseif argument == 'false' then
			args[#args+1] = false
			-- print 'isfalse'
		elseif argument == 'nil' then
			args[#args+1] = nil
			-- print 'isnil'
		elseif tonumber(argument) then
			args[#args+1] = tonumber(argument)
			-- print 'isnumber'
		else
			-- print('default to string')
			args[#args+1] = argument
		end
		::continue:: -- Easiest way to skip all this while in the state machine.
	end
	if in_long then
		error("unclosed json or string")
	end
	-- print("---\n")
	return args
end
--]]

function json.getargs(input)
  local wrapped = "[" .. input .. "]"
  return json.decode(wrapped)
end

--[[
-- test stuff please ignore
local inspect = require "../inspect"

local tests = {
	"true, false, 1,     null , 3",
	-- "2, aa b  c ",
	"true, '1', \"aaa bbb cc ddd\"",
	"'str, ing', \"sbr, in,g  \", [1, 2, 3], {'a': 'ba, \\'n,a na'}",
	-- "{ }, aab\"ckd",
  "[1, [2, 3], 4]",
  "'string', 1.0, true, nil, [1, 2, 3], {'key': 'val'}"
}

for _, test in ipairs(tests) do print("val:\n" .. inspect(json.getargs(test)) .. "\n\n") end
--]]

return json