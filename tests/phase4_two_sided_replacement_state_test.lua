package.path = package.path .. ";./?.lua"
local Engine = require("src.core.BattleEngine")
local Controller = require("src.core.BattleSceneController")
local InputState = require("src.core.InputState")
local Data = require("tests.battle_test_data")

local pass, fail = 0, 0
local function check(name, ok)
  if ok then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. name) end
end
local stats = {hp=10,attack=5,defense=5,speed=5,spAttack=5,spDefense=5}
local function battle(replacements)
  return Engine.new({
    player=Engine.makeBattler({species=1,level=5,stats=stats,types={12},moves={}}),
    foe=Engine.makeBattler({species=4,level=5,stats=stats,types={10},moves={}}),
    moves=Data.moves,typeChart=Data.typeChart,rng={next16=function() return 0 end},
    hasReplacement=function(side) return replacements[side] end,
  })
end
local b, e = battle({player=true,foe=true}), {}
b.player.hp, b.foe.hp = 0, 0
b:beginFaintSequence(); b:recordFaint("foe",e); b:recordFaint("player",e); b:finalizeFaintSequence(e)
check("records ordered faint events before requests", e[1].type == "faint" and e[2].type == "faint" and e[3].type == "forcedSwitchNeeded")
check("queues retail player then foe order", b.awaitingForcedSwitch == "player" and b.pendingForcedSwitches[2] == "foe")
local fresh = Engine.makeBattler({species=1,level=5,stats=stats,types={12},moves={}})
b:resolveForcedSwitch("player",fresh)
check("resolution advances scalar compatibility head", b.awaitingForcedSwitch == "foe")
b = battle({player=false,foe=false}); e = {}; b.player.hp,b.foe.hp=0,0
b:beginFaintSequence(); b:recordFaint("player",e); b:recordFaint("foe",e); b:finalizeFaintSequence(e)
check("simultaneous exhaustion is one draw terminal", b.outcome == "playerDrew" and #b.pendingForcedSwitches == 0 and e[#e].type == "battleEnd")
for _, case in ipairs({{"player", "playerLost"}, {"foe", "playerWon"}}) do
  b, e = battle({player=false,foe=false}), {}
  b:battler(case[1]).hp = 0; b:beginFaintSequence(); b:recordFaint(case[1],e); b:finalizeFaintSequence(e)
  check("one-side exhaustion emits " .. case[2], b.outcome == case[2] and #b.pendingForcedSwitches == 0)
end
b, e = battle({player=true,foe=true}), {}
b.player.hp,b.foe.hp=0,0; b:beginFaintSequence(); b:recordFaint("player",e); b:recordFaint("foe",e); b:finalizeFaintSequence(e)
local playerIncoming = Engine.makeBattler({species=1,level=5,stats=stats,types={12},moves={}})
local foeIncoming = Engine.makeBattler({species=4,level=5,stats=stats,types={10},moves={}})
local c = Controller.new({engine=b, introMessages={}, forcedSwitchChoices=function() return {{slot=2}} end,
  onForcedSwitchChoice=function() b:resolveForcedSwitch("player",playerIncoming); return {"player switched"} end,
  onMessagesComplete=function()
    if b.awaitingForcedSwitch == "foe" then b:resolveForcedSwitch("foe",foeIncoming); return {"foe switched"} end
  end})
c:_setMessages({"faints"}, Controller.PARTY); c:advanceMessage()
check("queue opens forced player selector first", c.state == Controller.PARTY and b.awaitingForcedSwitch == "player")
c:processInput({isNewlyPressed=function(_, key) return key == InputState.A_BUTTON end})
check("player choice keeps foe queue pending during messages", c.state == Controller.MESSAGES and b.awaitingForcedSwitch == "foe")
c:advanceMessage()
check("foe replacement is automatic before action", c.state == Controller.MESSAGES and b.awaitingForcedSwitch == nil)
c:advanceMessage()
check("queue reaches action only after both replacements", c.state == Controller.ACTION and b.player == playerIncoming and b.foe == foeIncoming)
print(("phase4_two_sided_replacement_state_test: %d passed, %d failed"):format(pass,fail))
os.exit(fail == 0 and 0 or 1)
