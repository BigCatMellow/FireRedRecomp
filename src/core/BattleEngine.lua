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
--   {type="crash", side=<attacker>, amount=, hpRemaining=} -- literal effect 45 miss
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
--   {type="moveFailed", side=}                    -- generic But it failed; distinct from screenFailed
--   {type="statChange", side=<target>, stat=, stages=-1, prevented=}
--   {type="statsWontRise", side=<attacker>}  -- two-stat UP move, both at +6
--   {type="statsWontFall", side=<defender>}  -- Tickle, target ATK/DEF both at -6
--   {type="splash"} / {type="haze"}
--   {type="wallShattered", side=<defender>}  -- Brick Break removed screens
--   {type="conversion", side=<attacker>, newType=}
--   {type="mementoHP", side=<attacker>}       -- attacker HP set to 0 before drops
--   {type="psychUp", side=<attacker>, target=<defender side>}
--   {type="bellyDrum", side=<attacker>, amount=, hpRemaining=}
--   {type="screenSet", side=, screen="reflect"|"lightScreen", turns=5}
--   {type="screenFailed", side=, screen="reflect"|"lightScreen"} -- already active
--   {type="screenExpired", side=, screen="reflect"|"lightScreen"} -- real 5-turn timer hit 0
--   {type="tutorialTip", kind="damage"|"stat"}  -- Oak first-battle text
--   {type="run", side=, success=}
--   {type="switch", side=}                         -- voluntary switch resolved
--   {type="throwBall", side=, target=, ball=}     -- rules-only item use
--   {type="capture", side=, target=, ball=, shakes=, success=,
--    automatic=}                                   -- CaptureRules result
--   {type="fastAsleep", side=}        -- sleep canceller: move not used, no PP
--   {type="wokeUp", side=}            -- sleep counter reached 0; move proceeds
--   {type="frozenSolid", side=}       -- freeze canceller: move not used, no PP
--   {type="thawed", side=}            -- canceller thaw (20%); move proceeds
--   {type="defrostedByMove", side=, move=} -- EFFECT_THAW_HIT user thawed
--   {type="fullyParalyzed", side=}    -- paralysis canceller: move not used, no PP
--   {type="defrostedByFire", side=<defender>} -- MOVEEND_DEFROST
--   {type="statusDamage", side=, kind="poison"|"toxic"|"burn", amount=,
--    hpRemaining=}                    -- end-of-turn status damage
--   {type="statusApplied", side=<target>, kind="poison"|"toxic"|"burn"|
--    "freeze"|"paralysis"|"sleep"}    -- status newly set
--   {type="statusPrevented", side=<target>, kind=, ability=} -- certain
--    effect blocked by Immunity/Water Veil/Limber
--   {type="statusAlready", side=<target>, kind=} -- primary status move on
--    a target that already has that status
--   {type="stayedAwake", side=<target>, ability=} -- Insomnia/Vital Spirit
--   {type="statusCured", side=<attacker>}   -- Refresh
--   {type="restSlept", side=<attacker>, statused=} -- Rest: "went to sleep!"
--    or (statused) "slept and became healthy!"; a restoreHP event follows
--   {type="focusEnergy", side=<attacker>}  -- Focus Energy: "is getting pumped!"
--   {type="paralysisHealed", side=<target>} -- Smelling Salt
--   {type="flinched", side=}          -- flinch canceller: move not used
--   {type="confusedTurn", side=}      -- "is confused!" (still confused)
--   {type="confusionSelfHit", side=, amount=, hpRemaining=}
--   {type="confusionEnded", side=}    -- snapped out; move proceeds
--   {type="confusionApplied", side=<target>}   -- "became confused!"
--   {type="alreadyConfused", side=<target>}
--   {type="confusionPrevented", side=<target>} -- Own Tempo
--   {type="chargeTurn", side=, move=, kind=}  -- two-turn move, turn 1
--   {type="fatigueConfusion", side=}  -- rampage lock ended: "became
--    confused due to fatigue!" (ENDTURN_THRASH)
--   {type="mustRecharge", side=}       -- recharge canceller
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
--   * Primary status (status1) EFFECTS are supported for a battler that
--     already carries one (loaded from the party record or set by a later
--     slice): sleep/freeze/paralysis move cancellers with their RNG,
--     burn's physical halving and paralysis's turn-order speed (in
--     BattleFormulas), Fire defrost at move end, end-of-turn poison/toxic/
--     burn damage, and faint clearing status (resolveStatusCancellers,
--     resolveMove, resolveStatusEndTurn, recordFaint). Moves apply a
--     status through the status-on-hit families (STATUS_HIT_MOVES, slice S2,
--     applySecondaryStatus) and the primary status moves
--     (PRIMARY_STATUS_MOVES, slice S3, resolvePrimaryStatusMove). Slice L1
--     adds Blaze Kick to STATUS_HIT_MOVES, Tri Attack's `% 3` status choice
--     (EFFECT_TRI_ATTACK) and Twineedle's trailing poison roll
--     (MULTI_HIT_MOVES[77]); the crit stage of every critcalc site comes
--     from critStageFor.
--   * Confusion and flinch (status2) cancellers, the confusion self-hit and
--     flinch clearing are supported (resolveStatusCancellers,
--     resolveConfusionSelfHit); battle-only, never persisted. Moves apply
--     them through STATUS2_HIT_MOVES (applySecondaryStatus2) and the
--     Confuse/Teeter Dance/Swagger/Flatter handlers (applyConfusion).
--     Soundproof is not represented (Supersonic, Snore, Growl, Sing).
--   * Abilities only where named (Damp, Guts, the status guards above);
--     no held items, weather,
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
--     (EFFECT_TRANSFORM etc). supportsMove() correctly rejects those.
--     (EFFECT_REST and EFFECT_FOCUS_ENERGY have their own early branches
--     in resolveMoveCore since status-leftovers slice L2.) (EFFECT_HAZE is now handled
--     by the fast-lane batch-3 path.)
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
--     EFFECT_RECOIL_IF_MISS=45 is a separate literal Jump Kick/Hi Jump Kick
--     ordinary-miss leaf: immunity exits before crash, otherwise noncritical
--     damage is halved/capped to target max HP and applied to attacker only.
--     Cancellation, abilities/items/status and nonordinary provenance remain
--     excluded. Not ported: EFFECT_DREAM_EATER=8 (heals like Absorb but
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
--     a fixed `setmultihitcounter 2` arg). EFFECT_TWINEEDLE=77 (slice L1)
--     is the same fixed 2 hits plus one trailing poison roll. All three
--     use the source tail (`sourceTail`, multi-hit tail follow-up):
--     effectiveness text once after the loop, then the count, then the
--     trailing seteffectwithchance roll, then the caller's faint. All share one real fact this
--     port depends on: accuracy is checked and PP is deducted exactly ONCE
--     for the whole move (real BattleScript_EffectMultiHit/EffectDoubleHit:
--     accuracycheck -> ... -> ppreduce -> setmultihitcounter, all BEFORE
--     the hit-count is even rolled) -- individual hits get their own crit
--     roll and damage roll only, never a repeat accuracy roll. Verified
--     against BattleScript_MultiHitLoop (data/battle_scripts_1.s): a
--     defender that reaches 0 HP during the sequence stops it
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
--     blocking respectively, neither of which this task covers). Brick
--     Break's screen removal is handled by EFFECT_BRICK_BREAK (fast-lane
--     batch 4).
--   * Capture is intentionally the first normal Poke Ball/no-status slice.
--     CaptureRules owns the exact formula/shake RNG. This engine neither
--     removes inventory nor copies a caught mon to party/PC or updates the
--     Pokedex; those are separate real battle-script/UI persistence steps.
--   * Move selection is caller-supplied; there is no AI. The opponent's
--     move is an input to runTurn, which is what makes scripted replay
--     tests possible.

local BattleFormulas = require("src.core.BattleFormulas")
local CaptureRules = require("src.core.CaptureRules")
local StatusConditions = require("src.core.StatusConditions")

local BattleEngine = {}
BattleEngine.__index = BattleEngine

BattleEngine.SIDE_PLAYER = "player"
BattleEngine.SIDE_FOE = "foe"
BattleEngine.EFFECT_ATTACK_DOWN = 18
BattleEngine.EFFECT_DEFENSE_DOWN = 19
-- Real EFFECT_HIGH_CRITICAL enters the ordinary hit script but advances only
-- Cmd_critcalc's stage from 0 (1/16) to 1 (1/8). It keeps the same one RNG
-- draw and every other ordinary-damage step.
BattleEngine.EFFECT_HIGH_CRITICAL = 43
-- Real EFFECT_FALSE_SWIPE shares the ordinary Hit script, but after final
-- damage it leaves a living target at one HP instead of allowing a knockout.
-- Substitute/Endure/Focus Band are separate, unrepresented stateful rules.
BattleEngine.EFFECT_FALSE_SWIPE = 101
-- Real EFFECT_ALWAYS_HIT and EFFECT_VITAL_THROW bypass Cmd_accuracycheck's
-- random accuracy branch entirely (battle_script_commands.c). They remain
-- distinct effects so future effect-specific behavior cannot be conflated.
BattleEngine.EFFECT_ALWAYS_HIT = 17
BattleEngine.EFFECT_VITAL_THROW = 78
BattleEngine.EFFECT_FLAIL = 99
BattleEngine.EFFECT_ERUPTION = 190
BattleEngine.EFFECT_PSYWAVE = 88
BattleEngine.EFFECT_OHKO = 38
BattleEngine.EFFECT_ENDEAVOR = 189
BattleEngine.EFFECT_PAIN_SPLIT = 91
BattleEngine.EFFECT_RESTORE_HP = 32
-- Fast-lane batch 3 (c75f352 data/battle_scripts_1.s): none of these
-- scripts has an accuracycheck or Random().
BattleEngine.EFFECT_HAZE = 25        -- EffectHaze :564, normalisebuffs
BattleEngine.EFFECT_SPLASH = 85      -- EffectSplash :1168
BattleEngine.EFFECT_BELLY_DRUM = 142 -- EffectBellyDrum :1772, maxattackhalvehp
BattleEngine.EFFECT_PSYCH_UP = 143   -- EffectPsychUp :1786, copyfoestats
BattleEngine.EFFECT_SOFTBOILED = 157 -- EffectSoftboiled :2023, tryhealhalfhealth
-- Fast-lane batch 6 (c75f352): neither script has accuracycheck.
BattleEngine.EFFECT_CONVERSION = 30  -- EffectConversion :658, tryconversiontypechange
BattleEngine.EFFECT_MEMENTO = 168    -- EffectMemento :2199, trymemento/setatkhptozero
BattleEngine.EFFECT_MAGNITUDE = 126
BattleEngine.MOVE_MAGNITUDE = 222

-- Real Cmd_remaininghptopower: scale the attacker's remaining HP to 48,
-- promote a positive underflow to one, then choose Flail/Reversal's dynamic
-- base power table before BattleScript_EffectHit begins.
function BattleEngine.flailPowerFromHP(hp, maxHP)
  local scaled = math.floor(hp * 48 / maxHP)
  if scaled == 0 and hp > 0 then scaled = 1 end
  if scaled <= 1 then return 200 end
  if scaled <= 4 then return 150 end
  if scaled <= 9 then return 100 end
  if scaled <= 16 then return 80 end
  if scaled <= 32 then return 40 end
  return 20
end

-- Real Cmd_scaledamagebyhealthratio for the bounded singles path. The ROM
-- command's gDynamicBasePower preseed guard has no counterpart in this engine;
-- this helper derives the effect-190 transient power without mutating move data.
function BattleEngine.eruptionPowerFromHP(hp, maxHP, storedPower)
  return math.max(1, math.floor(hp * storedPower / maxHP))
end

-- Magnitude's source command selects a transient base power with exactly one
-- Random() % 100 result. This leaf is deliberately Magnitude-specific: it is
-- not a shared dynamic-power abstraction and never changes catalog data.
function BattleEngine.magnitudeResultFromRoll(roll)
  assert(roll >= 0 and roll < 100, "Magnitude roll must be a residue 0..99")
  if roll <= 4 then return 4, 10 end
  if roll <= 14 then return 5, 30 end
  if roll <= 34 then return 6, 50 end
  if roll <= 64 then return 7, 70 end
  if roll <= 84 then return 8, 90 end
  if roll <= 94 then return 9, 110 end
  return 10, 150
end

-- Real Cmd_psywavedamageeffect: discard 11..15 from Random() % 16, then
-- scale the attacker's level by the accepted 50..150% value. This is a
-- distinct post-typecalc damage command, not ordinary base/random damage.
function BattleEngine.psywaveDamageFromLevel(level, rng)
  local roll
  repeat roll = rng:next16() % 16 until roll <= 10
  return math.floor(level * (roll * 10 + 50) / 100)
end

-- Represented-state Cmd_tryKO: its Random call occurs before the level gate.
function BattleEngine.ohkoSucceeds(attackerLevel, defenderLevel, accuracy, rng)
  local roll = rng:next16() % 100 + 1
  return attackerLevel >= defenderLevel and roll < accuracy + attackerLevel - defenderLevel
end
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

-- Self-target two-stat +1 family (data/battle_scripts_1.s at c75f352:
-- BattleScript_EffectCosmicPower/BulkUp/CalmMind/DragonDance). No accuracy
-- check, no RNG. Fails only when BOTH stats are at +6 (the jumpifstat pair ->
-- BattleScript_CantRaiseMultipleStats); otherwise each stat below +6 rises
-- by one, and a stat already at +6 is skipped silently (its statbuffchange
-- sets B_MSG_STAT_WONT_INCREASE and the script jumps past the message).
BattleEngine.DUAL_STAT_UP_MOVES = {
  [206] = { "defense",  "spDefense" }, -- EFFECT_COSMIC_POWER
  [208] = { "attack",   "defense" },   -- EFFECT_BULK_UP
  [211] = { "spAttack", "spDefense" }, -- EFFECT_CALM_MIND
  [212] = { "attack",   "speed" },     -- EFFECT_DRAGON_DANCE
}

