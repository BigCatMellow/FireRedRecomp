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
--   {type="forcedSwitchNeeded", side=}             -- fainted side has a real
--    living, eligible party replacement (caller-determined); the battle is
--    NOT over -- no {type="battleEnd"} follows -- but runTurn refuses to
--    start another turn until BattleEngine:resolveForcedSwitch(side,
--    newBattler) is called. See the header's forced-switch paragraph below.
--   {type="forcedSwitchResolved", side=}           -- resolveForcedSwitch
--    supplied the replacement; the battle may proceed normally again.
--   {type="noPP", side=, move=}                   -- see the Struggle stub
--   {type="statChange", side=<target>, stat=, stages=-1, prevented=}
--   {type="screenSet", side=, screen="reflect"|"lightScreen", turns=5}
--   {type="screenFailed", side=, screen="reflect"|"lightScreen"} -- already active
--   {type="screenExpired", side=, screen="reflect"|"lightScreen"} -- real 5-turn timer hit 0
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
--     only models the PP move-limitation (not Disable, Torment, Taunt,
--     Imprison, Encore, or held items), so the
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
--     Real Cmd_typecalc's MOVE_STRUGGLE special case is also ported: real
--     Struggle skips STAB and per-row type effectiveness entirely (`if
--     (gCurrentMove == MOVE_STRUGGLE) { gBattlescriptCurrInstr++; return;
--     }`), dealing plain neutral, unblockable damage even against a
--     normally-immune type (e.g. a Ghost-type). resolveMove flat-skips the
--     BattleFormulas.typeCalc call for MOVE_STRUGGLE rather than routing it
--     through the ordinary per-row type-chart walk with a fabricated
--     "always neutral" row.
--   * VOLUNTARY switching IS supported -- see the "switch" branch of
--     runTurn and BattlePartyBridge.findSwitchTargets/battlerFromParty. Real
--     SetActionsAndBattlersTurnOrder hoists B_ACTION_SWITCH into the same
--     early group as B_ACTION_USE_ITEM, resolved before any move regardless
--     of speed -- ported the same way capture/run already are: the switch
--     resolves immediately (no RNG), then the foe still attacks that same
--     turn. Real Cmd_switchindataupdate confirms an ordinary (non-Baton-Pass)
--     switch-in starts with neutral stat stages, which BattleEngine.
--     makeBattler already defaults to, so the caller-supplied incoming
--     battler needs no extra reset here. This engine stays fully
--     party-agnostic -- it has no idea what a "party slot" is;
--     BattlePartyBridge owns real switch-target eligibility
--     (Cmd_jumpifcantswitch: living, non-Egg, not the active slot).
--   * FORCED switch-after-faint IS supported -- see checkFaint's
--     `hasReplacement` dispatch and BattleEngine:resolveForcedSwitch. Real
--     control flow (verified end to end, not guessed): BattleTurnPassed
--     (src/battle_main.c:2953) runs DoFieldEndTurnEffects/
--     DoBattlerEndTurnEffects while `gBattleOutcome == 0`, THEN calls
--     HandleFaintedMonActions (src/battle_util.c:1144) -- which, per fainted
--     battler, executes BattleScript_HandleFaintedMon (data/
--     battle_scripts_1.s:2824). That script's `checkteamslost` step (Cmd_
--     checkteamslost, src/battle_script_commands.c:3385) is what actually
--     sets gBattleOutcome to WON/LOST, and it does so by summing each whole
--     TEAM's total HP, not by looking at the one battler that just fainted --
--     confirming the brief's assumption that a faint only ends the battle
--     when its side has no further living, non-Egg party member. The forced
--     party-select step itself is `openpartyscreen BS_FAINTED,
--     BattleScript_FaintedMonEnd` (that same script) -> Cmd_openpartyscreen
--     (src/battle_script_commands.c ~4855-4873): if HasNoMonsToSwitch, the
--     battler is marked permanently gAbsentBattlerFlags and the script falls
--     through to FaintedMonEnd (battle stays/ends exactly as this project's
--     pre-existing no-replacement case already did); otherwise real FireRed
--     blocks on a party-select menu (BtlController_EmitChoosePokemon) before
--     the NEXT turn's action selection can even begin -- ported as
--     BattleEngine.awaitingForcedSwitch, a side string that blocks runTurn
--     (see its top assert) until BattleEngine:resolveForcedSwitch(side,
--     newBattler) supplies the caller-built replacement (built the same
--     BattlePartyBridge.battlerFromParty way as any other switch-in, so it
--     already starts with neutral stat stages -- see the voluntary-switch
--     paragraph above; no separate reset is needed here either).
--     WHICH side(s): this engine has no idea what "trainer battle" or "wild
--     battle" even mean (party-agnostic, same as everywhere else in this
--     file) -- so `hasReplacement` is a plain caller-supplied
--     `function(side) -> boolean` passed to BattleEngine.new(), mirroring
--     how BattlePartyBridge.findSwitchTargets already answers the identical
--     question for voluntary switching. A wild encounter's caller simply
--     never returns true for the foe side (a lone wild Pokemon's "team" is
--     always exactly one, matching real GetMonData total-HP-of-party==0
--     immediately); a trainer battle's caller can return true for either
--     side. Omitting `hasReplacement` entirely (nil) preserves this
--     project's exact pre-existing behavior -- every faint ends the battle,
--     zero risk of regressing any caller or test that predates this feature.
--     DOES a faint interrupt the rest of the turn: real Cmd_attackcanceler
--     (src/battle_script_commands.c:819) opens every single move's battle
--     script with `if (gBattleMons[gBattlerAttacker].hp == 0) { ... jump to
--     BattleScript_MoveEnd }` -- i.e. a fainted battler's OWN next scheduled
--     action silently no-ops. Combined with this engine's strict
--     one-action-per-side-per-turn shape, the only battler that can still be
--     scheduled to act after a same-turn faint is the one that just fainted
--     (the other side, if it hadn't moved yet, already has nothing left to
--     out-order it with) -- so this project's pre-existing "stop resolving
--     the turn immediately on any faint" structure was already exactly
--     correct for the ordinary defender-faints-from-attacker's-hit case, and
--     needed no change. The one real subtlety this project's recoil/drain
--     work had not yet had to confront: EFFECT_RECOIL can faint the
--     ATTACKER itself (checkFaint(attackerSide,...) inside resolveMove)
--     while the DEFENDER is still alive and has not yet acted this turn --
--     real per-battler-slot scripting has no explicit "is my target's
--     replacement pending" gate for this, so rather than chase that
--     unverified edge case, runTurn conservatively also halts remaining
--     action processing whenever self.awaitingForcedSwitch is set (not just
--     when isOver()), matching this project's existing bias toward stopping
--     the turn the instant any faint changes battle state.
--     Reflect/Light Screen timers ARE still decayed on a turn that ends in a
--     pending forced switch (but NOT on a turn that ends the whole battle):
--     real BattleTurnPassed calls DoFieldEndTurnEffects/
--     DoBattlerEndTurnEffects BEFORE HandleFaintedMonActions -- the function
--     that actually computes gBattleOutcome via checkteamslost -- so
--     `gBattleOutcome == 0` (decaySideTimers' existing real gate, see its
--     own comment below) is STILL true on the very turn a battler faints
--     with a replacement pending, and only becomes nonzero once
--     checkteamslost later finds a whole team at 0 HP. Ported for free: a
--     pending forced switch leaves self.outcome nil (isOver() stays false),
--     so decaySideTimers' pre-existing `not self:isOver()` guards already do
--     the right real thing without needing their own edit; only the
--     "stop processing more actions" guards needed the extra
--     awaitingForcedSwitch check described above.
--   * Some major status conditions (sleep, poison, toxic, paralysis, burn,
--     and freeze) are supported; confusion, abilities, held items,
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
--     Still explicitly not ported: non-pure-single-stat effects other than
--     Haze, Mist, Focus Energy, and Rest (EFFECT_TRANSFORM, etc).
--     supportsMove() correctly rejects those.
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
--     EFFECT_DREAM_EATER=8 is also ported: its source-specific sleeping
--     target check runs before PP and accuracy, then it shares Absorb's
--     half-damage healing path. EFFECT_RECOIL_IF_MISS=45 is ported too.
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
--   * Reflect and Light Screen ARE supported -- see BattleEngine.
--     SCREEN_MOVES, resolveMove's move.power==0 dispatch, resolveScreenMove,
--     decaySideTimers, and BattleFormulas.calculateBaseDamage's screen
--     halving. Real EFFECT_REFLECT=65 (MOVE_REFLECT only) and
--     EFFECT_LIGHT_SCREEN=35 (MOVE_LIGHT_SCREEN only) -- confirmed against
--     src/data/battle_moves.h. Real BattleScript_EffectReflect/
--     EffectLightScreen (data/battle_scripts_1.s): attackcanceler ->
--     attackstring -> ppreduce -> setreflect/setlightscreen -> [message] ->
--     MoveEnd -- NO accuracycheck step, the same self-target
--     (MOVE_TARGET_USER), zero-RNG shape as STAT_STAGE_MOVES' self-target
--     UP family, so this reuses that exact "no accuracy roll" detection
--     rather than a separate mechanism. Real Cmd_setreflect/
--     Cmd_setlightscreen (src/battle_script_commands.c): if the CASTER's
--     own side already has the status active, it's a real no-op failure
--     (MOVE_RESULT_MISSED, a "but it failed" message, no RNG, no state
--     change, timer NOT refreshed) -- otherwise the flag sets on the
--     caster's own side and a real 5-turn gSideTimers[side].reflectTimer/
--     lightscreenTimer = 5 starts. This engine tracks that per-side state
--     in BattleEngine.new()'s new self.sideStatus table (keyed by side
--     string, since it's genuinely a per-SIDE status, outliving a
--     voluntary switch on that side -- real gSideStatuses is never reset by
--     an ordinary switch-in).
--
--     Damage-halving: real CalculateBaseDamage (src/pokemon.c) applies
--     Reflect (physical branch, ~2542) / Light Screen (special branch,
--     ~2600) in the exact real order `.../50 -> (burn halving, not
--     modeled) -> Reflect/Light Screen halving -> (double-battle halving,
--     not modeled) -> minimum-1 clamp`, tested against the DEFENDER's own
--     side (real `sideStatus` param is the defender's, not the attacker's)
--     and gated on a non-crit hit only (real `&& gCritMultiplier == 1` --
--     a crit bypasses screens entirely). This project's pre-existing code
--     applied its minimum-1 clamp immediately after the `/50` step, with
--     no slot for a halving step before that clamp -- fixed by moving the
--     physical branch's clamp to AFTER the new Reflect halving (separately
--     from the special branch's Light Screen halving, matching how the
--     real function has two nearly-identical but distinct blocks), so a
--     1-damage physical hit halved by Reflect truncates to 0 and is then
--     correctly clamped back up to 1 by the same real `if (damage == 0)
--     damage = 1` clamp -- not a special "Reflect can't reduce below 1"
--     rule, and not the wrong "clamp to 1 first, then halve to 0" order.
--     The special branch genuinely has no such clamp in real source, with
--     or without Light Screen -- a special hit Light Screen halves to 0
--     legitimately stays 0, ported unchanged. Real double-battle
--     `2 * (damage / 3)` variant and the real double-battle-specific
--     message id are out of scope (single battle only, matching this
--     project's whole scope).
--
--     End-of-turn decay: real ENDTURN_REFLECT/ENDTURN_LIGHT_SCREEN cases of
--     DoFieldEndTurnEffects (src/battle_util.c) -- the first "end of turn"
--     phase this engine has, added as BattleEngine:decaySideTimers, called
--     from runTurn. Real BattleTurnPassed (src/battle_main.c:2953) only
--     runs DoFieldEndTurnEffects when `gBattleOutcome == 0` (the battle is
--     still continuing after every action chosen for the turn has
--     finished) -- confirmed by reading HandleEndTurn_ContinueBattle, this
--     is NOT conditioned on "an ordinary move exchange happened": it also
--     fires after a switch-only turn or a failed capture/run attempt,
--     since none of those decide gBattleOutcome. Only a turn that DOES
--     decide the outcome this turn (a successful catch, a successful run,
--     or a faint) skips it. Ported as `not self:isOver()` guards at every
--     one of runTurn's normal-exit points (the switch branch, the
--     failed-capture path, the failed-run path, and the ordinary two-move
--     loop's fall-through), mirroring the real gBattleOutcome==0 gate
--     exactly rather than gating on action type. Each active timer
--     decrements by 1 (real per-side order: side 0 then side 1, ported as
--     player then foe); reaching 0 clears the status and this project
--     emits a {type="screenExpired"} event (real
--     BattleScript_SideStatusWoreOff's message, adapted to this project's
--     event-stream style rather than a string-table system it doesn't
--     have).
--
--     Not ported: Safeguard/Mist (separate real effect ids with different
--     real mechanics -- status-condition blocking and stat-lowering
--     blocking respectively, neither of which this task covers) and Brick
--     Break's real screen-removal special case
--     (src/battle_script_commands.c ~9445) -- a different move entirely.
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
BattleEngine.EFFECT_MIRROR_MOVE = 9
BattleEngine.EFFECT_CONFUSE = 49
BattleEngine.EFFECT_CONFUSE_HIT = 76
BattleEngine.EFFECT_FLINCH_HIT = 31
BattleEngine.EFFECT_FLINCH_MINIMIZE_HIT = 150
BattleEngine.EFFECT_EXPLOSION = 7
BattleEngine.EFFECT_BIDE = 26
BattleEngine.EFFECT_RAMPAGE = 27
BattleEngine.EFFECT_TRAP = 42
BattleEngine.EFFECT_DESTINY_BOND = 98
BattleEngine.EFFECT_MIMIC = 82
BattleEngine.EFFECT_SKETCH = 95
BattleEngine.EFFECT_SLEEP_TALK = 97
BattleEngine.EFFECT_ATTRACT = 120
BattleEngine.EFFECT_CAMOUFLAGE = 213
BattleEngine.EFFECT_NATURE_POWER = 173
-- sTerrainToType from Cmd_settypetoterrain (FireRed battle_script_commands.c).
BattleEngine.TERRAIN_TYPES = { [0]=12, [1]=12, [2]=4, [3]=11, [4]=11,
  [5]=11, [6]=5, [7]=5, [8]=0, [9]=0 }
BattleEngine.TERRAIN_NATURE_POWER_MOVES = { [0]=78, [1]=75, [2]=89, [3]=56,
  [4]=57, [5]=61, [6]=157, [7]=247, [8]=129, [9]=129 }
BattleEngine.EFFECT_SUBSTITUTE = 79
BattleEngine.EFFECT_TRANSFORM = 57
BattleEngine.EFFECT_PAY_DAY = 34
BattleEngine.EFFECT_TELEPORT = 153
BattleEngine.EFFECT_RAGE = 81
BattleEngine.EFFECT_ALWAYS_HIT = 17
BattleEngine.EFFECT_VITAL_THROW = 78
BattleEngine.EFFECT_RETURN = 121
BattleEngine.EFFECT_FRUSTRATION = 123
BattleEngine.EFFECT_HIDDEN_POWER = 135
BattleEngine.EFFECT_DEFENSE_CURL = 156
BattleEngine.EFFECT_SOFTBOILED = 157
BattleEngine.EFFECT_SLEEP = 1
BattleEngine.EFFECT_POISON_HIT = 2
BattleEngine.EFFECT_BURN_HIT = 4
BattleEngine.EFFECT_POISON = 66
BattleEngine.EFFECT_PARALYZE_HIT = 6
BattleEngine.EFFECT_PARALYZE = 67
BattleEngine.EFFECT_WILL_O_WISP = 167
BattleEngine.EFFECT_TOXIC = 33
BattleEngine.EFFECT_FREEZE_HIT = 5
BattleEngine.EFFECT_THAW_HIT = 125
BattleEngine.EFFECT_SPITE = 100
BattleEngine.EFFECT_SPLASH = 85
BattleEngine.EFFECT_CONVERSION = 30
BattleEngine.EFFECT_PRESENT = 122
BattleEngine.EFFECT_OHKO = 38
BattleEngine.EFFECT_HAZE = 25
BattleEngine.EFFECT_MIST = 46
BattleEngine.EFFECT_FOCUS_ENERGY = 47
BattleEngine.EFFECT_RAIN_DANCE = 136
BattleEngine.EFFECT_SUNNY_DAY = 137
BattleEngine.EFFECT_SANDSTORM = 115
BattleEngine.EFFECT_HAIL = 164
BattleEngine.EFFECT_THUNDER = 152
BattleEngine.EFFECT_CHARGE = 174
BattleEngine.EFFECT_MUD_SPORT = 201
BattleEngine.EFFECT_WATER_SPORT = 210
BattleEngine.EFFECT_SEMI_INVULNERABLE = 155
BattleEngine.EFFECT_EARTHQUAKE = 147
BattleEngine.EFFECT_GUST = 149
BattleEngine.EFFECT_SKY_UPPERCUT = 207
BattleEngine.EFFECT_FUTURE_SIGHT = 148
BattleEngine.EFFECT_UPROAR = 159
BattleEngine.EFFECT_STOCKPILE = 160
BattleEngine.EFFECT_SPIT_UP = 161
BattleEngine.EFFECT_SWALLOW = 162
BattleEngine.EFFECT_TORMENT = 165
BattleEngine.EFFECT_TAUNT = 175
BattleEngine.EFFECT_IMPRISON = 192
BattleEngine.EFFECT_ENCORE = 90
BattleEngine.EFFECT_DISABLE = 86

-- Core games identify the phase from the move id, not its effect id. Mods
-- may instead set `semiInvulnerableKind` directly on a move record.
BattleEngine.SEMI_INVULNERABLE_KINDS = {
  [19] = "air", [91] = "underground", [291] = "underwater", [340] = "air",
}

-- `true` means the move can hit; 2 is the retail doubled-damage variant.
BattleEngine.SEMI_INVULNERABLE_HITS = {
  air = { [146] = 2, [149] = 2, [152] = true, [207] = true },
  underground = { [126] = 2, [147] = 2, [38] = true },
  underwater = { [57] = 2, [250] = 2 },
}
BattleEngine.EFFECT_PROTECT = 111
BattleEngine.EFFECT_SPIKES = 112
BattleEngine.EFFECT_RAPID_SPIN = 129
BattleEngine.EFFECT_FLAIL = 99
BattleEngine.EFFECT_ERUPTION = 190
BattleEngine.EFFECT_MAGNITUDE = 126
BattleEngine.EFFECT_PSYWAVE = 88
BattleEngine.EFFECT_COUNTER = 89
BattleEngine.EFFECT_SUPER_FANG = 40
BattleEngine.EFFECT_DRAGON_RAGE = 41
BattleEngine.EFFECT_SONICBOOM = 130
BattleEngine.EFFECT_BRICK_BREAK = 186
BattleEngine.EFFECT_FALSE_SWIPE = 101
BattleEngine.EFFECT_LEVEL_DAMAGE = 87
BattleEngine.EFFECT_RESTORE_HP = 32
BattleEngine.EFFECT_REST = 37
BattleEngine.EFFECT_YAWN = 187
BattleEngine.EFFECT_LEECH_SEED = 84
BattleEngine.EFFECT_REFRESH = 193
BattleEngine.EFFECT_INGRAIN = 181
BattleEngine.EFFECT_MORNING_SUN = 132
BattleEngine.EFFECT_SYNTHESIS = 133
BattleEngine.EFFECT_MOONLIGHT = 134
BattleEngine.EFFECT_BELLY_DRUM = 142
BattleEngine.EFFECT_PSYCH_UP = 143
BattleEngine.EFFECT_PAIN_SPLIT = 91
BattleEngine.EFFECT_MIRROR_COAT = 144
BattleEngine.EFFECT_WEATHER_BALL = 203
BattleEngine.EFFECT_OVERHEAT = 204
BattleEngine.EFFECT_SUPERPOWER = 182
BattleEngine.EFFECT_TICKLE = 205
BattleEngine.EFFECT_ENDEAVOR = 189
BattleEngine.EFFECT_FOCUS_PUNCH = 170
BattleEngine.EFFECT_MEMENTO = 168
BattleEngine.MULTI_STAT_UP_MOVES = {
  [206] = { "defense", "spDefense" }, [208] = { "attack", "defense" },
  [211] = { "spAttack", "spDefense" }, [212] = { "attack", "speed" },
}
BattleEngine.EFFECT_ENDURE = 116
BattleEngine.HIGH_CRITICAL_EFFECTS = { [43] = true, [75] = true, [200] = true, [209] = true }
local SANDSTORM_IMMUNE_TYPES = { [4] = true, [5] = true, [8] = true } -- Ground, Rock, Steel

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
  [108] = { stat = "evasion",  delta =  1 }, -- EFFECT_MINIMIZE
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
  [63] = { stat = "accuracy",  delta = -2 }, -- EFFECT_ACCURACY_DOWN_2
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

-- Ancient Power and Silver Wind use MOVE_EFFECT_ALL_STATS_UP after a landed
-- hit, so their normal secondary-effect roll raises each non-HP battle stat
-- of the user by one stage.
BattleEngine.HIT_VARIANT_ALL_STATS_UP = { [140] = true }

-- Damaging moves whose BattleScript_Effect*Hit route installs a normal
-- chance-based nonvolatile status through Cmd_seteffectwithchance. The
-- status state stays canonical; this table only describes the source effect
-- and eligibility gates that this abilityless engine can represent.
BattleEngine.HIT_VARIANT_STATUS_MOVES = {
  [2] = { status=8,  event="poison", typeImmune={3, 8} }, -- EFFECT_POISON_HIT
  [4] = { status=16, event="burn", typeImmune={10} }, -- EFFECT_BURN_HIT
  [5] = { status=32, event="freeze", typeImmune={15}, blockedBySun=true },
  [6] = { status=64, event="paralyze" }, -- EFFECT_PARALYZE_HIT
  [200] = { status=16, event="burn", typeImmune={10} }, -- EFFECT_BLAZE_KICK
  [202] = { status=128, event="toxic", typeImmune={3, 8} }, -- EFFECT_POISON_FANG
  [209] = { status=8, event="poison", typeImmune={3, 8} }, -- EFFECT_POISON_TAIL
}

BattleEngine.HIT_VARIANT_CONFUSE_MOVES = { [76] = true } -- EFFECT_CONFUSE_HIT
BattleEngine.HIT_VARIANT_FLINCH_MOVES = {
  [31] = true, [92] = true, [146] = true, [150] = true,
  [75] = true,
} -- EFFECT_FLINCH_HIT, SNORE, TWISTER, FLINCH_MINIMIZE_HIT, SKY_ATTACK

-- Swagger and Flatter are opponent-target status moves that first raise one
-- stat, then apply the ordinary primary confusion effect. Keeping this
-- declarative makes the shared ordering explicit without special-casing
-- move ids in the zero-power branch.
BattleEngine.CONFUSE_STAT_MOVES = {
  [118] = { stat="attack", delta=2 }, -- EFFECT_SWAGGER
  [166] = { stat="spAttack", delta=1 }, -- EFFECT_FLATTER
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
BattleEngine.MOVE_ENCORE = 227
BattleEngine.MOVE_MIRROR_MOVE = 119
BattleEngine.MOVE_METRONOME = 118
BattleEngine.MOVE_SLEEP_TALK = 214
BattleEngine.MOVE_ASSIST = 274
BattleEngine.MIMIC_FORBIDDEN_MOVES = {
  [68]=true, [102]=true, [118]=true, [165]=true, [166]=true, [168]=true,
  [182]=true, [194]=true, [197]=true, [203]=true, [214]=true, [243]=true,
  [264]=true, [266]=true, [270]=true, [271]=true, [289]=true, [343]=true,
}

-- Cmd_seteffect/SetMoveEffect suppress target-directed volatile, status,
-- and stat effects while STATUS2_SUBSTITUTE is live.  This explicit effect
-- table is intentionally separate from damage interception: mods can
-- declare `ignoresSubstitute=true` without copying engine logic, while
-- exceptions (self effects, Haze, Perish Song, Psych Up) stay explicit.
BattleEngine.SUBSTITUTE_BLOCKED_TARGET_EFFECTS = {
  [1]=true, [33]=true, [49]=true, [66]=true, [67]=true, [84]=true,
  [86]=true, [90]=true, [91]=true, [94]=true, [100]=true, [106]=true,
  [107]=true, [109]=true, [113]=true, [118]=true, [165]=true, [166]=true,
  [167]=true, [175]=true, [187]=true, [199]=true, [205]=true,
}

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
  [8] = { divisor = 2 }, -- EFFECT_DREAM_EATER
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
  [77] = { fixed = 2, secondaryStatus = "poison" }, -- EFFECT_TWINEEDLE: two hits, then one poison roll.
  [104] = { fixed = 3, perHitAccuracy = true, growingPower = 10 }, -- EFFECT_TRIPLE_KICK.
}

-- The real screen family: a self-target (real MOVE_TARGET_USER, same
-- targeting bit as STAT_STAGE_MOVES' self-target UP branch) side-wide
-- damage-halving status. Real EFFECT_REFLECT=65 (MOVE_REFLECT only) and
-- EFFECT_LIGHT_SCREEN=35 (MOVE_LIGHT_SCREEN only) -- confirmed against
-- src/data/battle_moves.h, no other real gBattleMoves entry uses either
-- id. Real BattleScript_EffectReflect/EffectLightScreen (data/
-- battle_scripts_1.s): attackcanceler -> attackstring -> ppreduce ->
-- setreflect/setlightscreen -> [message] -> MoveEnd -- NO accuracycheck
-- step at all, exactly the same shape as STAT_STAGE_MOVES' self-target UP
-- family, so resolveMove's existing isSelfTargetStat detection is
-- extended to cover this table too rather than duplicating the "0 RNG,
-- can't miss" logic. The string value is the key into
-- BattleEngine's per-side sideStatus table (see BattleEngine.new) and
-- doubles as the suffix of its paired Timer field ("reflect" ->
-- .reflect/.reflectTimer, "lightScreen" -> .lightScreen/.lightScreenTimer).
BattleEngine.SCREEN_MOVES = {
  [65] = "reflect",     -- EFFECT_REFLECT (Reflect)
  [35] = "lightScreen", -- EFFECT_LIGHT_SCREEN (Light Screen)
}
BattleEngine.SIDE_STATUS_MOVES = {
  [46] = "mist", -- EFFECT_MIST: Cmd_setmist, 5 turns.
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
    gender = opts.gender,
    -- Optional until live wild-mon construction is persistent. Required
    -- only when the player selects the bounded capture action; this is the
    -- real gSpeciesInfo[species].catchRate consumed by handleballthrow.
    catchRate = opts.catchRate,
    level = opts.level,
    -- Stored as MON_DATA_FRIENDSHIP in BoxPokemon's growth substructure.
    -- The default is the real species-default friendship used by generated
    -- Pokémon when a caller has no more-specific canonical value.
    friendship = opts.friendship == nil and 70 or opts.friendship,
    ivs = opts.ivs or { hp=0, attack=0, defense=0, speed=0, spAttack=0, spDefense=0 },
    -- Raw Gen III status word. Keeping this canonical source value on the
    -- battler lets rules consume it without reaching back into save records.
    status = opts.status or 0,
    types = { opts.types[1], opts.types[2] },
    maxHP = stats.hp,
    hp = opts.hp or stats.hp,
    attack = stats.attack,
    defense = stats.defense,
    speed = stats.speed,
    spAttack = stats.spAttack,
    spDefense = stats.spDefense,
    -- STATUS2_FOCUS_ENERGY: set by EFFECT_FOCUS_ENERGY and consumed by
    -- Cmd_critcalc as critical-hit stage 2 for this battler.
    focusEnergy = false,
    protected = false,
    endured = false,
    protectUses = 0,
    lastMove = nil,
    lastMoveEffect = nil,
    permanentMoveChanges = {},
    infatuatedBy = opts.infatuatedBy,
    lastHitType = nil,
    lockOnTurns = opts.lockOnTurns or 0,
    lockOnBy = opts.lockOnBy,
    nightmare = opts.nightmare or false,
    cursed = opts.cursed or false,
    trappedBy = opts.trappedBy,
    foresight = opts.foresight or false,
    perishTimer = opts.perishTimer,
    grudge = opts.grudge or false,
    destinyBond = opts.destinyBond or false,
    damagedByThisTurn = nil,
    physicalDamageThisTurn = nil,
    specialDamageThisTurn = nil,
    -- EFFECT_BIDE stores direct HP lost while its user is locked, then
    -- releases twice that total after its two charging turns.
    bideTurns = 0,
    bideDamage = 0,
    bideMove = nil,
    furyCutterCount = 0,
    -- EFFECT_ROLLOUT retains its selected move and remaining hit count.
    rolloutTurns = 0,
    rolloutMove = nil,
    rampageTurns = opts.rampageTurns or 0,
    rampageMove = opts.rampageMove,
    -- STATUS2_WRAPPED: binding moves trap the target for 3–6 turns.
    trappedTurns = opts.trappedTurns or 0,
    trappedBy = opts.trappedBy,
    trappedMove = opts.trappedMove,
    -- STATUS2_SUBSTITUTE plus DisableStruct.substituteHP.  The HP belongs
    -- to the decoy, never the Pokemon, so it is deliberately a separate
    -- canonical field rather than an alternate view of `hp`.
    substituteHP = opts.substituteHP or 0,
    -- STATUS2_TRANSFORMED. The copied active-battle properties below are
    -- temporary: an ordinary switch constructs a fresh battler.
    transformed = opts.transformed or false,
    defenseCurled = false,
    -- STATUS3_CHARGED_UP plus DisableStruct.chargeTimer. Kept as a raw
    -- turn counter so imports/mods can seed the same canonical state.
    chargeTurns = opts.chargeTurns or 0,
    -- STATUS3_MUDSPORT / STATUS3_WATERSPORT persist while this battler is
    -- active. The damage modifier is field-wide, not side-restricted.
    mudSport = opts.mudSport or false,
    waterSport = opts.waterSport or false,
    semiInvulnerableMove = opts.semiInvulnerableMove,
    semiInvulnerableKind = opts.semiInvulnerableKind,
    -- gWishFutureKnock stores this on the target battler, not its source.
    futureAttack = opts.futureAttack,
    uproarTurns = opts.uproarTurns or 0,
    uproarMove = opts.uproarMove,
    stockpileCount = opts.stockpileCount or 0,
    -- STATUS2_TORMENT: persists until this active battler leaves battle.
    tormented = opts.tormented or false,
    -- STATUS3_IMPRISONED_OTHERS: this active battler seals matching moves.
    imprisoning = opts.imprisoning or false,
    -- DisableStruct.encoredMove / encoreTimer, stored by move id so modded
    -- move lists and reordered slots preserve the same canonical state.
    encoreTurns = opts.encoreTurns or 0,
    encoreMove = opts.encoreMove,
    -- DisableStruct.disabledMove / disableTimer.
    disabledTurns = opts.disabledTurns or 0,
    disabledMove = opts.disabledMove,
    -- DisableStruct.tauntTimer. Taunt prevents zero-power moves, which is
    -- the retail definition and keeps modded status moves data-driven.
    tauntTurns = opts.tauntTurns or 0,
    rageActive = false,
    -- STATUS2_RECHARGE / DisableStruct.rechargeTimer, set by the Hyper Beam
    -- family after a successful hit and consumed by the next action.
    recharging = opts.recharging or false,
    rechargeMove = opts.rechargeMove,
    -- STATUS3_MINIMIZED, set separately from its one-stage evasion raise.
    minimized = opts.minimized or false,
    skullBashMove = opts.skullBashMove,
    twoTurnMove = opts.twoTurnMove,
    -- Canonical STATUS2_CONFUSION's low three-bit 2–5 turn counter. It is
    -- intentionally separate from persistent status1 and vanishes on switch.
    confusionTurns = opts.confusionTurns or 0,
    flinched = false,
    -- Real DisableStruct.isFirstTurn. Fake Out checks this state, which is
    -- initialized on battle entry and every later switch-in.
    firstTurn = opts.firstTurn ~= false,
    enteredThisTurn = false,
    -- Canonical STATUS3_YAWN's two-turn delayed-sleep counter.
    yawnTurns = opts.yawnTurns or 0,
    -- Persistent only while active; ordinary switching constructs a fresh
    -- battler, matching STATUS3_LEECHSEED clearing on switch-out.
    leechSeededBy = opts.leechSeededBy,
    rooted = opts.rooted or false,
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
--   canEscape   -- optional true/false or `function(side, move, engine) ->
--                  boolean`; Teleport uses it after PP reduction. Omitted
--                  means true (wild-battle behavior). Trainer callers pass
--                  false; mods can model escape-blocking effects here.
--   hasReplacement -- optional `function(side) -> boolean`. checkFaint calls
--                  this when a battler faints to decide real
--                  BattleScript_HandleFaintedMon's fork (see the header's
--                  forced-switch paragraph): true means the side has a
--                  living, eligible party replacement, so the battle blocks
--                  on BattleEngine:resolveForcedSwitch instead of ending.
--                  Omitted (nil) reproduces this project's exact
--                  pre-existing behavior -- every faint ends the battle.
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
    battleTerrain = opts.battleTerrain or 9, -- BATTLE_TERRAIN_PLAIN
    -- Optional ModHooks instance. The engine itself stays deterministic when
    -- absent; when present it exposes `battle.resolveMove` around the exact
    -- resolver below, letting mods observe/extend real battle state without
    -- replacing this module or mutating imported move data in place.
    hooks = opts.hooks,
    turn = 0,
    runTries = 0, -- real gBattleStruct->runTries
    -- gPaydayMoney accumulates during a battle and is awarded only by the
    -- caller's completed-battle reward path.
    paydayMoney = opts.paydayMoney or 0,
    -- Real gSideStatuses/gSideTimers, reduced to the two fields this slice
    -- models (SIDE_STATUS_REFLECT/SIDE_STATUS_LIGHTSCREEN and their paired
    -- reflectTimer/lightscreenTimer, src/battle_util.c). Keyed by side
    -- string (matching this engine's SIDE_PLAYER/SIDE_FOE convention, not
    -- the real battler-index side) since this is a per-SIDE status, not
    -- per-battler -- it survives a voluntary switch on that side (real
    -- gSideStatuses is never cleared on an ordinary switch-in; only a
    -- fainted mon's whole side leaving battle would matter, which this
    -- bounded 1v1 engine doesn't model).
    sideStatus = {
      [BattleEngine.SIDE_PLAYER] = { reflect = false, reflectTimer = 0, lightScreen = false, lightScreenTimer = 0, mist = false, mistTimer = 0, safeguard = false, safeguardTimer = 0, wishTimer = 0, spikes = 0 },
      [BattleEngine.SIDE_FOE] = { reflect = false, reflectTimer = 0, lightScreen = false, lightScreenTimer = 0, mist = false, mistTimer = 0, safeguard = false, safeguardTimer = 0, wishTimer = 0, spikes = 0 },
    },
    -- Temporary move weather only. Permanent ability/field weather is not
    -- modeled in this bounded single-battle slice.
    weather = { kind = nil, timer = 0 },
    firstBattle = opts.firstBattle == true,
    -- Teleport calls GetIfCanRunFromBattle after PP reduction.  Callers
    -- supply false for trainer battles; mods may supply a predicate for
    -- custom escape-blocking field effects or abilities.
    canEscape = opts.canEscape == nil and true or opts.canEscape,
    tutorialPlayerDamageDone = false,
    tutorialPlayerStatDone = false,
    outcome = nil,
    -- See BattleEngine.new's opts doc and the header's forced-switch
    -- paragraph. hasReplacement is caller-supplied and optional; nil means
    -- "no party tracking", so checkFaint always ends the battle exactly as
    -- it did before this feature existed.
    hasReplacement = opts.hasReplacement,
    -- Real gAbsentBattlerFlags-adjacent blocking state: the side string
    -- ("player"/"foe") whose fainted battler still needs a caller-supplied
    -- replacement via resolveForcedSwitch, or nil when no forced switch is
    -- pending. runTurn refuses to start another turn while this is set (see
    -- its top assert) -- the real analogue of real FireRed blocking on the
    -- party-select menu before HandleTurnActionSelectionState can run again.
    awaitingForcedSwitch = nil,
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
    or BattleEngine.SCREEN_MOVES[move.effect] ~= nil
    or BattleEngine.SIDE_STATUS_MOVES[move.effect] ~= nil
    or move.effect == BattleEngine.EFFECT_FOCUS_ENERGY
    or move.effect == BattleEngine.EFFECT_RAIN_DANCE
    or move.effect == BattleEngine.EFFECT_SUNNY_DAY
    or move.effect == BattleEngine.EFFECT_SANDSTORM
    or move.effect == BattleEngine.EFFECT_HAIL
    or move.effect == BattleEngine.EFFECT_PROTECT
    or move.effect == BattleEngine.EFFECT_SPIKES
    or move.effect == BattleEngine.EFFECT_ENDURE
    or move.effect == BattleEngine.EFFECT_HAZE
    or move.effect == BattleEngine.EFFECT_RESTORE_HP
    or move.effect == BattleEngine.EFFECT_REST
    or move.effect == BattleEngine.EFFECT_YAWN
    or move.effect == BattleEngine.EFFECT_LEECH_SEED
    or move.effect == BattleEngine.EFFECT_REFRESH
    or move.effect == BattleEngine.EFFECT_INGRAIN
    or move.effect == BattleEngine.EFFECT_MORNING_SUN
    or move.effect == BattleEngine.EFFECT_SYNTHESIS
    or move.effect == BattleEngine.EFFECT_MOONLIGHT
    or move.effect == BattleEngine.EFFECT_BELLY_DRUM
    or move.effect == BattleEngine.EFFECT_PSYCH_UP
    or move.effect == BattleEngine.EFFECT_PAIN_SPLIT
    or move.effect == BattleEngine.EFFECT_ENDEAVOR
    or move.effect == BattleEngine.EFFECT_OHKO
    or move.effect == BattleEngine.EFFECT_BIDE
    or move.effect == BattleEngine.EFFECT_SPITE
    or move.effect == BattleEngine.EFFECT_SPLASH
    or move.effect == BattleEngine.EFFECT_CONVERSION
    or move.effect == BattleEngine.EFFECT_MEMENTO
    or move.effect == BattleEngine.EFFECT_DEFENSE_CURL
    or move.effect == BattleEngine.EFFECT_CHARGE
    or move.effect == BattleEngine.EFFECT_MUD_SPORT
    or move.effect == BattleEngine.EFFECT_WATER_SPORT
    or move.effect == BattleEngine.EFFECT_SEMI_INVULNERABLE
    or move.effect == BattleEngine.EFFECT_FUTURE_SIGHT
    or move.effect == BattleEngine.EFFECT_STOCKPILE
    or move.effect == BattleEngine.EFFECT_SWALLOW
    or move.effect == BattleEngine.EFFECT_TORMENT
    or move.effect == BattleEngine.EFFECT_TAUNT
    or move.effect == BattleEngine.EFFECT_IMPRISON
    or move.effect == BattleEngine.EFFECT_ENCORE
    or move.effect == BattleEngine.EFFECT_DISABLE
    or move.effect == BattleEngine.EFFECT_SOFTBOILED
    or move.effect == BattleEngine.EFFECT_SLEEP
    or move.effect == BattleEngine.EFFECT_CONFUSE
    or move.effect == 199 -- EFFECT_TEETER_DANCE (single-battle target)
    or move.effect == BattleEngine.EFFECT_POISON
    or move.effect == BattleEngine.EFFECT_PARALYZE
    or move.effect == BattleEngine.EFFECT_WILL_O_WISP
    or move.effect == BattleEngine.EFFECT_TOXIC
    or move.effect == BattleEngine.EFFECT_FREEZE_HIT
    or move.effect == BattleEngine.EFFECT_THAW_HIT
    or BattleEngine.CONFUSE_STAT_MOVES[move.effect] ~= nil
    or move.effect == 93 -- EFFECT_CONVERSION_2
    or move.effect == 94 -- EFFECT_LOCK_ON
    or move.effect == 107 -- EFFECT_NIGHTMARE
    or move.effect == 109 -- EFFECT_CURSE
    or move.effect == 106 -- EFFECT_MEAN_LOOK
    or move.effect == 113 -- EFFECT_FORESIGHT
    or move.effect == 114 -- EFFECT_PERISH_SONG
    or move.effect == 124 -- EFFECT_SAFEGUARD
    or move.effect == 179 -- EFFECT_WISH
    or move.effect == 194 -- EFFECT_GRUDGE
    or move.effect == BattleEngine.EFFECT_DESTINY_BOND
    or move.effect == BattleEngine.EFFECT_MIRROR_MOVE
    or move.effect == BattleEngine.EFFECT_MIMIC
    or move.effect == BattleEngine.EFFECT_SKETCH
    or move.effect == BattleEngine.EFFECT_SLEEP_TALK
    or move.effect == BattleEngine.EFFECT_ATTRACT
    or move.effect == BattleEngine.EFFECT_CAMOUFLAGE
    or move.effect == BattleEngine.EFFECT_NATURE_POWER
    or move.effect == BattleEngine.EFFECT_SUBSTITUTE
    or move.effect == BattleEngine.EFFECT_TRANSFORM
    or move.effect == BattleEngine.EFFECT_TELEPORT
    or BattleEngine.MULTI_STAT_UP_MOVES[move.effect] ~= nil
end

-- Cmd_critcalc: Focus Energy contributes two stages and each of the four
-- real high-critical effects contributes one. Item/ability sources remain
-- outside this itemless, abilityless slice.
function BattleEngine:critStage(attacker, move)
  return (attacker.focusEnergy and 2 or 0)
    + (BattleEngine.HIGH_CRITICAL_EFFECTS[move.effect] and 1 or 0)
end

-- Public extension seam. `ModHooks` receives (engine, attackerSide, moveSlot,
-- events) and may transform inputs/results around the canonical resolver.
function BattleEngine:resolveMove(attackerSide, moveSlot, events)
  if self.hooks then
    return self.hooks:call("battle.resolveMove", function(engine, side, slot, out)
      return engine:_resolveMove(side, slot, out)
    end, self, attackerSide, moveSlot, events)
  end
  return self:_resolveMove(attackerSide, moveSlot, events)
end

-- Resolves one attack, appending its events. Returns nothing; the caller
-- checks for a faint. Mirrors BattleScript_HitFromAccCheck's real order.
function BattleEngine:_resolveMove(attackerSide, moveSlot, events, copiedMoveId, calledBySleepTalk)
  local attacker = self:battler(attackerSide)
  local defenderSide = otherSide(attackerSide)
  local defender = self:battler(defenderSide)
  local function isImprisonedMove(moveId)
    if not defender.imprisoning then return false end
    for _, opposingSlot in ipairs(defender.moves) do
      if opposingSlot.move == moveId then return true end
    end
    return false
  end

  -- BattleScript_MoveUsedMustRecharge consumes the next selected action
  -- before move lookup or PP deduction. The locked move is retained solely
  -- for retail turn-order selection; this single-battler resolver needs no
  -- target/damage work on the recharge turn.
  if attacker.recharging then
    attacker.rageActive = false
    attacker.recharging, attacker.rechargeMove = false, nil
    events[#events + 1] = { type="recharging", side=attackerSide }
    return
  end

  -- CheckMoveLimitations cancels a multi-turn lock when Torment rejects its
  -- previous move. The caller may then select any different legal move.
  if attacker.tormented and attacker.lastMove then
    if attacker.skullBashMove == attacker.lastMove then attacker.skullBashMove = nil end
    if attacker.twoTurnMove == attacker.lastMove then attacker.twoTurnMove = nil end
    if attacker.semiInvulnerableMove == attacker.lastMove then
      attacker.semiInvulnerableMove, attacker.semiInvulnerableKind = nil, nil
    end
    if attacker.uproarMove == attacker.lastMove then attacker.uproarTurns, attacker.uproarMove = 0, nil end
    if attacker.rampageMove == attacker.lastMove then attacker.rampageTurns, attacker.rampageMove = 0, nil end
  end
  local skullBashSecond = attacker.skullBashMove ~= nil
  local twoTurnSecond = attacker.twoTurnMove ~= nil
  local semiInvulnerableSecond = attacker.semiInvulnerableMove ~= nil
  local uproarSecond = attacker.uproarTurns > 0
  local rampageSecond = attacker.rampageTurns > 0
  local forcedTwoTurn = skullBashSecond or twoTurnSecond or semiInvulnerableSecond or uproarSecond or rampageSecond
  if skullBashSecond then
    for i, slot in ipairs(attacker.moves) do
      if slot.move == attacker.skullBashMove then moveSlot = i break end
    end
  end
  if twoTurnSecond then
    for i, slot in ipairs(attacker.moves) do
      if slot.move == attacker.twoTurnMove then moveSlot = i break end
    end
  end
  if semiInvulnerableSecond then
    for i, slot in ipairs(attacker.moves) do
      if slot.move == attacker.semiInvulnerableMove then moveSlot = i break end
    end
  end
  if uproarSecond then
    for i, slot in ipairs(attacker.moves) do
      if slot.move == attacker.uproarMove then moveSlot = i break end
    end
  end
  if rampageSecond then
    for i, slot in ipairs(attacker.moves) do
      if slot.move == attacker.rampageMove then moveSlot = i break end
    end
  end

  if attacker.rolloutTurns > 0 then
    for i, slot in ipairs(attacker.moves) do
      if slot.move == attacker.rolloutMove then moveSlot = i break end
    end
  end

  if attacker.bideTurns > 0 then
    attacker.bideTurns = attacker.bideTurns - 1
    events[#events + 1] = { type="useMove", side=attackerSide, move=attacker.bideMove }
    if attacker.bideTurns > 0 then
      events[#events + 1] = { type="bideStore", side=attackerSide }
      return
    end
    local damage = attacker.bideDamage * 2
    attacker.bideDamage, attacker.bideMove = 0, nil
    if damage == 0 then
      events[#events + 1] = { type="bideFailed", side=attackerSide }
      return
    end
    self:applyDamage(attackerSide, defenderSide, defender, damage,
      {superEffective=false, notVeryEffective=false, noEffect=false}, events)
    events[#events + 1] = { type="bideRelease", side=attackerSide, target=defenderSide }
    return
  end

  -- Real AreAllMovesUnusable (src/battle_util.c) checked BEFORE the caller's
  -- chosen slot is even looked at: CheckMoveLimitations ORs together several
  -- real reasons a slot can be unusable (0 PP, Disable, Torment, Taunt,
  -- Imprison, Encore, Choice Band lock), and if every one of the battler's
  -- move slots ends up unusable, `gProtectStructs[].noValidMoves` is set.
  -- This engine currently models Torment and Taunt alongside PP; Disable,
  -- Imprison, Encore, and held-item limitations remain outside this slice.
  local allMovesUnusable = not forcedTwoTurn and not copiedMoveId
  if allMovesUnusable then
    for i = 1, #attacker.moves do
      local candidate = self.moves[attacker.moves[i].move]
      if attacker.moves[i].pp > 0
          and not (attacker.disabledTurns > 0 and attacker.moves[i].move == attacker.disabledMove)
          and not (attacker.tormented and attacker.moves[i].move == attacker.lastMove)
          and not (attacker.tauntTurns > 0 and candidate and candidate.power == 0) then
        if not isImprisonedMove(attacker.moves[i].move)
            and (attacker.encoreTurns <= 0 or attacker.moves[i].move == attacker.encoreMove) then
          allMovesUnusable = false
          break
        end
      end
    end
  end

  if attacker.encoreTurns > 0 and not allMovesUnusable and not forcedTwoTurn then
    for i, encoreSlot in ipairs(attacker.moves) do
      if encoreSlot.move == attacker.encoreMove then moveSlot = i break end
    end
  end

  local slot, move
  if copiedMoveId then
    -- Mirror Move restarts the copied move's script while `gCurrMovePos`
    -- still points at Mirror Move. Thus the copied script spends one PP
    -- from Mirror Move's own slot, never from a fictional copied-move slot.
    slot = attacker.moves[moveSlot]
    if not slot then error(("battler %s has no move in slot %d"):format(attackerSide, moveSlot)) end
    move = self.moves[copiedMoveId]
    if not move then error(("unknown copied move id %s"):format(tostring(copiedMoveId))) end
  elseif allMovesUnusable then
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

  -- BattleScript_EffectPayDay calls SetMoveEffect before it enters the
  -- ordinary EffectHit script, so the player-side amount accrues before
  -- attack cancellation, accuracy, or PP. The real u16 accumulator wraps
  -- only to saturate at 0xFFFF.
  if move.effect == BattleEngine.EFFECT_PAY_DAY and attackerSide == BattleEngine.SIDE_PLAYER then
    self.paydayMoney = math.min(0xFFFF, self.paydayMoney + attacker.level * 5)
    events[#events + 1] = { type="payDaySet", side=attackerSide, amount=self.paydayMoney }
  end

  -- Cmd_attackcanceler's Taunt limitation rejects status moves without
  -- reducing PP. Retail keys this off `power == 0`, not a fixed move list;
  -- preserve that data-driven rule for modded moves too.
  if slot and not forcedTwoTurn and attacker.tauntTurns > 0 and move.power == 0 then
    events[#events + 1] = { type="taunted", side=attackerSide, move=slot.move }
    return
  end
  if slot and not forcedTwoTurn and attacker.tormented and slot.move == attacker.lastMove then
    events[#events + 1] = { type="tormented", side=attackerSide, move=slot.move }
    return
  end
  if slot and not forcedTwoTurn and attacker.disabledTurns > 0 and slot.move == attacker.disabledMove then
    events[#events + 1] = { type="disabled", side=attackerSide, move=slot.move }
    return
  end
  if slot and not forcedTwoTurn and isImprisonedMove(slot.move) then
    events[#events + 1] = { type="imprisoned", side=attackerSide, move=slot.move, source=defenderSide }
    return
  end

  -- Defensive path only, real-game-unreachable: the caller selected a
  -- specific 0-PP slot while at least one OTHER slot of this battler still
  -- has PP (allMovesUnusable is false, so `slot` is set here, not Struggle).
  -- The real move-select menu greys out a 0-PP move and would never let a
  -- player submit this choice while another move remains available -- but
  -- this engine performs no UI-level move-menu validation, so a caller can
  -- still pass such a moveSlot. Don't crash, don't invent an action: keep
  -- the pre-existing no-op/noPP behavior for this specific unreachable case.
  if slot and slot.pp <= 0 and not forcedTwoTurn and not calledBySleepTalk then
    events[#events + 1] = { type = "noPP", side = attackerSide, move = slot.move }
    return
  end

  local moveId = copiedMoveId or (slot and slot.move) or BattleEngine.MOVE_STRUGGLE
  local previousMoveEffect = attacker.lastMoveEffect
  local hadGrudge = attacker.grudge
  local isSkullBash = move.effect == 145 -- EFFECT_SKULL_BASH
  local skullBashFirst = isSkullBash and not skullBashSecond
  -- Razor Wind, Sky Attack, and Solar Beam share the normal charge state.
  -- Solar Beam's one exception is real sunny weather: it attacks immediately.
  local isOrdinaryTwoTurn = move.effect == 39 or move.effect == 75
    or (move.effect == 151 and self.weather.kind ~= "sun")
  local ordinaryTwoTurnFirst = isOrdinaryTwoTurn and not twoTurnSecond
  local isSemiInvulnerable = move.effect == BattleEngine.EFFECT_SEMI_INVULNERABLE
  local semiInvulnerableFirst = isSemiInvulnerable and not semiInvulnerableSecond
  local isFutureSight = move.effect == BattleEngine.EFFECT_FUTURE_SIGHT
  local isStockpile = move.effect == BattleEngine.EFFECT_STOCKPILE
  local isSpitUp = move.effect == BattleEngine.EFFECT_SPIT_UP
  local isSwallow = move.effect == BattleEngine.EFFECT_SWALLOW
  local isTorment = move.effect == BattleEngine.EFFECT_TORMENT
  local isTaunt = move.effect == BattleEngine.EFFECT_TAUNT
  local isImprison = move.effect == BattleEngine.EFFECT_IMPRISON
  local isEncore = move.effect == BattleEngine.EFFECT_ENCORE
  local isDisable = move.effect == BattleEngine.EFFECT_DISABLE
  local isMirrorMove = move.effect == BattleEngine.EFFECT_MIRROR_MOVE
  events[#events + 1] = { type = "useMove", side = attackerSide, move = moveId }
  -- TryClearRageStatuses clears Rage as soon as another move is selected,
  -- including an action that is subsequently cancelled by a status ailment.
  if move.effect ~= BattleEngine.EFFECT_RAGE then attacker.rageActive = false end
  attacker.lastMove = moveId
  attacker.lastMoveEffect = move.effect
  if move.effect ~= 194 then attacker.grudge = false end -- EFFECT_GRUDGE
  if move.effect ~= BattleEngine.EFFECT_DESTINY_BOND then attacker.destinyBond = false end

  -- Cmd_attackcanceler decrements the three-bit Gen III sleep counter
  -- before a move can execute. A battler waking this turn proceeds; one
  -- still asleep cannot act or spend PP. Snore is already a damaging effect
  -- in this bounded engine and retains retail's asleep exception here.
  local sleepTurns = (attacker.status or 0) % 8
  if sleepTurns > 0 and not calledBySleepTalk then
    attacker.status = attacker.status - 1
    if attacker.status % 8 == 0 then
      events[#events + 1] = { type="wokeUp", side=attackerSide }
    else
      events[#events + 1] = { type="asleep", side=attackerSide,
        turnsRemaining=attacker.status % 8 }
      if moveId ~= 173 and move.effect ~= BattleEngine.EFFECT_SLEEP_TALK then -- MOVE_SNORE
        attacker.rampageTurns, attacker.rampageMove = 0, nil
        return
      end
    end
  end

  -- Frozen battlers roll a 20% natural thaw before moving. Flame Wheel and
  -- Sacred Fire instead thaw their frozen user and proceed after any
  -- non-thaw roll (Cmd_attackcanceler / EFFECT_THAW_HIT).
  if math.floor((attacker.status or 0) / 32) % 2 == 1 then
    local thawed = self.rng:next16() % 5 == 0
    if thawed or move.effect == BattleEngine.EFFECT_THAW_HIT then
      attacker.status = attacker.status - 32
      events[#events + 1] = { type="thawed", side=attackerSide,
        byMove=not thawed and move.effect == BattleEngine.EFFECT_THAW_HIT }
    else
      attacker.rampageTurns, attacker.rampageMove = 0, nil
      events[#events + 1] = { type="frozen", side=attackerSide }
      return
    end
  end

  -- STATUS2_FLINCHED only exists until this battler reaches its action.
  -- Its source action-canceller clears it and prevents PP reduction.
  if attacker.flinched then
    attacker.rampageTurns, attacker.rampageMove = 0, nil
    attacker.flinched = false
    events[#events + 1] = { type="flinched", side=attackerSide }
    return
  end

  -- Cmd_attackcanceler decrements volatile confusion before paralysis and
  -- before PP reduction. A continuing confusion rolls 50% to proceed; the
  -- other half uses a source-defined, typeless 40-power physical self-hit.
  if attacker.confusionTurns > 0 then
    attacker.confusionTurns = attacker.confusionTurns - 1
    if attacker.confusionTurns == 0 then
      events[#events + 1] = { type="snappedOut", side=attackerSide }
    elseif self.rng:next16() % 2 == 0 then
      local confusionMove = { power=40, type=0 }
      local damage = BattleFormulas.calculateBaseDamage(
        attacker, attacker, confusionMove, false, nil, nil)
      damage = BattleFormulas.applyRandomDamageMultiplier(damage, self.rng)
      damage = math.min(damage, attacker.hp)
      attacker.hp = attacker.hp - damage
      events[#events + 1] = { type="confusionSelfHit", side=attackerSide,
        amount=damage, hpRemaining=attacker.hp }
      self:checkFaint(attackerSide, events)
      attacker.rampageTurns, attacker.rampageMove = 0, nil
      return
    else
      events[#events + 1] = { type="confused", side=attackerSide,
        turnsRemaining=attacker.confusionTurns }
    end
  end

  -- Cmd_attackcanceler's paralysis branch rolls once; a zero low two-bit
  -- result is full paralysis. It happens before Protect/PP reduction.
  if math.floor((attacker.status or 0) / 64) % 2 == 1
      and self.rng:next16() % 4 == 0 then
    attacker.rampageTurns, attacker.rampageMove = 0, nil
    events[#events + 1] = { type="fullyParalyzed", side=attackerSide }
    return
  end

  if attacker.infatuatedBy and self.rng:next16() % 2 == 0 then
    attacker.rampageTurns, attacker.rampageMove = 0, nil
    events[#events + 1] = { type="infatuated", side=attackerSide, source=attacker.infatuatedBy }
    events[#events + 1] = { type="loveImmobility", side=attackerSide }
    return
  end

  -- Memento has a special protected-target branch: unlike ordinary blocked
  -- moves, retail still deducts its PP and makes the user faint, but never
  -- attempts either stat drop (BattleScript_MementoTargetProtect).
  if move.effect == BattleEngine.EFFECT_MEMENTO and defender.protected
      and math.floor((move.flags or 0) / 2) % 2 == 1 then
    slot.pp = slot.pp - 1
    attacker.hp = 0
    events[#events + 1] = { type="mementoSelfKO", side=attackerSide, protected=true, hpRemaining=0 }
    self:checkFaint(attackerSide, events)
    return
  end

  -- Real attackcanceler checks Protect before both accuracy and ppreduce.
  if not skullBashFirst and not ordinaryTwoTurnFirst and not semiInvulnerableFirst and defender.protected and math.floor((move.flags or 0) / 2) % 2 == 1 then
    attacker.rampageTurns, attacker.rampageMove = 0, nil
    events[#events + 1] = { type="protected", side=defenderSide, attacker=attackerSide }
    return
  end

  local counterDamage
  if move.effect == BattleEngine.EFFECT_COUNTER or move.effect == BattleEngine.EFFECT_MIRROR_COAT then
    local record = move.effect == BattleEngine.EFFECT_COUNTER
      and attacker.physicalDamageThisTurn or attacker.specialDamageThisTurn
    if not record or record.side ~= defenderSide or defender.hp <= 0 then
      events[#events + 1] = { type="counterFailed", side=attackerSide }
      return
    end
    counterDamage = record.amount * 2
  end

  -- BattleScript_EffectFocusPunch stops after attackcanceler when any
  -- direct damage already landed on the user this turn. Its failed branch
  -- spends PP but never reaches accuracy or ordinary hit resolution.
  if move.effect == BattleEngine.EFFECT_FOCUS_PUNCH and attacker.damagedByThisTurn then
    if slot then slot.pp = slot.pp - 1 end
    events[#events + 1] = { type="focusPunchLostFocus", side=attackerSide }
    return
  end

  if skullBashFirst then
    if slot then slot.pp = slot.pp - 1 end
    attacker.skullBashMove = moveId
    local before = attacker.statStages.defense
    attacker.statStages.defense = math.min(BattleFormulas.MAX_STAT_STAGE, before + 1)
    events[#events + 1] = { type="skullBashCharge", side=attackerSide }
    events[#events + 1] = { type="statChange", side=attackerSide, stat="defense",
      stages=attacker.statStages.defense-before, stage=attacker.statStages.defense,
      prevented=attacker.statStages.defense == before }
    return
  end
  if ordinaryTwoTurnFirst then
    if slot then slot.pp = slot.pp - 1 end
    attacker.twoTurnMove = moveId
    events[#events + 1] = { type="charging", side=attackerSide, move=moveId }
    return
  end
  if semiInvulnerableFirst then
    local kind = move.semiInvulnerableKind or BattleEngine.SEMI_INVULNERABLE_KINDS[moveId]
    assert(kind == "air" or kind == "underground" or kind == "underwater",
      "semi-invulnerable move needs an air, underground, or underwater kind")
    if slot then slot.pp = slot.pp - 1 end
    attacker.semiInvulnerableMove, attacker.semiInvulnerableKind = moveId, kind
    events[#events + 1] = { type="semiInvulnerableCharge", side=attackerSide, move=moveId, kind=kind }
    return
  end
  if skullBashSecond then attacker.skullBashMove = nil end
  if twoTurnSecond then attacker.twoTurnMove = nil end
  if semiInvulnerableSecond then
    attacker.semiInvulnerableMove, attacker.semiInvulnerableKind = nil, nil
  end

  -- BattleScript_EffectFakeOut checks DisableStruct.isFirstTurn after
  -- attackcanceler but before accuracy. Its failure branch still prints the
  -- attack string and spends PP, without making an accuracy roll or damage.
  if move.effect == 158 and not attacker.firstTurn then -- EFFECT_FAKE_OUT
    if slot then slot.pp = slot.pp - 1 end
    events[#events + 1] = { type="fakeOutFailed", side=attackerSide }
    return
  end

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
  -- Reflect/Light Screen (BattleEngine.SCREEN_MOVES) share this exact real
  -- shape: a self-target move (real MOVE_TARGET_USER) whose battle script
  -- has no accuracycheck step at all -- see SCREEN_MOVES' own comment.
  local screenStatusKey = BattleEngine.SCREEN_MOVES[move.effect]
  local sideStatusKey = BattleEngine.SIDE_STATUS_MOVES[move.effect]
  -- Haze's real script has no accuracycheck either: attackcanceler ->
  -- attackstring -> ppreduce -> normalisebuffs. Cmd_normalisebuffs then
  -- unconditionally writes DEFAULT_STAT_STAGE to every stat of both
  -- battlers (src/battle_script_commands.c), even if all were neutral.
  local isHaze = move.effect == BattleEngine.EFFECT_HAZE
  local isFocusEnergy = move.effect == BattleEngine.EFFECT_FOCUS_ENERGY
  local isProtect = move.effect == BattleEngine.EFFECT_PROTECT
  local isEndure = move.effect == BattleEngine.EFFECT_ENDURE
  local isSpikes = move.effect == BattleEngine.EFFECT_SPIKES
  local isRest = move.effect == BattleEngine.EFFECT_REST
  local isYawn = move.effect == BattleEngine.EFFECT_YAWN
  local isLeechSeed = move.effect == BattleEngine.EFFECT_LEECH_SEED
  local isRefresh = move.effect == BattleEngine.EFFECT_REFRESH
  local isIngrain = move.effect == BattleEngine.EFFECT_INGRAIN
  local healKind = move.effect == BattleEngine.EFFECT_RESTORE_HP and "half"
    or move.effect == BattleEngine.EFFECT_SOFTBOILED and "half"
    or (move.effect == BattleEngine.EFFECT_MORNING_SUN
      or move.effect == BattleEngine.EFFECT_SYNTHESIS
      or move.effect == BattleEngine.EFFECT_MOONLIGHT) and "weather" or nil
  local isBellyDrum = move.effect == BattleEngine.EFFECT_BELLY_DRUM
  local isPsychUp = move.effect == BattleEngine.EFFECT_PSYCH_UP
  local isPainSplit = move.effect == BattleEngine.EFFECT_PAIN_SPLIT
  local isTickle = move.effect == BattleEngine.EFFECT_TICKLE
  local multiStatUp = BattleEngine.MULTI_STAT_UP_MOVES[move.effect]
  local isEndeavor = move.effect == BattleEngine.EFFECT_ENDEAVOR
  local isBide = move.effect == BattleEngine.EFFECT_BIDE
  local isSpite = move.effect == BattleEngine.EFFECT_SPITE
  local isSplash = move.effect == BattleEngine.EFFECT_SPLASH
  local isConversion = move.effect == BattleEngine.EFFECT_CONVERSION
  local isPresent = move.effect == BattleEngine.EFFECT_PRESENT
  local isExplosion = move.effect == BattleEngine.EFFECT_EXPLOSION
  local isOHKO = move.effect == BattleEngine.EFFECT_OHKO
  local isMemento = move.effect == BattleEngine.EFFECT_MEMENTO
  local isDefenseCurl = move.effect == BattleEngine.EFFECT_DEFENSE_CURL
  local isCharge = move.effect == BattleEngine.EFFECT_CHARGE
  local sportKind = move.effect == BattleEngine.EFFECT_MUD_SPORT and "mud"
    or move.effect == BattleEngine.EFFECT_WATER_SPORT and "water" or nil
  local isDreamEater = move.effect == BattleEngine.EFFECT_DREAM_EATER
  local isSnore = move.effect == 92 -- EFFECT_SNORE
  -- Teeter Dance loops over every other active battler in doubles; this
  -- bounded 1v1 resolver has exactly the same one opposing target.
  local isConfuse = move.effect == BattleEngine.EFFECT_CONFUSE or move.effect == 199
  local isSleep = move.effect == BattleEngine.EFFECT_SLEEP
  local isPoison = move.effect == BattleEngine.EFFECT_POISON
  local isParalyze = move.effect == BattleEngine.EFFECT_PARALYZE
  local isWillOWisp = move.effect == BattleEngine.EFFECT_WILL_O_WISP
  local isToxic = move.effect == BattleEngine.EFFECT_TOXIC
  local confuseStat = BattleEngine.CONFUSE_STAT_MOVES[move.effect]
  local isConversion2 = move.effect == 93 -- EFFECT_CONVERSION_2
  local isLockOn = move.effect == 94 -- EFFECT_LOCK_ON
  local isNightmare = move.effect == 107 -- EFFECT_NIGHTMARE
  local isCurse = move.effect == 109 -- EFFECT_CURSE
  local isMeanLook = move.effect == 106 -- EFFECT_MEAN_LOOK
  local isForesight = move.effect == 113 -- EFFECT_FORESIGHT
  local isPerishSong = move.effect == 114 -- EFFECT_PERISH_SONG
  local isSafeguard = move.effect == 124 -- EFFECT_SAFEGUARD
  local isWish = move.effect == 179 -- EFFECT_WISH
  local isGrudge = move.effect == 194 -- EFFECT_GRUDGE
  local isDestinyBond = move.effect == BattleEngine.EFFECT_DESTINY_BOND
  local isMimic = move.effect == BattleEngine.EFFECT_MIMIC
  local isSketch = move.effect == BattleEngine.EFFECT_SKETCH
  local isCamouflage = move.effect == BattleEngine.EFFECT_CAMOUFLAGE
  local isNaturePower = move.effect == BattleEngine.EFFECT_NATURE_POWER
  local isSleepTalk = move.effect == BattleEngine.EFFECT_SLEEP_TALK
  local isAttract = move.effect == BattleEngine.EFFECT_ATTRACT
  local isSubstitute = move.effect == BattleEngine.EFFECT_SUBSTITUTE
  local isTransform = move.effect == BattleEngine.EFFECT_TRANSFORM
  local isTeleport = move.effect == BattleEngine.EFFECT_TELEPORT
  local safeguarded = self.sideStatus[defenderSide].safeguard
  local yawnPreFailed = isYawn and (defender.yawnTurns > 0 or defender.status ~= 0 or safeguarded)
  local confusePreFailed = isConfuse and (defender.confusionTurns > 0 or safeguarded)
  local sleepPreFailed = isSleep and (defender.status ~= 0 or safeguarded)
  local poisonPreFailed = isPoison and (defender.status ~= 0 or safeguarded
    or defender.types[1] == 3 or defender.types[2] == 3
    or defender.types[1] == 8 or defender.types[2] == 8)
  local paralyzePreFailed = isParalyze and (defender.status ~= 0 or safeguarded)
  local paralyzeTypeFlags
  if isParalyze then
    _, paralyzeTypeFlags = BattleFormulas.typeCalc(
      1, move.type, attacker.types, defender.types, self.typeChart)
  end
  local paralyzeTypeFailed = isParalyze and paralyzeTypeFlags.noEffect
  local burnPreFailed = isWillOWisp and (defender.status ~= 0 or safeguarded
    or defender.types[1] == 10 or defender.types[2] == 10)
  local toxicPreFailed = isToxic and (defender.status ~= 0 or safeguarded
    or defender.types[1] == 3 or defender.types[2] == 3
    or defender.types[1] == 8 or defender.types[2] == 8)
  local endeavorPreFailed = isEndeavor and defender.hp <= attacker.hp
  local ticklePreFailed = isTickle
    and defender.statStages.attack == BattleFormulas.MIN_STAT_STAGE
    and defender.statStages.defense == BattleFormulas.MIN_STAT_STAGE
  local magnitude, magnitudePower
  if move.effect == BattleEngine.EFFECT_MAGNITUDE then
    magnitude, magnitudePower = BattleFormulas.rollMagnitude(self.rng)
  end
  local weatherKind = move.effect == BattleEngine.EFFECT_RAIN_DANCE and "rain"
    or move.effect == BattleEngine.EFFECT_SUNNY_DAY and "sun"
    or move.effect == BattleEngine.EFFECT_SANDSTORM and "sandstorm"
    or move.effect == BattleEngine.EFFECT_HAIL and "hail" or nil
  -- Cmd_jumpifmoveaffectedbyprotect returns immediately for the always-hit
  -- and Vital Throw effects before Cmd_accuracycheck reaches Random(), even
  -- though their scripts otherwise share BattleScript_EffectHit.
  local alwaysHits = move.effect == BattleEngine.EFFECT_ALWAYS_HIT
    or move.effect == BattleEngine.EFFECT_VITAL_THROW
    or move.effect == BattleEngine.EFFECT_YAWN
  local lockOnActive = defender.lockOnTurns > 0 and defender.lockOnBy == attackerSide
  local foresightEvasion = defender.foresight and BattleFormulas.DEFAULT_STAT_STAGE or defender.statStages.evasion
  local needsAccuracyCheck = not isSelfTargetStat and not screenStatusKey and not sideStatusKey and not isHaze and not isFocusEnergy and not isProtect and not isEndure and not isSpikes and not weatherKind and not healKind and not isRest and not isRefresh and not isIngrain and not isConversion2 and not isNightmare and not isCurse and not isMeanLook and not isForesight and not isPerishSong and not isSafeguard and not isWish and not isGrudge and not isDestinyBond and not isMimic and not isSketch and not isCamouflage and not isNaturePower and not isSleepTalk and not isMirrorMove and not isTransform and not isTeleport and not isCharge and not sportKind and not isFutureSight and not isStockpile and not isSwallow and not isImprison and not lockOnActive and not yawnPreFailed and not isBellyDrum and not isPsychUp and not isPainSplit and not isBide and not isSplash and not isConversion and not isMemento and not isDefenseCurl and not confusePreFailed and not sleepPreFailed and not poisonPreFailed and not paralyzePreFailed and not paralyzeTypeFailed and not burnPreFailed and not toxicPreFailed and not alwaysHits and not ticklePreFailed and not multiStatUp and not endeavorPreFailed and not isOHKO and move.effect ~= 104

  local snorePreFailed = isSnore and (attacker.status or 0) % 8 == 0
  if snorePreFailed then needsAccuracyCheck = false end

  -- BattleScript_EffectDreamEater checks its target's sleep status before
  -- attackstring, PP reduction, and accuracy. The no-sleep branch therefore
  -- spends neither PP nor RNG and reports the ordinary no-effect result.
  if isDreamEater and (defender.status or 0) % 8 == 0 then
    events[#events + 1] = { type="noEffect", side=attackerSide, target=defenderSide }
    return
  end

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
    -- Cmd_accuracycheck: Rain makes EFFECT_THUNDER an unconditional hit;
    -- sun changes its ordinary move accuracy to 50 before stage math.
    if move.effect == BattleEngine.EFFECT_THUNDER and self.weather.kind == "rain" then
      hit = true
    else
      local moveAccuracy = move.accuracy
      if move.effect == BattleEngine.EFFECT_THUNDER and self.weather.kind == "sun" then moveAccuracy = 50 end
      hit = tutorialAccuracy or BattleFormulas.accuracyCheck(
        moveAccuracy, attacker.statStages.accuracy,
        foresightEvasion, self.rng)
    end
  else
    hit = true
  end

  -- BattleScript_EffectMirrorMove invokes Cmd_trymirrormove before its
  -- failure-only ppreduce. In this 1v1 engine, the opposing battler's last
  -- move is the sole candidate. On success retail swaps gCurrentMove and
  -- restarts that move's script; the recursive resolver below preserves the
  -- important part of that behavior: its PP step still debits Mirror Move's
  -- selected slot. Mirror Move itself is excluded because it cannot have
  -- supplied a target-directed last-taken move on retail, and avoiding it
  -- prevents an artificial recursive loop in this 1v1 representation.
  if isMirrorMove then
    local copied = defender.lastMove
    if not copied or copied == BattleEngine.MOVE_MIRROR_MOVE or not self.moves[copied] then
      if slot then slot.pp = slot.pp - 1 end
      events[#events + 1] = { type="mirrorMoveFailed", side=attackerSide, target=defenderSide }
      return
    end
    events[#events + 1] = { type="mirrorMove", side=attackerSide, target=defenderSide, move=copied }
    return self:_resolveMove(attackerSide, moveSlot, events, copied)
  end

  -- Nature Power selects its terrain move before any PP reduction; the
  -- called effect script then debits Nature Power's selected slot exactly
  -- once, the same `gCurrMovePos` behavior used by Mirror Move.
  if isNaturePower then
    local copied = BattleEngine.TERRAIN_NATURE_POWER_MOVES[self.battleTerrain]
    if not copied or not self.moves[copied] then
      events[#events + 1] = { type="naturePowerFailed", side=attackerSide }
      return
    end
    events[#events + 1] = { type="naturePower", side=attackerSide, move=copied }
    return self:_resolveMove(attackerSide, moveSlot, events, copied)
  end

  -- 2. ppreduce -- real order: after the accuracy roll (or, for a
  -- self-target UP move, in the same slot where accuracycheck would have
  -- been), and on the miss path too (BattleScript_PrintMoveMissed also
  -- runs ppreduce). Real HITMARKER_NO_PPDEDUCT means Struggle (no `slot`,
  -- see above) skips this step entirely -- there is no move slot of its
  -- own to decrement.
  if slot and not calledBySleepTalk and not skullBashSecond and not twoTurnSecond and not semiInvulnerableSecond and not uproarSecond and not rampageSecond then
    slot.pp = slot.pp - 1
  end

  if isSleepTalk then
    if (attacker.status or 0) % 8 == 0 then
      events[#events + 1] = { type="sleepTalkFailed", side=attackerSide, reason="awake" }
      return
    end
    local eligible = {}
    for i, candidate in ipairs(attacker.moves) do
      local candidateMove = self.moves[candidate.move]
      local twoTurn = candidateMove and (candidateMove.effect == 145 or candidateMove.effect == 146
        or candidateMove.effect == 147 or candidateMove.effect == BattleEngine.EFFECT_SEMI_INVULNERABLE
        or candidateMove.effect == BattleEngine.EFFECT_BIDE)
      local invalid = candidate.move == 0 or candidate.move == BattleEngine.MOVE_SLEEP_TALK
        or candidate.move == BattleEngine.MOVE_ASSIST or candidate.move == BattleEngine.MOVE_MIRROR_MOVE
        or candidate.move == BattleEngine.MOVE_METRONOME or candidate.move == 264 or candidate.move == 253
      if candidateMove and self:supportsMove(candidateMove) and not invalid and not twoTurn
          and not (attacker.disabledTurns > 0 and candidate.move == attacker.disabledMove)
          and not (attacker.tormented and candidate.move == attacker.lastMove)
          and not (attacker.tauntTurns > 0 and candidateMove.power == 0)
          and not isImprisonedMove(candidate.move)
          and (attacker.encoreTurns <= 0 or candidate.move == attacker.encoreMove) then
        eligible[i] = candidate.move
      end
    end
    local count = 0
    for _ in pairs(eligible) do count = count + 1 end
    if count == 0 then
      events[#events + 1] = { type="sleepTalkFailed", side=attackerSide, reason="noEligibleMove" }
      return
    end
    local selectedSlot
    repeat selectedSlot = (self.rng:next16() % 4) + 1 until eligible[selectedSlot]
    local copied = eligible[selectedSlot]
    events[#events + 1] = { type="sleepTalk", side=attackerSide, move=copied }
    return self:_resolveMove(attackerSide, selectedSlot, events, copied, true)
  end

  -- BattleScript_EffectTeleport reaches here directly after attackstring
  -- and ppreduce. It never rolls accuracy. In a trainer battle the source
  -- branches to BattleScript_ButItFailed; otherwise it ends immediately
  -- with the distinct PLAYER_TELEPORTED outcome. A predicate keeps this
  -- data-driven for mods that implement escape-blocking effects.
  if isTeleport then
    local canEscape = self.canEscape
    if type(canEscape) == "function" then
      canEscape = canEscape(attackerSide, move, self)
    end
    if not canEscape then
      events[#events + 1] = { type="teleportFailed", side=attackerSide }
      return
    end
    self.outcome = attackerSide == BattleEngine.SIDE_PLAYER and "teleported" or "foeFled"
    events[#events + 1] = { type="teleport", side=attackerSide }
    events[#events + 1] = { type="battleEnd", outcome=self.outcome }
    return
  end

  -- Real target-effect commands run after accuracy and PP. A Substitute is
  -- not a miss: it simply leaves target state untouched. Mods may opt out
  -- with the same declarative `ignoresSubstitute` hook used by applyDamage.
  local substituteBlocksTarget = defender.substituteHP > 0 and not move.ignoresSubstitute
  if substituteBlocksTarget and ((statEntry and not isSelfTargetStat)
      or BattleEngine.SUBSTITUTE_BLOCKED_TARGET_EFFECTS[move.effect]) then
    events[#events + 1] = { type="substituteBlocked", side=attackerSide,
      target=defenderSide, move=moveId }
    return
  end

  local semiKind = defender.semiInvulnerableKind
  local semiRule = semiKind and (move.semiInvulnerableHits and move.semiInvulnerableHits[semiKind]
    or BattleEngine.SEMI_INVULNERABLE_HITS[semiKind][move.effect])
  if semiKind and not semiRule then
    events[#events + 1] = { type="semiInvulnerableMiss", side=attackerSide,
      target=defenderSide, kind=semiKind }
    return
  end

  -- BattleScript_EffectSnore fails after attackstring/PP but before its
  -- accuracy check unless attackcanceler left the user asleep this turn.
  if snorePreFailed then
    events[#events + 1] = { type="snoreFailed", side=attackerSide }
    return
  end

  -- BattleScript_EffectExplosion calls Cmd_setatkhptozero immediately
  -- after PP reduction, before its accuracy roll and damage calculation.
  -- Faint resolution stays with runTurn so the target's faint retains the
  -- retail script's precedence over the attacker's deferred faint check.
  if isExplosion then
    attacker.hp = 0
    events[#events + 1] = { type="explosionSelfKO", side=attackerSide, hpRemaining=0 }
  end

  -- Cmd_removelightscreenreflect runs after Brick Break's successful
  -- accuracy check but before damagecalc. It clears both opposing screens
  -- at once, so this same hit is not reduced by either screen.
  if move.effect == BattleEngine.EFFECT_BRICK_BREAK and hit then
    local status = self.sideStatus[defenderSide]
    if status.reflect or status.lightScreen then
      status.reflect, status.reflectTimer = false, 0
      status.lightScreen, status.lightScreenTimer = false, 0
      events[#events + 1] = { type="screensShattered", side=defenderSide }
    end
  end

  if magnitude then
    events[#events + 1] = { type="magnitude", side=attackerSide, magnitude=magnitude }
  end
  if poisonPreFailed then
    events[#events + 1] = { type="poisonFailed", side=attackerSide, target=defenderSide }
    return
  end
  if confusePreFailed then
    events[#events + 1] = { type="confuseFailed", side=attackerSide, target=defenderSide }
    return
  end
  if yawnPreFailed then
    events[#events + 1] = { type="yawnFailed", side=attackerSide, target=defenderSide }
    return
  end
  if sleepPreFailed then
    events[#events + 1] = { type="sleepFailed", side=attackerSide, target=defenderSide }
    return
  end
  if paralyzePreFailed then
    events[#events + 1] = { type="paralyzeFailed", side=attackerSide, target=defenderSide }
    return
  end
  if paralyzeTypeFailed then
    events[#events + 1] = { type="noEffect", side=attackerSide, target=defenderSide }
    return
  end
  if burnPreFailed then
    events[#events + 1] = { type="burnFailed", side=attackerSide, target=defenderSide }
    return
  end
  if toxicPreFailed then events[#events + 1] = { type="toxicFailed", side=attackerSide, target=defenderSide }; return end
  if ticklePreFailed then
    events[#events + 1] = { type="tickleFailed", side=attackerSide }
    return
  end
  if endeavorPreFailed then
    events[#events + 1] = { type="endeavorFailed", side=attackerSide }
    return
  end

  -- Future Sight's script spends PP and schedules the target-owned delayed
  -- attack here; it has no accuracy or direct-damage step on cast.
  if isFutureSight then
    if defender.futureAttack then
      events[#events + 1] = { type="futureSightFailed", side=attackerSide, target=defenderSide }
    else
      defender.futureAttack = {
        turns = 3, move = moveId, attacker = attackerSide, accuracy = move.accuracy,
        damage = BattleFormulas.calculateBaseDamage(attacker, defender, move, false,
          self.sideStatus[defenderSide], self.weather.kind),
      }
      events[#events + 1] = { type="futureSightSet", side=attackerSide, target=defenderSide,
        move=moveId, turns=3 }
    end
    return
  end

  -- BattleScript_EffectTorment runs accuracycheck then Cmd_settorment; the
  -- volatile has no timer and a second application fails after spending PP.
  if isTorment then
    if not hit then
      events[#events + 1] = { type="miss", side=attackerSide }
      return
    end
    if defender.tormented then
      events[#events + 1] = { type="tormentFailed", side=attackerSide, target=defenderSide }
    else
      defender.tormented = true
      events[#events + 1] = { type="tormentSet", side=attackerSide, target=defenderSide }
    end
    return
  end

  -- Cmd_tryimprison has no accuracy check and only sets its persistent
  -- state when an opposing active battler knows at least one matching move.
  if isImprison then
    local shared = false
    for _, ownSlot in ipairs(attacker.moves) do
      for _, opposingSlot in ipairs(defender.moves) do
        if ownSlot.move == opposingSlot.move then shared = true break end
      end
      if shared then break end
    end
    if attacker.imprisoning or not shared then
      events[#events + 1] = { type="imprisonFailed", side=attackerSide }
    else
      attacker.imprisoning = true
      events[#events + 1] = { type="imprisonSet", side=attackerSide, target=defenderSide }
    end
    return
  end

  -- BattleScript_EffectTaunt runs accuracycheck then settaunt. FireRed's
  -- Cmd_settaunt uses a fixed two-turn timer and fails if already active.
  if isTaunt then
    if not hit then
      events[#events + 1] = { type="miss", side=attackerSide }
      return
    end
    if defender.tauntTurns > 0 then
      events[#events + 1] = { type="tauntFailed", side=attackerSide, target=defenderSide }
    else
      defender.tauntTurns = 2
      events[#events + 1] = { type="tauntSet", side=attackerSide, target=defenderSide, turns=2 }
    end
    return
  end

  -- Cmd_trysetencore locks the target's last usable non-encore move for a
  -- real random three-to-six turns. The counter is decremented at turn end.
  if isEncore then
    if not hit then
      events[#events + 1] = { type="miss", side=attackerSide }
      return
    end
    local moveToEncore = defender.lastMove
    local usable = moveToEncore and moveToEncore ~= BattleEngine.MOVE_STRUGGLE
      and moveToEncore ~= BattleEngine.MOVE_ENCORE
      and moveToEncore ~= BattleEngine.MOVE_MIRROR_MOVE
    if usable then
      usable = false
      for _, targetSlot in ipairs(defender.moves) do
        if targetSlot.move == moveToEncore and targetSlot.pp > 0 then usable = true break end
      end
    end
    if defender.encoreTurns > 0 or not usable then
      events[#events + 1] = { type="encoreFailed", side=attackerSide, target=defenderSide }
    else
      defender.encoreMove = moveToEncore
      defender.encoreTurns = self.rng:next16() % 4 + 3
      events[#events + 1] = { type="encoreSet", side=attackerSide, target=defenderSide,
        move=moveToEncore, turns=defender.encoreTurns }
    end
    return
  end

  -- BattleScript_EffectDisable applies after accuracy and PP reduction to
  -- the target's last move, provided it remains known and has PP.
  if isDisable then
    if not hit then
      events[#events + 1] = { type="miss", side=attackerSide }
      return
    end
    local moveToDisable = defender.lastMove
    local usable = false
    for _, targetSlot in ipairs(defender.moves) do
      if targetSlot.move == moveToDisable and targetSlot.pp > 0 then usable = true break end
    end
    if defender.disabledTurns > 0 or not usable then
      events[#events + 1] = { type="disableFailed", side=attackerSide, target=defenderSide }
    else
      defender.disabledMove = moveToDisable
      defender.disabledTurns = self.rng:next16() % 4 + 2
      events[#events + 1] = { type="disableSet", side=attackerSide, target=defenderSide,
        move=moveToDisable, turns=defender.disabledTurns }
    end
    return
  end

  if isStockpile then
    if attacker.stockpileCount >= 3 then
      events[#events + 1] = { type="stockpileFailed", side=attackerSide }
    else
      attacker.stockpileCount = attacker.stockpileCount + 1
      events[#events + 1] = { type="stockpile", side=attackerSide, count=attacker.stockpileCount }
    end
    return
  end
  if isSwallow then
    local count = attacker.stockpileCount
    attacker.stockpileCount = 0
    if count == 0 or attacker.hp == attacker.maxHP then
      events[#events + 1] = { type="swallowFailed", side=attackerSide, fullHP=attacker.hp == attacker.maxHP }
    else
      local amount = math.max(1, math.floor(attacker.maxHP / (2 ^ (3 - count))))
      amount = math.min(amount, attacker.maxHP - attacker.hp)
      attacker.hp = attacker.hp + amount
      events[#events + 1] = { type="swallow", side=attackerSide, count=count, amount=amount, hpRemaining=attacker.hp }
    end
    return
  end
  local spitUpCount
  if isSpitUp then
    spitUpCount = attacker.stockpileCount
    if spitUpCount == 0 then
      events[#events + 1] = { type="spitUpFailed", side=attackerSide }
      return
    end
    attacker.stockpileCount = 0
  end

  if not hit then
    if move.effect == 119 then attacker.furyCutterCount = 0 end
    if move.effect == BattleEngine.EFFECT_RAGE then attacker.rageActive = false end
    events[#events + 1] = { type = "miss", side = attackerSide }
    if move.effect == 45 then
      local crash, flags = BattleFormulas.typeCalc(
        BattleFormulas.calculateBaseDamage(attacker, defender, move, false, self.sideStatus[defenderSide], self.weather.kind),
        move.type, attacker.types, defender.types, self.typeChart)
      if not flags.noEffect then
        crash = math.max(1, math.floor(BattleFormulas.applyRandomDamageMultiplier(crash, self.rng) / 2))
        crash = math.min(crash, math.floor(defender.maxHP / 2), attacker.hp)
        attacker.hp = attacker.hp - crash
        events[#events + 1] = { type="recoil", side=attackerSide, amount=crash, hpRemaining=attacker.hp }
        self:checkFaint(attackerSide, events)
      end
    end
    return
  end

  -- SetMoveEffect starts Uproar after its initial accuracy check and locks
  -- the move for Random()&3 plus two turns. Later uses spend no more PP.
  if move.effect == BattleEngine.EFFECT_UPROAR and not uproarSecond then
    attacker.uproarTurns = (self.rng:next16() % 4) + 2
    attacker.uproarMove = moveId
    events[#events + 1] = { type="uproarSet", side=attackerSide, turns=attacker.uproarTurns }
  end
  if move.effect == BattleEngine.EFFECT_RAMPAGE and not rampageSecond then
    attacker.rampageTurns = (self.rng:next16() % 2) + 2
    attacker.rampageMove = moveId
    events[#events + 1] = { type="rampageSet", side=attackerSide, turns=attacker.rampageTurns }
  end

  -- Cmd_presentdamagecalculation rolls once after accuracy/PP.  The heal
  -- branch ignores type immunity and restores one quarter of target max HP.
  if isPresent then
    local roll = self.rng:next16() % 256
    if roll >= 204 then
      local before = defender.hp
      defender.hp = math.min(defender.maxHP, defender.hp + math.max(1, math.floor(defender.maxHP / 4)))
      if defender.hp == before then
        events[#events + 1] = { type="presentFailed", side=attackerSide, target=defenderSide }
      else
        events[#events + 1] = { type="presentHeal", side=attackerSide, target=defenderSide, amount=defender.hp-before }
      end
      return
    end
    move = { effect=move.effect, power=roll < 102 and 40 or roll < 178 and 80 or 120,
      type=move.type, accuracy=move.accuracy, priority=move.priority }
  end

  -- BattleScript_EffectOHKO uses its own path: ordinary accuracy stages do
  -- not apply, type immunity is still checked, and Cmd_tryKO rolls against
  -- move accuracy plus the level difference. A higher-level target always
  -- survives. This itemless/abilityless slice intentionally has no Sturdy
  -- or Focus Band branch, but keeps the real PP/RNG ordering above.
  if isOHKO then
    local _, ohkoFlags = BattleFormulas.typeCalc(1, move.type, attacker.types, defender.types, self.typeChart)
    if ohkoFlags.noEffect then
      events[#events + 1] = { type = "noEffect", side = attackerSide, target = defenderSide }
      return
    end
    local chance = move.accuracy + attacker.level - defender.level
    local koRoll = self.rng:next16() % 100 + 1
    if attacker.level < defender.level or koRoll >= chance then
      events[#events + 1] = { type="ohkoFailed", side=attackerSide }
      return
    end
    local flags = {
      superEffective=false, notVeryEffective=false, noEffect=false,
      damageCategory=BattleFormulas.damageCategory(move),
    }
    self:applyDamage(attackerSide, defenderSide, defender, defender.hp, flags, events)
    return
  end

  if move.power == 0 then
    if isCamouflage then
      local terrainType = BattleEngine.TERRAIN_TYPES[self.battleTerrain]
      if terrainType == nil or attacker.types[1] == terrainType or attacker.types[2] == terrainType then
        events[#events + 1] = { type="camouflageFailed", side=attackerSide }
      else
        attacker.types[1], attacker.types[2] = terrainType, terrainType
        events[#events + 1] = { type="camouflage", side=attackerSide, type=terrainType }
      end
      return
    end
    if isAttract then
      if defender.infatuatedBy or attacker.gender == nil or defender.gender == nil
          or attacker.gender == 255 or defender.gender == 255 -- MON_GENDERLESS
          or attacker.gender == defender.gender then
        events[#events + 1] = { type="attractFailed", side=attackerSide, target=defenderSide }
      else
        defender.infatuatedBy = attackerSide
        events[#events + 1] = { type="attract", side=attackerSide, target=defenderSide }
      end
      return
    end
    if isTransform then
      if defender.transformed or defender.semiInvulnerableKind then
        events[#events + 1] = { type="transformFailed", side=attackerSide, target=defenderSide }
      else
        -- Cmd_transformdataexecution copies BattlePokemon through the byte
        -- immediately before `pp`: species, battle stats, moves, IVs,
        -- ability, types, and all stat stages. Current/max HP, level,
        -- friendship, and nonvolatile/volatile status live after that
        -- boundary and therefore remain the user's own.
        attacker.transformed = true
        attacker.disabledTurns, attacker.disabledMove = 0, nil
        attacker.species = defender.species
        attacker.attack, attacker.defense, attacker.speed = defender.attack, defender.defense, defender.speed
        attacker.spAttack, attacker.spDefense = defender.spAttack, defender.spDefense
        attacker.types = { defender.types[1], defender.types[2] }
        for stat, stage in pairs(defender.statStages) do attacker.statStages[stat] = stage end
        attacker.moves = {}
        for i, targetSlot in ipairs(defender.moves) do
          local copiedMove = self.moves[targetSlot.move]
          attacker.moves[i] = { move=targetSlot.move, pp=math.min(5, (copiedMove and copiedMove.pp) or 5) }
        end
        events[#events + 1] = { type="transform", side=attackerSide, target=defenderSide,
          species=defender.species }
      end
      return
    end
    if isSubstitute then
      if attacker.substituteHP > 0 then
        events[#events + 1] = { type="substituteFailed", side=attackerSide, reason="alreadyActive" }
      else
        local cost = math.max(1, math.floor(attacker.maxHP / 4))
        -- Cmd_setsubstitute requires strictly more HP than the cost: the
        -- user may never create a decoy at 1 HP.
        if attacker.hp <= cost then
          events[#events + 1] = { type="substituteFailed", side=attackerSide, reason="insufficientHP" }
        else
          attacker.hp = attacker.hp - cost
          attacker.substituteHP = cost
          events[#events + 1] = { type="substituteSet", side=attackerSide,
            amount=cost, hpRemaining=attacker.hp, substituteHP=cost }
        end
      end
      return
    end
    if move.effect == 108 then attacker.minimized = true end -- EFFECT_MINIMIZE: set even at stat cap.
    if isGrudge then
      if hadGrudge then events[#events + 1] = { type="grudgeFailed", side=attackerSide }
      else attacker.grudge = true; events[#events + 1] = { type="grudge", side=attackerSide } end
      return
    end
    if isDestinyBond then
      attacker.destinyBond = true
      events[#events + 1] = { type="destinyBond", side=attackerSide }
      return
    end
    if isMimic then
      local copied = defender.lastMove
      local duplicate = false
      for _, candidate in ipairs(attacker.moves) do
        if candidate.move == copied then duplicate = true break end
      end
      if not copied or BattleEngine.MIMIC_FORBIDDEN_MOVES[copied] or duplicate or not self.moves[copied] then
        events[#events + 1] = { type="mimicFailed", side=attackerSide, target=defenderSide }
      else
        slot.move = copied
        slot.pp = math.min(5, self.moves[copied].pp or 5)
        events[#events + 1] = { type="mimic", side=attackerSide, target=defenderSide, move=copied, pp=slot.pp }
      end
      return
    end
    if isSketch then
      local copied = defender.lastMove
      local duplicate = false
      for _, candidate in ipairs(attacker.moves) do
        if candidate ~= slot and candidate.move == copied then duplicate = true break end
      end
      if attacker.transformed or not copied or copied == 165 -- MOVE_STRUGGLE
        or copied == 166 -- MOVE_SKETCH
        or duplicate or not self.moves[copied] then
        events[#events + 1] = { type="sketchFailed", side=attackerSide, target=defenderSide }
      else
        slot.move = copied
        slot.pp = self.moves[copied].pp or 0
        attacker.permanentMoveChanges[moveSlot] = copied
        events[#events + 1] = { type="sketch", side=attackerSide, target=defenderSide,
          move=copied, pp=slot.pp }
      end
      return
    end
    if isWish then
      local status = self.sideStatus[attackerSide]
      if status.wishTimer > 0 then events[#events + 1] = { type="wishFailed", side=attackerSide }
      else status.wishTimer = 2; events[#events + 1] = { type="wish", side=attackerSide, turns=2 } end
      return
    end
    if isSafeguard then
      local status = self.sideStatus[attackerSide]
      if status.safeguard then events[#events + 1] = { type="sideStatusFailed", side=attackerSide, status="safeguard" }
      else status.safeguard, status.safeguardTimer = true, 5; events[#events + 1] = { type="sideStatusSet", side=attackerSide, status="safeguard", turns=5 } end
      return
    end
    if isPerishSong then
      if attacker.perishTimer ~= nil and defender.perishTimer ~= nil then
        events[#events + 1] = { type="perishSongFailed", side=attackerSide }
      else
        if attacker.perishTimer == nil then attacker.perishTimer = 3 end
        if defender.perishTimer == nil then defender.perishTimer = 3 end
        events[#events + 1] = { type="perishSong", side=attackerSide }
      end
      return
    end
    if isForesight then
      defender.foresight = true
      events[#events + 1] = { type="foresight", side=attackerSide, target=defenderSide }
      return
    end
    if isMeanLook then
      if defender.trappedBy then
        events[#events + 1] = { type="trapFailed", side=attackerSide, target=defenderSide }
      else
        defender.trappedBy = attackerSide
        events[#events + 1] = { type="trapped", side=attackerSide, target=defenderSide }
      end
      return
    end
    if isCurse then
      local isGhost = attacker.types[1] == 7 or attacker.types[2] == 7
      if isGhost then
        if defender.cursed then
          events[#events + 1] = { type="curseFailed", side=attackerSide, target=defenderSide }
        else
          defender.cursed = true
          local amount = math.min(attacker.hp, math.max(1, math.floor(attacker.maxHP / 2)))
          attacker.hp = attacker.hp - amount
          events[#events + 1] = { type="curse", side=attackerSide, target=defenderSide }
          events[#events + 1] = { type="curseSelfDamage", side=attackerSide, amount=amount, hpRemaining=attacker.hp }
          self:checkFaint(attackerSide, events)
        end
      else
        local stages = attacker.statStages
        if stages.speed == BattleFormulas.MIN_STAT_STAGE
            and stages.attack == BattleFormulas.MAX_STAT_STAGE
            and stages.defense == BattleFormulas.MAX_STAT_STAGE then
          events[#events + 1] = { type="curseFailed", side=attackerSide }
          return
        end
        for _, entry in ipairs({ {stat="speed", delta=-1}, {stat="attack", delta=1}, {stat="defense", delta=1} }) do
          local before = stages[entry.stat]
          local stage = math.max(BattleFormulas.MIN_STAT_STAGE,
            math.min(BattleFormulas.MAX_STAT_STAGE, before + entry.delta))
          stages[entry.stat] = stage
          events[#events + 1] = { type="statChange", side=attackerSide, stat=entry.stat,
            stages=stage-before, stage=stage, prevented=stage == before }
        end
      end
      return
    end
    if isNightmare then
      if defender.nightmare or (defender.status or 0) % 8 == 0 then
        events[#events + 1] = { type="nightmareFailed", side=attackerSide, target=defenderSide }
      else
        defender.nightmare = true
        events[#events + 1] = { type="nightmare", side=attackerSide, target=defenderSide }
      end
      return
    end
    if isLockOn then
      defender.lockOnTurns, defender.lockOnBy = 2, attackerSide
      events[#events + 1] = { type="lockOn", side=attackerSide, target=defenderSide }
      return
    end
    if isConversion2 then
      local hitType = attacker.lastHitType
      if not hitType then
        events[#events + 1] = { type="conversionFailed", side=attackerSide }
        return
      end
      -- Cmd_settypetorandomresistance samples a type-chart row from a
      -- 128-value range, rejecting out-of-table and ineligible rows up to
      -- 1000 times before its deterministic source fallback.
      local selected
      for _ = 1, 1000 do
        local row = self.typeChart[self.rng:next16() % 128]
        if row and row.attackingType == hitType and row.multiplier <= 5
            and attacker.types[1] ~= row.defendingType and attacker.types[2] ~= row.defendingType then
          selected = row.defendingType
          break
        end
      end
      if not selected then
        local i = 0
        while self.typeChart[i] do
          local row = self.typeChart[i]
          if row.attackingType == hitType and row.multiplier <= 5
              and attacker.types[1] ~= row.defendingType and attacker.types[2] ~= row.defendingType then
            selected = row.defendingType
            break
          end
          i = i + 1
        end
      end
      if not selected then
        events[#events + 1] = { type="conversionFailed", side=attackerSide }
      else
        attacker.types = { selected, selected }
        events[#events + 1] = { type="conversion", side=attackerSide, typeId=selected }
      end
      return
    end
    if confuseStat then
      local current = defender.statStages[confuseStat.stat]
      if defender.confusionTurns > 0 and current == BattleFormulas.MAX_STAT_STAGE then
        events[#events + 1] = { type="confuseStatFailed", side=attackerSide, target=defenderSide }
        return
      end
      local stage = math.min(BattleFormulas.MAX_STAT_STAGE, current + confuseStat.delta)
      defender.statStages[confuseStat.stat] = stage
      events[#events + 1] = { type="statChange", side=defenderSide, stat=confuseStat.stat,
        stages=stage-current, stage=stage }
      if defender.confusionTurns == 0 then
        defender.confusionTurns = (self.rng:next16() % 4) + 2
        events[#events + 1] = { type="confuse", side=attackerSide, target=defenderSide,
          turns=defender.confusionTurns }
      end
      return
    end
    if isIngrain then
      if attacker.rooted then
        events[#events + 1] = { type="ingrainFailed", side=attackerSide }
      else
        attacker.rooted = true
        events[#events + 1] = { type="ingrain", side=attackerSide }
      end
      return
    end
    if isRefresh then
      local status = attacker.status or 0
      local curable = math.floor(status / 8) % 2 == 1
        or math.floor(status / 16) % 2 == 1
        or math.floor(status / 64) % 2 == 1
        or math.floor(status / 128) % 2 == 1
      if curable then
        attacker.status = 0
        events[#events + 1] = { type="refresh", side=attackerSide }
      else
        events[#events + 1] = { type="refreshFailed", side=attackerSide }
      end
      return
    end
    if isLeechSeed then
      if defender.leechSeededBy or defender.types[1] == 12 or defender.types[2] == 12 then
        events[#events + 1] = { type="leechSeedFailed", side=attackerSide, target=defenderSide }
      else
        defender.leechSeededBy = attackerSide
        events[#events + 1] = { type="leechSeed", side=attackerSide, target=defenderSide }
      end
      return
    end
    if isYawn then
      defender.yawnTurns = 2
      events[#events + 1] = { type="yawn", side=attackerSide, target=defenderSide,
        turns=defender.yawnTurns }
      return
    end
    if isRest then
      if attacker.hp == attacker.maxHP then
        events[#events + 1] = { type="restFailed", side=attackerSide }
      else
        attacker.hp = attacker.maxHP
        -- Cmd_trysetrest clears every status and stores exactly three in
        -- STATUS1_SLEEP's low three-bit counter before its full heal.
        attacker.status = 3
        events[#events + 1] = { type="rest", side=attackerSide,
          hpRemaining=attacker.hp, turns=3 }
      end
      return
    end
    if isConfuse then
      defender.confusionTurns = (self.rng:next16() % 4) + 2
      events[#events + 1] = { type="confuse", side=attackerSide, target=defenderSide,
        turns=defender.confusionTurns }
      return
    end
    if isSleep then
      -- SetMoveEffect stores (Random() & 3) + 2 directly in status1's low
      -- three bits, yielding a canonical two-to-five-turn sleep counter.
      defender.status = (self.rng:next16() % 4) + 2
      events[#events + 1] = { type="sleep", side=attackerSide, target=defenderSide,
        turns=defender.status }
      return
    end
    if isPoison then
      defender.status = defender.status + 8
      events[#events + 1] = { type="poison", side=attackerSide, target=defenderSide }
      return
    end
    if isParalyze then
      defender.status = 64
      events[#events + 1] = { type="paralyze", side=attackerSide, target=defenderSide }
      return
    end
    if isWillOWisp then
      defender.status = 16
      events[#events + 1] = { type="burn", side=attackerSide, target=defenderSide }
      return
    end
    if isToxic then defender.status = 128; events[#events + 1] = { type="toxic", side=attackerSide, target=defenderSide }; return end
    if isDefenseCurl then
      attacker.defenseCurled = true
      local current = attacker.statStages.defense
      local stage = math.min(BattleFormulas.MAX_STAT_STAGE, current + 1)
      attacker.statStages.defense = stage
      events[#events + 1] = { type="statChange", side=attackerSide, stat="defense",
        stages=stage-current, stage=stage, prevented=stage == current }
      return
    end
    if isCharge then
      attacker.chargeTurns = 2
      events[#events + 1] = { type="chargeSet", side=attackerSide, turns=2 }
      return
    end
    if sportKind then
      local field = sportKind == "mud" and "mudSport" or "waterSport"
      if attacker[field] then
        events[#events + 1] = { type="sportFailed", side=attackerSide, sport=sportKind }
      else
        attacker[field] = true
        events[#events + 1] = { type="sportSet", side=attackerSide, sport=sportKind }
      end
      return
    end
    -- BattleScript_EffectMemento: if the target already has minimum Attack
    -- AND Special Attack, it fails without sacrificing the user. Otherwise
    -- the user faints first, then each two-stage drop is attempted (Mist and
    -- a stage floor can independently prevent either drop).
    if isMemento then
      if defender.statStages.attack == BattleFormulas.MIN_STAT_STAGE
          and defender.statStages.spAttack == BattleFormulas.MIN_STAT_STAGE then
        events[#events + 1] = { type="mementoFailed", side=attackerSide }
        return
      end
      attacker.hp = 0
      events[#events + 1] = { type="mementoSelfKO", side=attackerSide, hpRemaining=0 }
      for _, stat in ipairs({ "attack", "spAttack" }) do
        local current = defender.statStages[stat]
        if self.sideStatus[defenderSide].mist then
          events[#events + 1] = { type="statChange", side=defenderSide, stat=stat,
            stages=0, prevented=true, mist=true }
        else
          local stage = math.max(BattleFormulas.MIN_STAT_STAGE, current - 2)
          defender.statStages[stat] = stage
          events[#events + 1] = { type="statChange", side=defenderSide, stat=stat,
            stages=stage-current, stage=stage, prevented=stage == current }
        end
      end
      self:checkFaint(attackerSide, events)
      return
    end
    if isConversion then
      local candidates = {}
      for _, known in ipairs(attacker.moves) do
        local knownMove = self.moves[known.move]
        local type = knownMove and knownMove.type
        if type ~= nil and type ~= attacker.types[1] and type ~= attacker.types[2] then
          candidates[#candidates + 1] = type
        end
      end
      if #candidates == 0 then
        events[#events + 1] = { type="conversionFailed", side=attackerSide }
      else
        local type = candidates[(self.rng:next16() % #candidates) + 1]
        attacker.types[1], attacker.types[2] = type, type
        events[#events + 1] = { type="conversion", side=attackerSide, newType=type }
      end
      return
    end
    if isSplash then
      events[#events + 1] = { type="splash", side=attackerSide }
      return
    end
    if isSpite then
      local targetSlot
      for _, candidate in ipairs(defender.moves) do
        if candidate.move == defender.lastMove then targetSlot = candidate break end
      end
      if not targetSlot or targetSlot.pp <= 1 then
        events[#events + 1] = { type="spiteFailed", side=attackerSide, target=defenderSide }
      else
        local amount = math.min(targetSlot.pp, (self.rng:next16() % 4) + 2)
        targetSlot.pp = targetSlot.pp - amount
        events[#events + 1] = { type="spite", side=attackerSide, target=defenderSide,
          move=targetSlot.move, amount=amount }
      end
      return
    end
    if isBide then
      attacker.bideTurns, attacker.bideDamage, attacker.bideMove = 2, 0, moveId
      events[#events + 1] = { type="bideStart", side=attackerSide }
      return
    end
    if multiStatUp then
      if attacker.statStages[multiStatUp[1]] == BattleFormulas.MAX_STAT_STAGE and attacker.statStages[multiStatUp[2]] == BattleFormulas.MAX_STAT_STAGE then
        events[#events + 1] = { type="multiStatUpFailed", side=attackerSide }
      else
        for _, stat in ipairs(multiStatUp) do
          local current = attacker.statStages[stat]
          local stage = math.min(BattleFormulas.MAX_STAT_STAGE, current + 1)
          attacker.statStages[stat] = stage
          events[#events + 1] = { type="statChange", side=attackerSide, stat=stat, stages=stage-current, stage=stage, prevented=stage == current }
        end
      end
      return
    end
    if isTickle then
      for _, stat in ipairs({ "attack", "defense" }) do
        local current = defender.statStages[stat]
        local stage = math.max(BattleFormulas.MIN_STAT_STAGE, current - 1)
        defender.statStages[stat] = stage
        events[#events + 1] = { type="statChange", side=defenderSide, stat=stat,
          stages=stage-current, stage=stage, prevented=stage == current }
      end
      return
    end
    if isPainSplit then
      local shared = math.floor((attacker.hp + defender.hp) / 2)
      local attackerBefore, defenderBefore = attacker.hp, defender.hp
      attacker.hp = math.min(attacker.maxHP, shared)
      defender.hp = math.min(defender.maxHP, shared)
      events[#events + 1] = { type="painSplit", side=attackerSide, target=defenderSide,
        attackerChange=attacker.hp-attackerBefore, targetChange=defender.hp-defenderBefore }
      return
    end
    if isPsychUp then
      for stat, stage in pairs(defender.statStages) do attacker.statStages[stat] = stage end
      events[#events + 1] = { type="psychUp", side=attackerSide, target=defenderSide }
      return
    end
    if isBellyDrum then
      local half = math.max(1, math.floor(attacker.maxHP / 2))
      if attacker.statStages.attack == BattleFormulas.MAX_STAT_STAGE or attacker.hp <= half then
        events[#events + 1] = { type="bellyDrumFailed", side=attackerSide }
      else
        attacker.statStages.attack = BattleFormulas.MAX_STAT_STAGE
        attacker.hp = attacker.hp - half
        events[#events + 1] = { type="bellyDrum", side=attackerSide, amount=half, hpRemaining=attacker.hp }
      end
      return
    end
    if healKind then
      self:resolveHeal(attackerSide, healKind, events)
      return
    end
    if isSpikes then
      self:resolveSpikes(attackerSide, defenderSide, events)
      return
    end
    if isProtect or isEndure then
      self:resolveProtect(attackerSide, attacker, previousMoveEffect, isEndure, events)
      return
    end
    if weatherKind then
      self:resolveWeatherMove(weatherKind, events)
      return
    end
    if isFocusEnergy then
      if attacker.focusEnergy then
        events[#events + 1] = { type="focusEnergyFailed", side=attackerSide }
      else
        attacker.focusEnergy = true
        events[#events + 1] = { type="focusEnergySet", side=attackerSide }
      end
      return
    end
    if isHaze then
      for _, side in ipairs({ BattleEngine.SIDE_PLAYER, BattleEngine.SIDE_FOE }) do
        local target = self:battler(side)
        for stat in pairs(target.statStages) do
          target.statStages[stat] = BattleFormulas.DEFAULT_STAT_STAGE
        end
      end
      events[#events + 1] = { type="haze", side=attackerSide }
      return
    end
    if screenStatusKey then
      self:resolveScreenMove(attackerSide, screenStatusKey, events)
      return
    end
    if sideStatusKey then
      self:resolveSideStatusMove(attackerSide, sideStatusKey, events)
      return
    end
    local stat = statEntry.stat
    local delta = statEntry.delta
    local targetSide = isSelfTargetStat and attackerSide or defenderSide
    local target = self:battler(targetSide)
    local current = target.statStages[stat]
    local atLimit = (delta > 0 and current == BattleFormulas.MAX_STAT_STAGE)
      or (delta < 0 and current == BattleFormulas.MIN_STAT_STAGE)
    if delta < 0 and self.sideStatus[targetSide].mist then
      events[#events + 1] = { type="statChange", side=targetSide, stat=stat, stages=0, prevented=true, mist=true }
    elseif atLimit then
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
    self:resolveMultiHit(attackerSide, attacker, defenderSide, defender, move, multiHitEntry, moveSlot, moveId, events)
    return
  end

  -- 3. critcalc (one Random()). Cmd_critcalc evaluates Random before its
  -- FIRST_BATTLE flag check, so the roll is still consumed while criticals
  -- are suppressed. Suppression is global until the first player damage
  -- message flips Oak's state flag, including a foe that attacks first.
  local rolledCrit = BattleFormulas.critRoll(self.rng, self:critStage(attacker, move))
  local isCrit = rolledCrit and not (self.firstBattle and not self.tutorialPlayerDamageDone)

  -- 4. damagecalc: base damage, then the real x2 crit multiply, which
  -- happens BEFORE typecalc. Real `sideStatus` param is the DEFENDER's own
  -- side (self.sideStatus[defenderSide] already has exactly the .reflect/
  -- .lightScreen fields calculateBaseDamage expects); a crit's non-crit
  -- gate is handled inside that function, not here.
  -- BattleScript_EffectFlail runs Cmd_remaininghptopower before the normal
  -- hit script, so Flail and Reversal retain every ordinary damage rule but
  -- substitute their source-derived dynamic base power first.
  local function scaledDamageMove(moveType, movePower)
    return { type=moveType, power=movePower, category=move.category }
  end
  local damageMove = move
  if spitUpCount then damageMove = scaledDamageMove(move.type, move.power * spitUpCount) end
  if move.effect == 117 then
    if attacker.rolloutTurns == 0 then
      attacker.rolloutTurns, attacker.rolloutMove = 5, moveId
    end
    damageMove = scaledDamageMove(move.type, move.power * (2 ^ (5 - attacker.rolloutTurns))
      * (attacker.defenseCurled and 2 or 1))
    attacker.rolloutTurns = attacker.rolloutTurns - 1
    if attacker.rolloutTurns == 0 then attacker.rolloutMove = nil end
  end
  if move.effect == 119 then
    attacker.furyCutterCount = math.min(5, attacker.furyCutterCount + 1)
    damageMove = scaledDamageMove(move.type, move.power * (2 ^ (attacker.furyCutterCount - 1)))
  end
  if move.effect == BattleEngine.EFFECT_FLAIL then
    damageMove = scaledDamageMove(move.type, BattleFormulas.flailPower(attacker.hp, attacker.maxHP))
  elseif move.effect == BattleEngine.EFFECT_ERUPTION then
    damageMove = scaledDamageMove(move.type, BattleFormulas.healthScaledPower(attacker.hp, attacker.maxHP, move.power))
  elseif move.effect == BattleEngine.EFFECT_MAGNITUDE then
    damageMove = scaledDamageMove(move.type, magnitudePower)
  elseif move.effect == BattleEngine.EFFECT_RETURN then
    damageMove = scaledDamageMove(move.type, math.floor(10 * attacker.friendship / 25))
  elseif move.effect == BattleEngine.EFFECT_FRUSTRATION then
    damageMove = scaledDamageMove(move.type, math.floor(10 * (255 - attacker.friendship) / 25))
  elseif move.effect == BattleEngine.EFFECT_HIDDEN_POWER then
    local iv = attacker.ivs
    local powerBits = math.floor(iv.hp / 2) % 2 + (math.floor(iv.attack / 2) % 2) * 2
      + (math.floor(iv.defense / 2) % 2) * 4 + (math.floor(iv.speed / 2) % 2) * 8
      + (math.floor(iv.spAttack / 2) % 2) * 16 + (math.floor(iv.spDefense / 2) % 2) * 32
    local typeBits = iv.hp % 2 + (iv.attack % 2) * 2 + (iv.defense % 2) * 4
      + (iv.speed % 2) * 8 + (iv.spAttack % 2) * 16 + (iv.spDefense % 2) * 32
    local hiddenType = math.floor(15 * typeBits / 63) + 1
    if hiddenType >= 9 then hiddenType = hiddenType + 1 end
    damageMove = scaledDamageMove(hiddenType, math.floor(40 * powerBits / 63) + 30)
  end
  if move.effect == BattleEngine.EFFECT_WEATHER_BALL and self.weather.kind then
    local weatherTypes = { rain=11, sandstorm=5, sun=10, hail=15 }
    damageMove = scaledDamageMove(weatherTypes[self.weather.kind] or 0, move.power * 2)
  end
  if attacker.chargeTurns > 0 and move.type == 13 then -- TYPE_ELECTRIC
    damageMove = scaledDamageMove(damageMove.type, damageMove.power * 2)
  end
  -- FireRed's CalculateBaseDamage scans every active battler for these
  -- STATUS3 flags. In a single battle either side's active state halves the
  -- matching type's move power, and switching naturally clears the source.
  if (damageMove.type == 13 and (self.player.mudSport or self.foe.mudSport))
      or (damageMove.type == 10 and (self.player.waterSport or self.foe.waterSport)) then
    damageMove = scaledDamageMove(damageMove.type, math.floor(damageMove.power / 2))
  end
  if semiRule == 2 then
    damageMove = scaledDamageMove(damageMove.type, damageMove.power * 2)
  end
  if move.effect == BattleEngine.EFFECT_FLINCH_MINIMIZE_HIT and defender.minimized then
    damageMove = scaledDamageMove(move.type, move.power * 2)
  end
  -- BattleScript_EffectFacade doubles its damage only for the user's four
  -- modeled nonvolatile conditions. Raw STATUS1 keeps this compatible with
  -- imported/modded battlers rather than coupling the rule to move data.
  if move.effect == 169 and (math.floor((attacker.status or 0) / 8) % 2 == 1
      or math.floor((attacker.status or 0) / 16) % 2 == 1
      or math.floor((attacker.status or 0) / 64) % 2 == 1
      or math.floor((attacker.status or 0) / 128) % 2 == 1) then -- EFFECT_FACADE
    damageMove = scaledDamageMove(move.type, move.power * 2)
  end
  -- BattleScript_EffectSmellingsalt doubles before the ordinary hit script
  -- when its target is paralyzed. Substitute is outside this engine slice.
  if move.effect == 171 and math.floor((defender.status or 0) / 64) % 2 == 1 then
    damageMove = scaledDamageMove(move.type, move.power * 2)
  end
  if move.effect == 185 and attacker.damagedByThisTurn == defenderSide then
    damageMove = scaledDamageMove(move.type, move.power * 2)
  end
  local damage = BattleFormulas.calculateBaseDamage(
    attacker, defender, damageMove, isCrit, self.sideStatus[defenderSide], self.weather.kind)
  if isCrit then
    damage = damage * BattleFormulas.CRIT_MULTIPLIER
  end

  -- 5. typecalc: STAB then per-row type effectiveness. Real Cmd_typecalc
  -- special-cases MOVE_STRUGGLE to skip this step entirely (`if
  -- (gCurrentMove == MOVE_STRUGGLE) { gBattlescriptCurrInstr++; return; }`)
  -- -- real Struggle always deals plain neutral damage, unblockable by any
  -- type immunity (e.g. it still hits a Ghost-type). Ported as a flat skip
  -- rather than routing Struggle through the ordinary per-row type-chart
  -- walk with a fabricated "always neutral" row.
  local flags
  if moveId == BattleEngine.MOVE_STRUGGLE then
    flags = { superEffective = false, notVeryEffective = false, noEffect = false }
  else
    damage, flags = BattleFormulas.typeCalc(
      damage, damageMove.type, attacker.types, defender.types, self.typeChart, defender.foresight
    )
  end

  -- Psywave's own script keeps type immunity but clears effectiveness
  -- flags, then uses Cmd_psywavedamageeffect instead of ordinary damage,
  -- STAB, and random-damage adjustment.
  local isPsywave = move.effect == BattleEngine.EFFECT_PSYWAVE
  local isSuperFang = move.effect == BattleEngine.EFFECT_SUPER_FANG
  local isEndeavorDamage = move.effect == BattleEngine.EFFECT_ENDEAVOR
  local fixedDamage = move.effect == BattleEngine.EFFECT_DRAGON_RAGE and 40
    or move.effect == BattleEngine.EFFECT_SONICBOOM and 20 or nil
  if move.effect == BattleEngine.EFFECT_LEVEL_DAMAGE then fixedDamage = attacker.level end
  if isPsywave or isSuperFang or fixedDamage or isEndeavorDamage or counterDamage then
    if flags.noEffect then
      events[#events + 1] = { type = "noEffect", side = attackerSide, target = defenderSide }
      return
    end
    damage = isPsywave and BattleFormulas.psywaveDamage(attacker.level, self.rng)
      or isSuperFang and BattleFormulas.superFangDamage(defender.hp)
      or isEndeavorDamage and (defender.hp - attacker.hp)
      or counterDamage
      or fixedDamage
    flags = { superEffective=false, notVeryEffective=false, noEffect=false }
  else
  -- 6. adjustnormaldamage always calls ApplyRandomDmgMultiplier, even
  -- for MOVE_RESULT_DOESNT_AFFECT_FOE; its Random() call happens before
  -- the real helper checks whether damage is zero.
    damage = BattleFormulas.applyRandomDamageMultiplier(damage, self.rng)

  if flags.noEffect then
    if move.effect == 119 then attacker.furyCutterCount = 0 end
    -- No HP changes for an immunity, but its exact RNG consumption above
    -- is observable in later actions and seeded replays.
    events[#events + 1] = { type = "noEffect", side = attackerSide, target = defenderSide }
    -- Real Cmd_seteffectwithchance still runs on a no-effect hit (the
    -- script isn't branched around it) and its Random() call is the FIRST
    -- operand of a C `&&` chain, so it is evaluated unconditionally before
    -- the later `&&` term that checks MOVE_RESULT_NO_EFFECT and blocks the
    -- actual effect. The roll must still be consumed here; its result is
    -- simply discarded. See BattleFormulas.secondaryEffectRoll's comment.
    if BattleEngine.HIT_VARIANT_STAT_MOVES[move.effect]
        or BattleEngine.HIT_VARIANT_ALL_STATS_UP[move.effect]
        or BattleEngine.HIT_VARIANT_STATUS_MOVES[move.effect]
        or BattleEngine.HIT_VARIANT_CONFUSE_MOVES[move.effect]
        or BattleEngine.HIT_VARIANT_FLINCH_MOVES[move.effect] then
      BattleFormulas.secondaryEffectRoll(self.rng, move.secondaryEffectChance)
    end
    return
  end
  end

  if isCrit then
    events[#events + 1] = { type = "critical", side = attackerSide }
  end

  -- 7. datahpupdate: real HP subtraction, floored at 0.
  flags.falseSwipe = move.effect == BattleEngine.EFFECT_FALSE_SWIPE
  if move.effect == BattleEngine.EFFECT_RAGE then attacker.rageActive = true end
  flags.damageCategory = BattleFormulas.damageCategory(damageMove)
  flags.moveType = damageMove.type
  flags.moveSlot, flags.moveId = moveSlot, moveId
  flags.ignoreSubstitute = move.ignoresSubstitute == true
  damage = self:applyDamage(attackerSide, defenderSide, defender, damage, flags, events)

  if move.effect == 80 then -- EFFECT_RECHARGE
    attacker.recharging, attacker.rechargeMove = true, moveId
    events[#events + 1] = { type="rechargeSet", side=attackerSide, move=moveId }
  end

  if move.effect == 171 and not flags.hitSubstitute and math.floor((defender.status or 0) / 64) % 2 == 1 then -- EFFECT_SMELLINGSALT
    defender.status = defender.status - 64
    events[#events + 1] = { type="paralysisCured", side=defenderSide, byMove=true }
  end

  -- BattleScript_EffectRapidSpin clears Spikes and any existing wrap state
  -- from its user after a landed hit.
  if move.effect == BattleEngine.EFFECT_RAPID_SPIN then
    if self.sideStatus[attackerSide].spikes > 0 then
      self.sideStatus[attackerSide].spikes = 0
      events[#events + 1] = { type="spikesCleared", side=attackerSide }
    end
    if attacker.trappedTurns > 0 then
      attacker.trappedTurns, attacker.trappedBy, attacker.trappedMove = 0, nil, nil
      events[#events + 1] = { type="trapCleared", side=attackerSide }
    end
  end
  if move.effect == BattleEngine.EFFECT_TRAP and not flags.hitSubstitute and defender.trappedTurns == 0 then
    defender.trappedTurns = (self.rng:next16() % 4) + 3
    defender.trappedBy, defender.trappedMove = attackerSide, moveId
    events[#events + 1] = { type="trapped", side=attackerSide, target=defenderSide,
      move=moveId, turns=defender.trappedTurns }
  end

  -- MOVEEND_DEFROST clears a frozen target after any landed, effective
  -- Fire-type hit; this is separate from EFFECT_THAW_HIT on the user.
  if damageMove.type == 10 and math.floor((defender.status or 0) / 32) % 2 == 1 then
    defender.status = defender.status - 32
    events[#events + 1] = { type="thawed", side=defenderSide, byFire=true }
  end

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
      kind = move.effect == BattleEngine.EFFECT_DREAM_EATER and "dreamEater" or nil,
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

  -- BattleScript_EffectOverheat sets MOVE_EFFECT_SP_ATK_TWO_DOWN as a
  -- certain self effect before entering the ordinary hit script.
  if move.effect == BattleEngine.EFFECT_OVERHEAT then
    local current = attacker.statStages.spAttack
    local stage = math.max(BattleFormulas.MIN_STAT_STAGE, current - 2)
    attacker.statStages.spAttack = stage
    events[#events + 1] = { type="statChange", side=attackerSide, stat="spAttack",
      stages=stage-current, stage=stage }
  end
  if move.effect == BattleEngine.EFFECT_SUPERPOWER then
    for _, stat in ipairs({ "attack", "defense" }) do
      local current = attacker.statStages[stat]
      local stage = math.max(BattleFormulas.MIN_STAT_STAGE, current - 1)
      attacker.statStages[stat] = stage
      events[#events + 1] = { type="statChange", side=attackerSide, stat=stat,
        stages=stage-current, stage=stage }
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
      if flags.hitSubstitute and not hitVariant.targetSelf then
        -- SetMoveEffect returns after its chance roll when a decoy was hit.
      elseif delta < 0 and self.sideStatus[targetSide].mist then
        events[#events + 1] = {
          type="statChange", side=targetSide, stat=stat, stages=0, prevented=true, mist=true,
        }
      elseif atLimit then
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
  if BattleEngine.HIT_VARIANT_ALL_STATS_UP[move.effect]
      and BattleFormulas.secondaryEffectRoll(self.rng, move.secondaryEffectChance) then
    for _, stat in ipairs({ "attack", "defense", "speed", "spAttack", "spDefense" }) do
      local current = attacker.statStages[stat]
      local stage = math.min(BattleFormulas.MAX_STAT_STAGE, current + 1)
      attacker.statStages[stat] = stage
      events[#events + 1] = { type="statChange", side=attackerSide, stat=stat,
        stages=stage-current, stage=stage, prevented=stage == current }
    end
  end
  local statusVariant = BattleEngine.HIT_VARIANT_STATUS_MOVES[move.effect]
  if statusVariant and BattleFormulas.secondaryEffectRoll(self.rng, move.secondaryEffectChance) and not flags.hitSubstitute then
    local typeImmune = false
    for _, type in ipairs(statusVariant.typeImmune or {}) do
      typeImmune = typeImmune or defender.types[1] == type or defender.types[2] == type
    end
    if defender.status == 0 and not self.sideStatus[defenderSide].safeguard and not typeImmune
        and not (statusVariant.blockedBySun and self.weather.kind == "sun") then
      defender.status = statusVariant.status
      events[#events + 1] = { type=statusVariant.event, side=attackerSide, target=defenderSide }
    end
  end
  -- BattleScript_EffectTriAttack installs MOVE_EFFECT_TRI_ATTACK, so the
  -- normal post-hit chance roll occurs first. SetMoveEffect then makes one
  -- additional Random()%3 choice only for an otherwise status-free target.
  if move.effect == 36 and BattleFormulas.secondaryEffectRoll(self.rng, move.secondaryEffectChance)
      and not flags.hitSubstitute
      and defender.status == 0 and not self.sideStatus[defenderSide].safeguard then -- EFFECT_TRI_ATTACK
    local choices = {
      { status=16, event="burn", typeImmune=10 },
      { status=32, event="freeze", typeImmune=15, blockedBySun=true },
      { status=64, event="paralyze" },
    }
    local choice = choices[self.rng:next16() % 3 + 1]
    local typeImmune = defender.types[1] == choice.typeImmune or defender.types[2] == choice.typeImmune
    if not typeImmune and not (choice.blockedBySun and self.weather.kind == "sun") then
      defender.status = choice.status
      events[#events + 1] = { type=choice.event, side=attackerSide, target=defenderSide }
    end
  end
  if BattleEngine.HIT_VARIANT_CONFUSE_MOVES[move.effect]
      and BattleFormulas.secondaryEffectRoll(self.rng, move.secondaryEffectChance)
      and not flags.hitSubstitute
      and defender.confusionTurns == 0 and not self.sideStatus[defenderSide].safeguard then
    defender.confusionTurns = (self.rng:next16() % 4) + 2
    events[#events + 1] = { type="confuse", side=attackerSide, target=defenderSide,
      turns=defender.confusionTurns }
  end
  if BattleEngine.HIT_VARIANT_FLINCH_MOVES[move.effect]
      and BattleFormulas.secondaryEffectRoll(self.rng, move.secondaryEffectChance)
      and not flags.hitSubstitute
      and self._actionIndex and self._actionCount
      and self._actionIndex < self._actionCount then
    defender.flinched = true
    events[#events + 1] = { type="flinch", side=attackerSide, target=defenderSide }
  end
  if move.effect == 158 and self._actionIndex and self._actionCount
      and self._actionIndex < self._actionCount then -- EFFECT_FAKE_OUT
    defender.flinched = true
    events[#events + 1] = { type="flinch", side=attackerSide, target=defenderSide }
  end
end

-- Real Cmd_setreflect/Cmd_setlightscreen (src/battle_script_commands.c
-- ~6415 and its lightscreen twin): if the CASTER's own side already has
-- this status active, real MOVE_RESULT_MISSED is set and a "but it failed"
-- message fires -- no RNG, no state change (real gSideTimers is left
-- alone, not refreshed to 5). Otherwise the flag is set on the caster's
-- OWN side (real `GET_BATTLER_SIDE(gBattlerAttacker)` -- a screen always
-- protects the mover's own side, never the target's) and a real 5-turn
-- `gSideTimers[side].reflectTimer/lightscreenTimer = 5` starts. `statusKey`
-- is "reflect" or "lightScreen" (BattleEngine.SCREEN_MOVES); the paired
-- Timer field is `statusKey .. "Timer"`, matching the two fields
-- BattleEngine.new() initializes per side.
function BattleEngine:resolveScreenMove(attackerSide, statusKey, events)
  local status = self.sideStatus[attackerSide]
  if status[statusKey] then
    events[#events + 1] = { type = "screenFailed", side = attackerSide, screen = statusKey }
    return
  end
  status[statusKey] = true
  status[statusKey .. "Timer"] = 5
  events[#events + 1] = { type = "screenSet", side = attackerSide, screen = statusKey, turns = 5 }
end

function BattleEngine:resolveSideStatusMove(attackerSide, statusKey, events)
  local status = self.sideStatus[attackerSide]
  if status[statusKey] then
    events[#events + 1] = { type="sideStatusFailed", side=attackerSide, status=statusKey }
    return
  end
  status[statusKey], status[statusKey .. "Timer"] = true, 5
  events[#events + 1] = { type="sideStatusSet", side=attackerSide, status=statusKey, turns=5 }
end

-- Cmd_trysetspikes places one layer on the OPPOSING side, fails at three,
-- and has no accuracy check. Spikes is deliberately a side property so it
-- survives ordinary and forced switches just like real gSideStatuses.
function BattleEngine:resolveSpikes(attackerSide, targetSide, events)
  local status = self.sideStatus[targetSide]
  if status.spikes >= 3 then
    events[#events + 1] = { type="spikesFailed", side=attackerSide, target=targetSide }
    return
  end
  status.spikes = status.spikes + 1
  events[#events + 1] = { type="spikesSet", side=attackerSide, target=targetSide, layers=status.spikes }
end

function BattleEngine:resolveHeal(side, kind, events)
  local battler = self:battler(side)
  if battler.hp == battler.maxHP then
    events[#events + 1] = { type="healFailed", side=side }
    return
  end
  local divisor = 2
  if kind == "weather" then
    if self.weather.kind == "sun" then divisor = 1.5
    elseif self.weather.kind then divisor = 4 end
  end
  local amount = math.max(1, math.floor(battler.maxHP / divisor))
  local before = battler.hp
  battler.hp = math.min(battler.maxHP, battler.hp + amount)
  events[#events + 1] = { type="heal", side=side, amount=battler.hp-before }
end

-- Cmd_switchindataupdate checks Spikes after a battler enters. The real
-- implementation skips Flying types and Levitate; this abilityless engine
-- models the type exemption and keeps abilities out of scope. Layer damage
-- is maxHP / 8, / 6, / 4 (minimum one) for one, two, three layers.
function BattleEngine:applySpikesOnSwitch(side, events)
  local battler = self:battler(side)
  local layers = self.sideStatus[side].spikes
  if layers == 0 or battler.hp <= 0 or battler.types[1] == 2 or battler.types[2] == 2 then return end
  local divisor = (5 - layers) * 2
  local damage = math.max(1, math.floor(battler.maxHP / divisor))
  battler.hp = math.max(0, battler.hp - damage)
  events[#events + 1] = { type="spikesDamage", side=side, damage=damage, layers=layers }
end

-- Real Cmd_setrain / Cmd_setsunny: a weather move has no accuracy check;
-- it fails only when that same weather is already active. A different
-- weather is replaced immediately, and the new temporary weather starts at
-- five turns (gWishFutureKnock.weatherDuration).
function BattleEngine:resolveWeatherMove(kind, events)
  if self.weather.kind == kind then
    events[#events + 1] = { type="weatherFailed", weather=kind }
    return
  end
  self.weather.kind, self.weather.timer = kind, 5
  events[#events + 1] = { type="weatherSet", weather=kind, turns=5 }
end

-- Cmd_setprotectlike. The threshold sequence is 65535, 32767, 16383,
-- 8191; each attempt consumes one Random() draw. Protect and Endure share
-- the same real protect-like chain, so any other previous move resets it.
function BattleEngine:resolveProtect(attackerSide, attacker, previousMoveEffect, isEndure, events)
  if previousMoveEffect ~= BattleEngine.EFFECT_PROTECT and previousMoveEffect ~= BattleEngine.EFFECT_ENDURE then attacker.protectUses = 0 end
  local thresholds = { 65535, 32767, 16383, 8191 }
  local rate = thresholds[math.min(attacker.protectUses + 1, #thresholds)]
  local hasRemainingAction = self._actionIndex == nil or self._actionIndex < (self._actionCount or 2)
  if hasRemainingAction and self.rng:next16() <= rate then
    if isEndure then attacker.endured = true else attacker.protected = true end
    attacker.protectUses = attacker.protectUses + 1
    events[#events + 1] = { type=isEndure and "endureSet" or "protectSet", side=attackerSide }
  else
    attacker.protectUses = 0
    events[#events + 1] = { type=isEndure and "endureFailed" or "protectFailed", side=attackerSide }
  end
end

-- Cmd_weatherdamage: temporary Sandstorm damages every non-Ground/Rock/
-- Steel battler and Hail every non-Ice battler for maxHP/16 (minimum 1).
-- Abilities and semi-invulnerable states are deliberately absent from this
-- statusless, abilityless slice.
function BattleEngine:applyDamagingWeather(events)
  local weather = self.weather.kind
  if weather ~= "sandstorm" and weather ~= "hail" then return end
  for _, side in ipairs({ BattleEngine.SIDE_PLAYER, BattleEngine.SIDE_FOE }) do
    local battler = self:battler(side)
    local immune = weather == "sandstorm"
      and (SANDSTORM_IMMUNE_TYPES[battler.types[1]] or SANDSTORM_IMMUNE_TYPES[battler.types[2]])
      or weather == "hail" and (battler.types[1] == 15 or battler.types[2] == 15)
    if not immune and battler.hp > 0 then
      local amount = math.floor(battler.maxHP / 16)
      if amount == 0 then amount = 1 end
      if amount > battler.hp then amount = battler.hp end
      battler.hp = battler.hp - amount
      events[#events + 1] = { type="weatherDamage", weather=weather, side=side, amount=amount, hpRemaining=battler.hp }
      self:checkFaint(side, events)
      if self:isOver() then return end
    end
  end
end

-- Real ENDTURN_REFLECT/ENDTURN_LIGHT_SCREEN cases of DoFieldEndTurnEffects
-- (src/battle_util.c:466) -- the first "end of turn" phase this engine has.
-- Real per-side order: side 0 (gBattleStruct->turnSideTracker == 0) before
-- side 1 -- ported the same way, player before foe. Each active timer
-- decrements by 1; when it reaches 0 the real code clears
-- gSideStatuses[side] and runs BattleScript_SideStatusWoreOff (a real
-- "protection wore off" message) -- represented here as a
-- {type="screenExpired"} event, matching this project's existing
-- per-side-effect event shape (e.g. {type="statChange", ...}) rather than
-- inventing a message-string system this project doesn't have.
--
-- WHEN this runs (see runTurn's call sites): real BattleTurnPassed
-- (src/battle_main.c:2953) only calls DoFieldEndTurnEffects when
-- `gBattleOutcome == 0`, i.e. the battle is still continuing after every
-- action chosen for this turn has finished executing. That is NOT the
-- same thing as "an ordinary two-move exchange happened" -- real
-- HandleEndTurn_ContinueBattle (src/battle_main.c) transitions to
-- BattleTurnPassed unconditionally once the turn's chosen actions (move,
-- voluntary switch, or a failed capture/run attempt) are done, with no
-- special case for switch/item turns. So a switch-only turn or a
-- failed-capture/failed-run turn still ticks these timers down exactly
-- like a plain two-move turn does; only a turn that decides the battle
-- outcome this turn (capture success, run success, or a faint) skips it.
-- Ported as `not self:isOver()` at every one of runTurn's normal-exit
-- points below, mirroring the real `gBattleOutcome == 0` gate exactly
-- rather than gating on which action type occurred.
function BattleEngine:decaySideTimers(events)
  for _, side in ipairs({ BattleEngine.SIDE_PLAYER, BattleEngine.SIDE_FOE }) do
    local status = self.sideStatus[side]
    if status.reflect then
      status.reflectTimer = status.reflectTimer - 1
      if status.reflectTimer <= 0 then
        status.reflect = false
        events[#events + 1] = { type = "screenExpired", side = side, screen = "reflect" }
      end
    end
    if status.lightScreen then
      status.lightScreenTimer = status.lightScreenTimer - 1
      if status.lightScreenTimer <= 0 then
        status.lightScreen = false
        events[#events + 1] = { type = "screenExpired", side = side, screen = "lightScreen" }
      end
    end
    if status.mist then
      status.mistTimer = status.mistTimer - 1
      if status.mistTimer <= 0 then
        status.mist = false
        events[#events + 1] = { type="sideStatusExpired", side=side, status="mist" }
      end
    end
    if status.safeguard then
      status.safeguardTimer = status.safeguardTimer - 1
      if status.safeguardTimer <= 0 then
        status.safeguard = false
        events[#events + 1] = { type="sideStatusExpired", side=side, status="safeguard" }
      end
    end
  end
  if self.weather.kind then
    self:applyDamagingWeather(events)
    if self:isOver() then return end
    self.weather.timer = self.weather.timer - 1
    if self.weather.timer <= 0 then
      local expired = self.weather.kind
      self.weather.kind, self.weather.timer = nil, 0
      events[#events + 1] = { type="weatherExpired", weather=expired }
    else
      events[#events + 1] = { type="weatherContinues", weather=self.weather.kind, turns=self.weather.timer }
    end
  end
end

-- Shared end-of-turn sequence. STATUS1_POISON is bit 3 in the real Gen III
-- status word; ordinary poison removes one eighth max HP (minimum one).
function BattleEngine:finishTurn(events)
  for _, side in ipairs({ BattleEngine.SIDE_PLAYER, BattleEngine.SIDE_FOE }) do
    local battler = self:battler(side)
    if battler.chargeTurns > 0 then
      battler.chargeTurns = battler.chargeTurns - 1
    end
    if battler.tauntTurns > 0 then
      battler.tauntTurns = battler.tauntTurns - 1
      if battler.tauntTurns == 0 then
        events[#events + 1] = { type="tauntEnded", side=side }
      end
    end
    if battler.encoreTurns > 0 then
      battler.encoreTurns = battler.encoreTurns - 1
      if battler.encoreTurns == 0 then
        battler.encoreMove = nil
        events[#events + 1] = { type="encoreEnded", side=side }
      end
    end
    if battler.disabledTurns > 0 then
      battler.disabledTurns = battler.disabledTurns - 1
      if battler.disabledTurns == 0 then
        battler.disabledMove = nil
        events[#events + 1] = { type="disableEnded", side=side }
      end
    end
    if battler.trappedTurns > 0 and battler.hp > 0 then
      battler.trappedTurns = battler.trappedTurns - 1
      if battler.trappedTurns > 0 then
        local amount = math.min(battler.hp, math.max(1, math.floor(battler.maxHP / 16)))
        battler.hp = battler.hp - amount
        events[#events + 1] = { type="trapDamage", side=side, target=battler.trappedBy,
          move=battler.trappedMove, amount=amount, hpRemaining=battler.hp,
          turns=battler.trappedTurns }
        if self:checkFaint(side, events) then return end
      else
        events[#events + 1] = { type="trapEnded", side=side, move=battler.trappedMove }
        battler.trappedBy, battler.trappedMove = nil, nil
      end
    end
    if battler.rooted and battler.hp > 0 and battler.hp < battler.maxHP then
      local amount = math.min(battler.maxHP - battler.hp, math.max(1, math.floor(battler.maxHP / 16)))
      battler.hp = battler.hp + amount
      events[#events + 1] = { type="ingrainHeal", side=side, amount=amount, hpRemaining=battler.hp }
    end
    local leechSource = battler.leechSeededBy and self:battler(battler.leechSeededBy) or nil
    if battler.hp > 0 and leechSource and leechSource.hp > 0 then
      local amount = math.min(battler.hp, math.max(1, math.floor(battler.maxHP / 8)))
      battler.hp = battler.hp - amount
      leechSource.hp = math.min(leechSource.maxHP, leechSource.hp + amount)
      events[#events + 1] = { type="leechSeedDrain", side=side,
        target=battler.leechSeededBy, amount=amount, hpRemaining=battler.hp,
        targetHpRemaining=leechSource.hp }
      if self:checkFaint(side, events) then return end
    end
    if battler.hp > 0 and math.floor(battler.status / 128) % 2 == 1 then
      local counter = math.floor(battler.status / 256) % 16
      counter = math.min(15, counter + 1)
      battler.status = battler.status % 256 + counter * 256
      local damage = math.max(1, math.floor(battler.maxHP / 16)) * counter
      battler.hp = math.max(0, battler.hp - damage)
      events[#events + 1] = { type="toxicDamage", side=side, amount=damage, counter=counter, hpRemaining=battler.hp }
      if self:checkFaint(side, events) then return end
    end
    if battler.hp > 0 and math.floor(battler.status / 8) % 2 == 1 then
      local damage = math.max(1, math.floor(battler.maxHP / 8))
      battler.hp = math.max(0, battler.hp - damage)
      events[#events + 1] = { type="poisonDamage", side=side, amount=damage, hpRemaining=battler.hp }
      if self:checkFaint(side, events) then return end
    end
    if battler.hp > 0 and math.floor(battler.status / 16) % 2 == 1 then
      local damage = math.max(1, math.floor(battler.maxHP / 8))
      battler.hp = math.max(0, battler.hp - damage)
      events[#events + 1] = { type="burnDamage", side=side, amount=damage, hpRemaining=battler.hp }
      if self:checkFaint(side, events) then return end
    end
    if battler.nightmare and battler.hp > 0 then
      if (battler.status or 0) % 8 == 0 then
        battler.nightmare = false
      else
        local damage = math.min(battler.hp, math.max(1, math.floor(battler.maxHP / 4)))
        battler.hp = battler.hp - damage
        events[#events + 1] = { type="nightmareDamage", side=side, amount=damage, hpRemaining=battler.hp }
        if self:checkFaint(side, events) then return end
      end
    end
    if battler.cursed and battler.hp > 0 then
      local damage = math.min(battler.hp, math.max(1, math.floor(battler.maxHP / 4)))
      battler.hp = battler.hp - damage
      events[#events + 1] = { type="curseDamage", side=side, amount=damage, hpRemaining=battler.hp }
      if self:checkFaint(side, events) then return end
    end
  end
  -- Uproar wakes sleeping active battlers and decrements its locked state.
  for _, sourceSide in ipairs({ BattleEngine.SIDE_PLAYER, BattleEngine.SIDE_FOE }) do
    local source = self:battler(sourceSide)
    if source.uproarTurns > 0 then
      for _, side in ipairs({ BattleEngine.SIDE_PLAYER, BattleEngine.SIDE_FOE }) do
        local battler = self:battler(side)
        if (battler.status or 0) % 8 > 0 then
          battler.status = battler.status - (battler.status % 8)
          battler.nightmare = false
          events[#events + 1] = { type="uproarWake", side=sourceSide, target=side }
        end
      end
      source.uproarTurns = source.uproarTurns - 1
      if source.uproarTurns == 0 then
        source.uproarMove = nil
        events[#events + 1] = { type="uproarEnded", side=sourceSide }
      else
        events[#events + 1] = { type="uproarContinues", side=sourceSide, turns=source.uproarTurns }
      end
    end
  end
  -- STATUS2_LOCK_CONFUSE is decremented after each locked action. When it
  -- expires, the user becomes confused unless already confused.
  for _, side in ipairs({ BattleEngine.SIDE_PLAYER, BattleEngine.SIDE_FOE }) do
    local battler = self:battler(side)
    if battler.rampageTurns > 0 then
      battler.rampageTurns = battler.rampageTurns - 1
      if battler.rampageTurns == 0 then
        battler.rampageMove = nil
        if battler.confusionTurns == 0 then
          battler.confusionTurns = (self.rng:next16() % 4) + 2
          events[#events + 1] = { type="rampageConfuse", side=side, turns=battler.confusionTurns }
        end
      else
        events[#events + 1] = { type="rampageContinues", side=side, turns=battler.rampageTurns }
      end
    end
  end
  -- HandleWishPerishSongOnTurnEnd decrements gWishFutureKnock's three-turn
  -- target counter and only then resolves the stored base damage. Gen III's
  -- delayed attack makes its own accuracy roll at impact and does not use
  -- ordinary type effectiveness or a new random-damage roll.
  for _, side in ipairs({ BattleEngine.SIDE_PLAYER, BattleEngine.SIDE_FOE }) do
    local battler = self:battler(side)
    local future = battler.futureAttack
    if future then
      future.turns = future.turns - 1
      if future.turns == 0 then
        battler.futureAttack = nil
        if BattleFormulas.accuracyCheck(future.accuracy,
            BattleFormulas.DEFAULT_STAT_STAGE, BattleFormulas.DEFAULT_STAT_STAGE, self.rng) then
          events[#events + 1] = { type="futureSightHit", side=future.attacker, target=side,
            move=future.move }
          self:applyDamage(future.attacker, side, battler, future.damage,
            {superEffective=false, notVeryEffective=false, noEffect=false}, events)
          if self:isOver() then return end
        else
          events[#events + 1] = { type="futureSightMiss", side=future.attacker, target=side,
            move=future.move }
        end
      end
    end
  end
  if not self:isOver() then self:decaySideTimers(events) end
  if self:isOver() then return end
  for _, side in ipairs({ BattleEngine.SIDE_PLAYER, BattleEngine.SIDE_FOE }) do
    local status = self.sideStatus[side]
    if status.wishTimer > 0 then
      status.wishTimer = status.wishTimer - 1
      if status.wishTimer == 0 then
        local battler = self:battler(side)
        if battler.hp < battler.maxHP then
          local amount = math.min(battler.maxHP - battler.hp, math.max(1, math.floor(battler.maxHP / 2)))
          battler.hp = battler.hp + amount
          events[#events + 1] = { type="wishHeal", side=side, amount=amount, hpRemaining=battler.hp }
        else
          events[#events + 1] = { type="wishFailed", side=side, fullHP=true }
        end
      end
    end
  end
  for _, side in ipairs({ BattleEngine.SIDE_PLAYER, BattleEngine.SIDE_FOE }) do
    local battler = self:battler(side)
    if battler.lockOnTurns > 0 then
      battler.lockOnTurns = battler.lockOnTurns - 1
      if battler.lockOnTurns == 0 then battler.lockOnBy = nil end
    end
    if battler.yawnTurns > 0 then
      battler.yawnTurns = battler.yawnTurns - 1
      if battler.yawnTurns == 0 and battler.status == 0 then
        battler.status = (self.rng:next16() % 4) + 2
        events[#events + 1] = { type="yawnSleep", side=side, turns=battler.status }
      end
    end
  end
  for _, side in ipairs({ BattleEngine.SIDE_PLAYER, BattleEngine.SIDE_FOE }) do
    local battler = self:battler(side)
    if battler.perishTimer ~= nil and battler.hp > 0 then
      if battler.perishTimer == 0 then
        battler.perishTimer = nil
        battler.hp = 0
        events[#events + 1] = { type="perishFaint", side=side }
        if self:checkFaint(side, events) then return end
      else
        events[#events + 1] = { type="perishCount", side=side, count=battler.perishTimer }
        battler.perishTimer = battler.perishTimer - 1
      end
    end
  end
  -- TurnValuesCleanUp clears DisableStruct.isFirstTurn at the end of the
  -- turn. A battler switched in during this turn keeps it through the next
  -- turn, as real SwitchInClearSetData initializes the replacement after
  -- that cleanup has begun.
  for _, side in ipairs({ BattleEngine.SIDE_PLAYER, BattleEngine.SIDE_FOE }) do
    local battler = self:battler(side)
    if battler.enteredThisTurn then battler.enteredThisTurn = false
    else battler.firstTurn = false end
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
  -- Cmd_datahpupdate directs ordinary incoming damage to the decoy while
  -- STATUS2_SUBSTITUTE is live. `ignoreSubstitute` is intentionally a move
  -- data hook: imported or modded moves that legitimately bypass a decoy
  -- can opt in without hard-coding a growing effect-id list here.
  if defender.substituteHP > 0 and not flags.ignoreSubstitute then
    local absorbed = math.min(damage, defender.substituteHP)
    defender.substituteHP = defender.substituteHP - absorbed
    flags.hitSubstitute = true
    events[#events + 1] = { type="substituteDamage", side=attackerSide,
      target=defenderSide, amount=absorbed, substituteHP=defender.substituteHP }
    if defender.substituteHP == 0 then
      events[#events + 1] = { type="substituteBroken", side=defenderSide }
    end
    return absorbed
  end
  if (defender.endured or flags.falseSwipe) and damage >= defender.hp then
    damage = defender.hp - 1
    if defender.endured then events[#events + 1] = { type="endured", side=defenderSide } end
  end
  if damage > defender.hp then
    damage = defender.hp
  end
  defender.hp = defender.hp - damage
  if damage > 0 then
    defender.damagedByThisTurn = attackerSide
    defender.lastHitType = flags.moveType
    -- Grudge only reacts when this hit itself causes the faint. Keeping a
    -- non-lethal hit here would incorrectly credit a later residual KO.
    if defender.hp == 0 then
      defender.faintedByMove = { side=attackerSide, moveSlot=flags.moveSlot, moveId=flags.moveId }
    end
  end
  if damage > 0 and defender.rageActive then
    local before = defender.statStages.attack
    defender.statStages.attack = math.min(BattleFormulas.MAX_STAT_STAGE, before + 1)
    events[#events + 1] = { type="rageBuilding", side=defenderSide,
      stages=defender.statStages.attack-before, stage=defender.statStages.attack }
  end
  if damage > 0 and defender.bideTurns > 0 then
    defender.bideDamage = defender.bideDamage + damage
  end
  if damage > 0 and flags.damageCategory then
    defender[flags.damageCategory .. "DamageThisTurn"] = { amount=damage, side=attackerSide }
  end
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
function BattleEngine:resolveMultiHit(attackerSide, attacker, defenderSide, defender, move, entry, moveSlot, moveId, events)
  local function applySecondaryStatus()
    if entry.secondaryStatus ~= "poison" then return end
    -- BattleScript_EffectTwineedle sets sMULTIHIT_EFFECT before its two-hit
    -- loop, then runs Cmd_seteffectwithchance exactly once after the loop.
    -- This therefore rolls once per complete move, not once per needle.
    if BattleFormulas.secondaryEffectRoll(self.rng, move.secondaryEffectChance)
        and defender.status == 0 and not self.sideStatus[defenderSide].safeguard
        and defender.types[1] ~= 3 and defender.types[2] ~= 3
        and defender.types[1] ~= 8 and defender.types[2] ~= 8 then
      defender.status = 8 -- STATUS1_POISON
      events[#events + 1] = { type="poison", side=attackerSide, target=defenderSide }
    end
  end
  local hitCount
  if entry.fixed then
    hitCount = entry.fixed
  else
    hitCount = BattleFormulas.rollMultiHitCount(self.rng)
  end
  local landedHits = 0

  for i = 1, hitCount do
    -- Real jumpifhasnohp BS_TARGET (top of BattleScript_MultiHitLoop): stop
    -- immediately if an earlier hit in this same sequence already fainted
    -- the defender. Unreachable on i==1 (runTurn only calls resolveMove for
    -- a battler with hp > 0), but real for i>1.
    if defender.hp <= 0 then break end

    if entry.perHitAccuracy and not BattleFormulas.accuracyCheck(
        move.accuracy, attacker.statStages.accuracy,
        defender.foresight and BattleFormulas.DEFAULT_STAT_STAGE or defender.statStages.evasion, self.rng) then
      if landedHits == 0 then events[#events + 1] = { type="miss", side=attackerSide } end
      break
    end

    local rolledCrit = BattleFormulas.critRoll(self.rng, self:critStage(attacker, move))
    local isCrit = rolledCrit and not (self.firstBattle and not self.tutorialPlayerDamageDone)

    local damageMove = entry.growingPower
      and { type=move.type, power=entry.growingPower * i, category=move.category } or move
    local damage = BattleFormulas.calculateBaseDamage(
      attacker, defender, damageMove, isCrit, self.sideStatus[defenderSide], self.weather.kind)
    if isCrit then
      damage = damage * BattleFormulas.CRIT_MULTIPLIER
    end

    local flags
    damage, flags = BattleFormulas.typeCalc(
      damage, damageMove.type, attacker.types, defender.types, self.typeChart, defender.foresight
    )

    if flags.noEffect then
      if entry.perHitAccuracy then BattleFormulas.applyRandomDamageMultiplier(damage, self.rng) end
      -- Real jumpifmovehadnoeffect: the ENTIRE sequence stops here, not
      -- just this one hit -- a type-immune target takes zero hits total.
      events[#events + 1] = { type = "noEffect", side = attackerSide, target = defenderSide }
      if entry.secondaryStatus then BattleFormulas.secondaryEffectRoll(self.rng, move.secondaryEffectChance) end
      return
    end

    damage = BattleFormulas.applyRandomDamageMultiplier(damage, self.rng)

    if isCrit then
      events[#events + 1] = { type = "critical", side = attackerSide }
    end

    flags.damageCategory = BattleFormulas.damageCategory(damageMove)
    flags.moveType, flags.moveSlot, flags.moveId = move.type, moveSlot, moveId
    self:applyDamage(attackerSide, defenderSide, defender, damage, flags, events)
    landedHits = landedHits + 1

    -- Real tryfaintmon BS_TARGET, checked every iteration (not just once
    -- at the end) so the sequence stops the instant HP hits 0, matching
    -- the real per-iteration jumpifhasnohp check at the top of the loop.
    if defender.hp == 0 then applySecondaryStatus() end
    if self:checkFaint(defenderSide, events) then
      return
    end
  end

  applySecondaryStatus()
  if landedHits > 0 then
    events[#events + 1] = { type = "multiHit", side = attackerSide, hits = landedHits }
  end
end

-- Checks for a faint on `side`, appending events and setting the outcome.
-- Returns true if the battle should stop resolving further actions this
-- turn -- either because the battle truly ended, OR because a forced
-- switch is now pending (see the header's forced-switch paragraph and
-- BattleEngine:resolveForcedSwitch). Real BattleScript_HandleFaintedMon's
-- fork (checkteamslost, then openpartyscreen) is mirrored here via the
-- caller-supplied `self.hasReplacement` predicate: real gBattleOutcome is
-- only set once a WHOLE team's total HP is 0, never by one battler fainting
-- while its side still has a living, eligible replacement.
function BattleEngine:checkFaint(side, events)
  local battler = self:battler(side)
  if battler.hp > 0 then return false end
  battler.hp = 0
  events[#events + 1] = { type = "faint", side = side }
  local cause = battler.faintedByMove
  if battler.destinyBond and cause then
    local attacker = self:battler(cause.side)
    battler.destinyBond = false
    if attacker.hp > 0 then
      attacker.hp = 0
      events[#events + 1] = { type="destinyBondKO", side=side, target=cause.side }
      self:checkFaint(cause.side, events)
      return true
    end
  end
  if battler.grudge and cause and cause.moveId ~= BattleEngine.MOVE_STRUGGLE then
    local attacker = self:battler(cause.side)
    local slot = cause.moveSlot and attacker.moves[cause.moveSlot] or nil
    if attacker.hp > 0 and slot then
      slot.pp = 0
      events[#events + 1] = { type="grudgePP", side=cause.side, target=side, move=slot.move }
    end
  end
  battler.grudge, battler.faintedByMove = false, nil
  if self.hasReplacement and self.hasReplacement(side) then
    self.awaitingForcedSwitch = side
    events[#events + 1] = { type = "forcedSwitchNeeded", side = side }
    return true
  end
  if side == BattleEngine.SIDE_PLAYER then
    self.outcome = "playerLost"
  else
    self.outcome = "playerWon"
  end
  events[#events + 1] = { type = "battleEnd", outcome = self.outcome }
  return true
end

-- Supplies the caller-built replacement for a pending forced switch (see
-- checkFaint and the header's forced-switch paragraph). `newBattler` must
-- already be an eligible, living battler -- built the same
-- BattlePartyBridge.battlerFromParty way as any other switch-in, so it
-- already starts with neutral stat stages (real Cmd_switchindataupdate;
-- see the voluntary-switch header paragraph) with no extra reset needed
-- here. Returns the events this step produces, matching this project's
-- always-return-an-event-list convention, so a caller can feed it through
-- the same presentation pipeline as runTurn's own return value.
function BattleEngine:resolveForcedSwitch(side, newBattler)
  assert(self.awaitingForcedSwitch == side,
    ("no forced switch is pending for side %s"):format(tostring(side)))
  assert(newBattler and newBattler.hp > 0,
    "resolveForcedSwitch needs a caller-supplied, already-eligible battler")
  if side == BattleEngine.SIDE_PLAYER then
    self.player = newBattler
  else
    self.foe = newBattler
  end
  self.awaitingForcedSwitch = nil
  local events = { { type = "forcedSwitchResolved", side = side } }
  self:applySpikesOnSwitch(side, events)
  self:checkFaint(side, events)
  return events
end

-- Runs one full turn. Each action is a table:
--   {action="move", moveSlot=n}   -- use the move in that 1-based slot
--   {action="run"}                -- player only (real singles run)
--   {action="capture"}            -- player only; normal Poke Ball slice
-- Returns the ordered event list for the turn.
function BattleEngine:runTurn(playerAction, foeAction)
  assert(not self:isOver(), "battle is already over")
  -- Real analogue: FireRed blocks on the forced-switch party-select menu
  -- (Cmd_openpartyscreen) before HandleTurnActionSelectionState can run
  -- again for the next turn. See checkFaint/resolveForcedSwitch and the
  -- header's forced-switch paragraph.
  assert(not self.awaitingForcedSwitch,
    "a forced switch is pending; call resolveForcedSwitch first")
  local events = {}
  self.turn = self.turn + 1
  self.player.protected, self.foe.protected = false, false
  self.player.endured, self.foe.endured = false, false
  self.player.damagedByThisTurn, self.foe.damagedByThisTurn = nil, nil
  self.player.physicalDamageThisTurn, self.foe.physicalDamageThisTurn = nil, nil
  self.player.specialDamageThisTurn, self.foe.specialDamageThisTurn = nil, nil
  events[#events + 1] = { type = "turnStart", turn = self.turn }

  -- BattleMain forces a battler with STATUS2_RECHARGE into B_ACTION_USE_MOVE
  -- before action selection. Preserve the caller's object elsewhere, but do
  -- not let a requested switch/run/capture bypass the locked recharge turn.
  if self.player.recharging or self.player.skullBashMove or self.player.twoTurnMove or self.player.semiInvulnerableMove or self.player.uproarTurns > 0 or self.player.rampageTurns > 0 then
    playerAction = { action="move", moveSlot=playerAction.moveSlot or 1 }
  end

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
    if self.player.rooted or self.player.trappedBy then
      events[#events + 1] = { type="switchFailed", side=BattleEngine.SIDE_PLAYER,
        rooted=self.player.rooted or nil, trapped=self.player.trappedBy ~= nil }
      self:resolveMove(BattleEngine.SIDE_FOE, foeAction.moveSlot, events)
      if not self:isOver() then self:checkFaint(BattleEngine.SIDE_PLAYER, events) end
      if not self:isOver() then self:finishTurn(events) end
      return events
    end
    assert(playerAction.battler and playerAction.battler.hp > 0,
      "switch needs a caller-supplied, already-eligible battler")
    self.player = playerAction.battler
    self.player.firstTurn, self.player.enteredThisTurn = true, true
    events[#events + 1] = { type = "switch", side = BattleEngine.SIDE_PLAYER }
    self:applySpikesOnSwitch(BattleEngine.SIDE_PLAYER, events)
    if self:checkFaint(BattleEngine.SIDE_PLAYER, events) then return events end
    self:resolveMove(BattleEngine.SIDE_FOE, foeAction.moveSlot, events)
    -- Same guard the capture/run branches below already use: a recoil/
    -- drain move can end the battle via the foe's own faint inside
    -- resolveMove before this checkFaint would otherwise re-check/
    -- overwrite that outcome.
    if not self:isOver() then
      self:checkFaint(BattleEngine.SIDE_PLAYER, events)
    end
    -- Real gBattleOutcome == 0 gate (see decaySideTimers' comment): a
    -- switch-only turn still reaches real BattleTurnPassed and ticks the
    -- Reflect/Light Screen timers down, as long as the battle didn't just
    -- end.
    if not self:isOver() then
      self:finishTurn(events)
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
    -- A failed capture still reaches real BattleTurnPassed (gBattleOutcome
    -- is only set by a SUCCESSFUL catch, handled by the early return
    -- above) -- so the timers still tick down here too.
    if not self:isOver() then
      self:finishTurn(events)
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
    -- A failed run still reaches real BattleTurnPassed (a SUCCESSFUL run
    -- sets gBattleOutcome and returns above, before this point) -- the
    -- timers still tick down.
    if not self:isOver() then
      self:finishTurn(events)
    end
    return events
  end

  local playerMove = self.player.bideTurns > 0 and self.moves[self.player.bideMove]
    or self.player.recharging and self.moves[self.player.rechargeMove]
    or self.player.skullBashMove and self.moves[self.player.skullBashMove]
    or self.player.twoTurnMove and self.moves[self.player.twoTurnMove]
    or self.player.semiInvulnerableMove and self.moves[self.player.semiInvulnerableMove]
    or self.player.uproarTurns > 0 and self.moves[self.player.uproarMove]
    or self.player.rampageTurns > 0 and self.moves[self.player.rampageMove]
    or self.moves[self.player.moves[playerAction.moveSlot].move]
  local foeMove = self.foe.bideTurns > 0 and self.moves[self.foe.bideMove]
    or self.foe.recharging and self.moves[self.foe.rechargeMove]
    or self.foe.skullBashMove and self.moves[self.foe.skullBashMove]
    or self.foe.twoTurnMove and self.moves[self.foe.twoTurnMove]
    or self.foe.semiInvulnerableMove and self.moves[self.foe.semiInvulnerableMove]
    or self.foe.uproarTurns > 0 and self.moves[self.foe.uproarMove]
    or self.foe.rampageTurns > 0 and self.moves[self.foe.rampageMove]
    or self.moves[self.foe.moves[foeAction.moveSlot].move]
  local strikesFirst = BattleFormulas.getWhoStrikesFirst(
    self.player, self.foe, playerMove, foeMove, self.rng
  )

  local order
  if strikesFirst == 0 then
    order = { { BattleEngine.SIDE_PLAYER, playerAction }, { BattleEngine.SIDE_FOE, foeAction } }
  else
    order = { { BattleEngine.SIDE_FOE, foeAction }, { BattleEngine.SIDE_PLAYER, playerAction } }
  end

  self._actionCount = #order
  for index, entry in ipairs(order) do
    self._actionIndex = index
    local side, action = entry[1], entry[2]
    if self:battler(side).hp > 0 then
      self:resolveMove(side, action.moveSlot, events)
      -- A recoil/drain move can already have ended the battle -- OR queued
      -- a forced switch -- via the attacker's own faint inside resolveMove
      -- (real attacker-faints-first ordering -- see that function's step
      -- 8a). Don't let a defender that also happens to be at 0 HP re-check
      -- and overwrite the real outcome. The awaitingForcedSwitch check
      -- (isOver() alone is NOT enough here: a pending forced switch
      -- deliberately leaves self.outcome nil, see checkFaint) also stops
      -- this turn from letting the other, still-healthy side attack a
      -- same-turn-fainted opponent before its replacement arrives -- see
      -- the header's forced-switch paragraph for why real source doesn't
      -- give this specific edge case (attacker recoils itself out before
      -- the defender has acted) an unambiguous real answer, and why this
      -- project conservatively halts the turn here instead.
      if self:isOver() or self.awaitingForcedSwitch then
        -- Real gBattleOutcome == 0 gate (see decaySideTimers' comment):
        -- real BattleTurnPassed runs DoFieldEndTurnEffects BEFORE
        -- HandleFaintedMonActions computes gBattleOutcome via
        -- checkteamslost, so a turn that leaves a forced switch pending
        -- (isOver() still false; only a TRUE battle end sets self.outcome)
        -- still decays Reflect/Light Screen timers -- only a turn that
        -- truly ends the whole battle skips it.
        if not self:isOver() then
          self:finishTurn(events)
        end
        return events
      end
      if self:checkFaint(otherSide(side), events) then
        if not self:isOver() then
          self:finishTurn(events)
        end
        return events
      end
      -- Explosion has already set the attacker to zero before its damage
      -- path. Its retail script checks the target first, then the attacker;
      -- ordinary recoil has already handled its own faint inside resolveMove.
      if self:checkFaint(side, events) then
        if not self:isOver() then
          self:finishTurn(events)
        end
        return events
      end
    end
  end
  self._actionIndex, self._actionCount = nil, nil

  -- Both actions for this ordinary move-exchange turn resolved without
  -- deciding the battle outcome -- the real gBattleOutcome == 0 case that
  -- reaches BattleTurnPassed and runs DoFieldEndTurnEffects.
  self:finishTurn(events)

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
