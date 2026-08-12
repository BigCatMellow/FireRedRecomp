-- Phase 1 shell: boots a window, verifies a ROM if POKEPORT_ROM points at
-- one, composites a real map (block grid + metatiles + tile graphics +
-- palettes, straight out of that ROM) into an image and draws it, and --
-- the Phase 1 exit criterion -- offers a read-only data viewer (press V)
-- to browse every species/move/trainer/map record. Defaults to Pallet
-- Town; POKEPORT_MAP=group,num renders any other map (see
-- MapCompositor.lua's doc comment on the metatile layer-type attribute
-- this doesn't read yet -- it affects sprite z-order, not the static
-- background, so it's not needed for what's drawn today). No gameplay, no
-- camera, no player/object sprites: this is "can we turn ROM bytes into a
-- recognizable map and browse its data," not a game yet. See
-- ../firered-recomp-roadmap.md Phase 2 for the real renderer.

local Version = require("src.core.Version")
local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local MapHeader = require("import.MapHeader")
local MapLayout = require("import.MapLayout")
local MapBlockData = require("import.MapBlockData")
local MapBorder = require("import.MapBorder")
local MapCompositor = require("import.MapCompositor")
local DataViewer = require("src.core.DataViewer")

local BORDER_MARGIN_METATILES = 2

local MAP_PALLET_TOWN = 3 * 256 + 0 -- group 3, num 0

-- POKEPORT_MAP=group,num overrides the default map (Pallet Town) -- used to
-- spot-check the compositor generalizes beyond the one map it was built
-- against, e.g. POKEPORT_MAP=3,19 (Route 1) or POKEPORT_MAP=4,0 (Pallet
-- Town's Player's House 1F, an indoor map with a different tileset).
local function selectedMapId()
  local override = os.getenv("POKEPORT_MAP")
  if not override then return MAP_PALLET_TOWN end
  local group, num = override:match("^(%d+),(%d+)$")
  if not group then return MAP_PALLET_TOWN end
  return tonumber(group) * 256 + tonumber(num)
end

local statusLines = {}
local mapImage
local MAP_SCALE = 2

-- Set once the ROM verifies, so the data viewer (toggled at any time with
-- V) can browse records without re-reading the file.
local romData, romAddrs

-- Data viewer state: which category/record is being browsed, and whether
-- the viewer is showing instead of the map.
local viewerActive = false
local viewerCategoryIndex = 1 -- index into DataViewer.CATEGORIES
local viewerRecordIndex = { species = 1, moves = 1, trainers = 0, maps = 3 * 256 + 0 }

local function addLine(text)
  table.insert(statusLines, text)
end

-- Builds a love.graphics.Image from a MapCompositor.composite() result.
local function buildMapImage(compositedMap)
  local imageData = love.image.newImageData(compositedMap.width, compositedMap.height)
  for y = 0, compositedMap.height - 1 do
    for x = 0, compositedMap.width - 1 do
      local color = compositedMap.getPixel(x, y)
      imageData:setPixel(x, y, color.r / 255, color.g / 255, color.b / 255, 1)
    end
  end
  return love.graphics.newImage(imageData)
end

