-- Verified-ROM proof for main.lua's trainer-only voluntary player switch.
package.path=package.path..";./?.lua"
local path=os.getenv("POKEPORT_ROM");if not path then print("SKIP phase4_player_voluntary_switch_rom_test (set POKEPORT_ROM)");os.exit(0)end
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
check("main starts BEN89 with two save-backed mons",W.startTrainerBattle(89));local b=W.battle;local e=b.controller.engine
while b.controller:message() do b.controller:advanceMessage() end
local outgoing=s.state.saveBlock1.playerParty[1];e.player.hp=math.max(1,e.player.hp-1);local outgoingHP=e.player.hp
local original=e.runTurn;local sawIncoming=false
function e:runTurn(playerAction,foeAction)
  sawIncoming=playerAction.action=="switch" and playerAction.battler and playerAction.battler.species==1 and foeAction.action=="move"
  return original(self,playerAction,foeAction)
end
press(b.controller,Input.DPAD_DOWN);press(b.controller,Input.A_BUTTON)
check("ACTION POKEMON opens selector for live legal bench",b.controller.state==Controller.PARTY and b.controller.partyMode=="voluntary" and #b.controller.partyChoices==1 and e.turn==0)
press(b.controller,Input.B_BUTTON);check("voluntary cancel retains active record and turn",b.controller.state==Controller.ACTION and b.partySlot==1 and e.turn==0 and outgoing.hp~=outgoingHP)
press(b.controller,Input.A_BUTTON);s.state.saveBlock1.playerParty[2].hp=0;press(b.controller,Input.A_BUTTON)
check("stale fainted choice is rejected without turn or active mutation",b.controller.state==Controller.PARTY and b.partySlot==1 and e.turn==0)
s.state.saveBlock1.playerParty[2].hp=20
-- Restore the live party record's valid cached HP. The selector re-reads it
-- before confirmation; this is a real save-backed mutation, not an engine shim.
press(b.controller,Input.A_BUTTON)
check("legal choice calls existing switch action before foe move",sawIncoming and e.turn==1 and b.partySlot==2 and b.partyRecord==s.state.saveBlock1.playerParty[2] and e.player.species==1)
check("outgoing HP persists and incoming record is persisted after foe turn",outgoing.hp==outgoingHP and b.partyRecord.hp==e.player.hp and b.persistedTurn==e.turn)
local saved=Save.decodeSaveBlock1(Save.encodeSaveBlock1(s.state.saveBlock1,0),0)
check("both switch records survive SaveFileCodec roundtrip",saved.playerParty[1].hp==outgoingHP and saved.playerParty[2].hp==e.player.hp)
-- The forced path still shares PARTY but remains intentionally cancel-proof.
e.awaitingForcedSwitch="player";b.controller.partyMode="forced";b.controller:_setMessages({"Choose replacement."},Controller.PARTY);while b.controller:message()do b.controller:advanceMessage()end;press(b.controller,Input.B_BUTTON)
check("forced replacement remains cancel-proof",e.awaitingForcedSwitch=="player" and b.controller.state==Controller.PARTY)
print(("phase4_player_voluntary_switch_rom_test: %d passed, %d failed"):format(pass,fail));os.exit(fail==0 and 0 or 1)
