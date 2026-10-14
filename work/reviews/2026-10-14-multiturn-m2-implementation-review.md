# Review: Phase 4 multi-turn M2 (semi-invulnerable moves), implementation

- Reviewer: independent Reviewer (Claude)
- Date: 2026-10-14
- Under review: commit `396b34b` on `claude/wizardly-faraday-o45q9z`
  ("Multi-turn M2: Fly/Dig/Dive/Bounce and moves that reach them")
- Design: `work/reports/phase4-multiturn-design-proposal.md` (Slice M2
  addendum); task `work/tasks/phase4-multiturn-m2.md`
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
  (`bsc.c` = `src/battle_script_commands.c`, `bs1.s` =
  `data/battle_scripts_1.s`, `bm.c` = `src/battle_message.c`)
- Baseline: `lua5.1 tests/battle_multiturn_test.lua` 64/0;
  `bash scripts/test_all.sh` PASS (171 files, no-ROM mode);
  `lua5.1 scripts/check_repository.lua` PASS.

## Verdict: **PASS WITH CORRECTIONS**

The core mechanics match source. These are the charge turn and state by move,
the RNG-free semi-invulnerable miss, the hit-through table, the x2 position,
Bounce/Thunder paralysis, the turn-2 PP/text/clear behaviour, and clearing on
cancel, faint and switch. I found no state or RNG divergence on a reachable
common path. Three result-text divergences remain (F1-F3). One rare crash
divergence also draws one fewer `Random()` (F3). Mutation testing shows that
about half of the slice's claimed sites have no test (F4). Fix F1, F2 and F4
before the slice is marked accepted. F3, F5 and F6 can go in as documented
limits or small follow-ups.

## Verified as correct

| Area | Source | Engine | Result |
| --- | --- | --- | --- |
| Charge turn: ppreduce, lock, text, then `setsemiinvulnerablebit` (Fly/Bounce ON_AIR, Dig UNDERGROUND, Dive UNDERWATER). No RNG. | `bs1.s:1969-1991`; `bsc.c:8618-8634` | `BattleEngine.lua:1602-1609`, `SEMI_INVULNERABLE_MOVES` `:773-778` | OK (charge turn draws 0) |
| Turn 2: NO_PPDEDUCT, accuracycheck, the bit cleared on both paths, miss goes to `PrintMoveMissed` ("used" + "missed", no PP) | `bs1.s:1993-2008, 276-285`; `bsc.c:8637-8653` | `:1622-1628` clears at turn-2 entry, `noPPDeduct`; generic miss | OK. Nothing reads the attacker's own bit between entry and its accuracycheck. |
| AccuracyCalcHelper: ON_AIR/UNDERGROUND/UNDERWATER miss without RNG, before the ALWAYS_HIT/Vital Throw short-circuit; no `CheckWonderGuardAndLevitate` on this miss | `bsc.c:958-1001, 1031-1036` | `semiInvulnerableMiss` `:1470-1476`; main site `:1853-1865` | OK (Swift, Vital Throw miss; generic hit prints "missed") |
| Hit-through table: Gust/Twister ON_AIR x2; Thunder/Sky Uppercut ON_AIR x1; Earthquake/Magnitude UNDERGROUND x2; Surf UNDERWATER x2 (by move id) | `bs1.s:239-243, 1822-1828, 1830-1840, 1679-1688, 1888-1891, 1916-1919, 2704-2706` | `HITS_AIR`/`HITS_UNDERGROUND` `:781-782`, Surf `:1475` | OK. Effects 146/147/149/152/207/126 each have exactly one member (`battle_moves.h`), so keying by effect is exact. |
| x2 position: `base * gCritMultiplier * dmgMultiplier` in `Cmd_damagecalc`, before typecalc/STAB/random | `bsc.c:1215` | `:2253-2269` multiplies after the crit x2 and before `typeCalc` | OK. Integer products commute. Probe: Gust 6 → 12 in the air, and 12 → 24 on a crit. |
| Bounce: `setmoveeffect PARALYSIS` on turn 2 only, rolled in `seteffectwithchance` after damage, `Random()%100 <= 30` | `bs1.s:1998-2000, 268`; `bsc.c:2774-2796` | `:2425-2432` (`moveId == MOVE_BOUNCE`), no-effect roll `:2306` | OK. Draw order is acc, crit, random, effect. |
| Thunder: `setmoveeffect PARALYSIS` + IGNORE_ON_AIR | `bs1.s:1916-1919` | `STATUS_HIT_MOVES[152]` `:750` | OK (4 draws on a hit) |
| Magnitude: PP and strength roll before the accuracycheck | `bs1.s:1679-1688` | `:1632-1646` before `:1859` | OK |
| Explosion: crit/damage/random draws before the accuracycheck | `bs1.s:381-396` | `:1667-1690` uses `accuracyRoll` after the draws | OK (2 draws, user faints) |
| Other accuracycheck sites: primary status, Confuse/Teeter Dance, Swagger/Flatter, Triple Kick (gates first) | `bs1.s` per script | `:1379, 1727, 1745, 2694` via `accuracyRoll` | OK by reading. Untested, see F4. |
| No-accuracycheck scripts (Psych Up, Memento, Haze, self moves) unaffected | e.g. `bs1.s:1786` | `needsAccuracyCheck` false | OK |
| `CancelMultiTurnMoves` clears SEMI_INVULNERABLE | `battle_util.c:202-213` | `cancelMultiTurnMoves` `:1451-1455` | OK (paralysis, flinch, confusion, recharge, sleep/freeze apply) |
| Faint / switch-in zero status3 | `battle_main.c` FaintClearSetData / SwitchInClearSetData | `recordFaint` `:1064`; a switch installs a fresh battler | OK |
| Twister flinch from a faster foe on turn 2 cancels Fly; the user lands, PP was spent on turn 1 | `battle_util.c` CANCELLER_FLINCH + `:210` | Probe: x2 hit (12), `flinched`, `semiInvulnerable=nil`, PP 9 | OK |
| Controller texts | `bm.c:139-142`, `gFirstTurnOfTwoStringIds` `bm.c:1029-1039` | `BattleSceneController.lua:440-443` | OK, line breaks match |
| ROM fixture records (8 moves: effect/power/type/acc/pp/chance/target/flags) | `battle_moves.h` | `tests/phase4_semi_invulnerable_effect_rom_test.lua:19-28` | OK (every field checked by hand) |
| Inventory partition: 5 families (147/149/152/155/207), 8 positive moves B→R | — | 99→104, 235→243, 167→175; uncovered 48→40 over 35→30 effects | OK. The arithmetic and effect list agree. |

