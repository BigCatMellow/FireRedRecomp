-- Run: lua5.1 tests/battle_protection_p1_test.lua
--
-- Protection slice P1 (work/tasks/phase4-protection-p1.md): the per-turn
-- `protected` flag and the attackcanceler / accuracycheck protect check,
-- applied to every admitted family. Nothing sets the flag outside tests
-- until P2 (decision D2): these tests set it directly, or through a hook that
-- sets it just before the attacker's action inside runTurn (where P2's
-- Protect will have set it). Oracles come from pret/pokefirered
-- c75f352304d529f6ba92d4f74b9cf8b5c3810788:
--   * DEFENDER_IS_PROTECTED src/battle_script_commands.c:42 (protected &&
--     FLAG_PROTECT_AFFECTED, bit 1, include/constants/pokemon.h:239);
--   * Cmd_attackcanceler :896-905 (!IsTwoTurnsMove || MULTIPLETURNS ->
--     CancelMultiTurnMoves, MISSED, MISS_TYPE = B_MSG_PROTECTED, continue);
--   * Cmd_accuracycheck :1003-1105 (JumpIfMoveAffectedByProtect first: no
--     Random(), no CheckWonderGuardAndLevitate);
--   * Cmd_resultmessage :1937 (MISSED && (!DOESNT_AFFECT_FOE || MISS_TYPE >
--     B_MSG_AVOIDED_ATK)): "It doesn't affect" wins over "protected";
--   * gMissStringIds[B_MSG_PROTECTED] src/battle_message.c:897 ->
--     "{B_DEF_NAME_WITH_PREFIX}\nprotected itself!" (:66);
--   * the per-family scripts in data/battle_scripts_1.s cited per row.
-- Move records are transcribed from src/data/battle_moves.h at the pin
-- (line numbers per record): rec(effect, power, type, accuracy, pp, chance,
-- target, priority, flags). Every expected number is worked from those
-- formulas, never read back from the engine.
package.path = package.path .. ";./?.lua"

local BattleEngine = require("src.core.BattleEngine")
local BattleSceneController = require("src.core.BattleSceneController")
local S = require("src.core.StatusConditions")
local Data = require("tests.battle_test_data")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local function scriptedRng(values)
  return {
    draws = 0,
    next16 = function(self)
      self.draws = self.draws + 1
      return values[self.draws] or 0
    end,
  }
end

local function rec(effect, power, type_, acc, pp, chance, target, priority, flags)
  return { effect = effect, power = power, type = type_, accuracy = acc, pp = pp,
    secondaryEffectChance = chance, target = target, priority = priority, flags = flags }
end

