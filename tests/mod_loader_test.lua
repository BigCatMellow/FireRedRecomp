-- Run: lua5.1 tests/mod_loader_test.lua
package.path = package.path .. ";./?.lua"
local Registry = require("src.core.ModRegistry")
local Loader = require("src.core.ModLoader")
local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

local registry = Registry.new()
registry:registerNamespace("moves", {semantics="deep", base={[1]={power=40}}})
local loader, trace = Loader.new(registry), {}
local loaded = assert(loader:load({
  {manifest={id="dependent",version="1.0.0",dependencies={"base"}}, callback=function(mod)
    trace[#trace + 1] = "dependent"
    mod:content("moves"):patch(1, {name="DEPENDENT"})
  end},
  {manifest={id="base",version="1.0.0"}, callback=function(mod)
    trace[#trace + 1] = "base"
    mod:content("moves"):patch(1, {power=50})
  end},
}))
check("loader applies dependencies before dependents", table.concat(trace, ",") == "base,dependent")
check("loader returns normalized deterministic manifests", loaded[1].id == "base" and loaded[2].id == "dependent")
local moves = registry:resolve("moves")
check("loader contributions compose through the registry", moves[1].power == 50 and moves[1].name == "DEPENDENT")

local failedRegistry = Registry.new()
failedRegistry:registerNamespace("moves", {semantics="deep", base={[1]={power=40}}})
local failedLoader = Loader.new(failedRegistry)
local value, err = failedLoader:load({
  {manifest={id="first",version="1.0.0"}, callback=function(mod)
    mod:content("moves"):patch(1, {power=99})
  end},
  {manifest={id="second",version="1.0.0",dependencies={"first"}}, callback=function()
    error("intentional failure")
  end},
})
check("a failed callback reports its responsible mod", value == nil and err:find("second", 1, true) ~= nil, err)
check("a failed load rolls back every earlier mod contribution", failedRegistry:resolve("moves")[1].power == 40)
check("a failed load leaves no prior mod registered", failedRegistry.mods.first == nil and failedRegistry.mods.second == nil)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
