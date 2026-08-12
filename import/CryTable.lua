-- Parses FireRed's gCryTable (struct ToneData[], pokefirered
-- include/gba/m4a_internal.h) -- extraction only. This is a GBA m4a sound
-- engine "instrument" descriptor pointing at raw waveform data; actually
-- playing audio is Phase 2/8 work, not Phase 1.
--
-- Verified against real ROM data: entries 1-3 (BULBASAUR/IVYSAUR/VENUSAUR's
-- cries by table position) all decode to type=32, key=60 (middle C,
-- plausible default pitch), and three genuinely distinct wav pointers
-- (each cry samples different waveform data) -- internally consistent
-- structured data, not garbage, confirming the struct layout is right.
--
-- Struct layout (12 bytes, no padding -- ends on a 4-byte boundary):
--   0x00 type        u8
--   0x01 key          u8
--   0x02 length       u8
--   0x03 pan_sweep   u8
--   0x04 wav           u32 LE pointer (raw -- struct WaveData*)
--   0x08 attack       u8
--   0x09 decay         u8
--   0x0A sustain      u8
--   0x0B release       u8
local CryTable = {}

CryTable.romBase = 0x08000000
CryTable.RECORD_SIZE = 12

local byte = string.byte

local function u32le(data, offset0based)
  return byte(data, offset0based + 1)
    + byte(data, offset0based + 2) * 256
    + byte(data, offset0based + 3) * 65536
    + byte(data, offset0based + 4) * 16777216
end

-- data: full ROM bytes. tableOffset: 0-based file offset of gCryTable.
-- cryId: entry index (a cry id, not necessarily 1:1 with species -- see
-- pokefirered src/data/pokemon/cry_ids.h for the species->cryId mapping).
function CryTable.resolve(data, tableOffset, cryId)
  local base = tableOffset + cryId * CryTable.RECORD_SIZE
  return {
    type = byte(data, base + 0x00 + 1),
    key = byte(data, base + 0x01 + 1),
    length = byte(data, base + 0x02 + 1),
    panSweep = byte(data, base + 0x03 + 1),
    wavPtr = u32le(data, base + 0x04),
    attack = byte(data, base + 0x08 + 1),
    decay = byte(data, base + 0x09 + 1),
    sustain = byte(data, base + 0x0A + 1),
    release = byte(data, base + 0x0B + 1),
  }
end

return CryTable
