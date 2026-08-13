-- Decodes a real `struct SubspriteTable` / `struct Subsprite`
-- (pokefirered include/sprite.h) -- the mechanism real overworld objects
-- use to build a visual sprite out of MULTIPLE OAM entries when it's
-- bigger/more complex than fits in ObjectSprite.lua/OamShapeSize.lua's
-- single-OAM-entry cap (64x64px, the largest real GBA OAM size). Real
-- consumer is src/sprite.c's AddSubspritesToOamBuffer: each Subsprite's
-- (x, y) is an OAM-style top-left-corner offset from the parent sprite's
-- own drawn corner (`oam.x - sprite->centerToCornerVecX`, etc; for a
-- static decode with no live `struct Sprite`/camera, this collapses to
-- "just an offset in a shared coordinate space -- composite by bounding
-- box"), its shape/size pick real OAM pixel dimensions
-- (OamShapeSize.PIXEL_DIMENSIONS), and tileOffset is added to the base
-- OAM's tileNum -- i.e. each subsprite's tile data lives in the SAME pic
-- sheet ObjectSprite.lua already decodes (a tile-unit, 32-bytes/tile,
-- offset into it), not a separate graphic.
--
-- Struct layout confirmed against real ROM bytes, not assumed from the C
-- declaration alone:
--
--   struct Subsprite { s8 x; s8 y; u16 shape:2; size:2; tileOffset:10;
--   priority:2; } decodes to EXACTLY 4 bytes/entry, no agbcc padding
--   (unlike AffineAnimCmd's real 6-declared/8-actual padding surprise) --
--   verified byte-for-byte against three real, consecutive entries at
--   gObjectEventSpriteOamTable_16x16_0/_1 (0x083a3728, 0x083a372c): both
--   decode to their real declared x=-8,y=-8,shape=0 (SQUARE),size=1
--   (16x16), tileOffset=0, priority=2/1 respectively; and against real
--   gObjectEventSpriteOamTable_128x64_0 (SS Anne's 4-entry table,
--   0x083a3a20): decodes to exactly the real x=-32/32/-32/32,
--   y=-16/-16/16/16, shape=1 (H_RECTANGLE), size=3 (64x32px),
--   tileOffset=0/32/64/96, priority=2 declared in
--   src/data/object_events/object_event_subsprites.h.
--
--   struct SubspriteTable { u8 subspriteCount; const struct Subsprite
--   *subsprites; } decodes to 8 bytes/entry (1 byte count + 3 bytes
--   alignment padding + 4-byte pointer) -- confirmed against real
--   gObjectEventSpriteOamTables_16x16[] (0x083a3748): entry 0 is a real
--   {0, NULL} passthrough (all 8 bytes zero), entry 1 is real
--   {1, gObjectEventSpriteOamTable_16x16_0} whose pointer bytes decode to
--   exactly 0x083a3728 -- the same address `nm` reports for that symbol.
--
-- Also confirmed by reading real pokefirered data (not decoded from ROM,
-- just read from source, since it explains *why* a table is used): the
-- player's own gObjectEventGraphicsInfo_RedNormal/_Mom use
-- gObjectEventSpriteOamTables_16x32 even though 16x32px fits one OAM
-- entry. Its 6 table entries are OAM-priority-layering variants (e.g.
-- splitting the sprite into a body-below/body-above-grass pair with
-- different `priority` per subsprite) selected by runtime state, NOT
-- sprite-size compositing -- table index 0 is a real {0, NULL}
-- passthrough (render the sprite's single OAM entry as-is), which is
-- what a static decode should use for such an object. Subsprite
-- *animation* (per-frame OAM tables) is not used anywhere in this data --
-- every SubspriteTable here is a single static layout picked once, not a
-- sequence -- so it's out of scope, per the task.

local SubspriteTable = {}

local byte = string.byte

local SUBSPRITE_STRIDE = 4
local TABLE_ENTRY_STRIDE = 8
SubspriteTable.SUBSPRITE_STRIDE = SUBSPRITE_STRIDE
SubspriteTable.TABLE_ENTRY_STRIDE = TABLE_ENTRY_STRIDE

-- data: full ROM bytes. offset: 0-based offset of a real Subsprite[]
-- array. count: number of entries (from the owning SubspriteTable's
-- subspriteCount). Returns a list of
-- { x, y, shape, size, tileOffset, priority } (x/y signed s8; shape/size
-- match OamShapeSize's [shape][size] indexing).
function SubspriteTable.decodeSubsprites(data, offset, count)
  local subsprites = {}
  for i = 0, count - 1 do
    local p = offset + i * SUBSPRITE_STRIDE
    local bx = byte(data, p + 1)
    local by = byte(data, p + 2)
    local b2, b3 = byte(data, p + 3), byte(data, p + 4)

    local x = bx >= 128 and (bx - 256) or bx
    local y = by >= 128 and (by - 256) or by
    local value = b2 + b3 * 256

    local shape = value % 4
    local size = math.floor(value / 4) % 4
    local tileOffset = math.floor(value / 16) % 1024
    local priority = math.floor(value / 16384) % 4

    subsprites[i + 1] = {
      x = x, y = y, shape = shape, size = size,
      tileOffset = tileOffset, priority = priority,
    }
  end
  return subsprites
end

-- data: full ROM bytes. offset: 0-based offset of a real SubspriteTable
-- entry (u8 count + pad + pointer to a Subsprite[]). The pointer bytes
-- are a RAW ROM POINTER decoded straight out of ROM data (full
-- 0x08xxxxxx address) -- NOT the RomAddresses.lua pre-subtracted
-- convention; this function does the "- 0x08000000" itself.
-- Returns { count = n, subsprites = {...} }, or { count = 0,
-- subsprites = {} } for a real {0, NULL} passthrough entry (meaning:
-- render the sprite's own single OAM entry as-is, no compositing).
function SubspriteTable.decodeTable(data, offset)
  local count = byte(data, offset + 1)
  if count == 0 then
    return { count = 0, subsprites = {} }
  end
  local p0, p1 = byte(data, offset + 5), byte(data, offset + 6)
  local p2, p3 = byte(data, offset + 7), byte(data, offset + 8)
  local pointer = p0 + p1 * 256 + p2 * 65536 + p3 * 16777216
  local subOffset = pointer - 0x08000000
  return { count = count, subsprites = SubspriteTable.decodeSubsprites(data, subOffset, count) }
end

return SubspriteTable
