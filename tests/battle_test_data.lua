-- Shared test fixture (NOT a test, and NOT engine code): real FireRed
-- battle data transcribed verbatim from pokefirered source so the battle
-- tests can run with no ROM present, matching this repo's no-ROM
-- contribution rule. Every value here is checked byte-for-byte against
-- the real ROM by tests/battle_engine_test.lua's opt-in POKEPORT_ROM
-- section -- if a transcription typo ever creeps in, that test fails.
--
-- Sources:
--   gTypeEffectiveness   -- src/battle_main.c:312 (111 real rows, up to
--                           but not including the ENDTABLE sentinel;
--                           row 108 is the real TYPE_FORESIGHT marker)
--   gBattleMoves entries -- src/data/battle_moves.h
--   gSpeciesInfo entries -- src/data/pokemon/species_info.h
local M = {}

-- Real type ids (include/constants/pokemon.h).
M.TYPE_NORMAL = 0
M.TYPE_FIGHTING = 1
M.TYPE_FLYING = 2
M.TYPE_POISON = 3
M.TYPE_GROUND = 4
M.TYPE_ROCK = 5
M.TYPE_BUG = 6
M.TYPE_GHOST = 7
M.TYPE_STEEL = 8
M.TYPE_MYSTERY = 9
M.TYPE_FIRE = 10
M.TYPE_WATER = 11
M.TYPE_GRASS = 12
M.TYPE_ELECTRIC = 13
M.TYPE_PSYCHIC = 14
M.TYPE_ICE = 15
M.TYPE_DRAGON = 16
M.TYPE_DARK = 17

-- Real move ids (include/constants/moves.h).
M.MOVE_TACKLE = 33
M.MOVE_SWORDS_DANCE = 14
M.MOVE_SAND_ATTACK = 28
M.MOVE_TAIL_WHIP = 39
M.MOVE_GROWL = 45
M.MOVE_EMBER = 52
M.MOVE_STRING_SHOT = 81
M.MOVE_AGILITY = 97
M.MOVE_SCREECH = 103
M.MOVE_QUICK_ATTACK = 98
M.MOVE_AMNESIA = 133
M.MOVE_ACID = 51
M.MOVE_PSYCHIC = 94
M.MOVE_STEEL_WING = 211
M.MOVE_METAL_CLAW = 232
M.MOVE_TAKE_DOWN = 36
M.MOVE_DOUBLE_EDGE = 38
M.MOVE_SUBMISSION = 66
M.MOVE_ABSORB = 71

-- Real MOVE_TARGET_* bits (include/battle.h).
M.MOVE_TARGET_SELECTED = 0
M.MOVE_TARGET_BOTH = 0x08
M.MOVE_TARGET_USER = 0x10

