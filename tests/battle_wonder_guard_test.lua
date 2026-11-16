-- Source-only WG oracles, pret c75f352. bsc.c:1274-1417 normal/miss,
-- :4346-4436 ordered typecalc2; bs1.s route commands cited inline. Values
-- are literal source command counts/arithmetic, never implementation reads.
package.path = package.path .. ";./?.lua"
local E = require("src.core.BattleEngine")
local F = require("src.core.BattleFormulas")
local C = require("src.core.BattleSceneController")
local D = require("tests.battle_test_data")
local S = require("src.core.StatusConditions")
local passed, failed = 0, 0
local function check(name, ok, detail)
  if ok then passed=passed+1 else failed=failed+1; print("FAIL "..name..": "..tostring(detail)) end
end
local function record(effect, power, t, accuracy)
  return {effect=effect,power=power,type=t,accuracy=accuracy or 100,pp=20,
    secondaryEffectChance=0,target=effect==85 and 0x10 or 0,priority=0,flags=0x32}
end
local function battle(m, opts)
  opts=opts or {}
  local function mon(t, id)
    return E.makeBattler({species=1,level=opts.level or 20,
      stats={hp=400,attack=100,defense=100,speed=30,spAttack=100,spDefense=100},
      types=t,moves={{move=id,pp=20}},ivs=opts.ivs})
  end
  local id=opts.id or 500
  local moves={[id]=m,[150]=record(85,0,0),[165]=record(48,50,0)}
  local rng={draws=0,next16=function(self)
    self.draws=self.draws+1
    return (opts.values or {0,1,0,0})[self.draws] or 0
  end}
  local p,q=mon(opts.attackerTypes or {14,14},id),mon(opts.types or {0,0},150)
  local e=E.new({player=p,foe=q,moves=moves,typeChart=D.typeChart,rng=rng})
  if opts.side=="foe" then e.player,e.foe=e.foe,e.player end
  local side=opts.side or "player"
  local a,d=e:battler(side),e:battler(side=="player" and "foe" or "player")
  a.ability=0;d.ability=opts.ability==nil and 25 or opts.ability
  if opts.protect then d.protected=true end
  d.semiInvulnerable=opts.semi
  if opts.hp then d.hp=opts.hp end
  if opts.attackerHP then a.hp=opts.attackerHP end
  return e,a,d,side
end
local function resolve(e,side)
  local events={};e:resolveMove(side or "player",1,events);return events
end
local function find(events,kind)
  for _,v in ipairs(events) do if v.type==kind then return v end end
end
local function result(events)
  for _,v in ipairs(events) do
    if v.type=="wonderGuard" or v.type=="noEffect" or v.type=="miss" or v.type=="protected" then return v.type end
  end
end
local function blocked(label,m,opts,draws,kind)
  opts=opts or {}
  for _,side in ipairs(opts.side and {opts.side} or {"player","foe"}) do
    local input={};for k,v in pairs(opts) do input[k]=v end;input.side=side
    local e,a,d,s=battle(m,input);local hp=d.hp;local events=resolve(e,s)
    check(side..label.." result",result(events)==(kind or "wonderGuard"),result(events))
    check(side..label.." HP",d.hp==hp and not find(events,"damage"))
    check(side..label.." PP",a.moves[1].pp==19,a.moves[1].pp)
    check(side..label.." RNG",e.rng.draws==draws,e.rng.draws)
  end
end
-- Ordinary hit: accuracy+crit+random+new blocked tail =4; successful
-- super-effective control remains existing3 (generic unblocked tail gap).
local chartCases={
  {"neutral",10,{0,0},true}, {"super",10,{12,12},false},
  {"4x",10,{12,6},false}, {"resist",10,{11,11},true},
  {"quarter",10,{11,5},true}, {"dual neutral",10,{11,12},true},
  {"immune",13,{4,4},true}, {"water ground",13,{11,4},true},
  {"ground flying",13,{4,2},true},
}
for _,side in ipairs({"player","foe"}) do
  for _,r in ipairs(chartCases) do
    local e,a,d,s=battle(record(0,40,r[2]),{types=r[3],side=side})
    local events=resolve(e,s)
    check(side..r[1].." blocked",(find(events,"wonderGuard")~=nil)==r[4])
    check(side..r[1].." HP",r[4] and d.hp==400 or not r[4] and d.hp<400)
    check(side..r[1].." draws",e.rng.draws==(r[4] and 4 or 3),e.rng.draws)
    check(side..r[1].." identity",not r[4] or find(events,"wonderGuard").target==(side=="player" and "foe" or "player"))
  end
