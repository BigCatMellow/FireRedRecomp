-- No-ROM test of a normal field Party slot's reduced SUMMARY/CANCEL flow.
-- Run: lua5.1 tests/party_selection_flow_test.lua
package.path = package.path .. ";./?.lua"

local PartyScreen = require("src.core.PartyScreen")
local PartySelectionFlow = require("src.core.PartySelectionFlow")
local PartyModel = require("src.core.PartyModel")
local InputState = require("src.core.InputState")
local WildPokemonFactory = require("src.core.WildPokemonFactory")
local Rng = require("src.core.Rng")
local BoxPokemonCodec = require("src.core.BoxPokemonCodec")
local StartMenu = require("src.core.StartMenu")

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

-- Source c75f352 src/menu.c:425-450: new A, new B, then exact repeated
-- UP-only/DOWN-only mask. Observe calls as well as cursor position: a
-- two-row cursor can hide a missing repeat implementation at its endpoints.
local function actionFlow()
  local screen = PartyScreen.new(party)
  tap(screen, { A_BUTTON=true })
  return PartySelectionFlow.new(screen)
end
for _, direction in ipairs({ InputState.DPAD_UP, InputState.DPAD_DOWN }) do
  local repeated = actionFlow()
  local calls = 0
  local move = repeated.cursor.moveCursorNoWrap
  repeated.cursor.moveCursorNoWrap = function(cursor, delta)
    calls = calls + 1
    return move(cursor, delta)
  end
  local input = InputState.new()
  input:update(direction)
  repeated:processInput(input)
  check("fresh direction invokes clamped move " .. direction, calls == 1)
  for _ = 1, 39 do input:update(direction); repeated:processInput(input) end
  check("no movement calls before held repeat " .. direction, calls == 1)
  input:update(direction); repeated:processInput(input)
  check("held direction repeats after 40 ticks " .. direction, calls == 2)
  for _ = 1, 4 do input:update(direction); repeated:processInput(input) end
  check("no movement calls between repeats " .. direction, calls == 2)
  input:update(direction); repeated:processInput(input)
  check("held direction repeats every 5 ticks " .. direction, calls == 3)
  check("repeated navigation stays clamped " .. direction,
    repeated.cursor.cursorPos == (direction == InputState.DPAD_UP and 0 or 1))
end
for _, mask in ipairs({ 0xC0, 0x50, 0x60, 0x90, 0xA0, 0xF0 }) do
  local chord = actionFlow()
  chord.cursor.cursorPos = 1
  local calls = 0
  chord.cursor.moveCursorNoWrap = function() calls = calls + 1 end
  local input = InputState.new()
  for _ = 1, 46 do input:update(mask); chord:processInput(input) end
  check("direction chord never moves on press or repeat " .. mask, calls == 0)
end
local priority = actionFlow()
tap(priority, { A_BUTTON=true, B_BUTTON=true, DPAD_DOWN=true })
check("new A wins over B and D-pad", priority.state == PartySelectionFlow.SUMMARY
  and priority.cursor.cursorPos == 0)
local backPriority = actionFlow()
tap(backPriority, { B_BUTTON=true, DPAD_DOWN=true })
check("new B wins over D-pad", backPriority:isDone() and backPriority.cursor.cursorPos == 0)

-- Execute actual production functions, including the complete love.update
-- dispatch chain, without loading ROM/LÖVE bootstrap. No copied dispatcher:
-- only dependencies outside these functions are synthetic/no-op witnesses.
local file = assert(io.open("main.lua", "r"))
local mainSource = file:read("*a")
file:close()
local function functionSource(signature)
  local first = assert(mainSource:find(signature, 1, true), signature)
  local last = assert(mainSource:find("\nend\n", first, true), signature .. " end")
  return mainSource:sub(first, last + 4)
end
local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, v in pairs(value) do result[key] = copy(v) end
  return result
