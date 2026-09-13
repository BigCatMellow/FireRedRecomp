-- Verified-ROM proof for main.lua's trainer-only forced player replacement.
package.path=package.path..";./?.lua"
local path=os.getenv("POKEPORT_ROM");if not path then print("SKIP phase4_player_forced_replacement_rom_test (set POKEPORT_ROM)");os.exit(0)end
local RI=require("import.RomImporter");local RA=require("import.RomAddresses");local Trainer=require("import.Trainer");local Species=require("import.SpeciesInfo");local Moves=require("import.BattleMove");local Types=require("import.TypeChart");local Nature=require("import.Nature");local Learn=require("import.LevelUpLearnset");local Flow=require("src.core.NewGameFlow");local Starter=require("src.core.StarterPokemonFactory");local Rng=require("src.core.Rng");local Save=require("src.core.SaveFileCodec");local Input=require("src.core.InputState");local Controller=require("src.core.BattleSceneController")
local ok,info=RI.verify(path);assert(ok,tostring(info));local f=assert(io.open(path,"rb"));local rom=f:read("*a");f:close();local a=assert(RA["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"]);love={};local App=require("main")
local species=Species.parseTable(rom,a.gSpeciesInfo,RA.COUNTS.NUM_SPECIES);local moves=Moves.parseTable(rom,a.gBattleMoves,RA.COUNTS.MOVES_COUNT);local catalog={species=species,moves=moves,typeChart=Types.parseTable(rom,a.gTypeEffectiveness),natures=Nature.parseTable(rom,a.sNatureStatTable),trainers=Trainer.parseTable(rom,a.gTrainers,RA.COUNTS.NUM_TRAINERS)}
local pass,fail=0,0;local function check(n,v)if v then pass=pass+1 else fail=fail+1;print("FAIL: "..n)end end
local function makeSession()
  local s=App.GameSession.fromNewGame({playerGender=0,playerName=Flow.encodeName("RED"),rivalName=Flow.encodeName("GREEN")},{nextRandom16=function()return 1 end,generatedTrainerIdLower=2})
  local function mon(seed)
    return Starter.generate({species=1,speciesInfo=species[1],speciesName=rom:sub(a.gSpeciesNames+12,a.gSpeciesNames+21),learnset=Learn.resolve(rom,a.gLevelUpLearnsets,1),battleMoves=moves,natures=catalog.natures,rng=Rng.new(seed),trainer={id=s.state.saveBlock2.playerTrainerId,name=s.state.saveBlock2.playerName:sub(1,7),gender=0},metLocation=0})
  end
  local sb=s.state.saveBlock1;sb.playerParty={mon(1),mon(2)};sb.playerPartyCount=2
  return s
end
local function press(c,key)local i=Input.new();i:update(0);i:update(key);c:processInput(i)end
local s=makeSession();App.configureTrainerBattleTest({romData=rom,romAddrs=a,catalog=catalog,session=s,rng=Rng.new(2),story={registerSeen=function()end}});local W=App.world
check("main starts trainer with two save-backed player mons",W.startTrainerBattle(89));local b=W.battle;local e=b.controller.engine;local ev={};e.player.hp=0;e:checkFaint("player",ev);b.controller:_setMessages(b.controller:_eventMessages(ev),Controller.PARTY)
while b.controller:message() do b.controller:advanceMessage() end
check("trainer faint with legal bench enters PARTY and not player loss",e.awaitingForcedSwitch=="player" and not e.outcome and b.controller.state==Controller.PARTY)
check("outgoing zero HP persists before selection",s.state.saveBlock1.playerParty[1].hp==0 and b.partySlot==1)
press(b.controller,Input.B_BUTTON);check("forced selector cancel retains pending state",e.awaitingForcedSwitch=="player" and b.controller.state==Controller.PARTY)
press(b.controller,Input.A_BUTTON);check("legal bench changes live slot and queues message once",e.awaitingForcedSwitch==nil and b.partySlot==2 and b.partyRecord==s.state.saveBlock1.playerParty[2] and b.controller.state==Controller.MESSAGES)
while b.controller:message() do b.controller:advanceMessage() end
check("replacement reaches action after message",b.controller.state==Controller.ACTION and e.player.hp==s.state.saveBlock1.playerParty[2].hp)
local saved=Save.decodeSaveBlock1(Save.encodeSaveBlock1(s.state.saveBlock1,0),0)
check("both outgoing and incoming records survive SaveFileCodec roundtrip",saved.playerParty[1].hp==0 and saved.playerParty[2].hp>0)
-- Remove the only bench after battle start: the engine must take its normal
-- player-loss fork rather than opening a selector for an illegal target.
W.battle=nil;s=makeSession();App.configureTrainerBattleTest({romData=rom,romAddrs=a,catalog=catalog,session=s,rng=Rng.new(3),story={registerSeen=function()end}});check("fresh trainer starts for no-bench check",W.startTrainerBattle(89));b=W.battle;e=b.controller.engine;s.state.saveBlock1.playerParty[2].hp=0;e.player.hp=0;ev={};e:checkFaint("player",ev)
check("no legal bench takes ordinary player-loss path without selector",e.outcome=="playerLost" and e.awaitingForcedSwitch==nil)
print(("phase4_player_forced_replacement_rom_test: %d passed, %d failed"):format(pass,fail));os.exit(fail==0 and 0 or 1)
