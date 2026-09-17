-- Run: lua5.1 tests/pokemon_firered_balance_mod_test.lua
package.path = package.path .. ";./?.lua"
local Runtime = require("src.core.ModRuntime")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end
local function read(path)
  local handle = assert(io.open(path, "rb"))
  local value = handle:read("*a")
  handle:close()
  return value
end
local fs = {
  list=function() return {"pokemon-firered-balance"} end,
  isDirectory=function(path) return path == "mods/pokemon-firered-balance" end,
  read=read,
}
check("mod root contains no stale placeholder package directory",
  io.open("mods/examples/.gitkeep", "rb") == nil)
local moves = {}
for id = 0, 354 do moves[id] = {power=1, accuracy=100, pp=20, marker=id} end
local host = {namespaces={
  {name="battleMoves", options={semantics="deep", base=moves}},
  {name="battleLearnsetAdditions", options={semantics="record", base={}}},
}}
local validated, validationErr = Runtime.validate(fs, "mods", host)
check("actual package validates against complete declared host", validated ~= nil, validationErr)
local runtime = Runtime.new(host)
local loaded, loadErr = runtime:load(fs, "mods")
local effectiveMoves = runtime:resolve("battleMoves")
local additions = runtime:resolve("battleLearnsetAdditions")
local categories = 0
for id = 0, 354 do
  if effectiveMoves[id].category == "physical" or effectiveMoves[id].category == "special" or effectiveMoves[id].category == "status" then categories = categories + 1 end
end
check("all 355 move records receive a valid explicit category", loaded and categories == 355, loadErr)
check("modern categories and frozen physical Poison exceptions resolve", effectiveMoves[17].category == "physical"
  and effectiveMoves[124].category == "physical" and effectiveMoves[127].category == "physical"
  and effectiveMoves[188].category == "physical" and effectiveMoves[314].category == "special"
  and effectiveMoves[0].category == "status")
check("only approved move fields are overridden", effectiveMoves[41].power == 30
  and effectiveMoves[318].pp == 10 and effectiveMoves[317].power == 60 and effectiveMoves[317].accuracy == 90
  and effectiveMoves[350].power == 25 and effectiveMoves[350].accuracy == 90
  and effectiveMoves[202].pp == 10 and effectiveMoves[17].power == 65
  and effectiveMoves[314].power == 65 and effectiveMoves[314].accuracy == 95
  and effectiveMoves[62].power == 70 and effectiveMoves[1].power == 1
  and effectiveMoves[1].marker == 1)
local expected = {
  [24]={30,305}, [31]={30,305}, [34]={30,342}, [42]={35,305}, [82]={32,351},
  [85]={37,65}, [94]={36,247}, [95]={30,317}, [101]={32,351}, [119]={38,127},
  [124]={25,62}, [136]={36,172}, [141]={46,350},
}
local additionCount, additionsMatch = 0, true
for species, row in pairs(additions) do
  additionCount = additionCount + 1
  additionsMatch = additionsMatch and expected[species] ~= nil and #row == 1
    and row[1].level == expected[species][1] and row[1].move == expected[species][2]
end
check("exactly the 13 approved natural additions are registered", additionCount == 13 and additionsMatch)
runtime:unload()
local unloadedMoves = runtime:resolve("battleMoves")
local unloadedAdditions = runtime:resolve("battleLearnsetAdditions")
check("unload restores synthetic base without package residue", unloadedMoves[124].category == nil
  and unloadedMoves[41].power == 1 and next(unloadedAdditions) == nil)
print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
