-- Source-derived test metadata only; no ROM table or game data is retained.
-- Source pin: pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788.
-- Coverage and admission are independent expectations, reviewed with
-- work/reports/phase4-move-effect-inventory.md. Never build these expectations
-- from BattleEngine's predicate/tables: that would make this check circular.
-- Each row: semantic class, expected admission, power class (1=positive,
-- 0=zero, -1=unused), complete real move-ID membership. Sentinel 0 is excluded.
-- Admission false on an unused row is a placeholder, not a runtime claim.
package.path = package.path .. ";./?.lua"

local inventory = {
  [0] = {"represented", true, 1, {1,5,10,11,15,17,21,22,25,30,33,55,56,57,64,65,70,88,121,127,224,304,337}}, -- EFFECT_HIT
  [1] = {"blocked_on_state", false, 0, {47,79,95,142,147,320}}, -- EFFECT_SLEEP
  [2] = {"blocked_on_state", true, 1, {40,123,124,188}}, -- EFFECT_POISON_HIT
  [3] = {"represented", true, 1, {71,72,141,202}}, -- EFFECT_ABSORB
  [4] = {"blocked_on_state", true, 1, {7,52,53,126,257}}, -- EFFECT_BURN_HIT
  [5] = {"blocked_on_state", true, 1, {8,58,59,181}}, -- EFFECT_FREEZE_HIT
  [6] = {"blocked_on_state", true, 1, {9,34,84,85,122,192,209,225}}, -- EFFECT_PARALYZE_HIT
  [7] = {"represented", true, 1, {120,153}}, -- EFFECT_EXPLOSION
  [8] = {"intentionally_rejected", false, 1, {138}}, -- EFFECT_DREAM_EATER
  [9] = {"blocked_on_state", false, 0, {119}}, -- EFFECT_MIRROR_MOVE
  [10] = {"represented", true, 0, {96,159,336}}, -- EFFECT_ATTACK_UP
  [11] = {"represented", true, 0, {106,110}}, -- EFFECT_DEFENSE_UP
  [12] = {"unused", false, -1, {}}, -- EFFECT_SPEED_UP
  [13] = {"represented", true, 0, {74}}, -- EFFECT_SPECIAL_ATTACK_UP
  [14] = {"unused", false, -1, {}}, -- EFFECT_SPECIAL_DEFENSE_UP
  [15] = {"unused", false, -1, {}}, -- EFFECT_ACCURACY_UP
  [16] = {"represented", true, 0, {104}}, -- EFFECT_EVASION_UP
  [17] = {"represented", true, 1, {129,185,325,332,345,351}}, -- EFFECT_ALWAYS_HIT
  [18] = {"represented", true, 0, {45}}, -- EFFECT_ATTACK_DOWN
  [19] = {"represented", true, 0, {39,43}}, -- EFFECT_DEFENSE_DOWN
  [20] = {"represented", true, 0, {81}}, -- EFFECT_SPEED_DOWN
  [21] = {"unused", false, -1, {}}, -- EFFECT_SPECIAL_ATTACK_DOWN
  [22] = {"unused", false, -1, {}}, -- EFFECT_SPECIAL_DEFENSE_DOWN
  [23] = {"represented", true, 0, {28,108,134,148}}, -- EFFECT_ACCURACY_DOWN
  [24] = {"represented", true, 0, {230}}, -- EFFECT_EVASION_DOWN
  [25] = {"candidate", false, 0, {114}}, -- EFFECT_HAZE
  [26] = {"blocked_on_state", true, 1, {117}}, -- EFFECT_BIDE
  [27] = {"blocked_on_state", true, 1, {37,80,200}}, -- EFFECT_RAMPAGE
  [28] = {"blocked_on_state", false, 0, {18,46}}, -- EFFECT_ROAR
  [29] = {"represented", true, 1, {3,4,31,42,131,140,154,198,292,331,333,350}}, -- EFFECT_MULTI_HIT
  [30] = {"candidate", false, 0, {160}}, -- EFFECT_CONVERSION
  [31] = {"blocked_on_state", true, 1, {27,29,44,125,157,158}}, -- EFFECT_FLINCH_HIT
  [32] = {"candidate", false, 0, {105,303}}, -- EFFECT_RESTORE_HP
  [33] = {"blocked_on_state", false, 0, {92}}, -- EFFECT_TOXIC
  [34] = {"blocked_on_state", true, 1, {6}}, -- EFFECT_PAY_DAY
  [35] = {"represented", true, 0, {113}}, -- EFFECT_LIGHT_SCREEN
  [36] = {"blocked_on_state", true, 1, {161}}, -- EFFECT_TRI_ATTACK
  [37] = {"blocked_on_state", false, 0, {156}}, -- EFFECT_REST
  [38] = {"represented", true, 1, {12,32,90,329}}, -- EFFECT_OHKO
  [39] = {"blocked_on_state", true, 1, {13}}, -- EFFECT_RAZOR_WIND
  [40] = {"represented", true, 1, {162}}, -- EFFECT_SUPER_FANG
  [41] = {"represented", true, 1, {82}}, -- EFFECT_DRAGON_RAGE
  [42] = {"blocked_on_state", true, 1, {20,35,83,128,250,328}}, -- EFFECT_TRAP
  [43] = {"represented", true, 1, {2,75,152,163,177,238,314,348}}, -- EFFECT_HIGH_CRITICAL
  [44] = {"represented", true, 1, {24,155}}, -- EFFECT_DOUBLE_HIT
  [45] = {"candidate", true, 1, {26,136}}, -- EFFECT_RECOIL_IF_MISS
  [46] = {"blocked_on_state", false, 0, {54}}, -- EFFECT_MIST
  [47] = {"blocked_on_state", false, 0, {116}}, -- EFFECT_FOCUS_ENERGY
  [48] = {"represented", true, 1, {36,66,165}}, -- EFFECT_RECOIL
  [49] = {"blocked_on_state", false, 0, {48,109,186}}, -- EFFECT_CONFUSE
  [50] = {"represented", true, 0, {14}}, -- EFFECT_ATTACK_UP_2
  [51] = {"represented", true, 0, {112,151,334}}, -- EFFECT_DEFENSE_UP_2
  [52] = {"represented", true, 0, {97}}, -- EFFECT_SPEED_UP_2
  [53] = {"represented", true, 0, {294}}, -- EFFECT_SPECIAL_ATTACK_UP_2
  [54] = {"represented", true, 0, {133}}, -- EFFECT_SPECIAL_DEFENSE_UP_2
  [55] = {"unused", false, -1, {}}, -- EFFECT_ACCURACY_UP_2
  [56] = {"unused", false, -1, {}}, -- EFFECT_EVASION_UP_2
  [57] = {"blocked_on_state", false, 0, {144}}, -- EFFECT_TRANSFORM
  [58] = {"represented", true, 0, {204,297}}, -- EFFECT_ATTACK_DOWN_2
  [59] = {"represented", true, 0, {103}}, -- EFFECT_DEFENSE_DOWN_2
  [60] = {"represented", true, 0, {178,184}}, -- EFFECT_SPEED_DOWN_2
  [61] = {"unused", false, -1, {}}, -- EFFECT_SPECIAL_ATTACK_DOWN_2
  [62] = {"represented", true, 0, {313,319}}, -- EFFECT_SPECIAL_DEFENSE_DOWN_2
  [63] = {"unused", false, -1, {}}, -- EFFECT_ACCURACY_DOWN_2
  [64] = {"unused", false, -1, {}}, -- EFFECT_EVASION_DOWN_2
  [65] = {"represented", true, 0, {115}}, -- EFFECT_REFLECT
  [66] = {"blocked_on_state", false, 0, {77,139}}, -- EFFECT_POISON
  [67] = {"blocked_on_state", false, 0, {78,86,137}}, -- EFFECT_PARALYZE
  [68] = {"represented", true, 1, {62}}, -- EFFECT_ATTACK_DOWN_HIT
  [69] = {"represented", true, 1, {51,231,249,306}}, -- EFFECT_DEFENSE_DOWN_HIT
  [70] = {"represented", true, 1, {61,132,145,196,317,341}}, -- EFFECT_SPEED_DOWN_HIT
  [71] = {"represented", true, 1, {296}}, -- EFFECT_SPECIAL_ATTACK_DOWN_HIT
  [72] = {"represented", true, 1, {94,242,247,295}}, -- EFFECT_SPECIAL_DEFENSE_DOWN_HIT
  [73] = {"represented", true, 1, {189,190,330}}, -- EFFECT_ACCURACY_DOWN_HIT
  [74] = {"unused", false, -1, {}}, -- EFFECT_EVASION_DOWN_HIT
  [75] = {"blocked_on_state", true, 1, {143}}, -- EFFECT_SKY_ATTACK
  [76] = {"blocked_on_state", true, 1, {60,93,146,223,324,352}}, -- EFFECT_CONFUSE_HIT
  [77] = {"blocked_on_state", true, 1, {41}}, -- EFFECT_TWINEEDLE
  [78] = {"represented", true, 1, {233}}, -- EFFECT_VITAL_THROW
  [79] = {"blocked_on_state", false, 0, {164}}, -- EFFECT_SUBSTITUTE
  [80] = {"blocked_on_state", true, 1, {63,307,308,338}}, -- EFFECT_RECHARGE
  [81] = {"blocked_on_state", true, 1, {99}}, -- EFFECT_RAGE
  [82] = {"blocked_on_state", false, 0, {102}}, -- EFFECT_MIMIC
  [83] = {"blocked_on_state", false, 0, {118}}, -- EFFECT_METRONOME
  [84] = {"blocked_on_state", false, 0, {73}}, -- EFFECT_LEECH_SEED
  [85] = {"candidate", false, 0, {150}}, -- EFFECT_SPLASH
  [86] = {"blocked_on_state", false, 0, {50}}, -- EFFECT_DISABLE
  [87] = {"represented", true, 1, {69,101}}, -- EFFECT_LEVEL_DAMAGE
  [88] = {"represented", true, 1, {149}}, -- EFFECT_PSYWAVE
  [89] = {"blocked_on_state", true, 1, {68}}, -- EFFECT_COUNTER
  [90] = {"blocked_on_state", false, 0, {227}}, -- EFFECT_ENCORE
  [91] = {"represented", true, 0, {220}}, -- EFFECT_PAIN_SPLIT
  [92] = {"blocked_on_state", true, 1, {173}}, -- EFFECT_SNORE
  [93] = {"blocked_on_state", false, 0, {176}}, -- EFFECT_CONVERSION_2
  [94] = {"blocked_on_state", false, 0, {170,199}}, -- EFFECT_LOCK_ON
  [95] = {"blocked_on_state", false, 0, {166}}, -- EFFECT_SKETCH
  [96] = {"unused", false, -1, {}}, -- EFFECT_UNUSED_60
  [97] = {"blocked_on_state", false, 0, {214}}, -- EFFECT_SLEEP_TALK
  [98] = {"blocked_on_state", false, 0, {194}}, -- EFFECT_DESTINY_BOND
  [99] = {"represented", true, 1, {175,179}}, -- EFFECT_FLAIL
  [100] = {"blocked_on_state", false, 0, {180}}, -- EFFECT_SPITE
  [101] = {"represented", true, 1, {206}}, -- EFFECT_FALSE_SWIPE
  [102] = {"blocked_on_state", false, 0, {215,312}}, -- EFFECT_HEAL_BELL
  [103] = {"represented", true, 1, {98,183,245}}, -- EFFECT_QUICK_ATTACK
  [104] = {"candidate", true, 1, {167}}, -- EFFECT_TRIPLE_KICK
  [105] = {"blocked_on_state", true, 1, {168,343}}, -- EFFECT_THIEF
  [106] = {"blocked_on_state", false, 0, {169,212,335}}, -- EFFECT_MEAN_LOOK
  [107] = {"blocked_on_state", false, 0, {171}}, -- EFFECT_NIGHTMARE
  [108] = {"blocked_on_state", false, 0, {107}}, -- EFFECT_MINIMIZE
  [109] = {"blocked_on_state", false, 0, {174}}, -- EFFECT_CURSE
  [110] = {"unused", false, -1, {}}, -- EFFECT_UNUSED_6E
  [111] = {"blocked_on_state", false, 0, {182,197}}, -- EFFECT_PROTECT
  [112] = {"blocked_on_state", false, 0, {191}}, -- EFFECT_SPIKES
  [113] = {"blocked_on_state", false, 0, {193,316}}, -- EFFECT_FORESIGHT
  [114] = {"blocked_on_state", false, 0, {195}}, -- EFFECT_PERISH_SONG
  [115] = {"blocked_on_state", false, 0, {201}}, -- EFFECT_SANDSTORM
  [116] = {"blocked_on_state", false, 0, {203}}, -- EFFECT_ENDURE
  [117] = {"blocked_on_state", true, 1, {205,301}}, -- EFFECT_ROLLOUT
  [118] = {"blocked_on_state", false, 0, {207}}, -- EFFECT_SWAGGER
  [119] = {"blocked_on_state", true, 1, {210}}, -- EFFECT_FURY_CUTTER
  [120] = {"blocked_on_state", false, 0, {213}}, -- EFFECT_ATTRACT
  [121] = {"blocked_on_state", true, 1, {216}}, -- EFFECT_RETURN
  [122] = {"blocked_on_state", true, 1, {217}}, -- EFFECT_PRESENT
  [123] = {"blocked_on_state", true, 1, {218}}, -- EFFECT_FRUSTRATION
  [124] = {"blocked_on_state", false, 0, {219}}, -- EFFECT_SAFEGUARD
  [125] = {"blocked_on_state", true, 1, {172,221}}, -- EFFECT_THAW_HIT
  [126] = {"candidate", true, 1, {222}}, -- EFFECT_MAGNITUDE
  [127] = {"blocked_on_state", false, 0, {226}}, -- EFFECT_BATON_PASS
  [128] = {"blocked_on_state", true, 1, {228}}, -- EFFECT_PURSUIT
  [129] = {"blocked_on_state", true, 1, {229}}, -- EFFECT_RAPID_SPIN
  [130] = {"represented", true, 1, {49}}, -- EFFECT_SONICBOOM
  [131] = {"unused", false, -1, {}}, -- EFFECT_UNUSED_83
  [132] = {"blocked_on_state", false, 0, {234}}, -- EFFECT_MORNING_SUN
  [133] = {"blocked_on_state", false, 0, {235}}, -- EFFECT_SYNTHESIS
  [134] = {"blocked_on_state", false, 0, {236}}, -- EFFECT_MOONLIGHT
  [135] = {"blocked_on_state", true, 1, {237}}, -- EFFECT_HIDDEN_POWER
  [136] = {"blocked_on_state", false, 0, {240}}, -- EFFECT_RAIN_DANCE
  [137] = {"blocked_on_state", false, 0, {241}}, -- EFFECT_SUNNY_DAY
  [138] = {"represented", true, 1, {211}}, -- EFFECT_DEFENSE_UP_HIT
  [139] = {"represented", true, 1, {232,309}}, -- EFFECT_ATTACK_UP_HIT
  [140] = {"candidate", true, 1, {246,318}}, -- EFFECT_ALL_STATS_UP_HIT
  [141] = {"unused", false, -1, {}}, -- EFFECT_UNUSED_8D
  [142] = {"candidate", false, 0, {187}}, -- EFFECT_BELLY_DRUM
  [143] = {"candidate", false, 0, {244}}, -- EFFECT_PSYCH_UP
  [144] = {"blocked_on_state", true, 1, {243}}, -- EFFECT_MIRROR_COAT
  [145] = {"blocked_on_state", true, 1, {130}}, -- EFFECT_SKULL_BASH
  [146] = {"blocked_on_state", true, 1, {239}}, -- EFFECT_TWISTER
  [147] = {"blocked_on_state", true, 1, {89}}, -- EFFECT_EARTHQUAKE
  [148] = {"blocked_on_state", true, 1, {248,353}}, -- EFFECT_FUTURE_SIGHT
  [149] = {"blocked_on_state", true, 1, {16}}, -- EFFECT_GUST
  [150] = {"blocked_on_state", true, 1, {23,302,310,326}}, -- EFFECT_FLINCH_MINIMIZE_HIT
  [151] = {"blocked_on_state", true, 1, {76}}, -- EFFECT_SOLAR_BEAM
  [152] = {"blocked_on_state", true, 1, {87}}, -- EFFECT_THUNDER
  [153] = {"blocked_on_state", false, 0, {100}}, -- EFFECT_TELEPORT
  [154] = {"blocked_on_state", true, 1, {251}}, -- EFFECT_BEAT_UP
  [155] = {"blocked_on_state", true, 1, {19,91,291,340}}, -- EFFECT_SEMI_INVULNERABLE
  [156] = {"blocked_on_state", false, 0, {111}}, -- EFFECT_DEFENSE_CURL
  [157] = {"candidate", false, 0, {135,208}}, -- EFFECT_SOFTBOILED
  [158] = {"blocked_on_state", true, 1, {252}}, -- EFFECT_FAKE_OUT
  [159] = {"blocked_on_state", true, 1, {253}}, -- EFFECT_UPROAR
  [160] = {"blocked_on_state", false, 0, {254}}, -- EFFECT_STOCKPILE
  [161] = {"blocked_on_state", true, 1, {255}}, -- EFFECT_SPIT_UP
  [162] = {"blocked_on_state", false, 0, {256}}, -- EFFECT_SWALLOW
  [163] = {"unused", false, -1, {}}, -- EFFECT_UNUSED_A3
  [164] = {"blocked_on_state", false, 0, {258}}, -- EFFECT_HAIL
  [165] = {"blocked_on_state", false, 0, {259}}, -- EFFECT_TORMENT
  [166] = {"blocked_on_state", false, 0, {260}}, -- EFFECT_FLATTER
  [167] = {"blocked_on_state", false, 0, {261}}, -- EFFECT_WILL_O_WISP
  [168] = {"candidate", false, 0, {262}}, -- EFFECT_MEMENTO
  [169] = {"blocked_on_state", true, 1, {263}}, -- EFFECT_FACADE
  [170] = {"blocked_on_state", true, 1, {264}}, -- EFFECT_FOCUS_PUNCH
  [171] = {"blocked_on_state", true, 1, {265}}, -- EFFECT_SMELLINGSALT
  [172] = {"blocked_on_state", false, 0, {266}}, -- EFFECT_FOLLOW_ME
  [173] = {"blocked_on_state", false, 0, {267}}, -- EFFECT_NATURE_POWER
  [174] = {"blocked_on_state", false, 0, {268}}, -- EFFECT_CHARGE
  [175] = {"blocked_on_state", false, 0, {269}}, -- EFFECT_TAUNT
  [176] = {"blocked_on_state", false, 0, {270}}, -- EFFECT_HELPING_HAND
  [177] = {"blocked_on_state", false, 0, {271}}, -- EFFECT_TRICK
  [178] = {"blocked_on_state", false, 0, {272}}, -- EFFECT_ROLE_PLAY
  [179] = {"blocked_on_state", false, 0, {273}}, -- EFFECT_WISH
  [180] = {"blocked_on_state", false, 0, {274}}, -- EFFECT_ASSIST
  [181] = {"blocked_on_state", false, 0, {275}}, -- EFFECT_INGRAIN
  [182] = {"candidate", true, 1, {276}}, -- EFFECT_SUPERPOWER
  [183] = {"blocked_on_state", false, 0, {277}}, -- EFFECT_MAGIC_COAT
  [184] = {"blocked_on_state", false, 0, {278}}, -- EFFECT_RECYCLE
  [185] = {"blocked_on_state", true, 1, {279}}, -- EFFECT_REVENGE
  [186] = {"candidate", true, 1, {280}}, -- EFFECT_BRICK_BREAK
  [187] = {"blocked_on_state", false, 0, {281}}, -- EFFECT_YAWN
  [188] = {"blocked_on_state", true, 1, {282}}, -- EFFECT_KNOCK_OFF
  [189] = {"represented", true, 1, {283}}, -- EFFECT_ENDEAVOR
  [190] = {"represented", true, 1, {284,323}}, -- EFFECT_ERUPTION
  [191] = {"blocked_on_state", false, 0, {285}}, -- EFFECT_SKILL_SWAP
  [192] = {"blocked_on_state", false, 0, {286}}, -- EFFECT_IMPRISON
  [193] = {"blocked_on_state", false, 0, {287}}, -- EFFECT_REFRESH
  [194] = {"blocked_on_state", false, 0, {288}}, -- EFFECT_GRUDGE
  [195] = {"blocked_on_state", false, 0, {289}}, -- EFFECT_SNATCH
  [196] = {"blocked_on_state", true, 1, {67}}, -- EFFECT_LOW_KICK
  [197] = {"blocked_on_state", true, 1, {290}}, -- EFFECT_SECRET_POWER
  [198] = {"represented", true, 1, {38,344}}, -- EFFECT_DOUBLE_EDGE
  [199] = {"blocked_on_state", false, 0, {298}}, -- EFFECT_TEETER_DANCE
  [200] = {"blocked_on_state", true, 1, {299}}, -- EFFECT_BLAZE_KICK
  [201] = {"blocked_on_state", false, 0, {300}}, -- EFFECT_MUD_SPORT
  [202] = {"blocked_on_state", true, 1, {305}}, -- EFFECT_POISON_FANG
  [203] = {"blocked_on_state", true, 1, {311}}, -- EFFECT_WEATHER_BALL
  [204] = {"candidate", true, 1, {315,354}}, -- EFFECT_OVERHEAT
  [205] = {"candidate", false, 0, {321}}, -- EFFECT_TICKLE
  [206] = {"candidate", false, 0, {322}}, -- EFFECT_COSMIC_POWER
  [207] = {"blocked_on_state", true, 1, {327}}, -- EFFECT_SKY_UPPERCUT
  [208] = {"candidate", false, 0, {339}}, -- EFFECT_BULK_UP
  [209] = {"blocked_on_state", true, 1, {342}}, -- EFFECT_POISON_TAIL
  [210] = {"blocked_on_state", false, 0, {346}}, -- EFFECT_WATER_SPORT
  [211] = {"candidate", false, 0, {347}}, -- EFFECT_CALM_MIND
  [212] = {"candidate", false, 0, {349}}, -- EFFECT_DRAGON_DANCE
  [213] = {"blocked_on_state", false, 0, {293}}, -- EFFECT_CAMOUFLAGE
}