## Findings

### F1 (Major): OHKO and Pain Split print "missed" where source prints "But it failed!"

Source: both scripts use `accuracycheck BattleScript_ButItFailed,
NO_ACC_CALC_CHECK_LOCK_ON` (`bs1.s:765, 1239`). Against an
ON_AIR/UNDERGROUND/UNDERWATER target the NO_ACC_CALC branch jumps to the
failure pointer without setting `MOVE_RESULT_MISSED` (`bsc.c:1022-1025`).
`BattleScript_ButItFailed` ORs `MOVE_RESULT_FAILED` (`bs1.s:2054-2059`), so
`Cmd_resultmessage` prints `STRINGID_BUTITFAILED` (`bsc.c:1937-1960`). PP is
spent (attackstring/ppreduce come first). No RNG is drawn, and the check comes
before OHKO's typecalc.

Engine: `BattleEngine.lua:1859-1860` sets `hit = false` for both. The generic
miss at `:1877-1903` then emits `{type="miss"}`, which the controller renders
as "<X>'s attack missed!" (`BattleSceneController.lua:219-220`). Probe: Fissure
and Pain Split against a flier give `useMove,miss` with 0 draws. PP and RNG are
correct; the text is wrong. The addendum's own wording ("OHKO and Pain Split
... also miss") carries the same error.

Fix: for `EFFECT_OHKO` and `EFFECT_PAIN_SPLIT`, emit `moveFailed` on the
semi-invulnerable miss. Add a test for each. Correct the addendum sentence.

### F2 (Major): Earthquake/Magnitude against a type-immune target in the air print "missed" where source prints "It doesn't affect…"

Source: a semi miss in the Earthquake loop (Magnitude enters it at
`bs1.s:1688`) goes to `BattleScript_HitAllWithUndergroundBonusMissed`
(`bs1.s:1867-1875`): `pause`, **`typecalc`**, `effectivenesssound`,
`resultmessage`. `Cmd_typecalc` sets `MOVE_RESULT_DOESNT_AFFECT_FOE` for Ground
against Flying (`bsc.c:1303-1320`, `ModulateDmgByType` `:1246-1252`). With
`MISS_TYPE` still 0 (`B_MSG_MISSED`), `Cmd_resultmessage` (`bsc.c:1937`) skips
the miss string and prints `STRINGID_ITDOESNTAFFECT`. Most Fly/Bounce users are
Flying-type, so "Earthquake into Fly" is the common case. The leaf has no
crit, damage or random draws, so RNG already matches.

Engine: the generic miss emits `miss` (`:1901-1902`). Probe: Earthquake against
a Flying-type Fly user gives `useMove,miss`, 0 draws. The new test
`tests/battle_multiturn_test.lua:437-440` uses a Normal-type flier, so it does
not see the difference.

