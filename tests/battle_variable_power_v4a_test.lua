-- V4a independent oracles from pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788:
-- bsc.c:8228-8236 friendship; :8503-8530 IV bits (HP/Atk/Def/Spe/SpA/SpD);
-- bs1.s:1735-1738 type before accuracy; pokemon.c:2398-2406 zero override;
-- bsc.c:1751-1756, :1823-1843, :4103-4109 Hidden Power never defrosts.
-- Level10 factor6, Atk20/Def20 physical: max(1,floor(6P/50))+2.
-- SpA100/SpD50 special: floor(12P/50)+2. No STAB unless explicitly set.
-- Expected values below are source arithmetic, never engine readbacks.
package.path = package.path .. ";./?.lua"
local E = require("src.core.BattleEngine")
local C = require("src.core.BattleSceneController")
local S = require("src.core.StatusConditions")
local D = require("tests.battle_test_data")
local passed, failed = 0, 0
local function check(name, ok, detail)
  if ok then passed = passed + 1 else
    failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(detail))
  end
end
local fields = { "hp", "attack", "defense", "speed", "spAttack", "spDefense" }
local function ivs(v)
  local out = {}; for i, key in ipairs(fields) do out[key] = type(v)=="table" and v[i] or v end
  return out
end
local FIRE = {2,3,2,2,2,3} -- bit0 sum34 -> Fire; bit1 sum63 ->70
local STEEL = {2,3,3,3,3,2} -- bit0 sum30 -> Steel; bit1 sum63 ->70
local moves = {}
for id, m in pairs(D.moves) do moves[id] = m end
local function record(effect, power, moveType, pp, flags)
  return {effect=effect,power=power,type=moveType,accuracy=100,pp=pp,
    secondaryEffectChance=0,target=0,priority=0,flags=flags}
end
moves[216] = record(121,1,0,20,0x33) -- battle_moves.h:2811-2822
moves[218] = record(123,1,0,20,0x33) -- :2837-2848
moves[237] = record(135,1,0,15,0x32) -- :3084-3095
moves[311] = record(203,50,0,10,0x12)
moves[150] = {effect=85,power=0,type=0,accuracy=0,pp=40,target=0x10,priority=0,flags=0}
local function battler(opts)
  opts = opts or {}
  return E.makeBattler({species=1,level=10,
    stats={hp=400,attack=20,defense=20,speed=opts.speed or 30,spAttack=100,spDefense=50},
    types=opts.types or {14,14}, friendship=opts.friendship, ivs=opts.ivs,
    moves={{move=opts.move or 237,pp=15}}})
end
local function battle(opts, values)
  opts = opts or {}
  local rng = {draws=0,next16=function(self)
    self.draws=self.draws+1; return (values or {0,1,0})[self.draws] or 0
  end}
  local e = E.new({player=battler(opts),foe=battler({speed=20,move=150,types={0,0}}),
    moves=moves,typeChart=D.typeChart,rng=rng})
  e.player.ability, e.foe.ability = 0, 0
  return e
end
local function find(events, kind)
  for _, event in ipairs(events) do if event.type == kind then return event end end
end
local function resolve(e, side)
  local events={}; e:resolveMove(side or "player",1,events); return events
end
local function damage(e, expected, name)
  local events = resolve(e); local hit = find(events,"damage")
  check(name, hit and hit.amount==expected, hit and hit.amount)
  return events
end

-- Validate complete optional snapshots. Caller-owned tables can change later;
-- neither that nor construction of the other side may change this battler.
do
  local input = ivs(FIRE); local opts = {friendship=70,ivs=input}
  local p, q = battler(opts), battler(opts)
  input.attack=0; opts.friendship=0
  check("copied friendship",p.friendship==70)
  check("copied IV snapshot",p.ivs.attack==3 and q.ivs.attack==3 and p.ivs~=input and p.ivs~=q.ivs)
  p.ivs.hp=0
  check("side snapshots isolated",q.ivs.hp==2)
  check("absent stays absent",battler().friendship==nil and battler().ivs==nil)
  for _, bad in ipairs({-1,256,0.5,"70",false,math.huge,0/0}) do
    check("invalid friendship "..tostring(bad),not pcall(battler,{friendship=bad}))
  end
  for _, key in ipairs(fields) do
    for _, bad in ipairs({-1,32,1.5,"31",false,math.huge,0/0}) do
      local inputIVs=ivs(31); inputIVs[key]=bad
      check("invalid IV "..key..tostring(bad),not pcall(battler,{ivs=inputIVs}))
    end
    local inputIVs=ivs(31); inputIVs[key]=nil
    check("missing IV "..key,not pcall(battler,{ivs=inputIVs}))
  end
  check("IV table required",not pcall(battler,{ivs=31}))