-- Real gBattleMoves records, keyed by real move id, in the exact shape
-- import/BattleMove.lua produces from ROM bytes.
M.moves = {
  [M.MOVE_TACKLE] = { effect = 0, power = 35, type = M.TYPE_NORMAL, accuracy = 95, pp = 35,
                      secondaryEffectChance = 0, target = 0, priority = 0, flags = 0x33 },
  [M.MOVE_EMBER] = { effect = 4, power = 40, type = M.TYPE_FIRE, accuracy = 100, pp = 25,
                     secondaryEffectChance = 10, target = 0, priority = 0, flags = 0x12 },
  -- Growl/Tail Whip: EFFECT_ATTACK_DOWN/EFFECT_DEFENSE_DOWN, real
  -- opponent-target (MOVE_TARGET_BOTH in a real single battle still
  -- resolves against the lone foe), 1-stage stat moves.
  [M.MOVE_GROWL] = { effect = 18, power = 0, type = M.TYPE_NORMAL, accuracy = 100, pp = 40,
                     secondaryEffectChance = 0, target = M.MOVE_TARGET_BOTH, priority = 0, flags = 0 },
  [M.MOVE_TAIL_WHIP] = { effect = 19, power = 0, type = M.TYPE_NORMAL, accuracy = 100, pp = 30,
                         secondaryEffectChance = 0, target = M.MOVE_TARGET_BOTH, priority = 0, flags = 0 },
  -- Swords Dance/Agility/Amnesia: real self-target (MOVE_TARGET_USER)
  -- 2-stage stat-UP moves. Real accuracy field is 0 (unused -- no
  -- accuracycheck step in their real battle script).
  [M.MOVE_SWORDS_DANCE] = { effect = 50, power = 0, type = M.TYPE_NORMAL, accuracy = 0, pp = 30,
                            secondaryEffectChance = 0, target = M.MOVE_TARGET_USER, priority = 0, flags = 0 },
  [M.MOVE_AGILITY] = { effect = 52, power = 0, type = M.TYPE_PSYCHIC, accuracy = 0, pp = 30,
                       secondaryEffectChance = 0, target = M.MOVE_TARGET_USER, priority = 0, flags = 0 },
  [M.MOVE_AMNESIA] = { effect = 54, power = 0, type = M.TYPE_PSYCHIC, accuracy = 0, pp = 20,
                       secondaryEffectChance = 0, target = M.MOVE_TARGET_USER, priority = 0, flags = 0 },
  -- Sand-Attack/Screech/String Shot: real opponent-target 1- and 2-stage
  -- stat-DOWN moves (Screech is EFFECT_DEFENSE_DOWN_2).
  [M.MOVE_SAND_ATTACK] = { effect = 23, power = 0, type = M.TYPE_GROUND, accuracy = 100, pp = 15,
                           secondaryEffectChance = 0, target = M.MOVE_TARGET_SELECTED, priority = 0, flags = 0 },
  [M.MOVE_SCREECH] = { effect = 59, power = 0, type = M.TYPE_NORMAL, accuracy = 85, pp = 40,
                       secondaryEffectChance = 0, target = M.MOVE_TARGET_SELECTED, priority = 0, flags = 0 },
  [M.MOVE_STRING_SHOT] = { effect = 20, power = 0, type = M.TYPE_BUG, accuracy = 95, pp = 40,
                           secondaryEffectChance = 0, target = M.MOVE_TARGET_BOTH, priority = 0, flags = 0 },
  [M.MOVE_QUICK_ATTACK] = { effect = 103, power = 40, type = M.TYPE_NORMAL, accuracy = 100, pp = 30,
                            secondaryEffectChance = 0, target = 0, priority = 1, flags = 0x33 },
  -- The real "_HIT" secondary-effect family (BattleEngine.HIT_VARIANT_STAT_
  -- MOVES): ordinary damaging moves with a chance to also change a stat.
  -- Acid/Psychic: opponent-target DOWN_HIT (real target field is just the
  -- ordinary damage target, not the secondary-effect direction -- see
  -- BattleEngine.lua's header). Metal Claw/Steel Wing: self-target UP_HIT.
  [M.MOVE_ACID] = { effect = 69, power = 40, type = M.TYPE_POISON, accuracy = 100, pp = 30,
                    secondaryEffectChance = 10, target = M.MOVE_TARGET_BOTH, priority = 0, flags = 0 },
  [M.MOVE_PSYCHIC] = { effect = 72, power = 90, type = M.TYPE_PSYCHIC, accuracy = 100, pp = 10,
                       secondaryEffectChance = 10, target = M.MOVE_TARGET_SELECTED, priority = 0, flags = 0 },
  [M.MOVE_STEEL_WING] = { effect = 138, power = 70, type = M.TYPE_STEEL, accuracy = 90, pp = 25,
                          secondaryEffectChance = 10, target = M.MOVE_TARGET_SELECTED, priority = 0, flags = 0 },
  [M.MOVE_METAL_CLAW] = { effect = 139, power = 50, type = M.TYPE_STEEL, accuracy = 95, pp = 35,
                          secondaryEffectChance = 10, target = M.MOVE_TARGET_SELECTED, priority = 0, flags = 0 },
  -- Recoil family (BattleEngine.RECOIL_MOVES): Take Down/Submission share
  -- real EFFECT_RECOIL=48 (25% recoil); Double-Edge is the separate real
  -- EFFECT_DOUBLE_EDGE=198 (33% recoil).
  [M.MOVE_TAKE_DOWN] = { effect = 48, power = 90, type = M.TYPE_NORMAL, accuracy = 85, pp = 20,
                        secondaryEffectChance = 0, target = M.MOVE_TARGET_SELECTED, priority = 0, flags = 0 },
  [M.MOVE_SUBMISSION] = { effect = 48, power = 80, type = M.TYPE_FIGHTING, accuracy = 80, pp = 25,
                          secondaryEffectChance = 0, target = M.MOVE_TARGET_SELECTED, priority = 0, flags = 0 },
  [M.MOVE_DOUBLE_EDGE] = { effect = 198, power = 120, type = M.TYPE_NORMAL, accuracy = 100, pp = 15,
                           secondaryEffectChance = 0, target = M.MOVE_TARGET_SELECTED, priority = 0, flags = 0 },
  -- Drain family (BattleEngine.DRAIN_MOVES): real EFFECT_ABSORB=3 (50%
  -- heal); Absorb itself.
  [M.MOVE_ABSORB] = { effect = 3, power = 20, type = M.TYPE_GRASS, accuracy = 100, pp = 20,
                      secondaryEffectChance = 0, target = M.MOVE_TARGET_SELECTED, priority = 0, flags = 0 },
}

-- Real gSpeciesInfo base stats + types.
M.BULBASAUR = { baseHP = 45, baseAttack = 49, baseDefense = 49, baseSpeed = 45,
                baseSpAttack = 65, baseSpDefense = 65, types = { M.TYPE_GRASS, M.TYPE_POISON } }
M.CHARMANDER = { baseHP = 39, baseAttack = 52, baseDefense = 43, baseSpeed = 65,
                 baseSpAttack = 60, baseSpDefense = 50, types = { M.TYPE_FIRE, M.TYPE_FIRE } }

-- Real gTypeEffectiveness rows, 0-indexed exactly like
-- import/TypeChart.lua's parseTable output.
M.typeChart = {
  [0] = { attackingType = 0  , defendingType = 5  , multiplier =  5 }, -- NORMAL vs ROCK
  [1] = { attackingType = 0  , defendingType = 8  , multiplier =  5 }, -- NORMAL vs STEEL
  [2] = { attackingType = 10 , defendingType = 10 , multiplier =  5 }, -- FIRE vs FIRE
  [3] = { attackingType = 10 , defendingType = 11 , multiplier =  5 }, -- FIRE vs WATER
  [4] = { attackingType = 10 , defendingType = 12 , multiplier = 20 }, -- FIRE vs GRASS
  [5] = { attackingType = 10 , defendingType = 15 , multiplier = 20 }, -- FIRE vs ICE
  [6] = { attackingType = 10 , defendingType = 6  , multiplier = 20 }, -- FIRE vs BUG
  [7] = { attackingType = 10 , defendingType = 5  , multiplier =  5 }, -- FIRE vs ROCK
  [8] = { attackingType = 10 , defendingType = 16 , multiplier =  5 }, -- FIRE vs DRAGON
  [9] = { attackingType = 10 , defendingType = 8  , multiplier = 20 }, -- FIRE vs STEEL
  [10] = { attackingType = 11 , defendingType = 10 , multiplier = 20 }, -- WATER vs FIRE
  [11] = { attackingType = 11 , defendingType = 11 , multiplier =  5 }, -- WATER vs WATER
  [12] = { attackingType = 11 , defendingType = 12 , multiplier =  5 }, -- WATER vs GRASS
  [13] = { attackingType = 11 , defendingType = 4  , multiplier = 20 }, -- WATER vs GROUND
  [14] = { attackingType = 11 , defendingType = 5  , multiplier = 20 }, -- WATER vs ROCK
  [15] = { attackingType = 11 , defendingType = 16 , multiplier =  5 }, -- WATER vs DRAGON
  [16] = { attackingType = 13 , defendingType = 11 , multiplier = 20 }, -- ELECTRIC vs WATER
  [17] = { attackingType = 13 , defendingType = 13 , multiplier =  5 }, -- ELECTRIC vs ELECTRIC
  [18] = { attackingType = 13 , defendingType = 12 , multiplier =  5 }, -- ELECTRIC vs GRASS
  [19] = { attackingType = 13 , defendingType = 4  , multiplier =  0 }, -- ELECTRIC vs GROUND
  [20] = { attackingType = 13 , defendingType = 2  , multiplier = 20 }, -- ELECTRIC vs FLYING
  [21] = { attackingType = 13 , defendingType = 16 , multiplier =  5 }, -- ELECTRIC vs DRAGON
  [22] = { attackingType = 12 , defendingType = 10 , multiplier =  5 }, -- GRASS vs FIRE
  [23] = { attackingType = 12 , defendingType = 11 , multiplier = 20 }, -- GRASS vs WATER
  [24] = { attackingType = 12 , defendingType = 12 , multiplier =  5 }, -- GRASS vs GRASS
  [25] = { attackingType = 12 , defendingType = 3  , multiplier =  5 }, -- GRASS vs POISON
  [26] = { attackingType = 12 , defendingType = 4  , multiplier = 20 }, -- GRASS vs GROUND
  [27] = { attackingType = 12 , defendingType = 2  , multiplier =  5 }, -- GRASS vs FLYING
  [28] = { attackingType = 12 , defendingType = 6  , multiplier =  5 }, -- GRASS vs BUG
  [29] = { attackingType = 12 , defendingType = 5  , multiplier = 20 }, -- GRASS vs ROCK
  [30] = { attackingType = 12 , defendingType = 16 , multiplier =  5 }, -- GRASS vs DRAGON
  [31] = { attackingType = 12 , defendingType = 8  , multiplier =  5 }, -- GRASS vs STEEL
  [32] = { attackingType = 15 , defendingType = 11 , multiplier =  5 }, -- ICE vs WATER
  [33] = { attackingType = 15 , defendingType = 12 , multiplier = 20 }, -- ICE vs GRASS
  [34] = { attackingType = 15 , defendingType = 15 , multiplier =  5 }, -- ICE vs ICE
  [35] = { attackingType = 15 , defendingType = 4  , multiplier = 20 }, -- ICE vs GROUND
  [36] = { attackingType = 15 , defendingType = 2  , multiplier = 20 }, -- ICE vs FLYING
  [37] = { attackingType = 15 , defendingType = 16 , multiplier = 20 }, -- ICE vs DRAGON
  [38] = { attackingType = 15 , defendingType = 8  , multiplier =  5 }, -- ICE vs STEEL
  [39] = { attackingType = 15 , defendingType = 10 , multiplier =  5 }, -- ICE vs FIRE
  [40] = { attackingType = 1  , defendingType = 0  , multiplier = 20 }, -- FIGHTING vs NORMAL
  [41] = { attackingType = 1  , defendingType = 15 , multiplier = 20 }, -- FIGHTING vs ICE
  [42] = { attackingType = 1  , defendingType = 3  , multiplier =  5 }, -- FIGHTING vs POISON
  [43] = { attackingType = 1  , defendingType = 2  , multiplier =  5 }, -- FIGHTING vs FLYING
  [44] = { attackingType = 1  , defendingType = 14 , multiplier =  5 }, -- FIGHTING vs PSYCHIC
  [45] = { attackingType = 1  , defendingType = 6  , multiplier =  5 }, -- FIGHTING vs BUG
  [46] = { attackingType = 1  , defendingType = 5  , multiplier = 20 }, -- FIGHTING vs ROCK
  [47] = { attackingType = 1  , defendingType = 17 , multiplier = 20 }, -- FIGHTING vs DARK
  [48] = { attackingType = 1  , defendingType = 8  , multiplier = 20 }, -- FIGHTING vs STEEL
  [49] = { attackingType = 3  , defendingType = 12 , multiplier = 20 }, -- POISON vs GRASS
  [50] = { attackingType = 3  , defendingType = 3  , multiplier =  5 }, -- POISON vs POISON
  [51] = { attackingType = 3  , defendingType = 4  , multiplier =  5 }, -- POISON vs GROUND
  [52] = { attackingType = 3  , defendingType = 5  , multiplier =  5 }, -- POISON vs ROCK
  [53] = { attackingType = 3  , defendingType = 7  , multiplier =  5 }, -- POISON vs GHOST
  [54] = { attackingType = 3  , defendingType = 8  , multiplier =  0 }, -- POISON vs STEEL
  [55] = { attackingType = 4  , defendingType = 10 , multiplier = 20 }, -- GROUND vs FIRE
  [56] = { attackingType = 4  , defendingType = 13 , multiplier = 20 }, -- GROUND vs ELECTRIC
  [57] = { attackingType = 4  , defendingType = 12 , multiplier =  5 }, -- GROUND vs GRASS
  [58] = { attackingType = 4  , defendingType = 3  , multiplier = 20 }, -- GROUND vs POISON
  [59] = { attackingType = 4  , defendingType = 2  , multiplier =  0 }, -- GROUND vs FLYING
  [60] = { attackingType = 4  , defendingType = 6  , multiplier =  5 }, -- GROUND vs BUG
  [61] = { attackingType = 4  , defendingType = 5  , multiplier = 20 }, -- GROUND vs ROCK
  [62] = { attackingType = 4  , defendingType = 8  , multiplier = 20 }, -- GROUND vs STEEL
  [63] = { attackingType = 2  , defendingType = 13 , multiplier =  5 }, -- FLYING vs ELECTRIC
  [64] = { attackingType = 2  , defendingType = 12 , multiplier = 20 }, -- FLYING vs GRASS
  [65] = { attackingType = 2  , defendingType = 1  , multiplier = 20 }, -- FLYING vs FIGHTING
  [66] = { attackingType = 2  , defendingType = 6  , multiplier = 20 }, -- FLYING vs BUG
  [67] = { attackingType = 2  , defendingType = 5  , multiplier =  5 }, -- FLYING vs ROCK
  [68] = { attackingType = 2  , defendingType = 8  , multiplier =  5 }, -- FLYING vs STEEL
  [69] = { attackingType = 14 , defendingType = 1  , multiplier = 20 }, -- PSYCHIC vs FIGHTING
  [70] = { attackingType = 14 , defendingType = 3  , multiplier = 20 }, -- PSYCHIC vs POISON
  [71] = { attackingType = 14 , defendingType = 14 , multiplier =  5 }, -- PSYCHIC vs PSYCHIC
  [72] = { attackingType = 14 , defendingType = 17 , multiplier =  0 }, -- PSYCHIC vs DARK
  [73] = { attackingType = 14 , defendingType = 8  , multiplier =  5 }, -- PSYCHIC vs STEEL
  [74] = { attackingType = 6  , defendingType = 10 , multiplier =  5 }, -- BUG vs FIRE
  [75] = { attackingType = 6  , defendingType = 12 , multiplier = 20 }, -- BUG vs GRASS
  [76] = { attackingType = 6  , defendingType = 1  , multiplier =  5 }, -- BUG vs FIGHTING
  [77] = { attackingType = 6  , defendingType = 3  , multiplier =  5 }, -- BUG vs POISON
  [78] = { attackingType = 6  , defendingType = 2  , multiplier =  5 }, -- BUG vs FLYING
  [79] = { attackingType = 6  , defendingType = 14 , multiplier = 20 }, -- BUG vs PSYCHIC
  [80] = { attackingType = 6  , defendingType = 7  , multiplier =  5 }, -- BUG vs GHOST
  [81] = { attackingType = 6  , defendingType = 17 , multiplier = 20 }, -- BUG vs DARK
  [82] = { attackingType = 6  , defendingType = 8  , multiplier =  5 }, -- BUG vs STEEL
  [83] = { attackingType = 5  , defendingType = 10 , multiplier = 20 }, -- ROCK vs FIRE
  [84] = { attackingType = 5  , defendingType = 15 , multiplier = 20 }, -- ROCK vs ICE
  [85] = { attackingType = 5  , defendingType = 1  , multiplier =  5 }, -- ROCK vs FIGHTING
  [86] = { attackingType = 5  , defendingType = 4  , multiplier =  5 }, -- ROCK vs GROUND
  [87] = { attackingType = 5  , defendingType = 2  , multiplier = 20 }, -- ROCK vs FLYING
  [88] = { attackingType = 5  , defendingType = 6  , multiplier = 20 }, -- ROCK vs BUG
  [89] = { attackingType = 5  , defendingType = 8  , multiplier =  5 }, -- ROCK vs STEEL
  [90] = { attackingType = 7  , defendingType = 0  , multiplier =  0 }, -- GHOST vs NORMAL
  [91] = { attackingType = 7  , defendingType = 14 , multiplier = 20 }, -- GHOST vs PSYCHIC
  [92] = { attackingType = 7  , defendingType = 17 , multiplier =  5 }, -- GHOST vs DARK
  [93] = { attackingType = 7  , defendingType = 8  , multiplier =  5 }, -- GHOST vs STEEL
  [94] = { attackingType = 7  , defendingType = 7  , multiplier = 20 }, -- GHOST vs GHOST
  [95] = { attackingType = 16 , defendingType = 16 , multiplier = 20 }, -- DRAGON vs DRAGON
  [96] = { attackingType = 16 , defendingType = 8  , multiplier =  5 }, -- DRAGON vs STEEL
  [97] = { attackingType = 17 , defendingType = 1  , multiplier =  5 }, -- DARK vs FIGHTING
  [98] = { attackingType = 17 , defendingType = 14 , multiplier = 20 }, -- DARK vs PSYCHIC
  [99] = { attackingType = 17 , defendingType = 7  , multiplier = 20 }, -- DARK vs GHOST
  [100] = { attackingType = 17 , defendingType = 17 , multiplier =  5 }, -- DARK vs DARK
  [101] = { attackingType = 17 , defendingType = 8  , multiplier =  5 }, -- DARK vs STEEL
  [102] = { attackingType = 8  , defendingType = 10 , multiplier =  5 }, -- STEEL vs FIRE
  [103] = { attackingType = 8  , defendingType = 11 , multiplier =  5 }, -- STEEL vs WATER
  [104] = { attackingType = 8  , defendingType = 13 , multiplier =  5 }, -- STEEL vs ELECTRIC
  [105] = { attackingType = 8  , defendingType = 15 , multiplier = 20 }, -- STEEL vs ICE
  [106] = { attackingType = 8  , defendingType = 5  , multiplier = 20 }, -- STEEL vs ROCK
  [107] = { attackingType = 8  , defendingType = 8  , multiplier =  5 }, -- STEEL vs STEEL
  [108] = { attackingType = 254, defendingType = 254, multiplier =  0 }, -- FORESIGHT vs FORESIGHT
  [109] = { attackingType = 0  , defendingType = 7  , multiplier =  0 }, -- NORMAL vs GHOST
  [110] = { attackingType = 1  , defendingType = 7  , multiplier =  0 }, -- FIGHTING vs GHOST
}

return M
