-- ROM addresses of data tables, keyed by the SHA-1 RomImporter.verify()
-- already reports. These only exist for a *linked* ROM, not the decomp
-- source tree, so each entry here was read out of a real pokefirered.map
-- produced by building pokefirered-master locally (see PARITY_CONTRACT.md /
-- the memory note on the unprivileged build toolchain) and then confirmed
-- by decoding a few known records (Bulbasaur/Ivysaur/Venusaur/Charmander
-- base stats) out of the actual built ROM with SpeciesInfo.parseTable and
-- checking them against known values.
--
-- GBA ROM addresses are memory-mapped starting at 0x08000000; the .gba file
-- offset is address - 0x08000000.

local RomAddresses = {}

RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"] = { -- FireRed (US) v1.0
  -- gSpeciesInfo: struct SpeciesInfo[NUM_SPECIES], pokefirered src/data/pokemon/species_info.h
  gSpeciesInfo = 0x08254784 - 0x08000000,
  -- gBattleMoves: struct BattleMove[MOVES_COUNT], pokefirered src/data/battle_moves.h
  -- Verified against real Pound (index 1) / Karate Chop (index 2) data.
  gBattleMoves = 0x08250c04 - 0x08000000,
  -- gTypeEffectiveness: flat (atkType,defType,mult) byte triples, pokefirered src/battle_main.c
  gTypeEffectiveness = 0x0824f050 - 0x08000000,
  -- gItems: struct Item[], pokefirered src/data/items.h
  -- Verified against real Master Ball (index 1) / Ultra Ball (index 2) data.
  gItems = 0x083db028 - 0x08000000,
  -- gAbilityNames: fixed-stride charmap string table, pokefirered src/data/text/abilities.h
  -- Verified against real ABILITY_NONE (index 0) / ABILITY_STENCH (index 1) data.
  gAbilityNames = 0x0824fc40 - 0x08000000,
  -- gSpeciesNames: fixed-stride (POKEMON_NAME_LENGTH+1 = 11 bytes) charmap
  -- string table, pokefirered src/data/text/species_names.h
  -- Verified against real BULBASAUR/IVYSAUR/VENUSAUR/CHARMANDER data.
  gSpeciesNames = 0x08245ee0 - 0x08000000,
  -- gTrainers: struct Trainer[], pokefirered src/data/trainers.h
  -- Verified against real TRAINER_YOUNGSTER_BEN (index 89) data.
  gTrainers = 0x0823eac8 - 0x08000000,
}

return RomAddresses