end

-- floor(10*f/25), floor(10*(255-f)/25); override0 uses record1.
local friends = {
  {0,1,102,3,14},{2,1,101,3,14},{3,1,100,3,14},{70,28,74,5,10},
  {128,51,50,8,8},{253,101,1,14,3},{254,101,1,14,3},{255,102,1,14,3},
}
for _, row in ipairs(friends) do
  for n, id in ipairs({216,218}) do
    check("friendship helper "..row[1]..":"..id,E.friendshipPower(row[1],id==218,1)==row[n+1])
    local e=battle({move=id,friendship=row[1]})
    damage(e,row[n+3],"friendship damage "..row[1]..":"..id)
    check("friendship ordinary RNG/PP",e.rng.draws==3 and e.player.moves[1].pp==14)
    check("friendship record immutable",moves[id].power==1 and moves[id].type==0)
  end
end
check("zero override uses actual record power",E.friendshipPower(0,false,7)==7)

-- Independent full type-bit oracle; all second bits0 give power30.
local typeOracle = {
  1,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,6,6,6,6,6,7,7,7,7,
  8,8,8,8,10,10,10,10,11,11,11,11,12,12,12,12,12,13,13,13,13,14,14,14,14,
  15,15,15,15,16,16,16,16,17,
}
for bits=0,63 do
  local input={}; for i=1,6 do input[i]=math.floor(bits/2^(i-1))%2 end
  local power,t=E.hiddenPower(ivs(input))
  check("type bits "..bits,power==30 and t==typeOracle[bits+1],t)
end
for i, want in ipairs({30,31,32,35,40,50}) do
  local input=ivs(0); input[fields[i]]=2
  local p,t=E.hiddenPower(input)
  check("power bit "..fields[i],p==want and t==1,p)
end
do
  local p,t=E.hiddenPower(ivs(31)); check("all31 Dark70",p==70 and t==17)
  p,t=E.hiddenPower(ivs(28)); check("upper IV bits ignored",p==30 and t==1)
  local e=battle({ivs=ivs(0)}); e.foe.types={7,7}
  local events=resolve(e)
  check("all0 Fighting30 immunity",find(events,"noEffect") and e.foe.hp==400 and e.rng.draws==3)
  e=battle({ivs=ivs(0)}); damage(e,10,"Fighting30 versus Normal double")
  e=battle({ivs=ivs(31)}); damage(e,18,"Dark70 special split")
  e=battle({ivs=ivs(STEEL),types={8,8}}); e.foe.types={15,15}
  damage(e,30,"Steel70 physical STAB and Ice effectiveness:10*1.5*2")
  e=battle({ivs=ivs(FIRE),types={10,10}}); e.foe.types={12,12}
  damage(e,54,"Fire70 special STAB and Grass effectiveness:18*1.5*2")
  check("Hidden Power shared record immutable",moves[237].power==1 and moves[237].type==0)
  e=battle({ivs=ivs(FIRE)}); e.weather={kind="sun",permanent=false}
  damage(e,26,"sun special term:16*1.5+2")
  e=battle({ivs=ivs(FIRE)}); e.weather={kind="rain",permanent=false}
  damage(e,10,"rain special term:16/2+2")
  e=battle({ivs=ivs(FIRE)}); e.foe.ability=47
  damage(e,10,"Thick Fat halves SpA:floor(50*70*6/50/50)+2")
  e=battle({ivs=ivs(FIRE)}); e.player.ability=66; e.player.hp=100
  damage(e,27,"Blaze power105:floor(100*105*6/50/50)+2")
  e=battle({ivs=ivs(FIRE)}); e.sideStatus.foe.lightScreen=true
  damage(e,10,"Light Screen special term:16/2+2")
  e=battle({ivs=ivs(FIRE)},{0,0,0})
  damage(e,36,"Hidden Power ordinary crit:18*2")
  e=battle({ivs=ivs(FIRE)},{0,1,15})
  damage(e,15,"Hidden Power ordinary random:floor(18*85/100)")
  -- Hustle cuts physical accuracy to80, never special. Draw80 yields81:
  -- Fire hits; Steel misses. Hustle also boosts Steel Atk20->30 on a hit.
  e=battle({ivs=ivs(FIRE)},{80,1,0}); e.player.ability=55
  damage(e,18,"Fire type set before Hustle accuracy")
  check("Fire hit draws3",e.rng.draws==3)
  e=battle({ivs=ivs(STEEL)},{80,1,0}); e.player.ability=55
  events=resolve(e)
  check("Steel Hustle miss draws1 PP1",find(events,"miss") and e.rng.draws==1 and e.player.moves[1].pp==14)
  e=battle({ivs=ivs(STEEL)},{79,1,0}); e.player.ability=55
  damage(e,14,"Steel Hustle boundary hit, Atk30:floor(9*70/50)+2")
  e=battle({ivs=ivs(FIRE)}); e.foe.status=S.FREEZE
  events=damage(e,18,"Fire Hidden Power hits frozen target")
  check("Fire Hidden Power never thaws",S.isFrozen(e.foe.status) and not find(events,"defrostedByFire"))
  e=battle({move=311}); e.weather={kind="sun",permanent=false}; e.foe.status=S.FREEZE
  events=resolve(e)
  check("Fire Weather Ball thaws control",not S.isFrozen(e.foe.status) and find(events,"defrostedByFire"))
