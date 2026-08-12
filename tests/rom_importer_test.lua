-- Plain Lua smoke test (no LÖVE runtime needed for the hash-table checks;
-- the love.data.hash-dependent path is skipped if love isn't present).
-- Run: lua5.1 tests/rom_importer_test.lua

package.path = package.path .. ";./?.lua"

local passed, failed = 0, 0
local function check(name, cond)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name)
  end
end

-- love isn't available under plain lua5.1, so stub just enough of
-- love.data.hash to exercise RomImporter's table logic without a real ROM.
-- This is not a substitute for testing the real sha1 path under `love .`.
if not love then
  _G.love = {
    data = {
      hash = function(_, data)
        -- Not a real sha1; only used so verify() can run end-to-end below
        -- against a fabricated "rom" whose hash we don't assert on.
        return data
      end,
    },
  }
end

local RomImporter = require("import.RomImporter")

check("known supported hash is present", RomImporter._SUPPORTED["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"] ~= nil)
check("supported entry has correct name", RomImporter._SUPPORTED["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"].name == "Pokémon FireRed (US)")

local ok, errMsg = RomImporter.verify("/nonexistent/path/rom.gba")
check("missing file fails cleanly", ok == false and type(errMsg) == "string")

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
