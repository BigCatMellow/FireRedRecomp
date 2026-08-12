-- Run: lua5.1 tests/trainer_party_test.lua
package.path = package.path .. ";./?.lua"
local TrainerParty = require("import.TrainerParty")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- TRAINER_YOUNGSTER_BEN's party (partyFlags=0, NoItemDefaultMoves, 8-byte
-- stride), exactly as it appears in the real ROM: RATTATA lvl 11, EKANS lvl 11.
local benPartyBytes = string.char(0x00, 0x00, 0x0b, 0x00, 0x13, 0x00, 0x00, 0x00)
  .. string.char(0x00, 0x00, 0x0b, 0x00, 0x17, 0x00, 0x00, 0x00)

local trainer = { partyFlags = 0, partySize = 2, partyPtr = 0x08000000 }
local party = TrainerParty.resolve(trainer, benPartyBytes)
check("mon0 species", party[0].species == 19, party[0].species)
check("mon0 lvl", party[0].lvl == 11, party[0].lvl)
check("mon1 species", party[1].species == 23, party[1].species)
check("no heldItem/moves fields for this layout", party[0].heldItem == nil and party[0].moves == nil)

-- Elite Four Lorelei's first mon (partyFlags=3, ItemCustomMoves, 16-byte
-- stride): DEWGONG lvl 52 iv 250, held item NONE, ICE_BEAM/SURF/HAIL/SAFEGUARD.
local loreleiBytes = string.char(
  0xfa, 0x00, -- iv = 250
  0x34,       -- lvl = 52
  0x00,       -- pad
  0x57, 0x00, -- species = 87 (DEWGONG)
  0x00, 0x00, -- heldItem = 0
  0x3a, 0x00, -- move0 = 58 (ICE_BEAM)
  0x39, 0x00, -- move1 = 57 (SURF)
  0x02, 0x01, -- move2 = 258 (HAIL)
  0xdb, 0x00  -- move3 = 219 (SAFEGUARD)
)
local loreleiTrainer = { partyFlags = 3, partySize = 1, partyPtr = 0x08000000 }
local loreleiParty = TrainerParty.resolve(loreleiTrainer, loreleiBytes)
local dewgong = loreleiParty[0]
check("dewgong species", dewgong.species == 87, dewgong.species)
check("dewgong lvl", dewgong.lvl == 52, dewgong.lvl)
check("dewgong iv", dewgong.iv == 250, dewgong.iv)
check("dewgong heldItem", dewgong.heldItem == 0, dewgong.heldItem)
check("dewgong moves", dewgong.moves[0] == 58 and dewgong.moves[1] == 57 and dewgong.moves[2] == 258 and dewgong.moves[3] == 219)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
