-- Parses FireRed's Pokédex browsing-order tables (gPokedexOrder_Alphabetical/
-- _Weight/_Height/_Type, pokefirered src/data/pokemon/pokedex_orders.h) and
-- the species→National Dex number mapping (sSpeciesToNationalPokedexNum,
-- pokefirered src/pokemon.c). All are flat u16 arrays; no padding.
--
-- Verified against real ROM data:
--   * gPokedexOrder_Alphabetical: entry 0 decodes to 387, exactly
--     NATIONAL_DEX_OLD_UNOWN_B (the Unown letters sort before real species
--     alphabetically); entry 25 decodes to 63, exactly NATIONAL_DEX_ABRA
--     (the first non-Unown entry, matching the source array's declared
--     order in pokedex_orders.h).
--   * sSpeciesToNationalPokedexNum: species 1-5 (Bulbasaur..Charmeleon) all
--     map to national dex numbers 1-5 -- the original 151 keep matching
--     SPECIES_*/NATIONAL_DEX_* numbers in FireRed by design.
--   * Real symbol sizes confirmed via `arm-none-eabi-nm -S`:
--     gPokedexOrder_Alphabetical is 0x336 bytes = exactly 411 u16 entries
--     (matching NATIONAL_DEX_COUNT-adjacent species count including the
--     old Unown letter forms).

local PokedexOrder = {}

PokedexOrder.NATIONAL_DEX_COUNT = 411 -- verified array length, see above

local byte = string.byte

local function u16le(data, offset0based)
  return byte(data, offset0based + 1) + byte(data, offset0based + 2) * 256
end

-- data: full ROM bytes. tableOffset: 0-based file offset of one of the
-- gPokedexOrder_* arrays. Returns a 0-indexed array of NATIONAL_DEX_* ids,
-- length PokedexOrder.NATIONAL_DEX_COUNT.
function PokedexOrder.parseOrderTable(data, tableOffset)
  local out = {}
  for i = 0, PokedexOrder.NATIONAL_DEX_COUNT - 1 do
    out[i] = u16le(data, tableOffset + i * 2)
  end
  return out
end

-- data: full ROM bytes. tableOffset: 0-based file offset of
-- sSpeciesToNationalPokedexNum. species: a SPECIES_* id (1-based).
-- Returns the National Dex number, or 0 for SPECIES_NONE (species=0),
-- matching SpeciesToNationalPokedexNum's own species==0 special case.
function PokedexOrder.speciesToNationalDexNum(data, tableOffset, species)
  if species == 0 then return 0 end
  return u16le(data, tableOffset + (species - 1) * 2)
end

return PokedexOrder
