package.path = package.path .. ";./?.lua"
local Controller = require("src.core.BattleSceneController")
local InputState = require("src.core.InputState")

local passed, failed = 0, 0
local function check(name, ok)
  if ok then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. name) end
end
local function press(controller, key)
  local input = InputState.new(); input:update(0); input:update(key)
  controller:processInput(input)
end

local engine = { player={hp=12, moves={}}, foe={hp=20}, turn=0, rng={state=0xC0FFEE} }
function engine:isOver() return false end
function engine:runTurn(action, foe)
  check("controller supplies existing engine switch action", action.action == "switch" and action.battler.hp == 18)
  self.turn = self.turn + 1
  self.player = action.battler
  self.foeSawIncoming = self.player
  return { {type="switch", side="player"}, {type="useMove", side="foe", move=1} }
end

local legal = {}
local switches = 0
local c
c = Controller.new({
  engine=engine,
  voluntarySwitchChoices=function() return legal end,
  onVoluntarySwitchChoice=function(choice)
    -- Model the main seam's current-list/name revalidation, not mere slot UI.
    if choice ~= legal[1] or choice.slot ~= 2 or choice.name ~= "BENCH" then return nil end
    switches = switches + 1
    c:_runTurn({action="switch", battler={hp=18, moves={}}})
    return nil
  end,
})
while c:message() do c:advanceMessage() end
press(c, InputState.DPAD_DOWN)
press(c, InputState.A_BUTTON)
check("no legal bench never enters selector or consumes a turn", c.state == Controller.MESSAGES and engine.turn == 0 and switches == 0 and engine.player.hp == 12)
while c:message() do c:advanceMessage() end
check("no-bench notice returns to ACTION unchanged", c.state == Controller.ACTION and engine.turn == 0 and engine.player.hp == 12)

legal = { {slot=2, record={id="bench"}, name="BENCH"} }
press(c, InputState.A_BUTTON)
check("ACTION POKEMON opens voluntary PARTY only for a legal bench", c.state == Controller.PARTY and c.partyMode == "voluntary" and #c.partyChoices == 1)
press(c, InputState.B_BUTTON)
check("voluntary selector cancel returns to ACTION unchanged", c.state == Controller.ACTION and engine.turn == 0 and switches == 0 and engine.player.hp == 12)
press(c, InputState.A_BUTTON)
legal = {}
press(c, InputState.A_BUTTON)
check("stale choice is re-read and rejected before turn dispatch", c.state == Controller.PARTY and engine.turn == 0 and switches == 0)
-- The sole displayed bench can become invalid between opening PARTY and the
-- next input.  B must still close a voluntary selector before its refreshed
-- empty choice list returns; it must not dispatch a turn, advance RNG, or
-- replace the active battler.  (Forced PARTY deliberately has the opposite
-- cancellation rule and is covered by the ROM seam.)
local staleActive, staleRng = engine.player, engine.rng.state
press(c, InputState.B_BUTTON)
check("stale empty voluntary selector cancels to ACTION without engine mutation",
  c.state == Controller.ACTION and engine.turn == 0 and switches == 0
    and engine.player == staleActive and engine.rng.state == staleRng)
legal = { {slot=2, record={id="bench"}, name="BENCH"} }
press(c, InputState.A_BUTTON)
c:_refreshPartyChoices()
local forged = c.onVoluntarySwitchChoice({slot=2, record=legal[1].record, name="FORGED"})
check("forged choice is rejected by callback revalidation", forged == nil and engine.turn == 0 and switches == 0)
press(c, InputState.A_BUTTON)
check("legal choice switches exactly once and foe sees incoming same turn", switches == 1 and engine.turn == 1 and engine.player.hp == 18 and engine.foeSawIncoming == engine.player and c.state == Controller.MESSAGES)

print(("phase4_player_voluntary_switch_controller_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
