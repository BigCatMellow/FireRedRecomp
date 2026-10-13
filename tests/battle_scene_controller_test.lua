-- Run: lua5.1 tests/battle_scene_controller_test.lua
package.path = package.path .. ";./?.lua"
local BattleSceneController = require("src.core.BattleSceneController")
local BattleEngine = require("src.core.BattleEngine")
local PokemonStats = require("src.core.PokemonStats")
local InputState = require("src.core.InputState")
local Data = require("tests.battle_test_data")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end
local function input(button)
  return {
    isNewlyPressed = function(_, b) return b == button end,
  }
end
local noInput = input(-1)
local rng = { next16 = function() return 0 end }
local zero = { hp=0,attack=0,defense=0,speed=0,spAttack=0,spDefense=0 }
local neutral = { attack=0,defense=0,speed=0,spAttack=0,spDefense=0 }
local bs = PokemonStats.calculateAll(Data.BULBASAUR, 5, zero, zero, neutral)
local cs = PokemonStats.calculateAll(Data.CHARMANDER, 5, zero, zero, neutral)
local function controller()
  local engine = BattleEngine.new({
    player = BattleEngine.makeBattler({ species=1,level=5,stats=bs,types=Data.BULBASAUR.types,moves={{move=Data.MOVE_TACKLE,pp=35}} }),
    foe = BattleEngine.makeBattler({ species=4,level=5,stats=cs,types=Data.CHARMANDER.types,moves={{move=Data.MOVE_TACKLE,pp=35}} }),
    moves=Data.moves,typeChart=Data.typeChart,rng=rng,
  })
  return BattleSceneController.new({ engine=engine,playerName="BULBASAUR",foeName="CHARMANDER",
    moveName=function(move) return move == Data.MOVE_GROWL and "GROWL" or "TACKLE" end })
end

local c = controller()
check("starts with real wild-appeared message", c:message() == "Wild CHARMANDER appeared!", c:message())
c:processInput(input(InputState.A_BUTTON))
check("A advances to Go message", c:message() == "Go! BULBASAUR!")
c:processInput(input(InputState.A_BUTTON))
check("intro completes into action menu", c.state == BattleSceneController.ACTION)

c:processInput(input(InputState.DPAD_RIGHT))
check("action Right uses real 2x2 xor layout", c.actionCursor == 1)
c:processInput(input(InputState.DPAD_DOWN))
check("action Down reaches RUN", c.actionCursor == 3)
c:processInput(input(InputState.DPAD_LEFT))
check("action Left reaches POKEMON", c.actionCursor == 2)
c:processInput(input(InputState.DPAD_UP))
check("action Up returns to FIGHT", c.actionCursor == 0)
c:processInput(input(InputState.A_BUTTON))
check("FIGHT opens move menu", c.state == BattleSceneController.MOVE and c.moveCursor == 0)
c:processInput(input(InputState.B_BUTTON))
check("B backs out of move menu", c.state == BattleSceneController.ACTION)

c.engine.player.speed = 100 -- make the presented HP-order assertion direct
c:processInput(input(InputState.A_BUTTON))
c:processInput(input(InputState.A_BUTTON))
check("choosing Tackle consumes engine PP", c.engine.player.moves[1].pp == 34)
check("engine events become ordered move messages", c.state == BattleSceneController.MESSAGES and c:message():find("used TACKLE", 1, true) ~= nil, c:message())
local before = c.displayedHP.foe
while c.state == BattleSceneController.MESSAGES and c.displayedHP.foe == before do c:advanceMessage() end
check("invisible damage event updates presented foe HP in stream order", c.displayedHP.foe < before, c.displayedHP.foe)

-- A fast runner uses BattleEngine's automatic escape path and the scene
-- only becomes complete after its final message is acknowledged.
c = controller()
c.engine.player.speed = c.engine.foe.speed
c:advanceMessage(); c:advanceMessage()
c:processInput(input(InputState.DPAD_RIGHT)); c:processInput(input(InputState.DPAD_DOWN))
c:processInput(input(InputState.A_BUTTON))
check("RUN produces Got away safely", c:message() == "Got away safely!", c:message())
check("outcome is not exited before message acknowledgement", not c:isComplete())
c:processInput(input(InputState.A_BUTTON))
check("acknowledging final run message completes scene", c:isComplete() and c.engine.outcome == "ran")

