-- Run: lua5.1 tests/mod_runtime_test.lua
package.path = package.path .. ";./?.lua"
local Runtime = require("src.core.ModRuntime")
local Compatibility = require("src.core.ModSaveCompatibility")
local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or "")) end
end

local files = {
  ["mods/base/manifest.json"] = '{"id":"base","version":"1.0.0","saveImpact":"gameplay"}',
  ["mods/base/init.lua"] = 'return function(mod) mod:content("moves"):patch(1, {power=50}); mod:content("species"):patch(1, {baseHP=99}) end',
  ["mods/addon/manifest.json"] = '{"id":"addon","version":"1.0.0","dependencies":["base"],"saveImpact":"cosmetic"}',
  ["mods/addon/init.lua"] = 'return function(mod) mod:content("moves"):patch(1, {accuracy=100}); mod:hook("probe", function(nextFn, value) return nextFn(value) + 1 end); mod:hook("field.isWalkTileBlocked", function(nextFn, x, y, mapId) if mapId == 7 then return false end return nextFn(x, y) end); mod:hook("field.playerStep", function(nextFn, mapId, x, y) if mapId == 8 and x == 1 then return "modded" end return nextFn(mapId, x, y) end); mod:hook("field.interact", function(nextFn, mapId, x, y, facing, context) if mapId == 9 and facing == "up" then context.message("custom") return "interacted" end return nextFn(mapId, x, y, facing, context) end); mod:hook("field.wildEncounter", function(nextFn, encounter, mapId, x, y) if mapId == 10 and x == 2 then return nextFn({species=25, level=7, slot=encounter.slot}) end return nextFn(encounter, mapId, x, y) end); mod:hook("field.warp", function(nextFn, destination, mapId, x, y) if mapId == 11 and x == 3 then return nextFn({mapId=1025, warpId=2}) end return nextFn(destination, mapId, x, y) end); mod:hook("field.mapLoaded", function(nextFn, mapId, x, y, context) if mapId == 12 and x == 4 and y == 5 then context.setVar(77, 99) return "entered" end return nextFn(mapId, x, y, context) end) end',
}
local fs = {
  list=function() return {"addon", "base"} end,
  isDirectory=function(path) return path == "mods/addon" or path == "mods/base" end,
  read=function(path) return files[path] end,
}
local validationHost = {
  namespaces = {
    {name="moves", options={semantics="deep", base={[1]={power=35, accuracy=95}}}},
    {name="species", options={semantics="deep", base={[1]={baseHP=45}}}},
  },
}
local runtime = Runtime.new(validationHost)
local validated, validationErr = Runtime.validate(fs, "mods")
check("headless validation checks package structure before runtime load", validated
  and validated[1].id == "base" and validated[2].id == "addon", validationErr)
local dryRun, dryRunErr = Runtime.validate(fs, "mods", validationHost)
check("declared-host validation executes callbacks against fresh content", dryRun
  and dryRun[1].id == "base" and dryRun[2].id == "addon", dryRunErr)

local originalAddon = files["mods/addon/init.lua"]
local function rngUnchanged(run)
  math.randomseed(24681357)
  local expected = math.random()
  math.randomseed(24681357)
  run()
  return math.random() == expected
end
check("successful declared-host validation preserves host RNG state", rngUnchanged(function()
  Runtime.validate(fs, "mods", validationHost)
end))
files["mods/addon/init.lua"] = 'return function(mod) math.randomseed(1) end'
local rngFailure, rngFailureErr
check("failed declared-host validation preserves host RNG state", rngUnchanged(function()
  rngFailure, rngFailureErr = Runtime.validate(fs, "mods", validationHost)
end) and rngFailure == nil and rngFailureErr:find("randomseed", 1, true) ~= nil, rngFailureErr)
files["mods/addon/init.lua"] = 'return function(mod) mod:content("unknown"):patch(1, {power=99}) end'
local invalidNamespace, invalidNamespaceErr = Runtime.validate(fs, "mods", validationHost)
check("declared-host validation rejects unknown content namespaces", invalidNamespace == nil
  and invalidNamespaceErr:find("unknown namespace", 1, true) ~= nil, invalidNamespaceErr)