end
-- Scan order Electric: Water20, Electric5, Grass5, Ground0, Flying20,
-- Dragon5. Defender type order never controls chart traversal.
local scans={
  {{11,4},"noEffect",true,false,true},{{4,11},"noEffect",true,false,true},
  {{4,2},"noEffect",false,false,true},{{2,4},"noEffect",false,false,true},
  {{4,4},"wonderGuard",false,false,true},
}
for i,r in ipairs(scans) do
  local all=F.wonderGuardScan(13,r[1],D.typeChart,false)
  local ordered=F.wonderGuardScan(13,r[1],D.typeChart,true)
  check("miss OR super "..i,all.superEffective==(i<=4))
  check("ordered super "..i,ordered.superEffective==r[3])
  check("zero global "..i,all.noEffect and ordered.noEffect)
  blocked("electric miss "..i,record(0,40,13,1),{types=r[1],values={99}},1,r[2])
end
blocked("fire dual-neutral miss",record(0,40,10,1),{types={11,12},values={99}},1)
blocked("ordinary miss",record(0,40,0,1),{values={99}},1)
blocked("Protect early",record(0,40,0),{protect=true},0,"protected")
blocked("semi early",record(0,40,0),{semi="air"},0,"miss")
-- Hit-all explicitly runs normal typecalc even following Protect.
for _,effect in ipairs({147,126}) do
  local id=effect==126 and 222 or 89
  blocked("hit-all protect "..effect,record(effect,1,4),{id=id,protect=true},effect==126 and 1 or 0)
  blocked("hit-all miss "..effect,record(effect,1,4,1),{id=id,values={99,99}},effect==126 and 2 or 1)
end
-- Rollout / Ice Ball typecalc2 before any critical/random draw; lock ends.
for _,t in ipairs({5,15}) do
  for _,mode in ipairs({"land","miss","protect","semi"}) do
    local opts={values={mode=="miss" and 99 or 0},protect=mode=="protect",semi=mode=="semi" and "air" or nil}
    local e,a,d=battle(record(117,30,t,50),opts);a.rolloutTimer=3;a.lockedSlot=1
    local ev=resolve(e)
    check("rollout "..t..mode.." result",result(ev)=="wonderGuard",result(ev))
    check("rollout "..t..mode.." state",a.rolloutTimer==0 and a.lockedSlot==nil and d.hp==400)
    check("rollout "..t..mode.." RNG",e.rng.draws==((mode=="protect" or mode=="semi") and 0 or 1),e.rng.draws)
    check("rollout "..t..mode.." PP",a.moves[1].pp==(mode=="protect" and 19 or 20))
  end
end
for _,mode in ipairs({"land","miss","protect","semi"}) do
  local e,a,d=battle(record(119,10,6,50),{values={mode=="miss" and 99 or 0,1},protect=mode=="protect",semi=mode=="semi" and "air" or nil})
  a.furyCutterCounter=4;local ev=resolve(e)
  check("cutter "..mode.." reset",a.furyCutterCounter==0 and d.hp==400)
  check("cutter "..mode.." result",result(ev)==((mode=="protect" and "protected") or (mode=="semi" and "miss") or "wonderGuard"))
  check("cutter "..mode.." RNG",e.rng.draws==((mode=="land" and 2) or (mode=="miss" and 1) or 0),e.rng.draws)
end
-- Present typecalc precedes choice; healing clears actual immunity only.
for _,hp in ipairs({300,400}) do
  local e,a,d=battle(record(122,1,0),{hp=hp,values={0,204}})
  local ev=resolve(e)
  check("present heal retained "..hp,find(ev,hp==400 and "restoreHPFull" or "restoreHP")~=nil)
  check("present heal no HP "..hp,d.hp==hp and not find(ev,"damage") and not find(ev,"wonderGuard"))
  check("present heal RNG "..hp,e.rng.draws==2)
