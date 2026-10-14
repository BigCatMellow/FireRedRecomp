# Review: Phase 4 multi-turn M2 addendum (semi-invulnerable moves), design

- Reviewer: independent Reviewer (Claude), per `AGENTS.md` rule 6
- Date: 2026-10-14
- Under review: the "Slice M2 addendum: semi-invulnerable moves" section of
  `work/reports/phase4-multiturn-design-proposal.md` (commit `faf5b74`)
- Base engine: `HEAD` (`faf5b74`, M1 lock machinery merged). I also read the
  uncommitted M2 work in progress in `src/core/BattleEngine.lua` and
  `BattleSceneController.lua`. Where a design gap is already visible in it, the
  finding says so. That work is not under review.
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Verdict: **PASS WITH CORRECTIONS**. There are no Blockers. Two Major findings
  are wrong result texts (and, for Earthquake, wrong RNG). Two Minor findings
  are needed for the spec to be exact. The Info items record verified facts and
  states the engine cannot reach.

## Verified as stated

| Claim | Source | Result |
| --- | --- | --- |
| Turn 1: `BattleScriptFirstChargingTurn` (attackcanceler, empty string, ppreduce, `MOVE_EFFECT_CHARGING` lock, turn-1 text), then `setsemiinvulnerablebit`, then MoveEnd | `data/battle_scripts_1.s:1969-1991, 794-806` | OK |
| Texts "flew up high!", "dug a hole!", "hid underwater!", "sprang up!" | `src/battle_message.c:139-142` | OK |
| Bit by move: Fly/Bounce ON_AIR, Dig UNDERGROUND, Dive UNDERWATER (set and clear) | `src/battle_script_commands.c:8617-8653` | OK |
| Turn 2: attackcanceler, `setmoveeffect CHARGING` + `clearstatusfromeffect` (clears MULTIPLETURNS and zeroes the effect byte), `HITMARKER_NO_PPDEDUCT`, Bounce `setmoveeffect MOVE_EFFECT_PARALYSIS` (not CERTAIN), `accuracycheck ACC_CURR_MOVE`, clear the bit, `HitFromAtkString` | `:1993-2004` | OK |
| Miss: clear the bit, then `PrintMoveMissed` (attackstring "used", ppreduce does nothing under NO_PPDEDUCT, "missed") | `:2006-2008, 276-285` | OK |
| `AccuracyCalcHelper` order: Lock-On, ON_AIR, UNDERGROUND, UNDERWATER, then rain-Thunder / ALWAYS_HIT / Vital Throw. Semi misses set `MOVE_RESULT_MISSED` without RNG and without `CheckWonderGuardAndLevitate` | `src/battle_script_commands.c:958-1001` | OK (Swift and Vital Throw miss) |
| `JumpIfMoveAffectedByProtect` runs before the helper | `:1040` | OK (Protect not represented) |
| Hit-through: Twister (ON_AIR, x2, `:1822-1828`), Gust (`:1888-1891`), Thunder (IGNORE_ON_AIR unconditional, no x2, `:1916-1919`), Sky Uppercut (same, `:2704-2706`), Earthquake/Magnitude loop (UNDERGROUND, x2, `:1830-1875`; Magnitude enters it at `:1679-1688`), Surf (UNDERWATER, x2, before attackcanceler, `:239-243`) | as cited | OK |
| x2 position: `damage * gCritMultiplier * dmgMultiplier`, after the crit and before typecalc (the existing Facade/Smelling Salt block) | `:1215` | OK |
| `CancelMultiTurnMoves` clears `STATUS3_SEMI_INVULNERABLE` | `src/battle_util.c:210` | OK |
| Faint (`FaintClearSetData`) and switch-in (`SwitchInClearSetData`) zero status3 | `src/battle_main.c:2368, 2442` | OK |
| Move data: Fly 70/95, Dig 60/100, Dive 60/100 (chance 0), Bounce 85/85 chance 30; Thunder 70 acc chance 30; Sky Uppercut 85/90 | `src/data/battle_moves.h` | OK |

### Admitted effects against a semi-invulnerable target

The left column is the engine path at HEAD (`supportsMove` plus the effect tables).

