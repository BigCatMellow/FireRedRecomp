-- Run: lua5.1 tests/mod_manifest_test.lua
package.path = package.path .. ";./?.lua"
local Manifest = require("src.core.ModManifest")
local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end
local function names(list)
  local out = {}; for i, manifest in ipairs(list) do out[i] = manifest.id end
  return table.concat(out, ",")
end

local ordered = Manifest.order({
  {id="zeta", version="1.0.0", priority=0},
  {id="alpha", version="1.0.0", priority=0},
  {id="dependent", version="1.0.0", priority=-10, dependencies={"zeta"}},
})
check("independent mods sort deterministically by priority then id while dependencies remain first",
  names(ordered) == "alpha,zeta,dependent", names(ordered))

local normalized = Manifest.validate({id="valid", name="Valid", version="2.3.4", priority="7"})
check("manifest validation normalizes optional fields", normalized.priority == 7 and #normalized.dependencies == 0)

local function fails(raw)
  local ok, err = pcall(raw); return not ok and tostring(err) or nil
end
check("duplicate ids are rejected", fails(function() Manifest.order({
  {id="same",version="1.0.0"}, {id="same",version="1.0.0"},
}) end):find("duplicate", 1, true) ~= nil)
check("missing dependencies are rejected", fails(function() Manifest.order({
  {id="needs",version="1.0.0",dependencies={"missing"}},
}) end):find("missing", 1, true) ~= nil)
check("enabled conflicts are rejected", fails(function() Manifest.order({
  {id="one",version="1.0.0",conflicts={"two"}}, {id="two",version="1.0.0"},
}) end):find("conflicts", 1, true) ~= nil)
check("dependency cycles are rejected", fails(function() Manifest.order({
  {id="one",version="1.0.0",dependencies={"two"}},
  {id="two",version="1.0.0",dependencies={"one"}},
}) end):find("cycle", 1, true) ~= nil)
check("unsupported APIs are rejected", fails(function()
  Manifest.validate({id="future",version="1.0.0",api=2})
end):find("requires API", 1, true) ~= nil)
check("malformed versions are rejected", fails(function()
  Manifest.validate({id="bad",version="1.0"})
end):find("MAJOR", 1, true) ~= nil)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