end
blocked("Present damage",record(122,1,0),{values={0,0,1,0,0}},5)
for _,effect in ipairs({41,87,130,40,189}) do
  blocked("fixed "..effect,record(effect,1,0),{attackerHP=200},2)
end
blocked("Psywave accepted",record(88,1,14),{values={0,10,0}},3)
blocked("Psywave rejected 11 15 10",record(88,1,14),{values={0,11,15,10,0}},5)
blocked("OHKO",record(38,1,0,30),{level=1},1)
do
  local e,a,d=battle(record(189,1,0),{attackerHP=400});local ev=resolve(e)
  check("Endeavor prerequisite",find(ev,"moveFailed") and e.rng.draws==0 and d.hp==400 and a.moves[1].pp==19)
end
-- Multi-hit: count when variable, crit, no damage-random, source tail.
for _,effect in ipairs({29,44,77}) do
  blocked("multi "..effect,record(effect,20,0),{values={0,0,1,0}},effect==29 and 4 or 3)
end
-- Triple Kick: source presentation counter1 before blocked damage, MISSED
-- cleared, zero actual HP/count of landed attacks is deliberately distinct.
for _,r in ipairs({{{11,11},false,false},{{3,3},true,false},{{7,7},false,true}}) do
  local e,a,d=battle(record(104,10,1),{id=167,types=r[1],values={0,1,0,0}})
  local ev=resolve(e);local count=find(ev,"multiHit")
  check("TripleKick HP "..r[1][1],d.hp==400 and not find(ev,"damage") and not find(ev,"wonderGuard"))
  check("TripleKick result "..r[1][1],r[3] and result(ev)=="noEffect" and not count or not r[3] and count and count.hits==1 and count.notVeryEffective==r[2])
  check("TripleKick RNG "..r[1][1],e.rng.draws==4,e.rng.draws)
end
-- Explosion crit/random precede accuracy, no tail, user always faints.
for _,r in ipairs({{false,false,"wonderGuard",3},{true,false,"protected",2},{false,true,"wonderGuard",3}}) do
  local e,a,d=battle(record(7,250,0,50),{id=153,protect=r[1],values={1,0,r[2] and 99 or 0}})
  local ev=resolve(e)
  check("Explosion reason "..r[3],result(ev)==r[3],result(ev))
  check("Explosion state",a.hp==0 and d.hp==400 and find(ev,"selfDestruct") and find(ev,"faint"))
  check("Explosion RNG",e.rng.draws==r[4],e.rng.draws)
end
-- Crash random miss: WG-MISSED permits crash, actual immunity suppresses.
for _,r in ipairs({{{11,11},"wonderGuard",true,2},{{7,7},"wonderGuard",false,1}}) do
  local e,a,d=battle(record(45,70,1,1),{id=26,types=r[1],values={99,0}})
  local ev=resolve(e)
  check("JumpKick reason",result(ev)==r[2],result(ev))
  check("JumpKick state",d.hp==400 and (a.hp<400)==r[3])
  check("JumpKick RNG",e.rng.draws==r[4],e.rng.draws)
end
-- Existing locked Rampage survives ability-only block; true immunity marks
-- targetNotAffected, consumed by existing end-of-turn cancellation.
for _,immune in ipairs({false,true}) do
  local e,a,d=battle(record(27,90,0),{types=immune and {7,7} or {0,0}})
  a.rampageTurns=3;a.lockedSlot=1
  local ev=resolve(e)
  check("Rampage block",result(ev)=="wonderGuard" and a.rampageTurns==3 and a.moves[1].pp==20)
  check("Rampage actual immunity",(a.targetNotAffected==true)==immune)
  check("Rampage RNG",e.rng.draws==4,e.rng.draws)
end
-- Dynamic Hidden Power FIRE (bit0 sum34, bit1 sum63) and Weather Ball.
local ivs={hp=2,attack=3,defense=2,speed=2,spAttack=2,spDefense=3}
for _,r in ipairs({{{0,0},true},{{12,12},false}}) do
  local m=record(135,1,0)
  local e,a,d=battle(m,{id=237,types=r[1],ivs=ivs});d.status=S.FREEZE
  local ev=resolve(e)
  check("HP dynamic guard",(find(ev,"wonderGuard")~=nil)==r[2])
  check("HP no defrost",d.status==S.FREEZE and not find(ev,"defrostedByFire"))
  check("HP immutable",m.type==0 and m.power==1)
