-- Resolves one species' real FireRed level-up learnset from ROM.
--
-- Source:
--   pokefirered src/data/pokemon/level_up_learnsets.h
--     LEVEL_UP_MOVE(lvl, move) == (lvl << 9) | move
--     LEVEL_UP_END == 0xFFFF
--   src/data/pokemon/level_up_learnset_pointers.h
--     gLevelUpLearnsets[NUM_SPECIES], an array of ROM pointers
--   include/constants/pokemon.h
--     LEVEL_UP_MOVE_ID=0x01FF, LEVEL_UP_MOVE_LV=0xFE00,
--     MAX_LEVEL_UP_MOVES=20
--
-- This importer intentionally does not own a linked address. Callers pass
-- the verified gLevelUpLearnsets file offset from their RomAddresses entry.

local LevelUpLearnset = {}

LevelUpLearnset.LEVEL_UP_END = 0xFFFF
LevelUpLearnset.MOVE_ID_MASK = 0x01FF
LevelUpLearnset.LEVEL_DIVISOR = 0x0200
LevelUpLearnset.MAX_LEVEL_UP_MOVES = 20
LevelUpLearnset.GBA_ROM_BASE = 0x08000000

local byte = string.byte

local function u16le(data, offset)
  return byte(data, offset + 1) + byte(data, offset + 2) * 256
end

local function u32le(data, offset)
  return byte(data, offset + 1) + byte(data, offset + 2) * 256
    + byte(data, offset + 3) * 65536 + byte(data, offset + 4) * 16777216
end

-- Purely merges an opt-in mod addition list into decoded ROM entries. The
-- caller supplies the supported move-id ceiling because this importer owns no
-- battle-move table. Base rows are never mutated or removed.
function LevelUpLearnset.mergeAdditions(base, additions, maxMoveId)
  assert(type(base) == "table", "base learnset must be an array")
  if additions == nil then return base end
  assert(type(additions) == "table", "learnset additions must be an array")
  assert(type(maxMoveId) == "number" and maxMoveId >= 1,
    "learnset additions require a supported move-id ceiling")
  for key in pairs(additions) do
    assert(type(key) == "number" and key >= 1 and key % 1 == 0 and key <= #additions,
      "learnset additions must be a contiguous 1-indexed array")
  end

  local out, seen = {}, {}
  for index, entry in ipairs(base) do
    assert(type(entry) == "table" and type(entry.level) == "number" and type(entry.move) == "number",
      "base learnset contains an invalid entry")
    local key = entry.level .. ":" .. entry.move
    assert(not seen[key], "base learnset contains duplicate entry " .. key)
    seen[key] = true
    out[#out + 1] = { level=entry.level, move=entry.move, packed=entry.packed, order=index }
  end
  for index, entry in ipairs(additions) do
    assert(type(entry) == "table" and type(entry.level) == "number" and entry.level % 1 == 0
      and entry.level >= 1 and entry.level <= 100, "learnset addition has invalid level")
    assert(type(entry.move) == "number" and entry.move % 1 == 0
      and entry.move >= 1 and entry.move <= maxMoveId, "learnset addition has invalid move")
    local key = entry.level .. ":" .. entry.move
    assert(not seen[key], "learnset addition duplicates " .. key)
    seen[key] = true
    out[#out + 1] = { level=entry.level, move=entry.move, order=#base + index }
  end
  table.sort(out, function(a, b)
    return a.level == b.level and a.order < b.order or a.level < b.level
  end)
  for _, entry in ipairs(out) do entry.order = nil end
  return out
end

-- Returns an ordered, 1-indexed list of { level, move, packed } records.
-- tableOffset is a 0-based ROM file offset; species is the real internal
-- species id and therefore also the pointer-table index.
function LevelUpLearnset.resolve(data, tableOffset, species, additions, maxMoveId)
  assert(type(data) == "string", "ROM data must be a byte string")
  assert(type(tableOffset) == "number", "learnset pointer-table offset is required")
  assert(type(species) == "number" and species >= 0, "species must be a non-negative id")

  local pointerOffset = tableOffset + species * 4
  assert(pointerOffset + 4 <= #data, "learnset pointer read ran past end of ROM")
  local pointer = u32le(data, pointerOffset)
  assert(pointer >= LevelUpLearnset.GBA_ROM_BASE,
    ("invalid learnset ROM pointer 0x%08X for species %d"):format(pointer, species))
  local cursor = pointer - LevelUpLearnset.GBA_ROM_BASE
  assert(cursor >= 0 and cursor + 2 <= #data,
    ("learnset pointer 0x%08X is outside ROM"):format(pointer))

  local out = {}
  for _ = 1, LevelUpLearnset.MAX_LEVEL_UP_MOVES + 1 do
    assert(cursor + 2 <= #data, "learnset read ran past end of ROM")
    local packed = u16le(data, cursor)
    cursor = cursor + 2
    if packed == LevelUpLearnset.LEVEL_UP_END then
      return LevelUpLearnset.mergeAdditions(out, additions, maxMoveId)
    end
    out[#out + 1] = {
      level = math.floor(packed / LevelUpLearnset.LEVEL_DIVISOR),
      move = packed % LevelUpLearnset.LEVEL_DIVISOR,
      packed = packed,
    }
    if #out > LevelUpLearnset.MAX_LEVEL_UP_MOVES then
      error(("species %d learnset exceeds real MAX_LEVEL_UP_MOVES=%d")
        :format(species, LevelUpLearnset.MAX_LEVEL_UP_MOVES))
    end
  end
  error(("species %d learnset has no LEVEL_UP_END terminator"):format(species))
end

return LevelUpLearnset