local function loadMapFromRom(romPath)
  local ok, info = RomImporter.verify(romPath)
  if not ok then
    addLine("ROM verification failed: " .. tostring(info))
    return
  end
  addLine(("ROM verified: %s v%s"):format(info.name, info.revision))

  local sha1 = RomImporter._sha1Hex((function()
    local f = io.open(romPath, "rb")
    local data = f:read("*a")
    f:close()
    return data
  end)())
  local addrs = RomAddresses[sha1]
  if not addrs then
    addLine("No known table addresses for this ROM's sha1.")
    return
  end

  local f = io.open(romPath, "rb")
  local data = f:read("*a")
  f:close()
  romData, romAddrs = data, addrs

  local DEBUG = os.getenv("POKEPORT_DEBUG") == "1"
  local function dbg(msg) if DEBUG then print("[dbg] " .. msg) io.stdout:flush() end end

  local mapId = selectedMapId()
  dbg("selectedMapId " .. mapId)
  local header = MapHeader.resolve(data, addrs.gMapGroups, mapId)
  dbg("header resolved")
  local layout = MapLayout.resolve(data, header.mapLayoutPtr)
  dbg("layout resolved " .. layout.width .. "x" .. layout.height)
  local blockData = MapBlockData.resolve(data, layout.mapPtr, layout.width, layout.height)
  dbg("blockData resolved")
  local border = MapBorder.resolve(data, layout.borderPtr, layout.borderWidth, layout.borderHeight)
  dbg("border resolved")
  local primary = MapCompositor.loadTilesetData(data, layout.primaryTilesetPtr)
  dbg("primary tileset loaded, tiles=" .. #primary.tiles)
  local secondary = MapCompositor.loadTilesetData(data, layout.secondaryTilesetPtr)
  dbg("secondary tileset loaded, tiles=" .. #secondary.tiles)
  local composited = MapCompositor.compositeWithBorder(data, primary, secondary, blockData, layout.width, layout.height, border, layout.borderWidth, layout.borderHeight, BORDER_MARGIN_METATILES)
  dbg("composited " .. composited.width .. "x" .. composited.height)

  addLine(("Composited map %d,%d: %dx%d metatiles, %dx%d px"):format(math.floor(mapId / 256), mapId % 256, layout.width, layout.height, composited.width, composited.height))
  mapImage = buildMapImage(composited)
  dbg("image built")
  mapImage:setFilter("nearest", "nearest")
  dbg("filter set")

  addLine("Press V for the data viewer (species/moves/trainers/maps).")
end

-- ---------------------------------------------------------------- viewer

local function viewerCategory()
  return DataViewer.CATEGORIES[viewerCategoryIndex]
end

local function viewerLines()
  if not romData then return { "No ROM loaded." } end
  local category = viewerCategory()
  local index = viewerRecordIndex[category]
  local lines = { ("[%s] record %s  (Tab: category, Up/Down: -+1, PgUp/PgDn: -+10, V: back to map)"):format(category, tostring(index)) }
  local ok, described = pcall(DataViewer.describe, romData, romAddrs, category, index)
  if ok then
    for _, l in ipairs(described) do lines[#lines + 1] = l end
  else
    lines[#lines + 1] = "Error: " .. tostring(described)
  end
  return lines
end

local function viewerStep(delta)
  local category = viewerCategory()
  if category == "maps" then
    -- Step the map number within the current group; Left/Right (handled
    -- separately) steps the group.
    local group = math.floor(viewerRecordIndex.maps / 256)
    local num = (viewerRecordIndex.maps % 256) + delta
    if num < 0 then num = 0 end
    if num > 255 then num = 255 end
    viewerRecordIndex.maps = group * 256 + num
  else
    viewerRecordIndex[category] = viewerRecordIndex[category] + delta
    if viewerRecordIndex[category] < 0 then viewerRecordIndex[category] = 0 end
  end
end

local function viewerStepGroup(delta)
  if viewerCategory() ~= "maps" then return end
  local group = math.floor(viewerRecordIndex.maps / 256) + delta
  local num = viewerRecordIndex.maps % 256
  if group < 0 then group = 0 end
  if group > 255 then group = 255 end
  viewerRecordIndex.maps = group * 256 + num
end

function love.load()
  love.window.setTitle(Version.title .. " " .. Version.version)
  addLine(Version.title .. " " .. Version.version)

  local romPath = os.getenv("POKEPORT_ROM")
  if not romPath then
    addLine("Set POKEPORT_ROM=/path/to/rom.gba to see real tile graphics decoded from it.")
    return
  end

  local okCall, errMsg = pcall(loadMapFromRom, romPath)
  if not okCall then
    addLine("Error: " .. tostring(errMsg))
  end

  -- POKEPORT_VIEWER=category:index boots straight into the data viewer on
  -- that record, e.g. POKEPORT_VIEWER=species:1 -- used for automated
  -- screenshot verification without needing real keypresses.
  local viewerOverride = os.getenv("POKEPORT_VIEWER")
  if viewerOverride then
    local category, index = viewerOverride:match("^(%a+):(-?%d+)$")
    if category and viewerRecordIndex[category] ~= nil then
      viewerActive = true
      for i, c in ipairs(DataViewer.CATEGORIES) do
        if c == category then viewerCategoryIndex = i end
      end
      viewerRecordIndex[category] = tonumber(index)
    end
  end

  -- love.filesystem is sandboxed to the save directory (see conf.lua's
  -- identity="firered-recomp"), so this always writes there under a fixed
  -- name rather than to an arbitrary POKEPORT_SCREENSHOT path.
  if os.getenv("POKEPORT_SCREENSHOT") == "1" and (mapImage or viewerActive) then
    love.graphics.captureScreenshot(function(imageData)
      imageData:encode("png", "screenshot.png")
      love.event.quit()
    end)
  end
end

function love.draw()
  love.graphics.clear(0.08, 0.08, 0.1)
  local y = 20
  for _, line in ipairs(statusLines) do
    love.graphics.print(line, 20, y)
    y = y + 20
  end

  if viewerActive then
    y = y + 10
    for _, line in ipairs(viewerLines()) do
      love.graphics.print(line, 20, y)
      y = y + 20
    end
  elseif mapImage then
    love.graphics.draw(mapImage, 20, y + 10, 0, MAP_SCALE, MAP_SCALE)
  end
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  elseif key == "v" then
    viewerActive = not viewerActive
  elseif viewerActive then
    if key == "tab" then
      viewerCategoryIndex = (viewerCategoryIndex % #DataViewer.CATEGORIES) + 1
    elseif key == "down" then
      viewerStep(1)
    elseif key == "up" then
      viewerStep(-1)
    elseif key == "pagedown" then
      viewerStep(10)
    elseif key == "pageup" then
      viewerStep(-10)
    elseif key == "right" then
      viewerStepGroup(1)
    elseif key == "left" then
      viewerStepGroup(-1)
    end
  end
end
