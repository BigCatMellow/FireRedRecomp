-- Source oracles: pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788.
-- bsc.c:756-769,9072-9088: strict greater-than hectogram thresholds;
-- bs1.s:2550-2552 -> Hit tail: accuracy, crit, damage, zero-chance secondary.
-- battle_moves.h:874-885 singleton67. No retail weight data/provider here.
-- Level10/Atk20/Def20, neutral/no STAB: floor(6P/50)+2 = 4,6,9,11,14,16.
package.path = package.path .. ";./?.lua"
local E = require("src.core.BattleEngine")
local C = require("src.core.BattleSceneController")
local D = require("tests.battle_test_data")
local S = require("src.core.StatusConditions")
local passed, failed = 0, 0
local function check(name, ok)
  if ok then passed=passed+1 else failed=failed+1; print("FAIL "..name) end
end
local function copy(t)
  if type(t)~="table" then return t end
  local out={}; for k,v in pairs(t) do out[k]=copy(v) end; return out
end
-- Full plain engine/event snapshots (including functions by identity) detect
-- mutation beyond the checked HP/PP fields; no implementation-derived oracle.
local function same(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~="table" then return a==b end
  for k,v in pairs(a) do if not same(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
local function record()
  return {effect=196,power=1,type=1,accuracy=100,pp=20,
    secondaryEffectChance=0,target=0,priority=0,flags=0x33}
end
local function battler(species, speed)
  return E.makeBattler({species=species or 1,level=10,types={11,11},
    stats={hp=400,attack=20,defense=20,speed=speed or 30,spAttack=20,spDefense=20},
    moves={{move=67,pp=20},{move=63,pp=5}}})
end
local function battle(weights, values)
  local moves={}; for id,m in pairs(D.moves) do moves[id]=copy(m) end
  moves[67]=record()
  moves[63]={effect=80,power=150,type=0,accuracy=90,pp=5,
    secondaryEffectChance=0,target=0,priority=0,flags=0x32}
  moves[150]={effect=85,power=0,type=0,accuracy=0,pp=40,
    secondaryEffectChance=0,target=0x10,priority=0,flags=0}
  local rng={draws=0,next16=function(self)
    self.draws=self.draws+1
    local source=values or {0,1,0,99}
    return assert(source[self.draws],"unexpected RNG draw "..self.draws)
  end}
  return E.new({player=battler(1,30),foe=battler(2,20),moves=moves,
    typeChart=D.typeChart,rng=rng,lowKickWeights=weights})
end
local function find(events,kind)
  for _,v in ipairs(events) do if v.type==kind then return v end end
end
local function resolve(e,side,slot)
  local events={}; e:resolveMove(side or "player",slot or 1,events); return events
end
local function damage(e,wanted,name,side)
  local ev=resolve(e,side); local hit=find(ev,"damage")
  check(name,hit and hit.amount==wanted)
  return ev
end
local moveAction={action="move",moveSlot=1}

local powers={{0,20},{99,20},{100,40},{101,40},{249,40},{250,60},{251,60},
  {499,60},{500,80},{501,80},{999,80},{1000,100},{1001,100},{1999,100},
  {2000,120},{2001,120},{65535,120}}
for _,row in ipairs(powers) do check("strict threshold "..row[1],E.lowKickPower(row[1])==row[2]) end
check("nil weight",not pcall(E.lowKickPower,nil))
for _,bad in ipairs({false,"100",0/0,math.huge,-math.huge,-1,65536,0.5}) do
  check("bad pure weight "..tostring(bad),not pcall(E.lowKickPower,bad))
  check("bad mapped weight "..tostring(bad),not pcall(battle,{[2]=bad}))
end
for _,bad in ipairs({0,252,276,412,413,439,440,-1,1.5,"2",false,math.huge,-math.huge}) do
  check("bad map key "..tostring(bad),not pcall(battle,{[bad]=100}))
end
for _,bad in ipairs({false,12,"map",function() error("caller invoked") end,
  setmetatable({[2]=100},{__index=function() error("metamethod invoked") end})}) do
  local p,q=battler(),battler(2); p.isFirstTurn=7;q.isFirstTurn=8
  local ok=pcall(E.new,{player=p,foe=q,moves={},typeChart={},rng={},lowKickWeights=bad})
  check("invalid provider rejected before caller writes",not ok and p.isFirstTurn==7 and q.isFirstTurn==8)
end
for _,badmap in ipairs({{[0]=100},{[2]=-1},{[2]=0/0}}) do
  local p,q=battler(),battler(2); p.isFirstTurn=7;q.isFirstTurn=8
  check("invalid entries before caller writes",not pcall(E.new,
    {player=p,foe=q,moves={},typeChart={},rng={},lowKickWeights=badmap})
    and p.isFirstTurn==7 and q.isFirstTurn==8)
end
for _,species in ipairs({1,201,251,277,410,411}) do
  local e=battle({[species]=0});e.foe.species=species
  check("ordinary internal species "..species,e:supportsMove(e.moves[67],67))
end
for _,species in ipairs({0,252,276,412,413,439,-1,1.5,"2",false,0/0,math.huge,-math.huge}) do
  local e=battle({[2]=250});e.foe.species=species
  check("bad current species "..tostring(species),not e:supportsMove(e.moves[67],67))
end
do
  local e=battle({[2]=250});e.foe.species=nil
  check("missing current species",not e:supportsMove(e.moves[67],67))
  e.foe.species=2
  check("no provider",not battle():supportsMove(record(),67))
  check("empty provider",not battle({}):supportsMove(record(),67))
  check("attacker key cannot admit defender",not battle({[1]=250}):supportsMove(record(),67))
  check("unidentified attacker needs explicit defender",not e:supportsMove(record(),67,{}))
  check("explicit defender",e:supportsMove(record(),67,{},e.foe))
  check("false attacker is not player identity",not e:supportsMove(record(),67,false))
  for _,bad in ipairs({false,2,"defender"}) do
    check("invalid explicit defender",not e:supportsMove(record(),67,e.player,bad))
  end
  check("opposite identity inference",not e:supportsMove(record(),67,e.foe))
  for key,value in pairs({effect=0,power=2,type=0,accuracy=99,pp=19,
      secondaryEffectChance=1,target=0x10,priority=1,flags=0x32}) do
    local m=record();m[key]=value
    check("source record "..key,not e:supportsMove(m,67))
    m=record();m[key]=nil
    check("missing record "..key,not e:supportsMove(m,67))
  end
  check("no arbitrary effect196",not e:supportsMove(record(),68))
end

for _,row in ipairs({{0,4},{100,6},{250,9},{500,11},{1000,14},{2000,16}}) do
  for _,side in ipairs({"player","foe"}) do
    local e=battle({[1]=row[1],[2]=row[1]})
    damage(e,row[2],"literal damage "..side..row[1],side)
    check("four ordered draws "..side..row[1],e.rng.draws==4)
    check("one PP "..side..row[1],e:battler(side).moves[1].pp==19)
    check("shared record unchanged",same(e.moves[67],record()))
  end
end
-- caller weights copied independently; action-local record cannot alias source.
do
  local weights={[1]=100,[2]=250};local e=battle(weights);local q=battle(weights)
  weights[2]=2000;weights[1]=nil
  damage(e,9,"caller mutation ignored")
  damage(q,9,"two engine copies ignored mutation")
  check("private map not exposed",e.lowKickWeights==nil)
  e.moves[67].power=120
  check("caller malformed move mutation refuses",not e:supportsMove(e.moves[67],67))
  q.foe.species=1;q.rng.draws=0
  damage(q,6,"fresh current target species")
  q.foe.species=3
  check("missing changed species refuses",not q:supportsLowKickAction("player",moveAction,"selection"))
end

-- Source modeled physical modifiers; held items/Battle/Shell Armor and extra
-- paralysis/confusion/tutorial producers are explicitly outside four-draw scope.
for _,row in ipairs({
  {"Fighting STAB",13,function(e)e.player.types={1,1}end},
  {"Normal weakness",18,function(e)e.foe.types={0,0}end},
  {"Huge Power",16,function(e)e.player.ability=37 end},
  {"Pure Power",16,function(e)e.player.ability=74 end},
  {"Hustle",12,function(e)e.player.ability=55 end},
  {"burn",5,function(e)e.player.status=S.BURN end},
  {"rain",9,function(e)e.weather.kind="rain"end},
  {"sun",9,function(e)e.weather.kind="sun"end},
  {"WG super",18,function(e)e.foe.types={0,0};e.foe.ability=25 end},
}) do
  local e=battle({[2]=250});row[3](e)
  damage(e,row[2],row[1]);check(row[1].." draws",e.rng.draws==4)
end
do
  local e=battle({[2]=250},{0,0,0,99})
  local events=damage(e,18,"critical doubles base")
  check("critical event and four draws",find(events,"critical") and e.rng.draws==4)
end
for _,kind in ipairs({"Ghost","WG neutral"}) do
  local e=battle({[2]=250})
  if kind=="Ghost" then e.foe.types={7,7} else e.foe.ability=25 end
  local events=resolve(e)
  check(kind.." zero HP",e.foe.hp==400 and not find(events,"damage"))
  check(kind.." event",find(events,kind=="Ghost" and "noEffect" or "wonderGuard")~=nil)
  check(kind.." exactly four draws",e.rng.draws==4)
end
for _,row in ipairs({
  {"lowered accuracy",1,19,"miss",function(e)e.player.statStages.accuracy=0 end,{99}},
  {"Hustle miss",1,19,"miss",function(e)e.player.ability=55 end,{80}},
  {"Protect",0,19,"protected",function(e)e.foe.protected=true end},
  {"Fly",0,19,"miss",function(e)e.foe.semiInvulnerable="air" end},
  {"Dig",0,19,"miss",function(e)e.foe.semiInvulnerable="underground" end},
  {"sleep",0,20,"fastAsleep",function(e)e.player.status=3 end},
  {"flinch",0,20,"flinched",function(e)e.player.flinched=true end},
}) do
  local e=battle({[2]=250},row[6]);row[5](e);local events=resolve(e)
  check(row[1].." event",find(events,row[4])~=nil)
  check(row[1].." draws/PP/HP",e.rng.draws==row[2] and e.player.moves[1].pp==row[3] and e.foe.hp==400)
end

-- Literal divergent lock contexts. Every call checks the entire unchanged
-- engine (timers, locks, old snapshot, flags, PP, events and RNG included).
for _,side in ipairs({"player","foe"}) do
  local cases={
    {"timer1 selected Low Kick",{recharging=true,rechargeTimer=1,lockedSlot=2},1,false,false,true},
    {"timer2 selected Low Kick",{recharging=true,rechargeTimer=2,lockedSlot=2},1,false,true,true},
    {"timer1 all zero",{recharging=true,rechargeTimer=1,lockedSlot=2},1,true,true,true},
    {"timer2 all zero",{recharging=true,rechargeTimer=2,lockedSlot=2},1,true,true,true},
    {"unlocked all zero",{},1,true,true,true},
    {"charging zero Low Kick",{charging=true,lockedSlot=1},2,true,false,false},
    {"rampage zero Low Kick",{rampageTurns=2,lockedSlot=1},2,true,false,false},
    {"rollout zero Low Kick",{rolloutTimer=2,lockedSlot=1},2,true,false,false},
    {"saved cleared lock passed Low Kick",{},1,true,true,false,true},
    {"saved cleared lock passed Hyper Beam",{},2,true,true,true,true},
    {"live nil slot direct fallback",{recharging=true,rechargeTimer=1},1,false,false,false},
  }
  for _,row in ipairs(cases) do
    local e=battle();local b=e:battler(side)
    for k,v in pairs(row[2]) do b[k]=v end
    if row[4] then for _,slot in ipairs(b.moves) do slot.pp=0 end end
    e.lockedThisTurn={[side]=row[7] or false};e.forcedSwitchEvents={{type="sentinel"}}
    for i,context in ipairs({"selection","resolution"}) do
      local before=copy(e)
      local ok,reason=e:supportsLowKickAction(side,{action="move",moveSlot=row[3]},context)
      check(side..row[1]..context,ok==row[i+4])
      check("reason bounded",ok or (type(reason)=="string" and #reason<100))
      check("planner immutable "..side..row[1]..context,same(e,before))
    end
  end
  for _,context in ipairs({"selection","resolution"}) do
    local e=battle();e.lockedThisTurn={[side]=true};local before=copy(e)
    check("context mandatory",not pcall(e.supportsLowKickAction,e,side,moveAction))
    check("nonmove retains admission",e:supportsLowKickAction(side,{action="run"},context))
    check("nonmove pure",same(e,before))
  end
  local e=battle();e:battler(side).charging=true
  local before=copy(e)
  check("selection nil locked slot loud",not pcall(e.supportsLowKickAction,e,side,moveAction,"selection"))
  check("malformed selection pure",same(e,before))
  check("direct live nil slot fallback Low Kick refuses",not e:supportsLowKickAction(side,moveAction,"resolution"))
end

-- Exercise the divergent planner outcomes at their real call sites too.
for _,side in ipairs({"player","foe"}) do
  for _,timer in ipairs({1,2}) do
    local e=battle();local b=e:battler(side)
    b.recharging=true;b.rechargeTimer=timer;b.lockedSlot=2
    local ev=resolve(e,side)
    check("direct live recharge ignores selected Low Kick "..side..timer,
      find(ev,"mustRecharge") and e.rng.draws==0 and b.rechargeTimer==0)
  end
  local e=battle(nil,{0,1,0});local b=e:battler(side)
  b.recharging=true;b.rechargeTimer=1;b.lockedSlot=2
  for _,slot in ipairs(b.moves) do slot.pp=0 end
  local other=side=="player" and e.foe or e.player
  other.moves[1].move=150
  local ev=e:runTurn(moveAction,moveAction)
  local used
  for _,event in ipairs(ev) do if event.type=="useMove" and event.move==165 then used=event end end
  check("selection timer1 zero PP actual Struggle "..side,
    used and used.move==165 and used.side==side and e.rng.draws==3)
end
do
  local e=battle();e.player.recharging=true;e.player.rechargeTimer=1;e.player.lockedSlot=2
  local ai=0;local c=C.new({engine=e,chooseFoeMove=function()ai=ai+1;return 1 end})
  local before=copy(e);c:_runTurn(moveAction)
  check("controller timer1 refusal before AI",ai==0 and same(e,before))
  e=battle();e.player.recharging=true;e.player.rechargeTimer=2;e.player.lockedSlot=2
  e.foe.moves[1].move=150
  c=C.new({engine=e,chooseFoeMove=function()ai=ai+1;return 1 end});c:_runTurn(moveAction)
  check("controller timer2 selects Hyper Beam recharge",e.turn==1 and e.rng.draws==0 and ai==1)
  e=battle({[1]=250})
  e.player.recharging=true;e.player.rechargeTimer=2;e.player.lockedSlot=2
  local incoming=battler(3)
  local ev=e:runTurn({action="switch",battler=incoming},moveAction)
  check("locked requested switch targets current player",not find(ev,"switch")
    and find(ev,"damage").amount==9 and e.player.species==1)
end

-- Synthetic, source-unreachable Low Kick/Rollout mismatch checks only effective
-- record and RNG. It makes no PP claim; real Rollout0PP is covered by V3.
for _,side in ipairs({"player","foe"}) do
  local e=battle({[1]=250,[2]=250});local b=e:battler(side)
  b.moves[1].pp=0;b.rolloutTimer=2;b.lockedSlot=1
  damage(e,9,"live locked Low Kick at zero PP "..side,side)
  check("synthetic live lock Low Kick draws "..side,e.rng.draws==4)
  e=battle({[1]=250,[2]=250});b=e:battler(side);b.moves[1].pp=0
  e.lockedThisTurn={[side]=true}
  local ev=resolve(e,side)
  check("saved cleared lock zero PP canceller boundary "..side,
    find(ev,"noPP") and not find(ev,"damage") and e.rng.draws==0)
end

-- Refusal at each exact engine boundary, both sides, after caller sentinels.
for _,side in ipairs({"player","foe"}) do
  for _,method in ipairs({"resolveMove","resolveMoveCore","runTurn"}) do
    local e=battle();e.currentMove={sentinel=true};e.moveDamageDealt=9
    e.lockedThisTurn={[side]=true};e:battler(side).moves[1].pp=0
    e.player.flinched=true;e.foe.targetNotAffected=true;e.forcedSwitchEvents={{type="old"}}
    -- selection ignores old snapshot, but other slot has PP so Low Kick remains.
    local events={{type="caller"}};local before,evBefore=copy(e),copy(events)
    local ok,err
    if method=="runTurn" then
      local other={action="move",moveSlot=2}
      ok,err=pcall(e.runTurn,e,side=="player" and moveAction or other,side=="foe" and moveAction or other)
    else ok,err=pcall(e[method],e,side,1,events) end
    check(method..side.." error",not ok and tostring(err):find("Low Kick",1,true))
    check(method..side.." exact state",same(e,before) and same(events,evBefore))
  end
end
-- RunTurn looks ahead to incoming voluntary target; lock overrides switch.
do
  local incoming=battler(3)
  local e=battle({[1]=250,[2]=250});e.player.moves[1].move=150
  local before=copy(e)
  check("switch incoming unsupported",not pcall(e.runTurn,e,{action="switch",battler=incoming},moveAction))
  check("switch refusal pre-entry",same(e,before) and incoming.isFirstTurn==2)
  e=battle({[3]=100});e.player.moves[1].move=150
  local ev=e:runTurn({action="switch",battler=incoming},moveAction)
  check("incoming target weight",find(ev,"switch") and find(ev,"damage").amount==6 and e.player==incoming)
  e=battle({[1]=250});e.player.charging=true;e.player.lockedSlot=1
  before=copy(e)
  check("locked switch validates actual player Low Kick",not pcall(e.runTurn,e,{action="switch",battler=incoming},moveAction))
  check("locked switch immutable",same(e,before))
end
-- Forced replacement must resolve first; next action reads actual new species.
do
  local e=battle({[2]=250,[3]=500});e.awaitingForcedSwitch="foe";e.pendingForcedSwitches={"foe"}
  local before=copy(e)
  check("pending forced replacement blocked",not pcall(e.runTurn,e,moveAction,moveAction) and same(e,before))
  e:resolveForcedSwitch("foe",battler(3));e.rng.draws=0
  damage(e,11,"forced replacement target")
  e.foe.species=4
  before=copy(e)
  check("replacement unknown next action refuses",not pcall(resolve,e) and same(e,before))
end

-- Controller player selection refuses before AI; selected foe failure retains
-- the producer's prior RNG. No main persistence/bag rollback claim is made.
do
  local e=battle();local ai=0
  local c=C.new({engine=e,chooseFoeMove=function()ai=ai+1;return 1 end})
  local before=copy(e);c:_runTurn(moveAction)
  check("player refusal no AI or engine mutation",ai==0 and same(e,before))
  check("existing refusal text",c.messages[1].text=="That move's effect is not available yet.")
  check("player refusal returns MOVE",c.afterMessages==C.MOVE)
  e=battle({[2]=250},{77});e.player.moves[1].move=150
  c=C.new({engine=e,chooseFoeMove=function(engine)ai=ai+1;engine.rng:next16();return 1 end})
  before=copy(e);before.rng.draws=1
  local ok,err=pcall(c._runTurn,c,moveAction)
  check("foe error propagates",not ok and tostring(err):find("Low Kick",1,true))
  check("chooser prior draw retained; no engine mutation",e.rng.draws==1 and ai==1 and same(e,before))
  -- A raw Low Kick slot must allow effective Struggle at 0 PP.
  e=battle(nil,{0,1,0});for _,slot in ipairs(e.player.moves)do slot.pp=0 end
  e.foe.moves[1].move=150
  c=C.new({engine=e,chooseFoeMove=function()return 1 end});c:_runTurn(moveAction)
  check("controller zero PP Struggle",e.turn==1 and e.player.moves[1].pp==0 and e.foe.hp<400)
end
-- Unaffected ordinary positive and nonmove routes keep their original draws.
do
  local e=battle(nil,{0,1,0});e.player.moves[1].move=33
  local ev=resolve(e)
  check("plain hit original three draws",find(ev,"damage") and e.rng.draws==3)
  e=battle();e.player.moves[1].move=150
  check("Splash no RNG",find(resolve(e),"splash") and e.rng.draws==0)
end
print(("battle_low_kick_test: %d passed, %d failed"):format(passed,failed))
os.exit(failed==0 and 0 or 1)