-- BAG with no real Bag instance (or an empty one) stays a bounded,
-- visible "no balls" message rather than crashing or pretending a throw
-- happened -- POKEMON switching still shows its own unavailable message
-- (no live-scene party-select UI exists yet).
c = controller(); c:advanceMessage(); c:advanceMessage()
c:processInput(input(InputState.DPAD_RIGHT)); c:processInput(input(InputState.A_BUTTON))
check("BAG with no bag instance stays a bounded message", c:message() == "You don't have any POKé BALLS!", c:message())
c:processInput(input(InputState.B_BUTTON))
check("B also acknowledges a battle message", c.state == BattleSceneController.ACTION)
c:processInput(noInput)

c:processInput(input(InputState.DPAD_LEFT)); c:processInput(input(InputState.DPAD_DOWN))
c:processInput(input(InputState.A_BUTTON))
check("POKEMON switching is still explicitly unavailable in the live scene",
  c:message() == "POKEMON switching is not available yet.", c:message())
c:processInput(input(InputState.B_BUTTON))

-- The bounded Oak-lab status effect is a normal selectable move.
c = controller(); c:advanceMessage(); c:advanceMessage()
Data.moves[Data.MOVE_GROWL] = { effect=18, power=0, type=0, accuracy=100, pp=40,
  secondaryEffectChance=0, target=0, priority=0, flags=0 }
c.engine.player.moves = { {move=Data.MOVE_GROWL,pp=40}, {move=Data.MOVE_TACKLE,pp=35} }
c.engine.player.speed = 100
c:processInput(input(InputState.A_BUTTON))
c:processInput(input(InputState.A_BUTTON))
check("Growl executes through the controller and spends PP",
  c:message() == "BULBASAUR used GROWL!" and c.engine.player.moves[1].pp == 39
    and c.engine.foe.statStages.attack == 5, c:message())

-- Other power-zero effects still fail visibly instead of fabricating rules.
c = controller(); c:advanceMessage(); c:advanceMessage()
Data.moves[999] = { effect=1, power=0, type=0, accuracy=100, pp=10,
  secondaryEffectChance=0, target=0, priority=0, flags=0 }
c.engine.player.moves = { {move=999,pp=10}, {move=Data.MOVE_TACKLE,pp=35} }
c:processInput(input(InputState.A_BUTTON)); c:processInput(input(InputState.A_BUTTON))
check("unsupported status effects remain an explicit boundary",
  c:message() == "That move's effect is not available yet." and c.engine.player.moves[1].pp == 10)

local failedEntries = c:_eventMessages({ { type="moveFailed", side="player" } })
check("generic move failure presents FireRed But it failed text", failedEntries[1].text == "But it failed!", failedEntries[1] and failedEntries[1].text)

-- Real BAG wiring: with a bag that actually has a Poke Ball, BAG throws
-- one (consuming it regardless of outcome, matching real
-- RemoveBagItem-before-throw semantics) and the engine's real "capture"
-- action resolves through the controller, ending the scene either way.
do
  local Bag = require("src.core.Bag")
  local CaptureRules = require("src.core.CaptureRules")
  local itemLookup = { [CaptureRules.ITEM_POKE_BALL] = { pocket = Bag.POCKET_POKE_BALLS } }
  local bag = Bag.new(itemLookup)
  bag:addItem(CaptureRules.ITEM_POKE_BALL, 1)

  local engine = BattleEngine.new({
    player = BattleEngine.makeBattler({ species=1, level=5, stats=bs, types=Data.BULBASAUR.types,
      moves={{move=Data.MOVE_TACKLE,pp=35}} }),
    foe = BattleEngine.makeBattler({ species=4, catchRate=255, level=5, stats=cs,
      types=Data.CHARMANDER.types, moves={{move=Data.MOVE_TACKLE,pp=35}} }),
    moves=Data.moves, typeChart=Data.typeChart,
    rng = { draws=0, next16=function(self) self.draws=self.draws+1; return 65535 end }, -- always-fail shake roll
  })
  local bagController = BattleSceneController.new({
    engine=engine, playerName="BULBASAUR", foeName="CHARMANDER", bag=bag,
    moveName=function() return "TACKLE" end,
  })
  bagController:advanceMessage(); bagController:advanceMessage()
  bagController:processInput(input(InputState.DPAD_RIGHT))
  bagController:processInput(input(InputState.A_BUTTON))
  check("a real ball is consumed from the bag on a throw attempt",
    bag:quantityOf(CaptureRules.ITEM_POKE_BALL) == 0)
  check("BAG actually resolves the engine's real capture action",
    bagController:message() == "BULBASAUR threw a POKé BALL!", bagController:message())
