-- Integration test: resolves REAL Pallet Town object events (via
-- MapHeader.resolve + MapEvents.resolve, the same real chain
-- full_sweep_validation_test.lua exercises) and builds real
-- ObjectEventState NPCs from them -- proving MapEvents.resolve(...)'s real
-- `.objectEvents` output (not a synthetic fixture) plugs directly into
-- ObjectEventState.new(). Opt-in via POKEPORT_ROM, skips cleanly otherwise.
--
-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/object_event_state_integration_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local MapHeader = require("import.MapHeader")
local MapEvents = require("import.MapEvents")
local ObjectEventState = require("src.core.ObjectEventState")
local ObjectEventInteraction = require("src.core.ObjectEventInteraction")
local Rng = require("src.core.Rng")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local ok, info = RomImporter.verify(romPath)
if not ok then
  print("FAIL: ROM did not verify -- " .. tostring(info))
  os.exit(1)
end

local sha1 = RomImporter._sha1HexOfFile(romPath)
local addrs = RomAddresses[sha1]
local f = io.open(romPath, "rb")
local data = f:read("*a")
f:close()

-- MAP_PALLET_TOWN = group 3, num 0 (matches tests/map_header_test.lua).
local MAP_PALLET_TOWN = 3 * 256 + 0
local header = MapHeader.resolve(data, addrs.gMapGroups, MAP_PALLET_TOWN)
local events = MapEvents.resolve(data, header.eventsPtr)

local npcs, skippedClones = ObjectEventState.new(events.objectEvents, { rng = Rng.new(999) })
check("Pallet Town has real object events decoded", #npcs > 0, #npcs)
check("Pallet Town has no clone objects (unlike Celadon City)", #skippedClones == 0, #skippedClones)

-- Find the real Sign Lady (localId 1 per data/maps/PalletTown/map.json's
-- LOCALID_PALLET_SIGN_LADY) and Prof Oak (localId 3) among the decoded NPCs.
local signLady, profOak
for _, npc in ipairs(npcs) do
  if npc.x == 3 and npc.y == 10 then signLady = npc end
  if npc.x == 10 and npc.y == 8 then profOak = npc end
end

check("real Sign Lady found (graphicsId OBJ_EVENT_GFX_WOMAN_1=23, WANDER_AROUND)",
  signLady ~= nil and signLady.graphicsId == 23 and signLady.movementType == 2)
check("real Prof Oak found (graphicsId OBJ_EVENT_GFX_PROF_OAK=71, FACE_UP)",
  profOak ~= nil and profOak.graphicsId == 71 and profOak.movementType == 7)

if signLady then
  check("Sign Lady's real initial facing is DOWN", signLady.facingDirection == ObjectEventState.DOWN)
  check("Sign Lady's real movement range (rangeX=1, rangeY=4)", signLady.rangeX == 1 and signLady.rangeY == 4)
  for _ = 1, 5000 do signLady:tick() end
  check("Sign Lady stayed within her real movement range after wandering",
    signLady.x >= 2 and signLady.x <= 4 and signLady.y >= 6 and signLady.y <= 14,
    signLady.x .. "," .. signLady.y)
end

if profOak then
  local target = ObjectEventInteraction.findInteractionTarget(10, 9, ObjectEventState.UP, npcs)
  check("player standing south of Prof Oak facing up finds him via the real interaction trigger", target == profOak)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