end
do
  local m=record(135,1,0,1)
  local e=battle(m,{id=237,types={12,12},ivs=ivs,values={99}})
  check("HP miss dynamic super",result(resolve(e))=="miss")
  local n=record(203,50,0);e=battle(n,{id=311,types={12,12}})
  e.weather={kind="sun",turns=5};local ev=resolve(e)
  check("WeatherBall dynamic guard",find(ev,"damage") and not find(ev,"wonderGuard") and n.type==0)
end
-- Negative controls and preexisting RNG limits are retained literally.
for _,effect in ipairs({0,48,3,89,144,26}) do
  local e,a,d=battle(record(effect,40,0),{ability=0});local ev=resolve(e)
  check("no ability "..effect,find(ev,"damage") and not find(ev,"wonderGuard"))
  check("unblocked RNG gap "..effect,e.rng.draws==3,e.rng.draws)
end
for _,effect in ipairs({89,144,26}) do
  local e,a,d=battle(record(effect,40,0));local ev=resolve(e)
  check("B fallback excluded "..effect,find(ev,"damage") and not find(ev,"wonderGuard") and e.rng.draws==3)
end
do
  local e,a,d=battle(record(0,40,0),{id=165});local ev=resolve(e)
  check("Struggle bypass",find(ev,"damage") and not find(ev,"wonderGuard") and e.rng.draws==3)
  e,a,d=battle(record(85,0,0));ev=resolve(e)
  check("power0 bypass",find(ev,"splash") and not find(ev,"wonderGuard") and e.rng.draws==0)
  e,a,d=battle(record(3,20,12),{attackerHP=200});ev=resolve(e)
  check("Absorb blocked no drain or tail",find(ev,"wonderGuard") and a.hp==200 and d.hp==400 and e.rng.draws==3)
end
-- CERTAIN secondaries still consume discarded tail, never apply effects.
for _,effect in ipairs({48,182,204,129,171,80,27,158}) do
  do
    local e,a,d=battle(record(effect,40,0));a.isFirstTurn=1;local ev=resolve(e)
    check("blocked secondary "..effect,find(ev,"wonderGuard") and d.hp==400 and a.hp==400 and not a.recharging and not a.flinched and e.rng.draws==4)
  end
end
-- Narrow controller text: correct current defender, no damage/HP event.
for _,side in ipairs({"player","foe"}) do
  local e,a,d,s=battle(record(0,40,0),{side=side})
  local c=C.new({engine=e,introMessages={},playerName="ALLY",foeName="FOE"})
  local entries=c:_eventMessages(resolve(e,s));local found=false;local hp=false
  for _,v in ipairs(entries) do
    if v.text==(side=="player" and "FOE" or "ALLY").." avoided\ndamage with WONDER GUARD!" then found=true end
    if v.hpSide then hp=true end
  end
  check("controller defender "..side,found)
  check("controller no HP "..side,not hp)
end
-- Source order is observable at actual Rollout call sites, even after
-- protection. Synthetic Electric records isolate chart-order differences;
-- these tests do not claim such a move exists in the source inventory.
for _,r in ipairs({{{11,4},"noEffect"},{{4,2},"wonderGuard"},{{4,4},"wonderGuard"}}) do
  blocked("ordered rollout protected "..r[1][1]..r[1][2],record(117,30,13),
    {types=r[1],protect=true},0,r[2])
end
blocked("super Rollout protect",record(117,30,5),{types={6,6},protect=true},0,"protected")
-- R2: preexisting MISSED suppresses normal typecalc's global super/resist;
-- unlike ordinary miss-helper and Rollout's ordered local OR flags.
blocked("super hit-all protect",record(147,100,4),{types={10,10},protect=true},0)
-- NO_ACC checks and early exits never use the ordinary random-miss scan.
for _,effect in ipairs({38,88,41,40}) do
  blocked("special early protect "..effect,record(effect,1,0),{protect=true},0,"protected")
