-- Run: lua5.1 tests/mod_save_profile_codec_test.lua
package.path = package.path .. ";./?.lua"
local Codec = require("src.core.ModSaveProfileCodec")
local Compatibility = require("src.core.ModSaveCompatibility")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or "")) end
end

local base = "FRSV" .. string.char(2, 0, 0, 0)
  .. string.rep("\0", Codec.BASE_BYTES - 8)
local profile = Compatibility.profile({
  {id="z-ui", version="1.2.3", saveImpact="cosmetic"},
  {id="a-content", version="2.0.0", saveImpact="gameplay"},
})
local sidecar = Codec.encode(profile)
local decoded = Codec.decode(sidecar)
check("profile sidecar round-trips deterministic profile data",
  Compatibility.key(decoded) == Compatibility.key(profile))

local attached = Codec.attach(base, profile)
local extractedBase, extractedProfile = Codec.extract(attached)
check("sidecar keeps the complete original FireRed buffer unchanged",
  extractedBase == base and #attached > #base)
check("attached sidecar extracts its compatibility profile",
  Compatibility.key(extractedProfile) == Compatibility.key(profile))

local legacyBase, legacyProfile = Codec.extract(base)
check("unmodified legacy saves remain valid with no profile", legacyBase == base and legacyProfile == nil)

local v1Bytes = "FRSV" .. string.char(1, 0, 0, 0)
  .. string.rep("\0", 2 * 5 * 4096)
local v1Base, v1Profile = Codec.extract(v1Bytes .. sidecar)
check("schema-v1 saves can carry and extract a sidecar", v1Base == v1Bytes
  and Compatibility.key(v1Profile) == Compatibility.key(profile))

local ok = pcall(function() Codec.decode(sidecar .. "x") end)
check("trailing sidecar bytes fail loudly", not ok)
ok = pcall(function() Codec.attach(base:sub(1, -2), profile) end)
check("partial base buffers fail loudly", not ok)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