-- src/data/battle_moves.h at the pin.
local RECORDS = {
  [33] = rec(0, 35, 0, 95, 35, 0, 0x00, 0, 0x33), -- TACKLE :432 EFFECT_HIT
  [40] = rec(2, 15, 3, 100, 35, 30, 0x00, 0, 0x12), -- POISON_STING :523 EFFECT_POISON_HIT
  [52] = rec(4, 40, 10, 100, 25, 10, 0x00, 0, 0x12), -- EMBER :679 EFFECT_BURN_HIT
  [58] = rec(5, 95, 15, 100, 10, 10, 0x00, 0, 0x12), -- ICE_BEAM :757 EFFECT_FREEZE_HIT
  [84] = rec(6, 40, 13, 100, 30, 10, 0x00, 0, 0x12), -- THUNDER_SHOCK :1095 EFFECT_PARALYZE_HIT
  [44] = rec(31, 60, 17, 100, 25, 30, 0x00, 0, 0x13), -- BITE :575 EFFECT_FLINCH_HIT
  [161] = rec(36, 80, 0, 100, 10, 20, 0x00, 0, 0x12), -- TRI_ATTACK :2096 EFFECT_TRI_ATTACK
  [2] = rec(43, 50, 1, 100, 25, 0, 0x00, 0, 0x33), -- KARATE_CHOP :29 EFFECT_HIGH_CRITICAL
  [62] = rec(68, 65, 15, 100, 20, 10, 0x00, 0, 0x12), -- AURORA_BEAM :809 EFFECT_ATTACK_DOWN_HIT
  [93] = rec(76, 50, 14, 100, 25, 10, 0x00, 0, 0x12), -- CONFUSION :1212 EFFECT_CONFUSE_HIT
  [98] = rec(103, 40, 0, 100, 30, 0, 0x00, 1, 0x33), -- QUICK_ATTACK :1277 EFFECT_QUICK_ATTACK
  [172] = rec(125, 60, 10, 100, 25, 10, 0x00, 0, 0x13), -- FLAME_WHEEL :2239 EFFECT_THAW_HIT
  [211] = rec(138, 70, 8, 90, 25, 10, 0x00, 0, 0x33), -- STEEL_WING :2746 EFFECT_DEFENSE_UP_HIT
  [232] = rec(139, 50, 8, 95, 35, 10, 0x00, 0, 0x13), -- METAL_CLAW :3019 EFFECT_ATTACK_UP_HIT
  [246] = rec(140, 60, 5, 100, 5, 10, 0x00, 0, 0x13), -- ANCIENT_POWER :3201 EFFECT_ALL_STATS_UP_HIT
  [239] = rec(146, 40, 16, 100, 20, 20, 0x08, 0, 0x32), -- TWISTER :3110 EFFECT_TWISTER
  [16] = rec(149, 40, 2, 100, 35, 0, 0x00, 0, 0x32), -- GUST :211 EFFECT_GUST
  [23] = rec(150, 65, 0, 100, 20, 30, 0x00, 0, 0x13), -- STOMP :302 EFFECT_FLINCH_MINIMIZE_HIT
  [87] = rec(152, 120, 13, 70, 10, 30, 0x00, 0, 0x12), -- THUNDER :1134 EFFECT_THUNDER
  [263] = rec(169, 70, 0, 100, 20, 0, 0x00, 0, 0x13), -- FACADE :3422 EFFECT_FACADE
  [265] = rec(171, 60, 0, 100, 10, 0, 0x00, 0, 0x13), -- SMELLING_SALT :3448 EFFECT_SMELLINGSALT
  [276] = rec(182, 120, 1, 100, 5, 0, 0x00, 0, 0x13), -- SUPERPOWER :3591 EFFECT_SUPERPOWER
  [299] = rec(200, 85, 10, 90, 10, 10, 0x00, 0, 0x13), -- BLAZE_KICK :3890 EFFECT_BLAZE_KICK
  [305] = rec(202, 50, 3, 100, 15, 30, 0x00, 0, 0x13), -- POISON_FANG :3968 EFFECT_POISON_FANG
  [311] = rec(203, 50, 0, 100, 10, 0, 0x00, 0, 0x32), -- WEATHER_BALL :4046 EFFECT_WEATHER_BALL
  [315] = rec(204, 140, 10, 90, 5, 100, 0x00, 0, 0x33), -- OVERHEAT :4098 EFFECT_OVERHEAT
  [327] = rec(207, 85, 1, 90, 15, 0, 0x00, 0, 0x33), -- SKY_UPPERCUT :4254 EFFECT_SKY_UPPERCUT
  [342] = rec(209, 50, 3, 100, 25, 10, 0x00, 0, 0x33), -- POISON_TAIL :4449 EFFECT_POISON_TAIL
  [129] = rec(17, 60, 0, 0, 20, 0, 0x08, 0, 0x32), -- SWIFT :1680 EFFECT_ALWAYS_HIT
  [233] = rec(78, 70, 1, 100, 10, 0, 0x00, -1, 0x33), -- VITAL_THROW :3032 EFFECT_VITAL_THROW
  [206] = rec(101, 40, 0, 100, 40, 0, 0x00, 0, 0x33), -- FALSE_SWIPE :2681 EFFECT_FALSE_SWIPE
  [175] = rec(99, 1, 0, 100, 15, 0, 0x00, 0, 0x33), -- FLAIL :2278 EFFECT_FLAIL
  [284] = rec(190, 150, 10, 100, 5, 0, 0x08, 0, 0x32), -- ERUPTION :3695 EFFECT_ERUPTION
  [229] = rec(129, 20, 0, 100, 40, 0, 0x00, 0, 0x33), -- RAPID_SPIN :2980 EFFECT_RAPID_SPIN
  [280] = rec(186, 75, 1, 100, 15, 0, 0x00, 0, 0x33), -- BRICK_BREAK :3643 EFFECT_BRICK_BREAK
  [35] = rec(42, 15, 0, 85, 20, 100, 0x00, 0, 0x33), -- WRAP :458 EFFECT_TRAP
  [36] = rec(48, 90, 0, 85, 20, 0, 0x00, 0, 0x33), -- TAKE_DOWN :471 EFFECT_RECOIL
  [38] = rec(198, 120, 0, 100, 15, 0, 0x00, 0, 0x33), -- DOUBLE_EDGE :497 EFFECT_DOUBLE_EDGE
  [165] = rec(48, 50, 0, 100, 1, 0, 0x00, 0, 0x33), -- STRUGGLE :2148 EFFECT_RECOIL
  [71] = rec(3, 20, 12, 100, 20, 0, 0x00, 0, 0x12), -- ABSORB :926 EFFECT_ABSORB
  [63] = rec(80, 150, 0, 90, 5, 0, 0x00, 0, 0x32), -- HYPER_BEAM :822 EFFECT_RECHARGE
  [3] = rec(29, 15, 0, 85, 10, 0, 0x00, 0, 0x33), -- DOUBLE_SLAP :42 EFFECT_MULTI_HIT
  [24] = rec(44, 30, 1, 100, 30, 0, 0x00, 0, 0x33), -- DOUBLE_KICK :315 EFFECT_DOUBLE_HIT
  [41] = rec(77, 25, 6, 100, 20, 20, 0x00, 0, 0x12), -- TWINEEDLE :536 EFFECT_TWINEEDLE
  [162] = rec(40, 1, 0, 90, 10, 0, 0x00, 0, 0x13), -- SUPER_FANG :2109 EFFECT_SUPER_FANG
  [82] = rec(41, 1, 16, 100, 10, 0, 0x00, 0, 0x32), -- DRAGON_RAGE :1069 EFFECT_DRAGON_RAGE
  [49] = rec(130, 1, 0, 90, 20, 0, 0x00, 0, 0x32), -- SONIC_BOOM :640 EFFECT_SONICBOOM
  [101] = rec(87, 1, 7, 100, 15, 0, 0x00, 0, 0x32), -- NIGHT_SHADE :1316 EFFECT_LEVEL_DAMAGE
  [149] = rec(88, 1, 14, 80, 15, 0, 0x00, 0, 0x32), -- PSYWAVE :1940 EFFECT_PSYWAVE
  [90] = rec(38, 1, 4, 30, 5, 0, 0x00, 0, 0x12), -- FISSURE :1173 EFFECT_OHKO
  [45] = rec(18, 0, 0, 100, 40, 0, 0x08, 0, 0x16), -- GROWL :588 EFFECT_ATTACK_DOWN
  [103] = rec(59, 0, 0, 85, 40, 0, 0x00, 0, 0x16), -- SCREECH :1342 EFFECT_DEFENSE_DOWN_2
  [167] = rec(104, 10, 1, 90, 10, 0, 0x00, 0, 0x33), -- TRIPLE_KICK :2174 EFFECT_TRIPLE_KICK
  [207] = rec(118, 0, 0, 90, 15, 100, 0x00, 0, 0x16), -- SWAGGER :2694 EFFECT_SWAGGER
  [260] = rec(166, 0, 17, 100, 15, 0, 0x00, 0, 0x16), -- FLATTER :3383 EFFECT_FLATTER
  [37] = rec(27, 90, 0, 100, 20, 100, 0x04, 0, 0x33), -- THRASH :484 EFFECT_RAMPAGE
  [252] = rec(158, 40, 0, 100, 10, 0, 0x00, 1, 0x12), -- FAKE_OUT :3279 EFFECT_FAKE_OUT
  [264] = rec(170, 150, 1, 100, 20, 0, 0x00, -3, 0x03), -- FOCUS_PUNCH :3435 EFFECT_FOCUS_PUNCH
  [222] = rec(126, 1, 4, 100, 30, 0, 0x20, 0, 0x32), -- MAGNITUDE :2889 EFFECT_MAGNITUDE
  [89] = rec(147, 100, 4, 100, 10, 0, 0x20, 0, 0x32), -- EARTHQUAKE :1160 EFFECT_EARTHQUAKE
  [95] = rec(1, 0, 14, 60, 20, 0, 0x00, 0, 0x16), -- HYPNOSIS :1238 EFFECT_SLEEP
  [77] = rec(66, 0, 3, 75, 35, 0, 0x00, 0, 0x16), -- POISON_POWDER :1004 EFFECT_POISON
  [86] = rec(67, 0, 13, 100, 20, 0, 0x00, 0, 0x16), -- THUNDER_WAVE :1121 EFFECT_PARALYZE
  [92] = rec(33, 0, 3, 85, 10, 100, 0x00, 0, 0x16), -- TOXIC :1199 EFFECT_TOXIC
  [261] = rec(167, 0, 10, 75, 15, 0, 0x00, 0, 0x16), -- WILL_O_WISP :3396 EFFECT_WILL_O_WISP
  [109] = rec(49, 0, 7, 100, 10, 0, 0x00, 0, 0x16), -- CONFUSE_RAY :1420 EFFECT_CONFUSE
  [298] = rec(199, 0, 0, 100, 20, 0, 0x20, 0, 0x02), -- TEETER_DANCE :3877 EFFECT_TEETER_DANCE
  [321] = rec(205, 0, 0, 100, 20, 0, 0x00, 0, 0x36), -- TICKLE :4176 EFFECT_TICKLE
  [220] = rec(91, 0, 0, 100, 20, 0, 0x00, 0, 0x12), -- PAIN_SPLIT :2863 EFFECT_PAIN_SPLIT
  [212] = rec(106, 0, 0, 100, 5, 0, 0x00, 0, 0x16), -- MEAN_LOOK :2759 EFFECT_MEAN_LOOK
  [73] = rec(84, 0, 12, 90, 10, 0, 0x00, 0, 0x16), -- LEECH_SEED :952 EFFECT_LEECH_SEED
  [171] = rec(107, 0, 7, 100, 15, 0, 0x00, 0, 0x12), -- NIGHTMARE :2226 EFFECT_NIGHTMARE
  [262] = rec(168, 0, 17, 100, 10, 0, 0x00, 0, 0x12), -- MEMENTO :3409 EFFECT_MEMENTO
  [120] = rec(7, 200, 0, 100, 5, 0, 0x20, 0, 0x32), -- SELF_DESTRUCT :1563 EFFECT_EXPLOSION
  [26] = rec(45, 70, 1, 95, 25, 0, 0x00, 0, 0x33), -- JUMP_KICK :341 EFFECT_RECOIL_IF_MISS
  [136] = rec(45, 85, 1, 90, 20, 0, 0x00, 0, 0x33), -- HI_JUMP_KICK :1771 EFFECT_RECOIL_IF_MISS
  [283] = rec(189, 1, 0, 100, 5, 0, 0x00, 0, 0x33), -- ENDEAVOR :3682 EFFECT_ENDEAVOR
  [173] = rec(92, 40, 0, 100, 15, 30, 0x00, 0, 0x32), -- SNORE :2252 EFFECT_SNORE
  [174] = rec(109, 0, 9, 0, 10, 0, 0x00, 0, 0x00), -- CURSE :2265 EFFECT_CURSE
  [244] = rec(143, 0, 0, 0, 10, 0, 0x00, 0, 0x08), -- PSYCH_UP :3175 EFFECT_PSYCH_UP
  [114] = rec(25, 0, 15, 0, 30, 0, 0x10, 0, 0x02), -- HAZE :1485 EFFECT_HAZE
  [258] = rec(164, 0, 15, 0, 10, 0, 0x10, 0, 0x02), -- HAIL :3357 EFFECT_HAIL
  [14] = rec(50, 0, 0, 0, 30, 0, 0x10, 0, 0x08), -- SWORDS_DANCE :185 EFFECT_ATTACK_UP_2
  [115] = rec(65, 0, 14, 0, 20, 0, 0x10, 0, 0x08), -- REFLECT :1498 EFFECT_REFLECT
  [240] = rec(136, 0, 11, 0, 5, 0, 0x10, 0, 0x00), -- RAIN_DANCE :3123 EFFECT_RAIN_DANCE
  [105] = rec(32, 0, 0, 0, 20, 0, 0x10, 0, 0x08), -- RECOVER :1368 EFFECT_RESTORE_HP
  [208] = rec(157, 0, 0, 0, 10, 0, 0x10, 0, 0x0A), -- MILK_DRINK :2707 EFFECT_SOFTBOILED
  [156] = rec(37, 0, 14, 0, 10, 0, 0x10, 0, 0x08), -- REST :2031 EFFECT_REST
  [116] = rec(47, 0, 0, 0, 30, 0, 0x10, 0, 0x08), -- FOCUS_ENERGY :1511 EFFECT_FOCUS_ENERGY
  [287] = rec(193, 0, 0, 100, 20, 0, 0x10, 0, 0x08), -- REFRESH :3734 EFFECT_REFRESH
  [275] = rec(181, 0, 12, 100, 20, 0, 0x10, 0, 0x08), -- INGRAIN :3578 EFFECT_INGRAIN
  [150] = rec(85, 0, 0, 0, 40, 0, 0x10, 0, 0x00), -- SPLASH :1953 EFFECT_SPLASH
  [160] = rec(30, 0, 0, 0, 30, 0, 0x10, 0, 0x00), -- CONVERSION :2083 EFFECT_CONVERSION
  [187] = rec(142, 0, 0, 0, 10, 0, 0x10, 0, 0x08), -- BELLY_DRUM :2434 EFFECT_BELLY_DRUM
  [339] = rec(208, 0, 1, 0, 20, 0, 0x10, 0, 0x08), -- BULK_UP :4410 EFFECT_BULK_UP
  [234] = rec(132, 0, 0, 0, 5, 0, 0x10, 0, 0x08), -- MORNING_SUN :3045 EFFECT_MORNING_SUN
  [135] = rec(157, 0, 0, 100, 10, 0, 0x10, 0, 0x18), -- SOFT_BOILED :1758 EFFECT_SOFTBOILED
  [13] = rec(39, 80, 0, 100, 10, 0, 0x08, 0, 0x32), -- RAZOR_WIND :172 EFFECT_RAZOR_WIND
  [130] = rec(145, 100, 0, 100, 15, 0, 0x00, 0, 0x33), -- SKULL_BASH :1693 EFFECT_SKULL_BASH
  [143] = rec(75, 140, 2, 90, 5, 30, 0x00, 0, 0x32), -- SKY_ATTACK :1862 EFFECT_SKY_ATTACK
  [76] = rec(151, 120, 12, 100, 10, 0, 0x00, 0, 0x32), -- SOLAR_BEAM :991 EFFECT_SOLAR_BEAM
  [19] = rec(155, 70, 2, 95, 15, 0, 0x00, 0, 0x33), -- FLY :250 EFFECT_SEMI_INVULNERABLE
  [91] = rec(155, 60, 4, 100, 10, 0, 0x00, 0, 0x33), -- DIG :1186 EFFECT_SEMI_INVULNERABLE
  [291] = rec(155, 60, 11, 100, 10, 0, 0x00, 0, 0x33), -- DIVE :3786 EFFECT_SEMI_INVULNERABLE
  [340] = rec(155, 85, 2, 85, 5, 30, 0x00, 0, 0x33), -- BOUNCE :4423 EFFECT_SEMI_INVULNERABLE
  [137] = rec(67, 0, 0, 75, 30, 0, 0x00, 0, 0x16), -- GLARE :1784 EFFECT_PARALYZE
  [78] = rec(67, 0, 12, 75, 30, 0, 0x00, 0, 0x16), -- STUN_SPORE :1017 EFFECT_PARALYZE
  [28] = rec(23, 0, 4, 100, 15, 0, 0x00, 0, 0x16), -- SAND_ATTACK :367 EFFECT_ACCURACY_DOWN
}
local moves = {}
for id, m in pairs(Data.moves) do moves[id] = m end
for id, m in pairs(RECORDS) do moves[id] = m end