end

-- Real gStatNamesTable/message shapes (src/battle_message.c) for the
-- full stat-move family BattleEngine.lua generalized beyond Growl/Tail
-- Whip: sharply-rose/harshly-fell for +-2, plain rose/fell for +-1, and
-- the real "won't go higher/lower" boundary pair -- this presentation
-- layer had not been updated when that engine work landed, so it was
-- still hardcoding "ATTACK"/"DEFENSE fell!" only.
do
  local c = controller()
  local messages = c:_eventMessages({
    { type = "statChange", side = "player", stat = "speed", stages = 2 },
    { type = "statChange", side = "foe", stat = "spDefense", stages = -2 },
    { type = "statChange", side = "player", stat = "accuracy", stages = -1 },
    { type = "statChange", side = "foe", stat = "evasion", stages = 0, prevented = true },
  })
  check("a +2 stat change uses the real \"sharply rose!\" verb",
    messages[1].text == "BULBASAUR's SPEED\nsharply rose!", messages[1].text)
  check("a -2 stat change uses the real \"harshly fell!\" verb",
    messages[2].text == "CHARMANDER's SP. DEF\nharshly fell!", messages[2].text)
  check("a -1 stat change uses the plain real \"fell!\" verb",
    messages[3].text == "BULBASAUR's ACCURACY\nfell!", messages[3].text)
  check("a prevented -1 change (stages=0) reports \"won't go lower!\", not \"higher\"",
    messages[4].text == "CHARMANDER's EVASIVENESS\nwon't go lower!", messages[4].text)
end

do
  local c = controller()
  local playerHP, foeHP, revision = c.engine.player.hp, c.engine.foe.hp, c.revision
  local messages = c:_eventMessages({
    { type = "useMove", side = "player", move = 222 },
    { type = "magnitude", side = "player", level = 7 },
    { type = "miss", side = "player" },
  })
  check("Magnitude announces its supplied level exactly once between use and result messages",
    #messages == 3 and messages[1].text:find("used", 1, true)
      and messages[2].text == "Magnitude 7!" and messages[3].text:find("missed", 1, true),
    messages[2] and messages[2].text)
  check("Magnitude presentation does not mutate engine state or controller revision",
    c.engine.player.hp == playerHP and c.engine.foe.hp == foeHP and c.revision == revision)
end

do
  local c = controller()
  local messages = c:_eventMessages({ { type = "recoil", side = "foe", amount = 5, hpRemaining = 10 } })
  check("recoil names the attacker, matching real sText_PkmnHitWithRecoil",
    messages[1].text == "CHARMANDER is hit\nwith recoil!", messages[1].text)
  check("recoil's hpSide is the attacker (recoil changes the attacker's OWN hp)",
    messages[1].hpSide == "foe" and messages[1].hp == 10, messages[1].hpSide)
end

do
  local c = controller()
  local messages = c:_eventMessages({ { type = "drain", side = "player", amount = 5, hpRemaining = 20 } })
  check("drain names the DEFENDER (whose energy was drained), matching real sText_PkmnEnergyDrained",
    messages[1].text == "CHARMANDER had its\nenergy drained!", messages[1].text)
  check("drain's hpSide is still the attacker (a real heal), even though the MESSAGE names the other side",
    messages[1].hpSide == "player" and messages[1].hp == 20, messages[1].hpSide)
end

