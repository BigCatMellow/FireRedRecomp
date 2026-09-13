package.path = package.path .. ";./?.lua"
local Orchestrator = require("src.core.TrainerBattleOrchestrator")
local Controller = require("src.core.BattleSceneController")

local passed, failed = 0, 0
local function check(name, ok) if ok then passed=passed+1 else failed=failed+1; print("FAIL: "..name) end end
local foes = { {species=1, hp=8}, {species=2, hp=9} }
local engine = { awaitingForcedSwitch="foe", foe=foes[1] }
function engine:resolveForcedSwitch(side, battler)
  check("forced switch is foe-only", side == "foe")
  self.foe, self.awaitingForcedSwitch = battler, nil
end
local rewards = {}
local orch = Orchestrator.new({foes=foes, toBattler=function(f) return f end})
local c = Controller.new({engine={player={hp=1}, foe={hp=1}}, moves={}, typeChart={}, rng={},
  -- constructor only needs player/foe for its display state in this test
  onMessagesComplete=function() end})
-- Replace its message stream directly: the callback must not run before the
-- last faint/message entry has been acknowledged.
c.onMessagesComplete = function()
  if engine.awaitingForcedSwitch == "foe" then
    local incoming = orch:resolveFoeReplacement(engine, function(_, slot, final)
      rewards[#rewards+1] = {slot=slot, final=final}
    end)
    return { "TRAINER sent out "..incoming.species.."!" }
  end
end
c:_setMessages({{text="FOE fainted!"}, {text="TRAINER must send out a new POKEMON!"}}, Controller.ACTION)
c:advanceMessage()
check("replacement is not resolved before final faint/message acknowledgement", engine.awaitingForcedSwitch == "foe")
c:advanceMessage()
check("replacement resolves after ordered messages", engine.awaitingForcedSwitch == nil and engine.foe.species == 2)
check("first foe reward settles once and is not final", #rewards == 1 and rewards[1].slot == 1 and not rewards[1].final)
check("incoming foe message is queued after replacement", c:message() == "TRAINER sent out 2!")
c:advanceMessage()
check("controller returns to action only after incoming message", c.state == Controller.ACTION)
orch:resolveFinalFoeReward(function(_, slot, final) rewards[#rewards+1]={slot=slot, final=final} end)
check("final foe settles once after final victory", #rewards == 2 and rewards[2].slot == 2 and rewards[2].final)
local ok = pcall(function() orch:resolveFinalFoeReward() end)
check("duplicate final settlement is rejected", not ok)
print(("phase4_foe_only_multimon_controller_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
