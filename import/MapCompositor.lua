-- Composites a full map's pixel grid from block data + metatiles + tile
-- graphics + palettes -- turns "a bunch of separately-decoded ROM tables"
-- into one actual image worth of pixel data. Pure data, no love.* calls
-- (testable under plain lua5.1); the caller turns the result into a real
-- image.
--
-- Combines primary + secondary tileset data the way the game actually
-- does: metatile ids and tile ids 0-639 (NUM_TILES_IN_PRIMARY /
-- NUM_METATILES_IN_PRIMARY) come from the primary tileset; ids 640+ come
-- from the secondary tileset, re-indexed by subtracting 640. Palette
-- indices 0-6 (NUM_PALS_IN_PRIMARY) come from the primary tileset's own
-- palette table; indices 7-15 come from the secondary tileset's own
-- palette table at that same absolute index (each tileset carries a full
-- 16-slot palette array, but only its own half is meaningfully populated).
--
-- Layer type (METATILE_ATTRIBUTE_LAYER_TYPE, bits 29-30 of a metatile's u32
-- attribute word, NOT read by this module -- metatileAttributesPtr is
-- parsed by Tileset.lua but unused here) does NOT decide which of a
-- metatile's two 4-tile layers get drawn -- checked against the real
-- DrawMetatile (pokefirered src/field_camera.c): for all three layer types
-- (NORMAL/COVERED/SPLIT), both the bottom (entries 0-3) and top (entries
-- 4-7) tile groups are always drawn to some background layer. What layer
-- type actually controls is *z-order relative to object/player sprites* --
-- whether the "top" tile group renders above or below them (SPLIT/NORMAL
-- put it above via BG2; COVERED puts it below via BG1, so a player can walk
-- "under" that tile group, e.g. under a tree's canopy). Since this
-- compositor draws only the static background (no object/player sprites
-- yet), drawing both layers unconditionally in bottom-then-top order is
-- the behaviorally correct output today, not an approximation. Layer type
-- will matter once sprite compositing exists and needs to interleave with
-- one of these tile groups.

local Metatile = require("import.Metatile")
local GbaGraphics = require("import.GbaGraphics")
local Tileset = require("import.Tileset")
local Lz77 = require("import.Lz77")

local MapCompositor = {}

-- Loads and decodes everything MapCompositor.composite() needs for one
-- tileset: decompresses its tile graphics (if compressed), decodes its
-- palette table, and records its metatiles array's file offset.
function MapCompositor.loadTilesetData(data, tilesetPtr)
  local tileset = Tileset.resolve(data, tilesetPtr)
  local tileBytesOffset = tileset.tilesPtr - Tileset.romBase

  local tileBytes
  if tileset.isCompressed then
    local decompressed, err = Lz77.decompress(data, tileBytesOffset + 1)
    if not decompressed then
      error("tileset decompression failed: " .. tostring(err))
    end
    tileBytes = decompressed
  else
    tileBytes = data:sub(tileBytesOffset + 1)
  end

  local tileCount = math.floor(#tileBytes / 32)

  -- palettesPtr holds 16 back-to-back palettes (16 colors x 2 bytes = 32
  -- bytes each), not just one -- decode all 16 so callers can index by
  -- whatever palette number a metatile's tile entries specify.
  local palettesOffset = tileset.palettesPtr - Tileset.romBase
  local palettes = {}
  for p = 0, 15 do
    palettes[p] = GbaGraphics.decodePalette(data, palettesOffset + p * 32)
  end

  return {
    tiles = GbaGraphics.decodeTiles(tileBytes, 0, tileCount),
    palettes = palettes,
    metatilesOffset = tileset.metatilesPtr - Tileset.romBase,
  }
end

local NUM_TILES_IN_PRIMARY = 640
local NUM_METATILES_IN_PRIMARY = 640
local NUM_PALS_IN_PRIMARY = 7

-- primary/secondary: { tiles = <decoded tile list from GbaGraphics.decodeTiles>,
--                       palettes = <decoded 16-entry palette from GbaGraphics.decodePalette>,
--                       metatilesOffset = <0-based file offset> }
-- blockData: from MapBlockData.resolve(). width/height: from MapLayout.
-- data: full ROM bytes (metatile lookups still read directly from it).
-- Returns { width, height, getPixel(px, py) -> {r,g,b,a} } in pixel units
-- (width*8, height*8 -- 16px per metatile since each is 2x2 tiles).
function MapCompositor.composite(data, primary, secondary, blockData, mapWidth, mapHeight)
  local pixelWidth = mapWidth * 16
  local pixelHeight = mapHeight * 16

  local function tileAndPalette(tileId, paletteIndex)
    if tileId < NUM_TILES_IN_PRIMARY then
      return primary.tiles[tileId], (paletteIndex < NUM_PALS_IN_PRIMARY) and primary.palettes[paletteIndex] or secondary.palettes[paletteIndex]
    else
      return secondary.tiles[tileId - NUM_TILES_IN_PRIMARY], (paletteIndex < NUM_PALS_IN_PRIMARY) and primary.palettes[paletteIndex] or secondary.palettes[paletteIndex]
    end
  end

  local function metatileEntries(metatileId)
    if metatileId < NUM_METATILES_IN_PRIMARY then
      return Metatile.resolve(data, primary.metatilesOffset, metatileId)
    else
      return Metatile.resolve(data, secondary.metatilesOffset, metatileId - NUM_METATILES_IN_PRIMARY)
    end
  end

  -- Precompute one RGBA pixel buffer for the whole map, row-major, so the
  -- caller (LÖVE) just streams it into an image without touching ROM
  -- structures itself.
  local pixels = {} -- pixels[y] = { [x] = {r,g,b,a} }, both 0-indexed

  for mapY = 0, mapHeight - 1 do
    for mapX = 0, mapWidth - 1 do
      local cell = blockData[mapY * mapWidth + mapX]
      local entries = metatileEntries(cell.metatileId)

      -- entries 0-3: bottom layer (2x2 subtiles), 4-7: top layer (2x2).
      -- Draw bottom first, then top on top of it -- correct for a
      -- sprite-less static background regardless of layer type (see
      -- module doc comment above).
      for layer = 0, 1 do
        for sub = 0, 3 do
          local entry = entries[layer * 4 + sub]
          local tile, palette = tileAndPalette(entry.tileId, entry.palette)
          if tile then
            local subX = sub % 2
            local subY = math.floor(sub / 2)
            local baseX = mapX * 16 + subX * 8
            local baseY = mapY * 16 + subY * 8
            for py = 0, 7 do
              for px = 0, 7 do
                local sx = entry.hFlip and (7 - px) or px
                local sy = entry.vFlip and (7 - py) or py
                local colorIndex = tile[sy * 8 + sx]
                if colorIndex ~= 0 then -- 0 = transparent; leave whatever was drawn by the layer below
                  local color = palette[colorIndex]
                  local y = baseY + py
                  pixels[y] = pixels[y] or {}
                  pixels[y][baseX + px] = color
                end
              end
            end
          end
        end
      end
    end
  end

  return {
    width = pixelWidth,
    height = pixelHeight,
    getPixel = function(x, y)
      local row = pixels[y]
      return (row and row[x]) or { r = 0, g = 0, b = 0 }
    end,
  }
end

-- Like composite(), but pads the map with `marginMetatiles` metatiles of
-- border tiling on every side, matching how the real game fills the area
-- past a map's edge (pokefirered src/fieldmap.c GetBorderBlockAt: the
-- border pattern tiles via `x mod borderWidth`, `y mod borderHeight`).
-- border: from MapBorder.resolve(). borderWidth/borderHeight: from the same
-- MapLayout the border came from.
function MapCompositor.compositeWithBorder(data, primary, secondary, blockData, mapWidth, mapHeight, border, borderWidth, borderHeight, marginMetatiles)
  local paddedWidth = mapWidth + marginMetatiles * 2
  local paddedHeight = mapHeight + marginMetatiles * 2

  local paddedBlocks = {}
  for y = 0, paddedHeight - 1 do
    for x = 0, paddedWidth - 1 do
      local mapX = x - marginMetatiles
      local mapY = y - marginMetatiles
      local index = y * paddedWidth + x
      if mapX >= 0 and mapX < mapWidth and mapY >= 0 and mapY < mapHeight then
        paddedBlocks[index] = blockData[mapY * mapWidth + mapX]
      else
        -- Lua's % on negative numbers already returns a non-negative
        -- result (matching C's GetBorderBlockAt after its own normalizing
        -- `+= 8 * borderWidth` step), so this needs no special-casing for
        -- x/y left or above the map.
        local borderIndex = (mapX % borderWidth) + (mapY % borderHeight) * borderWidth
        paddedBlocks[index] = { metatileId = border[borderIndex], collision = 0, elevation = 0 }
      end
    end
  end

  return MapCompositor.composite(data, primary, secondary, paddedBlocks, paddedWidth, paddedHeight)
end

return MapCompositor