Fix: on the Earthquake/Magnitude semi miss, run the RNG-free type query (as the
effect-45 branch at `:1878-1886` does) and emit `noEffect` when the target is
immune, else `miss`. Levitate is not modeled. Add a Flying-type flier test.

The same precedence applies to Explosion, whose typecalc runs before its
accuracycheck (`bs1.s:394-396`, miss leaf `:411-413`). Against a type-immune
semi target, source prints "It doesn't affect…". The engine checks `hit` before
`flags.noEffect` (`BattleEngine.lua:1685-1694`) and prints "missed". Probe:
Explosion against a Ghost Dig user gives `selfDestruct,miss`. Only a Ghost Dig
user (Sableye, Shedinja) can reach this, so it is Low. It can be fixed in the
same change by testing `flags.noEffect` before `hit` in the semi case.

### F3 (Minor): Jump Kick/Hi Jump Kick against a type-immune semi target skip the crash and its draw

Source: the semi miss sets only MISSED (no `CheckWonderGuardAndLevitate`,
`bsc.c:966-990`). `BattleScript_MoveMissedDoDamage` (`bs1.s:852-871`) prints
"missed". `jumpifbyte ... DOESNT_AFFECT_FOE` is not taken, so source prints
"kept going and crashed", runs damagecalc/typecalc (damage 0), and
`adjustnormaldamage` draws one `Random()`. `DMG_RECOIL_FROM_MISS` then promotes
the 0 to 1 (`bsc.c:6465-6471`).

Engine: the effect-45 branch (`BattleEngine.lua:1878-1886`) always runs the
immunity pre-scan, which is right only for a rolled miss. Probe: HJK against a
Ghost Dig user gives `useMove,noEffect` with 0 draws. Source gives "missed",
then a crash for 1 HP, 1 draw. Against a non-immune digger the engine already
matches (`miss,crash`, 1 draw). Reachable only with Sableye or Shedinja (TM28
Dig) against a Jump Kick user. Fix by skipping the pre-scan when the miss came
from `semiInvulnerableMiss`, or record it as a known limit.

### F4 (Major, test coverage): most of the claimed sites and doubles survive mutation

Each mutation below was applied alone, both suites were run, and the file was
restored with `git checkout -- <file>`.

| # | Mutation (`src/core/BattleEngine.lua` unless noted) | Multi-turn test | Full suite |
| --- | --- | --- | --- |
| 1 | `semiInvulnerableMiss` never misses | 5 FAIL | FAIL |
| 2 | Drop ALWAYS_HIT from `scriptHasAccuracyCheck` | FAIL (Swift) | FAIL |
| 3 | Drop VITAL_THROW | **pass** | **pass** |
| 4 | Drop OHKO | **pass** | **pass** |
| 5 | Drop PAIN_SPLIT | **pass** | **pass** |
| 6 | Gust x2 → x1 | FAIL | FAIL |
| 7 | Twister x2 → x1 | **pass** | **pass** |
| 8 | Earthquake x2 → x1 | **pass** | **pass** |
| 9 | Magnitude x2 → x1 | **pass** | **pass** |
| 10 | Surf x2 → x1 | **pass** | **pass** |
| 11 | Surf no longer reaches underwater | FAIL | FAIL |
| 12 | Sky Uppercut no longer reaches air | FAIL | FAIL |
| 13 | Thunder no longer reaches air | FAIL | FAIL |
| 14 | Turn 2 does not clear the bit | FAIL | FAIL |
| 15 | `cancelMultiTurnMoves` does not clear | FAIL | FAIL |
| 16 | `recordFaint` does not clear | FAIL | FAIL |
| 17 | Bounce paralysis removed | FAIL | FAIL |
| 18 | Bounce removed from the no-effect roll list | pass | pass (unreachable: no type is immune to Flying, so no test is possible) |
| 19 | Thunder paralysis removed | FAIL | FAIL |
| 20 | Primary-status site uses the plain roll | **pass** | **pass** |
| 21 | Confuse/Teeter Dance site uses the plain roll | **pass** | **pass** |
| 22 | Swagger/Flatter site uses the plain roll | **pass** | **pass** |
| 23 | Explosion site uses the plain roll | **pass** | **pass** |
| 24 | Triple Kick site uses the plain roll | **pass** | **pass** |
| 25 | Charge kind not set from the move | FAIL | FAIL |
| 26 | Dig mapped to "air" | FAIL | FAIL |
| 27 | Bounce mapped to "underground" | **pass** | **pass** |
| 28 | Dive text (`BattleSceneController.lua`) | FAIL | FAIL |
| 29 | Main-site semi check skipped (roll path only) | FAIL (Swift) | FAIL |
| 30 | `accuracyRoll` draws the roll before the semi check | **pass** | **pass** |