local expectedTotals = {
  moves = 354, defined = 214, used = 198, unused = 16,
  positive = 216, zero = 138, admitted = 248, rejected = 106,
  admitted_uncovered_positive = 111,
}
local expectedClasses = {
  represented = {families = 50, moves = 137, positive = 104, zero = 33},
  candidate = {families = 20, moves = 25, positive = 10, zero = 15},
  blocked_on_state = {families = 127, moves = 191, positive = 101, zero = 90},
  intentionally_rejected = {families = 1, moves = 1, positive = 1, zero = 0},
  unused = {families = 16, moves = 0, positive = 0, zero = 0},
}
local function counts()
  return {moves=0, defined=0, used=0, unused=0, positive=0, zero=0,
    admitted=0, rejected=0, admitted_uncovered_positive=0}
end
local failures = {}
local function check(condition, category)
  if not condition then failures[category] = (failures[category] or 0) + 1 end
end
local function equalCounts(actual, wanted, category)
  for key, value in pairs(wanted) do check(actual[key] == value, category) end
end
local function finish()
  local total, keys = 0, {}
  for category, n in pairs(failures) do total = total + n; keys[#keys+1] = category end
  table.sort(keys)
  for _, category in ipairs(keys) do
    print(("FAIL inventory %s mismatches=%d"):format(category, failures[category]))
  end
  if total > 0 then os.exit(1) end
end

-- Validate the literal expectation itself before any optional ROM work.
local expectedByMove, sourceTotals, sourceClasses = {}, counts(), {}
for kind in pairs(expectedClasses) do sourceClasses[kind] = {families=0,moves=0,positive=0,zero=0} end
for effect, row in pairs(inventory) do
  local kind, admitted, power, ids = row[1], row[2], row[3], row[4]
  local valid = type(effect)=="number" and effect%1==0 and effect>=0 and effect<214
    and expectedClasses[kind]~=nil and type(admitted)=="boolean" and type(ids)=="table"
    and (power==0 or power==1 or power==-1)
  check(valid, "expected_schema")
  if valid then
    sourceTotals.defined = sourceTotals.defined + 1
    sourceClasses[kind].families = sourceClasses[kind].families + 1
    check((#ids==0)==(kind=="unused") and (#ids==0)==(power==-1), "expected_unused")
    if #ids==0 then sourceTotals.unused=sourceTotals.unused+1 else sourceTotals.used=sourceTotals.used+1 end
    for _, id in ipairs(ids) do
      check(type(id)=="number" and id%1==0 and id>=1 and id<=354, "expected_move_range")
      check(expectedByMove[id]==nil, "expected_overlap")
      expectedByMove[id] = {effect=effect, kind=kind, admitted=admitted, power=power}
      sourceTotals.moves = sourceTotals.moves+1
      sourceClasses[kind].moves = sourceClasses[kind].moves+1
      local powerKey = power==1 and "positive" or "zero"
      sourceTotals[powerKey] = sourceTotals[powerKey]+1
      sourceClasses[kind][powerKey] = sourceClasses[kind][powerKey]+1
      local admitKey = admitted and "admitted" or "rejected"
      sourceTotals[admitKey] = sourceTotals[admitKey]+1
      if power==1 and admitted and kind~="represented" then
        sourceTotals.admitted_uncovered_positive = sourceTotals.admitted_uncovered_positive+1
      end
    end
  end
end
for effect=0,213 do check(inventory[effect]~=nil, "expected_effect_gap") end
for id=1,354 do check(expectedByMove[id]~=nil, "expected_move_gap") end
check(expectedByMove[0]==nil, "sentinel_excluded")
equalCounts(sourceTotals, expectedTotals, "expected_totals")
for kind, expected in pairs(expectedClasses) do equalCounts(sourceClasses[kind], expected, "expected_classes") end
finish()

local path = os.getenv("POKEPORT_ROM")
if not path or path=="" then
  print("SKIP phase4_move_effect_inventory_test: expected partition checked; set POKEPORT_ROM for SHA-verified admission/record checks")
  os.exit(0)
end
local RomImporter = require("import.RomImporter")
if not RomImporter.verify(path) then
  print("FAIL inventory supported-ROM SHA verification")
  os.exit(1)
end
local BattleMove = require("import.BattleMove")
local RomAddresses = require("import.RomAddresses")
local BattleEngine = require("src.core.BattleEngine")
local file = assert(io.open(path, "rb"))
local bytes = file:read("*a"); file:close()
local address = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
check(RomAddresses.COUNTS.MOVES_COUNT==355, "importer_count")
local moves = BattleMove.parseTable(bytes, address.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
bytes = nil -- in-memory only; never print or persist parsed records
local probe = setmetatable({}, {__index=BattleEngine})
local actual, familyCounts = counts(), {}
actual.defined = sourceTotals.defined -- definitions are source-only; ROM contains records, not this enum
for id=1,354 do
  local move, expected = moves[id], expectedByMove[id]
  check(move~=nil, "rom_missing_record")
  if move then
    actual.moves=actual.moves+1
    check(inventory[move.effect]~=nil, "rom_undefined_effect")
    familyCounts[move.effect]=(familyCounts[move.effect] or 0)+1
    check(move.effect==expected.effect, "rom_family_membership")
    local positive=move.power>0
    check((positive and 1 or 0)==expected.power, "rom_power_class")
    local powerKey=positive and "positive" or "zero"
    actual[powerKey]=actual[powerKey]+1
    local ok, admitted=pcall(probe.supportsMove, probe, move)
    check(ok and type(admitted)=="boolean", "admission_execution")
    check(ok and admitted==expected.admitted, "admission_expectation")
    local admitKey=ok and admitted and "admitted" or "rejected"
    actual[admitKey]=actual[admitKey]+1
    if positive and ok and admitted and expected.kind~="represented" then
      actual.admitted_uncovered_positive=actual.admitted_uncovered_positive+1
    end
  end
end
for effect=0,213 do
  local count=familyCounts[effect] or 0
  check(count==#inventory[effect][4], "rom_family_count")
  if count==0 then actual.unused=actual.unused+1 else actual.used=actual.used+1 end
end
equalCounts(actual, expectedTotals, "rom_totals")
-- Only counts are emitted, including on a disagreement. A failing result is
-- evidence to investigate, never permission to rewrite expectations to match.
print(("inventory aggregate moves=%d positive=%d zero=%d defined_source=%d used=%d unused=%d admitted=%d rejected=%d admitted_uncovered_positive=%d")
  :format(actual.moves,actual.positive,actual.zero,actual.defined,actual.used,actual.unused,actual.admitted,actual.rejected,actual.admitted_uncovered_positive))
finish()
print("phase4_move_effect_inventory_test: PASS complete source partition and SHA-verified ROM admission; semantic coverage is reviewed metadata, not proven by admission")