end

-- Missing data vetoes before a player turn/AI/RNG/PP. Foe resolution must
-- inspect that foe, even if the player carries complete data, and vice versa.
for _, id in ipairs({216,218,237}) do
  local e=battle({move=id}); local aiCalls=0
  e.foe.friendship=255; e.foe.ivs=ivs(31)
  check("player admission isolated "..id,not e:supportsMove(moves[id],id))
  check("explicit foe admission "..id,e:supportsMove(moves[id],id,e.foe))
  local c=C.new({engine=e,introMessages={},chooseFoeMove=function() aiCalls=aiCalls+1; return 1 end})
  local turn=e.turn
  c:_runTurn({action="move",moveSlot=1})
  check("controller unavailable text "..id,c.messages[1].text=="That move's effect is not available yet.")
  check("controller no turn/PP/RNG/AI "..id,e.turn==turn and e.rng.draws==0 and aiCalls==0
    and e.player.moves[1].pp==15 and e.foe.moves[1].pp==15)
  e=battle({move=id,friendship=255,ivs=ivs(31)})
  e.foe.moves[1].move=id
  local ok,err=pcall(resolve,e,"foe")
  check("foe missing input refuses "..id,not ok and tostring(err):find("unsupported move effect",1,true)
    and e.rng.draws==0 and e.foe.moves[1].pp==15)
  e=battle({move=150}); e.foe.moves[1].move=id
  e.foe.friendship=70; e.foe.ivs=ivs(31)
  local events=resolve(e,"foe")
  check("foe own data resolves "..id,find(events,"damage") and e.rng.draws==3)
end
do
  local e=battle()
  check("unrelated admission preserved",e:supportsMove(moves[33],33) and e:supportsMove(moves[150],150))
  e=battle({ivs=ivs(FIRE)}); e.foe.protected=true
  local events=resolve(e)
  check("protected HP no RNG PP1",find(events,"protected") and e.rng.draws==0 and e.player.moves[1].pp==14)
  e=battle({ivs=ivs(FIRE)}); e.foe.semiInvulnerable="air"
  events=resolve(e)
  check("semi invulnerable HP no RNG",find(events,"miss") and e.rng.draws==0)
  e=battle({move=216,friendship=255}); e.player.statStages.accuracy=0
  e.rng.next16=function(self) self.draws=self.draws+1; return 99 end
  events=resolve(e)
  check("Return miss ordinary RNG1 PP1",find(events,"miss") and e.rng.draws==1 and e.player.moves[1].pp==14)
  e=battle({ivs=ivs(FIRE)})
  e:runTurn({action="move",moveSlot=1},{action="move",moveSlot=1})
  check("whole turn no extra formula RNG",e.rng.draws==3 and e.foe.hp==382)
  local input=ivs(FIRE)
  e=battle({ivs=input}); for _,field in ipairs(fields) do input[field]=31 end
  damage(e,18,"caller IV changes cannot alter battle snapshot")
  e.player.moves[1].move=216; e.player.friendship=70
  e.rng.draws=0
  damage(e,5,"next action uses its own Normal power, no dynamic copy leak")
  check("both shared records unchanged",moves[216].power==1 and moves[216].type==0
    and moves[237].power==1 and moves[237].type==0 and e.currentMove==nil)
end
print(("%d passed, %d failed"):format(passed,failed))
os.exit(failed==0 and 0 or 1)
