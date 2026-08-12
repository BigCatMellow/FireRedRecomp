-- Parses metatile tile entries (pokefirered src/field_camera.c: each
-- metatile is NUM_TILES_PER_METATILE=8 consecutive u16 entries -- 2
-- background layers x 2x2 subtiles -- copied more or less directly to GBA
-- background tilemap VRAM). Because these are raw GBA BG tilemap entries,
-- not FireRed-specific data, they use the standard universal GBA tile-entry
-- bit layout (same as any GBA background, not something reverse-engineered
-- from this ROM specifically):
--   bits 0-9    tile number (0-1023)
--   bit 10       horizontal flip
--   bit 11       vertical flip
--   bits 12-15  palette number (0-15)
--
-- A tileset's `metatiles` pointer holds this ROM's primary tileset's
-- metatiles (640 of them, NUM_METATILES_IN_PRIMARY); the secondary
-- tileset's metatiles continue directly after in the game's actual lookup
-- (MapGridGetMetatileIdAt indexes a combined space), but each tileset
-- struct only points at its own array -- combining them for a specific map
-- is the caller's job (see MapMetatiles.lua).

local Metatile = {}

Metatile.TILES_PER_METATILE = 8
Metatile.NUM_METATILES_IN_PRIMARY = 640

local byte = string.byte

local function u16le(data, offset0based)
  return byte(data, offset0based + 1) + byte(data, offset0based + 2) * 256
end

-- Decodes one raw GBA tile-entry u16 into {tileId, hFlip, vFlip, palette}.
function Metatile.decodeTileEntry(entry)
  return {
    tileId = entry % 1024,
    hFlip = math.floor(entry / 1024) % 2 == 1,
    vFlip = math.floor(entry / 2048) % 2 == 1,
    palette = math.floor(entry / 4096) % 16,
  }
end

-- data: full ROM bytes. metatilesOffset: 0-based file offset of a tileset's
-- metatiles array. metatileIndex: index *within that tileset's own array*
-- (not a combined primary+secondary index -- see MapMetatiles.lua for that).
-- Returns an 8-entry array of decoded tile entries.
function Metatile.resolve(data, metatilesOffset, metatileIndex)
  local base = metatilesOffset + metatileIndex * Metatile.TILES_PER_METATILE * 2
  local out = {}
  for i = 0, Metatile.TILES_PER_METATILE - 1 do
    out[i] = Metatile.decodeTileEntry(u16le(data, base + i * 2))
  end
  return out
end

return Metatile
