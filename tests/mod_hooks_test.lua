-- Run: lua5.1 tests/mod_hooks_test.lua
package.path = package.path .. ";./?.lua"
local Hooks = require("src.core.ModHooks")
local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

local hooks, order = Hooks.new(), {}
hooks:wrap("damage", {id="zeta", priority=0}, function(nextFn, value)
  order[#order + 1] = "zeta-before"
  local result = nextFn(value + 1)
  order[#order + 1] = "zeta-after"
  return result * 2
end)
hooks:wrap("damage", {id="alpha", priority=0}, function(nextFn, value)
  order[#order + 1] = "alpha-before"
  local result = nextFn(value * 3)
  order[#order + 1] = "alpha-after"
  return result + 4
end)
local result = hooks:call("damage", function(value)
  order[#order + 1] = "vanilla"
  return value
end, 2)
check("equal-priority hooks use deterministic lexical owner order",
  table.concat(order, ",") == "alpha-before,zeta-before,vanilla,zeta-after,alpha-after",
  table.concat(order, ","))
check("hooks can transform arguments and results around the vanilla call", result == 18, result)

hooks:wrap("stop", {id="short-circuit"}, function(_, value) return value + 1, "kept" end)
local a, b = hooks:call("stop", function() error("vanilla should not run") end, 7)
check("a hook may intentionally short-circuit a call and preserve multiple results", a == 8 and b == "kept")

local remove = hooks:wrap("remove", {id="temporary"}, function(nextFn, value) return nextFn(value + 2) end)
check("registered hooks affect their named chain", hooks:call("remove", function(value) return value end, 1) == 3)
remove()
check("the unsubscribe returned by wrap removes only its hook", hooks:call("remove", function(value) return value end, 1) == 1)

hooks:wrap("owners", {id="one"}, function(nextFn) return nextFn() end)
hooks:wrap("owners", {id="two"}, function(nextFn) return nextFn() end)
hooks:removeOwner("one")
check("removeOwner removes a mod across chains without affecting peers", #hooks.chains.owners == 1 and hooks.chains.owners[1].owner == "two")

local duplicateNext = Hooks.new()
duplicateNext:wrap("once", {id="broken"}, function(nextFn) nextFn(); return nextFn() end)
local ok, err = pcall(function() duplicateNext:call("once", function() return true end) end)
check("calling next twice is rejected before duplicate vanilla side effects", not ok and tostring(err):find("more than once", 1, true) ~= nil)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
