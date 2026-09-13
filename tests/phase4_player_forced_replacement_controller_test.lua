package.path = package.path .. ";./?.lua"
local Controller = require("src.core.BattleSceneController")
local InputState = require("src.core.InputState")

local passed, failed = 0, 0
local function check(name, ok)
  if ok then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. name) end
end
local function press(controller, key)
  local input = InputState.new()
  input:update(0)
  input:update(key)
  controller:processInput(input)
end

local engine = { player={hp=0, moves={}}, foe={hp=9}, awaitingForcedSwitch="player" }
function engine:isOver() return false end
function engine:resolveForcedSwitch(side, battler)
  check("only player pending replacement can resolve", side == "player" and self.awaitingForcedSwitch == "player")
  self.player, self.awaitingForcedSwitch = battler, nil
end

local legal = { {slot=2, record={id="bench"}, name="BENCH"} }
local c = Controller.new({
  engine=engine,
  forcedSwitchChoices=function() return legal end,
  onForcedSwitchChoice=function(choice)
    if choice ~= legal[1] or choice.slot ~= 2 then return nil end
    engine:resolveForcedSwitch("player", {hp=12, moves={}})
    return { "FAINTED, come back!\nGo! BENCH!" }
  end,
})
c:_setMessages({"FAINTED!", "Choose a replacement."}, Controller.PARTY)
c:advanceMessage()
check("faint messages retain pending switch before final acknowledgement",
  engine.awaitingForcedSwitch == "player" and c.state == Controller.MESSAGES)
c:advanceMessage()
check("final faint message enters forced PARTY rather than ACTION",
  c.state == Controller.PARTY and #c.partyChoices == 1)
press(c, InputState.B_BUTTON)
check("cancel cannot clear pending forced replacement",
  c.state == Controller.PARTY and engine.awaitingForcedSwitch == "player")
legal = {}
press(c, InputState.A_BUTTON)
check("empty or invalid candidate set cannot resolve pending replacement",
  c.state == Controller.PARTY and engine.awaitingForcedSwitch == "player")
legal = { {slot=2, record={id="bench"}, name="BENCH"} }
press(c, InputState.A_BUTTON)
check("legal bench resolves exactly once and queues replacement message",
  engine.awaitingForcedSwitch == nil and engine.player.hp == 12
    and c.state == Controller.MESSAGES and c:message():find("Go! BENCH", 1, true) ~= nil)
c:advanceMessage()
check("replacement returns to ACTION only after its message", c.state == Controller.ACTION)

print(("phase4_player_forced_replacement_controller_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
