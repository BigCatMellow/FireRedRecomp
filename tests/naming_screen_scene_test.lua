-- ROM fixture tests for import/NamingScreenScene.lua.
-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/naming_screen_scene_test.lua
package.path = package.path .. ";./?.lua"

local NamingState = require("src.core.NamingScreenState")
local NamingScene = require("import.NamingScreenScene")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

check("scene geometry is the real GBA screen", NamingScene.SCREEN_WIDTH == 240 and NamingScene.SCREEN_HEIGHT == 160)
check("state tables retain real page widths", NamingState.COLUMN_COUNTS[NamingState.PAGE_UPPER] == 8 and NamingState.COLUMN_COUNTS[NamingState.PAGE_LOWER] == 8 and NamingState.COLUMN_COUNTS[NamingState.PAGE_SYMBOLS] == 6)

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print(("%d passed, %d failed"):format(passed, failed))
  print("SKIP: set POKEPORT_ROM to run ROM-backed naming-screen checks")
  os.exit(failed == 0 and 0 or 1)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local Charmap = require("import.Charmap")
local ok, info = RomImporter.verify(romPath)
if not ok then print("FAIL: ROM did not verify -- " .. tostring(info)); os.exit(1) end
local sha1 = RomImporter._sha1HexOfFile(romPath)
local addrs = assert(RomAddresses[sha1])
local f = assert(io.open(romPath, "rb")); local data = f:read("*a"); f:close()

local fixture = NamingScene.decodeKeyboardFixture(data, addrs)
check("ROM sKeyboardChars begins lowercase abcdef-space-period", table.concat({fixture.chars[0],fixture.chars[1],fixture.chars[2],fixture.chars[3],fixture.chars[4],fixture.chars[5],fixture.chars[6],fixture.chars[7]}, ",") == "213,214,215,216,217,218,0,173")
check("ROM page-column counts are KEYBOARD order 8,8,6", fixture.counts[0] == 8 and fixture.counts[1] == 8 and fixture.counts[2] == 6)
check("ROM uppercase cursor x positions match source", table.concat(fixture.columnX[1], ",", 0, 7) == "0,12,24,56,68,80,92,123")
check("ROM symbols cursor x positions match source", table.concat(fixture.columnX[2], ",", 0, 5) == "0,22,44,66,88,110")

local pageToKeyboard = { [NamingState.PAGE_LOWER]=0, [NamingState.PAGE_UPPER]=1, [NamingState.PAGE_SYMBOLS]=2 }
local allCharsMatch = true
for page, keyboard in pairs(pageToKeyboard) do
  for row = 0, 3 do
    for col = 0, 7 do
      local got = fixture.chars[keyboard * 32 + row * 8 + col]
      if got ~= NamingState.KEYBOARD_CHARS[page][row + 1][col + 1] then allCharsMatch = false end
    end
  end
end
check("all 96 source-transcribed insertion bytes match verified ROM", allCharsMatch)

local upperRow = Charmap.decode(NamingScene.keyboardRowRaw(data, addrs, NamingState.PAGE_UPPER, 0))
local lowerRow = Charmap.decode(NamingScene.keyboardRowRaw(data, addrs, NamingState.PAGE_LOWER, 0))
local symbolsRow = Charmap.decode(NamingScene.keyboardRowRaw(data, addrs, NamingState.PAGE_SYMBOLS, 2))
check("upper display row pointer resolves through real control-code text", upperRow:find("A") and upperRow:find("F") and upperRow:find("%."), upperRow)
check("lower display row pointer resolves through real control-code text", lowerRow:find("a") and lowerRow:find("f") and lowerRow:find("%."), lowerRow)
check("symbols display row contains ! ? male female / -", symbolsRow:find("!") and symbolsRow:find("?") and symbolsRow:find("♂") and symbolsRow:find("♀") and symbolsRow:find("/") and symbolsRow:find("%-"), symbolsRow)

local function decodedAt(offset, max)
  return Charmap.decode(data:sub(offset + 1, offset + (max or 160)))
end
check("real gender strings decode BOY/GIRL", decodedAt(addrs.gText_Boy, 8) == "BOY" and decodedAt(addrs.gText_Girl, 8) == "GIRL")
check("real gender prompt is the source-confirmed question", decodedAt(addrs.gOakSpeech_Text_AskPlayerGender):find("Are you a boy") ~= nil)
check("real player confirmation retains PLAYER placeholder", decodedAt(addrs.gOakSpeech_Text_SoYourNameIsPlayer):find("{PLAYER}", 1, true) ~= nil)
check("real rival confirmation retains RIVAL placeholder", decodedAt(addrs.gOakSpeech_Text_ConfirmRivalName):find("{RIVAL}", 1, true) ~= nil)

local PointerStringTable = require("import.PointerStringTable")
local rivalDefaults = {}
for i = 0, 3 do rivalDefaults[#rivalDefaults + 1] = PointerStringTable.resolveAt(data, addrs.sRivalNameChoices, i, 16) end
check("real FireRed rival defaults are GREEN/GARY/KAZ/TORU", table.concat(rivalDefaults, ",") == "GREEN,GARY,KAZ,TORU", table.concat(rivalDefaults, ","))
check("real player defaults include male RED and female OMI", PointerStringTable.resolveAt(data, addrs.sMaleNameChoices, 0, 16) == "RED" and PointerStringTable.resolveAt(data, addrs.sFemaleNameChoices, 2, 16) == "OMI")

for _, page in ipairs({NamingState.PAGE_UPPER, NamingState.PAGE_LOWER, NamingState.PAGE_SYMBOLS}) do
  local decoded = NamingScene.decode(data, addrs, page)
  check("page " .. page .. " gfx decompresses to 48 4bpp tiles", #decoded.gfxRaw == 1536 and decoded.tiles[47] ~= nil)
  check("page " .. page .. " tilemaps are 32x20 u16", #decoded.backgroundRaw == 1280 and #decoded.keyboardRaw == 1280)
end

local state = NamingState.new()
local composite = NamingScene.composite(data, addrs, { kind="player", state=state, entryBytes=string.char(0xCC,0xBF,0xBE,0xFF) })
check("full naming compositor returns 240x160", composite.width == 240 and composite.height == 160)
local opaque, colors = 0, {}
for y = 0, composite.height - 1 do
  for x = 0, composite.width - 1 do
    local p = composite.getPixel(x,y)
    if p.a ~= 0 then opaque = opaque + 1; colors[p.r .. "," .. p.g .. "," .. p.b] = true end
  end
end
local colorCount = 0; for _ in pairs(colors) do colorCount = colorCount + 1 end
check("full naming frame is opaque", opaque == 240 * 160, opaque)
check("full naming frame has substantial decoded color variation", colorCount > 20, colorCount)

local cursor = NamingScene.compositeCursor(data, addrs)
local cursorOpaque = 0
for y = 0, 15 do for x = 0, 15 do if cursor.getPixel(x,y).a ~= 0 then cursorOpaque = cursorOpaque + 1 end end end
check("real naming cursor decodes as 16x16 with visible pixels", cursor.width == 16 and cursor.height == 16 and cursorOpaque > 0 and cursorOpaque < 256, cursorOpaque)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
