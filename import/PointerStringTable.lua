-- Resolves a "const u8 *const table[N]" array -- a flat array of pointers,
-- each pointing to a charmap-encoded, 0xFF-terminated string. Several
-- FireRed name/description tables are shaped this way (gAbilityDescriptionPointers,
-- gNatureNamePointers, ...), unlike the fixed-stride tables SpeciesInfo/
-- AbilityNames/etc. use.
--
-- Verified against real ROM data: gAbilityDescriptionPointers[ABILITY_STENCH]
-- decodes via Charmap to exactly "Helps repel wild POKéMON." -- matching
-- pokefirered src/data/text/abilities.h's sStenchDescription verbatim,
-- including the accented é (charmap byte 0x06), confirming both the
-- pointer resolution and Charmap's non-ASCII handling are correct together.

local Charmap = require("import.Charmap")

local PointerStringTable = {}

PointerStringTable.romBase = 0x08000000

local byte = string.byte

local function u32le(data, offset0based)
  return byte(data, offset0based + 1)
    + byte(data, offset0based + 2) * 256
    + byte(data, offset0based + 3) * 65536
    + byte(data, offset0based + 4) * 16777216
end

-- data: full ROM bytes. tableOffset: 0-based file offset of the pointer
-- array. index: which entry to resolve. maxLength: safety cap on how many
-- bytes to scan for the terminator (charmap-encoded strings have no fixed
-- length here, unlike the fixed-stride name tables).
function PointerStringTable.resolveAt(data, tableOffset, index, maxLength)
  maxLength = maxLength or 256
  local ptr = u32le(data, tableOffset + index * 4)
  if ptr == 0 then return nil end
  local strOffset = ptr - PointerStringTable.romBase
  local raw = data:sub(strOffset + 1, strOffset + maxLength)
  return Charmap.decode(raw)
end

return PointerStringTable
