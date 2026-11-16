-- Native-input integration, pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788.
-- H1 controllers copy friendship/IVs at switch-in; pokemon.c:1815 species
-- friendship; battle_main.c:1576-1589 fixed IV=floor(iv*31/255).
-- bsc.c:8228-8236 power=floor(10*f/25) or floor(10*(255-f)/25),
-- zero override uses record1; :8503-8530 Hidden Power bit order HP/Atk/Def/
-- Spe/SpA/SpD. Ordinary damage: floor(floor(6*P*Atk/Def)/50)+2 at level10.
-- These literal damage oracles use known inputs, never implementation helpers.
package.path=package.path..";./?.lua"
local Bridge=require("src.core.BattlePartyBridge")
local Box=require("src.core.BoxPokemonCodec")
local Save=require("src.core.SaveFileCodec")
local Wild=require("src.core.WildPokemonFactory")
local Starter=require("src.core.StarterPokemonFactory")
local Trainer=require("src.core.TrainerPokemonFactory")
local E=require("src.core.BattleEngine")
local C=require("src.core.BattleSceneController")
local D=require("tests.battle_test_data")
local passed,failed=0,0
local function check(name,ok)
  if ok then passed=passed+1 else failed=failed+1; print("FAIL: "..name) end
end
local fields={"hp","attack","defense","speed","spAttack","spDefense"}
local function checkIvs(label,b,values)
  for i,k in ipairs(fields) do check(label.." "..k,b.ivs and b.ivs[k]==values[i]) end
end
local function sequence(values)
  return {draws=0,next16=function(self)
    self.draws=self.draws+1; return assert(values[self.draws],"unexpected RNG draw")
  end}
end
local moves={}
for id,m in pairs(D.moves) do moves[id]=m end
for i,id in ipairs({216,218,237}) do
  moves[id]={effect=({121,123,135})[i],power=1,type=0,accuracy=100,
    pp=id==237 and 15 or 20,secondaryEffectChance=0,target=0,priority=0,flags=id==237 and 0x32 or 0x33}
end
moves[150]={effect=85,power=0,type=0,accuracy=0,pp=40,target=0x10,priority=0,flags=0}
local info={baseHP=200,baseAttack=75,baseDefense=75,baseSpeed=100,
  baseSpAttack=225,baseSpDefense=225,types={14,14},catchRate=255,
  genderRatio=127,friendship=70,growthRate=0,abilities={0,0}}
local natures={}
for i=0,24 do natures[i]={attack=0,defense=0,speed=0,spAttack=0,spDefense=0} end
local function args(rng)
  return {species=19,level=10,speciesInfo=info,speciesName=string.rep(string.char(0xBB),10),
    trainer={id=0x12345678,name=string.rep(string.char(0xBB),7),gender=0},
    learnset={{level=1,move=216},{level=2,move=218},{level=3,move=237}},
    battleMoves=moves,natures=natures,metLocation=88,rng=rng}
end
local function engine(player)
  local foe=E.makeBattler({species=1,level=10,stats={hp=400,attack=20,defense=20,
    speed=1,spAttack=100,spDefense=50},types={0,0},moves={{move=150,pp=40}}})
  return E.new({player=player,foe=foe,moves=moves,typeChart=D.typeChart,rng=sequence({0,1,0})})
end
local function witness(label,b,expected)
  for slot,id in ipairs({216,218,237}) do
    check(label.." native move identity "..id,b.moves[slot].move==id)
    local e=engine(b)
    check(label.." admission "..id,e:supportsMove(moves[id],id,b))
    local events={}; local pp=b.moves[slot].pp
    e:resolveMove("player",slot,events)
    local amount
    for _,event in ipairs(events) do if event.type=="damage" then amount=event.amount end end
    check(label.." real damage "..id,amount==expected[slot])
    check(label.." ordinary PP/RNG "..id,b.moves[slot].pp==pp-1 and e.rng.draws==3)
  end
end

-- Encrypted party input crosses a real save encode/decode before Bridge.
-- FIRE IVs 2,3,2,2,2,3: bit0=34 -> Fire; bit1=63 -> power70.
local record=Starter.generate(args(sequence({0,0,2146,3138})))
local decoded=Box.decode(record.box)
decoded.substructs[0].friendship=255
local fire={2,3,2,2,2,3}
for i,k in ipairs(fields) do decoded.substructs[3].ivs[k]=fire[i] end
record.box=Box.encode(decoded)
record.maxHP=400; record.hp=400; record.attack=20; record.defense=20
record.speed=30; record.spAttack=100; record.spDefense=50
local bytes=Save.encodeSaveBlock1({playerPartyCount=1,playerParty={record}},0)
local saved=Save.decodeSaveBlock1(bytes,0).playerParty[1]
-- Stale convenience caches must lose to encrypted source data.
saved.friendship=0; saved.ivs={}; saved.boxData=decoded
decoded.substructs[0].friendship=0; decoded.substructs[3].ivs.attack=0
local party,owner=Bridge.battlerFromParty(saved,{[19]=info})
check("saved friendship255 wins over stale metadata",party.friendship==255)
checkIvs("saved all six IVs",party,fire)
check("saved snapshot independent",party.ivs~=owner.substructs[3].ivs)
owner.substructs[3].ivs.attack=0; owner.substructs[0].friendship=0
witness("saved party",party,{14,3,18})
check("computation leaves encrypted source intact",Box.decode(saved.box).substructs[0].friendship==255)

