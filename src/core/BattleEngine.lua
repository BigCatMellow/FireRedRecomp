-- Deterministic turn-resolution state machine for a real FireRed single
-- battle (1 Pokémon vs 1 Pokémon, direct damage plus the two stat moves
-- required by Oak's first battle). Pure Lua:
-- no love2d, no ROM reads, no globals, no timers -- every randomized
-- decision comes from a caller-supplied Rng instance (src/core/Rng.lua,
-- the real ISO_RANDOMIZE1 LCG), so a battle is a deterministic function
-- of (seed, action script). This is the house pattern already used by
-- ScriptInterpreter.lua / WildEncounterSelector.lua: pure rules logic with
-- a caller-driven interface.
--
-- RULES vs PRESENTATION (the checklist's "Battle animation event stream
-- separate from rules engine" line): this module computes rules only and
-- never draws, waits, or plays anything. Every turn returns an ordered
-- list of plain-table EVENTS describing what happened; an animation/UI
-- layer consumes that list at its own pace, and can be written, replaced,
-- or skipped entirely without touching a line of rules code. The engine
-- never asks the presentation layer anything back -- events are one-way
-- output, so replaying a battle headlessly in a test and playing it with
-- animations produce byte-identical rules results.
--
-- Emitted events (each a table with .type):
--   {type="turnStart", turn=n}
--   {type="useMove", side=, move=<move id>, moveName=nil}
--   {type="miss", side=}                          -- attacker missed
--   {type="noEffect", side=, target=}             -- 0x type effectiveness
--   {type="critical", side=}                      -- emitted before damage
--   {type="damage", side=<attacker>, target=<defender side>, amount=,
--    hpRemaining=, superEffective=, notVeryEffective=}
--   {type="faint", side=}
--   {type="noPP", side=, move=}                   -- see the Struggle stub
--   {type="statChange", side=<target>, stat=, stages=-1, prevented=}
--   {type="tutorialTip", kind="damage"|"stat"}  -- Oak first-battle text
--   {type="run", side=, success=}
--   {type="throwBall", side=, target=, ball=}     -- rules-only item use
--   {type="capture", side=, target=, ball=, shakes=, success=,
--    automatic=}                                   -- CaptureRules result
--   {type="battleEnd", outcome="playerWon"|"playerLost"|"ran"|"caught"}
--
-- Real turn structure ported, in real execution order:
--   1. Action ordering -- SetActionsAndBattlersTurnOrder (src/battle_main.c
--      :3572): a B_ACTION_RUN really is hoisted to the front of the turn
--      order (real `turnOrderId = 5` branch), so running resolves before
--      the opponent's move regardless of speed. B_ACTION_USE_ITEM is also
--      placed before move actions (same function's first item/switch pass),
--      so a Poke Ball resolves before the wild foe's move; after a failed
--      capture the foe still attacks. Otherwise both sides use moves and
--      order comes from GetWhoStrikesFirst (BattleFormulas).
--   2. Per move, the real battle script BattleScript_HitFromAccCheck
--      (data/battle_scripts_1.s:246) in order:
--        accuracycheck -> attackstring -> ppreduce -> critcalc ->
--        damagecalc -> typecalc -> adjustnormaldamage -> datahpupdate ->
--        tryfaintmon
--      Two consequences of that real order are honored exactly, because
--      they are observable and easy to get wrong:
--        (a) PP is deducted AFTER the accuracy roll but on the miss path
--            too -- BattleScript_PrintMoveMissed (line 276) also runs
--            `ppreduce`. A missed move still costs PP.
--        (b) The RNG is consumed in a fixed order per attack: accuracy
--            roll, then (on a hit) crit roll, then the damage roll. A miss
--            consumes exactly one Random(); a hit consumes exactly three.
--            Seeded replays depend on this being right.
--   3. After each action, a fainted defender ends the battle in this 1v1
--      slice (real code would prompt for a switch; there is no party here).
--
-- Real crit multiply placement: Cmd_damagecalc multiplies
-- CalculateBaseDamage's result by gCritMultiplier BEFORE typecalc's STAB
-- and type modifiers, not after -- ported in that order (it changes the
-- result, since every step truncates).
--
-- DOCUMENTED STUBS / SIMPLIFICATIONS in this slice (each is a real
-- mechanic deliberately not ported, never a silently wrong formula):
--   * Struggle: real FireRed makes a mon with no usable PP use MOVE_STRUGGLE
--     (gProtectStructs.noValidMoves -> BattleScript_NoPPForMove). Here,
--     selecting a 0-PP move emits a {type="noPP"} event and the attacker
--     simply loses its action for the turn. No Struggle move, no recoil.
--   * No party/switching: a faint ends the battle. Real code would run
--     the switch-in flow.
--   * No status conditions, abilities, held items, weather, screens,
--     multi-turn/charging moves, trapping, forced switching, multi-hit
--     moves, OHKO moves, recoil/drain, double battles, trainer AI, or
--     EXP/level-up on victory.
--   * Pure single-stat stage-change moves (Growl/Tail Whip's full real
--     family) ARE supported -- see BattleEngine.STAT_STAGE_MOVES and the
--     move.power == 0 branch of resolveMove.
--   * The real "_HIT" secondary-effect family (EFFECT_ATTACK_DOWN_HIT=68,
--     EFFECT_DEFENSE_DOWN_HIT=69, EFFECT_SPEED_DOWN_HIT=70,
--     EFFECT_SPECIAL_ATTACK_DOWN_HIT=71, EFFECT_SPECIAL_DEFENSE_DOWN_HIT=72,
--     EFFECT_ACCURACY_DOWN_HIT=73, EFFECT_DEFENSE_UP_HIT=138,
--     EFFECT_ATTACK_UP_HIT=139) IS supported -- see
--     BattleEngine.HIT_VARIANT_STAT_MOVES and resolveMove's post-damage
--     step. These are ordinary damaging moves (Acid, Psychic, Metal Claw,
--     ...) that run the exact same accuracy/crit/damage/type pipeline as
--     any other hit, then -- only when that hit landed and had an effect
--     (not a miss, not a 0x-type-effectiveness no-effect) -- roll a fresh
--     Random()%100<=secondaryEffectChance chance (real
--     Cmd_seteffectwithchance) to apply a 1-stage stat change: DOWN_HIT ids
--     to the opponent, UP_HIT ids to the user itself. On a no-effect hit
--     the real function still consumes that Random() call (it's the first
--     operand of a short-circuiting C `&&` chain) but never applies the
--     effect; this is ported exactly -- see the noEffect branch of
--     resolveMove and BattleFormulas.secondaryEffectRoll's comment. Not
--     ported: MOVE_EFFECT_CERTAIN (always-trigger; no move wired here uses
--     it) and Serene Grace's chance-doubling (no ability system exists yet).
--     Still explicitly not ported: non-pure-single-stat effects
--     (EFFECT_HAZE, EFFECT_FOCUS_ENERGY, EFFECT_TRANSFORM, EFFECT_REST,
--     etc). supportsMove() correctly rejects those.
--   * Real data/battle_scripts_1.s ALSO defines EFFECT_SPEED_UP=12,
--     EFFECT_SPECIAL_DEFENSE_UP=14, EFFECT_ACCURACY_UP=15,
--     EFFECT_ACCURACY_UP_2=55, EFFECT_EVASION_UP_2=56,
--     EFFECT_SPECIAL_ATTACK_DOWN_2=61, EFFECT_ACCURACY_DOWN_2=63, and
--     EFFECT_EVASION_DOWN_2=64, but the real gBattleScriptsForMoveEffects
--     table (that file, lines ~40-88) wires every one of those eight ids
--     to BattleScript_EffectHit, NOT to BattleScript_EffectStatUp/Down --
--     i.e. despite the names, none of them actually run a stat-change
--     script in the real game, and no real gBattleMoves entry uses any of
--     them (checked against src/data/battle_moves.h). STAT_STAGE_MOVES
--     deliberately omits these eight; supportsMove() correctly rejects
--     them too.
--   * Capture is intentionally the first normal Poke Ball/no-status slice.
--     CaptureRules owns the exact formula/shake RNG. This engine neither
--     removes inventory nor copies a caught mon to party/PC or updates the
--     Pokedex; those are separate real battle-script/UI persistence steps.
--   * Move selection is caller-supplied; there is no AI. The opponent's
--     move is an input to runTurn, which is what makes scripted replay
--     tests possible.

local BattleFormulas = require("src.core.BattleFormulas")
local CaptureRules = require("src.core.CaptureRules")

local BattleEngine = {}
BattleEngine.__index = BattleEngine

BattleEngine.SIDE_PLAYER = "player"
BattleEngine.SIDE_FOE = "foe"
BattleEngine.EFFECT_ATTACK_DOWN = 18
BattleEngine.EFFECT_DEFENSE_DOWN = 19

-- Real MOVE_TARGET_USER bit (include/battle.h: (1 << 4)). Whether a move
-- targets its own user is decoded straight from the move's real `target`
-- byte -- import/BattleMove.lua already exposes it verbatim -- rather than
-- assumed from the effect id's UP/DOWN naming, so this stays correct even
-- for a hypothetical real move whose target doesn't match its id family.
local MOVE_TARGET_USER = 0x10

-- The real pure single-stat stage-change effect family: every EFFECT_*
-- id (include/constants/battle_move_effects.h) that data/battle_scripts_1.s
-- actually routes to BattleScript_EffectStatUp or BattleScript_EffectStatDown
-- (not just BattleScript_EffectHit -- see the header's DOCUMENTED STUBS
-- note on the eight ids that alias to EffectHit despite their names).
-- `stat` matches a BattleEngine battler's statStages key; `delta` is the
-- signed real setstatchanger stage count (matching goesUp=FALSE for the
-- positive UP/UP_2 entries, goesUp=TRUE for the negative DOWN/DOWN_2
-- entries in that file).
BattleEngine.STAT_STAGE_MOVES = {
  [10] = { stat = "attack",    delta =  1 }, -- EFFECT_ATTACK_UP
  [11] = { stat = "defense",   delta =  1 }, -- EFFECT_DEFENSE_UP
  [13] = { stat = "spAttack",  delta =  1 }, -- EFFECT_SPECIAL_ATTACK_UP
  [16] = { stat = "evasion",   delta =  1 }, -- EFFECT_EVASION_UP
  [18] = { stat = "attack",    delta = -1 }, -- EFFECT_ATTACK_DOWN
  [19] = { stat = "defense",   delta = -1 }, -- EFFECT_DEFENSE_DOWN
  [20] = { stat = "speed",     delta = -1 }, -- EFFECT_SPEED_DOWN
  [23] = { stat = "accuracy",  delta = -1 }, -- EFFECT_ACCURACY_DOWN
  [24] = { stat = "evasion",   delta = -1 }, -- EFFECT_EVASION_DOWN
  [50] = { stat = "attack",    delta =  2 }, -- EFFECT_ATTACK_UP_2
  [51] = { stat = "defense",   delta =  2 }, -- EFFECT_DEFENSE_UP_2
  [52] = { stat = "speed",     delta =  2 }, -- EFFECT_SPEED_UP_2
  [53] = { stat = "spAttack",  delta =  2 }, -- EFFECT_SPECIAL_ATTACK_UP_2
  [54] = { stat = "spDefense", delta =  2 }, -- EFFECT_SPECIAL_DEFENSE_UP_2
  [58] = { stat = "attack",    delta = -2 }, -- EFFECT_ATTACK_DOWN_2
  [59] = { stat = "defense",   delta = -2 }, -- EFFECT_DEFENSE_DOWN_2
  [60] = { stat = "speed",     delta = -2 }, -- EFFECT_SPEED_DOWN_2
  [62] = { stat = "spDefense", delta = -2 }, -- EFFECT_SPECIAL_DEFENSE_DOWN_2
}

-- The real "_HIT" secondary-effect family: an ordinary damaging move
-- (accuracycheck -> ... -> datahpupdate, same pipeline as every other
-- direct-damage move) that, after damage resolves, has a chance
-- (gBattleMoves[move].secondaryEffectChance) to also apply a 1-stage stat
-- change (Cmd_seteffectwithchance -> BattleScript_EffectHit's tail; see
-- resolveMove's post-damage step). Unlike STAT_STAGE_MOVES, the DOWN/UP
-- split here is NOT derived from the move's real `target` byte (that field
-- just says "ordinary damage target"); it's a separate real fact per id,
-- confirmed against data/battle_scripts_1.s's setmoveeffect calls
-- (MOVE_EFFECT_*_MINUS_1 with no AFFECTS_USER flag for the DOWN ids;
-- MOVE_EFFECT_*_PLUS_1 | MOVE_EFFECT_AFFECTS_USER for the UP ids) and
-- against real gBattleMoves users in src/data/battle_moves.h (Acid/Psychic
-- opponent-target DOWN, Metal Claw/Meteor Mash/Steel Wing self-target UP).
BattleEngine.HIT_VARIANT_STAT_MOVES = {
  [68] = { stat = "attack",    delta = -1, targetSelf = false }, -- EFFECT_ATTACK_DOWN_HIT
  [69] = { stat = "defense",   delta = -1, targetSelf = false }, -- EFFECT_DEFENSE_DOWN_HIT
  [70] = { stat = "speed",     delta = -1, targetSelf = false }, -- EFFECT_SPEED_DOWN_HIT
  [71] = { stat = "spAttack",  delta = -1, targetSelf = false }, -- EFFECT_SPECIAL_ATTACK_DOWN_HIT
  [72] = { stat = "spDefense", delta = -1, targetSelf = false }, -- EFFECT_SPECIAL_DEFENSE_DOWN_HIT
  [73] = { stat = "accuracy",  delta = -1, targetSelf = false }, -- EFFECT_ACCURACY_DOWN_HIT
  [138] = { stat = "defense",  delta =  1, targetSelf = true },  -- EFFECT_DEFENSE_UP_HIT
  [139] = { stat = "attack",   delta =  1, targetSelf = true },  -- EFFECT_ATTACK_UP_HIT
}

-- Builds a battler table from computed stats. `stats` is a
-- PokemonStats.calculateAll() result (hp/attack/defense/speed/spAttack/
-- spDefense). `types` is {type1, type2} (real gSpeciesInfo.types --
-- mono-type species really do store the same type twice, and this engine
-- relies on that, matching the real `type1 != type2` guard in TypeCalc).
-- `moves` is an ordered list of {move=<id>, pp=<current pp>}.
-- statStages are the real 0..12 encoding, all defaulting to the real
-- neutral 6.
function BattleEngine.makeBattler(opts)
  local stats = opts.stats
  local battler = {
    species = opts.species,
    -- Optional until live wild-mon construction is persistent. Required
    -- only when the player selects the bounded capture action; this is the
    -- real gSpeciesInfo[species].catchRate consumed by handleballthrow.
    catchRate = opts.catchRate,
    level = opts.level,
    types = { opts.types[1], opts.types[2] },
    maxHP = stats.hp,
    hp = opts.hp or stats.hp,
    attack = stats.attack,
    defense = stats.defense,
    speed = stats.speed,
    spAttack = stats.spAttack,
    spDefense = stats.spDefense,
    moves = {},
    statStages = {
      attack = BattleFormulas.DEFAULT_STAT_STAGE,
      defense = BattleFormulas.DEFAULT_STAT_STAGE,
      speed = BattleFormulas.DEFAULT_STAT_STAGE,
      spAttack = BattleFormulas.DEFAULT_STAT_STAGE,
      spDefense = BattleFormulas.DEFAULT_STAT_STAGE,
      accuracy = BattleFormulas.DEFAULT_STAT_STAGE,
      evasion = BattleFormulas.DEFAULT_STAT_STAGE,
    },
  }
  for i, m in ipairs(opts.moves or {}) do
    battler.moves[i] = { move = m.move, pp = m.pp }
  end
  return battler
end

-- opts:
--   player, foe -- makeBattler() results
--   moves       -- the parsed gBattleMoves table (import/BattleMove.lua),
--                  indexed by real move id
--   typeChart   -- import/TypeChart.lua parseTable() rows
--   rng         -- an Rng instance (the real global Random() stream)
function BattleEngine.new(opts)
  assert(opts.player and opts.foe, "BattleEngine needs both battlers")
  assert(opts.moves, "BattleEngine needs the gBattleMoves table")
  assert(opts.typeChart, "BattleEngine needs the parsed type chart rows")
  assert(opts.rng, "BattleEngine needs an Rng instance")
  return setmetatable({
    player = opts.player,
    foe = opts.foe,
    moves = opts.moves,
    typeChart = opts.typeChart,
    rng = opts.rng,
    turn = 0,
    runTries = 0, -- real gBattleStruct->runTries
    firstBattle = opts.firstBattle == true,
    tutorialPlayerDamageDone = false,
    tutorialPlayerStatDone = false,
    outcome = nil,
  }, BattleEngine)
end

function BattleEngine:battler(side)
  if side == BattleEngine.SIDE_PLAYER then return self.player end
  return self.foe
end

local function otherSide(side)
  if side == BattleEngine.SIDE_PLAYER then return BattleEngine.SIDE_FOE end
  return BattleEngine.SIDE_PLAYER
end

function BattleEngine:isOver()
  return self.outcome ~= nil
end

function BattleEngine:supportsMove(move)
  if not move then return false end
  return move.power > 0 or BattleEngine.STAT_STAGE_MOVES[move.effect] ~= nil
end

-- Resolves one attack, appending its events. Returns nothing; the caller
-- checks for a faint. Mirrors BattleScript_HitFromAccCheck's real order.
function BattleEngine:resolveMove(attackerSide, moveSlot, events)
  local attacker = self:battler(attackerSide)
  local defenderSide = otherSide(attackerSide)
  local defender = self:battler(defenderSide)

  local slot = attacker.moves[moveSlot]
  if not slot then
    error(("battler %s has no move in slot %d"):format(attackerSide, moveSlot))
  end
  local move = self.moves[slot.move]
  if not move then
    error(("unknown move id %s"):format(tostring(slot.move)))
  end

  if not self:supportsMove(move) then
    error(("unsupported move effect %d for non-damaging move %d")
      :format(move.effect or -1, slot.move))
  end

  -- Documented Struggle stub (see header): out of PP means no action.
  if slot.pp <= 0 then
    events[#events + 1] = { type = "noPP", side = attackerSide, move = slot.move }
    return
  end

  events[#events + 1] = { type = "useMove", side = attackerSide, move = slot.move }

  -- Real BattleScript_EffectStatUp (every self-target UP/UP_2 effect) has
  -- NO accuracycheck step at all: attackcanceler -> attackstring ->
  -- ppreduce -> statbuffchange. It cannot miss and consumes zero Random()
  -- calls for accuracy. BattleScript_EffectStatDown (every opponent-target
  -- DOWN/DOWN_2 effect) DOES run accuracycheck, same as any damaging move.
  -- Self-vs-opponent targeting is derived from the move's real `target`
  -- field (MOVE_TARGET_USER), not assumed from the UP/DOWN id naming, so
  -- this stays correct-because-derived rather than correct-by-coincidence.
  local statEntry = BattleEngine.STAT_STAGE_MOVES[move.effect]
  local isSelfTargetStat = statEntry ~= nil
    and math.floor((move.target or 0) / MOVE_TARGET_USER) % 2 == 1
  local needsAccuracyCheck = not isSelfTargetStat

  -- The FIRST_BATTLE controller deliberately skips the first player
  -- accuracy RNG independently for a damaging move and for a (DOWN-family)
  -- stat move that actually rolls one. Foe attacks and subsequent player
  -- moves use the ordinary path.
  local tutorialAccuracy = needsAccuracyCheck and self.firstBattle
    and attackerSide == BattleEngine.SIDE_PLAYER
    and ((move.power > 0 and not self.tutorialPlayerDamageDone)
      or (move.power == 0 and not self.tutorialPlayerStatDone))
  local hit
  if needsAccuracyCheck then
    hit = tutorialAccuracy or BattleFormulas.accuracyCheck(
      move.accuracy, attacker.statStages.accuracy,
      defender.statStages.evasion, self.rng)
  else
    hit = true
  end

  -- 2. ppreduce -- real order: after the accuracy roll (or, for a
  -- self-target UP move, in the same slot where accuracycheck would have
  -- been), and on the miss path too (BattleScript_PrintMoveMissed also
  -- runs ppreduce).
  slot.pp = slot.pp - 1

  if not hit then
    events[#events + 1] = { type = "miss", side = attackerSide }
    return
  end

  if move.power == 0 then
    local stat = statEntry.stat
    local delta = statEntry.delta
    local targetSide = isSelfTargetStat and attackerSide or defenderSide
    local target = self:battler(targetSide)
    local current = target.statStages[stat]
    local atLimit = (delta > 0 and current == BattleFormulas.MAX_STAT_STAGE)
      or (delta < 0 and current == BattleFormulas.MIN_STAT_STAGE)
    if atLimit then
      events[#events + 1] = {
        type="statChange", side=targetSide, stat=stat, stages=0, prevented=true,
      }
    else
      local newStage = current + delta
      if newStage < BattleFormulas.MIN_STAT_STAGE then newStage = BattleFormulas.MIN_STAT_STAGE end
      if newStage > BattleFormulas.MAX_STAT_STAGE then newStage = BattleFormulas.MAX_STAT_STAGE end
      target.statStages[stat] = newStage
      events[#events + 1] = {
        type="statChange", side=targetSide, stat=stat, stages=delta,
        stage=newStage,
      }
      if self.firstBattle and attackerSide == BattleEngine.SIDE_PLAYER
          and not self.tutorialPlayerStatDone then
        self.tutorialPlayerStatDone = true
        events[#events + 1] = { type="tutorialTip", kind="stat" }
      end
    end
    return
  end

  -- 3. critcalc (one Random()). Cmd_critcalc evaluates Random before its
  -- FIRST_BATTLE flag check, so the roll is still consumed while criticals
  -- are suppressed. Suppression is global until the first player damage
  -- message flips Oak's state flag, including a foe that attacks first.
  local rolledCrit = BattleFormulas.critRoll(self.rng, 0)
  local isCrit = rolledCrit and not (self.firstBattle and not self.tutorialPlayerDamageDone)

  -- 4. damagecalc: base damage, then the real x2 crit multiply, which
  -- happens BEFORE typecalc.
  local damage = BattleFormulas.calculateBaseDamage(attacker, defender, move, isCrit)
  if isCrit then
    damage = damage * BattleFormulas.CRIT_MULTIPLIER
  end

  -- 5. typecalc: STAB then per-row type effectiveness.
  local flags
  damage, flags = BattleFormulas.typeCalc(
    damage, move.type, attacker.types, defender.types, self.typeChart
  )

  -- 6. adjustnormaldamage always calls ApplyRandomDmgMultiplier, even
  -- for MOVE_RESULT_DOESNT_AFFECT_FOE; its Random() call happens before
  -- the real helper checks whether damage is zero.
  damage = BattleFormulas.applyRandomDamageMultiplier(damage, self.rng)

  if flags.noEffect then
    -- No HP changes for an immunity, but its exact RNG consumption above
    -- is observable in later actions and seeded replays.
    events[#events + 1] = { type = "noEffect", side = attackerSide, target = defenderSide }
    -- Real Cmd_seteffectwithchance still runs on a no-effect hit (the
    -- script isn't branched around it) and its Random() call is the FIRST
    -- operand of a C `&&` chain, so it is evaluated unconditionally before
    -- the later `&&` term that checks MOVE_RESULT_NO_EFFECT and blocks the
    -- actual effect. The roll must still be consumed here; its result is
    -- simply discarded. See BattleFormulas.secondaryEffectRoll's comment.
    if BattleEngine.HIT_VARIANT_STAT_MOVES[move.effect] then
      BattleFormulas.secondaryEffectRoll(self.rng, move.secondaryEffectChance)
    end
    return
  end

  if isCrit then
    events[#events + 1] = { type = "critical", side = attackerSide }
  end

  -- 7. datahpupdate: real HP subtraction, floored at 0.
  if damage > defender.hp then
    damage = defender.hp
  end
  defender.hp = defender.hp - damage
  events[#events + 1] = {
    type = "damage",
    side = attackerSide,
    target = defenderSide,
    amount = damage,
    hpRemaining = defender.hp,
    superEffective = flags.superEffective,
    notVeryEffective = flags.notVeryEffective,
  }
  if self.firstBattle and attackerSide == BattleEngine.SIDE_PLAYER
      and not self.tutorialPlayerDamageDone then
    self.tutorialPlayerDamageDone = true
    events[#events + 1] = { type="tutorialTip", kind="damage" }
  end

  -- 8. seteffectwithchance (real Cmd_seteffectwithchance, after
  -- resultmessage/waitmessage and before tryfaintmon): a fresh
  -- Random()%100<=percentChance roll, consumed exactly once here because
  -- this hit landed and had an effect (the noEffect branch above already
  -- handled -- and returned out of -- the no-effect case, which still
  -- consumes this same roll but never applies it).
  local hitVariant = BattleEngine.HIT_VARIANT_STAT_MOVES[move.effect]
  if hitVariant then
    local succeeded = BattleFormulas.secondaryEffectRoll(self.rng, move.secondaryEffectChance)
    if succeeded then
      local targetSide = hitVariant.targetSelf and attackerSide or defenderSide
      local target = self:battler(targetSide)
      local stat = hitVariant.stat
      local delta = hitVariant.delta
      local current = target.statStages[stat]
      local atLimit = (delta > 0 and current == BattleFormulas.MAX_STAT_STAGE)
        or (delta < 0 and current == BattleFormulas.MIN_STAT_STAGE)
      if atLimit then
        events[#events + 1] = {
          type="statChange", side=targetSide, stat=stat, stages=0, prevented=true,
        }
      else
        local newStage = current + delta
        if newStage < BattleFormulas.MIN_STAT_STAGE then newStage = BattleFormulas.MIN_STAT_STAGE end
        if newStage > BattleFormulas.MAX_STAT_STAGE then newStage = BattleFormulas.MAX_STAT_STAGE end
        target.statStages[stat] = newStage
        events[#events + 1] = {
          type="statChange", side=targetSide, stat=stat, stages=delta, stage=newStage,
        }
      end
    end
  end
end

-- Checks for a faint on `side`, appending events and setting the outcome.
-- Returns true if the battle ended.
function BattleEngine:checkFaint(side, events)
  local battler = self:battler(side)
  if battler.hp > 0 then return false end
  battler.hp = 0
  events[#events + 1] = { type = "faint", side = side }
  if side == BattleEngine.SIDE_PLAYER then
    self.outcome = "playerLost"
  else
    self.outcome = "playerWon"
  end
  events[#events + 1] = { type = "battleEnd", outcome = self.outcome }
  return true
end

-- Runs one full turn. Each action is a table:
--   {action="move", moveSlot=n}   -- use the move in that 1-based slot
--   {action="run"}                -- player only (real singles run)
--   {action="capture"}            -- player only; normal Poke Ball slice
-- Returns the ordered event list for the turn.
function BattleEngine:runTurn(playerAction, foeAction)
  assert(not self:isOver(), "battle is already over")
  local events = {}
  self.turn = self.turn + 1
  events[#events + 1] = { type = "turnStart", turn = self.turn }

  -- Real SetActionsAndBattlersTurnOrder puts B_ACTION_USE_ITEM ahead of
  -- move actions. Inventory selection/removal happened before the battle
  -- action in the real UI and stays outside this rules engine. A failed ball
  -- consumes however many shared-RNG shake draws it needed, then the foe's
  -- move immediately continues on that same stream.
  if playerAction.action == "capture" then
    assert(self.foe.catchRate ~= nil,
      "capture needs foe.catchRate from gSpeciesInfo")
    events[#events + 1] = {
      type = "throwBall",
      side = BattleEngine.SIDE_PLAYER,
      target = BattleEngine.SIDE_FOE,
      ball = CaptureRules.ITEM_POKE_BALL,
    }
    local result = CaptureRules.tryPokeBall(self.foe, self.rng)
    events[#events + 1] = {
      type = "capture",
      side = BattleEngine.SIDE_PLAYER,
      target = BattleEngine.SIDE_FOE,
      ball = result.ballItemId,
      shakes = result.shakes,
      success = result.captured,
      automatic = result.automatic,
    }
    if result.captured then
      self.outcome = "caught"
      events[#events + 1] = { type = "battleEnd", outcome = self.outcome }
      return events
    end
    self:resolveMove(BattleEngine.SIDE_FOE, foeAction.moveSlot, events)
    self:checkFaint(BattleEngine.SIDE_PLAYER, events)
    return events
  end

  -- Real SetActionsAndBattlersTurnOrder: a run action is hoisted to the
  -- front of the turn order, ahead of any move.
  if playerAction.action == "run" then
    local success = BattleFormulas.tryRunFromBattle(
      self.player.speed,
      self.foe.speed,
      self.runTries,
      self.rng
    )
    self.runTries = self.runTries + 1 -- real: incremented either way
    events[#events + 1] = { type = "run", side = BattleEngine.SIDE_PLAYER, success = success }
    if success then
      self.outcome = "ran"
      events[#events + 1] = { type = "battleEnd", outcome = self.outcome }
      return events
    end
    -- Failed run: the player loses the action, the foe still attacks.
    self:resolveMove(BattleEngine.SIDE_FOE, foeAction.moveSlot, events)
    self:checkFaint(BattleEngine.SIDE_PLAYER, events)
    return events
  end

  local playerMove = self.moves[self.player.moves[playerAction.moveSlot].move]
  local foeMove = self.moves[self.foe.moves[foeAction.moveSlot].move]
  local strikesFirst = BattleFormulas.getWhoStrikesFirst(
    self.player, self.foe, playerMove, foeMove, self.rng
  )

  local order
  if strikesFirst == 0 then
    order = { { BattleEngine.SIDE_PLAYER, playerAction }, { BattleEngine.SIDE_FOE, foeAction } }
  else
    order = { { BattleEngine.SIDE_FOE, foeAction }, { BattleEngine.SIDE_PLAYER, playerAction } }
  end

  for _, entry in ipairs(order) do
    local side, action = entry[1], entry[2]
    if self:battler(side).hp > 0 then
      self:resolveMove(side, action.moveSlot, events)
      if self:checkFaint(otherSide(side), events) then
        return events
      end
    end
  end

  return events
end

-- Convenience for tests/replays: runs turns until the battle ends or
-- `maxTurns` is hit, taking each side's action from a script (a list of
-- action tables, the last one repeating if the script runs short).
-- Returns the flat event list across every turn.
function BattleEngine:runBattle(playerScript, foeScript, maxTurns)
  maxTurns = maxTurns or 100
  local all = {}
  local turn = 0
  while not self:isOver() and turn < maxTurns do
    turn = turn + 1
    local pa = playerScript[turn] or playerScript[#playerScript]
    local fa = foeScript[turn] or foeScript[#foeScript]
    for _, e in ipairs(self:runTurn(pa, fa)) do
      all[#all + 1] = e
    end
  end
  return all
end

return BattleEngine