end
-- A super-effective Psywave must retain the pre-clear guard predicate.
-- Level20 *150%=30, no ordinary crit/random/tail (existing unblocked gap).
do
  local e,a,d=battle(record(88,1,14),{types={1,1},values={0,10}})
  local ev=resolve(e);check("Psywave super allowed",find(ev,"damage") and find(ev,"damage").amount==30 and e.rng.draws==2)
end
-- A record-power0 dynamic move must never activate WG, even with nonzero
-- transient power. Admission/formulas remain their established behavior.
do
  local m=record(121,0,0)
  local e,a,d=battle(m,{id=216});a.friendship=255;local ev=resolve(e)
  check("original record power zero",find(ev,"damage") and not find(ev,"wonderGuard") and e.rng.draws==3 and m.power==0)
end
-- Charge turn1 has no typecalc; release hits WG without a second PP cost.
for _,effect in ipairs({39,75,145,151,155}) do
  local e,a,d=battle(record(effect,80,0),{id=effect==155 and 19 or 500})
  local ev=resolve(e)
  check("charge excluded "..effect,find(ev,"chargeTurn") and not find(ev,"wonderGuard") and d.hp==400 and e.rng.draws==0 and a.moves[1].pp==19)
  ev=resolve(e)
  check("release guarded "..effect,find(ev,"wonderGuard") and not a.charging and d.hp==400 and e.rng.draws==4 and a.moves[1].pp==19)
end
-- Solar Beam sun bypasses charge, still guards on the attacking turn.
do
  local e,a,d=battle(record(151,120,12));e.weather={kind="sun",permanent=false}
  local ev=resolve(e)
  check("sun Solar Beam",find(ev,"wonderGuard") and not find(ev,"chargeTurn") and d.hp==400 and e.rng.draws==4 and a.moves[1].pp==19)
end
-- Explosion priority when an earlier type immunity overlaps Guard and a
-- later protect/random failure supplies a new reason.
blocked("Explosion protects immune target",record(7,250,0),{id=153,types={7,7},protect=true},2,"noEffect")
blocked("Explosion miss immune target",record(7,250,0,1),{id=153,types={7,7},values={1,0,99}},3)
blocked("Explosion semi retains guard",record(7,250,0),{id=153,semi="air",values={1,0}},2)
-- The ordinary miss scan may differ from normal typecalc even in Explosion.
blocked("Explosion Electric immune super",record(7,250,13,1),{id=153,types={4,2},values={1,0,99}},3,"noEffect")
-- Crash after Protect/semi prints that early reason; the crash typecalc's
-- MISSED is explicitly cleared, while type immunity leaves zero HP change.
for _,mode in ipairs({"protect","semi"}) do
  for _,immune in ipairs({false,true}) do
    local e,a,d=battle(record(45,70,1,1),{id=26,types=immune and {7,7} or {11,11},
      protect=mode=="protect",semi=mode=="semi" and "air" or nil,values={0}})
    local ev=resolve(e);local crash=find(ev,"crash")
    check("crash early reason "..mode,result(ev)==(mode=="protect" and "protected" or "miss"))
    check("crash early state "..mode,crash and (crash.amount==0)==immune and (a.hp==400)==immune and d.hp==400 and e.rng.draws==1)
  end
end
-- Present healing retains source text with unchanged HP, including a Ghost
-- immunity which the branch clears while leaving Wonder Guard's MISSED.
do
  local e,a,d=battle(record(122,1,0),{types={7,7},hp=300,values={0,204}})
  local ev=resolve(e);local c=C.new({engine=e,introMessages={},foeName="GUARD"})
  local messages=c:_eventMessages(ev);local regained=false
  for _,v in ipairs(messages) do if v.text=="GUARD regained\nhealth!" then regained=true end end
  check("Present Ghost MISSED retains heal text",regained and d.hp==300 and find(ev,"restoreHP").amount==0 and e.rng.draws==2)