| Engine path | Script `accuracycheck`? | Against an ON_AIR/UNDERGROUND/UNDERWATER target |
| --- | --- | --- |
| Plain hit family (0, 43 high crit, 101, 103, Flail/Eruption/Facade/Smelling Salt/Superpower/Overheat, `*_HIT` stat/status/flinch/confuse, Twister/Gust/Thunder/Sky Uppercut, Struggle, Brick Break, Absorb, Recoil, Multi/Double hit, charge turn 2, Recharge) | yes, ACC_CURR_MOVE | Misses with no RNG and prints "used" + "missed". Brick Break does not shatter screens. Hyper Beam does not lock recharge. |
| ALWAYS_HIT (17), Vital Throw (78) | yes, the helper runs first | Misses |
| Jump Kick / Hi Jump Kick (45) | yes, then `MoveMissedDoDamage` | Misses and still crashes (F3) |
| Super Fang (40), Dragon Rage/Sonic Boom/Level damage (41/130/87), Psywave (88) | yes, before attackstring | Misses. No Psywave draw. |
| Endeavor (189) | yes, after the HP gate | HP gate first ("But it failed!"), then the miss goes to `MoveMissedPause` and prints "missed" |
| OHKO (38), Pain Split (91) | `NO_ACC_CALC_CHECK_LOCK_ON` | Prints **"But it failed!"**, not "missed" (F1) |
| Explosion (7) | yes, after critcalc/damagecalc/typecalc/random | Draws spent, user faints, target untouched (F2 covers the text) |
| Triple Kick (104) | yes, per kick | In singles the first kick misses, so the move prints "missed" with no kick draws. The trailing roll is the tracked plain-hit gap. |
| Magnitude (126), Earthquake (147) | yes, after attackstring/ppreduce (and after the Magnitude roll/text) | UNDERGROUND: hits x2. ON_AIR/UNDERWATER: see F2 |
| Primary status (1, 33, 66, 67, 167) | yes, after every gate | Gates take precedence. Otherwise the `ButItFailed` label is taken, but MISSED is set, so `resultmessage` prints "missed". |
| Confuse (49), Teeter Dance (199) | yes, after Own Tempo / already-confused | Gates first, then "missed" |
| Swagger (118), Flatter (166) | yes, before attackstring | "Missed", PP spent |
| Stat-down (18-24, 58-62), Tickle (205) | yes (Tickle after its both-at-minimum gate) | Gate first, then "missed" |
| Stat-up, dual stat-up, Belly Drum, Conversion, Splash, Haze, Refresh, Reflect/Light Screen, Recover/Slack Off, Softboiled/Milk Drink | no | Unaffected |
| Psych Up (143), Memento (168) | no | Unaffected: Psych Up copies, Memento lowers the target's stats |

## Findings

### F1 (Major): OHKO and Pain Split fail with "But it failed!", they do not miss

Evidence: `Cmd_accuracycheck`'s NO_ACC_CALC branch
(`src/battle_script_commands.c:1020-1028`) jumps straight to the failure
pointer when the target has a semi bit. It does not set
`MOVE_RESULT_MISSED`. Both scripts point at `BattleScript_ButItFailed`
(`data/battle_scripts_1.s:765, 1239`), which ORs `MOVE_RESULT_FAILED`
(`:2054-2059`). `Cmd_resultmessage` then prints `STRINGID_BUTITFAILED`
(`:1945-1960`). The check comes after attackstring/ppreduce, so PP is spent.
It also comes before the OHKO `typecalc`, so Fissure against a Flying-type
Fly user prints "But it failed!" and not "It doesn't affect…". No RNG is
drawn. The WIP turns both into `hit = false`, which emits `miss`.

Correction (replace "OHKO and Pain Split (NO_ACC_CALC_CHECK_LOCK_ON) also miss"):

> OHKO and Pain Split use `accuracycheck BattleScript_ButItFailed,
> NO_ACC_CALC_CHECK_LOCK_ON` (`:765, :1239`). Against a semi-invulnerable target
> that branch jumps without setting MISSED (`:1024-1025`), so the move prints
> "used" and then "But it failed!" (`moveFailed`), with PP spent and no RNG. This
> happens before OHKO's typecalc and its level/accuracy roll, and before Pain
> Split's HP change. Lock-On is not represented.

### F2 (Major): Earthquake/Magnitude against a target in the air or underwater, and the miss text after typecalc

