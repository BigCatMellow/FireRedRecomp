-- Real Pokédex owned/seen bit-array tracking, pokefirered
-- include/global.h (struct Pokedex, inside struct SaveBlock2) and
-- src/pokedex_screen.c (DexScreen_GetSetPokedexFlag, GetSetPokedexFlag).
--
-- struct Pokedex (include/global.h):
--   /*0x10*/ u8 owned[DEX_FLAGS_NO];
--   /*0x44*/ u8 seen[DEX_FLAGS_NO];
-- DEX_FLAGS_NO = ROUND_BITS_TO_BYTES(NUM_SPECIES) = ceil(412/8) = 52 --
-- NUM_SPECIES is SPECIES_EGG (412, include/constants/species.h), and the
-- 0x44-0x10 = 0x34 = 52-byte gap between the two real struct fields
-- confirms the 52 independently.
--
-- Real indexing formula, transcribed directly from
-- DexScreen_GetSetPokedexFlag(u16 nationalDexNo, u8 caseId, ...)
-- (src/pokedex_screen.c):
--   nationalDexNo--;               -- national dex # is 1-based, array is 0-based
--   index = nationalDexNo / 8;     -- byte offset into owned[]/seen[]
--   bit = nationalDexNo % 8;       -- bit within that byte
--   mask = 1 << bit;
-- Both `owned` and `seen` use this identical formula (only the array
-- differs), and real GetSetPokedexFlag's FLAG_GET_SEEN/FLAG_GET_CAUGHT/
-- FLAG_SET_SEEN/FLAG_SET_CAUGHT case IDs (include/pokedex.h) map directly
-- onto this module's isSeen/isOwned/setSeen/setOwned.
--
-- Real FireRed also runs an "anticheat" triple-check on GET (comparing
-- gSaveBlock2Ptr->pokedex.seen/owned against gSaveBlock1Ptr->seen1/seen2
-- mirror copies) -- that's save-block corruption-detection plumbing, out
-- of scope here (this module only models the bit arrays themselves, not
-- the save block's redundant mirrors; see the save-block handoff for
-- that layer).
--
-- Indexed by National Dex number (1-based, matching
-- import/PokedexOrder.lua's sSpeciesToNationalPokedexNum bridge) -- not
-- species ID directly. No `bit` library needed: only single-bit get/
-- set/clear is required, done with plain div/mod arithmetic (no XOR),
-- unlike BoxPokemonCodec's full-byte XOR which needed the lookup table.

local DexTracker = {}
DexTracker.__index = DexTracker

DexTracker.DEX_FLAGS_NO = 52 -- ROUND_BITS_TO_BYTES(NUM_SPECIES), see header
DexTracker.NATIONAL_DEX_COUNT = 411 -- NATIONAL_DEX_COUNT (== NATIONAL_DEX_DEOXYS), constants/pokedex.h

local function byteBitFor(nationalDexNo)
  local zeroBased = nationalDexNo - 1
  local index = math.floor(zeroBased / 8)
  local bit = zeroBased % 8
  return index, bit
end

local function isBitSet(byteVal, bit)
  return math.floor(byteVal / (2 ^ bit)) % 2 == 1
end

local function withBitSet(byteVal, bit)
  if isBitSet(byteVal, bit) then return byteVal end
  return byteVal + 2 ^ bit
end

function DexTracker.new()
  local self = setmetatable({ owned = {}, seen = {} }, DexTracker)
  for i = 0, DexTracker.DEX_FLAGS_NO - 1 do
    self.owned[i] = 0
    self.seen[i] = 0
  end
  return self
end

local function get(bytes, nationalDexNo)
  assert(nationalDexNo >= 1 and nationalDexNo <= DexTracker.NATIONAL_DEX_COUNT,
    "national dex number out of range: " .. tostring(nationalDexNo))
  local index, bit = byteBitFor(nationalDexNo)
  return isBitSet(bytes[index], bit)
end

local function set(bytes, nationalDexNo)
  assert(nationalDexNo >= 1 and nationalDexNo <= DexTracker.NATIONAL_DEX_COUNT,
    "national dex number out of range: " .. tostring(nationalDexNo))
  local index, bit = byteBitFor(nationalDexNo)
  bytes[index] = withBitSet(bytes[index], bit)
end

function DexTracker:isOwned(nationalDexNo)
  return get(self.owned, nationalDexNo)
end

function DexTracker:isSeen(nationalDexNo)
  return get(self.seen, nationalDexNo)
end

-- Real FireRed sets owned only alongside seen in practice (catching/
-- registering implies having seen it), but the two real arrays/flags
-- are independent bits -- this module exposes them independently too,
-- same as the real FLAG_SET_SEEN/FLAG_SET_CAUGHT case IDs do.
function DexTracker:setSeen(nationalDexNo)
  set(self.seen, nationalDexNo)
end

function DexTracker:setOwned(nationalDexNo)
  set(self.owned, nationalDexNo)
end

return DexTracker
