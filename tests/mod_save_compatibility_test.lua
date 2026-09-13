-- Run: lua5.1 tests/mod_save_compatibility_test.lua
package.path = package.path .. ";./?.lua"
local C = require("src.core.ModSaveCompatibility")
local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or "")) end
end
local function profile(entries) return C.profile(entries) end

local base = profile({})
local cosmetic = profile({{id="colors",version="1.0.0",saveImpact="cosmetic"}})
local gameplay = profile({{id="difficulty",version="1.0.0",saveImpact="gameplay"}})
local gameplayV2 = profile({{id="difficulty",version="2.0.0",saveImpact="gameplay"}})
check("identical profiles are exact", C.compare(gameplay, gameplay).status == "exact")
local cosmeticResult = C.compare(base, cosmetic)
check("cosmetic changes remain loadable but visible", cosmeticResult.status == "cosmetic" and cosmeticResult.changed[1] == "colors")
check("cosmetic differences have a deterministic host-visible description",
  C.describe(cosmeticResult) == "Cosmetic mod differences: colors.")
local rejected = C.compare(base, gameplay)
check("enabling gameplay content rejects an old save by default", rejected.status == "reject" and rejected.reason:find("difficulty", 1, true) ~= nil)
check("changing a gameplay mod version rejects by default", C.compare(gameplay, gameplayV2).status == "reject")
local migrations = {[C.key(gameplay)] = {[C.key(gameplayV2)] = "difficulty-v1-to-v2"}}
check("an explicit profile migration is surfaced to the caller", C.compare(gameplay, gameplayV2, migrations).migration == "difficulty-v1-to-v2")
check("migration descriptions do not imply execution", C.describe(
  C.compare(gameplay, gameplayV2, migrations)) == "Save requires explicit mod migration: difficulty-v1-to-v2.")
check("profile keys are deterministic regardless of input order", C.key(profile({
  {id="z",version="1.0.0",saveImpact="cosmetic"}, {id="a",version="1.0.0",saveImpact="gameplay"},
})) == C.key(profile({
  {id="a",version="1.0.0",saveImpact="gameplay"}, {id="z",version="1.0.0",saveImpact="cosmetic"},
})))

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
