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
--   {type="recoil", side=<attacker>, amount=, hpRemaining=}
--   {type="drain", side=<attacker>, amount=, hpRemaining=}
--   {type="faint", side=}
--   {type="noPP", side=, move=}                   -- see the Struggle stub
--   {type="statChange", side=<target>, stat=, stages=-1, prevented=}
--   {type="tutorialTip", kind="damage"|"stat"}  -- Oak first-battle text
--   {type="run", side=, success=}
--   {type="switch", side=}                         -- voluntary switch resolved
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
--   * Struggle IS supported -- see resolveMove's real AreAllMovesUnusable
--     check (src/battle_util.c) at the top of the function. This engine
--     only ever models the PP move-limitation (no status conditions,
--     Disable, Torment, Taunt, Imprison, Encore, or held items), so the
--     real "every one of the battler's move slots is unusable" condition
--     reduces to exactly one checkable thing here: every move slot the
--     battler has is at 0 PP. When that holds, real battle_main.c
--     (search noValidMoves) sets `gCurrentMove = gChosenMove =
--     MOVE_STRUGGLE` and `gHitMarker |= HITMARKER_NO_PPDEDUCT` -- ported
--     the same way: the caller's requested moveSlot is ignored entirely
--     and BattleEngine.MOVE_STRUGGLE=165 (a caller-supplied self.moves
--     entry, since it is never actually stored in a battler's own move
--     slots) is resolved instead, with the ppreduce step skipped (there is
--     no slot to decrement). Struggle (real effect = EFFECT_RECOIL=48,
--     power=50, accuracy=100) then runs the ordinary accuracy-checked
--     damage pipeline like any other move -- confirmed against real
--     Cmd_accuracycheck (src/battle_script_commands.c), which has no
--     MOVE_STRUGGLE special case at all, so Struggle really can miss, not
--     an always-hit move -- and its recoil falls straight through the
--     already-implemented BattleEngine.RECOIL_MOVES[48] path. Separately,
--     if only the caller's SELECTED slot is at 0 PP while another slot
--     still has PP, that's a state the real move-select menu would never
--     produce (a 0-PP move is greyed out while others remain choosable),
--     but this engine performs no UI-level menu validation -- so that
--     specific case still defensively no-ops with a {type="noPP"} event
--     rather than crashing or fabricating an action.
--     NOT ported (confirmed real but out of scope): real Cmd_typecalc
--     special-cases MOVE_STRUGGLE to skip STAB and type-effectiveness
--     entirely (always neutral damage, never blocked by an immunity, e.g.
--     against a Ghost-type) -- this engine's Struggle runs the ordinary
--     typeCalc step instead, so it WILL currently register as noEffect
--     against an immune type where real FireRed would not. Flagged here
--     for a future pass; not fixed as part of the auto-Struggle trigger.
--   * A faint still ends the battle -- unchanged. The real forced
--     switch-after-faint party-select prompt is a separate, unbuilt
--     feature (this is a bounded 1v1 engine in that one specific sense:
--     it has no flow for "choose a replacement after your active mon
--     faints"). VOLUNTARY switching, by contrast, IS supported -- see
--     the "switch" branch of runTurn and BattlePartyBridge.
--     findSwitchTargets/battlerFromParty. Real SetActionsAndBattlersTurnOrder
--     hoists B_ACTION_SWITCH into the same early group as B_ACTION_USE_ITEM,
--     resolved before any move regardless of speed -- ported the same way
--     capture/run already are: the switch resolves immediately (no RNG),
--     then the foe still attacks that same turn. Real Cmd_switchindataupdate
--     confirms an ordinary (non-Baton-Pass) switch-in starts with neutral
--     stat stages, which BattleEngine.makeBattler already defaults to, so
--     the caller-supplied incoming battler needs no extra reset here. This
--     engine stays fully party-agnostic -- it has no idea what a "party
--     slot" is; BattlePartyBridge owns real switch-target eligibility
--     (Cmd_jumpifcantswitch: living, non-Egg, not the active slot).
--   * No status conditions, abilities, held items, weather, screens,
--     multi-turn/charging moves, trapping, forced switching, OHKO moves,
--     double battles, trainer AI, or EXP/level-up on victory.
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
--   * Recoil and drain ARE supported -- see BattleEngine.RECOIL_MOVES /
--     BattleEngine.DRAIN_MOVES and resolveMove's step 8a. EFFECT_RECOIL=48
--     (Take Down, Submission, and Struggle -- all three real gBattleMoves
--     entries share this one effect id) docks the attacker 1/4 of the
--     actual (already-clamped) HP it just dealt, minimum 1; EFFECT_DOUBLE_
--     EDGE=198 (Double-Edge only) docks 1/3, minimum 1; EFFECT_ABSORB=3
--     (Absorb, Mega Drain, Giga Drain, Leech Life) heals the attacker 1/2,
--     minimum 1, clamped at maxHP. Ordinary damaging moves otherwise --
--     same accuracy/crit/damage/type pipeline, applied only once real
--     damage has actually been dealt to the defender. Verified against real
--     Cmd_seteffectsecondary (src/battle_script_commands.c's
--     MOVE_EFFECT_RECOIL_25/33 cases) and Cmd_negativedamage, and against
--     the real battle scripts (data/battle_scripts_1.s):
--       - Recoil is real-gated off on a type-immune (no-effect) hit: real
--         Cmd_seteffectwithchance's MOVE_EFFECT_CERTAIN branch (which is
--         how the recoil family, setmoveeffect'd as CERTAIN, actually
--         triggers -- no Random() roll at all, unlike the _HIT chance
--         family sharing that same real instruction slot) explicitly checks
--         `!(gMoveResultFlags & MOVE_RESULT_NO_EFFECT)`. Ported by simply
--         placing the recoil dispatch after the existing noEffect early
--         return, same as the _HIT family. This is real-reachable (Take
--         Down/Double-Edge are Normal-type; Ghost is immune to Normal).
--       - Absorb's real `negativedamage` script step is technically NOT
--         gated on MOVE_RESULT_NO_EFFECT at all (unlike recoil, it isn't
--         routed through Cmd_seteffectwithchance); taken completely
--         literally it would still force a minimum 1-HP heal on a no-effect
--         hit, using whatever gHpDealt happens to still hold from a
--         previous, unrelated datahpupdate call (real Cmd_datahpupdate
--         leaves gHpDealt completely untouched, not even zeroed, when
--         MOVE_RESULT_NO_EFFECT is set) -- i.e. real hardware behavior here
--         depends on unrelated prior battle state, not a formula of the
--         current hit. This is also permanently unreachable in real
--         FireRed: every EFFECT_ABSORB move is Grass or Bug type, and the
--         real gTypeEffectiveness table has zero immunities to either type.
--         Ported the same clean way as recoil (skip on noEffect) since
--         that's both behaviorally unreachable and the only sane choice for
--         a stateless per-move engine.
--     Real ordering, verified against BattleScript_MoveEffectRecoil and
--     BattleScript_EffectAbsorb: both apply the attacker's own HP change
--     and run `tryfaintmon BS_ATTACKER` BEFORE returning to the calling
--     script, which only then runs `tryfaintmon BS_TARGET` -- so a hit that
--     both drops the defender to 0 and recoils/drains the attacker to 0 on
--     the same swing resolves the attacker's own faint FIRST. resolveMove
--     calls checkFaint for the attacker right there in step 8a, and
--     runTurn's call sites all check isOver() immediately after
--     resolveMove returns so they never re-check (and potentially
--     overwrite) an outcome the attacker's own faint already decided.
--     The "no valid moves -> auto-Struggle" trigger IS ported -- see the
--     Struggle paragraph above and resolveMove's real AreAllMovesUnusable
--     check at the top of the function.
--     Not ported: EFFECT_RECOIL_IF_MISS=45 (Jump
--     Kick/Hi Jump Kick's crash-on-miss damage -- a different real effect
--     id and mechanic), and EFFECT_DREAM_EATER=8 (heals like Absorb but
--     real BattleScript_EffectDreamEater only works against a sleeping
--     target -- a status-condition precondition this project doesn't model;
--     supportsMove() explicitly rejects it rather than silently running it
--     as ordinary undrained damage).
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
--   * The real multi-hit family IS supported -- see BattleEngine.
--     MULTI_HIT_MOVES and resolveMultiHit. EFFECT_MULTI_HIT=29 (Double
--     Slap, Comet Punch, Fury Attack, Pin Missile, Spike Cannon, Barrage,
--     Fury Swipes, Bone Rush, Arm Thrust, Bullet Seed, Icicle Spear, Rock
--     Blast) hits a real 2-5 times, the count rolled by
--     BattleFormulas.rollMultiHitCount (Cmd_setmultihitcounter's arg-0
--     branch: one Random() call if the first roll is 0 or 1, giving count
--     2 or 3; two Random() calls if the first roll is 2 or 3, a second roll
--     then giving count 2-5). EFFECT_DOUBLE_HIT=44 (Double Kick, Bonemerang)
--     is always exactly 2 hits with ZERO hit-count RNG (real script passes
--     a fixed `setmultihitcounter 2` arg). Both share one real fact this
--     port depends on: accuracy is checked and PP is deducted exactly ONCE
--     for the whole move (real BattleScript_EffectMultiHit/EffectDoubleHit:
--     accuracycheck -> ... -> ppreduce -> setmultihitcounter, all BEFORE
--     the hit-count is even rolled) -- individual hits get their own crit
--     roll and damage roll only, never a repeat accuracy roll. Verified
--     against BattleScript_MultiHitLoop (data/battle_scripts_1.s): a
--     defender that reaches 0 HP partway through the sequence stops it
--     immediately (real per-iteration `jumpifhasnohp BS_TARGET`), and a
--     hit that resolves to MOVE_RESULT_NO_EFFECT (0x type effectiveness)
--     stops the ENTIRE sequence right there (real `jumpifmovehadnoeffect`)
--     -- a type-immune target takes zero hits total, not "immune hits
--     skipped, others land." That noEffect check also fires structurally
--     before the real per-hit `adjustnormaldamage` step, so (unlike the
--     ordinary single-hit path above, where the random-multiplier Random()
--     call always runs even on a no-effect hit) a no-effect hit inside a
--     multi-hit sequence does NOT consume that Random() call -- ported
--     exactly, see resolveMultiHit's inline comment. The real
--     `jumpifhasnohp BS_ATTACKER` check at the very top of the loop is
--     confirmed dead code for this engine's scope: no real EFFECT_MULTI_HIT
--     or EFFECT_DOUBLE_HIT move also has a recoil effect in this
--     generation, so the attacker can never reach 0 HP mid-sequence here;
--     documented rather than coded as an unreachable branch. Damage
--     application itself is NOT duplicated -- both this path and the
--     ordinary single-hit path call the shared BattleEngine:applyDamage
--     helper (real Cmd_datahpupdate's HP-subtraction-floored-at-0 plus its
--     damage event and FIRST_BATTLE tip), matching this project's existing
--     shared-helper pattern.
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
-- EFFECT_DREAM_EATER=8: real BattleScript_EffectDreamEater
-- (data/battle_scripts_1.s:427) jumps straight to "wasn't affected" unless
-- the target's real status1 has STATUS1_SLEEP set -- a status-condition
-- precondition this engine doesn't model. supportsMove() rejects it
-- explicitly below so it doesn't fall through to the ordinary damage path
-- (its power field is > 0, so it would otherwise silently pass the
-- power > 0 check and run as ordinary undrained damage).
BattleEngine.EFFECT_DREAM_EATER = 8

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

