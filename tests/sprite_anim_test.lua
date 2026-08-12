-- Integration test: decodes the real title screen flame animation
-- (sSpriteAnim_Flame) and checks it against the exact ANIMCMD_FRAME(...)
-- argument list from the real C source (src/title_screen.c). Opt-in via
-- POKEPORT_ROM, skips cleanly otherwise.
--
-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/sprite_anim_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local SpriteAnim = require("import.SpriteAnim")

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

local cmds = SpriteAnim.decodeCmds(data, addrs.sSpriteAnim_Flame)

-- Real source: ANIMCMD_FRAME(0,3), then 9x ANIMCMD_FRAME(imageValue,6) at
-- imageValue 4,8,...,36, then ANIMCMD_END. 11 entries total.
check("decodes exactly 11 commands (10 frames + END)", #cmds == 11, #cmds)
check("frame 0: imageValue=0, duration=3", cmds[1].type == "frame" and cmds[1].imageValue == 0 and cmds[1].duration == 3)

local expectedImageValues = { 0, 4, 8, 12, 16, 20, 24, 28, 32, 36 }
local allMatch = true
for i, expected in ipairs(expectedImageValues) do
  local cmd = cmds[i]
  if cmd.type ~= "frame" or cmd.imageValue ~= expected then allMatch = false end
  if i > 1 and cmd.duration ~= 6 then allMatch = false end
end
check("all 10 frames match the real imageValue sequence (0,4,8,...,36) with the right durations", allMatch)

check("no frame has hFlip/vFlip set (real source doesn't set them)", (function()
  for i = 1, 10 do
    if cmds[i].hFlip or cmds[i].vFlip then return false end
  end
  return true
end)())

check("terminates with ANIMCMD_END", cmds[11].type == "end")

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
