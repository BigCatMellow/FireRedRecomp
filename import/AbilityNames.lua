-- Parses FireRed's gAbilityNames table: a fixed-stride array of
-- charmap-encoded strings (ABILITY_NAME_LENGTH+1 = 13 bytes each,
-- pokefirered include/battle_main.h), terminated with the charmap's 0xFF
-- string-end byte and zero-padded after that.
--
-- Text isn't decoded here -- FireRed uses a custom charmap, not ASCII, and
-- that decoder doesn't exist yet (see PARITY_CONTRACT.md / roadmap Phase 1
-- "messages/text"). This just slices out the right raw bytes so decoding
-- can be plugged in later without re-deriving offsets.
--
-- Verified against real ROM data: index 0 (ABILITY_NONE) is seven 0xAE
-- bytes then 0xFF (FireRed's placeholder dash character, "-------");
-- index 1 (ABILITY_STENCH) is 6 charmap bytes + 0xFF, the right length for
-- "STENCH".
local RECORD_SIZE = 13

local AbilityNames = {}
AbilityNames.RECORD_SIZE = RECORD_SIZE
AbilityNames.STRING_TERMINATOR = 0xFF

-- Returns the raw charmap bytes up to (not including) the 0xFF terminator,
-- or the full record if no terminator is found within it.
function AbilityNames.rawNameRecord(data, tableOffset, index)
  local start = tableOffset + index * RECORD_SIZE
  local record = data:sub(start + 1, start + RECORD_SIZE)
  if #record < RECORD_SIZE then
    error(("ability name table read ran past end of data at index %d"):format(index))
  end
  local terminatorPos = record:find(string.char(AbilityNames.STRING_TERMINATOR))
  if terminatorPos then
    return record:sub(1, terminatorPos - 1)
  end
  return record
end

function AbilityNames.parseTable(data, tableOffset, count)
  local out = {}
  for i = 0, count - 1 do
    out[i] = AbilityNames.rawNameRecord(data, tableOffset, i)
  end
  return out
end

return AbilityNames
