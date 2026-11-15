-- Executes production main.lua fragments: completed-step dispatch, fixed
-- ticks through love.update/InputState, the C0 presenter task, dialogue
-- image selection, forced movement, map teardown and the replay case.
-- Fixtures contain synthetic bytes and service stubs only; no ROM, no LÖVE
-- process and no helper-only returned action.
package.path=package.path..";./?.lua"
love={}
local App=require("main")
local P=require("src.core.PlayerMovement")
local Input=require("src.core.InputState")
local Flow=require("src.core.NewGameFlow")
local Codec=require("src.core.SaveFileCodec")
local F=assert(loadfile("tests/phase5_viridian_roadblock_test.lua"))("fixtures")
local file=assert(io.open("main.lua","rb"));local source=file:read("*a");file:close()
local passed,failed=0,0
local function check(name,ok) if ok then passed=passed+1 else failed=failed+1;print("FAIL: "..name) end end
local function noop() end
local LEAK=Input.DPAD_RIGHT+Input.START_BUTTON+Input.SELECT_BUTTON+Input.A_BUTTON+Input.B_BUTTON

-- Plain-text mutation of one installed production fragment.
local function replaceOnce(old,new)
  return function(text)
    local a,b=text:find(old,1,true);assert(a,"mutation anchor missing: "..old)
    assert(not text:find(old,b+1,true),"mutation anchor repeated: "..old)
    return text:sub(1,a-1)..new..text:sub(b+1)
  end
