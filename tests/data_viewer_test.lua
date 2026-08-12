-- Integration test: exercises the read-only data viewer (Phase 1 exit
-- criterion) against a real ROM for all 4 categories. Opt-in via
-- POKEPORT_ROM, skips cleanly otherwise.
--
-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/data_viewer_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local DataViewer = require("src.core.DataViewer")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local ok, info = RomImporter.verify(romPath)
if not ok then
  print("FAIL: ROM did not verify -- " .. tostring(info))
  os.exit(1)
end

local sha1 = RomImporter._sha1HexOfFile(romPath)
local addrs = RomAddresses[sha1]

local f = io.open(romPath, "rb")
local data = f:read("*a")
f:close()

local function joined(category, index)
  return table.concat(DataViewer.describe(data, addrs, category, index), "\n")
end

check("species 1 (Bulbasaur) shows correct name/type/stats", (function()
  local text = joined("species", 1)
  return text:find("BULBASAUR", 1, true) and text:find("GRASS/POISON", 1, true) and text:find("HP 45", 1, true)
end)())

check("move 1 (Pound) shows correct name/power/pp", (function()
  local text = joined("moves", 1)
  return text:find("POUND", 1, true) and text:find("Power: 40", 1, true) and text:find("PP: 35", 1, true)
end)())

check("trainer 89 (Youngster Ben) shows correct name and party", (function()
  local text = joined("trainers", 89)
  return text:find("BEN", 1, true) and text:find("RATTATA Lv.11", 1, true) and text:find("EKANS Lv.11", 1, true)
end)())

check("map 3,0 (Pallet Town) shows correct layout dims", (function()
  local text = joined("maps", 3 * 256 + 0)
  return text:find("mapLayoutId: 78", 1, true) and text:find("24x20 metatiles", 1, true)
end)())

check("out-of-range species index reports an error, doesn't crash", (function()
  local ok2, text = pcall(joined, "species", 99999)
  return ok2 and text:find("out of range", 1, true) ~= nil
end)())

check("invalid map reports an error, doesn't crash", (function()
  local ok2, text = pcall(joined, "maps", 200 * 256 + 200)
  return ok2
end)())

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
