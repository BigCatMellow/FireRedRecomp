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

-- Bounded unavailable actions return visibly to the action menu.
c = controller(); c:advanceMessage(); c:advanceMessage()
c:processInput(input(InputState.DPAD_RIGHT)); c:processInput(input(InputState.A_BUTTON))
check("BAG gap is explicit", c:message() == "The BAG is not available yet.")
c:processInput(input(InputState.B_BUTTON))
check("B also acknowledges a battle message", c.state == BattleSceneController.ACTION)
c:processInput(noInput)

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

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
