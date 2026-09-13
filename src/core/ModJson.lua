-- Small strict JSON decoder for mod manifests. It has no filesystem or code
-- execution behavior and rejects duplicate object keys to keep manifests
-- deterministic across parsers.

local Json = {}
Json.NULL = {}

local function utf8(codepoint)
  assert(codepoint <= 0x10FFFF and not (codepoint >= 0xD800 and codepoint <= 0xDFFF),
    "invalid JSON unicode codepoint")
  if codepoint < 0x80 then return string.char(codepoint) end
  if codepoint < 0x800 then
    return string.char(0xC0 + math.floor(codepoint / 64), 0x80 + codepoint % 64)
  end
  if codepoint < 0x10000 then
    return string.char(0xE0 + math.floor(codepoint / 4096),
      0x80 + math.floor(codepoint / 64) % 64, 0x80 + codepoint % 64)
  end
  return string.char(0xF0 + math.floor(codepoint / 262144),
    0x80 + math.floor(codepoint / 4096) % 64,
    0x80 + math.floor(codepoint / 64) % 64, 0x80 + codepoint % 64)
end

function Json.decode(text)
  assert(type(text) == "string", "JSON input must be a string")
  local position, length = 1, #text
  local function fail(message) error(("JSON at byte %d: %s"):format(position, message), 0) end
  local function skipWhitespace()
    while position <= length and text:sub(position, position):match("%s") do position = position + 1 end
  end
  local function nextChar() return text:sub(position, position) end
  local function hex4()
    local value = text:sub(position, position + 3)
    if not value:match("^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$") then fail("invalid unicode escape") end
    position = position + 4
    return tonumber(value, 16)
  end
  local parseValue
  local function parseString()
    assert(nextChar() == '"')
    position = position + 1
    local out = {}
    while position <= length do
      local c = nextChar()
      if c == '"' then position = position + 1; return table.concat(out) end
      if c == "\\" then
        position = position + 1
        c = nextChar()
        local escapes = {['"']='"', ['\\']='\\', ['/']='/', b='\b', f='\f', n='\n', r='\r', t='\t'}
        if escapes[c] then out[#out + 1] = escapes[c]; position = position + 1
        elseif c == "u" then
          position = position + 1
          local codepoint = hex4()
          if codepoint >= 0xD800 and codepoint <= 0xDBFF then
            if text:sub(position, position + 1) ~= "\\u" then fail("unpaired unicode surrogate") end
            position = position + 2
            local low = hex4()
            if low < 0xDC00 or low > 0xDFFF then fail("unpaired unicode surrogate") end
            codepoint = 0x10000 + (codepoint - 0xD800) * 0x400 + low - 0xDC00
          elseif codepoint >= 0xDC00 and codepoint <= 0xDFFF then
            fail("unpaired unicode surrogate")
          end
          out[#out + 1] = utf8(codepoint)
        else fail("invalid string escape") end
      else
        if c == "" or c:byte() < 32 then fail("unterminated or control character in string") end
        out[#out + 1] = c
        position = position + 1
      end
    end
    fail("unterminated string")
  end
  local function parseNumber()
    local start = position
    if nextChar() == "-" then position = position + 1 end
    if nextChar() == "0" then position = position + 1
    elseif nextChar():match("[1-9]") then
      repeat position = position + 1 until not nextChar():match("%d")
    else fail("invalid number") end
    if nextChar() == "." then
      position = position + 1
      if not nextChar():match("%d") then fail("invalid fraction") end
      repeat position = position + 1 until not nextChar():match("%d")
    end
    if nextChar() == "e" or nextChar() == "E" then
      position = position + 1
      if nextChar() == "+" or nextChar() == "-" then position = position + 1 end
      if not nextChar():match("%d") then fail("invalid exponent") end
      repeat position = position + 1 until not nextChar():match("%d")
    end
    return tonumber(text:sub(start, position - 1))
  end
  local function parseArray()
    position = position + 1; skipWhitespace()
    local out = {}
    if nextChar() == "]" then position = position + 1; return out end
    while true do
      out[#out + 1] = parseValue(); skipWhitespace()
      if nextChar() == "]" then position = position + 1; return out end
      if nextChar() ~= "," then fail("expected , or ]") end
      position = position + 1; skipWhitespace()
    end
  end
  local function parseObject()
    position = position + 1; skipWhitespace()
    local out = {}
    if nextChar() == "}" then position = position + 1; return out end
    while true do
      if nextChar() ~= '"' then fail("expected object key") end
      local key = parseString(); skipWhitespace()
      if nextChar() ~= ":" then fail("expected :") end
      position = position + 1; skipWhitespace()
      if out[key] ~= nil then fail("duplicate object key " .. key) end
      out[key] = parseValue(); skipWhitespace()
      if nextChar() == "}" then position = position + 1; return out end
      if nextChar() ~= "," then fail("expected , or }") end
      position = position + 1; skipWhitespace()
    end
  end
  parseValue = function()
    skipWhitespace()
    local c = nextChar()
    if c == '"' then return parseString() end
    if c == "{" then return parseObject() end
    if c == "[" then return parseArray() end
    if c == "-" or c:match("%d") then return parseNumber() end
    if text:sub(position, position + 3) == "true" then position = position + 4; return true end
    if text:sub(position, position + 4) == "false" then position = position + 5; return false end
    if text:sub(position, position + 3) == "null" then position = position + 4; return Json.NULL end
    fail("expected JSON value")
  end
  local result = parseValue(); skipWhitespace()
  if position <= length then fail("trailing data") end
  return result
end

return Json
