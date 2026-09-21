-- Read-only development checks. Run from the repository root with Lua 5.1.
-- This is a bounded Markdown file-target check, not a Markdown validator.
local Checker = {}
local SUCCESS = "\0REPOSITORY_CHECK_ENUMERATED\0"

function Checker.enumerate(openPipe)
  -- Lua 5.1 does not reliably expose a pipe's child exit status. Only Git
  -- success emits this NUL-delimited trailer; stderr remains visible.
  local command = "git rev-parse --show-prefix && git ls-files --cached -z"
    .. " && printf '\\0REPOSITORY_CHECK_ENUMERATED\\0'"
  local ok, pipe = pcall(openPipe or io.popen, command, "r")
  if not ok or not pipe then return nil, "cannot start Git tracked-file enumeration" end
  local readOK, output = pcall(pipe.read, pipe, "*a")
  pcall(pipe.close, pipe)
  if not readOK or type(output) ~= "string" or output:sub(-#SUCCESS) ~= SUCCESS then
    return nil, "Git tracked-file enumeration failed (run inside the repository)"
  end
  local prefix, entries = output:sub(1, -#SUCCESS - 1):match("^([^\n]*)\n(.*)$")
  if prefix ~= "" then return nil, "run repository checks from the repository root" end
  if entries == "" or entries:sub(-1) ~= "\0" then
    return nil, "Git returned no tracked files or an incomplete tracked-file list"
  end
  local paths = {}
  for path in entries:gmatch("([^%z]+)%z") do paths[#paths + 1] = path end
  return paths
end

local function blankCodeBlocks(text)
  local lines, fence, width = {}, nil, 0
  for line in (text .. "\n"):gmatch("(.-)\n") do
    local run, rest = line:match("^ ? ? ?([`~]+)(.*)$")
    local marker = run and run:sub(1, 1)
    local valid = run and #run >= 3 and run == marker:rep(#run)
    if fence then
      if valid and marker == fence and #run >= width and rest:match("^%s*$") then
        fence = nil
      end
      lines[#lines + 1] = ""
    elseif valid then
      fence, width = marker, #run
      lines[#lines + 1] = ""
    elseif line:match("^    ") or line:match("^\t") then
      lines[#lines + 1] = ""
    else
      lines[#lines + 1] = line
    end
  end
  return table.concat(lines, "\n")
end

local function skipCodeSpan(text, pos)
  local run = text:match("^`+", pos)
  local at = pos + #run
  while at <= #text do
    local first, last = text:find("`+", at)
    if not first then break end
    if last - first + 1 == #run then return last + 1 end
    at = last + 1
  end
  return pos + #run -- An unmatched delimiter is literal Markdown.
end

local function labelEnd(text, pos)
  local depth, at = 1, pos + 1
  while at <= #text do
    local c = text:sub(at, at)
    if c == "\\" then at = at + 2
    elseif c == "`" then at = skipCodeSpan(text, at)
    else
      if c == "[" then depth = depth + 1 end
      if c == "]" then depth = depth - 1 end
      if depth == 0 then return at end
      at = at + 1
    end
  end
end

local function skipSpace(text, at)
  while text:sub(at, at):match("%s") do at = at + 1 end
  return at
end

local function destination(text, at)
  at = skipSpace(text, at)
  local angled = text:sub(at, at) == "<"
  if angled then at = at + 1 end
  local chars, depth = {}, 0
  while at <= #text do
    local c, nextChar = text:sub(at, at), text:sub(at + 1, at + 1)
    if c == "\\" and nextChar:match("%p") then
      chars[#chars + 1], at = nextChar, at + 2
    elseif angled and c == ">" then
      return table.concat(chars), at + 1
    elseif angled and (c == "\n" or c == "<") then
      return nil
    elseif not angled and (c:match("%s") or (c == ")" and depth == 0)) then
      return table.concat(chars), at
    else
      if not angled and c == "(" then depth = depth + 1 end
      if not angled and c == ")" then depth = depth - 1 end
      chars[#chars + 1], at = c, at + 1
    end
  end
  if not angled and depth == 0 then return table.concat(chars), at end
end

local function titleEnd(text, at)
  local quote = text:sub(at, at)
  if quote ~= '"' and quote ~= "'" and quote ~= "(" then return nil end
  local closing = quote == "(" and ")" or quote
  at = at + 1
  while at <= #text do
    local c = text:sub(at, at)
    if c == "\\" then at = at + 2
    elseif c == closing then return at + 1
    else at = at + 1 end
  end
end

local function inlineEnd(text, at)
  local beforeSpace = at
  at = skipSpace(text, at)
  if text:sub(at, at) == ")" then return at + 1 end
  local finish = at > beforeSpace and titleEnd(text, at)
  if finish then
    finish = skipSpace(text, finish)
    if text:sub(finish, finish) == ")" then return finish + 1 end
  end
end

local function skipHTML(text, at)
  if text:sub(at, at + 3) == "<!--" then
    local _, last = text:find("-->", at + 4, true)
    return last and last + 1 or #text + 1
  end
  local tag, rest = text:match("^<([%a][%w%-]*)([%s/>])", at)
  local closing = text:match("^</[%a][%w%-]*%s*>", at)
  if not tag and not closing then return at + 1 end
  local last, quote = at + 1, nil
  while last <= #text do
    local c = text:sub(last, last)
    if quote then
      if c == quote then quote = nil end
    elseif c == '"' or c == "'" then quote = c
    elseif c == ">" then break end
    last = last + 1
  end
  if last > #text then return #text + 1 end
  if tag and rest ~= "/" then
    local escapedTag = tag:lower():gsub("(%W)", "%%%1")
    local _, finish = text:lower():find("</" .. escapedTag .. "%s*>", last + 1)
    if finish then return finish + 1 end
    local blockTags = { div=true, table=true, pre=true, script=true, style=true, textarea=true }
    if blockTags[tag:lower()] then
      local _, blank = text:find("\n%s*\n", last + 1)
      return blank and blank + 1 or #text + 1
    end
  end
  return last + 1
end

function Checker.destinations(markdown)
  local text, links, at = blankCodeBlocks(markdown), {}, 1
  while at <= #text do
    local c = text:sub(at, at)
    if c == "\\" then at = at + 2
    elseif c == "`" then at = skipCodeSpan(text, at)
    elseif c == "<" then at = skipHTML(text, at)
    elseif c == "[" then
      local last = labelEnd(text, at)
      local target, finish, inline
      if last and text:sub(last + 1, last + 1) == "(" then
        inline = true
        local after
        target, after = destination(text, last + 2)
        if target then finish = inlineEnd(text, after) end
      elseif last and text:sub(last + 1, last + 1) == ":"
        and ("\n" .. text:sub(1, at - 1)):match("\n ? ? ?$") then
        target, finish = destination(text, last + 2)
        if finish then
          local title = skipSpace(text, finish)
          if title > finish then finish = titleEnd(text, title) or finish end
        end
      end
      if target and finish then
        local _, line = text:sub(1, at - 1):gsub("\n", "")
        -- An image inside a link label has its own destination. Do not lose
        -- it when advancing past the enclosing link and its optional title.
        if inline then
          for _, nested in ipairs(Checker.destinations(text:sub(at + 1, last - 1))) do
            links[#links + 1] = { target = nested.target, line = line + nested.line }
          end
        end
        links[#links + 1] = { target = target, line = line + 1 }
        at = finish
      else at = at + 1 end
    else at = at + 1 end
  end
  return links
end

local function resolve(document, target)
  if target:match("^[%a][%w+%.%-]*:") or target:sub(1, 2) == "//"
    or target:sub(1, 1) == "#" then return nil end
  target = target:match("^[^?#]*")
  if target == "" then return nil end -- Same-document/empty destination.
  if target:gsub("%%%x%x", ""):find("%%") then return nil, "malformed percent escape" end
  target = target:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
  if target:find("%z") or target:sub(1, 1) == "/" then
    return nil, "expected a repository-relative destination without NUL bytes"
  end
  local parts = {}
  local combined = (document:match("^(.*)/") or "") .. "/" .. target
  for part in combined:gmatch("[^/]+") do
    if part == ".." then
      if #parts == 0 then return nil, "destination escapes the repository" end
      parts[#parts] = nil
    elseif part ~= "." then parts[#parts + 1] = part end
  end
  return #parts == 0 and "." or table.concat(parts, "/")
end

local function readFile(path)
  local file, err = io.open(path, "rb")
  if not file then return nil, err end
  local data, readError = file:read("*a")
  file:close()
  return data, readError
end

local function exists(path)
  local file = io.open(path, "rb")
  if not file then return false end
  file:close()
  return true
end

function Checker.check(paths, read, present)
  read, present = read or readFile, present or exists
  local result = { lua = 0, markdown = 0, links = 0, errors = {} }
  local files, directories = {}, {}
  for _, path in ipairs(paths) do
    files[path], directories["."] = true, true
    for slash in path:gmatch("()/") do directories[path:sub(1, slash - 1)] = true end
  end
  local ordered = {}
  for path in pairs(files) do ordered[#ordered + 1] = path end
  table.sort(ordered)
  local function fail(message) result.errors[#result.errors + 1] = message end
  for _, path in ipairs(ordered) do
    local lua, markdown = path:match("%.lua$"), path:match("%.md$")
    if lua or markdown then
      local ok, data, err = pcall(read, path)
      if not ok or type(data) ~= "string" then
        fail(path .. ": cannot read tracked input: " .. tostring(ok and err or data))
      elseif lua then
        result.lua = result.lua + 1
        -- Match loadfile's shebang support while keeping reads injectable and
        -- never invoking the compiled chunk (including in synthetic tests).
        if data:sub(1, 1) == "#" then data = data:gsub("^[^\n]*", "", 1) end
        local chunk, syntaxError = loadstring(data, "@" .. path)
        if not chunk then fail(path .. ": Lua syntax: " .. tostring(syntaxError)) end
      else
        result.markdown = result.markdown + 1
        for _, link in ipairs(Checker.destinations(data)) do
          local target, why = resolve(path, link.target)
          if why then fail(path .. ":" .. link.line .. ": " .. link.target .. " — " .. why)
          elseif target then
            result.links = result.links + 1
            if not files[target] and not directories[target] then
              fail(path .. ":" .. link.line .. ": " .. link.target .. " -> " .. target .. " is not tracked")
            else
              local available, found = pcall(present, target)
              if not available or not found then
                fail(path .. ":" .. link.line .. ": " .. target .. " is not readable in the checkout")
              end
            end
          end
        end
      end
    end
  end
  if result.lua == 0 then fail("no readable tracked Lua files found") end
  if result.markdown == 0 then fail("no readable tracked Markdown files found") end
  return result
end

function Checker.main(enumerate, read, present, write)
  write = write or print
  local paths, err = (enumerate or Checker.enumerate)()
  if not paths then write("FAIL: " .. err); return 1 end
  local result = Checker.check(paths, read, present)
  for _, message in ipairs(result.errors) do write("FAIL: " .. message) end
  local success = #result.errors == 0
  write(string.format("%s: repository checks (%d tracked Lua, %d tracked Markdown, %d local targets)",
    success and "PASS" or "FAIL", result.lua, result.markdown, result.links))
  return success and 0 or 1
end

if ... == "scripts.check_repository" then return Checker end
os.exit(Checker.main())