do
  local c = controller()
  local messages = c:_eventMessages({ { type="painSplitHP", side="player", hpRemaining=12 },
    { type="painSplitHP", side="foe", hpRemaining=11 }, { type="painSplit" } })
  check("Pain Split preserves attacker then target invisible HP order before shared-pain text",
    messages[1].hpSide == "player" and messages[1].hp == 12 and messages[2].hpSide == "foe"
    and messages[2].hp == 11 and messages[3].text == "The battlers\nshared their pain!", messages[3] and messages[3].text)
end

do
  local c = controller()
  local messages = c:_eventMessages({ { type="useMove", side="player", move=105 },
    { type="restoreHP", side="player", beforeHP=10, hpRemaining=19, amount=9 } })
  check("Restore HP keeps the move announcement before an invisible own-HP snapshot and feedback",
    messages[1].text:find("used", 1, true) and messages[2].hpSide == "player" and messages[2].hp == 19
      and messages[3].text == "BULBASAUR recovered HP!", messages[3] and messages[3].text)
  messages = c:_eventMessages({ { type="restoreHPFull", side="foe" } })
  check("Restore HP full result has feedback without an HP snapshot",
    #messages == 1 and messages[1].hpSide == nil and messages[1].text == "CHARMANDER is already at full HP!", messages[1] and messages[1].text)
end

do
  local c = controller()
  local messages = c:_eventMessages({ { type = "multiHit", side = "player", hits = 4 } })
  check("multiHit reports the real hit count, matching sText_HitXTimes",
    messages[1].text == "Hit 4 time(s)!", messages[1].text)
end

do
  local c = controller()
  local messages = c:_eventMessages({ { type = "switch", side = "player" } })
  check("switch produces a real, non-empty status message", messages[1] and #messages[1].text > 0)
end

do
  local c = controller()
  local messages = c:_eventMessages({
    { type = "screenSet", side = "player", screen = "reflect", turns = 5 },
    { type = "screenSet", side = "foe", screen = "lightScreen", turns = 5 },
    { type = "screenFailed", side = "player", screen = "reflect" },
    { type = "screenExpired", side = "player", screen = "reflect" },
    { type = "screenExpired", side = "foe", screen = "lightScreen" },
  })
  check("screenSet reflect uses the real \"raised DEFENSE!\" message",
    messages[1].text == "BULBASAUR's REFLECT\nraised DEFENSE!", messages[1].text)
  check("screenSet lightScreen uses the real \"raised SP. DEF!\" message",
    messages[2].text == "CHARMANDER's LIGHT SCREEN\nraised SP. DEF!", messages[2].text)
  check("screenFailed uses the real \"But it failed!\" message",
    messages[3].text == "But it failed!", messages[3].text)
  check("screenExpired on the player side uses \"Your team's\"",
    messages[4].text == "Your team's REFLECT\nwore off!", messages[4].text)
  check("screenExpired on the foe side uses \"The foe's\"",
    messages[5].text == "The foe's LIGHT SCREEN\nwore off!", messages[5].text)
end

-- Actual effect-45 engine events through the controller's turn/message path.
do
  local moves={
    [26]={effect=45,power=70,type=1,accuracy=95,pp=25,priority=0,target=0},
    [105]={effect=32,power=0,type=0,accuracy=0,pp=20,priority=0,target=16},
  }
  local chart={[0]={attackingType=1,defendingType=7,multiplier=0}}
  local stats={hp=100,attack=40,defense=40,speed=20,spAttack=40,spDefense=40}
  for _,side in ipairs({"player","foe"}) do
    for _,mode in ipairs({"nonfatal","fatal","replacement","immune"}) do
      local draw=0
      local engine=BattleEngine.new({
        player=BattleEngine.makeBattler({species=1,level=20,stats=stats,types={10,10},moves={{move=105,pp=20}}}),
        foe=BattleEngine.makeBattler({species=4,level=20,stats=stats,types={10,10},moves={{move=105,pp=20}}}),
        moves=moves,typeChart=chart,rng={next16=function() draw=draw+1; return draw==1 and 99 or 0 end},
        hasReplacement=function(s) return mode=="replacement" and s==side end,
      })
      local attacker=engine:battler(side)
      local targetSide=side=="player" and "foe" or "player"
      local target=engine:battler(targetSide)
      attacker.moves={{move=26,pp=25}}; attacker.types={1,1}; attacker.speed=30
      if mode=="fatal" or mode=="replacement" then attacker.hp=1 end
      if mode=="immune" then target.types={7,7} end
      local beforeHP=attacker.hp
      local ctrl=BattleSceneController.new({engine=engine,playerName="PLAYER",foeName="FOE",
        moveName=function(id) return id==26 and "JUMP KICK" or "RECOVER" end,
        forcedSwitchChoices=function() return {{slot=2,name="BENCH"}} end})
      ctrl:advanceMessage(); ctrl:advanceMessage()
      ctrl:_runTurn({action="move",moveSlot=1})
      local label=side..":"..mode
      check("crash controller starts actual use with old HP "..label,
        ctrl:message():find("JUMP KICK",1,true)~=nil and ctrl.displayedHP[side]==beforeHP)
      ctrl:advanceMessage()
      if mode=="immune" then
        check("immune controller shows no effect and no HP mutation "..label,
          ctrl:message():find("doesn't affect",1,true)~=nil and attacker.hp==beforeHP
          and ctrl.displayedHP[side]==beforeHP and draw==1)
        local crashSeen=false
        for _,entry in ipairs(ctrl.messages) do
          crashSeen=crashSeen or (entry.text and entry.text:find("crashed",1,true)~=nil) or entry.hpSide~=nil
        end
        check("immune actual stream has no crash or HP entry "..label,not crashSeen)
      else
        check("crash controller miss keeps old display "..label,
          ctrl:message():find("missed",1,true)~=nil and ctrl.displayedHP[side]==beforeHP)
        ctrl:advanceMessage()
        check("crash text precedes invisible HP "..label,
          ctrl:message()==(side=="player" and "PLAYER" or "FOE").." kept going\nand crashed!"
          and ctrl.displayedHP[side]==beforeHP and attacker.hp<beforeHP)
        ctrl:advanceMessage()
        check("crash invisible HP applies before faint or continuation "..label,
          ctrl.displayedHP[side]==attacker.hp and ctrl.displayedHP[targetSide]==100
          and target.hp==100 and draw==2)
        if mode~="nonfatal" then
          check("actual fatal crash presents faint after zero HP "..label,
            ctrl:message():find("fainted",1,true)~=nil and ctrl.displayedHP[side]==0
            and ctrl.state==BattleSceneController.MESSAGES)
        end
      end
      local remaining=20
      while ctrl.state==BattleSceneController.MESSAGES and remaining>0 do ctrl:advanceMessage(); remaining=remaining-1 end
      local expected=mode=="fatal" and BattleSceneController.COMPLETE
        or (mode=="replacement" and side=="player" and BattleSceneController.PARTY)
        or BattleSceneController.ACTION
      check("crash messages drain before completion "..label,remaining>0 and ctrl.state==expected)
      if mode=="replacement" then
        check("crash pending replacement survives message drain "..label,
          engine.awaitingForcedSwitch==side and not engine:isOver())
      end
    end
  end
end

-- Two-stat self UP family through the real engine and message path.
-- Expected text: sText_AttackersStatRose / sText_StatsWontIncrease2.
do
  local moves={
    [349]={effect=212,power=0,type=16,accuracy=0,pp=20,priority=0,target=0x10},
    [105]={effect=32,power=0,type=0,accuracy=0,pp=20,priority=0,target=16},
  }
  local stats={hp=100,attack=40,defense=40,speed=20,spAttack=40,spDefense=40}
  for _,maxed in ipairs({false,true}) do
    local engine=BattleEngine.new({
      player=BattleEngine.makeBattler({species=1,level=20,stats=stats,types={0,0},moves={{move=349,pp=20}}}),
      foe=BattleEngine.makeBattler({species=4,level=20,stats=stats,types={0,0},moves={{move=105,pp=20}}}),
      moves=moves,typeChart={},rng={next16=function() return 0 end},
    })
    engine.player.speed=30
    if maxed then engine.player.statStages.attack=12; engine.player.statStages.speed=12 end
    local ctrl=BattleSceneController.new({engine=engine,playerName="PLAYER",foeName="FOE",
      moveName=function(id) return id==349 and "DRAGON DANCE" or "RECOVER" end})
    ctrl:advanceMessage(); ctrl:advanceMessage()
    ctrl:_runTurn({action="move",moveSlot=1})
    local texts={}
    for _,entry in ipairs(ctrl.messages) do if entry.text then texts[#texts+1]=entry.text end end
    local all=table.concat(texts,"|")
    if maxed then
      check("dual stat both maxed message",all:find("PLAYER's stats won't\ngo any higher!",1,true)~=nil
        and not all:find("rose!",1,true))
    else
      local a=all:find("PLAYER's ATTACK\nrose!",1,true)
      local s=all:find("PLAYER's SPEED\nrose!",1,true)
      check("dual stat messages in source order",a~=nil and s~=nil and a<s)
    end
  end
end

-- Tickle / Overheat through the real engine. Expected text:
-- sText_DefendersStatFell, sText_StatsWontDecrease2, sText_AttackersStatFell
-- with sText_StatHarshly.
do
  local moves={
    [321]={effect=205,power=0,type=0,accuracy=100,pp=20,priority=0,target=0},
    [315]={effect=204,power=140,type=10,accuracy=90,pp=5,secondaryEffectChance=100,priority=0,target=0},
    [105]={effect=32,power=0,type=0,accuracy=0,pp=20,priority=0,target=16},
  }
  local stats={hp=300,attack=40,defense=40,speed=20,spAttack=40,spDefense=40}
  local function run(moveId, setupFoe)
    local engine=BattleEngine.new({
      player=BattleEngine.makeBattler({species=1,level=20,stats=stats,types={0,0},moves={{move=moveId,pp=20}}}),
      foe=BattleEngine.makeBattler({species=4,level=20,stats=stats,types={0,0},moves={{move=105,pp=20}}}),
      moves=moves,typeChart={},rng={next16=function() return 0 end},
    })
    engine.player.speed=30
    if setupFoe then setupFoe(engine.foe) end
    local ctrl=BattleSceneController.new({engine=engine,playerName="PLAYER",foeName="FOE",
      moveName=function(id) return ({[321]="TICKLE",[315]="OVERHEAT"})[id] or "RECOVER" end})
    ctrl:advanceMessage(); ctrl:advanceMessage()
    ctrl:_runTurn({action="move",moveSlot=1})
    local texts={}
    for _,entry in ipairs(ctrl.messages) do if entry.text then texts[#texts+1]=entry.text end end
    return table.concat(texts,"|")
  end
  local all=run(321)
  local a=all:find("FOE's ATTACK\nfell!",1,true)
  local d=all:find("FOE's DEFENSE\nfell!",1,true)
  check("tickle messages in source order",a~=nil and d~=nil and a<d)
  all=run(321,function(foe) foe.statStages.attack=0; foe.statStages.defense=0 end)
  check("tickle both-minimum message",all:find("FOE's stats won't\ngo any lower!",1,true)~=nil
    and not all:find("fell!",1,true))
  all=run(315)
  check("overheat self harsh drop message",all:find("PLAYER's SP. ATK\nharshly fell!",1,true)~=nil)
end

-- Batch 3 messages through the real engine (src/battle_message.c texts).
do
  local moves={
    [150]={effect=85,power=0,type=0,accuracy=0,pp=40,priority=0,target=0x10},
    [114]={effect=25,power=0,type=15,accuracy=0,pp=30,priority=0,target=0x10},
    [244]={effect=143,power=0,type=0,accuracy=0,pp=10,priority=0,target=0},
    [187]={effect=142,power=0,type=0,accuracy=0,pp=10,priority=0,target=0x10},
    [105]={effect=32,power=0,type=0,accuracy=0,pp=20,priority=0,target=16},
  }
  local stats={hp=100,attack=40,defense=40,speed=20,spAttack=40,spDefense=40}
  local function run(moveId)
    local engine=BattleEngine.new({
      player=BattleEngine.makeBattler({species=1,level=20,stats=stats,types={0,0},moves={{move=moveId,pp=10}}}),
      foe=BattleEngine.makeBattler({species=4,level=20,stats=stats,types={0,0},moves={{move=105,pp=20}}}),
      moves=moves,typeChart={},rng={next16=function() return 0 end},
    })
    engine.player.speed=30
    local ctrl=BattleSceneController.new({engine=engine,playerName="PLAYER",foeName="FOE",
      moveName=function() return "MOVE" end})
    ctrl:advanceMessage(); ctrl:advanceMessage()
    ctrl:_runTurn({action="move",moveSlot=1})
    return ctrl, engine
  end
  local function texts(ctrl)
    local out={}
    for _,entry in ipairs(ctrl.messages) do if entry.text then out[#out+1]=entry.text end end
    return table.concat(out,"|")
  end
  check("splash message",texts(run(150)):find("But nothing happened!",1,true)~=nil)
  check("haze message",texts(run(114)):find("All stat changes were\neliminated!",1,true)~=nil)
  check("psych up message",texts(run(244)):find("PLAYER copied\nFOE's stat changes!",1,true)~=nil)
  local ctrl,engine=run(187)
  ctrl:advanceMessage()
  check("belly drum HP updates before its message",
    ctrl:message()=="PLAYER cut its own HP\nand maximized ATTACK!"
    and ctrl.displayedHP.player==50 and engine.player.hp==50)
end

-- Batch 4 messages through the real engine (sText_TheWallShattered,
-- sText_AttackersStatRose / sText_StatsWontIncrease).
do
  local moves={
    [280]={effect=186,power=75,type=1,accuracy=100,pp=15,secondaryEffectChance=0,priority=0,target=0},
    [246]={effect=140,power=60,type=5,accuracy=100,pp=5,secondaryEffectChance=10,priority=0,target=0},
    [105]={effect=32,power=0,type=0,accuracy=0,pp=20,priority=0,target=16},
  }
  local stats={hp=300,attack=40,defense=40,speed=20,spAttack=40,spDefense=40}
  local function run(moveId, prep)
    local engine=BattleEngine.new({
      player=BattleEngine.makeBattler({species=1,level=20,stats=stats,types={0,0},moves={{move=moveId,pp=5}}}),
      foe=BattleEngine.makeBattler({species=4,level=20,stats=stats,types={0,0},moves={{move=105,pp=20}}}),
      moves=moves,typeChart={},rng={next16=function() return 0 end},
    })
    engine.player.speed=30
    if prep then prep(engine) end
    local ctrl=BattleSceneController.new({engine=engine,playerName="PLAYER",foeName="FOE",
      moveName=function() return "MOVE" end})
    ctrl:advanceMessage(); ctrl:advanceMessage()
    ctrl:_runTurn({action="move",moveSlot=1})
    local out={}
    for _,entry in ipairs(ctrl.messages) do if entry.text then out[#out+1]=entry.text end end
    return table.concat(out,"|")
  end
  local all=run(280,function(e) e.sideStatus.foe.reflect=true; e.sideStatus.foe.reflectTimer=5 end)
  local wall=all:find("The wall shattered!",1,true)
  local used=all:find("PLAYER used MOVE!",1,true)
  local foeUsed=all:find("FOE used",1,true)
  check("brick break wall shattered message after use, before foe acts",wall~=nil and used<wall and wall<foeUsed)
  all=run(246,function(e) e.player.statStages.speed=12 end)
  local atk=all:find("PLAYER's ATTACK\nrose!",1,true)
  local spd=all:find("PLAYER's SPEED\nwon't go higher!",1,true)
  local spdef=all:find("PLAYER's SP. DEF\nrose!",1,true)
  check("ancient power all-stats messages in order",atk and spd and spdef and atk<spd and spd<spdef)
end

-- Triple Kick through the real engine: a later miss shows only the hit count
-- (sText_HitXTimes), a first-kick miss shows the miss text.
do
  local moves={
    [167]={effect=104,power=10,type=1,accuracy=90,pp=10,secondaryEffectChance=0,priority=0,target=0},
    [105]={effect=32,power=0,type=0,accuracy=0,pp=20,priority=0,target=16},
  }
  local stats={hp=300,attack=40,defense=40,speed=20,spAttack=40,spDefense=40}
  local function run(values)
    local i=0
    local engine=BattleEngine.new({
      player=BattleEngine.makeBattler({species=1,level=20,stats=stats,types={0,0},moves={{move=167,pp=10}}}),
      foe=BattleEngine.makeBattler({species=4,level=20,stats=stats,types={0,0},moves={{move=105,pp=20}}}),
      moves=moves,typeChart={},rng={next16=function() i=i+1; return values[i] or 0 end},
    })
    engine.player.speed=30
    local ctrl=BattleSceneController.new({engine=engine,playerName="PLAYER",foeName="FOE",
      moveName=function() return "MOVE" end})
    ctrl:advanceMessage(); ctrl:advanceMessage()
    ctrl:_runTurn({action="move",moveSlot=1})
    local out={}
    for _,entry in ipairs(ctrl.messages) do if entry.text then out[#out+1]=entry.text end end
    return table.concat(out,"|")
  end
  local all=run({0,1,0,0,1,0,99})
  check("triple kick later miss shows only hit count",all:find("Hit 2 time(s)!",1,true)~=nil
    and not all:find("missed",1,true))
  all=run({99})
  check("triple kick first miss shows miss text",all:find("missed",1,true)~=nil and not all:find("Hit ",1,true))
end

-- Batch 6 through the real engine: sText_PkmnChangedType with gTypeNames;
-- Memento's HP bar drops before the stat messages.
do
  local moves={
    [160]={effect=30,power=0,type=0,accuracy=0,pp=30,priority=0,target=0x10},
    [262]={effect=168,power=0,type=17,accuracy=100,pp=10,priority=0,target=0},
    [52]={effect=4,power=40,type=10,accuracy=100,pp=25,priority=0,target=0},
    [105]={effect=32,power=0,type=0,accuracy=0,pp=20,priority=0,target=16},
  }
  local stats={hp=100,attack=40,defense=40,speed=20,spAttack=40,spDefense=40}
  local function run(list, values)
    local i=0
    local playerMoves={}
    for k,id in ipairs(list) do playerMoves[k]={move=id,pp=10} end
    local engine=BattleEngine.new({
      player=BattleEngine.makeBattler({species=1,level=20,stats=stats,types={0,0},moves=playerMoves}),
      foe=BattleEngine.makeBattler({species=4,level=20,stats=stats,types={0,0},moves={{move=105,pp=20}}}),
      moves=moves,typeChart={},rng={next16=function() i=i+1; return values[i] or 0 end},
      hasReplacement=function() return false end,
    })
    engine.player.speed=30
    local ctrl=BattleSceneController.new({engine=engine,playerName="PLAYER",foeName="FOE",
      moveName=function() return "MOVE" end})
    ctrl:advanceMessage(); ctrl:advanceMessage()
    ctrl:_runTurn({action="move",moveSlot=1})
    return ctrl
  end
  local ctrl=run({160,52},{1})
  local out={}
  for _,entry in ipairs(ctrl.messages) do if entry.text then out[#out+1]=entry.text end end
  local names={[0]="NORMAL","FIGHT","FLYING","POISON","GROUND","ROCK","BUG","GHOST",
    "STEEL","???","FIRE","WATER","GRASS","ELECTR","PSYCHC","ICE","DRAGON","DARK"}
  local allNames=true
  for id=0,17 do allNames=allNames and BattleSceneController.TYPE_DISPLAY_NAMES[id]==names[id] end
  check("all 18 gTypeNames match source (battle_main.c:430-447)",allNames)
  check("conversion message uses source type name",
    table.concat(out,"|"):find("PLAYER transformed\ninto the FIRE type!",1,true)~=nil)
  ctrl=run({262},{})
  ctrl:advanceMessage()
  check("memento HP drops before the first stat message",
    ctrl:message()=="FOE's ATTACK\nharshly fell!" and ctrl.displayedHP.player==0)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