local M = {
  TACKLE = 33, POISON_STING = 40, EMBER = 52, ICE_BEAM = 58, THUNDER_SHOCK = 84, BITE = 44,
  TRI_ATTACK = 161, KARATE_CHOP = 2, AURORA_BEAM = 62, CONFUSION = 93, QUICK_ATTACK = 98,
  FLAME_WHEEL = 172, STEEL_WING = 211, METAL_CLAW = 232, ANCIENT_POWER = 246, TWISTER = 239,
  GUST = 16, STOMP = 23, THUNDER = 87, FACADE = 263, SMELLING_SALT = 265, SUPERPOWER = 276,
  BLAZE_KICK = 299, POISON_FANG = 305, WEATHER_BALL = 311, OVERHEAT = 315, SKY_UPPERCUT = 327,
  POISON_TAIL = 342, SWIFT = 129, VITAL_THROW = 233, FALSE_SWIPE = 206, FLAIL = 175,
  ERUPTION = 284, RAPID_SPIN = 229, BRICK_BREAK = 280, WRAP = 35, TAKE_DOWN = 36,
  DOUBLE_EDGE = 38, STRUGGLE = 165, ABSORB = 71, HYPER_BEAM = 63, DOUBLE_SLAP = 3,
  DOUBLE_KICK = 24, TWINEEDLE = 41, SUPER_FANG = 162, DRAGON_RAGE = 82, SONIC_BOOM = 49,
  NIGHT_SHADE = 101, PSYWAVE = 149, FISSURE = 90, GROWL = 45, SCREECH = 103, SAND_ATTACK = 28,
  TRIPLE_KICK = 167, SWAGGER = 207, FLATTER = 260, THRASH = 37, FAKE_OUT = 252,
  FOCUS_PUNCH = 264, MAGNITUDE = 222, EARTHQUAKE = 89, HYPNOSIS = 95, POISON_POWDER = 77,
  THUNDER_WAVE = 86, STUN_SPORE = 78, GLARE = 137, TOXIC = 92, WILL_O_WISP = 261,
  CONFUSE_RAY = 109, TEETER_DANCE = 298, TICKLE = 321, PAIN_SPLIT = 220, MEAN_LOOK = 212,
  LEECH_SEED = 73, NIGHTMARE = 171, MEMENTO = 262, SELF_DESTRUCT = 120, JUMP_KICK = 26,
  HI_JUMP_KICK = 136, ENDEAVOR = 283, SNORE = 173, CURSE = 174, PSYCH_UP = 244, HAZE = 114,
  HAIL = 258, SWORDS_DANCE = 14, REFLECT = 115, RAIN_DANCE = 240, RECOVER = 105,
  MILK_DRINK = 208, REST = 156, FOCUS_ENERGY = 116, REFRESH = 287, INGRAIN = 275,
  SPLASH = 150, CONVERSION = 160, BELLY_DRUM = 187, BULK_UP = 339, MORNING_SUN = 234,
  SOFT_BOILED = 135, RAZOR_WIND = 13, SKULL_BASH = 130, SKY_ATTACK = 143, SOLAR_BEAM = 76,
  FLY = 19, DIG = 91, DIVE = 291, BOUNCE = 340,
}
local T = Data
local ABILITY = { INSOMNIA = 15, IMMUNITY = 17, LIMBER = 7, OWN_TEMPO = 20, WATER_VEIL = 41 }

local function moveName(id)
  for name, mid in pairs(M) do if mid == id then return (name:gsub("_", " ")) end end
  return "MOVE " .. tostring(id)
end

