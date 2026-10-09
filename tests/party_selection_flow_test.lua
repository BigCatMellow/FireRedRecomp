-- No-ROM test of a normal field Party slot's reduced SUMMARY/CANCEL flow.
-- Run: lua5.1 tests/party_selection_flow_test.lua
package.path = package.path .. ";./?.lua"

local PartyScreen = require("src.core.PartyScreen")
local PartySelectionFlow = require("src.core.PartySelectionFlow")
local PartyModel = require("src.core.PartyModel")
local InputState = require("src.core.InputState")
local WildPokemonFactory = require("src.core.WildPokemonFactory")
local Rng = require("src.core.Rng")

local passed, failed = 0, 0
local function check(label, value)
  if value then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. label)
  end
end
local species = {
  baseHP=30, baseAttack=56, baseDefense=35, baseSpeed=72,
  baseSpAttack=25, baseSpDefense=35, types={0,0}, catchRate=255,
  genderRatio=127, friendship=70, growthRate=0, abilities={50,62},
}
local moves = { [33]={pp=35,power=35}, [39]={pp=30,power=0} }
local natures = {}
for i=0,24 do natures[i]={attack=0,defense=0,speed=0,spAttack=0,spDefense=0} end
local rawName = string.char(0xC9,0xBE,0xC7,0xC4,0xB6,0xB8,0xC7,0xFF,0,0)
local trainerName = string.char(0xCC,0xBF,0xBE,0xFF,0xFF,0xFF,0xFF)
local function makeRecord(seed)
  local mon = WildPokemonFactory.generate({
    species=19, level=5, speciesInfo=species,
    learnset={{level=1,move=33},{level=1,move=39}},
    battleMoves=moves, natures=natures, rng=Rng.new(seed),
    speciesName=rawName, trainer={id=0x12345678,name=trainerName,gender=0},
    metLocation=1,
  })
  return WildPokemonFactory.capture(mon, {ball=4})
end
local function tap(screen, keys)
  local input = InputState.new()
  input:update(0)
  input:update(InputState.buildMask(keys))
  screen:processInput(input)
end
local party = PartyModel.new()
party:add(makeRecord(10))
party:add(makeRecord(11))
local before = {
  party:get(1).box, party:get(2).box,
  party:get(1).hp, party:get(2).hp,
  party:get(1).status, party:get(2).status,
}
local function unchanged()
  return party:size() == 2
    and party:get(1).box == before[1] and party:get(2).box == before[2]
    and party:get(1).hp == before[3] and party:get(2).hp == before[4]
    and party:get(1).status == before[5] and party:get(2).status == before[6]
end

local list = PartyScreen.new(party)
local okUnselected = pcall(function() PartySelectionFlow.new(list) end)
check("submenu cannot open without a confirmed slot", not okUnselected)
tap(list, { DPAD_DOWN=true })
tap(list, { A_BUTTON=true })
check("second slot confirmed", list.confirmedSlot == 2)
local flow = PartySelectionFlow.new(list)
check("actions open for confirmed slot 2", flow.state == PartySelectionFlow.ACTIONS
  and flow.slot == 2 and flow:currentAction() == PartySelectionFlow.ACTION_SUMMARY)
check("unopened summary does not leak data", flow:summaryData() == nil)
tap(flow, { DPAD_UP=true })
check("two-action cursor is no-wrap at top", flow.cursor.cursorPos == 0)
tap(flow, { A_BUTTON=true })
check("SUMMARY opens one read-only page", flow.state == PartySelectionFlow.SUMMARY)
local info = flow:summaryData()
check("summary reads selected slot", info and info.slot == 2
  and info.nickname and #info.nickname > 0 and info.maxHp == party:get(2).maxHP)
check("summary reads real XP and combat stats", info
  and type(info.experience) == "number" and info.experience >= 0
  and info.attack == party:get(2).attack)
check("summary has not modified party", unchanged())
tap(flow, { DPAD_DOWN=true })
check("summary ignores action cursor input", flow.state == PartySelectionFlow.SUMMARY
  and flow.cursor.cursorPos == 0)
tap(flow, { A_BUTTON=true })
check("A cannot leave bounded summary page", flow.state == PartySelectionFlow.SUMMARY)
tap(flow, { B_BUTTON=true })
check("B from SUMMARY returns to actions for same slot",
  flow.state == PartySelectionFlow.ACTIONS and flow.slot == 2)
tap(flow, { B_BUTTON=true })
check("B from action menu returns to party list", flow:isDone())
check("closed menu ignores subsequent input", (function()
  tap(flow, { A_BUTTON=true })
  return flow:isDone()
end)())
check("resume list keeps previous cursor, not new-party default", list:resumeBrowsing()
  and list.state == PartyScreen.BROWSING and list:cursorRow() == 1)
check("back chain does not alter party", unchanged())
tap(list, { B_BUTTON=true })
check("B from list closes toward original START", list.state == PartyScreen.CLOSED)

-- Independent CANCEL-by-A route and no-wrap bottom behavior.
local secondList = PartyScreen.new(party)
tap(secondList, { A_BUTTON=true })
local cancelFlow = PartySelectionFlow.new(secondList)
tap(cancelFlow, { DPAD_DOWN=true })
tap(cancelFlow, { DPAD_DOWN=true })
check("action cursor no-wrap at bottom", cancelFlow.cursor.cursorPos == 1)
check("bottom action is CANCEL", cancelFlow:currentAction() == PartySelectionFlow.ACTION_CANCEL)
tap(cancelFlow, { A_BUTTON=true })
check("A on CANCEL returns to same party slot list", cancelFlow:isDone()
  and secondList:resumeBrowsing() and secondList:cursorRow() == 0)
check("CANCEL did not mutate party", unchanged())

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
