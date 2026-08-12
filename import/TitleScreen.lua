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
              local c = palette[colorIndex]
              pixels[y] = pixels[y] or {}
              pixels[y][tx * 8 + px] = { r = c.r, g = c.g, b = c.b, a = 1 }
            end
          end
        end
      end
    end
  end
end

-- transparentBase: whether pixels no layer touched should render fully
-- transparent (for a partial composite meant to be drawn *over* another
-- layer, e.g. TitleScreen.compositeAboveBorder) rather than opaque black
-- (the default -- correct for a composite that's meant to stand alone,
-- like compositeFull's final result, where every pixel is always
-- covered by at least the border layer).
local function pixelsToImage(pixels, transparentBase)
  local pixelWidth, pixelHeight = TitleScreen.WIDTH_TILES * 8, TitleScreen.HEIGHT_TILES * 8
  local emptyPixel = { r = 0, g = 0, b = 0, a = transparentBase and 0 or 1 }
  return {
    width = pixelWidth,
    height = pixelHeight,
    getPixel = function(x, y)
      local row = pixels[y]
      return (row and row[x]) or emptyPixel
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
  return pixelsToImage(pixels, true)
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

-- The border backdrop alone (bg3, priority 3, back-most) -- fills the
-- whole canvas, so it's always opaque. This is the layer the flame OBJ
-- sprites (also priority 3) render over but still tuck behind bg2/1/0
-- (see LayerCompositor.lua) -- exposed separately from compositeFull so
-- a caller can interleave the flame sprites at the correct point in the
-- real draw order instead of drawing them after everything.
function TitleScreen.compositeBorder(data, addrs)
  local pixels = {}
  local borderTilesRaw = Lz77.decompress(data, addrs.sBorderBgTiles + 1)
  local borderTiles = GbaGraphics.decodeTiles(borderTilesRaw, 0, math.floor(#borderTilesRaw / 32))
  local borderMapRaw = Lz77.decompress(data, addrs.sBorderBgMap + 1)
  local borderPalette = GbaGraphics.decodePalette(data, addrs.gGraphics_TitleScreen_BackgroundPals)
  drawLayer(pixels, borderTiles, borderMapRaw, borderPalette)
  return pixelsToImage(pixels)
end

-- Copyright/press-start (bg2, priority 2) and box art (bg1, priority 1)
-- composited together, back-to-front -- exposed separately from the logo
-- (bg0) because the real title screen's slash-in effect only ever
-- targets bg0 (SetGpuRegsForTitleScreenRun's real
-- `BLDCNT_TGT1_BG0 | BLDCNT_EFFECT_LIGHTEN`), so a caller applying that
-- effect needs the logo isolated rather than baked into one flat image
-- with layers the effect shouldn't touch.
function TitleScreen.compositeCopyrightAndBoxArt(data, addrs)
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

  return pixelsToImage(pixels, true)
end

-- Copyright/press-start, box art, and the logo composited together,
-- back-to-front -- the three layers with a lower priority number than
-- the border/flames, so they always draw in front of both. Unlike
-- compositeBorder, pixels no layer touches render fully transparent
-- (transparentBase=true) so this can be drawn *over* the border+flames
-- without blotting them out.
function TitleScreen.compositeAboveBorder(data, addrs)
  local below = TitleScreen.compositeCopyrightAndBoxArt(data, addrs)
  local logo = TitleScreen.compositeLogo(data, addrs.gGraphics_TitleScreen_GameTitleLogoTiles, addrs.gGraphics_TitleScreen_GameTitleLogoMap, addrs.gGraphics_TitleScreen_GameTitleLogoPals)
  local pixels = {}
  for y = 0, below.height - 1 do
    pixels[y] = {}
    for x = 0, below.width - 1 do
      local topPixel = logo.getPixel(x, y)
      pixels[y][x] = topPixel.a ~= 0 and topPixel or below.getPixel(x, y)
    end
  end
  return pixelsToImage(pixels, true)
end

-- Composites the border backdrop, then copyright/press-start, then the box
-- art Pokémon, then the logo on top -- back-to-front, matching bg3..bg0
-- priority order (lower priority number draws on top). addrs: the
-- RomAddresses[sha1] table. This is compositeBorder + compositeAboveBorder
-- flattened into one opaque image; a caller that needs to interleave the
-- flame OBJ sprites at the correct real draw order (see LayerCompositor.lua)
-- should call those two separately instead and draw the flames between them.
function TitleScreen.compositeFull(data, addrs)
  local border = TitleScreen.compositeBorder(data, addrs)
  local above = TitleScreen.compositeAboveBorder(data, addrs)
  local pixels = {}
  for y = 0, border.height - 1 do
    pixels[y] = {}
    for x = 0, border.width - 1 do
      local topPixel = above.getPixel(x, y)
      pixels[y][x] = topPixel.a ~= 0 and topPixel or border.getPixel(x, y)
    end
  end
  return pixelsToImage(pixels)
end

return TitleScreen
