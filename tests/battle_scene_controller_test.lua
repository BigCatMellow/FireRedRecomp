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

local hazeMessage = c:_eventMessages({ { type="haze", side="player" } })
check("Haze has its real stat-reset presentation message",
  hazeMessage[1] and hazeMessage[1].text == ("All stat changes were" .. string.char(10) .. "eliminated!"),
  hazeMessage[1] and hazeMessage[1].text)

local focusEnergyMessage = c:_eventMessages({ { type="focusEnergySet", side="player" } })
check("Focus Energy has its real getting-pumped presentation message",
  focusEnergyMessage[1] and focusEnergyMessage[1].text == ("BULBASAUR is getting" .. string.char(10) .. "pumped!"),
  focusEnergyMessage[1] and focusEnergyMessage[1].text)

local fakeOutFailedMessage = c:_eventMessages({ { type="fakeOutFailed", side="player" } })
check("Fake Out's later-turn failure uses the real generic failure message",
  fakeOutFailedMessage[1] and fakeOutFailedMessage[1].text == "But it failed!",
  fakeOutFailedMessage[1] and fakeOutFailedMessage[1].text)

local teleportMessages = c:_eventMessages({ { type="teleport", side="player" }, { type="teleportFailed", side="foe" } })
check("Teleport presents its flee and trainer-failure messages",
  teleportMessages[1] and teleportMessages[1].text == "BULBASAUR fled from the\nbattle!"
    and teleportMessages[2] and teleportMessages[2].text == "But it failed!", teleportMessages)

local paralysisCuredMessage = c:_eventMessages({ { type="paralysisCured", side="foe", byMove=true } })
check("Smelling Salt's cure has a paralysis-cleared presentation message",
  paralysisCuredMessage[1] and paralysisCuredMessage[1].text == ("CHARMANDER was cured of" .. string.char(10) .. "paralysis!"),
  paralysisCuredMessage[1] and paralysisCuredMessage[1].text)

local rechargingMessage = c:_eventMessages({ { type="recharging", side="player" } })
check("Recharge uses the retail must-recharge presentation message",
  rechargingMessage[1] and rechargingMessage[1].text == "BULBASAUR must recharge!",
  rechargingMessage[1] and rechargingMessage[1].text)

local rainMessage = c:_eventMessages({ { type="weatherSet", weather="rain" } })
check("Rain Dance has its real weather-start presentation message",
  rainMessage[1] and rainMessage[1].text == "It started to rain!", rainMessage[1] and rainMessage[1].text)

local protectMessage = c:_eventMessages({ { type="protectSet", side="player" } })
check("Protect has its real self-protection presentation message",
  protectMessage[1] and protectMessage[1].text == ("BULBASAUR protected" .. string.char(10) .. "itself!"), protectMessage[1] and protectMessage[1].text)

local endureMessage = c:_eventMessages({ { type="endureSet", side="player" } })
check("Endure has its real brace presentation message",
  endureMessage[1] and endureMessage[1].text == ("BULBASAUR braced" .. string.char(10) .. "itself!"), endureMessage[1] and endureMessage[1].text)

local spikesSetMessage = c:_eventMessages({ { type="spikesSet", side="player", target="foe" } })
check("Spikes has its real placement presentation message",
  spikesSetMessage[1] and spikesSetMessage[1].text == ("SPIKES were scattered all around" .. string.char(10) .. "the opponent's side!"), spikesSetMessage[1] and spikesSetMessage[1].text)

local spikesDamageMessage = c:_eventMessages({ { type="spikesDamage", side="foe", damage=4, layers=3 } })
check("Spikes has its real switch-in damage presentation message",
  spikesDamageMessage[1] and spikesDamageMessage[1].text == ("CHARMANDER is hurt" .. string.char(10) .. "by SPIKES!"), spikesDamageMessage[1] and spikesDamageMessage[1].text)

local spikesClearMessage = c:_eventMessages({ { type="spikesCleared", side="player" } })
check("Rapid Spin has its real Spikes-clear presentation message",
  spikesClearMessage[1] and spikesClearMessage[1].text == ("BULBASAUR blew away" .. string.char(10) .. "SPIKES!"), spikesClearMessage[1] and spikesClearMessage[1].text)

