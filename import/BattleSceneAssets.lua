-- ROM-backed visual assets for the first live wild-battle scene. Pure data
-- transforms only: the caller turns returned composites into love.Images.
--
-- The grass background symbols and layout are from src/battle_bg.c's
-- sBattleTerrainTable[BATTLE_TERRAIN_GRASS]. BG3 is 4bpp, screenSize=1
-- (64x32 tiles), with 3 compressed palette banks loaded at BG_PLTT_ID(2).
-- Pokémon use the existing gMonFrontPicTable/gMonBackPicTable compressed
-- 64x64 sheets plus gMonPaletteTable's compressed 16-color palette.

local Lz77 = require("import.Lz77")
local GbaGraphics = require("import.GbaGraphics")
local ObjectSprite = require("import.ObjectSprite")
local CompressedSpriteSheetTable = require("import.CompressedSpriteSheetTable")
local Charmap = require("import.Charmap")

local BattleSceneAssets = {}
local ROM_BASE = 0x08000000
local byte = string.byte

local function u32le(data, offset)
  return byte(data, offset + 1) + byte(data, offset + 2) * 256
    + byte(data, offset + 3) * 65536 + byte(data, offset + 4) * 16777216
end

local function decompressAt(data, offset, label)
  local raw, err = Lz77.decompress(data, offset + 1)
  if not raw then error(label .. " decompression failed: " .. tostring(err)) end
  return raw
end

function BattleSceneAssets.decodeMon(data, addrs, species, back)
  local tableOffset = back and addrs.gMonBackPicTable or addrs.gMonFrontPicTable
  local sheet = CompressedSpriteSheetTable.resolve(data, tableOffset, species)
  local gfx = decompressAt(data, sheet.dataPtr - ROM_BASE, "Pokemon sprite")
  if #gfx ~= sheet.size then
    error(("Pokemon sprite size mismatch: table says %d, got %d"):format(sheet.size, #gfx))
  end

  -- struct CompressedSpritePalette is pointer + u16 tag + 2 bytes tail
  -- padding, the same 8-byte array stride as CompressedSpriteSheet.
  local palRecord = addrs.gMonPaletteTable + species * 8
  local paletteRaw = decompressAt(data, u32le(data, palRecord) - ROM_BASE, "Pokemon palette")
  local palette = GbaGraphics.decodePalette(paletteRaw, 0)
  local tiles = ObjectSprite.decodeFrameTiles(gfx, 0, 8, 8, 0)
  return ObjectSprite.buildImage(tiles, palette, 8, 8)
end

-- Visible 240x160 window into the real 64x32 grass battle BG at scroll 0.
function BattleSceneAssets.compositeGrassBackground(data, addrs)
  local tilesRaw = decompressAt(data, addrs.sBattleTerrainTiles_Grass, "grass battle tiles")
  local mapRaw = decompressAt(data, addrs.sBattleTerrainTilemap_Grass, "grass battle tilemap")
  local paletteRaw = decompressAt(data, addrs.sBattleTerrainPalette_Grass, "grass battle palette")
  local tiles = GbaGraphics.decodeTiles(tilesRaw, 0, math.floor(#tilesRaw / 32))
  local palette = GbaGraphics.decodeFlatPalette(paletteRaw, 0, math.floor(#paletteRaw / 2))
  local pixels = {}

  for ty = 0, 19 do
    pixels[ty * 8] = pixels[ty * 8] or {}
    for tx = 0, 29 do
      local entryIndex = ty * 64 + tx -- BG screenSize=1 is 64 tiles wide
      local lo, hi = byte(mapRaw, entryIndex * 2 + 1), byte(mapRaw, entryIndex * 2 + 2)
      if not (lo and hi) then error("grass battle tilemap ended early") end
      local entry = lo + hi * 256
      local tile = tiles[entry % 1024]
      local hFlip = math.floor(entry / 1024) % 2 == 1
      local vFlip = math.floor(entry / 2048) % 2 == 1
      local bank = math.floor(entry / 4096) % 16
      if not tile then error("grass battle tile id is outside its tileset") end
      for py = 0, 7 do
        local row = ty * 8 + py
        pixels[row] = pixels[row] or {}
        for px = 0, 7 do
          local sx, sy = hFlip and (7 - px) or px, vFlip and (7 - py) or py
          local colorIndex = tile[sy * 8 + sx]
          -- LoadBattleTerrainGfx installs this 3-bank payload starting at
          -- BG_PLTT_ID(2), so tilemap bank 2 indexes payload colors 0..15.
          -- Bank-0/tile-0 entries are the intentionally blank part of the
          -- 64x32 screen block and use color 0 from the separately-loaded
          -- battle-interface palette; black is its untouched backdrop.
          local color
          if bank == 0 and colorIndex == 0 then
            color = { r = 0, g = 0, b = 0 }
          else
            color = palette[(bank - 2) * 16 + colorIndex]
          end
          if not color then error("grass battle tile references an unloaded palette bank") end
          pixels[row][tx * 8 + px] = color
        end
      end
    end
  end

  return {
    width = 240,
    height = 160,
    getPixel = function(x, y)
      local c = pixels[y] and pixels[y][x]
      return c and { r = c.r, g = c.g, b = c.b, a = 1 } or { r = 0, g = 0, b = 0, a = 1 }
    end,
  }
end

-- Plain ASCII -> TextRenderer token bridge for dynamic battle messages.
-- Newlines become real line-break tokens; unknown bytes become spaces.
local charToByte = {}
for b = 0, 255 do
  local ch = Charmap.BYTE_TO_CHAR[b]
  if ch and #ch == 1 and not charToByte[ch] then charToByte[ch] = b end
end
function BattleSceneAssets.textTokens(text, darkText)
  local tokens = {}
  if darkText then tokens[#tokens + 1] = { type = "color", fg = 2, shadow = 3 } end
  for i = 1, #text do
    local ch = text:sub(i, i)
    if ch == "\n" then
      tokens[#tokens + 1] = { type = "newline" }
    else
      tokens[#tokens + 1] = { type = "char", glyphId = charToByte[ch] or 0 }
    end
  end
  return tokens
end

return BattleSceneAssets
