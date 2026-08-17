-- Pure PartyScreen.lua state-machine coverage (no ROM needed -- party
-- records are built the same way tests/battle_party_bridge_test.lua does,
-- through the already-pure WildPokemonFactory.generate/capture pair, which
-- needs no ROM bytes, only plain Lua tables standing in for decoded ROM
-- data).
-- Run: lua5.1 tests/party_screen_test.lua
package.path = package.path .. ";./?.lua"

local PartyScreen = require("src.core.PartyScreen")
local PartyModel = require("src.core.PartyModel")
local InputState = require("src.core.InputState")
local WildPokemonFactory = require("src.core.WildPokemonFactory")
local Rng = require("src.core.Rng")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

local species = {
  baseHP=30, baseAttack=56, baseDefense=35, baseSpeed=72,
  baseSpAttack=25, baseSpDefense=35, types={0,0}, catchRate=255,
  genderRatio=127, friendship=70, growthRate=0, abilities={50,62},
}
local moves = { [33]={pp=35, power=35}, [39]={pp=30, power=0} }
local natures = {}
for i = 0, 24 do
  natures[i] = {attack=0,defense=0,speed=0,spAttack=0,spDefense=0}
end
-- Charmap bytes for "NIDORAN" (arbitrary stand-in species display name --
-- CreateBoxMon defaults nickname to the species name, see PartyScreen's
-- header citation).
local rawSpeciesName = string.char(0xC9,0xBE,0xC7,0xC4,0xB6,0xB8,0xC7,0xFF,0,0)
local trainerName = string.char(0xCC,0xBF,0xBE,0xFF,0xFF,0xFF,0xFF)

local function makeRecord(seed, level)
  local instance = WildPokemonFactory.generate({
    species=19, level=level or 5, speciesInfo=species,
    learnset={{level=1,move=33},{level=1,move=39}},
    battleMoves=moves, natures=natures, rng=Rng.new(seed),
    speciesName=rawSpeciesName, trainer={id=0x12345678,name=trainerName,gender=0},
    metLocation=1,
  })
  return WildPokemonFactory.capture(instance, {ball=4})
end

local function tap(screen, buttonMask)
  local input = InputState.new()
  input:update(0)
  input:update(buttonMask)
  screen:processInput(input)
end

-- 1. A party with fewer than 6 living mons only shows that many rows plus
-- CANCEL, not 6 fixed rows (real party array has no gaps).
local party = PartyModel.new()
party:add(makeRecord(1))
party:add(makeRecord(2))
party:add(makeRecord(3))
local screen = PartyScreen.new(party)
check("cursor sized to party:size()+1 (3 mons + CANCEL)", screen.cursor.maxCursorPos == 3)

