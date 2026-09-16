-- Run: lua5.1 tests/level_up_learnset_overlay_test.lua
package.path = package.path .. ";./?.lua"
local Learnset = require("import.LevelUpLearnset")
local Runtime = require("src.core.ModRuntime")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

local base = {{level=1, move=33, packed=545}, {level=10, move=39, packed=5159}}
local merged = Learnset.mergeAdditions(base, {{level=5, move=98}, {level=10, move=44}}, 354)
check("additions preserve decoded rows and sort by level",
  #merged == 4 and merged[1].move == 33 and merged[2].move == 98
    and merged[3].move == 39 and merged[4].move == 44)
check("merge does not mutate decoded base entries", #base == 2 and base[1].packed == 545)
check("duplicate addition fails closed", not pcall(Learnset.mergeAdditions, base, {{level=1, move=33}}, 354))
check("malformed addition fails closed", not pcall(Learnset.mergeAdditions, base, {{level=0, move=98}}, 354))
check("unsupported move id fails closed", not pcall(Learnset.mergeAdditions, base, {{level=5, move=355}}, 354))
check("sparse additions fail closed", not pcall(Learnset.mergeAdditions, base,
  {[2]={level=30, move=317}}, 354))

local files = {
  ["mods/learnset/manifest.json"] = '{"id":"learnset","version":"1.0.0","saveImpact":"gameplay"}',
  ["mods/learnset/init.lua"] = 'return function(mod) mod:content("battleLearnsetAdditions"):register(95, {{level=30, move=317}}) end',
}
local fs = {
  list=function() return {"learnset"} end,
  isDirectory=function(path) return path == "mods/learnset" end,
  read=function(path) return files[path] end,
}
local runtime = Runtime.new({namespaces={{name="battleLearnsetAdditions", options={semantics="record", base={}}}}})
local loaded, err = runtime:load(fs, "mods")
local additions = runtime:resolve("battleLearnsetAdditions")
local effective = Learnset.mergeAdditions(base, additions[95], 354)
check("headless mod runtime registers one species addition", loaded and additions[95]
  and additions[95][1].level == 30 and additions[95][1].move == 317, err)
check("registered addition reaches the common pure merge", #effective == 3 and effective[3].move == 317)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
