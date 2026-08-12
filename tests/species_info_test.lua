-- Run: lua5.1 tests/species_info_test.lua
package.path = package.path .. ";./?.lua"
local SpeciesInfo = require("import.SpeciesInfo")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Build one synthetic 28-byte SpeciesInfo record with known field values,
-- matching pokefirered's struct SpeciesInfo layout byte-for-byte.
local function buildRecord(fields)
  local b = {}
  b[0x00] = fields.baseHP
  b[0x01] = fields.baseAttack
  b[0x02] = fields.baseDefense
  b[0x03] = fields.baseSpeed
  b[0x04] = fields.baseSpAttack
  b[0x05] = fields.baseSpDefense
  b[0x06] = fields.type1
  b[0x07] = fields.type2
  b[0x08] = fields.catchRate
  b[0x09] = fields.expYield
  -- evYield bitfield (u16 LE): hp=1, atk=2, def=3, speed=0, spAtk=1, spDef=2
  -- -> 1 | (2<<2) | (3<<4) | (0<<6) | (1<<8) | (2<<10) = 1+8+48+0+256+2048 = 2361
  local evBits = 2361
  b[0x0A] = evBits % 256
  b[0x0B] = math.floor(evBits / 256)
  b[0x0C] = fields.itemCommon % 256
  b[0x0D] = math.floor(fields.itemCommon / 256)
  b[0x0E] = fields.itemRare % 256
  b[0x0F] = math.floor(fields.itemRare / 256)
  b[0x10] = fields.genderRatio
  b[0x11] = fields.eggCycles
  b[0x12] = fields.friendship
  b[0x13] = fields.growthRate
  b[0x14] = fields.eggGroup1
  b[0x15] = fields.eggGroup2
  b[0x16] = fields.ability1
  b[0x17] = fields.ability2
  b[0x18] = fields.safariZoneFleeRate
  b[0x19] = fields.bodyColor + (fields.noFlip and 128 or 0)
  b[0x1A] = 0
  b[0x1B] = 0

  local chars = {}
  for i = 0, 27 do chars[i + 1] = string.char(b[i]) end
  return table.concat(chars)
end

local record = buildRecord({
  baseHP = 45, baseAttack = 49, baseDefense = 49, baseSpeed = 45,
  baseSpAttack = 65, baseSpDefense = 65, type1 = 12, type2 = 12,
  catchRate = 45, expYield = 64, itemCommon = 0, itemRare = 0,
  genderRatio = 31, eggCycles = 20, friendship = 70, growthRate = 3,
  eggGroup1 = 5, eggGroup2 = 5, ability1 = 65, ability2 = 0,
  safariZoneFleeRate = 0, bodyColor = 5, noFlip = true,
})

check("record is 28 bytes", #record == SpeciesInfo.RECORD_SIZE)

local parsed = SpeciesInfo.parseRecord(record)
check("baseHP", parsed.baseHP == 45, parsed.baseHP)
check("baseSpAttack", parsed.baseSpAttack == 65, parsed.baseSpAttack)
check("types", parsed.types[1] == 12 and parsed.types[2] == 12)
check("catchRate", parsed.catchRate == 45, parsed.catchRate)
check("evYield.hp", parsed.evYield.hp == 1, parsed.evYield.hp)
check("evYield.attack", parsed.evYield.attack == 2, parsed.evYield.attack)
check("evYield.defense", parsed.evYield.defense == 3, parsed.evYield.defense)
check("evYield.speed", parsed.evYield.speed == 0, parsed.evYield.speed)
check("evYield.spAttack", parsed.evYield.spAttack == 1, parsed.evYield.spAttack)
check("evYield.spDefense", parsed.evYield.spDefense == 2, parsed.evYield.spDefense)
check("genderRatio", parsed.genderRatio == 31, parsed.genderRatio)
check("growthRate", parsed.growthRate == 3, parsed.growthRate)
check("abilities", parsed.abilities[1] == 65 and parsed.abilities[2] == 0)
check("bodyColor", parsed.bodyColor == 5, parsed.bodyColor)
check("noFlip", parsed.noFlip == true, parsed.noFlip)

-- parseTable over 3 back-to-back records, offset by a leading pad to prove
-- the tableOffset parameter is honored.
local pad = string.rep("\0", 4)
local blob = pad .. record .. record .. record
local rows = SpeciesInfo.parseTable(blob, 4, 3)
check("parseTable returns 3 rows", rows[0] ~= nil and rows[1] ~= nil and rows[2] ~= nil)
check("parseTable row matches single-record parse", rows[1].baseHP == 45)

local ok, err = pcall(SpeciesInfo.parseTable, blob, 4, 100)
check("parseTable errors past end of data", ok == false)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
