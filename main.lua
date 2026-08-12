-- Phase 1 shell: boots a window, verifies a ROM if POKEPORT_ROM points at
-- one, and -- the first real visual proof this project produces anything
-- -- decodes Pallet Town's primary tileset graphics straight out of that
-- ROM and draws them as a tile atlas. No map compositing, no gameplay:
-- this is "can we turn ROM bytes into pixels," not a game yet. See
-- ../firered-recomp-roadmap.md Phase 2 for the real renderer.

local Version = require("src.core.Version")
local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local MapHeader = require("import.MapHeader")
local MapLayout = require("import.MapLayout")
local Tileset = require("import.Tileset")
local Lz77 = require("import.Lz77")
local GbaGraphics = require("import.GbaGraphics")

local MAP_PALLET_TOWN = 3 * 256 + 0 -- group 3, num 0

local statusLines = {}
local tileAtlasImage
local TILE_SCALE = 4

local function addLine(text)
  table.insert(statusLines, text)
end

-- Builds a love.graphics.Image tile atlas from decoded tiles + a palette.
-- Tiles are laid out left-to-right, wrapping every `tilesPerRow` tiles.
local function buildTileAtlasImage(tiles, palette, tilesPerRow)
  local rows = math.ceil(#tiles / tilesPerRow)
  local imageData = love.image.newImageData(tilesPerRow * 8, rows * 8)

  for tileIndex = 0, #tiles do
    local tile = tiles[tileIndex]
    local tileX = (tileIndex % tilesPerRow) * 8
    local tileY = math.floor(tileIndex / tilesPerRow) * 8
    for py = 0, 7 do
      for px = 0, 7 do
        local colorIndex = tile[py * 8 + px]
        local color = palette[colorIndex]
        -- Palette index 0 is GBA's conventional transparent color; draw it
        -- as fully transparent so the atlas background shows through
        -- instead of a wrong opaque color.
        local a = colorIndex == 0 and 0 or 1
        imageData:setPixel(tileX + px, tileY + py, color.r / 255, color.g / 255, color.b / 255, a)
      end
    end
  end

  return love.graphics.newImage(imageData)
end

local function loadTileAtlasFromRom(romPath)
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

  local header = MapHeader.resolve(data, addrs.gMapGroups, MAP_PALLET_TOWN)
  local layout = MapLayout.resolve(data, header.mapLayoutPtr)
  local tileset = Tileset.resolve(data, layout.primaryTilesetPtr)

  local tileBytes = tileset.tilesPtr - 0x08000000
  local decompressed, err
  if tileset.isCompressed then
    decompressed, err = Lz77.decompress(data, tileBytes + 1)
    if not decompressed then
      addLine("Tile decompression failed: " .. tostring(err))
      return
    end
  else
    decompressed = data:sub(tileBytes + 1)
  end

  local tileCount = math.floor(#decompressed / 32)
  local tiles = GbaGraphics.decodeTiles(decompressed, 0, tileCount)
  local palette = GbaGraphics.decodePalette(data, tileset.palettesPtr - 0x08000000)

  addLine(("Decoded %d tiles from Pallet Town's primary tileset (%s)"):format(tileCount, layout.width .. "x" .. layout.height .. " map"))
  tileAtlasImage = buildTileAtlasImage(tiles, palette, 16)
  tileAtlasImage:setFilter("nearest", "nearest")
end

function love.load()
  love.window.setTitle(Version.title .. " " .. Version.version)
  addLine(Version.title .. " " .. Version.version)

  local romPath = os.getenv("POKEPORT_ROM")
  if not romPath then
    addLine("Set POKEPORT_ROM=/path/to/rom.gba to see real tile graphics decoded from it.")
    return
  end

  local okCall, errMsg = pcall(loadTileAtlasFromRom, romPath)
  if not okCall then
    addLine("Error: " .. tostring(errMsg))
  end

  -- love.filesystem is sandboxed to the save directory (see conf.lua's
  -- identity="firered-recomp"), so this always writes there under a fixed
  -- name rather than to an arbitrary POKEPORT_SCREENSHOT path.
  if os.getenv("POKEPORT_SCREENSHOT") == "1" and tileAtlasImage then
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

  if tileAtlasImage then
    love.graphics.draw(tileAtlasImage, 20, y + 10, 0, TILE_SCALE, TILE_SCALE)
  end
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  end
end
