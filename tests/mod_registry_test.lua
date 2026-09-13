-- Run: lua5.1 tests/mod_registry_test.lua
package.path = package.path .. ";./?.lua"
local Registry = require("src.core.ModRegistry")
local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

local registry = Registry.new()
registry:registerNamespace("moves", { semantics="deep", base={
  [1]={name="POUND", power=40, flags={contact=true, protect=true}},
} })
registry:registerNamespace("maps", { base={ pallet={name="PALLET TOWN"} } })

-- Callback order intentionally differs from precedence: resolve must be
-- deterministic from priority then id, never filesystem enumeration order.
assert(registry:apply({id="zeta", priority=0}, function(mod)
  mod:content("moves"):patch(1, {power=45, flags={contact=Registry.DELETE}})
  mod:content("maps"):override("pallet", {name="CUSTOM PALLET"})
end))
assert(registry:apply({id="alpha", priority=0}, function(mod)
  mod:content("moves"):patch(1, {name="TAP"})
  mod:content("moves"):register(900, {name="MOD BLAST", power=90})
end))

local moves, moveOwners = registry:resolve("moves")
check("deep patches compose in deterministic lexical mod order", moves[1].name == "TAP" and moves[1].power == 45)
check("deep patch deletion removes only its requested field", moves[1].flags.contact == nil and moves[1].flags.protect == true)
check("new records can be registered without mutating base data", moves[900].name == "MOD BLAST")
check("provenance records the effective last writer", moveOwners[1] == "zeta" and registry:provenance("moves", 900) == "alpha")
check("record namespace overrides are explicit and supported", registry:resolve("maps").pallet.name == "CUSTOM PALLET")

local baseMoves = registry.namespaces.moves.base
check("resolve never mutates the imported base table", baseMoves[1].power == 40 and baseMoves[1].flags.contact == true)

local bad, err = registry:apply({id="broken"}, function(mod)
  mod:content("moves"):register(901, {name="TEMP"})
  error("intentional failure")
end)
check("a failed mod callback reports failure", bad == nil and tostring(err):find("intentional failure", 1, true) ~= nil)
check("a failed mod callback rolls back all staged operations", registry:resolve("moves")[901] == nil)

assert(registry:apply({id="first"}, function(mod)
  mod:content("maps"):register("new-map", {name="ONE"})
end))
assert(registry:apply({id="second"}, function(mod)
  mod:content("maps"):register("new-map", {name="TWO"})
end))
local ok, duplicate = pcall(function() registry:resolve("maps") end)
check("duplicate registration is rejected and names the ownership mistake", not ok and tostring(duplicate):find("already exists", 1, true) ~= nil)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
