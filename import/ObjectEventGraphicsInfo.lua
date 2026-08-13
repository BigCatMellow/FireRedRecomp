-- Decodes a real `struct ObjectEventGraphicsInfo` (pokefirered
-- include/global.fieldmap.h) -- the missing link between an
-- ObjectEventTemplate's `graphicsId` (import/MapEvents.lua) and the real
-- ROM bytes that draw that NPC: its OAM template, subsprite table, anim
-- table, pic (frame image) table, and palette tag.
--
-- Lookup path (real src/event_object_movement.c GetObjectEventGraphicsInfo,
-- line ~2040): `gObjectEventGraphicsInfoPointers[graphicsId]` -- an ARRAY OF
-- POINTERS (not a flat struct array), one pointer per graphicsId, each
-- pointing at a separate real per-NPC struct instance. Real fallback rules
-- (reproduced in .resolveGraphicsId): a graphicsId >= OBJ_EVENT_GFX_VARS
-- (240) is a dynamic/VAR-resolved id (real VarGetObjectEventGraphicsId --
-- needs live script-var state this module doesn't have access to, so this
-- is a documented scope-out, raised loudly rather than silently
-- mis-resolved); a graphicsId >= NUM_OBJ_EVENT_GFX (152, real static id
-- count) falls back to OBJ_EVENT_GFX_LITTLE_BOY (16), exactly like the real
-- function.
--
-- Struct layout (36 bytes = 0x24, real source below), verified against real
-- ROM bytes for gObjectEventGraphicsInfo_Woman1 (graphicsId
-- OBJ_EVENT_GFX_WOMAN_1=23, used by Pallet Town's real Sign Lady NPC --
-- see MapEvents.lua's header comment) reached via the real pointer table at
-- gObjectEventGraphicsInfoPointers (0x0839fdb0, found via
-- `arm-none-eabi-nm`): decodes to width=16, height=32 (exactly the real
-- declared .width/.height), oam pointer 0x083a3710 (exactly
-- gObjectEventBaseOam_16x32's real nm address, already in RomAddresses.lua
-- from OamShapeSize.lua's earlier work), and images pointer 0x083a0688
-- (exactly the real nm address of sPicTable_Woman1). No agbcc padding
-- surprises: fields are declared at 2/4-byte-friendly offsets already (two
-- u8 bitfield/tracks bytes at 0x0C/0x0D need 2 bytes of tail padding before
-- the 0x10 pointer block, matching the explicit /*0x10*/ comment in the
-- real header), so the struct decodes at exactly its C-declared offsets:
--
--   /*0x00*/ u16 tileTag
--   /*0x02*/ u16 paletteTag
--   /*0x04*/ u16 reflectionPaletteTag
--   /*0x06*/ u16 size
--   /*0x08*/ s16 width
--   /*0x0A*/ s16 height
--   /*0x0C*/ u8 paletteSlot:4, shadowSize:2, inanimate:1, disableReflectionPaletteLoad:1
--   /*0x0D*/ u8 tracks
--   /*0x0E-0x0F*/ padding (align pointer block to 4)
--   /*0x10*/ const struct OamData *oam
--   /*0x14*/ const struct SubspriteTable *subspriteTables
--   /*0x18*/ const union AnimCmd *const *anims
--   /*0x1C*/ const struct SpriteFrameImage *images
--   /*0x20*/ const union AffineAnimCmd *const *affineAnims
--
-- `struct SpriteFrameImage { const void *data; u16 size; }` (include/
-- sprite.h) decodes to an 8-byte stride (4-byte pointer + u16 size + 2
-- bytes padding), NOT the naive 6 -- verified against 3 consecutive real
-- sPicTable_Woman1 entries: stride 8 gives frame0/1/2 pointers
-- 0x083703a8/0x083704a8/0x083705a8 (each exactly 256 bytes -- 2x4 tiles --
-- apart, matching the real `overworld_frame(gObjectEventPic_Woman1, 2, 4,
-- N)` macro's declared size), while stride 6 produces garbage. Frame 0's
-- pointer is exactly gObjectEventPic_Woman1's real nm address (0x083703a8).
--
-- Palette resolution: `paletteTag` (NOT a direct pointer) is resolved
-- through the real local/static `sObjectEventSpritePalettes[]` table
-- (src/event_object_movement.c ~line 481, `struct SpritePalette { const
-- u16 *data; u16 tag; }`, found via nm as it has no linker-map symbol) --
-- a small, hand-curated pool of shared NPC/player palettes (most NPCs reuse
-- one of a handful of real palettes), NOT one entry per graphicsId.
-- Verified byte-for-byte: entry index 2 decodes to data ptr 0x0836d868 /
-- tag 0x1105, exactly the real gObjectEventPal_NpcGreen address and
-- OBJ_EVENT_PAL_TAG_NPC_GREEN -- exactly what Woman1's real .paletteTag
-- resolves to. Entry index 8 (data ptr 0x0835b968, tag 0x1100 =
-- OBJ_EVENT_PAL_TAG_PLAYER_RED) exactly matches RomAddresses.lua's existing
-- gObjectEventPal_Player address, an independent cross-check. Confirmed
-- 8-byte stride (u32 ptr + u16 tag + 2 bytes padding), terminated by a real
-- {NULL, 0} sentinel entry (index 18 here).
--
-- Facing-direction frame selection: real per-direction anim command bodies
-- (src/data/object_events/object_event_anims.h) --
-- sAnim_FaceSouth/_FaceNorth/_FaceWest/_FaceEast -- resolve to
-- ANIMCMD_FRAME(0,...)/ (1,...)/ (2,...)/ (2,..., .hFlip=TRUE): standing
-- frame images are 0=south(down), 1=north(up), 2=west(left), and EAST
-- reuses the SAME frame 2 horizontally flipped (this game DOES do the
-- "shared L/R frame via hFlip" trick, not distinct L/R art) -- confirmed
-- from real source, not guessed. This is `sAnimTable_Standard`, used by the
-- large majority of real NPCs including Woman1/RedNormal/RedBike; a handful
-- of special objects (Ho-Oh, certain animals) use a different anims table
-- (e.g. sAnimTable_HoOh) with different south/north frame choices -- NOT
-- decoded here (this module doesn't decode the real AnimCmd bytecode at
-- all, since the standing-frame indices above are fixed/documented real
-- constants shared by the standard table, not something that needs
-- decoding per-NPC) -- a documented scoped simplification affecting only
-- those special-cased real objects, not ordinary human NPCs.

local ObjectSprite = require("import.ObjectSprite")

local ObjectEventGraphicsInfo = {}

ObjectEventGraphicsInfo.romBase = 0x08000000
ObjectEventGraphicsInfo.STRUCT_SIZE = 0x24
ObjectEventGraphicsInfo.NUM_OBJ_EVENT_GFX = 152 -- include/constants/event_objects.h
ObjectEventGraphicsInfo.OBJ_EVENT_GFX_VARS = 240
ObjectEventGraphicsInfo.OBJ_EVENT_GFX_LITTLE_BOY = 16

local byte = string.byte

local function s16le(data, offset0based)
  local v = byte(data, offset0based + 1) + byte(data, offset0based + 2) * 256
  if v >= 32768 then v = v - 65536 end
  return v
end

local function u16le(data, offset0based)
  return byte(data, offset0based + 1) + byte(data, offset0based + 2) * 256
end

local function u32le(data, offset0based)
  return byte(data, offset0based + 1)
    + byte(data, offset0based + 2) * 256
    + byte(data, offset0based + 3) * 65536
    + byte(data, offset0based + 4) * 16777216
end

-- Real fallback rules from GetObjectEventGraphicsInfo (see header comment).
-- Errors loudly on VAR-based ids rather than silently guessing a value,
-- per this project's "fail loudly on unimplemented" convention.
function ObjectEventGraphicsInfo.resolveGraphicsId(graphicsId)
  if graphicsId >= ObjectEventGraphicsInfo.OBJ_EVENT_GFX_VARS then
    error(("ObjectEventGraphicsInfo: dynamic (VAR-based) graphicsId %d not implemented -- " ..
      "real VarGetObjectEventGraphicsId needs live script-var state this module doesn't have"):format(graphicsId))
  end
  if graphicsId >= ObjectEventGraphicsInfo.NUM_OBJ_EVENT_GFX then
    return ObjectEventGraphicsInfo.OBJ_EVENT_GFX_LITTLE_BOY
  end
  return graphicsId
end

-- data: full ROM bytes. pointerTablePtr: RomAddresses.gObjectEventGraphicsInfoPointers
-- (already pre-subtracted file offset, per RomAddresses.lua's convention --
-- used directly, NOT subtracted again). graphicsId: the raw id from an
-- ObjectEventTemplate (MapEvents.lua's .objectEvents[n].graphicsId).
function ObjectEventGraphicsInfo.decode(data, pointerTablePtr, graphicsId)
  local resolvedId = ObjectEventGraphicsInfo.resolveGraphicsId(graphicsId)
  local entryOffset = pointerTablePtr + resolvedId * 4
  local structPtr = u32le(data, entryOffset) -- raw ROM pointer, decoded out of ROM data itself
  local base = structPtr - ObjectEventGraphicsInfo.romBase

  local bitfieldByte = byte(data, base + 0x0C + 1)

  return {
    graphicsId = resolvedId,
    structPtr = structPtr,
    tileTag = u16le(data, base + 0x00),
    paletteTag = u16le(data, base + 0x02),
    reflectionPaletteTag = u16le(data, base + 0x04),
    size = u16le(data, base + 0x06),
    width = s16le(data, base + 0x08),
    height = s16le(data, base + 0x0A),
    paletteSlot = bitfieldByte % 16,
    shadowSize = math.floor(bitfieldByte / 16) % 4,
    inanimate = math.floor(bitfieldByte / 64) % 2 == 1,
    disableReflectionPaletteLoad = math.floor(bitfieldByte / 128) % 2 == 1,
    tracks = byte(data, base + 0x0D + 1),
    oamPtr = u32le(data, base + 0x10),
    subspriteTablesPtr = u32le(data, base + 0x14),
    animsPtr = u32le(data, base + 0x18),
    imagesPtr = u32le(data, base + 0x1C),
    affineAnimsPtr = u32le(data, base + 0x20),
  }
end

-- Decodes one real `struct SpriteFrameImage` entry (8-byte stride -- see
-- header comment). imagesPtr: a RAW ROM pointer (from .decode()'s
-- `.imagesPtr`, NOT the RomAddresses convention -- subtracted here).
function ObjectEventGraphicsInfo.decodeFrameImagePointer(data, imagesPtr, frameIndex)
  local off = imagesPtr - ObjectEventGraphicsInfo.romBase + frameIndex * 8
  return { dataPtr = u32le(data, off), size = u16le(data, off + 4) }
end

-- Resolves a real paletteTag/reflectionPaletteTag to its raw palette data
-- pointer via sObjectEventSpritePalettes (see header comment). spritePalettesPtr:
-- RomAddresses.sObjectEventSpritePalettes (pre-subtracted file offset, used
-- directly). Linear-scans until the real {NULL,0} terminator; errors loudly
-- if the tag isn't found (a real gap would mean a bad RomAddresses entry or
-- an unsupported reflection/dynamic palette tag, not something to silently
-- paper over).
function ObjectEventGraphicsInfo.resolvePaletteTag(data, spritePalettesPtr, paletteTag)
  local i = 0
  while true do
    local off = spritePalettesPtr + i * 8
    local ptr = u32le(data, off)
    local tag = u16le(data, off + 4)
    if ptr == 0 and tag == 0 then
      error(("ObjectEventGraphicsInfo: palette tag 0x%04X not found in sObjectEventSpritePalettes"):format(paletteTag))
    end
    if tag == paletteTag then
      return ptr
    end
    i = i + 1
  end
end

-- Real standing-frame index + hFlip per facing direction, from
-- sAnimTable_Standard's sAnim_Face{South,North,West,East} bodies -- see
-- header comment. Direction strings match PlayerMovement.lua's
-- DOWN/UP/LEFT/RIGHT convention.
local FACE_FRAME = {
  down = { frame = 0, hFlip = false },
  up = { frame = 1, hFlip = false },
  left = { frame = 2, hFlip = false },
  right = { frame = 2, hFlip = true },
}
ObjectEventGraphicsInfo.FACE_FRAME = FACE_FRAME

-- Connects graphicsId -> real pixels: decodes the standing-frame image for
-- a resolved facing direction, using the existing ObjectSprite decode
-- pipeline (no new graphics-decode primitive needed, per the task brief).
-- data: full ROM bytes. info: from .decode(). palettePtr: raw ROM pointer
-- from .resolvePaletteTag(). facingDirection: "down"/"up"/"left"/"right".
-- Returns (image, hFlip) -- hFlip is true for "right" (see FACE_FRAME); the
-- caller (a future love2d-side renderer, out of scope here) is responsible
-- for actually flipping the drawn quad, matching how
-- ObjectSprite.compositeSubsprites already documents hFlip as the
-- renderer's job, not the decoder's.
--
-- Only single-OAM-entry objects (width/height <= 64px, true for every real
-- humanoid NPC graphic -- 152 of 153 real gObjectEventGraphicsInfo entries,
-- the sole exception being the 128x64 SS Anne vehicle graphic) are
-- supported by this path; a >64px object raises a loud error pointing at
-- ObjectSprite.compositeSubsprites (already proven against real SS Anne
-- data) as the fallback, since compositing does not support hFlip and
-- isn't independently re-verified against a *facing-aware* NPC by this
-- task (no ordinary interactive NPC needs it in verified data).
function ObjectEventGraphicsInfo.decodeStandingImage(data, info, palettePtr, facingDirection)
  local face = FACE_FRAME[facingDirection]
  if not face then
    error("ObjectEventGraphicsInfo: unknown facing direction " .. tostring(facingDirection))
  end
  if info.width > 64 or info.height > 64 then
    error(("ObjectEventGraphicsInfo: graphicsId %d is %dx%d, exceeds the single-OAM 64x64 cap -- " ..
      "use ObjectSprite.compositeSubsprites with this info's subspriteTablesPtr instead " ..
      "(not wired here: no facing-aware multi-OAM NPC exists in verified data)"):format(
      info.graphicsId, info.width, info.height))
  end

  local frame = ObjectEventGraphicsInfo.decodeFrameImagePointer(data, info.imagesPtr, face.frame)
  local widthTiles, heightTiles = info.width / 8, info.height / 8
  local image = ObjectSprite.decodeFrame(
    data,
    frame.dataPtr - ObjectEventGraphicsInfo.romBase,
    palettePtr - ObjectEventGraphicsInfo.romBase,
    widthTiles,
    heightTiles,
    0)
  return image, face.hFlip
end

return ObjectEventGraphicsInfo
