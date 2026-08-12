-- Parses FireRed's sNatureStatTable (pokefirered src/pokemon.c) -- the
-- +10%/-10% stat modifier each of the 25 natures applies. This table is
-- `static`, so unlike every other table this project has decoded so far,
-- it has no exported name in the linker `.map` (only global symbols end up
-- there). Found instead via the full ELF symbol table -- `arm-none-eabi-nm
-- pokefirered.elf | grep sNatureStatTable` -- which does list local/static
-- symbols with their address.
--
-- Verified against real ROM data: rows 0-3 decode to exactly
-- NATURE_HARDY {0,0,0,0,0}, NATURE_LONELY {+1,-1,0,0,0}, NATURE_BRAVE
-- {+1,0,-1,0,0}, NATURE_ADAMANT {+1,0,0,-1,0} -- matching the source table
-- in src/pokemon.c exactly.
--
-- Layout: NUM_NATURES=25 rows x NUM_NATURE_STATS=5 signed bytes each
-- (attack, defense, speed, spAttack, spDefense -- HP is never affected by
-- nature). No padding: s8[5] rows pack back-to-back with no alignment
-- gap, confirmed by rows 1-3 decoding correctly at a plain 5-byte stride.

local Nature = {}

Nature.NUM_NATURES = 25
Nature.NUM_NATURE_STATS = 5
Nature.ROW_SIZE = Nature.NUM_NATURE_STATS

local byte = string.byte

local function s8(b)
  if b >= 128 then return b - 256 end
  return b
end

-- data: full ROM bytes. tableOffset: 0-based file offset of sNatureStatTable.
-- Returns a 0-indexed array of { attack, defense, speed, spAttack, spDefense },
-- each -1, 0, or +1.
function Nature.parseTable(data, tableOffset)
  local out = {}
  for n = 0, Nature.NUM_NATURES - 1 do
    local base = tableOffset + n * Nature.ROW_SIZE
    out[n] = {
      attack = s8(byte(data, base + 1)),
      defense = s8(byte(data, base + 2)),
      speed = s8(byte(data, base + 3)),
      spAttack = s8(byte(data, base + 4)),
      spDefense = s8(byte(data, base + 5)),
    }
  end
  return out
end

return Nature