end
local function install(env,first,last,name,transform)
  local a=assert(source:find(first,1,true),first);local b=assert(source:find(last,a+#first,true),last)
  local text=source:sub(a,b-1)
  if transform then text=transform(text) end
  local chunk=assert(loadstring(text.."\nreturn "..name,"@main.lua:"..name));setfenv(chunk,env)
  local value=chunk();if not name:find(".",1,true) then env[name]=value end;return value
end
local SECTIONS={
  {"elevation","-- Transient player elevation input","-- Keep the field camera","world.readPlayerElevationHeight"},
  {"c0","-- Viridian City C0 roadblock (src/core","-- Deterministic guarded C0 witness","world.viridianRoadblockTask"},
  {"replay","-- Deterministic guarded C0 witness","local function playerMovementTask(","world.runViridianRoadblockReplay"},
  {"playerTask","local function playerMovementTask(","-- Ticks a pending TrainerApproach","playerMovementTask"},
  {"npcTask","local function npcMovementTask(","local function dialogueTask(","npcMovementTask"},
  {"loadMap","function loadMap(data, addrs, mapId, dbg)","-- Real warp transition","loadMap"},
  {"sync","syncSessionLocation = function","-- The real naming screen seeds","syncSessionLocation"},
  {"images","local function ensureDialogueImagesCurrent(","local FLAME_TILE_WIDTH","ensureDialogueImagesCurrent"},
  {"update","function love.update(dt)","local function drawNewGameFlow(","love.update"},
  {"keypressed","function love.keypressed(key)","-- Keep the live LÖVE entrypoint unchanged","love.keypressed"},
}
local function harness(mutations)
  mutations=mutations or {}
  local blocks={};for i=0,1023 do blocks[i]={elevation=3,collision=0} end
  local session=App.GameSession.fromNewGame({playerGender=0,playerName=Flow.encodeName("RED"),rivalName=Flow.encodeName("GREEN")})
  session:setVar(0x4051,0);session:setLocation(769,22,12,"north")
  local counts={trainer=0,early=0,connection=0,warp=0,wild=0,npc=0,interaction=0,menu=0,collision=0,ledge=0,sync=0}
  local env=setmetatable({world={},newGame={session=session,active=false},PlayerMovement=P,InputState=Input,
    NewGameFlow=Flow,SaveFileCodec=Codec,
    inputState=Input.new(),scheduler=require("src.core.TaskScheduler").new(),
    FIXED_TICK=1/60,tickAccumulator=0,walkActive=true,walkMapId=769,
    walkMapWidth=32,walkMapHeight=32,walkMapBlockData=blocks,romData=F.bytes(),romAddrs={gMapGroups=0},
    love={keyboard={isDown=function() return false end},event={}},
    addLine=noop,counts=counts,GameSession=App.GameSession,printed={},
    DIALOGUE_CONTENT_TILES_W=26,DIALOGUE_CONTENT_TILES_H=4,
    fontData="synthetic",fontAddrs={},fontPalette={[1]={r=255,g=255,b=255}},
    TextWindow={decodeFrameTiles=noop,decodePalette=noop,compositeFrame=function() return {} end},
    buildImage=function() return {setFilter=noop} end,
    MapHeader={resolve=function() return {mapScriptsPtr=0x08000010,mapLayoutPtr=1,eventsPtr=1,connectionsPtr=0} end},
    MapLayout={resolve=function() return {width=32,height=32,mapPtr=1,primaryTilesetPtr=1,secondaryTilesetPtr=2,borderPtr=1,borderWidth=1,borderHeight=1} end},
    MapBlockData={resolve=function() return blocks end},
    MapEvents={resolve=function() return {warps={},coordEvents=F.context().events} end},
    Tileset={resolve=function() return {metatileAttributesPtr=1} end},
    MapBorder={resolve=function() return {} end},
    MapCompositor={loadTilesetData=function() return {tiles={}} end,compositeWithBorder=function() return {width=512,height=512} end},
    loadMapObjectEvents=function() end,
  },{__index=_G})
  env.print=function(line) env.printed[#env.printed+1]=line end
  env.love.event.quit=function(code) env.quitCode=code or 0 end
  env.TextRenderer={renderTokens=function(_,_,tokens) env.rendered=tokens;return {} end}
  for _,pair in ipairs({{"tryEarlyStoryTriggerAt","early"},{"tryWarpAt","warp"},{"rollWildEncounterAt","wild"},
    {"tryStartInteraction","interaction"}}) do
    env[pair[1]]=function() counts[pair[2]]=counts[pair[2]]+1;return false end
  end
  env.getLedgeJumpDirection=function() counts.ledge=counts.ledge+1;return env.ledgeDirection end
  env.world.isPlayerWalkTileBlocked=function() counts.collision=counts.collision+1;return env.blocked or false end
  env.world.tryTrainerSightlineAt=function() counts.trainer=counts.trainer+1;return env.trainerWins or false end
  env.world.tryConnectionAt=function() counts.connection=counts.connection+1;return false end
  env.world.openStartMenu=function() counts.menu=counts.menu+1 end
  env.world.clearViews=function() env.walkActive=false;env.newGame.active=false end
  env.world.npcs={{tick=function() counts.npc=counts.npc+1 end}}
  for _,s in ipairs(SECTIONS) do install(env,s[2],s[3],s[4],mutations[s[1]]) end
  local sync=env.syncSessionLocation
  env.syncSessionLocation=function() counts.sync=counts.sync+1;sync() end
  env.world.roadblockMapScriptsPtr=0x08000010
  env.world.coordEvents=F.context().events
  env.playerMovement=P.new(22,12,P.UP)
  env.playerMovement:bindElevationSource(env.world.readPlayerElevationHeight,env.world.readPlayerElevationGeneration)
  env.scheduler:createTask(env.playerMovementTask,0)
  env.scheduler:createTask(env.npcMovementTask,0)
  return env
end
local function tick(e,mask,n)
  e.world.replayInputMask=mask or 0
  for _=1,n or 1 do e.love.update(1/60) end
end
local function enter(e)
  tick(e,Input.DPAD_UP);tick(e,0,16)
  return e.world.viridianRoadblock
end
-- Bounded: returns false instead of erroring so mutants keep running.
local function untilState(e,state,mask,maxStep)
  for _=1,2000 do
    local r=e.world.viridianRoadblock
    if not r then return false end
    if r.state==state then return true end
    local printer,index=r.printer,r.printer and r.printer.tokenIndex
    tick(e,mask or 0)
    if maxStep and r.printer and r.printer==printer and r.printer.tokenIndex>index+1 then maxStep.revealAll=true end
  end
  return false
end
local function finishText(e)
  untilState(e,"WAIT_PAGE",Input.B_BUTTON);tick(e,0);tick(e,Input.B_BUTTON)
  untilState(e,"WAIT_FINAL",Input.B_BUTTON);tick(e,0);tick(e,Input.A_BUTTON)
end

-- One full production pass. Every named result must be true for production;
-- mutation witnesses below require the named invariant to fail.
local function scenario(e)
  local res,c,p={},e.counts,e.playerMovement
  local before=Codec.encode(e.newGame.session.state)
  tick(e,Input.DPAD_UP);tick(e,0,15)
  res.no_premature=not e.world.viridianRoadblock and p.moving
  tick(e,0);local r=e.world.viridianRoadblock
  res.selected_e3=r~=nil and r.state=="PRINT_PAGE1" and p:getEffectiveElevation()==3
  if not r then return res end
  res.trainer_first_once=c.trainer==1 and c.early==0 and c.wild==0 and c.warp==0 and c.connection==0
  e.ensureDialogueImagesCurrent();res.blue_renderer=e.rendered~=nil and e.rendered[1].fg==8
  local npc=c.npc
  for _=1,3 do tick(e,Input.START_BUTTON+Input.SELECT_BUTTON+Input.DPAD_RIGHT);tick(e,0) end
  e.love.keypressed("v");e.love.keypressed("k")
  res.print_lock=c.npc==npc and c.interaction==0 and c.menu==0 and not p.moving and r.page==1
  local step={}
  tick(e,Input.A_BUTTON);res.activation_no_glyph=r.accelerated and r.remaining==0
  res.page1_complete=untilState(e,"WAIT_PAGE",Input.A_BUTTON,step)
  tick(e,Input.A_BUTTON);res.held_no_page_clear=r.state=="WAIT_PAGE" and r.page==1
  local oldPrinter=r.printer
  tick(e,0);tick(e,Input.B_BUTTON)
  res.new_b_page_clear=r.page==2 and r.printer~=nil and r.printer~=oldPrinter and r.printer.tokenIndex==0 and r.accelerated
  e.ensureDialogueImagesCurrent()
  res.page_cache_reset=not e.world.dialogueTextImage and e.world.dialogueBuiltPrinter==r.printer
  res.page2_complete=untilState(e,"WAIT_FINAL",Input.B_BUTTON,step)
  res.no_reveal_all=not step.revealAll
  tick(e,Input.B_BUTTON);res.held_no_final=r.state=="WAIT_FINAL"
  tick(e,0);tick(e,Input.A_BUTTON)
  res.final_ack_keeps_frame=r.state=="CLOSE_PENDING" and r.acknowledgedBy=="A" and r.printer~=nil and not p.moving
  tick(e,Input.DPAD_RIGHT+Input.START_BUTTON)
  res.close_before_move=r.state=="WALK_DOWN" and not r.printer and not e.world.dialogueTextImage and not p.moving
  -- Ordinary admission would refuse and the ledge would hop two tiles.
  local collision,ledge=c.collision,c.ledge
  e.blocked=true;e.ledgeDirection=P.DOWN
  tick(e,Input.DPAD_RIGHT+Input.START_BUTTON)
  e.blocked=false;e.ledgeDirection=nil
  res.no_collision_ledge=c.collision==collision and c.ledge==ledge
  res.forced_start=r.state=="WAIT_MOVEMENT_END" and p.destTileX==22 and p.destTileY==12
    and p.facingDirection==P.DOWN and p:pixelY()==11*16
  local sync,pixels=c.sync,true
  for i=1,16 do
    -- Alternating masks make every button/direction a NEW press while owned.
    tick(e,i%2==1 and LEAK or 0)
    pixels=pixels and p:pixelX()==22*16 and p:pixelY()==11*16+i and p.moving==(i<16)
      and c.npc==npc and c.menu==0 and c.interaction==0
  end
  res.sixteen_pixels_locked=pixels
  res.wait_before_release=e.world.viridianRoadblock==r and r.state=="RELEASE_PENDING"
    and c.sync==sync+1 and p:getEffectiveElevation()==nil
  tick(e,Input.DPAD_RIGHT+Input.START_BUTTON+Input.A_BUTTON)
  res.release_barrier=not e.world.viridianRoadblock and not p.moving and p.tileX==22 and p.tileY==12
    and c.npc==npc and c.menu==0 and c.interaction==0
  res.no_nested_dispatch=c.trainer==1 and c.early==0 and c.connection==0 and c.warp==0 and c.wild==0
  local expected=App.GameSession.fromSavedState(assert(Codec.decode(before)))
  expected:setLocation(769,22,12,"south")
  res.location_facing_only=Codec.encode(expected.state)==Codec.encode(e.newGame.session.state)
  tick(e,Input.DPAD_RIGHT)
  res.resume_next_tick=p.moving and p.destTileX==23 and c.npc==npc+1
  return res
end

do
  local res=scenario(harness())
  local names={"no_premature","selected_e3","trainer_first_once","blue_renderer","print_lock",
    "activation_no_glyph","page1_complete","held_no_page_clear","new_b_page_clear","page_cache_reset",
    "page2_complete","no_reveal_all","held_no_final","final_ack_keeps_frame","close_before_move",
    "no_collision_ledge","forced_start","sixteen_pixels_locked","wait_before_release","release_barrier",
    "no_nested_dispatch","location_facing_only","resume_next_tick"}
  for _,name in ipairs(names) do check("production "..name,res[name]==true) end
end

-- Production wrong map/scene/E and malformed selected context, not a returned helper.
for _,case in ipairs({{"scene",1,"fallthrough"},{"map",768,"fallthrough"},{"e",4,"fallthrough"},
  {"e",0,"fallthrough"},{"e",false,"REFUSED"},{"scene",false,"REFUSED"},{"owner",true,"REFUSED"},
  {"table",false,"REFUSED"},{"script",false,"REFUSED"},{"speed",3,"REFUSED"},{"event",false,"REFUSED"}}) do
  local e=harness()
  if case[1]=="scene" then e.newGame.session.state.saveBlock1.vars[82]=case[2]
  elseif case[1]=="map" then e.walkMapId=case[2]
  elseif case[1]=="e" then
    for _,b in pairs(e.walkMapBlockData) do b.elevation=case[2] end
    if case[2]==0 then e.playerMovement:bootstrapElevation() end
  elseif case[1]=="owner" then e.world.startMenuActive=true
  elseif case[1]=="table" then e.world.roadblockMapScriptsPtr=0
  elseif case[1]=="script" then e.romData=F.bytes({[64]=0})
  elseif case[1]=="speed" then e.newGame.session.state.saveBlock2.options.textSpeed=case[2]
  elseif case[1]=="event" then e.world.coordEvents[0].trigger=0x4052 end
  local saved=Codec.encode(e.newGame.session.state)
  local r=enter(e)
  local label=case[1].."="..tostring(case[2])
  if case[3]=="fallthrough" then
    check("production legacy "..label,not r and e.counts.early==1 and e.counts.trainer==1 and e.counts.wild==1)
  else
    check("production refusal "..label,r and r.state=="REFUSED" and r.printer==nil
      and e.counts.wild==0 and e.counts.early==0 and e.counts.warp==0)
    tick(e,Input.DPAD_DOWN+Input.START_BUTTON+Input.A_BUTTON);tick(e,0);tick(e,Input.DPAD_DOWN+Input.START_BUTTON+Input.A_BUTTON,18)
    check("refusal suppresses input "..label,not e.playerMovement.moving and e.counts.menu==0 and e.counts.interaction==0)
    e.world.startMenuActive=nil
    local state=e.newGame.session.state
    local expected=App.GameSession.fromSavedState(assert(Codec.decode(saved)))
    expected:setLocation(769,22,11,"north")
    check("refusal writes no scene/reward "..label,Codec.encode(expected.state)==Codec.encode(state))
    e.loadMap(e.romData,e.romAddrs,769,noop)
    check("same-ID reload recovers refusal "..label,not e.world.viridianRoadblock and e.playerMovement:getEffectiveElevation()==nil)
  end
end
for _,elevation in ipairs({0,4}) do
  local e=harness();e.world.coordEvents[0].elevation=0
  for _,b in pairs(e.walkMapBlockData) do b.elevation=elevation end
  if elevation==0 then e.playerMovement:bootstrapElevation() end
  local r=enter(e)
  check("production known wildcard "..elevation,r~=nil and r.state=="PRINT_PAGE1" and e.counts.wild==0)
end
do
  local e=harness();e.trainerWins=true;local r=enter(e)
  check("trainer wins once before C0",not r and e.counts.trainer==1 and e.counts.wild==0 and e.counts.early==0)
end
for _,kind in ipairs({"generation","position","owner","player","reload","destination"}) do
  local e=harness();enter(e);finishText(e)
  local old=e.playerMovement
  if kind=="destination" then e.walkMapBlockData[12*32+22]=nil;tick(e,0,2)
  else
    tick(e,0,3)
    if kind=="generation" then e.world.playerElevationGeneration=e.world.playerElevationGeneration+1
    elseif kind=="position" then e.playerMovement.tileX=21
    elseif kind=="owner" then e.world.dialogue={isActive=function() return true end}
    elseif kind=="player" then e.playerMovement=P.new(22,11,P.DOWN)
    else e.loadMap(e.romData,e.romAddrs,769,noop) end
    tick(e,0)
  end
  local r=e.world.viridianRoadblock
  check("teardown/stale "..kind,kind=="reload" and not r or r and r.state=="REFUSED")
  check("stale motion cancelled "..kind,not old.moving and old.tileY==11 or kind=="player")
  check("stale E invalid "..kind,old:getEffectiveElevation()==nil)
  if kind=="owner" then check("never releases other owner",e.world.dialogue:isActive()) end
end
do
  local e=harness();enter(e);finishText(e);tick(e,0,20)
  check("release completes",not e.world.viridianRoadblock and e.playerMovement.tileY==12)
  check("ordinary re-entry retriggers",enter(e)~=nil and e.counts.trainer==2 and e.newGame.session:getVar(0x4051)==0)
end

-- The guarded replay case itself, run against synthetic production paths.
do
  local e=harness();e.world.runViridianRoadblockReplay()
  local line=e.printed[#e.printed] or ""
  check("replay case passes synthetic witness",line:find("RUNTIME_REPLAY viridian_roadblock PASS",1,true)==1 and e.quitCode==0)
  check("replay restores dispatch owners",e.world.replayInputMask==nil and e.world.tryConnectionAt~=nil)
end

-- Negative mutation witnesses: each executes production fragments with one
-- defect; the same production assertion must detect it.
local BARRIER=replaceOnce("if not world.roadblockTickOwned and not (world.viridianRoadblock and world.viridianRoadblock:isActive()) then",
  "if not (world.viridianRoadblock and world.viridianRoadblock:isActive()) then")
do
  local res=scenario(harness({update=BARRIER}))
  check("mutation witness: omitted release barrier leaks",res.release_barrier==false and res.sixteen_pixels_locked==true)
  local e=harness({update=BARRIER});e.world.runViridianRoadblockReplay()
  local line=e.printed[#e.printed] or ""
  check("mutation witness: replay detects release leak",line:find("FAIL",1,true)~=nil
    and line:find("pass1_release_barrier",1,true)~=nil and e.quitCode==1)
end
do
  local res=scenario(harness({c0=replaceOnce("local ok, reason = p:startScriptedDown(function(x,y)",
    'p:tryMove(PlayerMovement.DOWN, world.isPlayerWalkTileBlocked, getLedgeJumpDirection, "script")\n'
    ..'    local ok, reason = p.moving, "blocked"\n    local _ = (function(x,y)')}))
  check("mutation witness: ordinary collision/ledge admission detected",res.no_collision_ledge==false)
end
do
  local res=scenario(harness({c0=replaceOnce("      syncSessionLocation()\n      r.forced, r.state = false, \"RELEASE_PENDING\"",
    "      syncSessionLocation()\n      if not tryEarlyStoryTriggerAt(p.tileX, p.tileY) and not world.tryConnectionAt(p.tileX, p.tileY)\n"
    .."          and not tryWarpAt(p.tileX, p.tileY) and not world.tryTrainerSightlineAt(p.tileX, p.tileY) then\n"
    .."        rollWildEncounterAt(p.tileX, p.tileY)\n      end\n      r.forced, r.state = false, \"RELEASE_PENDING\"")}))
  check("mutation witness: nested completed-step dispatch detected",res.no_nested_dispatch==false)
end
do
  local res=scenario(harness({playerTask=replaceOnce(
    "if world.roadblockTickOwned or (world.viridianRoadblock and world.viridianRoadblock:isActive()) then return end","")}))
  check("mutation witness: ordinary tick during forced motion detected",res.sixteen_pixels_locked==false)
end
print(("phase5_viridian_roadblock_integration_test: %d passed, %d failed"):format(passed,failed))
os.exit(failed==0 and 0 or 1)