end
-- Unblocked Triple Kick retains its existing count and generic tail gap
-- when a later accuracy roll fails (a WG defender alone is insufficient).
do
  local e,a,d=battle(record(104,10,1,50),{id=167,types={0,0},values={0,1,0,99}})
  local ev=resolve(e);local count=find(ev,"multiHit")
  check("unblocked later kick miss",count and count.hits==1 and find(ev,"damage") and not find(ev,"wonderGuard") and not find(ev,"miss") and e.rng.draws==4)
end
blocked("TripleKick random miss guard",record(104,10,1,1),{id=167,types={11,11},values={99,0}},2)
blocked("TripleKick early semi",record(104,10,1),{id=167,types={11,11},semi="air"},0,"miss")
-- Identical locked states on both sides reach existing end-of-turn cleanup:
-- pure MISSED decrements3->2, true immunity cancels without fatigue RNG.
for _,side in ipairs({"player","foe"}) do
  for _,immune in ipairs({false,true}) do
    local e,a,d=battle(record(27,90,0),{side=side,types=immune and {7,7} or {0,0}})
    a.rampageTurns=3;a.lockedSlot=1
    local ev=resolve(e,side)
    e:resolveStatusEndTurn(ev,{side,side=="player" and "foe" or "player"})
    check("endturn rampage "..side..tostring(immune),a.rampageTurns==(immune and 0 or 2) and (a.lockedSlot==nil)==immune and not find(ev,"fatigueConfusion") and e.rng.draws==4)
  end
end
-- Magnitude chooses strength BEFORE accuracy. Roll99 => Magnitude10,
-- roll0 then lands: strength+accuracy+crit+random=4, NO secondary tail
-- (bs1.s:1679-1688,1830-1875). Assert both attacker sides.
for _,side in ipairs({"player","foe"}) do
  local e,a,d=battle(record(126,1,4),{id=222,side=side,values={99,0,1,0}})
  local ev=resolve(e,side)
  check("Magnitude strength before guard "..side,find(ev,"magnitude").level==10 and find(ev,"wonderGuard") and e.rng.draws==4 and d.hp==400 and a.moves[1].pp==19)
end
-- Weather Ball dynamic miss type: Fire versus Grass is super, Normal
-- would be neutral; inverse Water target is resisted and uses ability text.
for _,r in ipairs({{{12,12},"miss"},{{11,11},"wonderGuard"}}) do
  local m=record(203,50,0,1)
  local e=battle(m,{id=311,types=r[1],values={99}});e.weather={kind="sun",permanent=false}
  local ev=resolve(e)
  check("WeatherBall miss dynamic "..r[1][1],result(ev)==r[2] and e.rng.draws==1 and m.type==0)
end
-- A blocked hit never applies freeze/burn/poison/stat/trap/recoil, and
-- never triggers source producer-history wiring (which remains excluded).
for _,effect in ipairs({4,5,6,68,69,70,140,129,42,48,198}) do
  local m=record(effect,40,0);m.secondaryEffectChance=100
  local e,a,d=battle(m);local ev=resolve(e)
  check("secondary suppressed "..effect,find(ev,"wonderGuard") and d.hp==400 and a.hp==400 and d.status==0 and d.statStages.attack==6 and d.statStages.defense==6 and d.statStages.speed==6 and a.statStages.attack==6 and d.wrapTurns==0 and not find(ev,"recoil") and not find(ev,"statChange") and not find(ev,"statusApplied") and e.rng.draws==4)
end
-- Last locked turn: pure ability MISSED can finish with fatigue confusion;
-- true immunity cancels first. Literal extra draw is the confusion duration.
for _,immune in ipairs({false,true}) do
  local e,a,d=battle(record(27,90,0),{types=immune and {7,7} or {0,0}})
  a.rampageTurns=1;a.lockedSlot=1;local ev=resolve(e)
  e:resolveStatusEndTurn(ev,{"player","foe"})
  check("last rampage immunity "..tostring(immune),a.rampageTurns==0 and a.lockedSlot==nil and (find(ev,"fatigueConfusion")~=nil)==not immune and e.rng.draws==(immune and 4 or 5))
