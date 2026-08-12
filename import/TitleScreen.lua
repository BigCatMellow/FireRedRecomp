-- Composites FireRed's title screen logo ("Pokémon FireRed Version"),
-- pokefirered src/title_screen.c. This is Phase 2 territory (the roadmap's
-- exit criterion for Phase 2 is literally "title screen ... screenshot
-- parity"), started early because the pieces (Lz77, tile-entry decode)
-- already existed from the map renderer and only needed an 8bpp tile
-- decoder added.
--
-- The logo layer (BG 0 in sBgTemplates) is `paletteMode: 1` -- 8bpp, NOT
-- 4bpp like every tile graphic decoded so far. Confirmed empirically: naive
-- 4bpp decoding produces visual noise; 8bpp decoding produces the exact
-- real "Pokémon FireRed Version" logo art (yellow/blue lettering,
-- correctly shaped), spot-checked by eye against the known real title
-- screen. The tilemap format itself is the same 16-bit tile-entry layout
-- as everything else (tile id + h/v flip); the palette nibble bits are
-- meaningless for 8bpp BGs and ignored.
--
-- Palette: LoadPalette(..., BG_PLTT_ID(0), 13 * PLTT_SIZE_4BPP) loads 13
-- consecutive 16-color banks (208 colors) as ONE flat 8bpp palette, not 13
-- separate 4bpp palettes -- 8bpp backgrounds don't bank-select per tile.
--
-- Dimensions: the compressed tilemap decompresses to exactly 640 bytes/2 =
-- 640 u16 entries = 32 tiles wide x 20 tall (256x160px) -- wider than the
-- 240px-visible screen (BG can scroll slightly), tall enough to cover the
-- 160px screen height exactly.

local Lz77 = require("import.Lz77")
local GbaGraphics = require("import.GbaGraphics")

local TitleScreen = {}

TitleScreen.romBase = 0x08000000
TitleScreen.LOGO_WIDTH_TILES = 32
TitleScreen.LOGO_HEIGHT_TILES = 20
TitleScreen.LOGO_PALETTE_COLORS = 13 * 16

-- data: full ROM bytes. tilesOffset/mapOffset/palOffset: 0-based file
-- offsets (matching RomAddresses.lua's convention -- already
-- romBase-subtracted -- unlike raw pointers this project decodes out of
-- ROM data itself). tiles/map are LZ77-compressed; palette is not.
-- Returns { width, height, getPixel(px, py) -> {r,g,b} } in pixel units.
function TitleScreen.compositeLogo(data, tilesOffset, mapOffset, palOffset)
  local tilesRaw, tilesErr = Lz77.decompress(data, tilesOffset + 1)
  if not tilesRaw then error("logo tiles decompression failed: " .. tostring(tilesErr)) end
  local tiles = GbaGraphics.decodeTiles8bpp(tilesRaw, 0, math.floor(#tilesRaw / 64))

  local mapRaw, mapErr = Lz77.decompress(data, mapOffset + 1)
  if not mapRaw then error("logo map decompression failed: " .. tostring(mapErr)) end

  local palette = GbaGraphics.decodeFlatPalette(data, palOffset, TitleScreen.LOGO_PALETTE_COLORS)

  local width, height = TitleScreen.LOGO_WIDTH_TILES, TitleScreen.LOGO_HEIGHT_TILES
  local pixelWidth, pixelHeight = width * 8, height * 8
  local pixels = {}

  local byte = string.byte
  for ty = 0, height - 1 do
    for tx = 0, width - 1 do
      local entryIdx = ty * width + tx
      local b1, b2 = byte(mapRaw, entryIdx * 2 + 1), byte(mapRaw, entryIdx * 2 + 2)
      if not (b1 and b2) then
        error(("logo tilemap read ran past end of data at tile %d,%d"):format(tx, ty))
      end
      local entry = b1 + b2 * 256
      local tileId = entry % 1024
      local hFlip = math.floor(entry / 1024) % 2 == 1
      local vFlip = math.floor(entry / 2048) % 2 == 1
      local tile = tiles[tileId]
      if tile then
        for py = 0, 7 do
          for px = 0, 7 do
            local sx = hFlip and (7 - px) or px
            local sy = vFlip and (7 - py) or py
            local colorIndex = tile[sy * 8 + sx]
            if colorIndex ~= 0 then -- 0 = transparent
              local y = ty * 8 + py
              pixels[y] = pixels[y] or {}
              pixels[y][tx * 8 + px] = palette[colorIndex]
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

return TitleScreen