Evidence: on a semi miss, Earthquake's loop goes to
`BattleScript_HitAllWithUndergroundBonusMissed` (`data/battle_scripts_1.s
:1867-1875`): `pause`, **`typecalc`**, `effectivenesssound`, `resultmessage`.
There is no critcalc, damagecalc or random draw. `typecalc` sets
`DOESNT_AFFECT_FOE` on a Flying-type target. `resultmessage`
(`:1937`) prints the miss string only when DOESNT_AFFECT is clear (MISS_TYPE
is `B_MSG_MISSED` = 0). Otherwise it prints "It doesn't affect X…". Almost
every Fly user is Flying-type, so the common case of Earthquake against Fly
prints "It doesn't affect…". The design has a single "miss" helper. The WIP
emits `miss` from the generic block. Explosion has the same order (typecalc
`:394`, before accuracycheck `:396`, miss path `resultmessage` `:411-413`): a
type-immune semi target prints "It doesn't affect…". Only a Ghost-type user of
Dig (Sableye) can reach that case.

Correction (add to Source facts and Design):

> Earthquake/Magnitude against an ON_AIR or UNDERWATER target: attackstring,
> ppreduce (Magnitude also does its strength roll and text), then the miss leaf
> `:1867-1875`. That leaf runs typecalc only, with no crit, damage or random
> draws. It emits `noEffect` when the target is type-immune (Ground against
> Flying) and `miss` otherwise. The Levitate ground-miss text is unmodeled
> because the engine has no Levitate. Explosion's semi miss uses the same
> precedence: its typecalc has already run, so a type-immune target gives
> `noEffect` and any other target gives `miss`. Every other accuracycheck path
> emits `miss` on a semi miss, because the semi branch never calls
> `CheckWonderGuardAndLevitate`.

### F3 (Minor): Jump Kick crashes on a semi miss and skips the immunity scan

Evidence: `BattleScript_EffectRecoilIfMiss` (`:848-851`) sends a semi miss to
`BattleScript_MoveMissedDoDamage` (`:852-866`), so the crash happens. The
engine's effect-45 miss branch first queries type immunity and emits
`noEffect` with no crash. That is right for a rolled miss, because
`CheckWonderGuardAndLevitate` sets DOESNT_AFFECT (`:1094-1098`). It is wrong for
a semi miss, which never sets DOESNT_AFFECT. Against a type-immune semi target
(only a Ghost using Dig), source prints "missed" and then crashes. The crash
leaf's typecalc zeroes the damage and `DMG_RECOIL_FROM_MISS` promotes it to 1.
The addendum does not mention Jump Kick at all.

Correction (add):

> Jump Kick / Hi Jump Kick against a semi-invulnerable target miss without RNG
> and take the crash leaf (`:852-866`): "used", "missed", then the crash. The
> semi miss skips the existing type-immunity pre-scan, which applies only to a
> rolled miss, so the crash always happens. Its damage is the normal
> no-crit, typecalc, random, half, promote, cap formula, so a type-immune target
> yields 1.

### F4 (Minor): The semi check replaces the roll at its existing site, after every gate

Evidence: the gates come before `accuracycheck` in these scripts: primary
status (`:984-995, 1005-1015, 687-698`; for example, Thunder Wave against a
Ground-type Dig user prints "doesn't affect" through the typecalc gate),
Confuse and Teeter Dance (Own Tempo, already confused), Tickle (`:2648-2651`),
Endeavor (HP gate, `:2478-2480`), Explosion (Damp, then crit/damage/random,
`:381-396`), and Magnitude (strength roll). The addendum says "decides a
semi-invulnerable miss before any accuracy roll". That wording can be read as
"before the gates".

Correction (replace that sentence):

> A single helper, `accuracyRoll`, replaces the accuracy roll at each existing
> roll site. It returns a miss without RNG for a semi target the move does not
> reach. Each site keeps its gates, PP order and pre-accuracy draws ahead of the
> helper. Sites that do not roll but whose script still has an accuracycheck
> (ALWAYS_HIT, Vital Throw) call only the semi check. OHKO and Pain Split call
> it and fail as in F1. Sites with no script accuracycheck (the "unaffected" row
> of the table) never call it. Source order inside `Cmd_accuracycheck`: the
> FIRST_BATTLE/Pokédude short-circuit, then NO_ACC_CALC or (Protect, Lock-On,
> ON_AIR, UNDERGROUND, UNDERWATER, rain-Thunder/ALWAYS_HIT/Vital Throw), then the
> roll. Oak's tutorial short-circuit therefore comes before the semi check. No
> tutorial battler can reach that case.