local rows = {}
for row, isCancel, data in screen:iterateRows() do
  rows[#rows + 1] = { row = row, isCancel = isCancel, data = data }
end
check("iterateRows yields exactly size()+1 rows", #rows == 4, #rows)
check("first 3 rows are mons, not CANCEL", not rows[1].isCancel and not rows[2].isCancel and not rows[3].isCancel)
check("4th row is CANCEL", rows[4].isCancel == true and rows[4].data == nil)
check("row data reads real cached level/HP off the party record",
  rows[1].data.level == 5 and rows[1].data.hp == rows[1].data.maxHp
    and rows[1].data.slot == 1)
check("row data nickname decodes the real species-name-as-nickname default",
  rows[1].data.nickname ~= nil and #rows[1].data.nickname > 0, rows[1].data.nickname)

-- 2. Cursor wraparound matches real UpdatePartySelectionSingleLayout: Up
-- from slot 0 goes to CANCEL, Down from CANCEL goes to slot 0, Down from
-- the last mon goes to CANCEL.
check("cursor starts at row 0", screen:cursorRow() == 0)
tap(screen, InputState.buildMask({ DPAD_UP = true }))
check("Up from slot 0 wraps to CANCEL", screen:cursorRow() == 3, screen:cursorRow())
check("cursorRow() at CANCEL matches isCancelRow", screen:isCancelRow(screen:cursorRow()))
tap(screen, InputState.buildMask({ DPAD_DOWN = true }))
check("Down from CANCEL wraps to slot 0", screen:cursorRow() == 0, screen:cursorRow())
-- From slot 0: Up -> CANCEL (row 3), Up -> last mon (row 2, wrapping past
-- CANCEL), Up -> row 1.
tap(screen, InputState.buildMask({ DPAD_UP = true }))
tap(screen, InputState.buildMask({ DPAD_UP = true }))
check("2 Ups from slot 0 lands on the last mon (slot 3, row 2)", screen:cursorRow() == 2, screen:cursorRow())
tap(screen, InputState.buildMask({ DPAD_DOWN = true }))
check("Down from the last mon goes to CANCEL", screen:cursorRow() == 3, screen:cursorRow())

-- 3. Up/Down auto-repeats (real gMain.newAndRepeatedKeys), unlike StartMenu.
local repeatScreen = PartyScreen.new(party)
local heldInput = InputState.new()
heldInput:update(0)
heldInput:update(InputState.buildMask({ DPAD_DOWN = true })) -- newly pressed: row 0 -> 1
repeatScreen:processInput(heldInput)
check("first Down moves one row", repeatScreen:cursorRow() == 1, repeatScreen:cursorRow())
local moved = false
for _ = 1, 60 do
  heldInput:update(InputState.buildMask({ DPAD_DOWN = true })) -- held
  repeatScreen:processInput(heldInput)
  if repeatScreen:cursorRow() ~= 1 then moved = true end
end
check("holding Down auto-repeats the cursor (real newAndRepeatedKeys)", moved)

-- 4. A on a mon confirms that slot (real HandleChooseMonSelection's
-- default case opens the per-mon submenu -- out of this module's scope,
-- see header -- but confirming the slot itself is in scope).
local confirmScreen = PartyScreen.new(party)
tap(confirmScreen, InputState.buildMask({ DPAD_DOWN = true })) -- row 0 -> row 1 (slot 2)
tap(confirmScreen, InputState.buildMask({ A_BUTTON = true }))
check("A on a mon confirms that slot", confirmScreen.state == PartyScreen.CONFIRMED
  and confirmScreen.confirmedSlot == 2)
check("isDone true once confirmed", confirmScreen:isDone())

-- 5. A on CANCEL behaves exactly like B (real PartyMenuButtonHandler: A on
-- SLOT_CANCEL returns the same result as a B press).
local cancelViaA = PartyScreen.new(party)
tap(cancelViaA, InputState.buildMask({ DPAD_UP = true })) -- row 0 -> CANCEL
tap(cancelViaA, InputState.buildMask({ A_BUTTON = true }))
check("A on CANCEL closes with no confirmed slot", cancelViaA.state == PartyScreen.CLOSED
  and cancelViaA.confirmedSlot == nil)

-- 6. B anywhere closes with no confirmed slot (real HandleChooseMonCancel
-- default case: back to the Start menu).
local cancelViaB = PartyScreen.new(party)
tap(cancelViaB, InputState.buildMask({ DPAD_DOWN = true }))
tap(cancelViaB, InputState.buildMask({ B_BUTTON = true }))
check("B closes with no confirmed slot regardless of cursor position",
  cancelViaB.state == PartyScreen.CLOSED and cancelViaB.confirmedSlot == nil)

-- 7. Once done, further input is inert.
local doneScreen = PartyScreen.new(party)
tap(doneScreen, InputState.buildMask({ B_BUTTON = true }))
tap(doneScreen, InputState.buildMask({ DPAD_DOWN = true }))
check("processInput after CLOSED does nothing further", doneScreen:cursorRow() == 0)

-- 8. A single-mon party still has a working CANCEL row (2 total rows).
local soloParty = PartyModel.new()
soloParty:add(makeRecord(9))
local soloScreen = PartyScreen.new(soloParty)
check("solo party has 1 mon row + CANCEL", soloScreen.cursor.maxCursorPos == 1)
tap(soloScreen, InputState.buildMask({ DPAD_UP = true }))
check("Up from the only mon wraps to CANCEL in a 1-mon party", soloScreen:cursorRow() == 1)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
