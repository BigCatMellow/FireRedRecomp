-- Run: lua5.1 tests/charmap_test.lua
package.path = package.path .. ";./?.lua"
local Charmap = require("import.Charmap")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Real bytes, verified against the built ROM (ABILITY_STENCH, ITEM_MASTER_BALL).
local stench = string.char(0xcd, 0xce, 0xbf, 0xc8, 0xbd, 0xc2, 0xff, 0x00)
check("decodes STENCH", Charmap.decode(stench) == "STENCH", Charmap.decode(stench))

local masterBall = string.char(0xc7, 0xbb, 0xcd, 0xce, 0xbf, 0xcc, 0x00, 0xbc, 0xbb, 0xc6, 0xc6, 0xff, 0x00, 0x00)
check("decodes MASTER BALL (space is 0x00)", Charmap.decode(masterBall) == "MASTER BALL", Charmap.decode(masterBall))

check("stops at terminator, ignores trailing padding", Charmap.decode(string.char(0xbb, 0xff, 0xbb)) == "A")
check("without stopAtTerminator, keeps decoding past 0xFF as '$'", Charmap.decode(string.char(0xbb, 0xff, 0xbb), false) == "A$A")

local unmapped = Charmap.decode(string.char(0xF8)) -- not a defined charmap byte (F7-F9 are unused duplicate arrows)
check("unmapped byte renders as hex placeholder, not silently dropped", unmapped == "[F8]", unmapped)

-- Control codes: verified against real ROM data (PalletTown_Text_OakDontGoOut,
-- PalletTown_Text_PlayersHouse).
check("0xFE (newline) decodes to a real newline", Charmap.decode(string.char(0xbb, 0xfe, 0xbc)) == "A\nB")
check("0xFA/0xFB also decode as newline", Charmap.decode(string.char(0xfa)) == "\n" and Charmap.decode(string.char(0xfb)) == "\n")
check("0xFD 0x01 decodes to {PLAYER}", Charmap.decode(string.char(0xfd, 0x01)) == "{PLAYER}")
check("0xFD with unknown subcode falls back to a hex tag", Charmap.decode(string.char(0xfd, 0x99)) == "{FD:99}")
check("0xFC 0x01 (COLOR) decodes as a tag, consuming only 2 bytes (known limitation: trailing param bytes not skipped)", Charmap.decode(string.char(0xfc, 0x01, 0xbb)) == "{FC:01}A")

-- decodeAt over a fixed-stride table (11-byte species-name-style stride).
local blob = masterBall:sub(1, 11) .. string.char(0xbb, 0xbc, 0xbd, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00) -- "ABC"
check("decodeAt reads the right entry", Charmap.decodeAt(blob, 0, 11, 1) == "ABC", Charmap.decodeAt(blob, 0, 11, 1))
local ok = pcall(Charmap.decodeAt, blob, 0, 11, 5) -- past the end
check("decodeAt errors past end of data", ok == false)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