### F5 (Info): Bounce's secondary and the turn-2 roll

`seteffectwithchance` rolls `Random() % 100 <= chance` (`:2789`). Bounce
paralyzes on 31 of 100 residues, the same as Thunder and every existing
secondary. Bounce shares effect 155, so it must be routed by move id, on turn 2
only, and also on a no-effect hit (the roll is drawn and discarded). Fly, Dig
and Dive reach turn 2 with effect byte 0 (cleared by `clearstatusfromeffect`,
`:2826`), so they follow the tracked plain-hit `seteffectwithchance` gap.
Earthquake and Magnitude have no `seteffectwithchance` in their loop, so they
match source exactly. Suggested wording: "Bounce: paralysis roll
`Random()%100 <= 30` on turn 2 (by move id). Fly/Dig/Dive: plain-hit roll gap."

### F6 (Info): Clear points and turn order

- The bit lives from turn 1's `setsemiinvulnerablebit` until the user's own
  turn-2 accuracycheck. On turn 2, a faster opponent still misses and a slower
  one hits normally. Clearing the bit at turn-2 entry, after the cancellers
  (the WIP), is equivalent: nothing reads the attacker's own bit before its
  accuracycheck.
- Singles resolve each move atomically, so a target cannot become
  semi-invulnerable after the attacker has passed its accuracycheck.
- `MOVEEND_ATTACKER_VISIBLE` (`src/battle_script_commands.c:4199-4209`) also
  clears the bit when the move had no effect or `WasUnableToUseMove`. That
  covers sleep and frozen stops, which do not call `CancelMultiTurnMoves`. The
  engine cannot reach those, because no admitted move puts a semi-invulnerable
  battler to sleep or freezes it. For robustness, recommend clearing
  `semiInvulnerable` on any canceller stop.
- Reachable interplay that should get tests:
  - Twister (hits ON_AIR, 20% flinch) from a faster foe on turn 2 makes the
    flinch canceller fire `cancelMultiTurnMoves`. The user becomes hittable and
    the Fly PP was already spent on turn 1.
  - Thunder or Bounce paralysis on an airborne user, then full paralysis on
    turn 2, cancels the move.
  - A confusion self-hit on turn 2 cancels the move.
- End-of-turn PSN/TOX/BRN damage still applies to a semi-invulnerable battler.
  `DoBattlerEndTurnEffects` has no semi check. Only sandstorm and hail exempt
  UNDERGROUND/UNDERWATER (`:7236-7252`), and weather is unmodeled. A faint there
  clears everything.

### F7 (Info): AI

The `AI_CheckBadMove` dispatch (`data/battle_ai_scripts.s`) has no entry for
effects 147, 149, 152, 155 or 207. Its only related entry is
`EFFECT_MAGNITUDE → AI_CBM_Magnitude` (`:175, 368-370`), which is already ported
(`AICheckBadMove.lua:575`). `AICheckBadMove.score` falls through to
`return 0` for the new effects, and none of them is in `UNPORTED_EFFECTS`, so
it raises no error. The Levitate gate for Ground moves is in step 1. FRLG
AI_CBM has no semi-invulnerable target check. `AI_CV_SemiInvulnerable`
(`:741`) belongs to CheckViability, which is out of scope as in M1. A locked
foe draws no AI RNG (M1).

### F8 (Info): Thunder accuracy and weather

Rain's always-hit is in `AccuracyCalcHelper` (`:993`). Sun's `moveAcc = 50` is
in `Cmd_accuracycheck` (`:1063-1064`). Weather is unmodeled, so Thunder rolls
70. Its IGNORE_ON_AIR is set unconditionally and it has no x2. Whirlpool's
underwater x2 stays in the blocked trap family. The line citations in the
addendum are correct. Magnitude's own entry is at `:1679-1688`; add it beside
the shared loop.

## Required before implementation

Apply the correction texts from F1 through F4 to the addendum. F5 through F8
are optional wording. The tests should cover:

- OHKO and Pain Split giving `moveFailed` against a semi target
- Earthquake/Magnitude against a Flying-type Fly user giving `noEffect` with
  zero crit/random draws, and against an airborne non-Flying target giving
  `miss`
- the Jump Kick crash on a semi miss
- a status-move gate taking precedence over the semi miss
- the Twister-flinch and Thunder-paralysis cancellations of turn 2
- end-of-turn poison on an airborne battler
