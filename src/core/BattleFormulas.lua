-- Real Gen 3 (FireRed) battle math, ported by hand from pokefirered
-- source. Pure functions only -- no love2d, no ROM, no global state; every
-- random draw is taken from a caller-supplied Rng instance
-- (src/core/Rng.lua, the real ISO_RANDOMIZE1 LCG) so a whole battle is a
-- deterministic function of its seed. All division here is C integer
-- truncation, reproduced with math.floor (every operand is non-negative,
-- so floor == C truncation exactly).
--
-- Real functions ported, with the exact source they came from:
--
-- 1. CalculateBaseDamage (src/pokemon.c:2385) -- the real damage core.
--    NOTE the real function's shape, which differs from the community
--    "one-line formula": there is no single expression, it's a sequence
--    of separately-truncating integer steps, and it returns damage + 2
--    (the "+2" is inside CalculateBaseDamage, not a separate step):
--      damage  = APPLY_STAT_MOD(attack, attacker, STAT_ATK)
--      damage  = damage * gBattleMovePower
--      damage  = damage * (2 * level / 5 + 2)      <- inner / is integer
--      damage  = damage / APPLY_STAT_MOD(defense, defender, STAT_DEF)
--      damage  = damage / 50
--      if damage == 0 then damage = 1              <- PHYSICAL BRANCH ONLY
--      return damage + 2
--    Real quirk deliberately preserved: that `if (damage == 0) damage = 1`
--    clamp exists ONLY in the physical branch of the real function. The
--    special branch has no such clamp (a 0-damage special hit stays 0 and
--    returns 2). Do not "fix" this to be symmetric -- it is real behavior.
--    TYPE_MYSTERY (the ??? type, id 9) is forced to 0 damage, also real.
--
--    Critical hits (real: `if (gCritMultiplier == 2)` branches inside
--    CalculateBaseDamage): a crit does NOT skip stat stages wholesale --
--    it ignores the attacker's *lowered* attack stages (uses the raw stat
--    if statStage <= 6) and the defender's *raised* defense stages (uses
--    the raw stat if statStage >= 6), while still honoring a raised
--    attack / lowered defense. Ported exactly.
--
--    The x2 crit multiply itself is NOT in CalculateBaseDamage -- it is
--    applied by the caller, Cmd_damagecalc (src/battle_script_commands.c:
--    1208): `gBattleMoveDamage = CalculateBaseDamage(...) * gCritMultiplier
--    * gBattleScripting.dmgMultiplier`. Gen 3's crit multiplier really is
--    2 (sCriticalHitChance / gCritMultiplier == 2), NOT the 1.5 of later
--    generations -- confirmed in source, see critRoll below.
--
-- 2. TypeCalc (src/battle_script_commands.c:1455) -- STAB and type
--    effectiveness, applied AFTER the crit multiply, BEFORE the random
--    damage roll. Real order and real integer truncation:
--      STAB (attacker has the move's type): damage = damage * 15 / 10
--      then, walking gTypeEffectiveness row by row (import/TypeChart.lua),
--      each matching row calls ModulateDmgByType: damage = damage * mul / 10
--      with `if (damage == 0 && mul != 0) damage = 1`.
--    Two matching rows (one per defender type) are applied *sequentially*,
--    each truncating -- that is not the same as multiplying by a combined
--    4x/0.25x factor in one step, and this port keeps the real per-row
--    sequence. TYPE_FORESIGHT (0xFE) marker rows are skipped (real code
--    only breaks out of the loop there when the defender has
--    STATUS2_FORESIGHT, which this slice doesn't model).
--
-- 3. ApplyRandomDmgMultiplier (src/battle_script_commands.c:1557), called
--    by Cmd_adjustnormaldamage. The real 85-100% roll, exact bounds:
--      rand = Random(); randPercent = 100 - (rand % 16)
--      damage = damage * randPercent / 100; if damage == 0 then damage = 1
--    So the real range is 85..100 inclusive, uniform over 16 values, taken
--    from ONE Random() call, and only applied when damage is nonzero.
--
-- 4. Cmd_accuracycheck (src/battle_script_commands.c:1003) -- accuracy:
--      buff = attackerAccStage + 6 - defenderEvasionStage, clamped to
--             [MIN_STAT_STAGE=0, MAX_STAT_STAGE=12]
--      calc = sAccuracyStageRatios[buff].dividend * moveAccuracy
--             / sAccuracyStageRatios[buff].divisor
--      miss if (Random() % 100 + 1) > calc
--    sAccuracyStageRatios is its own table (33/100, 36/100, 43/100,
--    50/100, 60/100, 75/100, 1/1, 133/100, 166/100, 2/1, 233/100, 133/50,
--    3/1) -- it is NOT gStatStageRatios; the two tables really do differ.
--
-- 5. Cmd_critcalc (src/battle_script_commands.c:1170) -- crit roll:
--      sCriticalHitChance[] = {16, 8, 4, 3, 2}; crit if
--      (Random() % sCriticalHitChance[critChance]) == 0, i.e. 1/16 at the
--      base stage. critChance stage sources (Focus Energy, high-crit
--      moves, Scope Lens/Lucky Punch/Stick) are out of this slice's scope;
--      the stage index is a parameter here so they can be added later.
--
-- 6. GetWhoStrikesFirst (src/battle_main.c:3400) -- turn order:
--      speed = speed * gStatStageRatios[stage][0] / gStatStageRatios[stage][1]
--      then: higher move priority goes first; on equal priority, higher
--      speed goes first; on an exact speed tie, `Random() & 1` decides
--      (a real coin flip -- NOT "player first", and NOT a re-roll loop).
--    Real return values: 0 = battler1 first, 1 or 2 = battler2 first (2 is
--    the speed-tie-coin-flip case; every real caller just tests nonzero).
--    Paralysis (speed/4), Macho Brace, Quick Claw, Swift Swim/Chlorophyll
--    and the Badge 3 speed boost are all real modifiers deliberately left
--    out of this slice (no status/items/abilities/weather/badges yet).
--
-- 7. TryRunFromBattle (src/battle_main.c:4229) -- run odds, singles path:
--      if runner speed >= opponent speed: always escapes
--      else: speedVar = runnerSpeed * 128 / opponentSpeed + runTries * 30
--            escape if speedVar > (Random() & 0xFF)
--      runTries increments on every attempt, win or lose.
--
-- Real modifiers NOT ported here (all no-ops in this slice, each because
-- the system it depends on doesn't exist yet): held items and their hold
-- effects, abilities, badge stat boosts, burn's attack halving, Reflect/
-- Light Screen, weather, Explosion's defense halving, double-battle
-- spread-damage halving, Helping Hand, Charge, Flash Fire, Levitate and
-- Wonder Guard. Each is a documented gap, not an approximation: the
-- ported code paths above are byte-for-byte the real ones for a plain
-- single-battle direct-damage move with no items/abilities/status.

local BattleFormulas = {}

local floor = math.floor

local function idiv(a, b)
  return floor(a / b)
end

-- Real type ids, include/constants/pokemon.h.
BattleFormulas.TYPE_NORMAL = 0
BattleFormulas.TYPE_MYSTERY = 9 -- the ??? type; splits physical from special
BattleFormulas.TYPE_NONE = 255

-- IS_TYPE_PHYSICAL / IS_TYPE_SPECIAL, include/battle.h:475-476. This is
-- the real FireRed-era (Gen 1-3) physical/special split: it is decided by
-- the MOVE'S TYPE, not by any per-move category field. gBattleMoves has
-- no category member at all in this era (see import/BattleMove.lua's real
-- 9-field struct). Everything with a type id below TYPE_MYSTERY(9) is
-- physical -- Normal(0), Fighting(1), Flying(2), Poison(3), Ground(4),
-- Rock(5), Bug(6), Ghost(7), Steel(8); everything above it is special --
-- Fire(10), Water(11), Grass(12), Electric(13), Psychic(14), Ice(15),
-- Dragon(16), Dark(17). The split is literally an ordering property of
-- the type id table, not a lookup table anyone has to transcribe.
function BattleFormulas.isPhysicalType(moveType)
  return moveType < BattleFormulas.TYPE_MYSTERY
end

function BattleFormulas.isSpecialType(moveType)
  return moveType > BattleFormulas.TYPE_MYSTERY
end

-- Real stat stages are stored 0..12 with 6 == neutral (MIN_STAT_STAGE 0,
-- DEFAULT_STAT_STAGE 6, MAX_STAT_STAGE 12, include/constants/pokemon.h).
-- This module keeps that real 0..12 encoding rather than a -6..+6 one so
-- the real tables index directly.
BattleFormulas.MIN_STAT_STAGE = 0
BattleFormulas.DEFAULT_STAT_STAGE = 6
BattleFormulas.MAX_STAT_STAGE = 12

-- gStatStageRatios, src/pokemon.c:1442. Indexed by real stage 0..12.
BattleFormulas.STAT_STAGE_RATIOS = {
  [0] = { 10, 40 }, -- -6
  [1] = { 10, 35 },
  [2] = { 10, 30 },
  [3] = { 10, 25 },
  [4] = { 10, 20 },
  [5] = { 10, 15 },
  [6] = { 10, 10 }, --  0 (neutral)
  [7] = { 15, 10 },
  [8] = { 20, 10 },
  [9] = { 25, 10 },
  [10] = { 30, 10 },
  [11] = { 35, 10 },
  [12] = { 40, 10 }, -- +6
}

-- sAccuracyStageRatios, src/battle_script_commands.c:570. A DIFFERENT
-- table from gStatStageRatios -- accuracy/evasion stages use these.
BattleFormulas.ACCURACY_STAGE_RATIOS = {
  [0] = { 33, 100 }, -- -6
  [1] = { 36, 100 },
  [2] = { 43, 100 },
  [3] = { 50, 100 },
  [4] = { 60, 100 },
  [5] = { 75, 100 },
  [6] = { 1, 1 }, --  0 (neutral)
  [7] = { 133, 100 },
  [8] = { 166, 100 },
  [9] = { 2, 1 },
  [10] = { 233, 100 },
  [11] = { 133, 50 },
  [12] = { 3, 1 },
}

-- sCriticalHitChance, src/battle_script_commands.c:588. 1/N per stage.
BattleFormulas.CRITICAL_HIT_CHANCE = { [0] = 16, [1] = 8, [2] = 4, [3] = 3, [4] = 2 }

-- APPLY_STAT_MOD, src/pokemon.c:2374.
function BattleFormulas.applyStatMod(stat, stage)
  local ratio = BattleFormulas.STAT_STAGE_RATIOS[stage or BattleFormulas.DEFAULT_STAT_STAGE]
  return idiv(stat * ratio[1], ratio[2])
end

local function stageOf(battler, key)
  local stages = battler.statStages
  if not stages then return BattleFormulas.DEFAULT_STAT_STAGE end
  return stages[key] or BattleFormulas.DEFAULT_STAT_STAGE
end

-- Real CalculateBaseDamage (src/pokemon.c:2385), reduced to the code
-- paths that are live in a single battle with no items/abilities/status/
-- weather/screens (see this file's header for the full list of real
-- branches deliberately not modeled). Returns the real s32 result --
-- which already includes the real trailing "+ 2".
--
-- attacker/defender: battler tables (see BattleEngine.lua) needing
--   .level, .attack/.defense/.spAttack/.spDefense, optional .statStages.
-- move: a parsed gBattleMoves record (import/BattleMove.lua) -- .power,
--   .type.
-- isCrit: whether Cmd_critcalc set gCritMultiplier to 2 this hit.
function BattleFormulas.calculateBaseDamage(attacker, defender, move, isCrit)
  local moveType = move.type
  local power = move.power
  local damage = 0

  if BattleFormulas.isPhysicalType(moveType) then
    -- Real: on a crit, a LOWERED attack stage is ignored (raw stat used),
    -- a raised one is still applied.
    local atkStage = stageOf(attacker, "attack")
    if isCrit and atkStage <= BattleFormulas.DEFAULT_STAT_STAGE then
      damage = attacker.attack
    else
      damage = BattleFormulas.applyStatMod(attacker.attack, atkStage)
    end

    damage = damage * power
    damage = damage * (idiv(2 * attacker.level, 5) + 2)

    -- Real: on a crit, a RAISED defense stage is ignored, a lowered one
    -- is still applied.
    local defStage = stageOf(defender, "defense")
    local damageHelper
    if isCrit and defStage >= BattleFormulas.DEFAULT_STAT_STAGE then
      damageHelper = defender.defense
    else
      damageHelper = BattleFormulas.applyStatMod(defender.defense, defStage)
    end

    damage = idiv(damage, damageHelper)
    damage = idiv(damage, 50)

    -- Real physical-only minimum-1 clamp (see header).
    if damage == 0 then
      damage = 1
    end
  end

  if moveType == BattleFormulas.TYPE_MYSTERY then
    damage = 0 -- real: the ??? type does 0 damage
  end

  if BattleFormulas.isSpecialType(moveType) then
    local spAtkStage = stageOf(attacker, "spAttack")
    if isCrit and spAtkStage <= BattleFormulas.DEFAULT_STAT_STAGE then
      damage = attacker.spAttack
    else
      damage = BattleFormulas.applyStatMod(attacker.spAttack, spAtkStage)
    end

    damage = damage * power
    damage = damage * (idiv(2 * attacker.level, 5) + 2)

    local spDefStage = stageOf(defender, "spDefense")
    local damageHelper
    if isCrit and spDefStage >= BattleFormulas.DEFAULT_STAT_STAGE then
      damageHelper = defender.spDefense
    else
      damageHelper = BattleFormulas.applyStatMod(defender.spDefense, spDefStage)
    end

    damage = idiv(damage, damageHelper)
    damage = idiv(damage, 50)
    -- No minimum-1 clamp here: real special branch genuinely lacks one.
  end

  return damage + 2
end

BattleFormulas.MUL_NO_EFFECT = 0
BattleFormulas.MUL_NOT_EFFECTIVE = 5
BattleFormulas.MUL_NORMAL = 10
BattleFormulas.MUL_SUPER_EFFECTIVE = 20
BattleFormulas.TYPE_FORESIGHT = 0xFE

-- ModulateDmgByType, src/battle_script_commands.c:1240.
local function modulateDmgByType(damage, multiplier)
  damage = idiv(damage * multiplier, 10)
  if damage == 0 and multiplier ~= 0 then
    damage = 1
  end
  return damage
end

-- Real TypeCalc (src/battle_script_commands.c:1455): applies STAB, then
-- walks the real gTypeEffectiveness rows applying one ModulateDmgByType
-- per matching row (up to two, one per defender type -- and only once if
-- both defender types are the same, matching the real
-- `type1 != type2` guard).
--
-- typeChartRows: import/TypeChart.lua's parseTable output (a 0-indexed
--   array of {attackingType, defendingType, multiplier}).
-- attackerTypes/defenderTypes: {type1, type2}.
-- Returns damage, flags where flags = {superEffective=, notVeryEffective=,
--   noEffect=} (a plain-Lua stand-in for the real MOVE_RESULT_* bits, used
--   by the presentation layer for the real "It's super effective!" line).
function BattleFormulas.typeCalc(damage, moveType, attackerTypes, defenderTypes, typeChartRows)
  local flags = { superEffective = false, notVeryEffective = false, noEffect = false }

  -- Real ModulateDmgByType2 (src/battle_script_commands.c): a later
  -- opposing type multiplier cancels the previous result bit. Thus a
  -- 2x * 0.5x dual-type hit is neutral, not both "super" and "not very".
  local function recordMultiplier(multiplier)
    if multiplier == BattleFormulas.MUL_NO_EFFECT then
      flags.noEffect = true
      flags.notVeryEffective = false
    elseif multiplier == BattleFormulas.MUL_SUPER_EFFECTIVE then
      if flags.notVeryEffective then
        flags.notVeryEffective = false
      else
        flags.superEffective = true
      end
    elseif multiplier == BattleFormulas.MUL_NOT_EFFECTIVE then
      if flags.superEffective then
        flags.superEffective = false
      else
        flags.notVeryEffective = true
      end
    end
  end

  -- Real STAB check: IS_BATTLER_OF_TYPE -- either of the attacker's two
  -- types matching is enough, and a mono-type mon (whose type1 == type2)
  -- gets it exactly once, since this is a single test, not per-type.
  if attackerTypes[1] == moveType or attackerTypes[2] == moveType then
    damage = idiv(damage * 15, 10)
  end

  local i = 0
  while true do
    local row = typeChartRows[i]
    if not row then break end
    if row.attackingType == BattleFormulas.TYPE_FORESIGHT then
      -- Real code breaks here only under STATUS2_FORESIGHT (not modeled);
      -- otherwise it skips the marker row and keeps walking.
      i = i + 1
    else
      if row.attackingType == moveType then
        if row.defendingType == defenderTypes[1] then
          damage = modulateDmgByType(damage, row.multiplier)
          recordMultiplier(row.multiplier)
        end
        if row.defendingType == defenderTypes[2] and defenderTypes[1] ~= defenderTypes[2] then
          damage = modulateDmgByType(damage, row.multiplier)
          recordMultiplier(row.multiplier)
        end
      end
      i = i + 1
    end
  end

  if flags.noEffect then
    -- Real MOVE_RESULT_DOESNT_AFFECT_FOE clears the other two bits.
    flags.superEffective = false
    flags.notVeryEffective = false
  end

  return damage, flags
end

-- ApplyRandomDmgMultiplier, src/battle_script_commands.c:1557. Consumes
-- exactly one Random() call, always (even when damage is 0 -- the real
-- function calls Random() before testing gBattleMoveDamage, so the RNG
-- stream advances either way; that ordering matters for seeded replays).
function BattleFormulas.applyRandomDamageMultiplier(damage, rng)
  local rand = rng:next16()
  local randPercent = 100 - (rand % 16)
  if damage ~= 0 then
    damage = damage * randPercent
    damage = idiv(damage, 100)
    if damage == 0 then
      damage = 1
    end
  end
  return damage
end

-- Real accuracy check from Cmd_accuracycheck (src/battle_script_commands.c
-- :1003). Consumes exactly one Random() call. Returns true on a hit.
-- accStage/evasionStage are real 0..12 stages (default 6).
function BattleFormulas.accuracyCheck(moveAccuracy, accStage, evasionStage, rng)
  accStage = accStage or BattleFormulas.DEFAULT_STAT_STAGE
  evasionStage = evasionStage or BattleFormulas.DEFAULT_STAT_STAGE

  local buff = accStage + BattleFormulas.DEFAULT_STAT_STAGE - evasionStage
  if buff < BattleFormulas.MIN_STAT_STAGE then buff = BattleFormulas.MIN_STAT_STAGE end
  if buff > BattleFormulas.MAX_STAT_STAGE then buff = BattleFormulas.MAX_STAT_STAGE end

  local ratio = BattleFormulas.ACCURACY_STAGE_RATIOS[buff]
  local calc = idiv(ratio[1] * moveAccuracy, ratio[2])

  return not ((rng:next16() % 100 + 1) > calc)
end

-- Real crit roll from Cmd_critcalc (src/battle_script_commands.c:1170).
-- Consumes exactly one Random() call. critStage defaults to 0 (the base
-- 1/16); the real stage sources (Focus Energy, high-crit-ratio moves,
-- Scope Lens/Lucky Punch/Stick) are out of this slice's scope, but the
-- real clamp to the last table entry is kept so they drop straight in.
function BattleFormulas.critRoll(rng, critStage)
  critStage = critStage or 0
  if critStage > 4 then critStage = 4 end
  return (rng:next16() % BattleFormulas.CRITICAL_HIT_CHANCE[critStage]) == 0
end

BattleFormulas.CRIT_MULTIPLIER = 2 -- real gCritMultiplier on a crit (Gen 3)

-- Real secondary-effect roll from Cmd_seteffectwithchance
-- (src/battle_script_commands.c:2774): `Random() % 100 <= percentChance`.
-- Consumes exactly one Random() call. Note this is evaluated as the FIRST
-- operand of a C `&&` chain in the real function, so it runs -- and always
-- consumes its Random() -- on every non-miss hit reaching that command,
-- INCLUDING a MOVE_RESULT_NO_EFFECT (0x type-effectiveness) hit; only the
-- actual effect application is separately gated on NO_EFFECT by the real
-- function's later `&&` terms. Callers must still call this on a no-effect
-- hit to consume the real RNG draw, and simply discard a `true` result.
-- No MOVE_EFFECT_CERTAIN / Serene Grace handling here -- out of this
-- project's scope (see BattleEngine.lua's header).
function BattleFormulas.secondaryEffectRoll(rng, percentChance)
  return (rng:next16() % 100) <= percentChance
end

-- Real EFFECT_MULTI_HIT hit-count roll, Cmd_setmultihitcounter's arg-0
-- branch (src/battle_script_commands.c:6857):
--   gMultiHitCounter = Random() & 3
--   if gMultiHitCounter > 1: gMultiHitCounter = (Random() & 3) + 2
--   else: gMultiHitCounter += 2
-- `Random() & 3` == `Random() % 4` (power-of-two mask), matching this
-- project's existing `next16() % 4` idiom elsewhere (ObjectEventState.lua).
-- Consumes exactly ONE Random() call when the first roll is 0 or 1 (final
-- count 2 or 3), or exactly TWO when the first roll is 2 or 3 (a second
-- roll of 0-3 plus 2 gives a final count of 2-5) -- this variable RNG
-- consumption is itself real-observable and must be exact for seeded
-- replay. Produces the real 3/8, 3/8, 1/8, 1/8 distribution for 2/3/4/5
-- hits as an emergent property of this exact mechanism, not a lookup
-- table. EFFECT_DOUBLE_HIT does NOT call this -- its real script passes a
-- fixed `setmultihitcounter 2` arg, consuming zero Random() calls; callers
-- must branch on the fixed-count case themselves rather than calling this.
function BattleFormulas.rollMultiHitCount(rng)
  local first = rng:next16() % 4
  if first > 1 then
    return (rng:next16() % 4) + 2
  end
  return first + 2
end

-- Real speed used for turn order (GetWhoStrikesFirst, src/battle_main.c
-- :3428). Paralysis/items/abilities/badges deliberately not modeled.
function BattleFormulas.effectiveSpeed(battler)
  return BattleFormulas.applyStatMod(battler.speed, stageOf(battler, "speed"))
end

-- Real GetWhoStrikesFirst (src/battle_main.c:3400), reduced to the
-- singles no-items/no-status path. move1/move2 are parsed gBattleMoves
-- records (only .priority is read) or nil for a non-move action, matching
-- the real MOVE_NONE case (gBattleMoves[MOVE_NONE].priority == 0).
-- Returns 0 if battler1 strikes first, or a nonzero value if battler2
-- does -- specifically the real 1 (faster/priority) or 2 (speed-tie coin
-- flip), preserved so callers can tell a tie-break apart from a clean win.
-- Consumes one Random() call if and only if speeds tie at equal priority,
-- which is exactly when the real code rolls.
function BattleFormulas.getWhoStrikesFirst(battler1, battler2, move1, move2, rng)
  local speed1 = BattleFormulas.effectiveSpeed(battler1)
  local speed2 = BattleFormulas.effectiveSpeed(battler2)
  local priority1 = (move1 and move1.priority) or 0
  local priority2 = (move2 and move2.priority) or 0

  if priority1 ~= priority2 then
    if priority1 < priority2 then return 1 end
    return 0
  end

  -- Equal priorities (the real code has two structurally identical
  -- branches for "some priority is nonzero" and "both are zero"; they do
  -- the same thing, so this port has one).
  if speed1 == speed2 then
    if (rng:next16() % 2) == 1 then -- real `Random() & 1`
      return 2
    end
    return 0
  elseif speed1 < speed2 then
    return 1
  end
  return 0
end

-- Real TryRunFromBattle (src/battle_main.c:4229), singles path only, with
-- no Run Away ability / Smoke Ball item / ghost-without-Silph-Scope
-- special cases. runTries is the real gBattleStruct->runTries counter --
-- the caller owns it and must increment it after every attempt (the real
-- code increments on failure and success alike).
-- Consumes one Random() call only when the runner is slower, matching the
-- real branch (the always-escape fast path rolls nothing).
function BattleFormulas.tryRunFromBattle(runnerSpeed, opponentSpeed, runTries, rng)
  if runnerSpeed < opponentSpeed then
    -- Real speedVar is a u8 local (src/battle_main.c), so assignment
    -- wraps modulo 256 before its comparison with Random() & 0xFF.
    local speedVar = (idiv(runnerSpeed * 128, opponentSpeed) + (runTries * 30)) % 256
    return speedVar > (rng:next16() % 256) -- real `Random() & 0xFF`
  end
  return true -- real: same speed or faster always escapes
end

return BattleFormulas