local sandMessage = c:_eventMessages({ { type="weatherDamage", weather="sandstorm", side="foe" } })
check("Sandstorm has its real weather-damage presentation message",
  sandMessage[1] and sandMessage[1].text == ("CHARMANDER is buffeted" .. string.char(10) .. "by the sandstorm!"), sandMessage[1] and sandMessage[1].text)

do
  local messages = c:_eventMessages({
    { type="sleep", target="foe" },
    { type="poisonDamage", side="foe", hpRemaining=12 },
    { type="confusionSelfHit", side="player", hpRemaining=9 },
    { type="leechSeedDrain", side="foe", target="player", hpRemaining=8, targetHpRemaining=20 },
    { type="ingrainHeal", side="player", hpRemaining=22 },
  })
  check("status application names the affected battler",
    messages[1].text == "CHARMANDER fell asleep!", messages[1].text)
  check("status residual damage updates the affected HP bar",
    messages[2].text == ("CHARMANDER is hurt" .. string.char(10) .. "by poison!")
      and messages[2].hpSide == "foe" and messages[2].hp == 12, messages[2].text)
  check("confusion self-hit updates its own HP bar",
    messages[3].hpSide == "player" and messages[3].hp == 9, messages[3].text)
  check("Leech Seed updates both HP bars in event order",
    messages[4].hpSide == "foe" and messages[4].hp == 8
      and not messages[5].text and messages[5].hpSide == "player" and messages[5].hp == 20,
    messages[4].text)
  check("Ingrain healing updates its owner's HP bar",
    messages[6].hpSide == "player" and messages[6].hp == 22, messages[6].text)
end

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

-- Unported power-zero effects still fail visibly instead of fabricating rules.
c = controller(); c:advanceMessage(); c:advanceMessage()
Data.moves[999] = { effect=96, power=0, type=0, accuracy=100, pp=10,
  secondaryEffectChance=0, target=0, priority=0, flags=0 }
c.engine.player.moves = { {move=999,pp=10}, {move=Data.MOVE_TACKLE,pp=35} }
c:processInput(input(InputState.A_BUTTON)); c:processInput(input(InputState.A_BUTTON))
check("unsupported zero-power effects remain an explicit boundary",
  c:message() == "That move's effect is not available yet." and c.engine.player.moves[1].pp == 10)

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
  local messages = c:_eventMessages({ { type = "drain", side = "player", kind = "dreamEater", amount = 5, hpRemaining = 20 } })
  check("Dream Eater uses its real target-dream presentation text",
    messages[1].text == "CHARMANDER's dream\nwas eaten!", messages[1].text)
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

do
  local c = controller()
  local messages = c:_eventMessages({
    { type="substituteSet", side="player", hpRemaining=15 },
    { type="substituteDamage", side="foe", target="player", amount=4, substituteHP=0 },
    { type="substituteBroken", side="player" },
  })
  check("Substitute events present setup, intercepted hit, and break without a false HP loss",
    messages[1].hpSide == "player" and messages[1].hp == 15
      and messages[2].hpSide == nil and messages[3].text == "BULBASAUR's substitute\nbroke!")
end

do
  local c = controller()
  local messages = c:_eventMessages({ { type="transform", side="player", target="foe" }, { type="transformFailed", side="foe", target="player" } })
  check("Transform has success and failure presentation", messages[1].text == "BULBASAUR transformed!" and messages[2].text == "But it failed!")
end

do
  local c = controller()
  local messages = c:_eventMessages({
    { type="mimic", side="player", move=Data.MOVE_TACKLE },
    { type="sketch", side="foe", move=Data.MOVE_TACKLE },
    { type="sleepTalkFailed", side="player" },
  })
  check("Mimic, Sketch, and failed Sleep Talk have move-aware presentation",
    messages[1].text == "BULBASAUR learned\nTACKLE!"
      and messages[2].text == "CHARMANDER sketched\nTACKLE!"
      and messages[3].text == "But it failed!")
end

do
  local c = controller()
  local messages = c:_eventMessages({
    { type="camouflage", side="player" },
    { type="naturePower", side="foe", move=Data.MOVE_TACKLE },
  })
  check("Camouflage and Nature Power have live presentation",
    messages[1].text == "BULBASAUR changed its type!"
      and messages[2].text == "Nature Power turned into\nTACKLE!")
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
