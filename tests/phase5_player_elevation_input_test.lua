-- Production function/closure execution with synthetic decoded map services.
-- No ROM/LÖVE or new main export. Source oracle: accepted c75f352 spawn/begin/
-- finish lifecycle; in particular 15->4 retains begin, changes BEFORE dispatch.
package.path = package.path .. ";./?.lua"
love = {}
local App = require("main")
local P = require("src.core.PlayerMovement")
local Input = require("src.core.InputState")
local Flow = require("src.core.NewGameFlow")
local Codec = require("src.core.SaveFileCodec")
local passed, failed = 0, 0
local function check(name, ok)
  if ok then passed = passed+1 else failed = failed+1; print("FAIL: " .. name) end
end
local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}; for k,v in pairs(value) do result[k] = copy(v) end
  return result
end
local file = assert(io.open("main.lua", "rb"))
local source = file:read("*a"); file:close()
local function fragment(first, last)
  local a = assert(source:find(first, 1, true), first)
  local b = assert(source:find(last, a+#first, true), last)
  return source:sub(a, b-1)
end
local function install(env, first, last, name)
  local chunk = assert(loadstring(fragment(first, last) .. "\nreturn " .. name, "@main.lua:" .. name))
  setfenv(chunk, env)
  local value = chunk()
  if not name:find(".", 1, true) then env[name] = value end
  return value
end
local function noop() end
local function harness()
  local blocks = {}; for i=0,255 do blocks[i] = {elevation=3, collision=0} end
  local env = setmetatable({
    world={}, newGame={active=false}, PlayerMovement=P, InputState=Input,
    inputState=Input.new(), scheduler=require("src.core.TaskScheduler").new(),
    FIXED_TICK=1/60, tickAccumulator=0, walkActive=true,
    fixtureBlocks=blocks, fixtureEvents={warps={}, coordEvents={}},
    romData="", romAddrs={gMapGroups=0}, walkMapId=769,
    walkMapBlockData=blocks, walkMapWidth=16, walkMapHeight=16,
    addLine=noop, npcMovementTask=noop, dialogueTask=noop,
    GameSession=App.GameSession, Rng=require("src.core.Rng"),
    NewGameDefaults=require("src.core.NewGameDefaults"),
    Battle={EarlyStory=require("src.core.EarlyStory")},
    SaveFileCodec=Codec, SAVE_FILENAME="synthetic-unused",
    love={keyboard={isDown=function() return false end}, filesystem={}},
    findFirstWalkableTile=function() return 0,0 end,
    getLedgeJumpDirection=function() return nil end,
    rollWildEncounterAt=noop, tryStartInteraction=noop,
    MapHeader={resolve=function() return {mapLayoutPtr=1,eventsPtr=1,connectionsPtr=0,regionMapSectionId=1} end},
    MapLayout={resolve=function() return {width=16,height=16,mapPtr=1,primaryTilesetPtr=1,
      secondaryTilesetPtr=2,borderPtr=1,borderWidth=1,borderHeight=1} end},
    Tileset={resolve=function() return {metatileAttributesPtr=1} end},
    MapBorder={resolve=function() return {} end},
    MapCompositor={loadTilesetData=function() return {tiles={}} end,
      compositeWithBorder=function() return {width=256,height=256} end},
    buildImage=function() return {setFilter=noop} end,
  }, {__index=_G})
  env.MapBlockData={resolve=function() return env.fixtureBlocks end}
  env.MapEvents={resolve=function() return env.fixtureEvents end}
  env.loadMapObjectEvents=function(_, events) env.world.coordEvents=events.coordEvents end
  env.world.isPlayerWalkTileBlocked=function() return false end
  env.world.connectionForEdge=function() return env.connection end
  env.world.tryTrainerSightlineAt=function() return false end
  env.world.tryViridianMartParcelPresentationAtDestination=noop
  env.world.createViridianParcelStory=noop
  env.world.clearViews=noop
  env.world.startRivalBattle=function() return false end
  env.world.oakParcelDexPresentationTask=noop
  env.world.trainerApproachTask=noop
  env.world.handleMartParcelPresentationCommand=noop
  install(env, "-- Transient player elevation input", "-- Keep the field camera", "world.readPlayerElevationHeight")
  install(env, "local function playerMovementTask(", "-- Ticks a pending TrainerApproach", "playerMovementTask")
  install(env, "world.martParcelPresentationTask = function", "-- Task-bounded command bridge for ReceiveDexScene", "world.martParcelPresentationTask")
  install(env, "local function loadWalkAssets(", "-- The full real Oak intro scene", "loadWalkAssets")
  install(env, "function loadMap(data, addrs, mapId, dbg)", "-- Real warp transition", "loadMap")
  install(env, "function tryWarpAt(x, y)", "-- Real edge-of-map connection", "tryWarpAt")
  install(env, "world.tryConnectionAt = function", "-- Persists only the field location", "world.tryConnectionAt")
  install(env, "syncSessionLocation = function", "-- The real naming screen seeds", "syncSessionLocation")
  install(env, "bootstrapFreshSession = function", "-- Real save-file name", "bootstrapFreshSession")
  install(env, "function loadGameFile()", "tryEarlyStoryTriggerAt = function", "loadGameFile")
  install(env, "tryEarlyStoryTriggerAt = function", "acceptStarterChoice = function", "tryEarlyStoryTriggerAt")
  install(env, "world.finishTrainerBattle = function", "function love.update(dt)", "world.finishTrainerBattle")
  install(env, "function love.update(dt)", "local function drawNewGameFlow(", "love.update")
  env.loadWalkAssets(noop) -- actual constructor, binding, scheduler ownership
  env.newGame.flow={isComplete=function() return true end, result=function()
    return {playerGender=Flow.MALE, playerName=Flow.encodeName("RED"), rivalName=Flow.encodeName("GREEN")}
  end}
  return env
end
local function fresh(env)
  env.bootstrapFreshSession()
  check("actual bootstrap owns final tile before spawn", env.playerMovement.tileX==6
    and env.playerMovement.tileY==6 and env.playerMovement.currentElevation==0
    and env.playerMovement:getEffectiveElevation()==0 and env.playerMovement.elevationSpawnPending
    and env.playerMovement.elevationProvenance=="fresh_avatar")
end
local function tick(env, mask, count)
  env.world.replayInputMask = mask or 0
  for _=1,count or 1 do env.love.update(1/60) end
end
do
  local env = harness()
  check("actual debug construction stays unknown", env.playerMovement:getEffectiveElevation()==nil)
  fresh(env)
  local savedBefore = copy(env.newGame.session.state)
  env.fixtureBlocks[6*16+7].elevation=15
  env.fixtureBlocks[6*16+8].elevation=4
  local observations={}
  env.newGame.story.onStep=function(_, map, x, y, events)
    observations[#observations+1]={x=x,y=y,e=env.playerMovement:getEffectiveElevation(),
      c=env.playerMovement.currentElevation, moving=env.playerMovement.moving}
    check("dispatch API still exactly existing map/events", map==env.walkMapId and events==env.world.coordEvents)
    return nil
  end
  tick(env, Input.DPAD_RIGHT) -- scheduler spawn, then actual normal input
  check("normal input begins without changing public tile", env.playerMovement.moving
    and env.playerMovement.tileX==6 and env.playerMovement:getEffectiveElevation()==3)
  tick(env, 0, 15)
  check("no dispatch before frame16", #observations==0 and env.playerMovement:pixelX()==6*16+15)
  tick(env, 0)
  check("actual first completion reads retained E on15", #observations==1
    and observations[1].x==7 and observations[1].e==3 and not observations[1].moving)
  tick(env, Input.DPAD_RIGHT); tick(env, 0)
  check("later origin15 begin retains3", env.playerMovement:getEffectiveElevation()==3)
  tick(env, 0, 15)
  check("PRODUCTION finish sampling precedes dispatch", #observations==2
    and observations[2].x==8 and observations[2].e==4 and observations[2].c==4)
  local expected = App.GameSession.fromSavedState(savedBefore)
  expected:setLocation(env.walkMapId, 8, 6, "east")
  check("only existing location persistence changes serialized state",
    Codec.encode(expected.state)==Codec.encode(env.newGame.session.state))
end

-- Production standing/blocked spawn, decoded missing samples, generation and
-- stale coordinate backstops. These run actual input and scheduler closures.
for _, blocked in ipairs({false,true}) do
  local env=harness(); fresh(env)
  env.world.isPlayerWalkTileBlocked=function() return blocked end
  tick(env, blocked and Input.DPAD_RIGHT or 0)
  check("production pending spawn while standing/blocked", env.playerMovement:getEffectiveElevation()==3
    and not env.playerMovement.moving)
end
do
  local env=harness(); fresh(env)
  env.fixtureBlocks[6*16+6]=nil
  tick(env,0)
  check("production missing block never defaults height", env.playerMovement:getEffectiveElevation()==nil)
  check("production reader rejects off-map coords", env.world.readPlayerElevationHeight(-1,6)==nil
    and env.world.readPlayerElevationHeight(16,6)==nil and env.world.readPlayerElevationHeight(0.5,6)==nil)
  env.fixtureBlocks[6*16+6]="malformed"
  env.playerMovement:bootstrapElevation(); tick(env,0)
  check("malformed decoded block is fail-closed without throwing", env.playerMovement:getEffectiveElevation()==nil)
end
for _, direction in ipairs({Input.DPAD_RIGHT,Input.DPAD_LEFT,Input.DPAD_UP,Input.DPAD_DOWN}) do
  local env=harness(); fresh(env)
  env.playerMovement:invalidateElevation("unqualified_history")
  tick(env,direction); tick(env,0,15)
  check("each real direction keeps history unknown before finish "..direction, env.playerMovement:getEffectiveElevation()==nil)
  tick(env,0)
  check("each real direction declares normal provenance "..direction, env.playerMovement:getEffectiveElevation()==3
    and env.playerMovement.elevationProvenance=="normal_finish")
end
do
  local env=harness(); fresh(env); tick(env,Input.DPAD_RIGHT); tick(env,0)
  env.world.playerElevationGeneration=env.world.playerElevationGeneration+1
  tick(env,0,15)
  check("production changed generation cancels old finish", env.playerMovement:getEffectiveElevation()==nil)
  tick(env,Input.DPAD_RIGHT); tick(env,0,16)
  check("production next qualified normal finish converges", env.playerMovement:getEffectiveElevation()==3)
  env.playerMovement.tileY=7
  tick(env,0)
  check("production direct coordinate mismatch invalidates", env.playerMovement:getEffectiveElevation()==nil)
end

-- Run the real map loader; the header stub observes invalidation BEFORE data
-- replacement. Reloading the same ID must not preserve stale valid E.
do
  local env=harness(); fresh(env); tick(env,0)
  local header=env.MapHeader.resolve
  env.MapHeader.resolve=function(...)
    check("PRODUCTION map load invalidates before decode", env.playerMovement:getEffectiveElevation()==nil)
    return header(...)
  end
  local gen=env.world.playerElevationGeneration
  env.loadMap("",env.romAddrs,env.walkMapId,noop)
  check("same-map reload advances generation", env.world.playerElevationGeneration==gen+1)
end
-- Isolate each caller's explicit invalidation from common loadMap's own one:
-- a same-position relocation must not rely on coordinate mismatch as a crutch.
for _, owner in ipairs({"warp","connection","save","oakEscort","stayForStarter","rivalBattle"}) do
  local env=harness(); fresh(env); tick(env,0)
  tick(env,Input.DPAD_RIGHT); tick(env,0)
  check("relocation begins with pending normal work "..owner, env.playerMovement.elevationStep~=nil)
  local x,y=env.playerMovement.tileX,env.playerMovement.tileY
  local saved=Codec.encode(env.newGame.session.state)
  env.loadMap=noop
  if owner=="warp" then
    env.walkMapWarps={[0]={x=x,y=y,warpId=0,mapGroup=3,mapNum=1}}
    env.tryWarpAt(x,y)
  elseif owner=="connection" then
    -- North entry destination y=height-1; arrange unchanged coordinates.
    env.walkMapHeight=y+1
    env.connection={direction=require("import.MapConnections").CONNECTION_NORTH,offset=0,mapGroup=3,mapNum=1}
    env.world.tryConnectionAt(x,y)
  elseif owner=="save" then
    env.love.filesystem.getInfo=function() return {} end
    env.love.filesystem.read=function() return saved end
    env.loadGameFile()
  else
    env.newGame.story.onStep=function() return {kind=owner,mapId=env.walkMapId,x=x,y=y} end
    env.tryEarlyStoryTriggerAt(x,y)
  end
  check("PRODUCTION same-position "..owner.." invalidates", env.playerMovement.tileX==x
    and env.playerMovement.tileY==y and env.playerMovement:getEffectiveElevation()==nil)
  check("placement cancels pending work "..owner, env.playerMovement.elevationStep==nil
    and not env.playerMovement.elevationSpawnPending)
end

-- Both production whiteout owners, with unrelated settlement services stubbed.
for _, trainer in ipairs({false,true}) do
  local env=harness(); fresh(env); tick(env,0)
  local x,y=env.playerMovement.tileX,env.playerMovement.tileY
  env.loadMap=noop
  env.world.battleCatalog={moves={}}
  env.Battle.WhiteoutRules={highestPartyLevel=function() return 1 end,
    countBadges=function() return 0 end, computeMoneyLoss=function() return 0 end,
    respawnLocation=function() return {mapGroup=3,mapNum=1,x=x,y=y} end}
  env.Battle.RivalRewards={healParty=noop}
  local battle={kind=trainer and "trainer" or "wild", trainerName="synthetic",
    controller={engine={outcome="playerLost"},processInput=noop,isComplete=function() return true end}}
  if trainer then env.world.finishTrainerBattle(battle)
  else env.world.battle=battle; tick(env,0) end
  check("same-position whiteout invalidates "..tostring(trainer), env.playerMovement.tileX==x
    and env.playerMovement.tileY==y and env.playerMovement:getEffectiveElevation()==nil)
end

do
  local env=harness(); fresh(env); tick(env,0)
  env.world.martParcelPresentation={isInputLocked=function() return true end,isActive=function() return true end}
  env.world.martParcelMotion={kind="approach_counter",playerSteps=0,clerkTicks=64}
  env.world.martParcelPresentationTask(0)
  for _=1,15 do env.world.martParcelPresentationTask(0) end
  check("actual Mart script movement cannot qualify", env.playerMovement.tileY==5
    and env.playerMovement:getEffectiveElevation()==nil)
  env.world.martParcelPresentation=nil; env.world.martParcelMotion=nil
  env.fixtureBlocks[5*16+7].elevation=0
  tick(env,Input.DPAD_RIGHT); tick(env,0,16)
  check("production finish0 cannot recover script history", env.playerMovement:getEffectiveElevation()==nil)
  env.fixtureBlocks[5*16+8].elevation=15
  tick(env,Input.DPAD_RIGHT); tick(env,0,16)
  check("production finish15 cannot recover script history", env.playerMovement:getEffectiveElevation()==nil)
  tick(env,Input.DPAD_RIGHT); tick(env,0,16)
  check("production ordinary finish3 recovers script history", env.playerMovement:getEffectiveElevation()==3)
end
do
  local env=harness(); fresh(env); tick(env,0)
  env.getLedgeJumpDirection=function() return P.RIGHT end
  tick(env,Input.DPAD_RIGHT); tick(env,0,16)
  check("actual normal input ledge stays unqualified, outcome unchanged", env.playerMovement.tileX==8
    and not env.playerMovement.moving and env.playerMovement:getEffectiveElevation()==nil)
end
do
  local env=harness(); fresh(env); tick(env,Input.DPAD_RIGHT); tick(env,0)
  env.world.martParcelPresentation={isInputLocked=function() return true end,isActive=function() return true end}
  env.world.martParcelMotion={kind="approach_counter",playerSteps=0,clerkTicks=64}
  for _=1,15 do env.world.martParcelPresentationTask(0) end
  check("script direct ticks cannot inherit an in-flight normal step", env.playerMovement.tileX==7
    and env.playerMovement:getEffectiveElevation()==nil)
end
-- Execute the developer command's actual movement/dispatch block, not a
-- rewritten approximation. Its env lookup happens outside this extracted block.
do
  local env=harness(); fresh(env); tick(env,0)
  local a=assert(source:find('playerMovement:tryMove(dir,',1,true))
  local b=assert(source:find('\n      end',a,true))
  local command=assert(loadstring("for _=1,1 do\n" .. source:sub(a,b-1) .. "\nend", "@main.lua:POKEPORT_WALK"))
  env.dir=P.RIGHT; setfenv(command,env); command()
  check("actual developer walking cannot qualify", env.playerMovement.tileX==7
    and env.playerMovement:getEffectiveElevation()==nil)
end

do
  local env=harness(); fresh(env); tick(env,0)
  env.BORDER_MARGIN_METATILES=0; env.WALK_CAMERA_WIDTH=240; env.WALK_CAMERA_HEIGHT=160
  env.world.cameraViewport={follow=function(_,_,x,y) return {x=x,y=y,width=240,height=160} end}
  env.world.currentWalkCamera=function()
    local p=env.playerMovement
    return {x=p:pixelX(),y=p:pixelY(),width=240,height=160},p:pixelX(),p:pixelY(),256,256
  end
  env.world.isPlayerWalkTileBlocked=function() return env.playerMovement.tileX~=6 end
  local exitCode
  env.print=noop -- no real replay was run: synthetic production-owner test only
  env.love.event={quit=function(code) exitCode=code or 0 end}
  install(env,"function world.runPhase2CameraViewportReplay()","-- Real metatile BEHAVIOR", "world.runPhase2CameraViewportReplay")
  env.world.runPhase2CameraViewportReplay()
  check("actual automated camera helper cannot qualify", exitCode==0 and env.playerMovement.tileX==7
    and env.playerMovement:getEffectiveElevation()==nil)
end

print(("phase5_player_elevation_input_test: %d passed, %d failed"):format(passed,failed))
os.exit(failed==0 and 0 or 1)