-- Wild native five draws: personality/nature then packed 1,2,3 / 4,5,6.
-- IV bit0=21 -> Bug; bit1=38 ->54. Atk20 => damage8 (no STAB).
local wrng=sequence({0,0,0,3137,6308})
local wild=Wild.generate(args(wrng))
wild.friendship=255 -- boxed owner must still supply70
local active=Bridge.battlerFromGenerated(wild)
check("wild boxed friendship authoritative",active.friendship==70)
checkIvs("wild all six IVs",active,{1,2,3,4,5,6})
wild.ivs.attack=31; wild.boxData.substructs[0].friendship=0
check("wild snapshot isolated",active.ivs.attack==2 and active.friendship==70)
witness("wild snapshot",active,{5,10,8})
check("wild construction/computation adds no factory RNG",wrng.draws==5)
-- A fresh constructor observes the newly authoritative zero; old snapshot stays70.
local fresh=Bridge.battlerFromGenerated(wild)
check("wild fresh switch-in reads zero",fresh.friendship==0 and active.friendship==70)

-- Default and custom trainer layouts: fixed12 IVs from iv100; Atk21.
-- All low bits0 -> Fighting30 (physical), versus Normal damage5*2=10.
for _,flags in ipairs({0,1}) do
  local rng=sequence({0,0}); local options=args(rng)
  options.speciesInfo={}; for k,v in pairs(info) do options.speciesInfo[k]=v end
  options.speciesInfo.friendship=flags==0 and 35 or 0
  options.trainer={partyFlags=flags,rawName=string.char(0xBB,0xFF),doubleBattle=false}
  options.partyMon={species=19,lvl=10,iv=100}
  if flags==1 then options.partyMon.moves={[0]=216,[1]=218,[2]=237,[3]=0} end
  local generated=Trainer.generate(options)
  local b=Bridge.battlerFromGenerated(generated)
  check("trainer base friendship layout"..flags,b.friendship==(flags==0 and 35 or 0))
  checkIvs("trainer fixed IVs layout"..flags,b,{12,12,12,12,12,12})
  generated.friendship=255; generated.ivs.hp=31
  check("trainer independent snapshot layout"..flags,b.ivs.hp==12 and b.ivs~=generated.ivs)
  witness("trainer layout"..flags,b,flags==0 and {3,13,10} or {3,14,10})
  check("trainer source RNG unchanged layout"..flags,rng.draws==2)
end

-- Controller runs the actual native saved Return through selection/resolution.
local controlled=Bridge.battlerFromParty(saved,{[19]=info})
local e=engine(controlled); local aiCalls=0
local c=C.new({engine=e,introMessages={},chooseFoeMove=function() aiCalls=aiCalls+1; return 1 end})
local turn=e.turn; c:_runTurn({action="move",moveSlot=1})
check("native controller admitted and resolved Return",e.turn==turn+1 and e.foe.hp==386
  and controlled.moves[1].pp==19 and e.rng.draws==3 and aiCalls==1)
-- Explicit absent synthetic API retains refusal before turn/PP/RNG/AI.
for _,id in ipairs({216,218,237}) do
  local bare=Bridge.battlerFromGenerated({species=19,level=10,types={14,14},
    stats={hp=400,attack=20,defense=20,speed=30,spAttack=100,spDefense=50},moves={{move=id,pp=15}}})
  local absent=engine(bare); local calls=0
  local controller=C.new({engine=absent,introMessages={},chooseFoeMove=function() calls=calls+1; return 1 end})
  local before=absent.turn; controller:_runTurn({action="move",moveSlot=1})
  check("absent native inputs remain absent "..id,bare.friendship==nil and bare.ivs==nil)
  check("absent controller refusal "..id,controller.messages[1].text=="That move's effect is not available yet."
    and absent.turn==before and bare.moves[1].pp==15 and absent.rng.draws==0 and calls==0)
end
check("all three shared records immutable",moves[216].power==1 and moves[218].power==1
  and moves[237].power==1 and moves[237].type==0)
print(("battle_variable_power_v4b_test: %d passed, %d failed"):format(passed,failed))
os.exit(failed==0 and 0 or 1)
