-- Synthetic in-memory files only: no user files, shell, network or temp data.
package.path = package.path .. ";./?.lua"
local Checker = require("scripts.check_repository")
local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1
  else failed = failed + 1; print("FAIL: " .. name .. " -- " .. tostring(detail)) end
end
local function fixture(markdown, extra, missing)
  local files = { ["main.lua"] = "return 42", ["docs/readme.md"] = markdown,
    ["README.md"] = "Project", ["docs/other.md"] = "Other", ["docs/a b.txt"] = "ok",
    ["docs/a(b).txt"] = "ok", ["docs/hash#mark.txt"] = "ok" }
  for path, data in pairs(extra or {}) do files[path] = data end
  local paths = {}
  for path in pairs(files) do paths[#paths + 1] = path end
  local function read(path) return files[path], "synthetic read error" end
  local function present(path)
    if path == missing then return false end
    return files[path] ~= nil or path == "docs" or path == "." or path == "untracked.txt"
  end
  return paths, read, present
end
local function verify(name, markdown, expectedLinks, extra)
  local result = Checker.check(fixture(markdown, extra))
  check(name, #result.errors == 0 and result.links == expectedLinks,
    table.concat(result.errors, "; ") .. " links=" .. result.links)
  return result
end
local function rejects(name, markdown, expected, extra, missing)
  local result = Checker.check(fixture(markdown, extra, missing))
  local errors = table.concat(result.errors, "\n")
  check(name, #result.errors > 0 and errors:find(expected, 1, true) ~= nil, errors)
end

local initial = verify("valid Lua and document-relative links",
  "[other](other.md) [root](../README.md) [dir](../docs/) [repo](..)", 4)
check("dynamic file counts", initial.lua == 1 and initial.markdown == 3)
verify("images and reference definitions", "![image](a%20b.txt)\n[ref]: other.md\n[use][ref]", 2)
verify("linked images retain both destinations", "[![alt](a%20b.txt)](other.md)", 2)
verify("reference titles are not link destinations",
  '[ref]: other.md "[example](missing.md)"\n[ok](other.md)', 2)
verify("angle destinations, titles and multiline links",
  "[one](<a b.txt> \"title\")\n[two](\nother.md\n)\n[ref]:\n  <other.md> 'title'", 3)
verify("query, fragments and percent-encoded literal hash",
  "[a](other.md?q=1#heading) [b](hash%23mark.txt) [c](a%20b.txt?ignored#ignored)", 3)
verify("parentheses and Markdown escapes",
  "[a](a(b).txt) [b](a\\(b\\).txt) [nested [label]](other.md)", 3)
verify("backticks in link labels", "[`other.md`](other.md)", 1)
verify("normalization", "[a](./../docs/./other.md) [b](%2E%2E/README.md)", 2)
verify("external/same-document targets excluded",
  "[a](https://invalid.example/no-request) [b](MAILTO:x@y.invalid) [c](//invalid.example/x)"
    .. " [d](#absent-heading) [e]() [f](?query)", 0)
verify("bare and inline-code paths excluded",
  "missing.md `missing.md` `[x](missing.md)` ``[x](missing.md) ` text``", 0)
verify("escaped Markdown opener is not a link", "\\[literal](missing.md)", 0)
verify("fenced code, wider fences and tilde fences excluded",
  "````lua\n[x](missing.md)\n```\n[y](missing.md)\n````\n"
    .. "~~~\n[z](missing.md)\n~~~\n[ok](other.md)", 1)
verify("indented code excluded", "    [x](missing.md)\n\t[y](missing.md)\n[ok](other.md)", 1)
verify("HTML tags, attributes, comments and blocks excluded",
  '<img src="missing.md">\n<!-- [x](missing.md) -->\n<div>\n[x](missing.md)\n</div>\n'
    .. '<span title="[x](missing.md)">[y](missing.md)</span>\n[ok](other.md)', 1)
verify("HTML attribute quote protects angle bracket",
  '<img alt="> [example](missing.md)"> [ok](other.md)', 1)
rejects("missing target fails with document and line", "intro\n[x](missing.md)", "docs/readme.md:2:")
rejects("existing untracked file cannot satisfy target", "[x](../untracked.txt)", "untracked.txt is not tracked")
rejects("directory must contain tracked descendants", "[x](empty-dir/)", "empty-dir is not tracked")
rejects("tracked but absent target fails", "[x](a%20b.txt)", "not readable in the checkout", nil, "docs/a b.txt")
rejects("absolute local path fails", "[x](/README.md)", "repository-relative")
rejects("escape above repository fails", "[x](../../outside.md)", "escapes the repository")
rejects("malformed percent escape fails", "[x](a%2.txt)", "malformed percent escape")
rejects("encoded NUL fails", "[x](a%00.txt)", "without NUL")
rejects("missing reference destination fails", "[ref]: missing.md\n[use][ref]", "is not tracked")
rejects("missing linked image fails", "[![alt](missing.md)](other.md)", "missing.md is not tracked")
rejects("invalid Lua fails with path", "Project", "broken.lua: Lua syntax", { ["broken.lua"] = "local =" })

_G.repositoryCheckerChunkExecuted = nil
local parsed = verify("compiled chunks never execute", "Project", 0,
  { ["probe.lua"] = "_G.repositoryCheckerChunkExecuted = true; error('must not run')" })
check("parse has no runtime side effect", _G.repositoryCheckerChunkExecuted == nil and parsed.lua == 2)
verify("Lua shebang parsing", "Project", 0, { ["cli.lua"] = "#!/usr/bin/env lua5.1\nreturn 1" })

local paths, read, present = fixture("Project")
local unreadable = Checker.check(paths, function(path)
  if path == "main.lua" then return nil, "permission denied" end
  return read(path)
end, present)
check("unreadable tracked source cannot pass", table.concat(unreadable.errors, "\n"):find("main.lua: cannot read", 1, true))
local unreadableDoc = Checker.check(paths, function(path)
  if path == "docs/readme.md" then error("read failure") end
  return read(path)
end, present)
check("thrown document read error cannot pass", table.concat(unreadableDoc.errors, "\n"):find("docs/readme.md: cannot read", 1, true))
check("empty tracked tree cannot pass", #Checker.check({}, read, present).errors > 0)

local function pipe(output)
  return function() return { read = function() return output end, close = function() return true end } end
end
local trailer = "\0REPOSITORY_CHECK_ENUMERATED\0"
local enumerated = Checker.enumerate(pipe("\nmain.lua\0docs/a b.md\0" .. trailer))
check("NUL-separated enumeration preserves spaces", enumerated and #enumerated == 2 and enumerated[2] == "docs/a b.md")
for _, output in ipairs({ "", "\nmain.lua\0", "\n" .. trailer,
  "\nmain.lua" .. trailer, "docs/\nmain.lua\0" .. trailer }) do
  local files = Checker.enumerate(pipe(output))
  check("failed/incomplete/empty/subdirectory enumeration is rejected", files == nil)
end
check("pipe launch failure is rejected", Checker.enumerate(function() error("unavailable") end) == nil)
check("pipe read failure is rejected", Checker.enumerate(function()
  return { read = function() error("read failed") end, close = function() return true end }
end) == nil)

local output = {}
local function write(line) output[#output + 1] = line end
check("CLI returns nonzero on enumeration error", Checker.main(function() return nil, "synthetic Git failure" end,
  read, present, write) == 1 and output[1]:find("synthetic Git failure", 1, true))
check("CLI returns success for valid tree", Checker.main(function() return paths end, read, present, write) == 0)
local badPaths, badRead, badPresent = fixture("[x](missing.md)")
check("CLI returns nonzero for link error", Checker.main(function() return badPaths end, badRead, badPresent, write) == 1)
local badLuaPaths, badLuaRead, badLuaPresent = fixture("Project", { ["bad.lua"] = "local =" })
check("CLI returns nonzero for syntax error", Checker.main(function() return badLuaPaths end, badLuaRead, badLuaPresent, write) == 1)
check("CLI reports exact failing path", table.concat(output, "\n"):find("bad.lua", 1, true))

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
