-- Run: lua5.1 tests/mod_entrypoint_test.lua
package.path = package.path .. ";./?.lua"
local Entrypoint = require("src.core.ModEntrypoint")
local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or "")) end
end

local callback, err = Entrypoint.compile([[ 
  assert(os == nil and io == nil and require == nil and _G.os == nil)
  return function(mod) mod:register("moves", 999, {power = 60}) end
]], "mods/example/init.lua")
local received
if callback then callback({register=function(_, namespace, id, value)
  received = {namespace=namespace, id=id, value=value}
end}) end
check("entrypoint evaluates in a capability-free sandbox", callback ~= nil and err == nil)
check("entrypoint callback receives only explicit registry API", received and received.namespace == "moves"
  and received.id == 999 and received.value.power == 60)

local originalInsert = table.insert
callback = assert(Entrypoint.compile([[table.insert = false; return function() end]], "mods/mutate/init.lua"))
callback()
check("sandbox library mutation cannot affect host globals", table.insert == originalInsert)

callback = assert(Entrypoint.compile([[assert(math.random == nil and math.randomseed == nil); return function() end]],
  "mods/no-rng/init.lua"))
callback()
check("sandbox exposes no ambient process-global RNG", math.random ~= nil and math.randomseed ~= nil)

callback = assert(Entrypoint.compile([[assert(answer == 42); return function() return answer end]],
  "mods/capability/init.lua", {answer=42}))
check("host-selected capabilities are visible", callback() == 42)

local bad, badErr = Entrypoint.compile("return function(", "mods/bad/init.lua")
check("syntax errors report the package path", bad == nil and badErr:find("mods/bad/init.lua", 1, true) ~= nil)
bad, badErr = Entrypoint.compile("return 42", "mods/value/init.lua")
check("non-callback entries fail loudly", bad == nil and badErr:find("must return a callback", 1, true) ~= nil)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
