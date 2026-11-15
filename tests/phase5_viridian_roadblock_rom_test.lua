-- Opt-in verified-ROM fixture for the bounded Viridian City C0 roadblock.
-- Run:
--   POKEPORT_ROM=/path/to/pokefirered.gba lua5.1 tests/phase5_viridian_roadblock_rom_test.lua
-- Verifies SHA-1 41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc through RomImporter
-- before any read, then resolves map 3,1 through the existing header/event/
-- script/layout importers. Every pointer is resolved dynamically; no ROM
-- bytes, pointer constants or dialogue are stored or printed here.
package.path = package.path .. ";./?.lua"

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local MapHeader = require("import.MapHeader")
local MapEvents = require("import.MapEvents")
local MapScripts = require("import.MapScripts")
local MapLayout = require("import.MapLayout")
local MapBlockData = require("import.MapBlockData")
local ViridianRoadblock = require("src.core.ViridianRoadblock")

local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase5_viridian_roadblock_rom_test (set POKEPORT_ROM)"); os.exit(0) end
local ok, info = RomImporter.verify(path)
if not ok then print("FAIL: ROM verification -- " .. tostring(info)); os.exit(1) end
local f = assert(io.open(path, "rb")); local rom = f:read("*a"); f:close()
local addrs = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end
local function inRom(ptr)
  return type(ptr) == "number" and ptr >= 0x08000000 and ptr - 0x08000000 < #rom
end

local MAP_VIRIDIAN_CITY = 3 * 256 + 1
local header = MapHeader.resolve(rom, addrs.gMapGroups, MAP_VIRIDIAN_CITY)
local events = MapEvents.resolve(rom, header.eventsPtr)
local c0 = events.coordEvents[0]

check("C0 is decoded index 0 at (22,11)", c0 ~= nil and c0.x == 22 and c0.y == 11)
check("C0 trigger is VAR_MAP_SCENE_VIRIDIAN_CITY_OLD_MAN value 0",
  c0 ~= nil and c0.trigger == 0x4051 and c0.index == 0)
check("actual selected C0 elevation is 3", c0 ~= nil and c0.elevation == 3, c0 and c0.elevation)
check("C0 script pointer is inside the ROM", c0 ~= nil and inRom(c0.scriptPtr))
local others = 0
for index, event in pairs(events.coordEvents) do
  if index ~= 0 and event.x == 22 and event.y == 11 then others = others + 1 end
end
check("no conflicting coord event shares (22,11)", others == 0, others)

local hooks = MapScripts.resolve(rom, header.mapScriptsPtr)
check("map-script table is exactly one ON_TRANSITION hook",
  hooks[0] ~= nil and hooks[0].type == MapScripts.ON_TRANSITION and hooks[1] == nil
    and inRom(hooks[0].scriptPtr))

local descriptor, reason = ViridianRoadblock.describe(rom, c0 and c0.scriptPtr, header.mapScriptsPtr)
check("bounded C0 script/movement/text descriptor validates", descriptor ~= nil, reason)
if descriptor then
  check("text and movement pointers resolve inside the ROM",
    inRom(descriptor.textPtr) and inRom(descriptor.movementPtr)
      and descriptor.textPtr ~= descriptor.movementPtr)
  local function shape(tokens)
    local glyphs, newlines, other = 0, 0, 0
    for _, token in ipairs(tokens) do
      if token.type == "char" then glyphs = glyphs + 1
      elseif token.type == "newline" then newlines = newlines + 1
      else other = other + 1 end
    end
    return glyphs, newlines, other
  end
  local g1, n1, o1 = shape(descriptor.pages[1])
  local g2, n2, o2 = shape(descriptor.pages[2])
  check("two plain pages: one page-1 newline, none on page 2",
    g1 > 0 and n1 == 1 and o1 == 0 and g2 > 0 and n2 == 0 and o2 == 0)
  local presenter = ViridianRoadblock.new(descriptor, 1)
  check("default mid text speed presenter starts on page 1",
    presenter ~= nil and presenter.state == "PRINT_PAGE1" and presenter.delay == 4)
end

-- Same admission the runtime uses, on the real decoded events.
local context = { mapId=MAP_VIRIDIAN_CITY, x=22, y=11, normalStep=true, moving=false,
  generation=1, stepGeneration=1, scene=0, elevation=3, events=events.coordEvents }
check("real C0 selects known E3", ViridianRoadblock.classify(context) == "owned")
context.elevation = 4
check("real C0 does not select wrong E4", ViridianRoadblock.classify(context) == "not_selected")
context.elevation = 0
check("real C0 does not select known E0 (event E is not the wildcard)",
  ViridianRoadblock.classify(context) == "not_selected")
context.elevation = nil
check("real C0 refuses unknown E", ViridianRoadblock.classify(context) == "refused")

-- Replay fixture prerequisites: an ordinary UP step (22,12)->(22,11) can
-- complete onto height 3, and the forced step's destination is loaded.
local layout = MapLayout.resolve(rom, header.mapLayoutPtr)
local blocks = MapBlockData.resolve(rom, layout.mapPtr, layout.width, layout.height)
local c0Cell = blocks[11 * layout.width + 22]
local belowCell = blocks[12 * layout.width + 22]
check("C0 tile is passable at height 3", c0Cell ~= nil and c0Cell.collision == 0 and c0Cell.elevation == 3,
  c0Cell and (c0Cell.collision .. "/" .. c0Cell.elevation))
-- The forced step bypasses collision, so only loaded-map presence is needed.
check("fixture origin/forced destination (22,12) is on the loaded map",
  belowCell ~= nil and layout.height > 12 and layout.width > 22)

print(("phase5_viridian_roadblock_rom_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