files["mods/addon/init.lua"] = 'return function(mod) mod:content("moves"):patch(2, {power=99}) end'
local invalidPatch, invalidPatchErr = Runtime.validate(fs, "mods", validationHost)
check("declared-host validation resolves and rejects invalid lazy patches", invalidPatch == nil
  and invalidPatchErr:find("cannot be patched", 1, true) ~= nil, invalidPatchErr)
files["mods/addon/init.lua"] = originalAddon
local loaded, err = runtime:load(fs, "mods")
local moves, owners = runtime:resolve("moves")
local species = runtime:resolve("species")
check("runtime discovers then loads dependency order", loaded and loaded[1].id == "base"
  and loaded[2].id == "addon", err)
check("runtime resolves deterministic composed content", moves[1].power == 50 and moves[1].accuracy == 100
  and owners[1] == "base", moves[1].power .. "/" .. moves[1].accuracy .. "/" .. tostring(owners[1]))
check("runtime resolves multiple independent namespaces", species[1].baseHP == 99)
check("runtime exposes the enabled save profile", Compatibility.key(runtime.profile)
  == "v1/addon@1.0.0:cosmetic;base@1.0.0:gameplay")
check("runtime exposes deterministic package-owned hooks", runtime.hooks:call("probe",
  function(value) return value * 2 end, 5) == 11)
check("runtime hooks can receive field coordinates and map id", not runtime.hooks:call(
  "field.isWalkTileBlocked", function() return true end, 4, 5, 7))
check("runtime hooks can short-circuit completed player steps", runtime.hooks:call(
  "field.playerStep", function() return "vanilla" end, 8, 1, 2) == "modded")
check("runtime hooks can replace a wild encounter deterministically", runtime.hooks:call(
  "field.wildEncounter", function(encounter) return encounter.species == 25 and encounter.level == 7 end,
  {species=19, level=3, slot=1}, 10, 2, 4))
check("runtime hooks can redirect a field warp deterministically", runtime.hooks:call(
  "field.warp", function(destination) return destination.mapId == 1025 and destination.warpId == 2 end,
  {mapId=1024, warpId=1}, 11, 3, 4))
local enteredVar
check("runtime hooks can observe a finalized map entry with bounded state", runtime.hooks:call(
  "field.mapLoaded", function() return "vanilla" end, 12, 4, 5,
  {setVar=function(id, value) enteredVar = {id=id, value=value} end}) == "entered"
  and enteredVar and enteredVar.id == 77 and enteredVar.value == 99)
local interactionMessage
check("runtime hooks can short-circuit field interactions", runtime.hooks:call(
  "field.interact", function() return "vanilla" end, 9, 1, 2, "up",
  {message=function(text) interactionMessage = text end}) == "interacted" and interactionMessage == "custom")
runtime:unload()
moves = runtime:resolve("moves")
species = runtime:resolve("species")
check("unload removes all mod operations and resets profile", moves[1].power == 35
  and species[1].baseHP == 45 and runtime.profile.entries[1] == nil
  and runtime.hooks:call("probe", function(value) return value end, 5) == 5)

files["mods/addon/init.lua"] = 'return function(mod) mod:content("moves"):patch(1, {power=99}); mod:hook("probe", function(nextFn, value) return nextFn(value) + 99 end); error("stop") end'
loaded, err = runtime:load(fs, "mods")
moves = runtime:resolve("moves")
species = runtime:resolve("species")
check("callback failure rolls back every package", loaded == nil and err:find("addon", 1, true) ~= nil
  and moves[1].power == 35 and species[1].baseHP == 45
  and runtime.hooks:call("probe", function(value) return value end, 5) == 5)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