-- Certain self-drop after a damaging hit (c75f352: EffectSuperpower/
-- EffectOverheat set MOVE_EFFECT_ATK_DEF_DOWN / SP_ATK_TWO_DOWN with
-- AFFECTS_USER|CERTAIN, then EffectHit). Cmd_seteffectwithchance's CERTAIN
-- branch applies it with no Random() on a hit that affected the target; on
-- a no-effect hit its else-if still evaluates Random() first. Applied via
-- BattleScript_AtkDefDown/SAtkDown2: a stat already at -6 is skipped
-- silently (cMULTISTRING_CHOOSER == B_MSG_STAT_WONT_DECREASE jumps past).
BattleEngine.SELF_DROP_HIT_MOVES = {
  [182] = { { stat = "attack", delta = -1 }, { stat = "defense", delta = -1 } }, -- EFFECT_SUPERPOWER
  [204] = { { stat = "spAttack", delta = -2 } },                               -- EFFECT_OVERHEAT
}

-- EFFECT_TICKLE (c75f352 BattleScript_EffectTickle): ppreduce, then fail
-- before accuracycheck only when target ATK and DEF are both at -6
-- (BattleScript_CantLowerMultipleStats); a miss goes to ButItFailed; then
-- target ATK -1 and DEF -1, each skipped silently at -6.
BattleEngine.EFFECT_TICKLE = 205

-- EFFECT_ALL_STATS_UP_HIT (c75f352 EffectAllStatsUpHit :1768): EffectHit with
-- chance MOVE_EFFECT_ALL_STATS_UP|AFFECTS_USER -> BattleScript_AllStatsUp
-- (:3405). Skipped entirely when all five are at +6; otherwise ATK, DEF,
-- SPEED, SP.ATK, SP.DEF each statbuffchange then printfromtable with no
-- message skip, so a stat already at +6 prints its "won't go higher!".
BattleEngine.EFFECT_ALL_STATS_UP_HIT = 140
-- EFFECT_BRICK_BREAK (c75f352 EffectBrickBreak :2413): after accuracy and
-- ppreduce, removelightscreenreflect clears both of the target side's
-- screens before critcalc/damagecalc; "The wall shattered!" follows the
-- attack animation whenever one was removed, even on an immune target.
BattleEngine.EFFECT_BRICK_BREAK = 186
-- EFFECT_TRIPLE_KICK (c75f352 EffectTripleKick :1380): ppreduce with no
-- outer accuracycheck, then up to three iterations of accuracycheck ->
-- movevaluescleanup -> power += 10 -> critcalc/damagecalc/typecalc/
-- adjustnormaldamage -> jumpifmovehadnoeffect. A miss or no-effect ends the
-- loop; with no landed hit the result message shows, otherwise MISSED is
-- cleared and "Hit N time(s)!" prints before tryfaintmon BS_TARGET.
BattleEngine.EFFECT_TRIPLE_KICK = 104

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
BattleEngine.EFFECT_EXPLOSION = 7
BattleEngine.ABILITY_DAMP = 6
-- Primary status (status1) cancellers and end-of-turn damage; see
-- resolveStatusCancellers / resolveStatusEndTurn.
BattleEngine.MOVE_SNORE = 173
BattleEngine.MOVE_SLEEP_TALK = 214
BattleEngine.EFFECT_THAW_HIT = 125
BattleEngine.TYPE_FIRE = 10

-- Status-on-hit families (slice S2): the stock hit script with a
-- setmoveeffect status byte applied by seteffectwithchance
-- (data/battle_scripts_1.s:321-374, :2632; Poison Tail shares the Poison
-- Hit script at :233). Poison Tail also adds one crit stage (Cmd_critcalc,
-- src/battle_script_commands.c:1184-1188).
BattleEngine.EFFECT_POISON_TAIL = 209
BattleEngine.STATUS_HIT_MOVES = {
  [2] = "poison",      -- EFFECT_POISON_HIT
  [4] = "burn",        -- EFFECT_BURN_HIT
  [5] = "freeze",      -- EFFECT_FREEZE_HIT
  [6] = "paralysis",   -- EFFECT_PARALYZE_HIT
  [202] = "toxic",     -- EFFECT_POISON_FANG
  [209] = "poison",    -- EFFECT_POISON_TAIL
  [125] = "burn",      -- EFFECT_THAW_HIT (data/battle_scripts_1.s:1675-1677)
  [152] = "paralysis", -- EFFECT_THUNDER (:1916-1919)
  [200] = "burn",      -- EFFECT_BLAZE_KICK (BattleScript_EffectBurnHit, :224, :364-366);
                       -- its +1 crit stage comes from critStageFor (slice L1)
}
-- Status-leftovers slice L1 (work/reports/phase4-status-leftovers-design-proposal.md).
-- EFFECT_TRI_ATTACK: the stock hit script with MOVE_EFFECT_TRI_ATTACK
-- (data/battle_scripts_1.s:731-733), resolved after the landed hit in
-- resolveMoveCore. EFFECT_TWINEEDLE is a MULTI_HIT_MOVES entry with a
-- trailing poison roll. EFFECT_BLAZE_KICK is the burn-hit row above plus
-- one crit stage.
BattleEngine.EFFECT_TRI_ATTACK = 36
BattleEngine.EFFECT_TWINEEDLE = 77
BattleEngine.EFFECT_BLAZE_KICK = 200
-- SetMoveEffect's MOVE_EFFECT_TRI_ATTACK case (src/battle_script_commands.c
-- :2466-2475): byte `Random() % 3 + 3`, i.e. 3 burn, 4 freeze, 5 paralysis
-- (include/constants/battle.h:223-225), indexed here by `% 3 + 1`.
BattleEngine.TRI_ATTACK_KINDS = { "burn", "freeze", "paralysis" }
-- Status slice S4 (data/battle_scripts_1.s:2247-2270, :2515-2525).
-- Confusion/flinch slice C2: status2 secondaries (seteffectwithchance) and
-- the confusion-causing status moves.
BattleEngine.STATUS2_HIT_MOVES = {
  [76] = "confusion",  -- EFFECT_CONFUSE_HIT (data/battle_scripts_1.s:1068-1070)
  [31] = "flinch",     -- EFFECT_FLINCH_HIT (:669-671)
  [150] = "flinch",    -- EFFECT_FLINCH_MINIMIZE_HIT (:1894-1897; Minimize unmodeled)
  [146] = "flinch",    -- EFFECT_TWISTER (:1822-1828; on-air unmodeled)
  [92] = "flinch",     -- EFFECT_SNORE (asleep path, :1264-1268)
  [75] = "flinch",     -- EFFECT_SKY_ATTACK (second turn, :790-791)
}
BattleEngine.EFFECT_SNORE = 92
-- Locked multi-turn slice M1: recharge (EFFECT_RECHARGE 80) and two-turn
-- charge moves (data/battle_scripts_1.s:777-806, :1061-1066, :1107-1111,
-- :1807-1820, :1899-1913).
BattleEngine.EFFECT_RECHARGE = 80
-- Slice M3: Thrash/Petal Dance/Outrage (data/battle_scripts_1.s:585-593).
BattleEngine.EFFECT_RAMPAGE = 27
BattleEngine.EFFECT_SEMI_INVULNERABLE = 155
BattleEngine.MOVE_SURF = 57
BattleEngine.MOVE_BOUNCE = 340
-- Semi-invulnerable charge kinds by move (setsemiinvulnerablebit,
-- src/battle_script_commands.c:8618-8634).
BattleEngine.SEMI_INVULNERABLE_MOVES = {
  [19] = { kind = "fly", state = "air" },          -- Fly
  [91] = { kind = "dig", state = "underground" },  -- Dig
  [291] = { kind = "dive", state = "underwater" }, -- Dive
  [340] = { kind = "bounce", state = "air" },      -- Bounce
}
-- Moves that set the matching IGNORE hitmarker (data/battle_scripts_1.s
-- :239-243, 1822-1858, 1888-1891, 1916-1919, 2704-2706) and their x2.
BattleEngine.HITS_AIR = { [149] = 2, [146] = 2, [152] = 1, [207] = 1 } -- Gust, Twister, Thunder, Sky Uppercut
BattleEngine.HITS_UNDERGROUND = { [147] = 2, [126] = 2 }                -- Earthquake, Magnitude
BattleEngine.EFFECT_SKY_ATTACK = 75
BattleEngine.EFFECT_SKULL_BASH = 145
BattleEngine.CHARGE_MOVES = {
  [39] = "razorWind",   -- EFFECT_RAZOR_WIND
  [75] = "skyAttack",   -- EFFECT_SKY_ATTACK
  [145] = "skullBash",  -- EFFECT_SKULL_BASH
  [151] = "solarBeam",  -- EFFECT_SOLAR_BEAM (weather unmodeled: always charges)
  [155] = "semiInvulnerable", -- EFFECT_SEMI_INVULNERABLE (kind by move)
}
BattleEngine.EFFECT_CONFUSE = 49
BattleEngine.EFFECT_SWAGGER = 118
BattleEngine.EFFECT_FLATTER = 166
BattleEngine.EFFECT_TEETER_DANCE = 199
BattleEngine.ABILITY_OWN_TEMPO = 20
BattleEngine.ABILITY_INNER_FOCUS = 39
BattleEngine.EFFECT_FACADE = 169
BattleEngine.EFFECT_SMELLINGSALT = 171
BattleEngine.EFFECT_REFRESH = 193
-- Status-leftovers slice L2 (BattleScript_EffectRest, bs1.s:735-759;
-- BattleScript_EffectFocusEnergy, bs1.s:884-894).
BattleEngine.EFFECT_REST = 37
BattleEngine.EFFECT_FOCUS_ENERGY = 47
BattleEngine.MOVE_REST = 156
-- SetMoveEffect ability guards (include/constants/abilities.h ids).
BattleEngine.ABILITY_LIMBER = 7
BattleEngine.ABILITY_IMMUNITY = 17
BattleEngine.ABILITY_SHIELD_DUST = 19
BattleEngine.ABILITY_MAGMA_ARMOR = 40
BattleEngine.ABILITY_WATER_VEIL = 41
BattleEngine.ABILITY_INSOMNIA = 15
BattleEngine.ABILITY_VITAL_SPIRIT = 72
-- Primary status moves (slice S3): zero-power scripts with their own gate
-- order before accuracycheck (data/battle_scripts_1.s:287-301 Sleep,
-- :984-1003 Poison, :1005-1024 Paralyze, :687-706 Toxic, :2170-2185
-- Will-O-Wisp), then seteffectprimary.
BattleEngine.PRIMARY_STATUS_MOVES = {
  [1] = "sleep",       -- EFFECT_SLEEP
  [66] = "poison",     -- EFFECT_POISON
  [67] = "paralysis",  -- EFFECT_PARALYZE
  [33] = "toxic",      -- EFFECT_TOXIC
  [167] = "burn",      -- EFFECT_WILL_O_WISP
}
local STATUS_BLOCKING_ABILITY = {
  poison = 17, toxic = 17, burn = 41, paralysis = 7, freeze = 40,
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
}

-- The three bounded fixed-damage effects. Their real scripts still run the
-- ordinary accuracycheck -> ppreduce -> typecalc path, so type immunity is
-- meaningful, but they do not enter Cmd_critcalc or adjustnormaldamage:
-- Dragon Rage always deals 40 HP, SonicBoom always deals 20 HP, and the
-- level-damage family (Night Shade / Seismic Toss) deals the attacker's
-- level. TypeCalc's nonzero multipliers only set presentation result bits
-- for ordinary damage; these scripts clear those bits and retain their fixed
-- amount, while its zero multiplier still prevents HP loss.
BattleEngine.FIXED_DAMAGE_MOVES = {
  [41] = { amount = 40 },       -- EFFECT_DRAGON_RAGE
  [87] = { amount = "level" },  -- EFFECT_LEVEL_DAMAGE
  [130] = { amount = 20 },      -- EFFECT_SONICBOOM
}

