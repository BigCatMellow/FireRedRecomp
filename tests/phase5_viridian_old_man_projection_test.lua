-- No ROM/LÖVE needed. Literal expectations are from the accepted c75f3523
-- Viridian local-ID-4 source lock, not calculated by the implementation.
package.path = package.path .. ";./?.lua"
local Projection = require("src.core.ViridianOldManProjection")
local ObjectEventState = require("src.core.ObjectEventState")
local Graphics = require("import.ObjectEventGraphicsInfo")
local Rng = require("src.core.Rng")
local passed, failed = 0, 0
local function check(name, condition)
  if condition then passed = passed + 1
  else failed = failed + 1; print("FAIL: " .. name) end
end
local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = copy(item) end
  return result
end
local function equal(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for key, value in pairs(a) do if not equal(value, b[key]) then return false end end
  for key in pairs(b) do if a[key] == nil then return false end end
  return true
end
local function fixtures()
  return {
    [0] = { localId=9, kind=0, graphicsId=23, x=3, y=4, movementType=8,
      movementRangeX=1, movementRangeY=1, scriptPtr=0, flagId=0 },
    [1] = { localId=4, kind=0, graphicsId=240, x=21, y=6, elevation=3,
      movementType=1, movementRangeX=2, movementRangeY=3, trainerType=0,
      trainerRangeOrBerryTreeId=0, scriptPtr=0x12345678, flagId=0 },
    -- An unrelated dynamic object must not acquire generic VAR support.
    [2] = { localId=7, kind=0, graphicsId=240, x=8, y=9, movementType=8,
      movementRangeX=0, movementRangeY=0, scriptPtr=0, flagId=0 },
    [3] = { localId=8, kind=255, graphicsId=12, x=2, y=3,
      targetLocalId=2, targetMapNum=0, targetMapGroup=3 },
  }
end
local function sessionFor(scene)
  local reads = {}
  local session = {
    getVar = function(_, id)
      reads[#reads + 1] = id
      assert(id == 0x4051, "unexpected scene read")
      return scene
    end,
    setVar = function() error("projection must not write variables") end,
    setFlag = function() error("projection must not write flags") end,
  }
  return session, reads
end

for _, case in ipairs({ {0,34,21,11,8}, {1,32,21,8,1}, {2,32,21,6,1}, {65535,32,21,6,1} }) do
  local scene = case[1]
  local source = fixtures()
  local before = copy(source)
  local session, reads = sessionFor(scene)
  local sessionBefore = copy(session)
  local output, diagnostic = Projection.apply(769, source, session)
  local npc = output[1]
  local label = "scene " .. scene .. ": "
  check(label .. "success has no refusal diagnostic", diagnostic == nil)
  check(label .. "copies list and selected object", output ~= source and npc ~= source[1])
  check(label .. "literal source projection", npc.graphicsId == case[2] and npc.x == case[3]
    and npc.y == case[4] and npc.movementType == case[5])
  check(label .. "reads only scene once", #reads == 1 and reads[1] == 0x4051)
  check(label .. "does not mutate templates or session", equal(source, before) and equal(session, sessionBefore))
  check(label .. "unrelated records keep identity", output[0] == source[0]
    and output[2] == source[2] and output[3] == source[3] and output[4] == nil)
  local expected = copy(source[1])
  expected.graphicsId, expected.x, expected.y, expected.movementType = case[2], case[3], case[4], case[5]
  check(label .. "all other selected fields preserved", equal(npc, expected))
  check(label .. "resolved static graphics accepted", Graphics.resolveGraphicsId(npc.graphicsId) == case[2])
  local live, clones = ObjectEventState.new(output, { rng=Rng.new(1) })
  check(label .. "projection reaches ordinary NPC construction", live[2].localId == 4
    and live[2].graphicsId == case[2] and live[2].x == case[3] and live[2].y == case[4]
    and live[2].movementType == case[5] and live[2].initialX == case[3] and live[2].initialY == case[4])
  check(label .. "other NPC and clone handling unchanged", live[1].graphicsId == 23
    and live[3].graphicsId == 240 and #clones == 1 and clones[1] == source[3])
end

-- Re-entry always derives from untouched decoded input, not the last scene.
do
  local source = fixtures()
  for _, scene in ipairs({0, 1, 2, 0}) do
    local output = Projection.apply(769, source, sessionFor(scene))
    check("re-entry " .. scene .. " uses decoded baseline", output[1].y == ({[0]=11, [1]=8, [2]=6})[scene]
      and source[1].y == 6 and source[1].graphicsId == 240)
  end
  local shifted = fixtures()
  shifted[1].x, shifted[1].y, shifted[1].movementType = 17, 19, 8
  local output = Projection.apply(769, shifted, sessionFor(2))
  check(">=2 retains decoded fields, not stale scene-1 coordinates", output[1].x == 17
    and output[1].y == 19 and output[1].movementType == 8 and output[1].graphicsId == 32)
end

local function refuse(label, mapId, source, session, reason)
  local before = copy(source)
  local output, diagnostic = Projection.apply(mapId, source, session)
  check(label .. ": diagnostic no-op", output == source and diagnostic == reason)
  check(label .. ": unchanged input", equal(source, before))
end
do
  local session, reads = sessionFor(0)
  refuse("wrong map", 768, fixtures(), session, "wrong_map")
  refuse("wrong group", 513, fixtures(), session, "wrong_map")
  check("wrong maps do not read scene", #reads == 0)
  refuse("missing session", 769, fixtures(), nil, "missing_session")
  refuse("missing getter", 769, fixtures(), {}, "missing_session")
  refuse("non-session scalar", 769, fixtures(), false, "missing_session")
  refuse("missing list", 769, nil, session, "invalid_templates")
  refuse("missing object", 769, {}, session, "missing_template")
  local wrongId = fixtures(); wrongId[1].localId = 5
  refuse("wrong local ID with graphics 240", 769, wrongId, session, "missing_template")
  local wrongKind = fixtures(); wrongKind[1].kind = 255
  refuse("clone local ID 4", 769, wrongKind, session, "wrong_template_kind")
  wrongKind[1].kind = nil
  refuse("missing normal-kind discriminator", 769, wrongKind, session, "wrong_template_kind")
  for _, gfx in ipairs({32, 34, 239, 241}) do
    local source = fixtures(); source[1].graphicsId = gfx
    refuse("non-base graphics " .. gfx, 769, source, session, "wrong_base_graphics")
  end
  local ambiguous = fixtures(); ambiguous[2].localId = 4
  refuse("duplicate local ID", 769, ambiguous, session, "ambiguous_local_id")
  check("ineligible objects never read scene", #reads == 0)
  refuse("getter failure", 769, fixtures(), {getVar=function() error("unavailable") end}, "scene_read_failed")
  refuse("missing scene", 769, fixtures(), sessionFor(nil), "invalid_scene")
  for _, scene in ipairs({-1, 0.5, "1", false, {}, math.huge, -math.huge, 0/0}) do
    refuse("invalid scene " .. tostring(scene), 769, fixtures(), sessionFor(scene), "invalid_scene")
  end
  local ok, err = pcall(Graphics.resolveGraphicsId, 240)
  check("generic dynamic 240 remains refused", not ok and tostring(err):find("dynamic", 1, true) ~= nil)
end

-- Execute the actual production loader body with only its external field/ROM
-- services stubbed. No new main export, duplicated integration or ROM needed.
local file = assert(io.open("main.lua", "rb"))
local mainSource = file:read("*a"); file:close()
local first = assert(mainSource:find("local function loadMapObjectEvents(", 1, true))
local last = assert(mainSource:find("\n-- Real RemoveObjectEventByLocalIdAndMap", first, true))
local loaderSource = mainSource:sub(first, last - 1)
local call = assert(loaderSource:find('require("src.core.ViridianOldManProjection").apply(', 1, true))
local spawn = assert(loaderSource:find("pcall(ObjectEventState.new, objectEvents", 1, true))
check("production projection precedes NPC construction", call < spawn)
local mapLoad = assert(mainSource:find("function loadMap(data, addrs, mapId, dbg)", 1, true))
local decode = assert(mainSource:find("MapEvents.resolve(data, header.eventsPtr)", mapLoad, true))
local loadObjects = assert(mainSource:find("loadMapObjectEvents(data, events, mapId)", decode, true))
check("production events decode before object loading", decode < loadObjects)

local function runLoader(mapId, scene, missingSession, hideOldMan)
  local source, messages, calls = fixtures(), {}, 0
  local before = copy(source)
  local session, reads = sessionFor(scene)
  source[1].flagId = 123
  before[1].flagId = 123
  session.getFlag = function(_, id) return hideOldMan and id == 123 end
  local world = {globalRng=Rng.new(1)}
  local env = setmetatable({
    world=world, newGame={session=not missingSession and session or nil},
    ensureRngStreams=function() end, isWalkTileBlocked=function() return false end,
    ObjectEventState=ObjectEventState, romAddrs={gWildMonHeaders=0},
    WildEncounters={findHeader=function() return nil end},
    addLine=function(message) messages[#messages+1] = message end,
    require=function(name)
      assert(name == "src.core.ViridianOldManProjection", "unexpected loader dependency")
      calls = calls + 1
      return Projection
    end,
  }, {__index=_G})
  local chunk = assert(loadstring(loaderSource .. "\nreturn loadMapObjectEvents", "@main.lua:loadMapObjectEvents"))
  setfenv(chunk, env)
  chunk()("", {objectEvents=source, bgEvents={}, coordEvents={}}, mapId)
  check("loader preserves decoded templates", equal(source, before) and world.mapObjectEventTemplates == source)
  return world, messages, calls, reads
end
for _, case in ipairs({{0,34,11,8}, {1,32,8,1}, {2,32,6,1}}) do
  local world, _, calls, reads = runLoader(769, case[1])
  local npc = world.npcs[2]
  check("actual loader projects scene " .. case[1], npc.localId == 4 and npc.graphicsId == case[2]
    and npc.x == 21 and npc.y == case[3] and npc.movementType == case[4] and calls == 1 and #reads == 1)
end
do
  local world, _, calls, reads = runLoader(768, 0)
  check("actual loader does not project other map", world.npcs[2].graphicsId == 240 and calls == 0 and #reads == 0)
  local missing, messages = runLoader(769, 0, true)
  check("actual loader surfaces missing-session diagnostic", missing.npcs[2].graphicsId == 240
    and table.concat(messages, "\n"):find("projection skipped: missing_session", 1, true) ~= nil)
  local hidden, hiddenMessages, _, hiddenReads = runLoader(769, 0, false, true)
  check("existing hide filter is preserved", #hidden.npcs == 2 and hidden.npcs[1].localId == 9
    and hidden.npcs[2].localId == 7 and #hiddenReads == 0)
  check("filtered target is diagnosed, never respawned", table.concat(hiddenMessages, "\n"):find(
    "projection skipped: missing_template", 1, true) ~= nil)
  local invalid, invalidMessages = runLoader(769, -1)
  check("actual loader preserves refusal instead of projecting fallback", invalid.npcs[2].graphicsId == 240
    and table.concat(invalidMessages, "\n"):find("projection skipped: invalid_scene", 1, true) ~= nil)
end

print(("phase5_viridian_old_man_projection_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