-- Level 10, every stat 20 unless overridden. The player is Psychic, the foe
-- Water (no STAB, neutral effectiveness for the formulas below).
local function battle(values, opts)
  opts = opts or {}
  local function moveList(list, pp)
    local out = {}
    for i, id in ipairs(list) do out[i] = { move = id, pp = pp or moves[id].pp } end
    return out
  end
  local engine = BattleEngine.new({
    player = BattleEngine.makeBattler({ species = 1, level = opts.playerLevel or 10,
      stats = { hp = opts.playerHP or 400, attack = 20, defense = 20,
        speed = opts.playerSpeed or 30, spAttack = 20, spDefense = 20 },
      types = opts.playerTypes or { T.TYPE_PSYCHIC, T.TYPE_PSYCHIC },
      status = opts.playerStatus,
      moves = moveList(opts.playerMoves or { M.TACKLE }, opts.playerPP) }),
    foe = BattleEngine.makeBattler({ species = 19, level = opts.foeLevel or 10,
      stats = { hp = opts.foeHP or 400, attack = 20, defense = 20, speed = opts.foeSpeed or 20,
        spAttack = 20, spDefense = 20 },
      types = opts.foeTypes or { T.TYPE_WATER, T.TYPE_WATER },
      status = opts.foeStatus, moves = moveList(opts.foeMoves or { M.SPLASH }) }),
    moves = moves, typeChart = Data.typeChart, rng = scriptedRng(values or {}),
  })
  engine.player.ability = opts.playerAbility or 0
  engine.foe.ability = opts.foeAbility or 0
  if opts.playerCurrentHP then engine.player.hp = opts.playerCurrentHP end
  if opts.foeCurrentHP then engine.foe.hp = opts.foeCurrentHP end
  return engine
end

-- runTurn clears `protected` at its start (TurnValuesCleanUp(TRUE) is the
-- source clear); this hook sets it on `side` right before the OTHER side's
-- action, where a faster Protect would have set it in P2.
local function protectDuring(engine, side)
  engine.resolveMove = function(self, attackerSide, slot, events)
    if attackerSide ~= side then self:battler(side).protected = true end
    return BattleEngine.resolveMove(self, attackerSide, slot, events)
  end
end

local MOVE = { action = "move", moveSlot = 1 }

