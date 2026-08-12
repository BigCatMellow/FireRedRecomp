-- Composites FireRed's title screen layers (pokefirered src/title_screen.c).
-- This is Phase 2 territory (the roadmap's exit criterion for Phase 2 is
-- literally "title screen ... screenshot parity"), started early because
-- the pieces (Lz77, tile-entry decode) already existed from the map
-- renderer.
--
-- Four background layers, each a `struct BgTemplate` in sBgTemplates,
-- lower `priority` drawn on top:
--   bg0 priority0 (front): game title logo -- 8bpp (paletteMode=1), the
--     ONLY 8bpp graphic in this project so far; every other tile graphic
--     decoded (all map tiles, this layer's siblings below) is 4bpp.
--     Confirmed empirically: decoding it as 4bpp produces visual noise;
--     8bpp produces the exact real "Pokémon FireRed Version" logo art.
--   bg1 priority1: box art Pokémon (Charizard) -- 4bpp, one palette bank.
--   bg2 priority2: copyright notice + "PRESS START" -- 4bpp, one palette bank.
--   bg3 priority3 (back): animated border/flames/slash -- NOT implemented
--     yet (its tile/palette symbols are `static`, not in the linker `.map`
--     -- would need the `nm` trick, and the flame/slash pieces are
--     genuinely animated OBJs, not just a static BG, so this is more
--     involved than the other three layers).
--
-- All three implemented layers verified: logo by exact pixel color
-- (yellow 255,247,41 lettering, blue outline) and live screenshot; box art
-- and copyright/press-start by eye against known real title screen
-- content (Charizard breathing fire; "PRESS START" and the
-- "©2004 GAME FREAK inc." copyright line, both legible and correctly
-- positioned).
--
-- Palette layout: the logo's 8bpp mode uses a flat 208-color palette
-- (13 banks loaded as one block, BG_PLTT_ID(0)). The 4bpp layers each load
-- exactly ONE 16-color bank (BG_PLTT_ID(13)/(14)/(15) for box art/border/
-- copyright respectively) -- confirmed by checking their tilemap entries'
-- palette nibble, which is always exactly that bank index (13 for box art,
-- for example) -- but since only one bank is loaded per 4bpp layer, this
-- module just uses that layer's single decoded palette for every tile,
-- ignoring the (redundant, always-constant-per-layer) nibble value.
--
-- Dimensions: every layer's compressed tilemap decompresses to exactly
-- 640 u16 entries = 32 tiles wide x 20 tall (256x160px) -- wider than the
-- 240px-visible screen (BG can scroll slightly), tall enough to cover the
-- 160px screen height exactly.

local Lz77 = require("import.Lz77")
local GbaGraphics = require("import.GbaGraphics")

local TitleScreen = {}

TitleScreen.romBase = 0x08000000
TitleScreen.WIDTH_TILES = 32
TitleScreen.HEIGHT_TILES = 20
TitleScreen.LOGO_PALETTE_COLORS = 13 * 16

local byte = string.byte

local function decodeTileEntry(b1, b2)
  local entry = b1 + b2 * 256
  return {
    tileId = entry % 1024,
    hFlip = math.floor(entry / 1024) % 2 == 1,
    vFlip = math.floor(entry / 2048) % 2 == 1,
  }
end

-- Shared by every layer: walks a 32x20 tilemap, drawing each tile's pixels
-- (skipping palette index 0 -- transparent) into `pixels`, a
-- pixels[y][x] = {r,g,b} sparse grid the caller owns (so multiple layers
-- can be composited into one shared buffer in back-to-front order).
local function drawLayer(pixels, tiles, mapRaw, palette)
  for ty = 0, TitleScreen.HEIGHT_TILES - 1 do
    for tx = 0, TitleScreen.WIDTH_TILES - 1 do
      local entryIdx = ty * TitleScreen.WIDTH_TILES + tx
      local b1, b2 = byte(mapRaw, entryIdx * 2 + 1), byte(mapRaw, entryIdx * 2 + 2)
      if not (b1 and b2) then
        error(("tilemap read ran past end of data at tile %d,%d"):format(tx, ty))
      end
      local entry = decodeTileEntry(b1, b2)
      local tile = tiles[entry.tileId]
      if tile then
        for py = 0, 7 do
          for px = 0, 7 do
            local sx = entry.hFlip and (7 - px) or px
            local sy = entry.vFlip and (7 - py) or py
            local colorIndex = tile[sy * 8 + sx]
            if colorIndex ~= 0 then
              local y = ty * 8 + py
              pixels[y] = pixels[y] or {}
              pixels[y][tx * 8 + px] = palette[colorIndex]
            end
          end
        end
      end
    end
  end
end

local function pixelsToImage(pixels)
  local pixelWidth, pixelHeight = TitleScreen.WIDTH_TILES * 8, TitleScreen.HEIGHT_TILES * 8
  return {
    width = pixelWidth,
    height = pixelHeight,
    getPixel = function(x, y)
      local row = pixels[y]
      return (row and row[x]) or { r = 0, g = 0, b = 0 }
    end,
  }
end

-- data: full ROM bytes. tilesOffset/mapOffset/palOffset: 0-based file
-- offsets (matching RomAddresses.lua's convention). tiles/map are
-- LZ77-compressed; palette is not.
function TitleScreen.compositeLogo(data, tilesOffset, mapOffset, palOffset)
  local tilesRaw, tilesErr = Lz77.decompress(data, tilesOffset + 1)
  if not tilesRaw then error("logo tiles decompression failed: " .. tostring(tilesErr)) end
  local tiles = GbaGraphics.decodeTiles8bpp(tilesRaw, 0, math.floor(#tilesRaw / 64))

  local mapRaw, mapErr = Lz77.decompress(data, mapOffset + 1)
  if not mapRaw then error("logo map decompression failed: " .. tostring(mapErr)) end

  local palette = GbaGraphics.decodeFlatPalette(data, palOffset, TitleScreen.LOGO_PALETTE_COLORS)

  local pixels = {}
  drawLayer(pixels, tiles, mapRaw, palette)
  return pixelsToImage(pixels)
end

-- Generic 4bpp title-screen layer (box art Pokémon, copyright/press-start).
-- Same shape as compositeLogo but 4bpp tiles + a single 16-color palette.
function TitleScreen.compositeLayer4bpp(data, tilesOffset, mapOffset, palOffset)
  local tilesRaw, tilesErr = Lz77.decompress(data, tilesOffset + 1)
  if not tilesRaw then error("layer tiles decompression failed: " .. tostring(tilesErr)) end
  local tiles = GbaGraphics.decodeTiles(tilesRaw, 0, math.floor(#tilesRaw / 32))

  local mapRaw, mapErr = Lz77.decompress(data, mapOffset + 1)
  if not mapRaw then error("layer map decompression failed: " .. tostring(mapErr)) end

  local palette = GbaGraphics.decodePalette(data, palOffset)

  local pixels = {}
  drawLayer(pixels, tiles, mapRaw, palette)
  return pixelsToImage(pixels)
end

-- Composites the copyright/press-start layer, then the box art Pokémon,
-- then the logo on top -- back-to-front, matching bg3..bg0 priority order
-- (lower priority number draws on top). addrs: the RomAddresses[sha1]
-- table (needs gGraphics_TitleScreen_{GameTitleLogo,BoxArtMon,
-- CopyrightPressStart}{Tiles,Map,Pals}). The border/flames layer (bg3,
-- furthest back) isn't implemented yet -- see this module's doc comment.
function TitleScreen.compositeFull(data, addrs)
  local pixels = {}

  local copyrightTilesRaw = Lz77.decompress(data, addrs.gGraphics_TitleScreen_CopyrightPressStartTiles + 1)
  local copyrightTiles = GbaGraphics.decodeTiles(copyrightTilesRaw, 0, math.floor(#copyrightTilesRaw / 32))
  local copyrightMapRaw = Lz77.decompress(data, addrs.gGraphics_TitleScreen_CopyrightPressStartMap + 1)
  local copyrightPalette = GbaGraphics.decodePalette(data, addrs.gGraphics_TitleScreen_BackgroundPals)
  drawLayer(pixels, copyrightTiles, copyrightMapRaw, copyrightPalette)

  local boxArtTilesRaw = Lz77.decompress(data, addrs.gGraphics_TitleScreen_BoxArtMonTiles + 1)
  local boxArtTiles = GbaGraphics.decodeTiles(boxArtTilesRaw, 0, math.floor(#boxArtTilesRaw / 32))
  local boxArtMapRaw = Lz77.decompress(data, addrs.gGraphics_TitleScreen_BoxArtMonMap + 1)
  local boxArtPalette = GbaGraphics.decodePalette(data, addrs.gGraphics_TitleScreen_BoxArtMonPals)
  drawLayer(pixels, boxArtTiles, boxArtMapRaw, boxArtPalette)

  local logoTilesRaw = Lz77.decompress(data, addrs.gGraphics_TitleScreen_GameTitleLogoTiles + 1)
  local logoTiles = GbaGraphics.decodeTiles8bpp(logoTilesRaw, 0, math.floor(#logoTilesRaw / 64))
  local logoMapRaw = Lz77.decompress(data, addrs.gGraphics_TitleScreen_GameTitleLogoMap + 1)
  local logoPalette = GbaGraphics.decodeFlatPalette(data, addrs.gGraphics_TitleScreen_GameTitleLogoPals, TitleScreen.LOGO_PALETTE_COLORS)
  drawLayer(pixels, logoTiles, logoMapRaw, logoPalette)

  return pixelsToImage(pixels)
end

return TitleScreen