end
-- Exact47 independent review R1-R3 corrections. Literal command-order
-- oracles: hit-all has no seteffectwithchance; its missed-label typecalc
-- receives global MISSED; Brick Break clears MISSED/DOESNT_AFFECT only
-- after actual screen removal, then runs ordered typecalc2.
for _,r in ipairs({{89,147,100,3},{222,126,1,4}}) do
  blocked("hit-all landed no tail "..r[1],record(r[2],r[3],4),{id=r[1]},r[4])
  for _,mode in ipairs({"protect","random","semi"}) do
    local opts={id=r[1],types={10,10},protect=mode=="protect",
      semi=mode=="semi" and "air" or nil,values={99,99}}
    local draws=(r[1]==222 and 1 or 0)+(mode=="random" and 1 or 0)
    blocked("super hit-all "..r[1]..mode,record(r[2],r[3],4,1),opts,draws)
    -- Retain actual immunity independently of absent effectiveness bits;
    -- the source WG reason still wins over DOESNT_AFFECT.
    opts.types={2,2}
    blocked("immune hit-all "..r[1]..mode,record(r[2],r[3],4,1),opts,draws)
  end
end
-- Distinct scan controls with identical super Ground/Fire input:
-- ordinary random-miss OR flags keep the plain miss; ordered typecalc2
-- keeps Protect; only hit-all's pre-MISSED normal typecalc suppresses super.
blocked("super ordinary random scan",record(0,100,4,1),{types={10,10},values={99}},1,"miss")
blocked("super ordered scan protect",record(117,30,4),{types={10,10},protect=true},0,"protected")
-- Actual Brick Break static record: id280/effect186/power75/Fighting.
-- Chart order: Dark20 is before the Foresight marker and Ghost0. With
-- screens, clearing prior bits then ordered OR yields immunity/no WG;
-- without screens, first normal WG-MISSED remains. Source total4 draws.
for _,side in ipairs({"player","foe"}) do
  for _,screen in ipairs({"none","reflect","lightScreen","both"}) do
    for _,types in ipairs({{7,17},{17,7}}) do
      local e,a,d=battle(record(186,75,1),{id=280,side=side,types=types})
      local target=side=="player" and "foe" or "player"
      local status=e.sideStatus[target]
      if screen=="reflect" or screen=="both" then status.reflect=true;status.reflectTimer=3 end
      if screen=="lightScreen" or screen=="both" then status.lightScreen=true;status.lightScreenTimer=2 end
      local ev=resolve(e,side)
      check("Brick Break reason "..side..screen..types[1],result(ev)==(screen=="none" and "wonderGuard" or "noEffect"),result(ev))
      check("Brick Break HP/PP "..side..screen..types[1],d.hp==400 and a.moves[1].pp==19 and not find(ev,"damage"))
      check("Brick Break RNG "..side..screen..types[1],e.rng.draws==4,e.rng.draws)
      check("Brick Break removed screens "..side..screen..types[1],not status.reflect and not status.lightScreen and status.reflectTimer==0 and status.lightScreenTimer==0 and (find(ev,"wallShattered")~=nil)==(screen~="none"))
    end
  end
  -- Ghost mono has no super row before zero: after cleanup the second
  -- scan DOES reassert WG, distinct from Ghost/Dark. Neutral also reasserts.
  for _,types in ipairs({{7,7},{11,11}}) do
    local e,a,d=battle(record(186,75,1),{id=280,side=side,types=types})
    local status=e.sideStatus[side=="player" and "foe" or "player"]
    status.reflect=true;status.reflectTimer=3
    local ev=resolve(e,side)
    check("Brick Break ordered reassert "..side..types[1],result(ev)=="wonderGuard" and d.hp==400 and e.rng.draws==4 and not status.reflect and status.reflectTimer==0)
  end
  -- Source-super Fighting/Normal never has an initial WG block; preserve
  -- native unblocked generic3-draw gap while removing the screen.
  local e,a,d=battle(record(186,75,1),{id=280,side=side,types={0,0}})
  local status=e.sideStatus[side=="player" and "foe" or "player"]
  status.reflect=true;status.reflectTimer=3
  local ev=resolve(e,side)
  check("Brick Break unblocked control "..side,find(ev,"damage") and not find(ev,"wonderGuard") and d.hp<400 and e.rng.draws==3 and not status.reflect)
end
print(passed.." passed, "..failed.." failed")
if failed>0 then os.exit(1) end