-- Super Fang is separate from fixed damage: its real command derives the
-- amount from the defender's current HP after typecalc.
BattleEngine.CURRENT_HP_DAMAGE_MOVES = {
  [40] = true, -- EFFECT_SUPER_FANG
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
-- EFFECT_TWINEEDLE=77 (slice L1, data/battle_scripts_1.s:1072-1080) also
-- passes a literal 2 and sets sMULTIHIT_EFFECT = MOVE_EFFECT_POISON:
-- `statusKind` names the status the trailing roll can apply (77 only;
-- 29/44 set `sMULTIHIT_EFFECT` to 0, bs1.s:612, :845, so their roll never
-- applies anything). `sourceTail` (multi-hit tail follow-up, replacing the
-- L1 `statusKind` key, L1 review F2) selects resolveMultiHit's source tail:
-- a KO breaks the loop, the last hit's effectiveness text and the hit count
-- are still emitted, then ONE trailing seteffectwithchance roll for the
-- whole move, then the caller's faint check. Every current entry sets it;
-- see resolveMultiHit.
BattleEngine.MULTI_HIT_MOVES = {
  [29] = { fixed = nil, sourceTail = true }, -- EFFECT_MULTI_HIT (Double Slap, Comet Punch, Fury Attack,
                          -- Pin Missile, Spike Cannon, Barrage, Fury Swipes, Bone Rush, Arm Thrust,
                          -- Bullet Seed, Icicle Spear, Rock Blast): rolled 2-5 hits.
  [44] = { fixed = 2, sourceTail = true },   -- EFFECT_DOUBLE_HIT (Double Kick, Bonemerang): always 2 hits.
  [77] = { fixed = 2, sourceTail = true, statusKind = "poison" }, -- EFFECT_TWINEEDLE: 2 hits, then one
                                                                  -- 20% poison roll.
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
    -- Real gBattleMons[].status1 word (StatusConditions bit layout).
    status = opts.status or 0,
    -- status2 confusion turns (bits 0-2) and STATUS2_FLINCHED; battle-only,
    -- never persisted (include/constants/battle.h:105-107).
    confusionTurns = 0,
    flinched = false,
    -- STATUS2_FOCUS_ENERGY (battle.h:120): set by Focus Energy, +2 crit
    -- stages in critStageFor; battle-only, never persisted, no timer.
    -- Cleared on faint (recordFaint); a switch-in is a fresh battler.
    focusEnergy = false,
    -- Locked moves (status2 MULTIPLETURNS / RECHARGE, gLockedMoves).
    charging = false,
    semiInvulnerable = nil, -- "air" / "underground" / "underwater"
    recharging = false,
    rechargeTimer = 0,
    -- Rampage: STATUS2_LOCK_CONFUSE turns (0-3; MULTIPLETURNS is set exactly
    -- while it is nonzero for this family) and this turn's
    -- gProtectStructs[].targetNotAffected (reset at each runTurn start).
    rampageTurns = 0,
    targetNotAffected = false,
    lockedSlot = nil,
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
    turn = 0,
    runTries = 0, -- real gBattleStruct->runTries
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
      [BattleEngine.SIDE_PLAYER] = { reflect = false, reflectTimer = 0, lightScreen = false, lightScreenTimer = 0 },
      [BattleEngine.SIDE_FOE] = { reflect = false, reflectTimer = 0, lightScreen = false, lightScreenTimer = 0 },
    },
    firstBattle = opts.firstBattle == true,
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
    -- Authoritative post-faint state. awaitingForcedSwitch remains the
    -- compatibility view for existing controller/orchestrator callers.
    pendingForcedSwitches = {},
    faintSequence = nil,
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

function BattleEngine:_syncForcedSwitchHead()
  self.awaitingForcedSwitch = self.pendingForcedSwitches[1]
end

function BattleEngine:beginFaintSequence()
  assert(not self.faintSequence, "a faint sequence is already active")
  self.faintSequence = {}
end

function BattleEngine:recordFaint(side, events)
  local battler = self:battler(side)
  if battler.hp > 0 then return false end
  assert(self.faintSequence, "recordFaint needs beginFaintSequence")
  battler.hp = 0
  -- Real Cmd_cleareffectsonfaint (src/battle_script_commands.c:2930-2938)
  -- zeroes status1 and writes it to the party copy; FaintClearSetData
  -- clears status2 (confusion, flinch, Focus Energy).
  battler.status = 0
  battler.confusionTurns = 0
  battler.flinched = false
  battler.focusEnergy = false
  battler.charging, battler.recharging, battler.rechargeTimer, battler.lockedSlot = false, false, 0, nil
  battler.semiInvulnerable = nil
  battler.rampageTurns = 0
  for _, recorded in ipairs(self.faintSequence) do
    if recorded == side then return false end
  end
  self.faintSequence[#self.faintSequence + 1] = side
  events[#events + 1] = { type = "faint", side = side }
  return true
end

function BattleEngine:finalizeFaintSequence(events)
  local fainted = assert(self.faintSequence, "finalizeFaintSequence needs beginFaintSequence")
  self.faintSequence = nil
  if #fainted == 0 then return false end
  local playerAlive = self.hasReplacement and self.hasReplacement(BattleEngine.SIDE_PLAYER)
  local foeAlive = self.hasReplacement and self.hasReplacement(BattleEngine.SIDE_FOE)
  local playerFainted, foeFainted = false, false
  for _, side in ipairs(fainted) do
    playerFainted = playerFainted or side == BattleEngine.SIDE_PLAYER
    foeFainted = foeFainted or side == BattleEngine.SIDE_FOE
  end
  if playerFainted and not playerAlive and foeFainted and not foeAlive then
    self.outcome = "playerDrew"
  elseif playerFainted and not playerAlive then
    self.outcome = "playerLost"
  elseif foeFainted and not foeAlive then
    self.outcome = "playerWon"
  end
  if self.outcome then
    -- A decided battle sends no replacement (checkteamslost ends it before
    -- HandleFaintedMonActions), including a switch queued by an earlier
    -- faint sequence this turn (e.g. an end-of-turn status faint).
    self.pendingForcedSwitches = {}
    self:_syncForcedSwitchHead()
    events[#events + 1] = { type = "battleEnd", outcome = self.outcome }
    return true
  end
  local queued = {}
  for _, side in ipairs(self.pendingForcedSwitches) do queued[side] = true end
  for _, side in ipairs({ BattleEngine.SIDE_PLAYER, BattleEngine.SIDE_FOE }) do
    for _, recorded in ipairs(fainted) do
      if recorded == side and not queued[side] then
        queued[side] = true
        events[#events + 1] = { type = "forcedSwitchNeeded", side = side }
      end
    end
  end
  -- Real HandleFaintedMonActions walks battlers in id order, so the
  -- player's replacement always comes first, even when separate faint
  -- sequences in one turn (move, then end-of-turn status) queued the foe
  -- first.
  self.pendingForcedSwitches = {}
  for _, side in ipairs({ BattleEngine.SIDE_PLAYER, BattleEngine.SIDE_FOE }) do
    if queued[side] then
      self.pendingForcedSwitches[#self.pendingForcedSwitches + 1] = side
    end
  end
  self:_syncForcedSwitchHead()
  return self.awaitingForcedSwitch ~= nil
end

function BattleEngine:supportsMove(move, moveId)
  if not move then return false end
  if move.effect == BattleEngine.EFFECT_DREAM_EATER then return false end
  if move.effect == BattleEngine.EFFECT_RESTORE_HP then
    return (moveId == 105 or moveId == 303)
      and move.power == 0 and move.target == MOVE_TARGET_USER
  end
  if BattleEngine.DUAL_STAT_UP_MOVES[move.effect] then
    return move.power == 0 and move.target == MOVE_TARGET_USER
  end
  if move.effect == BattleEngine.EFFECT_SOFTBOILED then
    return (moveId == 135 or moveId == 208)
      and move.power == 0 and move.target == MOVE_TARGET_USER
  end
  if move.effect == BattleEngine.EFFECT_SPLASH or move.effect == BattleEngine.EFFECT_HAZE
      or move.effect == BattleEngine.EFFECT_BELLY_DRUM then
    return move.power == 0 and move.target == MOVE_TARGET_USER
  end
  if move.effect == BattleEngine.EFFECT_PSYCH_UP or move.effect == BattleEngine.EFFECT_MEMENTO then
    return move.power == 0 and move.target == 0 -- MOVE_TARGET_SELECTED
  end
  if move.effect == BattleEngine.EFFECT_CONVERSION then
    return move.power == 0 and move.target == MOVE_TARGET_USER
  end
  if move.effect == BattleEngine.EFFECT_TICKLE then
    return move.power == 0 and move.target == 0 -- MOVE_TARGET_SELECTED
  end
  if BattleEngine.PRIMARY_STATUS_MOVES[move.effect] then
    return move.power == 0 and move.target == 0 -- MOVE_TARGET_SELECTED
  end
  if move.effect == BattleEngine.EFFECT_REFRESH then
    return move.power == 0 and move.target == MOVE_TARGET_USER
  end
  if move.effect == BattleEngine.EFFECT_REST then
    return moveId == BattleEngine.MOVE_REST
      and move.power == 0 and move.target == MOVE_TARGET_USER
  end
  if move.effect == BattleEngine.EFFECT_FOCUS_ENERGY then
    return move.power == 0 and move.target == MOVE_TARGET_USER
  end
  if move.effect == BattleEngine.EFFECT_CONFUSE or move.effect == BattleEngine.EFFECT_SWAGGER
      or move.effect == BattleEngine.EFFECT_FLATTER then
    return move.power == 0 and move.target == 0 -- MOVE_TARGET_SELECTED
  end
  if move.effect == BattleEngine.EFFECT_TEETER_DANCE then
    return move.power == 0 and move.target == 0x20 -- MOVE_TARGET_FOES_AND_ALLY
  end
  return move.power > 0 or BattleEngine.STAT_STAGE_MOVES[move.effect] ~= nil
    or BattleEngine.SCREEN_MOVES[move.effect] ~= nil
    or move.effect == BattleEngine.EFFECT_PAIN_SPLIT
end

-- DMG_RECOIL_FROM_MISS at the accepted c75f352 source pin: halve, promote
-- zero, then cap by TARGET max HP. The arithmetic maxHP=1 edge stays zero.
function BattleEngine.recoilIfMissDamage(damage, targetMaxHP)
  local half = math.floor(damage / 2)
  if half == 0 then half = 1 end
  return math.min(half, math.floor(targetMaxHP / 2))
end

-- Resolves one attack, appending its events. Returns nothing; the caller
-- checks for a faint. Mirrors BattleScript_HitFromAccCheck's real order.
-- One move action: the core resolution below, then the move-end defrost
-- check (real MOVEEND_DEFROST, src/battle_script_commands.c:4103-4116): a
-- Fire move that dealt damage to a frozen target still above 0 HP thaws it.
function BattleEngine:resolveMove(attackerSide, moveSlot, events)
  self.currentMove = nil
  self.moveDamageDealt = 0
  self:resolveMoveCore(attackerSide, moveSlot, events)
  local defenderSide = otherSide(attackerSide)
  local defender = self:battler(defenderSide)
  if self.currentMove and self.currentMove.type == BattleEngine.TYPE_FIRE
      and self.moveDamageDealt > 0 and defender.hp > 0
      and StatusConditions.isFrozen(defender.status)
      and not self:isOver() then
    defender.status = defender.status - StatusConditions.FREEZE
    events[#events + 1] = { type = "defrostedByFire", side = defenderSide }
  end
  self.currentMove = nil
end

-- Real AtkCanceller_UnableToUseMove status cases (src/battle_util.c
-- :1266-1333 sleep/freeze, :1361-1371 flinch, :1407-1435 confusion,
-- :1439-1449 paralysis, :1513-1525 thaw), in source order. Returns true when
-- the move is cancelled: none of these failures prints "used" or deducts
-- PP (they jump to BattleScript_MoveEnd before attackstring/ppreduce).
-- Draws: freeze `Random() % 5` on every frozen attempt (thaw-hit moves
-- included); confusion `Random() & 1` while still confused after the
-- decrement, plus the self-hit's random multiplier; paralysis
-- `Random() % 4` on every paralyzed attempt that reaches it.
function BattleEngine:resolveStatusCancellers(attackerSide, attacker, moveId, move, events)
  local S = StatusConditions
  local status = attacker.status or 0
  local snoreAsleep = false
  if S.isAsleep(status) then
    -- CANCELLER_ASLEEP: decrement first (Early Bird not represented).
    local turns = S.sleepTurns(status) - 1
    attacker.status = S.withSleepTurns(status, turns)
    if turns > 0 then
      -- Snore/Sleep Talk pass the canceller; Snore's own script prints
      -- "fast asleep" after attackcanceler, i.e. after every remaining
      -- canceller (data/battle_scripts_1.s:1253-1266), so it is emitted at
      -- the end below. Its awake failure is handled in resolveMoveCore.
      if moveId ~= BattleEngine.MOVE_SNORE and moveId ~= BattleEngine.MOVE_SLEEP_TALK then
        events[#events + 1] = { type = "fastAsleep", side = attackerSide }
        return true
      end
      snoreAsleep = true
    else
      events[#events + 1] = { type = "wokeUp", side = attackerSide }
    end
  end
  if S.isFrozen(attacker.status) then
    -- CANCELLER_FROZEN
    if self.rng:next16() % 5 ~= 0 then
      if move.effect ~= BattleEngine.EFFECT_THAW_HIT then
        events[#events + 1] = { type = "frozenSolid", side = attackerSide }
        return true
      end
    else
      attacker.status = attacker.status - S.FREEZE
      events[#events + 1] = { type = "thawed", side = attackerSide }
    end
  end
  if attacker.recharging then
    -- CANCELLER_RECHARGE (src/battle_util.c:1349-1358).
    attacker.recharging = false
    attacker.rechargeTimer = 0
    self:cancelMultiTurnMoves(attacker)
    events[#events + 1] = { type = "mustRecharge", side = attackerSide }
    return true
  end
  if attacker.flinched then
    -- CANCELLER_FLINCH (src/battle_util.c:1361-1371).
    attacker.flinched = false
    self:cancelMultiTurnMoves(attacker)
    events[#events + 1] = { type = "flinched", side = attackerSide }
    return true
  end
  if (attacker.confusionTurns or 0) > 0 then
    -- CANCELLER_CONFUSED (:1407-1435): decrement first; still confused ->
    -- "is confused!" then `Random() & 1` (nonzero: the move proceeds and the
    -- remaining cancellers run); reaching 0 -> snapped out, move proceeds.
    attacker.confusionTurns = attacker.confusionTurns - 1
    if attacker.confusionTurns > 0 then
      events[#events + 1] = { type = "confusedTurn", side = attackerSide }
      if self.rng:next16() % 2 == 0 then
        self:resolveConfusionSelfHit(attackerSide, attacker, move, events)
        return true
      end
    else
      events[#events + 1] = { type = "confusionEnded", side = attackerSide }
    end
  end
  if S.isParalyzed(attacker.status) and self.rng:next16() % 4 == 0 then
    -- CANCELLER_PARALYSED
    events[#events + 1] = { type = "fullyParalyzed", side = attackerSide }
    self:cancelMultiTurnMoves(attacker) -- cancelmultiturnmoves (:3717)
    return true
  end
  if S.isFrozen(attacker.status) and move.effect == BattleEngine.EFFECT_THAW_HIT then
    -- CANCELLER_THAW
    attacker.status = attacker.status - S.FREEZE
    events[#events + 1] = { type = "defrostedByMove", side = attackerSide, move = moveId }
  end
  if snoreAsleep then
    events[#events + 1] = { type = "fastAsleep", side = attackerSide }
  end
  return false
end

-- Real SetMoveEffect for a secondary (non-primary) status byte on the
-- target (src/battle_script_commands.c:2110-2370). Represented guards in
-- source order: Shield Dust blocks every secondary status (:2132-2134);
-- target at 0 HP (:2140); the per-status ability (Immunity, Water Veil,
-- Limber print their prevention text only when `certain`, else fail
-- silently; Magma Armor is always silent); then type immunity and an
-- existing status (StatusConditions.canApply), which fail silently for a
-- secondary effect. Safeguard and Substitute are not represented.
function BattleEngine:applySecondaryStatus(targetSide, kind, certain, events)
  local target = self:battler(targetSide)
  if target.ability == BattleEngine.ABILITY_SHIELD_DUST then return false end
  if target.hp <= 0 then return false end
  local blocking = STATUS_BLOCKING_ABILITY[kind]
  if target.ability == blocking and kind ~= "freeze" then
    if certain then
      events[#events + 1] = {
        type = "statusPrevented", side = targetSide, kind = kind, ability = blocking,
      }
    end
    return false
  end
  local ok = StatusConditions.canApply(target, kind)
  if not ok then return false end
  if kind == "freeze" and target.ability == BattleEngine.ABILITY_MAGMA_ARMOR then
    return false
  end
  StatusConditions.apply(target, kind, self.rng)
  if kind == "sleep" or kind == "freeze" then self:cancelMultiTurnMoves(target) end
  events[#events + 1] = { type = "statusApplied", side = targetSide, kind = kind }
  return true
end

-- The primary status scripts' gates, in each script's own order (Substitute
-- and Safeguard are not represented). Every gate is RNG-free; the one
-- accuracycheck draw follows them, then seteffectprimary applies the
-- status (sleep draws its 2-5 turns there). Failure events:
--   statusAlready   "already asleep/poisoned/paralyzed/has a burn"
--   statusPrevented Immunity / Limber / Water Veil text (primary always prints)
--   stayedAwake     Insomnia / Vital Spirit (jumpifcantmakeasleep)
--   noEffect        "It doesn't affect" (Poison/Steel, Fire, typecalc x0)
--   moveFailed      any other existing status
function BattleEngine:resolvePrimaryStatusMove(attackerSide, attacker, defenderSide, defender, move, kind, events)
  local S = StatusConditions
  local status = defender.status or 0
  local function isType(t) return defender.types[1] == t or defender.types[2] == t end
  local function already()
    events[#events + 1] = { type = "statusAlready", side = defenderSide, kind = kind }
  end
  local function prevented(ability)
    events[#events + 1] = { type = "statusPrevented", side = defenderSide, kind = kind, ability = ability }
  end
  local function notAffected()
    events[#events + 1] = { type = "noEffect", side = attackerSide, target = defenderSide }
  end
  local function failed()
    events[#events + 1] = { type = "moveFailed", side = attackerSide }
  end
  local poisonOrSteel = isType(S.TYPE_POISON) or isType(S.TYPE_STEEL)
  local anyStatus = S.hasAny(status)

  if kind == "sleep" then
    if S.isAsleep(status) then return already() end
    if defender.ability == BattleEngine.ABILITY_INSOMNIA
        or defender.ability == BattleEngine.ABILITY_VITAL_SPIRIT then
      events[#events + 1] = { type = "stayedAwake", side = defenderSide, ability = defender.ability }
      return
    end
    if anyStatus then return failed() end
  elseif kind == "poison" then
    if defender.ability == BattleEngine.ABILITY_IMMUNITY then return prevented(defender.ability) end
    if S.isPoisoned(status) or S.isBadlyPoisoned(status) then return already() end
    if poisonOrSteel then return notAffected() end
    if anyStatus then return failed() end
  elseif kind == "paralysis" then
    if defender.ability == BattleEngine.ABILITY_LIMBER then return prevented(defender.ability) end
    local _, flags = BattleFormulas.typeCalc(1, move.type, attacker.types, defender.types, self.typeChart)
    if flags.noEffect then return notAffected() end
    if S.isParalyzed(status) then return already() end
    if anyStatus then return failed() end
  elseif kind == "toxic" then
    if defender.ability == BattleEngine.ABILITY_IMMUNITY then return prevented(defender.ability) end
    if S.isPoisoned(status) or S.isBadlyPoisoned(status) then return already() end
    if anyStatus then return failed() end
    if poisonOrSteel then return notAffected() end
  elseif kind == "burn" then
    if S.isBurned(status) then return already() end
    if isType(S.TYPE_FIRE) then return notAffected() end
    if defender.ability == BattleEngine.ABILITY_WATER_VEIL then return prevented(defender.ability) end
    if anyStatus then return failed() end
  end

  if not self:accuracyRoll(attacker, defender, move, nil) then
    events[#events + 1] = { type = "miss", side = attackerSide }
    return
  end
  S.apply(defender, kind, self.rng)
  if kind == "sleep" then self:cancelMultiTurnMoves(defender) end
  events[#events + 1] = { type = "statusApplied", side = defenderSide, kind = kind }
end

-- Confusion self-hit: CalculateBaseDamage(attacker, attacker, MOVE_POUND,
-- sideStatus 0, power 40, type 0) -- the attacker's own attack/defense,
-- stages, burn and ability terms, no crit, no screens, no STAB/typecalc --
-- then Cmd_adjustnormaldamage2's random multiplier draw, the HP update and
-- tryfaintmon BS_ATTACKER (data/battle_scripts_1.s:3736-3755). Source tests
-- gCurrentMove's effect for the Explosion defense halving, so a confused
-- Self-Destruct/Explosion user halves its own defense.
BattleEngine.CONFUSION_SELF_HIT_POWER = 40
function BattleEngine:resolveConfusionSelfHit(side, battler, chosenMove, events)
  local pound = {
    power = BattleEngine.CONFUSION_SELF_HIT_POWER, type = 0,
    effect = (chosenMove and chosenMove.effect == BattleEngine.EFFECT_EXPLOSION)
      and BattleEngine.EFFECT_EXPLOSION or 0,
  }
  self:cancelMultiTurnMoves(battler) -- cancelmultiturnmoves (:3742)
  local damage = BattleFormulas.calculateBaseDamage(battler, battler, pound, false, nil)
  damage = BattleFormulas.applyRandomDamageMultiplier(damage, self.rng)
  if damage > battler.hp then damage = battler.hp end
  battler.hp = battler.hp - damage
  events[#events + 1] = {
    type = "confusionSelfHit", side = side, amount = damage, hpRemaining = battler.hp,
  }
  self:checkFaint(side, events)
end

-- SetMoveEffect MOVE_EFFECT_CONFUSION (src/battle_script_commands.c
-- :2405-2418) after the caller's script gates: Own Tempo or already
-- confused -> silent; otherwise `(Random() % 4) + 2` turns and "became
-- confused!". `eventType` replaces that text's event (the rampage end runs
-- BattleScript_ThrashConfuses instead, src/battle_util.c:966-968).
function BattleEngine:applyConfusion(targetSide, target, events, eventType)
  if target.ability == BattleEngine.ABILITY_OWN_TEMPO
      or (target.confusionTurns or 0) > 0 then
    return false
  end
  target.confusionTurns = (self.rng:next16() % 4) + 2
  events[#events + 1] = { type = eventType or "confusionApplied", side = targetSide }
  return true
end

-- Secondary confusion/flinch (SetMoveEffect, non-primary): Shield Dust
-- blocks both (effect bytes 7 and 8 are <= 9, :2132-2134); target at 0 HP
-- returns (:2140). Flinch: Inner Focus blocks silently (every in-scope
-- flinch is a non-certain secondary); otherwise the bit is set only when
-- the target has not had its turn yet (GetBattlerTurnOrderNum(target) >
-- gCurrentTurnActionNumber, :2435-2436) -- in this singles engine, only the
-- first mover of a two-move turn (self.flinchTargetPending). No message is
-- printed when the bit is set.
function BattleEngine:applySecondaryStatus2(targetSide, target, kind, events)
  if target.ability == BattleEngine.ABILITY_SHIELD_DUST then return false end
  if target.hp <= 0 then return false end
  if kind == "confusion" then
    return self:applyConfusion(targetSide, target, events)
  end
  if target.ability == BattleEngine.ABILITY_INNER_FOCUS then return false end
  if self.flinchTargetPending then
    target.flinched = true
    return true
  end
  return false
end

-- CancelMultiTurnMoves (src/battle_util.c:203-214), reduced to the
-- represented multi-turn state: the two-turn charge lock and the rampage
-- lock (MULTIPLETURNS + LOCK_CONFUSE; no fatigue confusion follows).
function BattleEngine:cancelMultiTurnMoves(battler)
  battler.charging = false
  battler.semiInvulnerable = nil
  battler.rampageTurns = 0
  if not battler.recharging then battler.lockedSlot = nil end
end

-- True when the side skips action selection for the coming turn
-- (MULTIPLETURNS or RECHARGE, src/battle_main.c:3125-3130): the controller
-- must not open a menu or run the foe AI, and runTurn uses the locked move.
-- A recharge whose timer would lapse at this turn's start (timer 1, the
-- battler did not act last turn) no longer locks. A rampage locks while
-- its LOCK_CONFUSE counter is nonzero.
function BattleEngine:isLocked(side)
  local b = self:battler(side)
  return b.charging or (b.rampageTurns or 0) > 0 or (b.recharging and b.rechargeTimer > 1)
end

-- AccuracyCalcHelper's semi-invulnerable checks: an ON_AIR / UNDERGROUND /
-- UNDERWATER target makes accuracycheck miss without RNG unless the move set
-- the matching IGNORE hitmarker (Surf only for underwater here).
function BattleEngine:semiInvulnerableMiss(defender, move, moveId)
  local state = defender.semiInvulnerable
  if not state then return false end
  if state == "air" then return BattleEngine.HITS_AIR[move.effect] == nil end
  if state == "underground" then return BattleEngine.HITS_UNDERGROUND[move.effect] == nil end
  return moveId ~= BattleEngine.MOVE_SURF
end

-- One accuracycheck: the semi-invulnerable miss first (no RNG), then the
-- ordinary roll.
function BattleEngine:accuracyRoll(attacker, defender, move, moveId)
  if self:semiInvulnerableMiss(defender, move, moveId) then return false end
  return BattleFormulas.accuracyCheck(move.accuracy, attacker.statStages.accuracy,
    defender.statStages.evasion, self.rng, attacker.ability, move.type)
end

function BattleEngine:resolveMoveCore(attackerSide, moveSlot, events)
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
  -- A locked battler skips action selection, so noValidMoves is never set
  -- and gLockedMoves is used (src/battle_main.c:3125-3130, 3983-3992).
  -- A side locked at this turn's start keeps its locked action even when
  -- the lock is cancelled before it moves (sleep/freeze applied by a faster
  -- foe); source chose that move at selection time.
  local turnLocked = self.lockedThisTurn and self.lockedThisTurn[attackerSide]
  local rampaging = (attacker.rampageTurns or 0) > 0
  local lockedTurn = attacker.charging or attacker.recharging or rampaging or turnLocked
  if lockedTurn then
    allMovesUnusable = false
    -- runTurn already passed the locked slot; a lock cancelled earlier this
    -- turn has cleared lockedSlot, so keep the slot the turn started with.
    moveSlot = attacker.lockedSlot or moveSlot
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

  local effectiveMoveId = slot and slot.move or BattleEngine.MOVE_STRUGGLE
  if not self:supportsMove(move, effectiveMoveId) then
    error(("unsupported move effect %d for non-damaging move %d")
      :format(move.effect or -1, slot and slot.move or BattleEngine.MOVE_STRUGGLE))
  end

  if move.effect == BattleEngine.EFFECT_FLAIL then
    -- Do not mutate shared ROM move data: stock writes a transient dynamic
    -- base power before entering the otherwise ordinary Hit script.
    local dynamicMove = {}
    for k, v in pairs(move) do dynamicMove[k] = v end
    dynamicMove.power = BattleEngine.flailPowerFromHP(attacker.hp, attacker.maxHP)
    move = dynamicMove
  end
  if move.effect == BattleEngine.EFFECT_ERUPTION then
    local dynamicMove = {}
    for k, v in pairs(move) do dynamicMove[k] = v end
    dynamicMove.power = BattleEngine.eruptionPowerFromHP(attacker.hp, attacker.maxHP, move.power)
    move = dynamicMove
  end

  -- (A locked action is exempt here; its 0-PP case is handled after the
  -- cancellers, as in source.)
  -- Defensive path only, real-game-unreachable: the caller selected a
  -- specific 0-PP slot while at least one OTHER slot of this battler still
  -- has PP (allMovesUnusable is false, so `slot` is set here, not Struggle).
  -- The real move-select menu greys out a 0-PP move and would never let a
  -- player submit this choice while another move remains available -- but
  -- this engine performs no UI-level move-menu validation, so a caller can
  -- still pass such a moveSlot. Don't crash, don't invent an action: keep
  -- the pre-existing no-op/noPP behavior for this specific unreachable case.
  if slot and slot.pp <= 0 and not lockedTurn then
    events[#events + 1] = { type = "noPP", side = attackerSide, move = slot.move }
    return
  end

  local moveId = effectiveMoveId
  if self:resolveStatusCancellers(attackerSide, attacker, moveId, move, events) then
    return
  end
  -- Source checks PP after the cancellers (src/battle_script_commands.c
  -- :833-842); a locked action whose lock was cancelled earlier this turn
  -- reaches it with no NO_PPDEDUCT, so a spent move reports no PP here.
  -- A live rampage (MULTIPLETURNS) bypasses the check (:838-839).
  if lockedTurn and not attacker.charging and not attacker.recharging
      and (attacker.rampageTurns or 0) == 0
      and slot and slot.pp <= 0 then
    events[#events + 1] = { type = "noPP", side = attackerSide, move = slot.move }
    return
  end
  self.noPPDeduct = false
  local chargeKind = BattleEngine.CHARGE_MOVES[move.effect]
  if chargeKind then
    if not attacker.charging then
      -- BattleScriptFirstChargingTurn: no attackstring, ppreduce,
      -- MOVE_EFFECT_CHARGING (lock), the turn-1 text; Skull Bash then DEF+1
      -- (silent at +6).
      if slot then slot.pp = slot.pp - 1 end
      attacker.charging = true
      attacker.lockedSlot = moveSlot
      local semi = BattleEngine.SEMI_INVULNERABLE_MOVES[moveId]
      if semi then
        chargeKind = semi.kind
        attacker.semiInvulnerable = semi.state
      end
      events[#events + 1] = { type = "chargeTurn", side = attackerSide, move = moveId, kind = chargeKind }
      if move.effect == BattleEngine.EFFECT_SKULL_BASH
          and attacker.statStages.defense < BattleFormulas.MAX_STAT_STAGE then
        attacker.statStages.defense = attacker.statStages.defense + 1
        events[#events + 1] = {
          type = "statChange", side = attackerSide, stat = "defense", stages = 1,
          stage = attacker.statStages.defense,
        }
      end
      return
    end
    -- BattleScript_TwoTurnMovesSecondTurn: clear the lock, no PP, then the
    -- ordinary hit from accuracycheck.
    attacker.charging = false
    attacker.lockedSlot = nil
    -- Turn 2 clears the semi-invulnerable bit at its accuracycheck on both
    -- the hit and miss paths; nothing observes it in between.
    attacker.semiInvulnerable = nil
    self.noPPDeduct = true
  end
  self.currentMove = move
  events[#events + 1] = { type = "useMove", side = attackerSide, move = moveId }
  local isMagnitude = moveId == BattleEngine.MOVE_MAGNITUDE
    and move.effect == BattleEngine.EFFECT_MAGNITUDE
  if isMagnitude then
    -- BattleScript_EffectMagnitude performs ppreduce, then its one strength
    -- roll/message, before it enters the ordinary single-defender hit path.
    -- Keep the selected power local, just as Flail/Eruption do, so the ROM
    -- record's nominal power 1 remains immutable.
    slot.pp = slot.pp - 1
    local level, power = BattleEngine.magnitudeResultFromRoll(self.rng:next16() % 100)
    local magnitudeMove = {}
    for k, v in pairs(move) do magnitudeMove[k] = v end
    magnitudeMove.power = power
    move = magnitudeMove
    events[#events + 1] = { type = "magnitude", side = attackerSide, level = level }
  end
  local isExplosion = move.effect == BattleEngine.EFFECT_EXPLOSION
  if isExplosion then
    -- Real EffectExplosion reaches ppreduce before tryexplosion. Damp scans
    -- every active battler; this bounded singles engine has these two only.
    slot.pp = slot.pp - 1
    if attacker.ability == BattleEngine.ABILITY_DAMP
        or defender.ability == BattleEngine.ABILITY_DAMP then
      events[#events + 1] = { type = "damp", side = attackerSide }
      return
    end
    -- Real tryexplosion sets the user's HP to 0 before accuracycheck, but
    -- faint scripts are deferred until the script reaches tryfaintmon.
    attacker.hp = 0
    events[#events + 1] = { type = "selfDestruct", side = attackerSide }

    local function settleExplosion(recordDefender)
      self:beginFaintSequence()
      if recordDefender then self:recordFaint(defenderSide, events) end
      self:recordFaint(attackerSide, events)
      self:finalizeFaintSequence(events)
    end

    -- EffectExplosion's stock script performs critcalc, damagecalc,
    -- typecalc, and adjustnormaldamage before accuracycheck. Their critical
    -- and random draws are therefore consumed before accuracy, including
    -- on the miss path.
    local rolledCrit = BattleFormulas.critRoll(self.rng, self:critStageFor(attacker, move))
    local isCrit = rolledCrit and not (self.firstBattle and not self.tutorialPlayerDamageDone)
    -- calculateBaseDamage halves defense for EFFECT_EXPLOSION after the
    -- ability terms (source order, src/pokemon.c:2505-2507).
    local damage = BattleFormulas.calculateBaseDamage(
      attacker, defender, move, isCrit, self.sideStatus[defenderSide])
    if isCrit then damage = damage * BattleFormulas.CRIT_MULTIPLIER end
    local flags
    damage, flags = BattleFormulas.typeCalc(
      damage, move.type, attacker.types, defender.types, self.typeChart)
    damage = BattleFormulas.applyRandomDamageMultiplier(damage, self.rng)
    local hit = self:accuracyRoll(attacker, defender, move, moveId)
    -- A miss after typecalc keeps DOESNT_AFFECT_FOE, so resultmessage
    -- (bsc.c:1937) prints "It doesn't affect" for an immune target.
    if not hit and not flags.noEffect then
      events[#events + 1] = { type = "miss", side = attackerSide }
      settleExplosion(false)
      return
    end
    if flags.noEffect then
      events[#events + 1] = { type = "noEffect", side = attackerSide, target = defenderSide }
      settleExplosion(false)
      return
    end
    if isCrit then events[#events + 1] = { type = "critical", side = attackerSide } end
    self:applyDamage(attackerSide, defenderSide, defender, damage, flags, events)
    settleExplosion(true)
    return
  end

  -- EffectEndeavor reaches ppreduce before its HP comparison, unlike the
  -- ordinary Hit family below. A non-viable target goes directly to the
  -- generic "But it failed" message and consumes no accuracy RNG.
  local isEndeavor = move.effect == BattleEngine.EFFECT_ENDEAVOR
  if isEndeavor then
    if slot then slot.pp = slot.pp - 1 end
    if defender.hp <= attacker.hp then
      events[#events + 1] = { type = "moveFailed", side = attackerSide }
      return
    end
  end

  if move.effect == BattleEngine.EFFECT_CONFUSE or move.effect == BattleEngine.EFFECT_TEETER_DANCE then
    -- BattleScript_EffectConfuse (data/battle_scripts_1.s:902-917) and, for
    -- the lone singles target, BattleScript_EffectTeeterDance (:2566-2618):
    -- attackstring/ppreduce, Own Tempo text, (Substitute), already confused
    -- text, accuracycheck, seteffectprimary. No RNG before accuracy.
    if slot then slot.pp = slot.pp - 1 end
    if defender.ability == BattleEngine.ABILITY_OWN_TEMPO then
      events[#events + 1] = { type = "confusionPrevented", side = defenderSide }
      return
    end
    if (defender.confusionTurns or 0) > 0 then
      events[#events + 1] = { type = "alreadyConfused", side = defenderSide }
      return
    end
    if not self:accuracyRoll(attacker, defender, move, moveId) then
      events[#events + 1] = { type = "miss", side = attackerSide }
      return
    end
    self:applyConfusion(defenderSide, defender, events)
    return
  end

  if move.effect == BattleEngine.EFFECT_SWAGGER or move.effect == BattleEngine.EFFECT_FLATTER then
    -- BattleScript_EffectSwagger/Flatter (:1604-1625, :2147-2168):
    -- (Substitute), accuracycheck BEFORE attackstring (a miss still prints
    -- "used" -- already emitted -- spends PP and misses), ppreduce;
    -- jumpifconfusedandstatmaxed (`:8196-8203`): confused AND stat at +6 ->
    -- But it failed; statbuffchange raises ATK+2 / SP.ATK+1 or skips
    -- silently at +6; then Own Tempo text, else seteffectprimary confusion
    -- (already confused: silent).
    local stat, delta = "attack", 2
    if move.effect == BattleEngine.EFFECT_FLATTER then stat, delta = "spAttack", 1 end
    local hit = self:accuracyRoll(attacker, defender, move, moveId)
    if slot then slot.pp = slot.pp - 1 end
    if not hit then
      events[#events + 1] = { type = "miss", side = attackerSide }
      return
    end
    local stages = defender.statStages
    if (defender.confusionTurns or 0) > 0 and stages[stat] == BattleFormulas.MAX_STAT_STAGE then
      events[#events + 1] = { type = "moveFailed", side = attackerSide }
      return
    end
    if stages[stat] < BattleFormulas.MAX_STAT_STAGE then
      stages[stat] = math.min(BattleFormulas.MAX_STAT_STAGE, stages[stat] + delta)
      events[#events + 1] = {
        type = "statChange", side = defenderSide, stat = stat, stages = delta, stage = stages[stat],
      }
    end
    if defender.ability == BattleEngine.ABILITY_OWN_TEMPO then
      events[#events + 1] = { type = "confusionPrevented", side = defenderSide }
      return
    end
    self:applyConfusion(defenderSide, defender, events)
    return
  end

  if move.effect == BattleEngine.EFFECT_SNORE
      and not StatusConditions.isAsleep(attacker.status) then
    -- BattleScript_EffectSnore (:1253-1258): awake (including just woken this
    -- turn) -> attackstring, ppreduce, But it failed.
    if slot then slot.pp = slot.pp - 1 end
    events[#events + 1] = { type = "moveFailed", side = attackerSide }
    return
  end

  if move.effect == BattleEngine.EFFECT_REFRESH then
    -- attackcanceler/attackstring/ppreduce, then
    -- Cmd_cureifburnedparalysedorpoisoned (src/battle_script_commands.c
    -- :8728-8742): any PSN/BRN/PAR/TOX on the user sets status1 to 0;
    -- otherwise "But it failed!". No accuracycheck, no RNG.
    if slot then slot.pp = slot.pp - 1 end
    local st = attacker.status or 0
    if StatusConditions.isPoisoned(st) or StatusConditions.isBurned(st)
        or StatusConditions.isParalyzed(st) or StatusConditions.isBadlyPoisoned(st) then
      attacker.status = 0
      events[#events + 1] = { type = "statusCured", side = attackerSide }
    else
      events[#events + 1] = { type = "moveFailed", side = attackerSide }
    end
    return
  end

  if move.effect == BattleEngine.EFFECT_REST then
    -- BattleScript_EffectRest (data/battle_scripts_1.s:735-759):
    -- attackcanceler/attackstring/ppreduce, no accuracycheck, no RNG.
    if slot then slot.pp = slot.pp - 1 end
    local st = attacker.status or 0
    if StatusConditions.isAsleep(st) then
      -- jumpifstatus STATUS1_SLEEP -> "is already asleep!" (:86). Defensive:
      -- CANCELLER_ASLEEP stops a sleeping user before this script.
      events[#events + 1] = { type = "statusAlready", side = attackerSide, kind = "sleep" }
      return
    end
    -- jumpifcantmakeasleep (src/battle_script_commands.c:6546-6566): the
    -- target is the user for MOVE_TARGET_USER. Uproar is not represented.
    if attacker.ability == BattleEngine.ABILITY_INSOMNIA
        or attacker.ability == BattleEngine.ABILITY_VITAL_SPIRIT then
      events[#events + 1] = { type = "stayedAwake", side = attackerSide, ability = attacker.ability }
      return
    end
    -- Cmd_trysetrest (:6480-6502): full HP -> BattleScript_AlreadyAtFullHp.
    if attacker.hp == attacker.maxHP then
      events[#events + 1] = { type = "restoreHPFull", side = attackerSide }
      return
    end
    -- `status1 & (u8)~STATUS1_SLEEP`: bits 3-7 (PSN/BRN/FRZ/PAR/TOX); the
    -- toxic counter (bits 8-11) does not count. Then status1 is overwritten
    -- with STATUS1_SLEEP_TURN(3), clearing every other bit and the counter.
    local statused = StatusConditions.isPoisoned(st) or StatusConditions.isBurned(st)
      or StatusConditions.isFrozen(st) or StatusConditions.isParalyzed(st)
      or StatusConditions.isBadlyPoisoned(st)
    attacker.status = StatusConditions.withSleepTurns(0, 3)
    events[#events + 1] = { type = "restSlept", side = attackerSide, statused = statused and true or false }
    -- BattleScript_PresentHealTarget (:2028-2036): damage = -maxHP,
    -- datahpupdate clamps to maxHP, "regained health!".
    local beforeHP = attacker.hp
    attacker.hp = attacker.maxHP
    events[#events + 1] = {
      type = "restoreHP", side = attackerSide, beforeHP = beforeHP,
      hpRemaining = attacker.hp, amount = attacker.hp - beforeHP,
    }
    return
  end

  if move.effect == BattleEngine.EFFECT_FOCUS_ENERGY then
    -- BattleScript_EffectFocusEnergy (data/battle_scripts_1.s:884-894):
    -- attackcanceler/attackstring/ppreduce, no accuracycheck, no RNG;
    -- jumpifstatus2 STATUS2_FOCUS_ENERGY -> But it failed!; otherwise
    -- Cmd_setfocusenergy (src/battle_script_commands.c:7383-7396).
    if slot then slot.pp = slot.pp - 1 end
    if attacker.focusEnergy then
      events[#events + 1] = { type = "moveFailed", side = attackerSide }
    else
      attacker.focusEnergy = true
      events[#events + 1] = { type = "focusEnergy", side = attackerSide }
    end
    return
  end

  local primaryStatus = BattleEngine.PRIMARY_STATUS_MOVES[move.effect]
  if primaryStatus then
    -- attackstring/ppreduce precede every gate in these scripts.
    if slot then slot.pp = slot.pp - 1 end
    self:resolvePrimaryStatusMove(attackerSide, attacker, defenderSide, defender,
      move, primaryStatus, events)
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
  local dualStatUp = BattleEngine.DUAL_STAT_UP_MOVES[move.effect]
  -- Tickle's both-at-minimum gate precedes its accuracycheck (no RNG).
  local isTickle = move.effect == BattleEngine.EFFECT_TICKLE
  local tickleGateFails = isTickle
    and defender.statStages.attack == BattleFormulas.MIN_STAT_STAGE
    and defender.statStages.defense == BattleFormulas.MIN_STAT_STAGE
  local needsAccuracyCheck = not isSelfTargetStat and not screenStatusKey
    and not dualStatUp and not tickleGateFails
    and move.effect ~= BattleEngine.EFFECT_ALWAYS_HIT
    and move.effect ~= BattleEngine.EFFECT_VITAL_THROW
    and move.effect ~= BattleEngine.EFFECT_OHKO
    and move.effect ~= BattleEngine.EFFECT_PAIN_SPLIT
    and move.effect ~= BattleEngine.EFFECT_RESTORE_HP
    and move.effect ~= BattleEngine.EFFECT_SOFTBOILED
    and move.effect ~= BattleEngine.EFFECT_SPLASH
    and move.effect ~= BattleEngine.EFFECT_HAZE
    and move.effect ~= BattleEngine.EFFECT_BELLY_DRUM
    and move.effect ~= BattleEngine.EFFECT_PSYCH_UP
    and move.effect ~= BattleEngine.EFFECT_TRIPLE_KICK
    and move.effect ~= BattleEngine.EFFECT_CONVERSION
    and move.effect ~= BattleEngine.EFFECT_MEMENTO

  -- The FIRST_BATTLE controller deliberately skips the first player
  -- accuracy RNG independently for a damaging move and for a (DOWN-family)
  -- stat move that actually rolls one. Foe attacks and subsequent player
  -- moves use the ordinary path.
  local tutorialAccuracy = needsAccuracyCheck and self.firstBattle
    and attackerSide == BattleEngine.SIDE_PLAYER
    and ((move.power > 0 and not self.tutorialPlayerDamageDone)
      or (move.power == 0 and not self.tutorialPlayerStatDone))
  -- Scripts whose accuracycheck short-circuits the roll (ALWAYS_HIT,
  -- Vital Throw, OHKO, Pain Split) still miss a semi-invulnerable target
  -- (AccuracyCalcHelper, src/battle_script_commands.c:958-1001).
  local scriptHasAccuracyCheck = needsAccuracyCheck
    or move.effect == BattleEngine.EFFECT_ALWAYS_HIT
    or move.effect == BattleEngine.EFFECT_VITAL_THROW
    or move.effect == BattleEngine.EFFECT_OHKO
    or move.effect == BattleEngine.EFFECT_PAIN_SPLIT
  local semiMiss = scriptHasAccuracyCheck and self:semiInvulnerableMiss(defender, move, moveId)
  local hit
  if semiMiss then
    hit = false
  elseif needsAccuracyCheck then
    hit = tutorialAccuracy or self:accuracyRoll(attacker, defender, move, moveId)
  else
    hit = true
  end

  -- 2. ppreduce -- real order: after the accuracy roll (or, for a
  -- self-target UP move, in the same slot where accuracycheck would have
  -- been), and on the miss path too (BattleScript_PrintMoveMissed also
  -- runs ppreduce). Real HITMARKER_NO_PPDEDUCT means Struggle (no `slot`,
  -- see above) skips this step entirely -- there is no move slot of its
  -- own to decrement.
  -- Rampage (data/battle_scripts_1.s:585-593): a locked hit jumps over
  -- ppreduce (jumpifstatus2 MULTIPLETURNS), but a locked miss reaches
  -- BattleScript_PrintMoveMissed's ppreduce, which spends nothing at 0 PP
  -- (bsc.c:1147; reachable because the 0-PP check is bypassed while locked).
  local rampageLocked = move.effect == BattleEngine.EFFECT_RAMPAGE
    and (attacker.rampageTurns or 0) > 0
  if slot and not isEndeavor and not isMagnitude and not self.noPPDeduct then
    if not rampageLocked then
      slot.pp = slot.pp - 1
    elseif not hit and slot.pp > 0 then
      slot.pp = slot.pp - 1
    end
  end

  if not hit then
    if semiMiss and (move.effect == BattleEngine.EFFECT_OHKO
        or move.effect == BattleEngine.EFFECT_PAIN_SPLIT) then
      -- NO_ACC_CALC(_CHECK_LOCK_ON) against a semi-invulnerable target jumps
      -- to the script's failure label without MISSED (bsc.c:1022-1025):
      -- "But it failed!", PP already spent, no RNG.
      events[#events + 1] = { type = "moveFailed", side = attackerSide }
      return
    end
    if BattleEngine.HITS_UNDERGROUND[move.effect] then
      -- BattleScript_HitAllWithUndergroundBonusMissed (bs1.s:1867-1875)
      -- runs typecalc: an immune target prints "It doesn't affect" instead
      -- of "missed" (resultmessage, bsc.c:1937). No RNG.
      local _, immunity = BattleFormulas.typeCalc(
        1, move.type, attacker.types, defender.types, self.typeChart)
      events[#events + 1] = immunity.noEffect
        and { type = "noEffect", side = attackerSide, target = defenderSide }
        or { type = "miss", side = attackerSide }
      return
    end
    if move.effect == 45 and (moveId == 26 or moveId == 136) then
      -- Ordinary accuracy failure already scans type immunity in source,
      -- before resultmessage/the crash guard. This pure query spends no RNG.
      -- AccuracyCalcHelper's semi-invulnerable miss returns before that
      -- scan, so the crash happens even against an immune target.
      local _, immunity = BattleFormulas.typeCalc(
        1, move.type, attacker.types, defender.types, self.typeChart)
      if immunity.noEffect and not semiMiss then
        events[#events + 1] = { type = "noEffect", side = attackerSide, target = defenderSide }
        return
      end
      events[#events + 1] = { type = "miss", side = attackerSide }
      -- HandleAction_UseMove resets both multipliers to 1; no critcalc on
      -- this leaf. Preserve base -> STAB/type -> random -> half/min/cap.
      local damage = BattleFormulas.calculateBaseDamage(
        attacker, defender, move, false, self.sideStatus[defenderSide])
      damage = BattleFormulas.typeCalc(damage, move.type, attacker.types, defender.types, self.typeChart)
      damage = BattleFormulas.applyRandomDamageMultiplier(damage, self.rng)
      local loss = math.min(attacker.hp, BattleEngine.recoilIfMissDamage(damage, defender.maxHP))
      attacker.hp = attacker.hp - loss
      events[#events + 1] = { type = "crash", side = attackerSide, amount = loss, hpRemaining = attacker.hp }
      -- Do not use applyDamage: it targets the defender and advances Oak's
      -- damage tutorial. No hit/effectiveness or ordinary recoil result here.
      self:checkFaint(attackerSide, events)
      return
    end
    if move.effect == BattleEngine.EFFECT_RAMPAGE and not semiMiss then
      -- A failed roll runs CheckWonderGuardAndLevitate (bsc.c:1102): an
      -- immune target sets targetNotAffected and resultmessage prints "It
      -- doesn't affect" (:1937); the rampage is cancelled at end of turn.
      -- AccuracyCalcHelper's semi-invulnerable miss returns before that
      -- scan (:958-1001): plain "missed", lock kept. Pure query, no RNG.
      local _, immunity = BattleFormulas.typeCalc(
        1, move.type, attacker.types, defender.types, self.typeChart)
      if immunity.noEffect then
        attacker.targetNotAffected = true
        events[#events + 1] = { type = "noEffect", side = attackerSide, target = defenderSide }
        return
      end
    end
    events[#events + 1] = { type = "miss", side = attackerSide }
    return
  end

  if move.power == 0 then
    if move.effect == BattleEngine.EFFECT_SPLASH then
      events[#events + 1] = { type = "splash" }
      return
    end
    if move.effect == BattleEngine.EFFECT_CONVERSION then
      -- Cmd_tryconversiontypechange (bsc.c:7003): count leading move slots;
      -- ??? (Curse) reads as GHOST for a Ghost user, else NORMAL; fail if
      -- every slot's type is already one of the user's; otherwise draw
      -- Random() & 3 until it names a valid slot whose type differs.
      local function slotType(i)
        local t = self.moves[attacker.moves[i].move].type
        if t == BattleFormulas.TYPE_MYSTERY then
          local ghost = attacker.types[1] == 7 or attacker.types[2] == 7
          t = ghost and 7 or 0
        end
        return t
      end
      local function isOwn(t) return t == attacker.types[1] or t == attacker.types[2] end
      local valid = 0
      while valid < 4 and attacker.moves[valid + 1] and attacker.moves[valid + 1].move ~= 0 do
        valid = valid + 1
      end
      local any = false
      for i = 1, valid do
        if not isOwn(slotType(i)) then any = true; break end
      end
      if not any then
        events[#events + 1] = { type = "moveFailed", side = attackerSide }
        return
      end
      local newType
      repeat
        local slot
        repeat slot = self.rng:next16() % 4 until slot < valid
        newType = slotType(slot + 1)
      until not isOwn(newType)
      attacker.types = { newType, newType }
      events[#events + 1] = { type = "conversion", side = attackerSide, newType = newType }
      return
    end
    if move.effect == BattleEngine.EFFECT_MEMENTO then
      -- Cmd_trymemento (bsc.c:8681): fail only if target ATK and SP.ATK are
      -- both at -6 (Protect not modeled). Otherwise attacker HP -> 0 first,
      -- then target ATK -2 and SP.ATK -2 (each silently skipped at -6), then
      -- tryfaintmon BS_ATTACKER.
      local stages = defender.statStages
      if stages.attack == BattleFormulas.MIN_STAT_STAGE
          and stages.spAttack == BattleFormulas.MIN_STAT_STAGE then
        events[#events + 1] = { type = "moveFailed", side = attackerSide }
        return
      end
      attacker.hp = 0
      events[#events + 1] = { type = "mementoHP", side = attackerSide }
      for _, stat in ipairs({ "attack", "spAttack" }) do
        if stages[stat] > BattleFormulas.MIN_STAT_STAGE then
          stages[stat] = math.max(BattleFormulas.MIN_STAT_STAGE, stages[stat] - 2)
          events[#events + 1] = {
            type = "statChange", side = defenderSide, stat = stat, stages = -2, stage = stages[stat],
          }
          if self.firstBattle and attackerSide == BattleEngine.SIDE_PLAYER
              and not self.tutorialPlayerStatDone then
            self.tutorialPlayerStatDone = true
            events[#events + 1] = { type = "tutorialTip", kind = "stat" }
          end
        end
      end
      self:checkFaint(attackerSide, events)
      return
    end
    if move.effect == BattleEngine.EFFECT_HAZE then
      -- Cmd_normalisebuffs: every battler's stages back to neutral.
      for _, battler in ipairs({ self.player, self.foe }) do
        for stat in pairs(battler.statStages) do
          battler.statStages[stat] = BattleFormulas.DEFAULT_STAT_STAGE
        end
      end
      events[#events + 1] = { type = "haze" }
      return
    end
    if move.effect == BattleEngine.EFFECT_PSYCH_UP then
      -- Cmd_copyfoestats copies every stage and never fails.
      for stat, stage in pairs(defender.statStages) do
        attacker.statStages[stat] = stage
      end
      events[#events + 1] = { type = "psychUp", side = attackerSide, target = defenderSide }
      return
    end
    if move.effect == BattleEngine.EFFECT_BELLY_DRUM then
      -- Cmd_maxattackhalvehp: fail unless ATK < +6 and HP > max(1, maxHP/2).
      local halfHP = math.max(1, math.floor(attacker.maxHP / 2))
      if attacker.statStages.attack >= BattleFormulas.MAX_STAT_STAGE
          or attacker.hp <= halfHP then
        events[#events + 1] = { type = "moveFailed", side = attackerSide }
        return
      end
      attacker.statStages.attack = BattleFormulas.MAX_STAT_STAGE
      attacker.hp = attacker.hp - halfHP
      events[#events + 1] = {
        type = "bellyDrum", side = attackerSide, amount = halfHP, hpRemaining = attacker.hp,
      }
      return
    end
    if move.effect == BattleEngine.EFFECT_RESTORE_HP
        or move.effect == BattleEngine.EFFECT_SOFTBOILED then
      if attacker.hp == attacker.maxHP then
        events[#events + 1] = { type = "restoreHPFull", side = attackerSide }
        return
      end
      local beforeHP = attacker.hp
      local requested = math.max(1, math.floor(attacker.maxHP / 2))
      attacker.hp = math.min(attacker.maxHP, attacker.hp + requested)
      events[#events + 1] = {
        type = "restoreHP", side = attackerSide, beforeHP = beforeHP,
        hpRemaining = attacker.hp, amount = attacker.hp - beforeHP,
      }
      return
    end
    if move.effect == BattleEngine.EFFECT_PAIN_SPLIT then
      -- Cmd_painsplitdmgcalc stores both signed deltas from the same
      -- pre-mutation average; the script then updates attacker before target.
      local average = math.floor((attacker.hp + defender.hp) / 2)
      local function applyPainSplitHP(side, battler)
        local beforeHP = battler.hp
        local afterHP = math.max(0, math.min(battler.maxHP, average))
        battler.hp = afterHP
        events[#events + 1] = {
          type = "painSplitHP", side = side, beforeHP = beforeHP,
          hpRemaining = afterHP, amount = afterHP - beforeHP,
        }
      end
      applyPainSplitHP(attackerSide, attacker)
      applyPainSplitHP(defenderSide, defender)
      events[#events + 1] = { type = "painSplit" }
      return
    end
    if isTickle then
      if tickleGateFails then
        events[#events + 1] = { type = "statsWontFall", side = defenderSide }
        return
      end
      local stages = defender.statStages
      for _, stat in ipairs({ "attack", "defense" }) do
        if stages[stat] > BattleFormulas.MIN_STAT_STAGE then
          stages[stat] = stages[stat] - 1
          events[#events + 1] = {
            type = "statChange", side = defenderSide, stat = stat, stages = -1,
            stage = stages[stat],
          }
          -- Oak first battle: the first defender-stat-fell message sets the
          -- stat tutorial flag and tip (battle_controller_oak_old_man.c:1766).
          if self.firstBattle and attackerSide == BattleEngine.SIDE_PLAYER
              and not self.tutorialPlayerStatDone then
            self.tutorialPlayerStatDone = true
            events[#events + 1] = { type = "tutorialTip", kind = "stat" }
          end
        end
      end
      return
    end
    if dualStatUp then
      local maxStage = BattleFormulas.MAX_STAT_STAGE
      local stages = attacker.statStages
      if stages[dualStatUp[1]] == maxStage and stages[dualStatUp[2]] == maxStage then
        events[#events + 1] = { type = "statsWontRise", side = attackerSide }
        return
      end
      for _, stat in ipairs(dualStatUp) do
        if stages[stat] < maxStage then
          stages[stat] = stages[stat] + 1
          events[#events + 1] = {
            type = "statChange", side = attackerSide, stat = stat, stages = 1,
            stage = stages[stat],
          }
        end
      end
      return
    end
    if screenStatusKey then
      self:resolveScreenMove(attackerSide, screenStatusKey, events)
      return
    end
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

  -- These scripts deliberately bypass critcalc/damagecalc/adjustnormaldamage
  -- after the shared accuracy and PP work above. They nevertheless execute
  -- the real typecalc route so immunity retains its normal no-effect result.
  -- A nonzero effectiveness multiplier must not change a fixed amount or
  -- produce effectiveness presentation; only zero is behaviorally relevant.
  local fixedDamageEntry = BattleEngine.FIXED_DAMAGE_MOVES[move.effect]
  if fixedDamageEntry then
    local fixedDamage = fixedDamageEntry.amount == "level"
      and attacker.level or fixedDamageEntry.amount
    local _, flags = BattleFormulas.typeCalc(
      fixedDamage, move.type, attacker.types, defender.types, self.typeChart
    )
    if flags.noEffect then
      events[#events + 1] = { type = "noEffect", side = attackerSide, target = defenderSide }
      return
    end
    flags.superEffective = false
    flags.notVeryEffective = false
    self:applyDamage(attackerSide, defenderSide, defender, fixedDamage, flags, events)
    return
  end

  if BattleEngine.CURRENT_HP_DAMAGE_MOVES[move.effect] then
    local _, flags = BattleFormulas.typeCalc(
      1, move.type, attacker.types, defender.types, self.typeChart
    )
    if flags.noEffect then
      events[#events + 1] = { type = "noEffect", side = attackerSide, target = defenderSide }
      return
    end
    flags.superEffective = false
    flags.notVeryEffective = false
    local damage = math.max(1, math.floor(defender.hp / 2))
    self:applyDamage(attackerSide, defenderSide, defender, damage, flags, events)
    return
  end

  if move.effect == BattleEngine.EFFECT_ENDEAVOR then
    -- setdamagetohealthdifference precomputed this after PP and before the
    -- ordinary accuracy step. The later set-damage path retains typecalc but
    -- bypasses critical/base/random damage and clears nonzero presentation.
    local _, flags = BattleFormulas.typeCalc(
      1, move.type, attacker.types, defender.types, self.typeChart
    )
    if flags.noEffect then
      events[#events + 1] = { type = "noEffect", side = attackerSide, target = defenderSide }
      return
    end
    flags.superEffective = false
    flags.notVeryEffective = false
    self:applyDamage(attackerSide, defenderSide, defender, defender.hp - attacker.hp, flags, events)
    return
  end

  if move.effect == BattleEngine.EFFECT_PSYWAVE then
    -- Stock runs typecalc before psywavedamageeffect, clears only nonzero
    -- effectiveness presentation, then samples even if typecalc was immune.
    local _, flags = BattleFormulas.typeCalc(
      1, move.type, attacker.types, defender.types, self.typeChart
    )
    flags.superEffective = false
    flags.notVeryEffective = false
    local damage = BattleEngine.psywaveDamageFromLevel(attacker.level, self.rng)
    if flags.noEffect then
      events[#events + 1] = { type = "noEffect", side = attackerSide, target = defenderSide }
      return
    end
    self:applyDamage(attackerSide, defenderSide, defender, damage, flags, events)
    return
  end

  if move.effect == BattleEngine.EFFECT_OHKO then
    local _, flags = BattleFormulas.typeCalc(1, move.type, attacker.types, defender.types, self.typeChart)
    if flags.noEffect then
      events[#events + 1] = { type = "noEffect", side = attackerSide, target = defenderSide }
      return
    end
    flags.superEffective = false; flags.notVeryEffective = false
    if not BattleEngine.ohkoSucceeds(attacker.level, defender.level, move.accuracy, self.rng) then
      events[#events + 1] = { type = "miss", side = attackerSide }
      return
    end
    self:applyDamage(attackerSide, defenderSide, defender, defender.hp, flags, events)
    return
  end

  if move.effect == BattleEngine.EFFECT_TRIPLE_KICK then
    self:resolveTripleKick(attackerSide, attacker, defenderSide, defender, move, events)
    return
  end

  if move.effect == BattleEngine.EFFECT_BRICK_BREAK then
    -- Source tests the timers (bsc.c:9444); flags and timers stay in sync
    -- via resolveScreenMove/decaySideTimers, so the flags are equivalent.
    local status = self.sideStatus[defenderSide]
    if status.reflect or status.lightScreen then
      status.reflect, status.reflectTimer = false, 0
      status.lightScreen, status.lightScreenTimer = false, 0
      events[#events + 1] = { type = "wallShattered", side = defenderSide }
    end
  end

  -- 3. critcalc (one Random()). Cmd_critcalc evaluates Random before its
  -- FIRST_BATTLE flag check, so the roll is still consumed while criticals
  -- are suppressed. Suppression is global until the first player damage
  -- message flips Oak's state flag, including a foe that attacks first.
  local rolledCrit = BattleFormulas.critRoll(self.rng, self:critStageFor(attacker, move))
  local isCrit = rolledCrit and not (self.firstBattle and not self.tutorialPlayerDamageDone)

  -- 4. damagecalc: base damage, then the real x2 crit multiply, which
  -- happens BEFORE typecalc. Real `sideStatus` param is the DEFENDER's own
  -- side (self.sideStatus[defenderSide] already has exactly the .reflect/
  -- .lightScreen fields calculateBaseDamage expects); a crit's non-crit
  -- gate is handled inside that function, not here.
  local damage = BattleFormulas.calculateBaseDamage(
    attacker, defender, move, isCrit, self.sideStatus[defenderSide])
  if isCrit then
    damage = damage * BattleFormulas.CRIT_MULTIPLIER
  end
  -- Cmd_damagecalc's dmgMultiplier (src/battle_script_commands.c:1215):
  -- Facade doubles when the user has PSN/BRN/PAR/TOX (burn halving still
  -- applies inside the base damage); Smelling Salt doubles against a
  -- paralyzed target (Substitute not represented).
  local st = attacker.status or 0
  if move.effect == BattleEngine.EFFECT_FACADE
      and (StatusConditions.isPoisoned(st) or StatusConditions.isBurned(st)
        or StatusConditions.isParalyzed(st) or StatusConditions.isBadlyPoisoned(st)) then
    damage = damage * 2
  elseif move.effect == BattleEngine.EFFECT_SMELLINGSALT
      and StatusConditions.isParalyzed(defender.status) then
    damage = damage * 2
  elseif defender.semiInvulnerable == "air" and BattleEngine.HITS_AIR[move.effect] then
    damage = damage * BattleEngine.HITS_AIR[move.effect]  -- Gust/Twister x2
  elseif defender.semiInvulnerable == "underground" and BattleEngine.HITS_UNDERGROUND[move.effect] then
    damage = damage * BattleEngine.HITS_UNDERGROUND[move.effect]  -- Earthquake/Magnitude x2
  elseif defender.semiInvulnerable == "underwater" and moveId == BattleEngine.MOVE_SURF then
    damage = damage * 2
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
      damage, move.type, attacker.types, defender.types, self.typeChart
    )
  end

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
    -- Rampage: typecalc sets targetNotAffected (bsc.c:1340); turn 1 sets
    -- no lock, a locked turn is cancelled at end of turn (no confusion).
    if move.effect == BattleEngine.EFFECT_RAMPAGE then attacker.targetNotAffected = true end
    if BattleEngine.HIT_VARIANT_STAT_MOVES[move.effect]
        or BattleEngine.SELF_DROP_HIT_MOVES[move.effect]
        or move.effect == BattleEngine.EFFECT_ALL_STATS_UP_HIT
        or BattleEngine.STATUS_HIT_MOVES[move.effect]
        or move.effect == BattleEngine.EFFECT_TRI_ATTACK
        or moveId == BattleEngine.MOVE_BOUNCE
        or BattleEngine.STATUS2_HIT_MOVES[move.effect]
        or move.effect == BattleEngine.EFFECT_SMELLINGSALT
        or move.effect == BattleEngine.EFFECT_RECHARGE
        or move.effect == BattleEngine.EFFECT_RAMPAGE then
      -- Smelling Salt's byte is CERTAIN, which skips the roll only when the
      -- move had an effect; a no-effect hit falls to the rolling branch.
      BattleFormulas.secondaryEffectRoll(self.rng, move.secondaryEffectChance)
    end
    return
  end

  if isCrit then
    events[#events + 1] = { type = "critical", side = attackerSide }
  end

  if move.effect == BattleEngine.EFFECT_FALSE_SWIPE and damage >= defender.hp then
    damage = math.max(0, defender.hp - 1)
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
  local selfDrop = BattleEngine.SELF_DROP_HIT_MOVES[move.effect]
  if selfDrop then
    -- CERTAIN branch: no Random(); the attacker is alive here (a recoil
    -- faint would have returned above and these moves have no recoil).
    for _, change in ipairs(selfDrop) do
      local current = attacker.statStages[change.stat]
      if current > BattleFormulas.MIN_STAT_STAGE then
        local newStage = math.max(BattleFormulas.MIN_STAT_STAGE, current + change.delta)
        attacker.statStages[change.stat] = newStage
        events[#events + 1] = {
          type = "statChange", side = attackerSide, stat = change.stat,
          stages = change.delta, stage = newStage,
        }
      end
    end
  end

  if move.effect == BattleEngine.EFFECT_ALL_STATS_UP_HIT
      and BattleFormulas.secondaryEffectRoll(self.rng, move.secondaryEffectChance) then
    local stages = attacker.statStages
    local order = { "attack", "defense", "speed", "spAttack", "spDefense" }
    local anyBelow = false
    for _, stat in ipairs(order) do
      if stages[stat] < BattleFormulas.MAX_STAT_STAGE then anyBelow = true end
    end
    if anyBelow then
      for _, stat in ipairs(order) do
        if stages[stat] < BattleFormulas.MAX_STAT_STAGE then
          stages[stat] = stages[stat] + 1
          events[#events + 1] = {
            type = "statChange", side = attackerSide, stat = stat, stages = 1, stage = stages[stat],
          }
        else
          events[#events + 1] = {
            type = "statChange", side = attackerSide, stat = stat, stages = 1, prevented = true,
          }
        end
      end
    end
  end

  local statusKind = BattleEngine.STATUS_HIT_MOVES[move.effect]
    or (moveId == BattleEngine.MOVE_BOUNCE and "paralysis" or nil)
  if statusKind
      and BattleFormulas.secondaryEffectRoll(self.rng, move.secondaryEffectChance) then
    -- Cmd_seteffectwithchance (:2789-2796): a chance of 100 or more calls
    -- SetMoveEffect with MOVE_EFFECT_CERTAIN.
    self:applySecondaryStatus(defenderSide, statusKind,
      move.secondaryEffectChance >= 100, events)
  end

  if move.effect == BattleEngine.EFFECT_TRI_ATTACK
      and BattleFormulas.secondaryEffectRoll(self.rng, move.secondaryEffectChance) then
    -- SetMoveEffect's outer call (src/battle_script_commands.c:2131-2146,
    -- :2466-2475): Shield Dust (byte 9 <= 9), then 0 HP, then the WHOLE
    -- status1 word (`if (status1)`, counter bits included -- not
    -- StatusConditions.hasAny). Each exits silently with no `% 3` draw.
    -- Otherwise `Random() % 3` picks the status and the recursive
    -- SetMoveEffect(FALSE, 0) re-runs the guards in applySecondaryStatus,
    -- whose ability/type/Magma Armor failures are silent after the draw.
    if defender.ability ~= BattleEngine.ABILITY_SHIELD_DUST and defender.hp > 0
        and (defender.status or 0) == 0 then
      local kind = BattleEngine.TRI_ATTACK_KINDS[(self.rng:next16() % 3) + 1]
      self:applySecondaryStatus(defenderSide, kind, false, events)
    end
  end

  if move.effect == BattleEngine.EFFECT_RECHARGE and attacker.hp > 0 then
    -- MOVE_EFFECT_RECHARGE | AFFECTS_USER | CERTAIN: no roll when the move
    -- had an effect, including a KO (src/battle_script_commands.c
    -- :2600-2605).
    attacker.recharging = true
    attacker.rechargeTimer = 2
    attacker.lockedSlot = moveSlot
  end

  if move.effect == BattleEngine.EFFECT_RAMPAGE then
    -- seteffectwithchance always draws `Random() % 100` (chance 100, not
    -- CERTAIN). confuseifrepeatingattackends set MOVE_EFFECT_THRASH |
    -- AFFECTS_USER only when LOCK_CONFUSE was clear (bsc.c:6849-6855), so
    -- only turn 1 locks: MULTIPLETURNS, gLockedMoves and
    -- LOCK_CONFUSE_TURN((Random() & 1) + 2) (:2719-2730). The guards test
    -- the live attacker, so a KO of the target still locks.
    BattleFormulas.secondaryEffectRoll(self.rng, move.secondaryEffectChance)
    if (attacker.rampageTurns or 0) == 0 and attacker.hp > 0 then
      attacker.rampageTurns = (self.rng:next16() % 2) + 2
      attacker.lockedSlot = moveSlot
    end
  end

  local status2Kind = BattleEngine.STATUS2_HIT_MOVES[move.effect]
  if status2Kind
      and BattleFormulas.secondaryEffectRoll(self.rng, move.secondaryEffectChance) then
    self:applySecondaryStatus2(defenderSide, defender, status2Kind, events)
  end

  if move.effect == BattleEngine.EFFECT_SMELLINGSALT and defender.hp > 0
      and StatusConditions.isParalyzed(defender.status) then
    -- MOVE_EFFECT_REMOVE_PARALYSIS | CERTAIN (no roll; :2690-2705).
    defender.status = defender.status - StatusConditions.PARALYSIS
    events[#events + 1] = { type = "paralysisHealed", side = defenderSide }
  end

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
  if defenderSide ~= attackerSide then
    self.moveDamageDealt = (self.moveDamageDealt or 0) + damage
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
-- neither repeats here. `entry.fixed` is EFFECT_DOUBLE_HIT's and
-- EFFECT_TWINEEDLE's real fixed `setmultihitcounter 2` arg (zero hit-count
-- RNG); otherwise this is
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
-- -> adjustnormaldamage -> apply damage (the faint handling depends on the
-- tail, see below). Real BattleScript_MultiHitLoop also opens with `jumpifhasnohp BS_ATTACKER`
-- (jumps to MultiHitEnd) before the BS_TARGET check -- confirmed dead code
-- for every move this engine actually supports: no real EFFECT_MULTI_HIT
-- EFFECT_DOUBLE_HIT or EFFECT_TWINEEDLE move also carries a recoil effect in this
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
-- multi-hit sequence.
--
-- Two tails, selected by `entry.sourceTail` (its own flag since the
-- multi-hit tail follow-up; L1 keyed it on `statusKind`, L1 review F2):
--   * Entries WITH sourceTail (every current entry: 29, 44 and 77) follow
--     the source tail exactly (data/battle_scripts_1.s:613-655):
--       - a target at 0 HP BREAKS the loop (jumpifhasnohp BS_TARGET, or
--         decrementmultihit reaching 0, both -> MultiHitPrintStrings); there
--         is no in-loop checkFaint;
--       - the per-hit damage events carry no effectiveness flags: the loop
--         body has critmessage but no resultmessage (:633). The single
--         `resultmessage` at MultiHitPrintStrings (:644-645) reports the
--         LAST landed hit's flags (movevaluescleanup resets them per hit),
--         so they ride on the multiHit event, which the controller prints
--         before "Hit N time(s)!";
--       - {type="multiHit", hits=<hits landed>} is then emitted (:646-649);
--       - then ONE seteffectwithchance (BattleScript_MultiHitEnd, :651)
--         for the whole move. Its `Random() % 100` is the first `&&`
--         operand (src/battle_script_commands.c:2789), so it is drawn on
--         every path that reaches MultiHitEnd whatever the effect byte and
--         secondaryEffectChance: for 29/44 the byte is 0 (`setbyte
--         sMULTIHIT_EFFECT, 0`, :612, :845; chance 0 in battle_moves.h) and
--         the draw applies nothing; for 77 SetMoveEffect returns on the
--         0-HP guard after a KO;
--       - the caller's ordinary defender faint check (runTurn) emits
--         `faint` (and `forcedSwitchNeeded` when a replacement exists)
--         after all of that (tryfaintmon BS_TARGET, :653).
--     The no-effect exit (MultiHitNoMoreHits -> resultmessage "It doesn't
--     affect..." -> jumpifmovehadnoeffect MultiHitEnd, :624, :642-647)
--     emits no count but still draws the roll (reachable for 29/44, e.g.
--     Double Kick or Fury Attack against a Ghost; unreachable for Bug).
--   * Entries WITHOUT sourceTail keep the pre-follow-up shape (checkFaint
--     after every landed hit, no count after a KO, effectiveness on every
--     damage event, no trailing roll). No current entry uses it.
function BattleEngine:resolveMultiHit(attackerSide, attacker, defenderSide, defender, move, entry, events)
  local hitCount
  if entry.fixed then
    hitCount = entry.fixed
  else
    hitCount = BattleFormulas.rollMultiHitCount(self.rng)
  end
  local sourceTail = entry.sourceTail == true

  local hits = 0
  -- The last landed hit's typecalc flags, for the single post-loop
  -- resultmessage (source tail only).
  local lastFlags
  for i = 1, hitCount do
    -- Real jumpifhasnohp BS_TARGET (top of BattleScript_MultiHitLoop): stop
    -- immediately if an earlier hit in this same sequence already fainted
    -- the defender. Unreachable on i==1 (runTurn only calls resolveMove for
    -- a battler with hp > 0), but real for i>1.
    if defender.hp <= 0 then break end

    local rolledCrit = BattleFormulas.critRoll(self.rng, self:critStageFor(attacker, move))
    local isCrit = rolledCrit and not (self.firstBattle and not self.tutorialPlayerDamageDone)

    local damage = BattleFormulas.calculateBaseDamage(
      attacker, defender, move, isCrit, self.sideStatus[defenderSide])
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
      if sourceTail then
        -- MultiHitNoMoreHits -> PrintStrings (resultmessage is the noEffect
        -- text, no count) -> MultiHitEnd: seteffectwithchance still draws
        -- (29/44/77 alike) and never applies (MOVE_RESULT_NO_EFFECT).
        BattleFormulas.secondaryEffectRoll(self.rng, move.secondaryEffectChance)
      end
      return
    end

    damage = BattleFormulas.applyRandomDamageMultiplier(damage, self.rng)

    if isCrit then
      events[#events + 1] = { type = "critical", side = attackerSide }
    end

    if sourceTail then
      -- No per-hit resultmessage in BattleScript_MultiHitLoop (bs1.s:619-
      -- 640): the damage event carries no effectiveness text; it moves to
      -- the multiHit event below.
      lastFlags = flags
      self:applyDamage(attackerSide, defenderSide, defender, damage,
        { superEffective = false, notVeryEffective = false }, events)
    else
      self:applyDamage(attackerSide, defenderSide, defender, damage, flags, events)
    end
    hits = hits + 1

    -- Older shape only (see above): tryfaintmon BS_TARGET checked every
    -- iteration, which stops the sequence and emits the faint at once.
    if not sourceTail and self:checkFaint(defenderSide, events) then
      return
    end
  end

  -- Reached with hits >= 1: on the source tail a KO breaks the loop
  -- instead of returning, so the count is emitted for it too.
  events[#events + 1] = {
    type = "multiHit", side = attackerSide, hits = hits,
    -- MultiHitPrintStrings' resultmessage (bs1.s:644-645), last hit's flags.
    superEffective = (lastFlags and lastFlags.superEffective) == true,
    notVeryEffective = (lastFlags and lastFlags.notVeryEffective) == true,
  }

  -- BattleScript_MultiHitEnd's seteffectwithchance: drawn for every source-
  -- tail entry; only an entry with a statusKind can apply anything.
  if sourceTail
      and BattleFormulas.secondaryEffectRoll(self.rng, move.secondaryEffectChance)
      and entry.statusKind then
    -- Shield Dust, 0 HP, Immunity, Poison/Steel type and an existing status
    -- all fail silently inside applySecondaryStatus (certain = false).
    self:applySecondaryStatus(defenderSide, entry.statusKind,
      move.secondaryEffectChance >= 100, events)
  end
end

-- EFFECT_TRIPLE_KICK loop (see the constant's comment). Per-hit power is
-- 10/20/30 via gDynamicBasePower; unlike the multi-hit loop, the damage
-- random roll comes before jumpifmovehadnoeffect. A defender fainted by an
-- earlier kick stops the loop (jumpifhasnohp) but still prints the hit
-- count; its faint is then handled by the caller's ordinary faint check.
-- The trailing seteffectwithchance Random() is not spent, matching the
-- tracked plain-hit gap; note the source spends it on every path here,
-- including a first-kick miss (bs1.s:1431).
function BattleEngine:resolveTripleKick(attackerSide, attacker, defenderSide, defender, move, events)
  local hits, power = 0, 0
  local stopped
  for _ = 1, 3 do
    if defender.hp <= 0 then break end
    if not self:accuracyRoll(attacker, defender, move, nil) then
      stopped = "miss"
      break
    end
    power = power + 10
    local kick = setmetatable({ power = power }, { __index = move })
    local rolledCrit = BattleFormulas.critRoll(self.rng, self:critStageFor(attacker, move))
    local isCrit = rolledCrit and not (self.firstBattle and not self.tutorialPlayerDamageDone)
    local damage = BattleFormulas.calculateBaseDamage(
      attacker, defender, kick, isCrit, self.sideStatus[defenderSide])
    if isCrit then damage = damage * BattleFormulas.CRIT_MULTIPLIER end
    local flags
    damage, flags = BattleFormulas.typeCalc(damage, move.type, attacker.types, defender.types, self.typeChart)
    damage = BattleFormulas.applyRandomDamageMultiplier(damage, self.rng)
    if flags.noEffect then
      stopped = "noEffect"
      break
    end
    if isCrit then events[#events + 1] = { type = "critical", side = attackerSide } end
    self:applyDamage(attackerSide, defenderSide, defender, damage, flags, events)
    hits = hits + 1
  end
  if hits == 0 then
    if stopped == "noEffect" then
      events[#events + 1] = { type = "noEffect", side = attackerSide, target = defenderSide }
    else
      events[#events + 1] = { type = "miss", side = attackerSide }
    end
    return
  end
  events[#events + 1] = { type = "multiHit", side = attackerSide, hits = hits }
end

-- Cmd_critcalc's stage (src/battle_script_commands.c:1184-1194), shared by
-- every critcalc site: the ordinary hit, Explosion's pre-accuracy calc,
-- each resolveMultiHit iteration and each Triple Kick kick (helper H1,
-- status-leftovers slice L1). +1 for EFFECT_HIGH_CRITICAL, EFFECT_SKY_ATTACK,
-- EFFECT_BLAZE_KICK and EFFECT_POISON_TAIL; BattleFormulas.critRoll clamps
-- to index 4. `2 * STATUS2_FOCUS_ENERGY` (attacker.focusEnergy, slice L2)
-- comes first; Scope Lens, Lucky Punch and Stick are not represented (no
-- held items).
BattleEngine.CRIT_STAGE_EFFECTS = {
  [43] = 1,  -- EFFECT_HIGH_CRITICAL
  [75] = 1,  -- EFFECT_SKY_ATTACK
  [200] = 1, -- EFFECT_BLAZE_KICK
  [209] = 1, -- EFFECT_POISON_TAIL
}
function BattleEngine:critStageFor(attacker, move)
  return 2 * (attacker.focusEnergy and 1 or 0)
    + (BattleEngine.CRIT_STAGE_EFFECTS[move.effect] or 0)
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
  self:beginFaintSequence()
  self:recordFaint(side, events)
  return self:finalizeFaintSequence(events)
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
  table.remove(self.pendingForcedSwitches, 1)
  self:_syncForcedSwitchHead()
  return { { type = "forcedSwitchResolved", side = side } }
end

-- Real BattleTurnPassed end-of-turn work (src/battle_main.c:2958-2964):
-- field effects (screen timers) first, then per-battler effects. Callers
-- only reach this when the battle is not over (the real gBattleOutcome == 0
-- gate). `sides` is the turn's action order: hoisted switch/item/run
-- actions first, otherwise the getWhoStrikesFirst order.
local HOISTED_ORDER = { BattleEngine.SIDE_PLAYER, BattleEngine.SIDE_FOE }
local function sidesOf(order)
  return { order[1][1], order[2][1] }
end

function BattleEngine:resolveEndTurn(events, sides)
  -- HandleEndTurn_ContinueBattle clears flinch before end-turn effects.
  self.player.flinched, self.foe.flinched = false, false
  -- ...and cancels a sleeping battler's multi-turn move (:2941-2942).
  for _, b in ipairs({ self.player, self.foe }) do
    if StatusConditions.isAsleep(b.status) and (b.charging or (b.rampageTurns or 0) > 0) then
      self:cancelMultiTurnMoves(b)
    end
  end
  self:decaySideTimers(events)
  self:resolveStatusEndTurn(events, sides)
end

-- Real DoBattlerEndTurnEffects status cases (src/battle_util.c:805-841),
-- per battler in turn order: poison max(1, maxHP/8); toxic counter
-- incremented first (capped at 15) then max(1, maxHP/16) * counter; burn
-- max(1, maxHP/8). Battlers at 0 HP are skipped. Each tick runs
-- tryfaintmon/checkteamslost (data/battle_scripts_1.s:3685-3686): a faint
-- that decides the battle stops the phase (BattleTurnPassed re-tests
-- gBattleOutcome); one that only queues a forced switch lets the remaining
-- battlers tick. The toxic counter is battle-local: BattlePartyBridge masks
-- it on persist.
function BattleEngine:resolveStatusEndTurn(events, sides)
  local S = StatusConditions
  for _, side in ipairs(sides) do
    if self:isOver() then return end
    local battler = self:battler(side)
    local status = battler.status or 0
    if battler.hp > 0 then
      local kind, amount
      if S.isPoisoned(status) then
        kind = "poison"
        amount = math.max(1, math.floor(battler.maxHP / 8))
      elseif S.isBadlyPoisoned(status) then
        local counter = S.toxicCounter(status)
        if counter ~= S.TOXIC_COUNTER_MAX then counter = counter + 1 end
        battler.status = S.withToxicCounter(status, counter)
        kind = "toxic"
        amount = math.max(1, math.floor(battler.maxHP / 16)) * counter
      elseif S.isBurned(status) then
        kind = "burn"
        amount = math.max(1, math.floor(battler.maxHP / 8))
      end
      if kind then
        if amount > battler.hp then amount = battler.hp end
        battler.hp = battler.hp - amount
        events[#events + 1] = {
          type = "statusDamage", side = side, kind = kind,
          amount = amount, hpRemaining = battler.hp,
        }
        if battler.hp == 0 then
          self:checkFaint(side, events)
        end
      end
    end
    -- ENDTURN_THRASH (src/battle_util.c:953-973), after this battler's
    -- status damage. A faint above already cleared the lock (recordFaint).
    if (battler.rampageTurns or 0) > 0 then
      battler.rampageTurns = battler.rampageTurns - 1
      if battler.targetNotAffected then
        -- WasUnableToUseMove: the cancel points that set the other flags
        -- already called cancelMultiTurnMoves during the turn.
        self:cancelMultiTurnMoves(battler)
      elseif battler.rampageTurns == 0 then
        battler.lockedSlot = nil
        if (battler.confusionTurns or 0) == 0 then
          -- SetMoveEffect(TRUE, CONFUSION | AFFECTS_USER): primary, so no
          -- Shield Dust/Safeguard; Own Tempo silent with no draw.
          self:applyConfusion(side, battler, events, "fatigueConfusion")
        end
      end
    end
  end
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
  events[#events + 1] = { type = "turnStart", turn = self.turn }
  -- STATUS2_FLINCHED is cleared for every battler between turns
  -- (src/battle_main.c:2940 HandleEndTurn_ContinueBattle; flinch only
  -- matters within the turn it was set, so clearing here is equivalent).
  self.player.flinched, self.foe.flinched = false, false
  -- gProtectStructs[].targetNotAffected is per turn (cleared with the
  -- other protect structs after the end-of-turn effects).
  self.player.targetNotAffected, self.foe.targetNotAffected = false, false
  -- A locked side's chosen action is replaced by its locked move.
  self.lockedThisTurn = {
    [BattleEngine.SIDE_PLAYER] = self:isLocked(BattleEngine.SIDE_PLAYER),
    [BattleEngine.SIDE_FOE] = self:isLocked(BattleEngine.SIDE_FOE),
  }
  if self:isLocked(BattleEngine.SIDE_PLAYER) then
    playerAction = { action = "move", moveSlot = self.player.lockedSlot }
  end
  if self:isLocked(BattleEngine.SIDE_FOE) then
    foeAction = { action = "move", moveSlot = self.foe.lockedSlot }
  end
  -- rechargeTimer counts down at each turn's action start; at 0 the
  -- recharge lapses unused (src/battle_main.c:3641-3646).
  for _, b in ipairs({ self.player, self.foe }) do
    if b.rechargeTimer > 0 then
      b.rechargeTimer = b.rechargeTimer - 1
      if b.rechargeTimer == 0 and b.recharging then
        b.recharging = false
        if not b.charging then b.lockedSlot = nil end
      end
    end
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
    -- Real gBattleOutcome == 0 gate (see decaySideTimers' comment): a
    -- switch-only turn still reaches real BattleTurnPassed and ticks the
    -- Reflect/Light Screen timers down, as long as the battle didn't just
    -- end.
    if not self:isOver() then
      self:resolveEndTurn(events, HOISTED_ORDER)
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
      self:resolveEndTurn(events, HOISTED_ORDER)
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
      self:resolveEndTurn(events, HOISTED_ORDER)
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

  for index, entry in ipairs(order) do
    local side, action = entry[1], entry[2]
    if self:battler(side).hp > 0 then
      -- Only the first mover's target still has its turn ahead (flinch).
      self.flinchTargetPending = index == 1
      self:resolveMove(side, action.moveSlot, events)
      self.flinchTargetPending = false
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
          self:resolveEndTurn(events, sidesOf(order))
        end
        return events
      end
      if self:checkFaint(otherSide(side), events) then
        if not self:isOver() then
          self:resolveEndTurn(events, sidesOf(order))
        end
        return events
      end
    end
  end

  -- Both actions for this ordinary move-exchange turn resolved without
  -- deciding the battle outcome -- the real gBattleOutcome == 0 case that
  -- reaches BattleTurnPassed and runs DoFieldEndTurnEffects.
  self:resolveEndTurn(events, sidesOf(order))

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
