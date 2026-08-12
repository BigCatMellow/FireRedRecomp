-- Run: lua5.1 tests/trainer_test.lua
package.path = package.path .. ";./?.lua"
local Trainer = require("import.Trainer")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

check("record size is 40", Trainer.RECORD_SIZE == 40)

-- TRAINER_YOUNGSTER_BEN (index 89), exactly as it appears in the real ROM
-- (verified against pokefirered.gba built locally): class=57, name="BEN",
-- doubleBattle=false, aiFlags=0x1 (AI_SCRIPT_CHECK_BAD_MOVE), partySize=2.
local record = string.char(
  0x00,       -- partyFlags
  0x39,       -- trainerClass = 57
  0x00,       -- encounterMusic_gender
  0x00,       -- trainerPic
  0xbc, 0xbf, 0xc8, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, -- name "BEN"
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, -- items[4]
  0x00,       -- doubleBattle = false
  0x00, 0x00, 0x00, -- padding
  0x01, 0x00, 0x00, 0x00, -- aiFlags = 1
  0x02,       -- partySize = 2
  0x00, 0x00, 0x00, -- padding
  0x00, 0x00, 0x00, 0x00 -- party pointer
)

check("record is 40 bytes", #record == 40)

local parsed = Trainer.parseRecord(record)
check("trainerClass", parsed.trainerClass == 57, parsed.trainerClass)
check("rawName decodes to BEN's bytes", parsed.rawName:sub(1, 4) == string.char(0xbc, 0xbf, 0xc8, 0xff))
check("doubleBattle is false", parsed.doubleBattle == false)
check("aiFlags", parsed.aiFlags == 1, parsed.aiFlags)
check("partySize", parsed.partySize == 2, parsed.partySize)
check("items array has 4 entries", parsed.items[0] == 0 and parsed.items[3] == 0)

-- Gender bit: encounterMusic_gender high bit set = female trainer.
local femaleRecord = record:sub(1, 2) .. string.char(0x80) .. record:sub(4)
check("female bit decodes correctly", Trainer.parseRecord(femaleRecord).isFemale == true)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