-- The real recoil family: an ordinary damaging move that, immediately after
-- dealing damage, docks the ATTACKER's own HP by a fraction of the actual
-- (already-clamped) HP it just removed from the defender. Real
-- Cmd_seteffectsecondary / SetMoveEffect (src/battle_script_commands.c
-- ~2508 and ~2711): `gBattleMoveDamage = gHpDealt / divisor; if 0, force 1`.
-- `divisor` matches the real MOVE_EFFECT_RECOIL_25 (Take Down, Submission,
-- and Struggle -- all three real gBattleMoves entries literally share
-- EFFECT_RECOIL, confirmed against src/data/battle_moves.h) and
-- MOVE_EFFECT_RECOIL_33 (Double-Edge only) cases. Real BattleScript_
-- EffectRecoil/EffectDoubleEdge (data/battle_scripts_1.s) `setmoveeffect`
-- this with MOVE_EFFECT_CERTAIN before falling into BattleScript_EffectHit,
-- so it lands at the exact same real script position as the _HIT family's
-- seteffectwithchance step above -- but MOVE_EFFECT_CERTAIN means
-- Cmd_seteffectwithchance takes its certain-effect branch with NO Random()
-- roll at all (confirmed against that function's real body), unlike the
-- _HIT family's chance roll. Also confirmed: that same real function guards
-- BOTH its certain-effect branch and its chance-roll branch with
-- `!(gMoveResultFlags & MOVE_RESULT_NO_EFFECT)`, so recoil genuinely never
-- triggers on a type-immune hit (reachable in real play: Take Down/
-- Double-Edge are Normal-type, and Ghost is immune to Normal) -- ported by
-- simply placing this dispatch after resolveMove's existing noEffect early
-- return, same as the _HIT family.
BattleEngine.RECOIL_MOVES = {
  [48] = { divisor = 4 },  -- EFFECT_RECOIL (Take Down, Submission, Struggle)
  [198] = { divisor = 3 }, -- EFFECT_DOUBLE_EDGE (Double-Edge)
}

-- Real MOVE_STRUGGLE id (include/constants/moves.h). Used only by the
-- auto-Struggle trigger in resolveMove -- see the header's Struggle
-- paragraph. Struggle is never stored in a battler's move slots (real
-- gBattleMons[].moves never contains it); a caller's `moves` table needs
-- an entry keyed by this id for the trigger to have anything to resolve.
BattleEngine.MOVE_STRUGGLE = 165