Fifteen mutants survive. Excluding #18, which no test could catch, fourteen
are real gaps. The checks behind them are:

- `Earthquake hits a digger` (`:448`) and `Surf hits a diver` (`:456`) check
  only that damage happened, and Twister checks only that it hit (`:432`).
- No test touches Vital Throw, OHKO, Pain Split, or the five secondary
  accuracy sites. Mutation #30 shows that the "no RNG" claim at those sites
  is unguarded.
- `Gust doubles` (`:424`) uses `>= base * 2 - 1`. It catches #6, but an exact
  equality is available (6 → 12 with scripted rolls).

Add exact-damage x2 checks for Twister, Earthquake, Magnitude and Surf. Add a
0-draw miss for at least one secondary site (primary status or Confuse), plus
Explosion (2 draws) and Triple Kick. Add the F1 texts for OHKO and Pain Split,
the F2 Flying-type Earthquake case, a Vital Throw miss, and a check that
Bounce's state is "air" (Gust hits a bouncer).

### F5 (Minor, documentation): plain-hit `seteffectwithchance` roll gap on the newly represented hits

In source, `BattleScript_HitFromAtkString` ends with `seteffectwithchance`
(`bs1.s:268`). That command evaluates `Random() % 100` even with effect byte 0
(`bsc.c:2789`). The newly represented Gust and Sky Uppercut, Surf in its
underwater case, and Fly/Dig/Dive turn 2 therefore spend one more draw in
source than in the engine. Turn 2 has effect byte 0 because
`clearstatusfromeffect` zeroes it (`bsc.c` `Cmd_clearstatusfromeffect`). This
is the repository's tracked plain-hit gap
(`work/tasks/phase4-self-drop-tickle-batch.md`,
`work/reviews/2026-10-13-batch4-hit-effects-review.md` F1), not a new
regression. Earthquake and Magnitude have no `seteffectwithchance` in their
loop (`bs1.s:1836-1875`), and Thunder and Bounce roll it, so those match
exactly. The inventory rows for 149, 155 and 207
(`work/reports/phase4-move-effect-inventory.md`) and the task's Known limits
do not name the gap, as earlier slices' rows do (e.g. effect 104). Add a
clause to each.

### F6 (Minor, documentation): Earthquake row and design wording

- Row 147 says "Singles plain hit". Source Earthquake does attackstring and
  ppreduce before the accuracycheck (`bs1.s:1830-1833`), has no
  `seteffectwithchance`, and its miss leaf runs typecalc (F2). PP and draws
  agree with the engine, but the row should state the miss-text rule once F2
  is fixed.
- The addendum's "OHKO and Pain Split (NO_ACC_CALC_CHECK_LOCK_ON) also miss"
  should say they fail with "But it failed!" (F1).

### F7 (Info): states not reachable today

- Oak's FIRST_BATTLE short-circuit runs before AccuracyCalcHelper
  (`bsc.c:1007-1018`). The engine checks the semi miss first
  (`:1859-1862`). No tutorial battler has a semi-invulnerable move, so this
  is unreachable. A one-line comment would be enough.
- `MOVEEND_ATTACKER_VISIBLE` (`bsc.c:4199-4209`) also clears the bit when
  the move had no effect or the user was unable to move. Every reachable stop
  in this engine already goes through `cancelMultiTurnMoves`.
- Sandstorm/hail exempt UNDERGROUND/UNDERWATER (`bsc.c:7236-7252`), and
  Transform fails against a semi target (`:7403`). Weather and Transform are
  not represented.
- An independent design review of the addendum,
  `work/reviews/2026-10-14-multiturn-m2-design-review.md`, appeared
  untracked in the worktree while this review was running. Its F1-F3 agree
  with F1-F3 here. This review did not create or modify that file.

## Required before acceptance

1. F1: emit `moveFailed` for OHKO/Pain Split against a semi-invulnerable
   target, and add tests.
2. F2: run a typecalc-based `noEffect`/`miss` split on the Earthquake/Magnitude
   semi miss (and, optionally, on the Explosion one), and add a Flying-type
   flier test.
3. F4: add the missing tests listed above so that mutants 3-5, 7-10, 20-24, 27
   and 30 fail.
4. F5/F6: correct the inventory rows, the task's Known limits and the addendum
   wording.

F3 can be fixed or recorded as a known limit.

## Working tree

Every mutation was reverted with `git checkout -- <file>`.
`src/`, `tests/` and the tracked work files are unchanged. Probes were run from
the scratchpad. This file is left uncommitted.
