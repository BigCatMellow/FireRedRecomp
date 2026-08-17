-- ROM-gated test for live battle scene graphics.
-- Run: POKEPORT_ROM=/path/to/pokefirered.gba lua5.1 tests/battle_scene_assets_test.lua
package.path = package.path .. ";./?.lua"
local BattleSceneAssets = require("import.BattleSceneAssets")
local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")

local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP: set POKEPORT_ROM for battle scene asset checks"); os.exit(0) end
local f = assert(io.open(path, "rb")); local data = f:read("*a"); f:close()
local addrs = assert(RomAddresses[RomImporter._sha1HexOfFile(path)])
local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or "")) end
end

local front = BattleSceneAssets.decodeMon(data, addrs, 16, false) -- Pidgey
local back = BattleSceneAssets.decodeMon(data, addrs, 1, true) -- Bulbasaur
check("real Pidgey front sprite is 64x64", front.width == 64 and front.height == 64)
check("real Bulbasaur back sprite is 64x64", back.width == 64 and back.height == 64)
local function opaqueCount(image)
  local n = 0
  for y=0,image.height-1 do for x=0,image.width-1 do if image.getPixel(x,y).a ~= 0 then n=n+1 end end end
  return n
end
check("real Pidgey front sprite has visible pixels", opaqueCount(front) > 100)
check("real Bulbasaur back sprite has visible pixels", opaqueCount(back) > 100)

local bg = BattleSceneAssets.compositeGrassBackground(data, addrs)
check("grass battle background is one real GBA viewport", bg.width == 240 and bg.height == 160)
local colors = {}
for y=0,159,8 do for x=0,239,8 do local c=bg.getPixel(x,y); colors[c.r..","..c.g..","..c.b]=true end end
local colorCount=0; for _ in pairs(colors) do colorCount=colorCount+1 end
check("grass battle background contains varied real palette colors", colorCount > 4, colorCount)

local tokens = BattleSceneAssets.textTokens("FIGHT\nRUN", true)
check("dynamic battle text uses dark color then real newline", tokens[1].type == "color" and tokens[7].type == "newline")

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