local function sig(events)
  local out = {}
  for _, e in ipairs(events) do
    local s = e.type .. (e.side and (":" .. e.side) or "")
    if e.result then s = s .. "(" .. e.result .. ")" end
    out[#out + 1] = s
  end
  return table.concat(out, ",")
end
local function find(events, kind, side)
  for _, e in ipairs(events) do
    if e.type == kind and (side == nil or e.side == side) then return e end
  end
end
local function count(events, kind)
  local n = 0
  for _, e in ipairs(events) do if e.type == kind then n = n + 1 end end
  return n
end

local function texts(engine, events)
  local c = BattleSceneController.new({ engine = engine, playerName = "PLAYER", foeName = "FOE",
    introMessages = {}, moveName = moveName })
  local out = {}
  for _, entry in ipairs(c:_eventMessages(events)) do
    out[#out + 1] = entry.text or ("[hp " .. entry.hpSide .. " " .. entry.hp .. "]")
  end
  return table.concat(out, "|")
end

local function stagesNeutral(b)
  for _, v in pairs(b.statStages) do if v ~= 6 then return false end end
  return true
end

-- One player action against a protected foe through resolveMove directly.
local function protectedAction(opts, values, setup)
  local e = battle(values, opts)
  if setup then setup(e) end
  e.foe.protected = true
  local events = {}
  e:resolveMove("player", 1, events)
  return e, events
end

---------------------------------------------------------------------------
-- Defaults, the predicate, the resets
---------------------------------------------------------------------------
do
  local e = battle({})
  check("makeBattler: protected false", e.player.protected == false and e.foe.protected == false)
  e.foe.protected = true
  check("protectBlocks: flagged move, protected selected target", e:protectBlocks(e.foe, moves[M.TACKLE]))
  check("protectBlocks: flags without FLAG_PROTECT_AFFECTED (Psych Up 0x08, Curse 0)",
    not e:protectBlocks(e.foe, moves[M.PSYCH_UP]) and not e:protectBlocks(e.foe, moves[M.CURSE]))
  check("protectBlocks: MOVE_TARGET_USER with the flag (Haze, Hail, Milk Drink)",
    not e:protectBlocks(e.foe, moves[M.HAZE]) and not e:protectBlocks(e.foe, moves[M.HAIL])
      and not e:protectBlocks(e.foe, moves[M.MILK_DRINK]))
  check("protectBlocks: MOVE_TARGET_BOTH / FOES_AND_ALLY are blocked (Growl, Teeter Dance)",
    e:protectBlocks(e.foe, moves[M.GROWL]) and e:protectBlocks(e.foe, moves[M.TEETER_DANCE]))
  check("protectBlocks: not protected", not e:protectBlocks(e.player, moves[M.TACKLE]))

  -- The flag is per turn: runTurn's start clears it, so a flag left over
  -- from the previous turn blocks nothing (Tackle hits: 3 draws).
  local r = battle({ 0, 1, 0 })
  r.foe.protected = true
  local events = r:runTurn(MOVE, MOVE)
  check("runTurn start clears protected", r.foe.protected == false and find(events, "damage", "player")
    and not find(events, "protected") and r.rng.draws == 3, sig(events))

  -- recordFaint clears it (FaintClearSetData, src/battle_main.c:2461).
  local f = battle({})
  f.foe.protected = true
  f.foe.hp = 0
  f:beginFaintSequence()
  f:recordFaint("foe", {})
  check("recordFaint clears protected", f.foe.protected == false)
end

---------------------------------------------------------------------------
-- Every admitted family against a protected target (table-driven).
-- Row fields: move, opts (battle options), setup(e), expect (event
-- signature), draws, pp (PP change of slot 1), check(e, events) extra.
-- Unless a row says otherwise: the foe's HP, status and stages are
-- unchanged and the player's HP is unchanged.
---------------------------------------------------------------------------
local PROTECTED = "useMove:player,protected:player"
local ROWS = {
  -- Shape A: attackcanceler -> accuracycheck BattleScript_PrintMoveMissed
  -- -> attackstring, ppreduce, resultmessage (bs1.s:246-247, :276-285).
  { name = "EFFECT_HIT Tackle", move = M.TACKLE },
  { name = "2 poison hit", move = M.POISON_STING },
  { name = "4 burn hit", move = M.EMBER },
  { name = "5 freeze hit", move = M.ICE_BEAM },
  { name = "6 paralyze hit", move = M.THUNDER_SHOCK },
  { name = "31 flinch hit", move = M.BITE },
  { name = "36 Tri Attack (no % 3)", move = M.TRI_ATTACK },
  { name = "43 high crit", move = M.KARATE_CHOP },
  { name = "68 attack-down hit", move = M.AURORA_BEAM },
  { name = "76 confuse hit", move = M.CONFUSION, check = function(e) return e.foe.confusionTurns == 0 end },
  { name = "103 Quick Attack", move = M.QUICK_ATTACK },
  { name = "125 thaw hit", move = M.FLAME_WHEEL },
  { name = "138 user DEF-up hit", move = M.STEEL_WING, check = function(e) return stagesNeutral(e.player) end },
  { name = "139 user ATK-up hit", move = M.METAL_CLAW, check = function(e) return stagesNeutral(e.player) end },
  { name = "140 all-stats-up hit", move = M.ANCIENT_POWER, check = function(e) return stagesNeutral(e.player) end },
  { name = "146 Twister", move = M.TWISTER },
  { name = "149 Gust", move = M.GUST },
  { name = "150 Stomp", move = M.STOMP },
  { name = "152 Thunder", move = M.THUNDER },
  { name = "152 Thunder in rain (protect precedes the sure hit)", move = M.THUNDER,
    setup = function(e) e.weather = { kind = "rain", permanent = false }; e.weatherDuration = 5 end },
  { name = "169 Facade", move = M.FACADE, opts = { playerStatus = S.BURN } },
  { name = "171 Smelling Salt (paralysis kept)", move = M.SMELLING_SALT, opts = { foeStatus = S.PARALYSIS },
    check = function(e) return e.foe.status == S.PARALYSIS end },
  { name = "182 Superpower (no self-drop)", move = M.SUPERPOWER, check = function(e) return stagesNeutral(e.player) end },
  { name = "200 Blaze Kick", move = M.BLAZE_KICK },
  { name = "202 Poison Fang", move = M.POISON_FANG },
  { name = "203 Weather Ball", move = M.WEATHER_BALL },
  { name = "204 Overheat (no self-drop)", move = M.OVERHEAT, check = function(e) return stagesNeutral(e.player) end },
  { name = "207 Sky Uppercut", move = M.SKY_UPPERCUT },
  { name = "209 Poison Tail", move = M.POISON_TAIL },
  { name = "17 always-hit Swift (protect precedes AccuracyCalcHelper)", move = M.SWIFT },
  { name = "78 Vital Throw", move = M.VITAL_THROW },
  { name = "101 False Swipe", move = M.FALSE_SWIPE },
  { name = "99 Flail", move = M.FLAIL, opts = { playerCurrentHP = 10 } },
  { name = "190 Eruption", move = M.ERUPTION },
  { name = "129 Rapid Spin (seed kept)", move = M.RAPID_SPIN,
    setup = function(e) e.player.seeded = true end, check = function(e) return e.player.seeded end },
  { name = "186 Brick Break (screens kept)", move = M.BRICK_BREAK,
    setup = function(e) e.sideStatus.foe.reflect = true; e.sideStatus.foe.reflectTimer = 5 end,
    check = function(e) return e.sideStatus.foe.reflect and e.sideStatus.foe.reflectTimer == 5 end },
  { name = "42 trap Wrap (no wrap, no % 100, no & 3)", move = M.WRAP,
    check = function(e) return e.foe.wrapTurns == 0 and e.foe.wrapMove == nil end },
  { name = "48 recoil Take Down (no recoil)", move = M.TAKE_DOWN },
  { name = "198 Double-Edge (no recoil)", move = M.DOUBLE_EDGE },
  { name = "3 absorb (no drain)", move = M.ABSORB, opts = { playerCurrentHP = 100 },
    check = function(e) return e.player.hp == 100 end },
  { name = "80 Hyper Beam (no recharge lock)", move = M.HYPER_BEAM,
    check = function(e) return not e.player.recharging and not e:isLocked("player") end },
  { name = "29 multi-hit (no hit-count draw)", move = M.DOUBLE_SLAP },
  { name = "44 double hit", move = M.DOUBLE_KICK },
  { name = "77 Twineedle", move = M.TWINEEDLE },
  { name = "40 Super Fang", move = M.SUPER_FANG },
  { name = "41 Dragon Rage", move = M.DRAGON_RAGE },
  { name = "130 Sonic Boom", move = M.SONIC_BOOM },
  { name = "87 level damage Night Shade", move = M.NIGHT_SHADE },
  { name = "88 Psywave (no sample)", move = M.PSYWAVE },
  { name = "18 stat down Growl", move = M.GROWL },
  { name = "59 stat down 2 Screech", move = M.SCREECH },
  { name = "23 accuracy down Sand Attack", move = M.SAND_ATTACK },
  -- bs1.s:1380-1430: the loop's first accuracycheck -> NoMoreHits, 0 hits,
  -- resultmessage. Source still draws TripleKickEnd's seteffectwithchance
  -- Random() % 100; the engine omits it under the tracked trailing-roll gap
  -- (inventory row 104, review F5), so 0 draws here is the engine's gap,
  -- not a source fact.
  { name = "104 Triple Kick (0 hits)", move = M.TRIPLE_KICK },
  -- bs1.s:1604-1608, :2147-2151: accuracycheck PrintMoveMissed first.
  { name = "118 Swagger (no ATK+2, no confusion)", move = M.SWAGGER,
    check = function(e) return e.foe.confusionTurns == 0 end },
  { name = "166 Flatter", move = M.FLATTER, check = function(e) return e.foe.confusionTurns == 0 end },
  { name = "27 rampage turn 1 (no lock)", move = M.THRASH,
    check = function(e) return e.player.rampageTurns == 0 and e.player.lockedSlot == nil
      and not e:isLocked("player") end },
  { name = "158 Fake Out on the first turn", move = M.FAKE_OUT },
  { name = "170 Focus Punch, not hit this turn", move = M.FOCUS_PUNCH },
  { name = "165 Struggle (no PP slot, no recoil)", move = M.TACKLE, opts = { playerPP = 0 }, pp = 0 },
  -- Shape B: status scripts (bs1.s:287-300, :687-705, :902-917, :984-1022,
  -- :2170-2185, :2566-2677).
  { name = "1 sleep", move = M.HYPNOSIS },
  { name = "1 sleep: already asleep keeps its text", move = M.HYPNOSIS,
    opts = { foeStatus = S.withSleepTurns(0, 3) }, expect = "useMove:player,statusAlready:foe" },
  { name = "1 sleep: Insomnia keeps its text", move = M.HYPNOSIS, opts = { foeAbility = ABILITY.INSOMNIA },
    expect = "useMove:player,stayedAwake:foe" },
  { name = "1 sleep: any-status ButItFailed -> protected", move = M.HYPNOSIS, opts = { foeStatus = S.PARALYSIS } },
  { name = "66 poison", move = M.POISON_POWDER },
  { name = "66 poison: Immunity keeps its text", move = M.POISON_POWDER, opts = { foeAbility = ABILITY.IMMUNITY },
    expect = "useMove:player,statusPrevented:foe" },
  { name = "66 poison: already poisoned keeps its text", move = M.POISON_POWDER, opts = { foeStatus = S.POISON },
    expect = "useMove:player,statusAlready:foe" },
  { name = "66 poison: a Poison type gets doesn't affect", move = M.POISON_POWDER,
    opts = { foeTypes = { T.TYPE_POISON, T.TYPE_POISON } }, expect = "useMove:player,noEffect:player" },
  { name = "66 poison: any-status -> protected", move = M.POISON_POWDER, opts = { foeStatus = S.BURN } },
  { name = "67 Thunder Wave", move = M.THUNDER_WAVE },
  -- Review F1: jumpifmovehadnoeffect (bs1.s:1011-1012) precedes the
  -- already-paralyzed gate.
  { name = "67 Thunder Wave: already paralyzed -> protected (F1)", move = M.THUNDER_WAVE,
    opts = { foeStatus = S.PARALYSIS } },
  { name = "67 Stun Spore: already paralyzed -> protected (F1)", move = M.STUN_SPORE,
    opts = { foeStatus = S.PARALYSIS } },
  { name = "67 Glare: already paralyzed -> protected (F1)", move = M.GLARE, opts = { foeStatus = S.PARALYSIS } },
  { name = "67 Thunder Wave: any other status -> protected", move = M.THUNDER_WAVE, opts = { foeStatus = S.BURN } },
  { name = "67 Thunder Wave: Limber keeps its text", move = M.THUNDER_WAVE,
    opts = { foeAbility = ABILITY.LIMBER, foeStatus = S.PARALYSIS }, expect = "useMove:player,statusPrevented:foe" },
  { name = "67 Thunder Wave: a Ground type gets doesn't affect", move = M.THUNDER_WAVE,
    opts = { foeTypes = { T.TYPE_GROUND, T.TYPE_GROUND }, foeStatus = S.PARALYSIS },
    expect = "useMove:player,noEffect:player" },
  { name = "67 Glare: a Ghost type gets doesn't affect", move = M.GLARE,
    opts = { foeTypes = { T.TYPE_GHOST, T.TYPE_GHOST } }, expect = "useMove:player,noEffect:player" },
  { name = "33 Toxic", move = M.TOXIC },
  { name = "33 Toxic: a Steel type gets doesn't affect", move = M.TOXIC,
    opts = { foeTypes = { T.TYPE_STEEL, T.TYPE_STEEL } }, expect = "useMove:player,noEffect:player" },
  { name = "167 Will-O-Wisp", move = M.WILL_O_WISP },
  { name = "167 Will-O-Wisp: already burned keeps its text", move = M.WILL_O_WISP, opts = { foeStatus = S.BURN },
    expect = "useMove:player,statusAlready:foe" },
  { name = "167 Will-O-Wisp: a Fire type gets doesn't affect", move = M.WILL_O_WISP,
    opts = { foeTypes = { T.TYPE_FIRE, T.TYPE_FIRE } }, expect = "useMove:player,noEffect:player" },
  { name = "167 Will-O-Wisp: Water Veil keeps its text", move = M.WILL_O_WISP,
    opts = { foeAbility = ABILITY.WATER_VEIL }, expect = "useMove:player,statusPrevented:foe" },
  { name = "49 Confuse Ray", move = M.CONFUSE_RAY, check = function(e) return e.foe.confusionTurns == 0 end },
  { name = "49 confuse: Own Tempo keeps its text", move = M.CONFUSE_RAY, opts = { foeAbility = ABILITY.OWN_TEMPO },
    expect = "useMove:player,confusionPrevented:foe" },
  { name = "49 confuse: already confused keeps its text", move = M.CONFUSE_RAY,
    setup = function(e) e.foe.confusionTurns = 3 end, expect = "useMove:player,alreadyConfused:foe",
    check = function(e) return e.foe.confusionTurns == 3 end },
  { name = "199 Teeter Dance", move = M.TEETER_DANCE, check = function(e) return e.foe.confusionTurns == 0 end },
  { name = "205 Tickle", move = M.TICKLE },
  { name = "205 Tickle: both at -6 keeps won't go lower", move = M.TICKLE,
    setup = function(e) e.foe.statStages.attack = 0; e.foe.statStages.defense = 0 end,
    expect = "useMove:player,statsWontFall:foe", check = function() return true end, stages = false },
  -- Shape C: NO_ACC_CALC(_CHECK_LOCK_ON) (bs1.s:761-775, :1235-1245,
  -- :1440-1453): protected, not "But it failed!".
  { name = "38 OHKO Fissure (no tryKO draw)", move = M.FISSURE },
  { name = "91 Pain Split (HP unchanged)", move = M.PAIN_SPLIT, opts = { playerCurrentHP = 100 },
    check = function(e) return e.player.hp == 100 end },
  { name = "106 Mean Look (no escape lock)", move = M.MEAN_LOOK, check = function(e) return not e.foe.escapePrevented end },
  { name = "106 Mean Look: protected before the already-prevented gate", move = M.MEAN_LOOK,
    setup = function(e) e.foe.escapePrevented = true end },
  -- Shape D.
  { name = "84 Leech Seed: evaded, no draw (bs1.s:1153-1166; bsc.c:6438)", move = M.LEECH_SEED,
    expect = "useMove:player,leechSeed:player(evaded)", check = function(e) return not e.foe.seeded end },
  { name = "84 Leech Seed: a Grass target is evaded too (NO_EFFECT is tested first)", move = M.LEECH_SEED,
    opts = { foeTypes = { T.TYPE_GRASS, T.TYPE_GRASS } }, expect = "useMove:player,leechSeed:player(evaded)" },
  { name = "107 Nightmare, awake target -> protected", move = M.NIGHTMARE },
  { name = "107 Nightmare, already in a nightmare -> protected", move = M.NIGHTMARE,
    opts = { foeStatus = S.withSleepTurns(0, 3) }, setup = function(e) e.foe.nightmare = true end },
  { name = "189 Endeavor, target HP <= user HP -> protected", move = M.ENDEAVOR, opts = { foeCurrentHP = 50 } },
  { name = "189 Endeavor, target HP > user HP -> protected", move = M.ENDEAVOR, opts = { playerCurrentHP = 50 } },
  { name = "92 Snore, awake -> protected", move = M.SNORE },
  { name = "92 Snore, asleep: fast asleep, then protected (no flinch draw)", move = M.SNORE,
    opts = { playerStatus = S.withSleepTurns(0, 3) }, expect = "fastAsleep:player,useMove:player,protected:player" },
  { name = "126 Magnitude: strength roll, then protected", move = M.MAGNITUDE, draws = 1,
    expect = "useMove:player,magnitude:player,protected:player" },
  { name = "126 Magnitude: a Flying target gets doesn't affect", move = M.MAGNITUDE, draws = 1,
    opts = { foeTypes = { T.TYPE_FLYING, T.TYPE_FLYING } }, expect = "useMove:player,magnitude:player,noEffect:player" },
  { name = "147 Earthquake", move = M.EARTHQUAKE },
  { name = "147 Earthquake: a Flying target gets doesn't affect (typecalc in the miss path)", move = M.EARTHQUAKE,
    opts = { foeTypes = { T.TYPE_FLYING, T.TYPE_FLYING } }, expect = "useMove:player,noEffect:player" },
  { name = "158 Fake Out after the first turn -> protected, not But it failed", move = M.FAKE_OUT,
    setup = function(e) e.player.isFirstTurn = 0 end },
}

for _, row in ipairs(ROWS) do
  local opts = {}
  for k, v in pairs(row.opts or {}) do opts[k] = v end
  opts.playerMoves = opts.playerMoves or { row.move }
  local e, events = protectedAction(opts, {}, row.setup)
  local slot = e.player.moves[1]
  local startPP = row.opts and row.opts.playerPP or moves[row.move].pp
  local expect = row.expect or PROTECTED
  local ok = sig(events) == expect
  check(row.name .. ": events", ok, sig(events))
  check(row.name .. ": draws", e.rng.draws == (row.draws or 0), e.rng.draws)
  check(row.name .. ": PP", slot.pp - startPP == (row.pp or -1), slot.pp - startPP)
  local foeHP = row.opts and row.opts.foeCurrentHP or 400
  local playerHP = row.opts and row.opts.playerCurrentHP or 400
  check(row.name .. ": no damage, no HP change", e.foe.hp == foeHP and e.player.hp == playerHP
    and not find(events, "damage") and not find(events, "recoil") and not find(events, "drain"),
    e.foe.hp .. "/" .. e.player.hp)
  local foeStatus = row.opts and row.opts.foeStatus or 0
  check(row.name .. ": no status, no stage change", e.foe.status == foeStatus
    and (row.stages == false or stagesNeutral(e.foe)) and not find(events, "statusApplied")
    and not find(events, "statChange"))
  if row.check then check(row.name .. ": effect state", row.check(e, events)) end
end

---------------------------------------------------------------------------
-- Struggle: every slot at 0 PP selects Struggle (165), which carries the
-- flag: protected, no recoil, no PP (HITMARKER_NO_PPDEDUCT).
---------------------------------------------------------------------------
do
  local e, events = protectedAction({ playerPP = 0 })
  check("Struggle: useMove 165 then protected", sig(events) == PROTECTED
    and events[1].move == M.STRUGGLE, sig(events))
end

---------------------------------------------------------------------------
-- Shape D special cases with draws or extra state.
---------------------------------------------------------------------------
do
  -- Nightmare on a sleeping target LANDS through Protect (no accuracycheck;
  -- seteffectprimary ignores MISSED, bsc.c:2678-2681; decision D5).
  local e, events = protectedAction({ playerMoves = { M.NIGHTMARE }, foeStatus = S.withSleepTurns(0, 3) })
  check("Nightmare on a sleeping protected target lands", sig(events) == "useMove:player,nightmare:player"
    and e.foe.nightmare and e.rng.draws == 0 and e.player.moves[1].pp == 14, sig(events))

  -- Memento (bs1.s:2199-2201, :2234-2244): the user faints, no stat drops,
  -- and it cannot fail even at -6/-6.
  local m, mev = protectedAction({ playerMoves = { M.MEMENTO } })
  check("Memento into Protect: the user faints, no drops", sig(mev):find(
    "^useMove:player,mementoHP:player,protected:player,faint:player") ~= nil
    and m.player.hp == 0 and stagesNeutral(m.foe) and m.rng.draws == 0 and m.player.moves[1].pp == 9, sig(mev))
  local m2, mev2 = protectedAction({ playerMoves = { M.MEMENTO } }, {}, function(x)
    x.foe.statStages.attack = 0; x.foe.statStages.spAttack = 0 end)
  check("Memento into Protect at -6/-6 still faints the user (no But it failed)",
    sig(mev2):find("^useMove:player,mementoHP:player,protected:player,faint:player") ~= nil
    and not find(mev2, "moveFailed") and m2.player.hp == 0, sig(mev2))

  -- Self-Destruct (bs1.s:376-417): critcalc and adjustnormaldamage draw
  -- before accuracycheck (2 draws), no accuracy draw, the user faints.
  local x, xev = protectedAction({ playerMoves = { M.SELF_DESTRUCT } })
  check("Explosion into Protect: protected, user faints, 2 draws",
    sig(xev):find("^useMove:player,selfDestruct:player,protected:player,faint:player") ~= nil
    and x.rng.draws == 2 and x.player.hp == 0 and x.foe.hp == 400 and x.player.moves[1].pp == 4, sig(xev))
  local xg, xgev = protectedAction({ playerMoves = { M.SELF_DESTRUCT }, foeTypes = { T.TYPE_GHOST, T.TYPE_GHOST } })
  check("Explosion into a protected Ghost: doesn't affect wins, 2 draws",
    sig(xgev):find("^useMove:player,selfDestruct:player,noEffect:player,faint:player") ~= nil
    and not find(xgev, "protected") and xg.rng.draws == 2, sig(xgev))

  -- Jump Kick / Hi Jump Kick (bs1.s:853-870): the protected text, then the
  -- crash. Crash damage: damagecalc (no crit) floor(6*70*20/20/50)+2 = 10
  -- vs Water (neutral), random draw 0 -> 10, DMG_RECOIL_FROM_MISS 10/2 = 5.
  -- One draw.
  local j, jev = protectedAction({ playerMoves = { M.JUMP_KICK } })
  local crash = find(jev, "crash", "player")
  check("Jump Kick into Protect: protected then crash, 1 draw, 5 HP",
    sig(jev) == "useMove:player,protected:player,crash:player" and crash.amount == 5
    and j.player.hp == 395 and j.rng.draws == 1 and j.player.moves[1].pp == 24, sig(jev))
  -- Hi Jump Kick power 85: floor(6*85/50)+2 = 12 -> 6.
  local h, hev = protectedAction({ playerMoves = { M.HI_JUMP_KICK } })
  check("Hi Jump Kick into Protect: crash 6", find(hev, "crash").amount == 6 and h.player.hp == 394
    and h.rng.draws == 1, sig(hev))
  -- Review F2: against a protected Ghost the crash text prints (no
  -- immunity scan on the protect path), the adjustnormaldamage draw is
  -- taken, and no HP is lost (the crash's own typecalc sets
  -- DOESNT_AFFECT_FOE, which gates datahpupdate, bsc.c:1713, :1758).
  local g, gev = protectedAction({ playerMoves = { M.JUMP_KICK }, foeTypes = { T.TYPE_GHOST, T.TYPE_GHOST } })
  check("Jump Kick into a protected Ghost: protected, crash text, 1 draw, no HP loss (F2)",
    sig(gev) == "useMove:player,protected:player,crash:player" and find(gev, "crash").amount == 0
    and g.player.hp == 400 and g.rng.draws == 1, sig(gev))
  check("Jump Kick into a protected Ghost: texts",
    texts(g, gev) == "PLAYER used JUMP KICK!|FOE\nprotected itself!|PLAYER kept going\nand crashed!|[hp player 400]",
    texts(g, gev))
end

---------------------------------------------------------------------------
-- Shape E: pass-through families run exactly as without protect (same
-- events, same draws, same state), decision D5 and the USER-target rule.
---------------------------------------------------------------------------
do
  local PASS = {
    { "Ghost Curse lays its curse (flags 0)", M.CURSE, { playerTypes = { T.TYPE_GHOST, T.TYPE_GHOST } } },
    { "non-Ghost Curse", M.CURSE },
    { "Psych Up copies a protected target's stages", M.PSYCH_UP, nil, function(e) e.foe.statStages.attack = 9 end },
    { "Haze (target USER)", M.HAZE, nil, function(e) e.foe.statStages.attack = 9 end },
    { "Hail (target USER)", M.HAIL },
    { "Swords Dance", M.SWORDS_DANCE }, { "Reflect", M.REFLECT }, { "Rain Dance", M.RAIN_DANCE },
    { "Recover", M.RECOVER, { playerCurrentHP = 100 } }, { "Milk Drink", M.MILK_DRINK, { playerCurrentHP = 100 } },
    { "Soft-Boiled", M.SOFT_BOILED, { playerCurrentHP = 100 } }, { "Morning Sun", M.MORNING_SUN, { playerCurrentHP = 100 } },
    { "Rest", M.REST, { playerCurrentHP = 100 } }, { "Focus Energy", M.FOCUS_ENERGY },
    { "Refresh", M.REFRESH, { playerStatus = S.POISON } }, { "Ingrain", M.INGRAIN }, { "Splash", M.SPLASH },
    { "Conversion", M.CONVERSION, { playerMoves = { M.CONVERSION, M.TACKLE } } },
    { "Belly Drum", M.BELLY_DRUM }, { "Bulk Up", M.BULK_UP },
    { "Nightmare on a sleeping target", M.NIGHTMARE, { foeStatus = S.withSleepTurns(0, 3) } },
  }
  for _, p in ipairs(PASS) do
    local opts = p[3] or {}
    if not opts.playerMoves then
      local copy = {}
      for k, v in pairs(opts) do copy[k] = v end
      copy.playerMoves = { p[2] }
      opts = copy
    end
    local values = { 0, 1, 0, 1, 0, 1 }
    local plain = battle(values, opts)
    if p[4] then p[4](plain) end
    local plainEvents = {}
    plain:resolveMove("player", 1, plainEvents)
    local e, events = protectedAction(opts, values, p[4])
    check("pass-through " .. p[1] .. ": same events and draws as unprotected",
      sig(events) == sig(plainEvents) and e.rng.draws == plain.rng.draws and not find(events, "protected"),
      sig(events) .. " vs " .. sig(plainEvents))
    check("pass-through " .. p[1] .. ": same state", e.foe.hp == plain.foe.hp and e.player.hp == plain.player.hp
      and e.foe.cursed == plain.foe.cursed and e.player.statStages.attack == plain.player.statStages.attack
      and e.foe.statStages.attack == plain.foe.statStages.attack and e.foe.nightmare == plain.foe.nightmare)
  end
  local g, gev = protectedAction({ playerMoves = { M.CURSE }, playerTypes = { T.TYPE_GHOST, T.TYPE_GHOST } })
  check("Ghost Curse through Protect: cursed, the user pays half its HP",
    g.foe.cursed and g.player.hp == 200 and find(gev, "curseLaid"), sig(gev))
  local ps, psev = protectedAction({ playerMoves = { M.PSYCH_UP } }, {}, function(x) x.foe.statStages.attack = 9 end)
  check("Psych Up through Protect copies ATK +3", ps.player.statStages.attack == 9, sig(psev))
end

---------------------------------------------------------------------------
-- Multi-turn and lock interactions through runTurn (bs1.s:784-792,
-- :1997-2008; bu.c:203-214). The foe uses Splash (no draws); the player is
-- faster.
---------------------------------------------------------------------------
do
  -- Turn 1 of every two-turn family charges even against a protected
  -- target (attackcanceler's !IsTwoTurnsMove || MULTIPLETURNS clause).
  -- Turn 2 is blocked: "used", protected, no PP (NO_PPDEDUCT), the lock and
  -- the semi-invulnerable bit cleared, unlocked next turn.
  local TWO_TURN = {
    { "Razor Wind", M.RAZOR_WIND }, { "Skull Bash", M.SKULL_BASH }, { "Sky Attack", M.SKY_ATTACK },
    { "Solar Beam", M.SOLAR_BEAM }, { "Fly", M.FLY }, { "Dig", M.DIG }, { "Dive", M.DIVE },
    { "Bounce", M.BOUNCE },
  }
  for _, t in ipairs(TWO_TURN) do
    local e = battle({}, { playerMoves = { t[2] } })
    protectDuring(e, "foe")
    local pp = moves[t[2]].pp
    local t1 = e:runTurn(MOVE, MOVE)
    check(t[1] .. " turn 1 into Protect still charges", find(t1, "chargeTurn", "player")
      and not find(t1, "protected") and e.player.charging and e:isLocked("player")
      and e.player.moves[1].pp == pp - 1 and e.rng.draws == 0, sig(t1))
    local t2 = e:runTurn(MOVE, MOVE)
    check(t[1] .. " turn 2 into Protect: used, protected, no draws",
      sig(t2):find("^turnStart,useMove:player,protected:player,useMove:foe,splash") ~= nil
      and e.rng.draws == 0, sig(t2))
    check(t[1] .. " turn 2 into Protect: no PP, lock and semi-invulnerable cleared, unlocked",
      e.player.moves[1].pp == pp - 1 and not e.player.charging and e.player.semiInvulnerable == nil
      and e.player.lockedSlot == nil and not e:isLocked("player"))
  end

  -- Solar Beam in sun: SolarBeamOnFirstTurn spends its PP and sets the lock
  -- before attackcanceler, then TwoTurnMovesSecondTurn's attackcanceler
  -- blocks it the same turn.
  local sb = battle({}, { playerMoves = { M.SOLAR_BEAM } })
  sb.weather = { kind = "sun", permanent = false }
  sb.weatherDuration = 5
  protectDuring(sb, "foe")
  local sev = sb:runTurn(MOVE, MOVE)
  check("Solar Beam in sun into Protect: used, protected, 1 PP, unlocked",
    sig(sev):find("^turnStart,useMove:player,protected:player") ~= nil and sb.player.moves[1].pp == 9
    and not sb.player.charging and not sb:isLocked("player") and sb.rng.draws == 0, sig(sev))

  -- Locked Thrash: turn 1 hits (accuracy 0, crit 1, random 0, the
  -- seteffectwithchance % 100 and the LOCK_CONFUSE `& 1` -> 2 turns:
  -- 5 draws). Turn 2 into Protect: CancelMultiTurnMoves clears
  -- MULTIPLETURNS and LOCK_CONFUSE, so the rampage ends with NO fatigue
  -- confusion; PrintMoveMissed's ppreduce spends one PP.
  -- LOCK_CONFUSE 2 is decremented at the end of turn 1 (ENDTURN_THRASH),
  -- leaving 1: turn 2 is the last locked turn. Control: unprotected, turn 2
  -- hits (3 draws) and its end of turn confuses (fatigue, `% 4` draw).
  local ctl = battle({ 0, 1, 0, 0, 0, 0, 1, 0, 0, 0 }, { playerMoves = { M.THRASH } })
  ctl:runTurn(MOVE, MOVE)
  local ctlev = ctl:runTurn(MOVE, MOVE)
  check("control: an unprotected last locked Thrash turn ends in fatigue confusion",
    find(ctlev, "fatigueConfusion", "player") and ctl.player.confusionTurns > 0, sig(ctlev))
  local th = battle({ 0, 1, 0, 0, 0 }, { playerMoves = { M.THRASH } })
  local first = th:runTurn(MOVE, MOVE)
  check("Thrash turn 1 locks (2 turns, 1 left after its end of turn)", th.player.rampageTurns == 1
    and th:isLocked("player") and th.rng.draws == 5 and th.player.moves[1].pp == 19, sig(first))
  protectDuring(th, "foe")
  local second = th:runTurn({ action = "move", moveSlot = 1 }, MOVE)
  check("locked Thrash into Protect: used, protected, no draws",
    sig(second):find("^turnStart,useMove:player,protected:player,useMove:foe,splash") ~= nil
    and th.rng.draws == 5, sig(second))
  check("locked Thrash into Protect: rampage over, no fatigue confusion, 1 PP, unlocked",
    th.player.rampageTurns == 0 and th.player.confusionTurns == 0 and not find(second, "fatigueConfusion")
    and th.player.moves[1].pp == 18 and not th:isLocked("player"), sig(second))
  local third = th:runTurn(MOVE, MOVE)
  check("after a blocked rampage the player chooses freely (no lock, no confusion)",
    not find(third, "fatigueConfusion") and not find(third, "confusedTurn"), sig(third))

  -- Ordering trap R2: rampageLocked is captured before the cancel, so a
  -- locked rampage at 0 PP stays at 0 (the guarded ppreduce).
  local z = battle({ 0, 1, 0, 0, 0 }, { playerMoves = { M.THRASH } })
  z:runTurn(MOVE, MOVE)
  z.player.moves[1].pp = 0
  protectDuring(z, "foe")
  local zev = z:runTurn(MOVE, MOVE)
  check("locked 0-PP Thrash into Protect: PP stays 0, protected, unlocked",
    z.player.moves[1].pp == 0 and find(zev, "protected", "player") and not find(zev, "noPP")
    and not z:isLocked("player"), sig(zev) .. " pp=" .. z.player.moves[1].pp)

  -- A battler recharging against a protecting foe is unaffected (the
  -- recharge canceller precedes the protect step).
  local rc = battle({ 0, 1, 0 }, { playerMoves = { M.HYPER_BEAM } })
  rc:runTurn(MOVE, MOVE)
  check("Hyper Beam hit locks the recharge", rc.player.recharging)
  protectDuring(rc, "foe")
  local rcev = rc:runTurn(MOVE, MOVE)
  check("recharge turn against a protecting foe: mustRecharge, no protected text",
    find(rcev, "mustRecharge", "player") and not find(rcev, "protected"), sig(rcev))
end

---------------------------------------------------------------------------
-- Residual effects still tick on a protected battler (nothing reads the
-- flag at end of turn).
---------------------------------------------------------------------------
do
  local e = battle({ 2 }, { playerMoves = { M.SPLASH }, foeMoves = { M.SPLASH }, foeStatus = S.POISON })
  e.foe.seeded = true
  e.foe.wrapTurns, e.foe.wrapMove = 3, M.WRAP
  e.foe.cursed = true
  e.foe.protected = true
  -- Set the flag through the hook too, so it is live during the turn.
  protectDuring(e, "foe")
  local events = e:runTurn(MOVE, MOVE)
  check("a protected battler still takes poison, Leech Seed, wrap and Curse damage",
    find(events, "statusDamage", "foe") and find(events, "leechSeedDrain", "foe")
      and find(events, "wrapDamage", "foe") and find(events, "curseDamage", "foe"), sig(events))
end

---------------------------------------------------------------------------
-- Focus Punch: the lost-focus branch precedes the protected text; the
-- move-passed-attackcanceler flag (review F4).
---------------------------------------------------------------------------
do
  local e = battle({}, { playerMoves = { M.FOCUS_PUNCH } })
  e.player.tookMoveDamage = true
  e.foe.protected = true
  local events = {}
  e:resolveMove("player", 1, events)
  check("Focus Punch, hit this turn, into Protect: lost focus wins", sig(events) == "focusLost:player"
    and e.player.moves[1].pp == 19, sig(events))

  local c = battle({}, { playerMoves = { M.FLY } })
  local cev = {}
  c:resolveMove("player", 1, cev)
  check("F4: a charging turn 1 passed attackcanceler (moveObeyed)", c.moveObeyed == true
    and find(cev, "chargeTurn"))
  local p = battle({ 0 }, { playerStatus = S.PARALYSIS })
  local pev = {}
  p:resolveMove("player", 1, pev)
  check("F4: a canceller-stopped move did not (moveObeyed false)", p.moveObeyed == false
    and find(pev, "fullyParalyzed"), sig(pev))
  local h = battle({ 0, 1, 0 })
  h:resolveMove("player", 1, {})
  check("F4: an ordinary hit passed attackcanceler", h.moveObeyed == true)
  local pr, prev = protectedAction({})
  check("F4: a protected move still passed attackcanceler", pr.moveObeyed == true and pr.protectedMove == true,
    sig(prev))
end

---------------------------------------------------------------------------
-- Controller texts through the real engine.
---------------------------------------------------------------------------
do
  local e, events = protectedAction({})
  check("text: used, then <target>\\nprotected itself!",
    texts(e, events) == "PLAYER used TACKLE!|FOE\nprotected itself!", texts(e, events))
  local f = battle({}, { playerMoves = { M.SPLASH }, foeMoves = { M.TACKLE } })
  f.player.protected = true
  local fev = {}
  f:resolveMove("foe", 1, fev)
  check("text: the foe's move into the player's Protect names the player",
    texts(f, fev) == "FOE used TACKLE!|PLAYER\nprotected itself!", texts(f, fev))
  local l, lev = protectedAction({ playerMoves = { M.LEECH_SEED } })
  check("text: Leech Seed into Protect is evaded",
    texts(l, lev) == "PLAYER used LEECH SEED!|FOE evaded\nthe attack!", texts(l, lev))
  local t, tev = protectedAction({ playerMoves = { M.THUNDER_WAVE }, foeTypes = { T.TYPE_GROUND, T.TYPE_GROUND } })
  check("text: doesn't affect wins over protected",
    texts(t, tev) == "PLAYER used THUNDER WAVE!|It doesn't affect FOE...", texts(t, tev))
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