-- The real drain family: EFFECT_ABSORB (Absorb, Mega Drain, Giga Drain,
-- Leech Life -- confirmed against src/data/battle_moves.h) heals the
-- attacker by a fraction of the actual HP just dealt. Real Cmd_negativedamage
-- (src/battle_script_commands.c:6643): `gBattleMoveDamage = -(gHpDealt /
-- divisor); if 0, force -1`. Unlike the recoil family, real
-- BattleScript_EffectAbsorb's `negativedamage` step is NOT gated behind a
-- MOVE_RESULT_NO_EFFECT check anywhere in the real script or the real
-- command itself -- it's a plain unconditional script instruction, not
-- routed through Cmd_seteffectwithchance at all. Taken completely literally
-- this means real Absorb would still force a 1-HP heal on an immune hit
-- using whatever gHpDealt happens to still hold from a previous, unrelated
-- datahpupdate call (real Cmd_datahpupdate leaves the gHpDealt global
-- entirely untouched -- not even zeroed -- when MOVE_RESULT_NO_EFFECT is
-- set, confirmed against that function's real body). That's not a
-- real per-move formula, it's stale/leftover global state from whatever
-- else happened earlier in the battle, and it is provably unreachable in
-- real FireRed play anyway: every EFFECT_ABSORB move is Grass (Absorb/Mega
-- Drain/Giga Drain) or Bug (Leech Life) type, and the real gTypeEffectiveness
-- table has zero immunities to either type, so a no-effect Absorb-family
-- hit can never happen on real hardware. Ported the same clean way as
-- recoil (skip on noEffect, via the existing early return) since that is
-- both behaviorally unreachable and the only sane choice for a stateless
-- per-move engine.
BattleEngine.DRAIN_MOVES = {
  [3] = { divisor = 2 }, -- EFFECT_ABSORB (Absorb, Mega Drain, Giga Drain, Leech Life)
}

-- The real multi-hit family: a single move selection that hits the
-- defender multiple times in one turn. Real BattleScript_EffectMultiHit /
-- BattleScript_EffectDoubleHit (data/battle_scripts_1.s): attackcanceler ->
-- accuracycheck -> attackstring -> ppreduce -> setmultihitcounter ->
-- initmultihitstring -> [BattleScript_MultiHitLoop]. Accuracy is checked
-- ONCE for the whole move (already done by the time resolveMove reaches
-- this dispatch) and PP is deducted ONCE -- neither repeats per hit.
-- `fixed` mirrors the real `setmultihitcounter` arg: EFFECT_DOUBLE_HIT
-- passes a literal 2 (Cmd_setmultihitcounter's nonzero-arg branch), so the
-- count is just 2 with ZERO hit-count Random() calls; EFFECT_MULTI_HIT
-- passes 0, running the roll branch (BattleFormulas.rollMultiHitCount) for
-- a real 2-5 hit count. Confirmed against src/data/battle_moves.h: no real
-- gBattleMoves entry uses EFFECT_DOUBLE_HIT differently (Double Kick and
-- Bonemerang both just use it plainly, no special-casing needed).
BattleEngine.MULTI_HIT_MOVES = {
  [29] = { fixed = nil }, -- EFFECT_MULTI_HIT (Double Slap, Comet Punch, Fury Attack, Pin Missile,
                          -- Spike Cannon, Barrage, Fury Swipes, Bone Rush, Arm Thrust, Bullet Seed,
                          -- Icicle Spear, Rock Blast): rolled 2-5 hits.
  [44] = { fixed = 2 },   -- EFFECT_DOUBLE_HIT (Double Kick, Bonemerang): always exactly 2 hits.
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
  if move.effect == BattleEngine.EFFECT_DREAM_EATER then return false end
  return move.power > 0 or BattleEngine.STAT_STAGE_MOVES[move.effect] ~= nil
end

-- Resolves one attack, appending its events. Returns nothing; the caller
-- checks for a faint. Mirrors BattleScript_HitFromAccCheck's real order.
function BattleEngine:resolveMove(attackerSide, moveSlot, events)
  local attacker = self:battler(attackerSide)
  local defenderSide = otherSide(attackerSide)
  local defender = self:battler(defenderSide)

  -- Real AreAllMovesUnusable (src/battle_util.c) checked BEFORE the caller's
  -- chosen slot is even looked at: CheckMoveLimitations ORs together several
  -- real reasons a slot can be unusable (0 PP, Disable, Torment, Taunt,
  -- Imprison, Encore, Choice Band lock), and if every one of the battler's
  -- move slots ends up unusable, `gProtectStructs[].noValidMoves` is set.
  -- This engine models none of those other mechanics (no status conditions,
  -- no Disable/Taunt/Imprison/Encore, no held items) -- confirmed by reading
  -- CheckMoveLimitations end to end, none of those fields exist anywhere in
  -- this codebase -- so for this engine the real condition reduces to
  -- exactly one checkable thing: every move slot the battler has is at 0 PP.
  local allMovesUnusable = true
  for i = 1, #attacker.moves do
    if attacker.moves[i].pp > 0 then
      allMovesUnusable = false
      break
    end
  end

  local slot, move
  if allMovesUnusable then
    -- Real battle_main.c (search noValidMoves): `gCurrentMove = gChosenMove
    -- = MOVE_STRUGGLE; gHitMarker |= HITMARKER_NO_PPDEDUCT`. The real move
    -- menu doesn't even let the player choose in this state -- it
    -- substitutes Struggle automatically -- so this is a precondition check
    -- on the whole battler, and it overrides whatever `moveSlot` the caller
    -- passed. There is no real move slot for Struggle (no `slot` local);
    -- ppreduce below must be skipped entirely for it.
    move = self.moves[BattleEngine.MOVE_STRUGGLE]
    if not move then
      error("battle needs a moves[" .. BattleEngine.MOVE_STRUGGLE ..
        "] (MOVE_STRUGGLE) entry for the auto-Struggle trigger")
    end
  else
    slot = attacker.moves[moveSlot]
    if not slot then
      error(("battler %s has no move in slot %d"):format(attackerSide, moveSlot))
    end
    move = self.moves[slot.move]
    if not move then
      error(("unknown move id %s"):format(tostring(slot.move)))
    end
  end

  if not self:supportsMove(move) then
    error(("unsupported move effect %d for non-damaging move %d")
      :format(move.effect or -1, slot and slot.move or BattleEngine.MOVE_STRUGGLE))
  end

  -- Defensive path only, real-game-unreachable: the caller selected a
  -- specific 0-PP slot while at least one OTHER slot of this battler still
  -- has PP (allMovesUnusable is false, so `slot` is set here, not Struggle).
  -- The real move-select menu greys out a 0-PP move and would never let a
  -- player submit this choice while another move remains available -- but
  -- this engine performs no UI-level move-menu validation, so a caller can
  -- still pass such a moveSlot. Don't crash, don't invent an action: keep
  -- the pre-existing no-op/noPP behavior for this specific unreachable case.
  if slot and slot.pp <= 0 then
    events[#events + 1] = { type = "noPP", side = attackerSide, move = slot.move }
    return
  end

  events[#events + 1] = {
    type = "useMove", side = attackerSide,
    move = slot and slot.move or BattleEngine.MOVE_STRUGGLE,
  }

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
  -- runs ppreduce). Real HITMARKER_NO_PPDEDUCT means Struggle (no `slot`,
  -- see above) skips this step entirely -- there is no move slot of its
  -- own to decrement.
  if slot then
    slot.pp = slot.pp - 1
  end

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

  -- The real multi-hit family (EFFECT_MULTI_HIT / EFFECT_DOUBLE_HIT): the
  -- move's single accuracy roll and single PP deduction already happened
  -- above; everything from here (hit-count roll, per-hit crit/damage/type,
  -- early-stop rules) is real BattleScript_MultiHitLoop territory, handled
  -- by resolveMultiHit. See BattleEngine.MULTI_HIT_MOVES for the exact real
  -- per-effect-id hit-count source.
  local multiHitEntry = BattleEngine.MULTI_HIT_MOVES[move.effect]
  if multiHitEntry then
    self:resolveMultiHit(attackerSide, attacker, defenderSide, defender, move, multiHitEntry, events)
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
  damage = self:applyDamage(attackerSide, defenderSide, defender, damage, flags, events)

  -- 8a. Recoil/drain: a real self-inflicted HP change derived from the
  -- actual, already-clamped `damage` just dealt (real gHpDealt). See
  -- BattleEngine.RECOIL_MOVES/DRAIN_MOVES for the exact real formulas and
  -- their per-family noEffect gating.
  --
  -- Real ordering (verified against data/battle_scripts_1.s):
  -- BattleScript_MoveEffectRecoil and BattleScript_EffectAbsorb both apply
  -- the attacker's own HP change and run `tryfaintmon BS_ATTACKER` BEFORE
  -- returning to the calling script, which only then runs
  -- `tryfaintmon BS_TARGET`. So a hit that both drops the defender to 0 and
  -- recoils/drains the attacker to 0 on the same swing resolves the
  -- attacker's own faint FIRST -- this is the real outcome even for a
  -- simultaneous double-KO. checkFaint is called here, for the attacker,
  -- before control returns to runTurn's existing defender-faint check.
  local recoilEntry = BattleEngine.RECOIL_MOVES[move.effect]
  if recoilEntry then
    local recoil = math.floor(damage / recoilEntry.divisor)
    if recoil == 0 then recoil = 1 end
    if recoil > attacker.hp then recoil = attacker.hp end
    attacker.hp = attacker.hp - recoil
    events[#events + 1] = {
      type = "recoil", side = attackerSide, amount = recoil, hpRemaining = attacker.hp,
    }
    if self:checkFaint(attackerSide, events) then
      return
    end
  end

  local drainEntry = BattleEngine.DRAIN_MOVES[move.effect]
  if drainEntry then
    local heal = math.floor(damage / drainEntry.divisor)
    if heal == 0 then heal = 1 end
    -- Real Cmd_datahpupdate's HP-goes-up branch clamps at maxHP (src/
    -- battle_script_commands.c ~1789-1794), matching this project's
    -- established heal-clamp pattern (e.g. WildPokemonFactory/
    -- BattlePartyBridge's math.max(0, math.min(maxHP, hp))).
    attacker.hp = math.max(0, math.min(attacker.maxHP, attacker.hp + heal))
    events[#events + 1] = {
      type = "drain", side = attackerSide, amount = heal, hpRemaining = attacker.hp,
    }
    -- Real BattleScript_EffectAbsorb also runs tryfaintmon BS_ATTACKER
    -- before BS_TARGET; a heal can never itself faint the attacker, but
    -- checkFaint is called here anyway for structural symmetry with the
    -- recoil path (and correctness if this table ever gains a
    -- Liquid-Ooze-style negative-drain entry).
    if self:checkFaint(attackerSide, events) then
      return
    end
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

-- Real datahpupdate's HP subtraction (floored at 0), plus the resulting
-- "damage" event and the FIRST_BATTLE damage-tutorial tip. Shared by the
-- ordinary single-hit path (resolveMove's step 7) and resolveMultiHit's
-- per-hit loop below, so the actual damage-application logic is written
-- once. Returns the real, already-clamped amount actually removed (what
-- real gHpDealt would hold), since callers like the recoil/drain dispatch
-- need that exact clamped figure, not the pre-clamp `damage` they passed in.
function BattleEngine:applyDamage(attackerSide, defenderSide, defender, damage, flags, events)
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
  return damage
end

-- Runs the real per-hit loop (BattleScript_MultiHitLoop, data/
-- battle_scripts_1.s) after the caller (resolveMove) has already checked
-- accuracy exactly once and deducted PP exactly once for the whole move --
-- neither repeats here. `entry.fixed` is EFFECT_DOUBLE_HIT's real fixed
-- `setmultihitcounter 2` arg (zero hit-count RNG); otherwise this is
-- EFFECT_MULTI_HIT and rolls the real 2-5 count via
-- BattleFormulas.rollMultiHitCount (its own RNG-draw-count doc explains the
-- variable 1-or-2-draw consumption).
--
-- Real per-iteration order: critcalc -> damagecalc -> typecalc ->
-- jumpifmovehadnoeffect (stop the WHOLE sequence right there, BEFORE
-- adjustnormaldamage even runs -- unlike the ordinary single-hit path
-- above, where adjustnormaldamage's random-multiplier Random() call always
-- runs before the noEffect check; the multi-hit script's noEffect branch
-- skips that Random() call entirely, since type doesn't change between
-- hits this is only ever reachable on the first hit, but the real script
-- structurally rechecks it every iteration and this ports that literally)
-- -> adjustnormaldamage -> apply damage -> tryfaintmon BS_TARGET. Real
-- BattleScript_MultiHitLoop also opens with `jumpifhasnohp BS_ATTACKER`
-- (jumps to MultiHitEnd) before the BS_TARGET check -- confirmed dead code
-- for every move this engine actually supports: no real EFFECT_MULTI_HIT
-- or EFFECT_DOUBLE_HIT move also carries a recoil effect in this
-- generation (checked against src/data/battle_moves.h's real records), so
-- the attacker can never reach 0 HP mid-sequence here. Not ported as a
-- branch; documented here instead, matching this file's existing practice
-- of noting confirmed-unreachable real branches rather than adding dead
-- code for them.
--
-- Event shape: this project's event stream is its own design, not real
-- FireRed's message system (see the header). Each landed hit reuses the
-- exact same {type="critical"}/{type="damage"} events the single-hit path
-- emits, one pair per landed hit, in order -- so a UI layer that already
-- knows how to animate a single hit needs no new event types to animate a
-- multi-hit sequence. A trailing {type="multiHit", hits=} event is emitted
-- only when the loop completes all its rolled/fixed hits without an early
-- stop (mirroring real STRINGID_HITXTIMES, which real
-- BattleScript_MultiHitPrintStrings only reaches when the move didn't end
-- in MOVE_RESULT_NO_EFFECT) -- an early stop from a mid-sequence faint
-- already ends the battle via checkFaint's own faint/battleEnd events,
-- which communicate the same "sequence is over" information, so no
-- separate multiHit summary is emitted in that terminal case.
function BattleEngine:resolveMultiHit(attackerSide, attacker, defenderSide, defender, move, entry, events)
  local hitCount
  if entry.fixed then
    hitCount = entry.fixed
  else
    hitCount = BattleFormulas.rollMultiHitCount(self.rng)
  end

  for i = 1, hitCount do
    -- Real jumpifhasnohp BS_TARGET (top of BattleScript_MultiHitLoop): stop
    -- immediately if an earlier hit in this same sequence already fainted
    -- the defender. Unreachable on i==1 (runTurn only calls resolveMove for
    -- a battler with hp > 0), but real for i>1.
    if defender.hp <= 0 then break end

    local rolledCrit = BattleFormulas.critRoll(self.rng, 0)
    local isCrit = rolledCrit and not (self.firstBattle and not self.tutorialPlayerDamageDone)

    local damage = BattleFormulas.calculateBaseDamage(attacker, defender, move, isCrit)
    if isCrit then
      damage = damage * BattleFormulas.CRIT_MULTIPLIER
    end

    local flags
    damage, flags = BattleFormulas.typeCalc(
      damage, move.type, attacker.types, defender.types, self.typeChart
    )

    if flags.noEffect then
      -- Real jumpifmovehadnoeffect: the ENTIRE sequence stops here, not
      -- just this one hit -- a type-immune target takes zero hits total.
      events[#events + 1] = { type = "noEffect", side = attackerSide, target = defenderSide }
      return
    end

    damage = BattleFormulas.applyRandomDamageMultiplier(damage, self.rng)

    if isCrit then
      events[#events + 1] = { type = "critical", side = attackerSide }
    end

    self:applyDamage(attackerSide, defenderSide, defender, damage, flags, events)

    -- Real tryfaintmon BS_TARGET, checked every iteration (not just once
    -- at the end) so the sequence stops the instant HP hits 0, matching
    -- the real per-iteration jumpifhasnohp check at the top of the loop.
    if self:checkFaint(defenderSide, events) then
      return
    end
  end

  events[#events + 1] = { type = "multiHit", side = attackerSide, hits = hitCount }
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

  -- Real SetActionsAndBattlersTurnOrder puts B_ACTION_SWITCH in the same
  -- early group as B_ACTION_USE_ITEM, both hoisted ahead of any move
  -- action regardless of speed. This engine stays fully party-agnostic --
  -- it has no idea what a "party slot" is -- so the caller (BattlePartyBridge)
  -- already did real eligibility filtering (Cmd_jumpifcantswitch: living,
  -- non-Egg, not the currently-active slot) and built the incoming battler
  -- via the same generic BattlePartyBridge.battlerFromParty this engine's
  -- initial lead already goes through. Real Cmd_switchindataupdate confirms
  -- an ordinary switch-in (not EFFECT_BATON_PASS, not implemented anywhere
  -- in this project) starts with neutral stat stages -- BattleEngine.
  -- makeBattler already defaults every stage to neutral, so simply swapping
  -- in the caller's freshly-built battler is correct with no extra reset
  -- step. Voluntary switching only: a faint still ends the battle exactly
  -- as documented above (the real forced switch-after-faint party-select
  -- prompt is a separate, unbuilt feature).
  if playerAction.action == "switch" then
    assert(playerAction.battler and playerAction.battler.hp > 0,
      "switch needs a caller-supplied, already-eligible battler")
    self.player = playerAction.battler
    events[#events + 1] = { type = "switch", side = BattleEngine.SIDE_PLAYER }
    self:resolveMove(BattleEngine.SIDE_FOE, foeAction.moveSlot, events)
    -- Same guard the capture/run branches below already use: a recoil/
    -- drain move can end the battle via the foe's own faint inside
    -- resolveMove before this checkFaint would otherwise re-check/
    -- overwrite that outcome.
    if not self:isOver() then
      self:checkFaint(BattleEngine.SIDE_PLAYER, events)
    end
    return events
  end

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
    -- A recoil/drain move can already have ended the battle via the foe's
    -- own faint inside resolveMove (see its real attacker-faints-first
    -- ordering note); don't re-check/overwrite the outcome if so.
    if not self:isOver() then
      self:checkFaint(BattleEngine.SIDE_PLAYER, events)
    end
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
    if not self:isOver() then
      self:checkFaint(BattleEngine.SIDE_PLAYER, events)
    end
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
      -- A recoil/drain move can already have ended the battle via the
      -- attacker's own faint inside resolveMove (real attacker-faints-first
      -- ordering -- see that function's step 8a). Don't let a defender that
      -- also happens to be at 0 HP re-check and overwrite the real outcome.
      if self:isOver() then
        return events
      end
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