end
local function equal(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not equal(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end
local function savedRecord(seed, egg)
  local record = makeRecord(seed)
  local decoded = BoxPokemonCodec.decode(record.box)
  decoded.nickname = string.char(egg and 0xBC or 0xBB, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0)
  decoded.isEgg, decoded.substructs[3].isEgg = egg, egg
  decoded.substructs[0].species = egg and 25 or 19
  decoded.substructs[0].experience = egg and 2345 or 1234
  decoded.substructs[1].pp = { 7, 11, 0, 0 }
  record.box = BoxPokemonCodec.encode(decoded)
  record.level, record.hp, record.maxHP, record.status = 17, 23, 47, 8
  record.attack, record.defense, record.speed = 31, 37, 41
  record.spAttack, record.spDefense = 43, 53
  return record
end
local ordinary, egg = savedRecord(21, false), savedRecord(22, true)
local sessionState = {
  saveBlock1 = { playerPartyCount=2, playerParty={ ordinary, egg },
    money=321, flags={ 1, 2 }, bag={ { item=4, quantity=9 } }, location={ x=8, y=9 } },
  saveBlock2 = { pokedex={ seen=string.rep("\0", 52) } },
  battle = { turn=7, hp=13 },
}
local savedBefore = copy(sessionState)
local calls = { start=0, bag=0, move=0, interaction=0, save=0 }
local environment = setmetatable({
  world = {}, newGame = { session = { state=sessionState,
    getFlag=function(_, id) return id == 0x828 end } },
  Battle = { PartyScreen=PartyScreen, PartySelectionFlow=PartySelectionFlow,
    StartMenu=StartMenu, DexTracker=require("src.core.DexTracker"),
    EarlyStory={ FLAG_SYS_POKEMON_GET=0x828 } },
  InputState=InputState, inputState=InputState.new(),
  tickAccumulator=0, FIXED_TICK=1, scheduler={ runTasks=function() end },
  love={ keyboard={ isDown=function() return false end } },
  walkActive=true, PlayerMovement={ DOWN=1, UP=2, LEFT=3, RIGHT=4 },
  playerMovement={ tileX=8, tileY=9, tryMove=function(self)
    calls.move = calls.move + 1; self.tileX = self.tileX + 1
  end },
  tryStartInteraction=function() calls.interaction = calls.interaction + 1 end,
  saveGame=function() calls.save = calls.save + 1 end,
  addLine=function() end,
}, { __index=_G })
for _, signature in ipairs({ "world.openStartMenu = function()",
    "world.closeStartMenu = function()", "world.handleStartMenuSelection = function()",
    "world.partyScreenLines = function()", "function love.update(dt)" }) do
  local chunk = assert(loadstring(functionSource(signature), "@production:" .. signature))
  setfenv(chunk, environment)()
end
local world = environment.world
local function tick(mask)
  world.replayInputMask = mask
  environment.love.update(1)
end
local function press(mask) tick(0); tick(mask) end
local function intact(label)
  check(label .. ": every saved field and encoded byte unchanged", equal(sessionState, savedBefore)
    and sessionState.saveBlock1.playerParty[1] == ordinary
    and sessionState.saveBlock1.playerParty[2] == egg)
end
local function isolated(label, startCalls, list, listCalls)
  check(label .. ": production field/Bag/START isolation",
    calls.start == startCalls and calls.bag == 0 and calls.move == 0
      and calls.interaction == 0 and calls.save == 0
      and environment.playerMovement.tileX == 8 and environment.playerMovement.tileY == 9)
  if list then check(label .. ": list input not consumed", list.calls == listCalls) end
  intact(label)
end
world.openStartMenu()
local retainedStart = world.startMenu
local startInput = retainedStart.processInput
retainedStart.processInput = function(self, input)
  calls.start = calls.start + 1
  return startInput(self, input)
end
for slot = 1, 2 do
  press(InputState.A_BUTTON) -- actual START dispatch, not a directly created list
  local currentList = assert(world.partyScreen)
  check("normal START opens live adapter slot test " .. slot,
    currentList.party:get(1) == ordinary and currentList.party:get(2) == egg
      and world.partySelection == nil)
  if slot == 2 then press(InputState.DPAD_DOWN) end
  local listInput = currentList.processInput
  currentList.calls = 0
  currentList.processInput = function(self, input)
    self.calls = self.calls + 1
    return listInput(self, input)
  end
  press(InputState.A_BUTTON)
  local active = assert(world.partySelection)
  check("selection A opens actions only, without cascading " .. slot,
    active.slot == slot and active.state == PartySelectionFlow.ACTIONS)
  local listCalls, startCalls = currentList.calls, calls.start
  -- A competing lower-priority Bag is a sentinel, not a real simultaneous UI.
  world.bagScreenActive = true
  world.bagScreen = { processInput=function() calls.bag = calls.bag + 1 end,
    isDone=function() return false end }
  for _ = 1, 45 do tick(InputState.A_BUTTON) end
  check("held selection A cannot open summary " .. slot, active.state == PartySelectionFlow.ACTIONS)
  isolated("actions held A " .. slot, startCalls, currentList, listCalls)
  press(InputState.A_BUTTON)
  check("fresh A enters summary " .. slot, active.state == PartySelectionFlow.SUMMARY)
  local projection = active:summaryData()
  check("literal saved projection " .. slot, projection.slot == slot
    and projection.nickname == (slot == 2 and "B" or "A")
    and projection.species == (slot == 2 and 25 or 19) and projection.isEgg == (slot == 2)
    and projection.level == 17 and projection.hp == 23 and projection.maxHp == 47
    and projection.status == 8 and projection.attack == 31 and projection.defense == 37
    and projection.speed == 41 and projection.spAttack == 43 and projection.spDefense == 53
    and projection.experience == (slot == 2 and 2345 or 1234))
  local lines = world.partyScreenLines()
  check("ordinary versus explicit reduced Egg label " .. slot,
    (slot == 2 and lines[1] == "EGG - saved-data projection  B  (B: back)")
      or (slot == 1 and lines[1] == "SUMMARY  A  (B: back)"))
  isolated("summary projection " .. slot, startCalls, currentList, listCalls)
  for _, mask in ipairs({ 0x40, 0x80, 0x20, 0x10, 0x200, 0x100, 0x1, 0x8 }) do
    press(mask)
    for _ = 1, 45 do tick(mask) end
    check("summary cannot cycle/page/change projection " .. slot .. "/" .. mask,
      active.state == PartySelectionFlow.SUMMARY and active.slot == slot
        and equal(active:summaryData(), projection))
    isolated("summary input " .. slot .. "/" .. mask, startCalls, currentList, listCalls)
  end
  -- Returned tables are not saved-record aliases.
  projection.hp, projection.attack, projection.nickname = -1, -1, "changed"
  intact("mutating returned projection " .. slot)
  press(InputState.B_BUTTON)
  check("summary B returns only to actions " .. slot,
    world.partySelection == active and active.state == PartySelectionFlow.ACTIONS)
  for _ = 1, 45 do tick(InputState.B_BUTTON) end
  check("held B cannot cascade to list " .. slot, world.partySelection == active)
  isolated("summary B and held B " .. slot, startCalls, currentList, listCalls)
  if slot == 2 then
    press(InputState.DPAD_DOWN)
    press(InputState.A_BUTTON) -- action CANCEL route
  else
    press(InputState.B_BUTTON)
  end
  check("action cancel resumes same list without consuming input " .. slot,
    world.partySelection == nil and world.partyScreen == currentList
      and currentList.state == PartyScreen.BROWSING and currentList:cursorRow() == slot - 1)
  isolated("action cancellation " .. slot, startCalls, currentList, listCalls)
  local heldCancel = slot == 2 and InputState.A_BUTTON or InputState.B_BUTTON
  for _ = 1, 45 do tick(heldCancel) end
  check("held action cancel does not reopen or close resumed list " .. slot,
    world.partySelection == nil and world.partyScreen == currentList)
  world.bagScreen, world.bagScreenActive = nil, false
  if slot == 2 then press(InputState.DPAD_DOWN); press(InputState.A_BUTTON)
  else press(InputState.B_BUTTON) end
  check("list cancellation returns to retained START " .. slot,
    world.partyScreen == nil and not world.partyScreenActive and world.partySelection == nil
      and world.startMenu == retainedStart and retainedStart.state == StartMenu.OPEN)
  isolated("list cancellation " .. slot, startCalls)
end
-- Full cleanup and reopening must not reuse a stale selected mon/action.
world.closeStartMenu()
check("Party cleanup clears flow and list", world.partySelection == nil and world.partyScreen == nil)
world.openStartMenu(); press(InputState.A_BUTTON)
check("reopened Party starts in fresh browsing state", world.partySelection == nil
  and world.partyScreen.state == PartyScreen.BROWSING and world.partyScreen:cursorRow() == 0)
intact("reopen")
-- Positive control: the extracted production update really can reach field
-- movement/interaction when all menus close; isolation assertions above are
-- not passing because those branches were omitted or permanently disabled.
world.closeStartMenu()
press(InputState.DPAD_DOWN + InputState.A_BUTTON)
check("production field controls become reachable after menus close",
  calls.move == 1 and calls.interaction == 1 and environment.playerMovement.tileX == 9)
intact("field positive control does not write synthetic session")

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
