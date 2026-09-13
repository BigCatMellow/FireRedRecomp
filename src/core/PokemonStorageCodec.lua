-- Codec for FireRed's real `struct PokemonStorage`
-- (include/pokemon_storage_system.h).  This is deliberately separate from
-- SaveFileCodec: the latter owns sectors 5-13, while this module owns only
-- the 0x83D0-byte in-RAM structure those sectors concatenate.
--
-- Layout, transcribed from the source header:
--   0x0000  u8 currentBox (real 0-based index)
--   0x0001  BoxPokemon boxes[14][30] (80 bytes each)
--   0x8344  u8 boxNames[14][9]
--   0x83C2  u8 boxWallpapers[14]
--   0x83D0  end (three trailing alignment bytes)
--
-- The public bridge intentionally uses this project's 1-based PcBoxes
-- conventions. Empty slots remain nil in Lua and are written as the real
-- all-zero BoxPokemon representation.

local PcBoxes = require("src.core.PcBoxes")

local PokemonStorageCodec = {}

PokemonStorageCodec.BOX_MON_SIZE = 80
PokemonStorageCodec.BOX_NAME_SIZE = 9
PokemonStorageCodec.BOXES_OFFSET = 0x0001
PokemonStorageCodec.BOX_NAMES_OFFSET = 0x8344
PokemonStorageCodec.WALLPAPERS_OFFSET = 0x83C2
PokemonStorageCodec.SIZE = 0x83D0

local function padded(value, size)
  value = value or ""
  return (value .. string.rep("\0", size)):sub(1, size)
end

function PokemonStorageCodec.new()
  return {
    currentBox = 1,
    boxes = PcBoxes.new(),
    boxNames = {},
    boxWallpapers = {},
  }
end

function PokemonStorageCodec.encode(storage)
  storage = storage or PokemonStorageCodec.new()
  local boxes = assert(storage.boxes, "PokemonStorage needs a PcBoxes instance")
  local currentBox = math.max(1, math.min(PcBoxes.TOTAL_BOXES_COUNT, storage.currentBox or 1))
  local out = {}
  for i = 1, PokemonStorageCodec.SIZE do out[i] = "\0" end
  out[1] = string.char(currentBox - 1) -- real storage uses 0-based box ids.

  for box = 1, PcBoxes.TOTAL_BOXES_COUNT do
    for slot = 1, PcBoxes.IN_BOX_COUNT do
      local record = boxes:get(box, slot)
      local blob = padded(record and record.box, PokemonStorageCodec.BOX_MON_SIZE)
      local offset = PokemonStorageCodec.BOXES_OFFSET
        + ((box - 1) * PcBoxes.IN_BOX_COUNT + (slot - 1)) * PokemonStorageCodec.BOX_MON_SIZE
      for i = 1, PokemonStorageCodec.BOX_MON_SIZE do out[offset + i] = blob:sub(i, i) end
    end
    local name = padded((storage.boxNames or {})[box], PokemonStorageCodec.BOX_NAME_SIZE)
    local nameOffset = PokemonStorageCodec.BOX_NAMES_OFFSET + (box - 1) * PokemonStorageCodec.BOX_NAME_SIZE
    for i = 1, PokemonStorageCodec.BOX_NAME_SIZE do out[nameOffset + i] = name:sub(i, i) end
    out[PokemonStorageCodec.WALLPAPERS_OFFSET + box] = string.char(((storage.boxWallpapers or {})[box] or 0) % 256)
  end
  return table.concat(out)
end

function PokemonStorageCodec.decode(bytes)
  assert(#bytes == PokemonStorageCodec.SIZE,
    ("PokemonStorage bytes must be %d bytes, got %d"):format(PokemonStorageCodec.SIZE, #bytes))
  local storage = PokemonStorageCodec.new()
  storage.currentBox = math.max(1, math.min(PcBoxes.TOTAL_BOXES_COUNT, bytes:byte(1) + 1))
  local zeroBlob = string.rep("\0", PokemonStorageCodec.BOX_MON_SIZE)
  for box = 1, PcBoxes.TOTAL_BOXES_COUNT do
    for slot = 1, PcBoxes.IN_BOX_COUNT do
      local offset = PokemonStorageCodec.BOXES_OFFSET
        + ((box - 1) * PcBoxes.IN_BOX_COUNT + (slot - 1)) * PokemonStorageCodec.BOX_MON_SIZE
      local blob = bytes:sub(offset + 1, offset + PokemonStorageCodec.BOX_MON_SIZE)
      if blob ~= zeroBlob then assert(storage.boxes:add(box, { box=blob })) end
    end
    local nameOffset = PokemonStorageCodec.BOX_NAMES_OFFSET + (box - 1) * PokemonStorageCodec.BOX_NAME_SIZE
    storage.boxNames[box] = bytes:sub(nameOffset + 1, nameOffset + PokemonStorageCodec.BOX_NAME_SIZE)
    storage.boxWallpapers[box] = bytes:byte(PokemonStorageCodec.WALLPAPERS_OFFSET + box)
  end
  return storage
end

return PokemonStorageCodec
