# Review: residual slice R1 implementation (255aa6b, 89f0b91) and the doc fold (9fb52ef)

- Reviewed: branch `claude/wizardly-faraday-o45q9z`. The commits are:
  - `255aa6b`: F7 follow-up, a signed prevented stat-move event;
  - `89f0b91`: residual R1;
  - `9fb52ef`: doc-only fold of the design review, skimmed for accuracy.
- Spec: `work/reports/phase4-residual-effects-design-proposal.md`, `work/reviews/2026-10-15-residual-effects-design-review.md`, `work/tasks/phase4-residual-r1.md`.
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`. I fetched the following fresh from the pin:
  - `src/battle_util.c` (bu.c);
  - `src/battle_main.c` (bm.c);
  - `src/battle_script_commands.c` (bsc.c);
  - `data/battle_scripts_1.s` (bs1.s);
  - `src/battle_message.c` (msg.c);
  - `include/constants/battle.h`.

  I used the local copies of `battle_moves.h` and `battle_ai_scripts.s` (`/tmp/claude-0/r1src/`).
- Role: independent implementation review. I edited no tracked file except this one, and committed nothing.

## Verdict: **PASS WITH CORRECTIONS**

The engine behaviour matches source for everything R1 models. I found no correctness defect. The required correction is a test gap: two mutants that remove the F1 `break` after the Nightmare and Curse ticks survive both the R1 test and `scripts/test_all.sh`. The code is right today, but nothing pins it (Finding 1). The remaining findings are Low or Info.

Runs at HEAD (89f0b91):

- `lua5.1 tests/battle_residual_r1_test.lua`: 103 passed, 0 failed.
- `bash scripts/test_all.sh`: PASS, 187 files (no-ROM mode).
- `lua5.1 scripts/check_repository.lua`: PASS.
- After all mutations, `git status` and `git diff` were empty, and `cmp` against fresh backups was clean.

## 1. Leech Seed KO and the team-loss flow (focus)

I traced `resolveStatusEndTurn` (`src/core/BattleEngine.lua:3802-3912`) against `DoBattlerEndTurnEffects` (bu.c:743-1060), `BattleScript_LeechSeedTurnDrain` (bs1.s:3223-3243), `BattleScript_DoTurnDmg` (bs1.s:3681-3688), `Cmd_checkteamslost` (bsc.c:3385-3420), `Cmd_tryfaintmon` (bsc.c:2831-2905) and `BattleTurnPassed` (bm.c:2953-2965).

| Requirement | Engine | Result |
| --- | --- | --- |
| Lazy open, no finalize at a seed KO | `:3846-3850`: opens only if `faintSequence` is nil, then `recordFaint(seeded)` and `recordFaint(receiver)` in tryfaintmon order (attacker, then target) | Correct. The drain script has no `checkteamslost`. |
| Finalize after every `DoTurnDmg` tick, fatal or not | `tickTeamCheck` `:3806-3813`, called at `:3874` (poison/toxic/burn), `:3881` (Nightmare) and `:3889` (Curse) | Correct. It records **only** the ticking side, which is a no-op above 0 HP. |
| No finalize after Rain Dish, the drain or the rampage tick | none called | Correct. Rain Dish (bs1.s:3938-3944) and Thrash have no team check. |
| F1: `isOver()` checked after each team check | `if tickTeamCheck(side) then break end` at all three sites; loop top `:3820` is `break` | Correct (see Finding 1 for the test gap). |
| F2: post-loop finalize | `:3911` | Correct. Every exit is a `break`, so it is always reached. When the battle was decided by a tick, the sequence is already nil. |
| No duplicate `faint` | `recordFaint` de-duplicates within a sequence. A tick can only record a battler that went from above 0 to 0 in that tick, and the drain requires both battlers above 0 HP | Correct. A battler that fainted mid-turn (weather, or a move) is never re-recorded. Probe P1: a sandstorm KOs the foe (replacement queued), then the seeded player's drain is skipped and the poison tick follows. Result: one foe `faint`, one `forcedSwitchNeeded`. |
| Draw | `finalizeFaintSequence` gives `playerDrew` when both recorded sides lack a replacement (`:1323-1324`), which mirrors the independent OR at bsc.c:3407-3420 | Correct. It is pinned by the ooze double KO and by a seed KO followed by fatal poison. Probe P7: a seed KO of the player, then the foe's fatal Nightmare tick, gives `playerDrew` with one faint per side. |
| Weather damage | `resolveWeatherEndTurn` keeps `checkFaint` (`:3739-3741`), and every field case precedes every battler case, so no sequence can be open (`beginFaintSequence` would assert) | Correct. |
| Rain Dish | Runs before the drain, matching ENDTURN_ABILITIES before ENDTURN_LEECH_SEED. After a deferred seed KO, the survivor's Rain Dish still runs, then `battleEnd` | Correct (pinned). |
| Status ticks | Same amounts. `damage()` clamps. A fatal tick with no open sequence equals the old `checkFaint` | Correct (no regression; earlier status tests pass). |
| Rampage | A seed-KO'd rampager is cleared by `recordFaint` (no fatigue). Probe P4: one faint, then a foe forced switch. F1 stops a survivor's rampage tick after a deciding Curse tick (probe Q2) | Correct. |
| Forced-switch replacement | The receiver is `otherSide(side)`, a slot, so a forced or voluntary replacement is healed. The drain is skipped while the slot is at 0 HP (bu.c:790-792). `finalizeFaintSequence` keeps the player-first queue order. A decided battle clears queued switches | Correct (pinned). |
| Controller battle end | `_runTurn`'s `after` (`BattleSceneController.lua:653-655`) reads `isOver()` and `awaitingForcedSwitch` after the whole event list. `battleEnd` has no text. `faint` emits its text with an hp=0 entry | Correct. |
| `main.lua` `playerDrew` (read-only) | `:4316` (Oak lab, loss branch), `:4352` (story mapped to `playerLost`), `:4416` (trainer whiteout), `:4493` (wild whiteout). Every `outcome ==` site handles it. `EarlyStory.lua:204` only ever receives the mapped value | No change needed. `main.lua` is untouched. |

Extra probes (scratch file only), all matching source:

- **P2.** A Liquid Ooze drain KOs the player, who has no replacement. The foe's burn tick then decides `playerLost`, and the player's pending Curse does not run.
- **P3.** The player goes first, its Curse tick is non-fatal, and the ooze KO afterwards gives `playerLost` at the post-loop finalize.
- **P5.** Both battlers are seeded. The player's self-KO by its own seed skips the foe's drain, because the receiver is at 0 HP.
- **P8.** Leech Seed and a Ghost Curse land in the same turn. The texts and HP entries come out in source order.

## 2. Per-battler order

bu.c:720-742 gives Ingrain, Abilities, Items1, Leech Seed, Poison, Bad Poison, Burn, Nightmares, Curse, Wrap, Uproar, Thrash. The engine runs Rain Dish, then the drain, then poison/toxic/burn, then Nightmare, then Curse, then the rampage tick (`:3821-3908`). One battler's whole list runs before the next, and the gates are `hp ~= 0`, as at bu.c:789-871. No semi-invulnerable gate exists, so a Dig user ticks (pinned). The Nightmare silent clear matches the FRLG re-check at bu.c:844-856. Order mutants (drain removed or moved, Nightmare disabled) are caught.

## 3. Leech Seed

- **Move** (`:2143-2167`).
  - `ppreduce` comes before `accuracyRoll`. A semi-invulnerable target gives no draw (AccuracyCalcHelper, bsc.c:958-1001).
  - `setseeded` order: a miss or an already-seeded target gives "evaded", then Grass in either type gives "noEffect", otherwise the target is seeded (bsc.c:6436-6456).
  - There is no typecalc, so a Ghost target is seeded.
  - Texts match msg.c:70, :159 and :160.
- **Drain** (`:3831-3850`).
  - The seeded battler loses `max(1, floor(maxHP/8))`, clamped to its HP, which is gHpDealt.
  - The receiver heals `min(missing, gHpDealt)`. With Liquid Ooze on the **seeded** battler (`jumpifability BS_ATTACKER`, bs1.s:3228), the receiver instead takes gHpDealt as damage, clamped.
  - The seeded HP update comes first, then the receiver's, then the text (msg.c:161 or :290).
  - At full HP the heal is 0 and the text still prints.
- **Seeder-slot heal**: a replacement is healed, both voluntary and forced (pinned).

## 4. Curse

- The Ghost test checks type1 or type2 (bsc.c:3826-3834). Running the cancellers first is equivalent.
- **Non-Ghost** (`:2196-2225`):
  - no accuracy step;
  - fails only at Speed −6 **and** Attack +6 **and** Defense +6 (bs1.s:1483-1485);
  - otherwise Speed −1, Attack +1 and Defense +1, in that order;
  - a capped stat carries a signed prevented event ("won't go lower/higher!"), because ChangeStatBuffs returns WORKED under ALLOW_PTR (bsc.c:6772-6813);
  - Mist, Protect and Clear Body exempt `MOVE_CURSE` (bsc.c:6679-6704), and none of them is modelled.
- **Ghost** (`:2226-2245`):
  - a semi-invulnerable target fails with no draw (`NO_ACC_CALC_CHECK_LOCK_ON`, bsc.c:1020-1025; F3: Ghost path only);
  - an already-cursed target fails;
  - the cost is `min(hp, max(1, floor(maxHP/2)))` (bsc.c:8093-8108);
  - the HP update comes before the text (bs1.s:1521-1525), then `checkFaint(attacker)`.
- **Tick**: `max(1, floor(maxHP/4))`, text before HP (bs1.s:3797-3801).
- All Curse mutants were caught: OR in the fail test, stat order, `stages = 0`, no semi-invulnerable check, no cursed check, cost /4, unclamped cost, type1-only, no self-faint, tick /8, no tick team check.

## 5. Nightmare

- **Move** (`:2170-2185`): no accuracy, typecalc or RNG. It fails when the target is already nightmared or awake (bs1.s:1455-1469).
- **Tick**: ¼ while asleep, otherwise a silent clear.
- **Canceller wake-up**: clears the flag (`:1483`, matching bu.c:1300).
- **Faint**: clears all three flags (`:1303`, matching bm.c:2441-2442).
- **Switch-in**: the incoming battler is fresh (`BattlePartyBridge` → `makeBattler`; no field copying anywhere).

## 6. Rapid Spin

- Seed arm (`:3087-3100`): it runs on a landed hit with no draw (CERTAIN and not NO_EFFECT, bsc.c:2786-2791). It comes before the target's faint, which matches `rapidspinfree` before `tryfaintmon BS_TARGET`. It removes the seed only; the wrap arm is R3 and is never set, so the else-if chain holds.
- Against a Ghost, effect 129 joins the no-effect discarded-roll list, giving 4 draws and keeping the seed (bsc.c:2792-2797).
- A miss draws 1.
- The `attacker.hp > 0` guard is an equivalent mutant: nothing modelled can drop a Rapid Spin user to 0 before the effect.

## 7. F7 fix (255aa6b)

- **Sign.** The pure stat-move path (`:2685-2692`) now emits `stages = delta` on a prevented event. Every pure stat move's cap test uses the sign of `delta`, so an UP move gets "won't go higher!" and a DOWN move (−1 or −2) gets "won't go lower!". This matches B_MSG_STAT_WONT_INCREASE / _DECREASE (bsc.c:6772-6775, :6799-6806).
- **Other emitters, unchanged:**
  - Curse uses signed values (`:2216`);
  - AncientPower uses `stages = 1` (`:3025`), which already printed "higher";
  - the hit-variant path keeps `stages = 0` (`:3122`).
- **Controller.** The controller (`BattleSceneController.lua:328-330`) is the only consumer of `statChange` events. It was not modified, and every test in the suite passes.
- **Out-of-scope note** (task, "Known limits"): **confirmed accurate.** For an UP secondary at +6 (Metal Claw style), `SetMoveEffect` calls `ChangeStatBuffs(…, affectsUser, 0)`, which returns DIDNT_WORK, so the effect is silent (bsc.c:2516-2536, :6812-6813). The engine prints "won't go lower!" (`:3120-3123`). A DOWN secondary at −6 returns WORKED and prints "won't go lower!" in source, so only the UP case is wrong. See Finding 4.
- **Tests.** Mutant M32, which reverts the fix, is caught by `battle_engine_test.lua` (3 failures).

## 8. AI

- `AICheckBadMove.lua:296`: Nightmare returns −10 when the target is already nightmared, before the −8 awake test (ai.s:237-240).
- `AICheckBadMove.lua:366`: Leech Seed returns −10 when the target is already seeded, before the Grass type1/type2 −10 (ai.s:414-420).
- Curse is unchanged (ai.s:438-441 has no Ghost test).
- The diff touches only those two handlers and their comments. The dispatch rows `[84]`, `[107]` and `[109]` were already present.
- The `AI_CV_*` references to these bits (ai.s:1085, :1269, :2018-2029, :2334) belong to scripts this engine does not run (TrainerAI uses only CheckBadMove).
- Both AI mutants (M34, M35) are caught.

## 9. Inventory, admission, ROM fixture

- **Admission.** Effects 84, 107 and 109 are admitted at power 0 with target SELECTED. The `moves.h` records at :952, :2226 and :2265 are all `MOVE_TARGET_SELECTED`. Rapid Spin was already admitted (power 20).
- **Totals.** 292 + 3 = 295 admitted and 62 − 3 = 59 rejected. Uncovered positive-power records go from 33 to 32 (Rapid Spin), over 24 effects.
- **Class deltas.** Represented gains 4 families, 4 moves, +1 positive and +3 zero. Blocked loses the same. The report table agrees with the test.
- **ROM fixture.** Every field matches `battle_moves.h`:
  - Leech Seed: 84/0/Grass 12/90/10/0/0/0x16 (PROTECT | MAGIC_COAT | MIRROR);
  - Nightmare: 107/0/Ghost 7/100/15/0/0/0x12;
  - Curse: 109/0/Mystery 9/0/10/0/0/0;
  - Rapid Spin: 129/20/Normal 0/100/40/0/0/0x33.

  The fixture skips cleanly without a ROM. Liquid Ooze is 64.

## 10. Regressions

The full suite passes (187 files), including:

- the earlier status, weather (W1-W3b), forced-switch, multi-mon controller and inventory tests;
- the Oak and rival flows.

With no Leech Seed KO, `tickTeamCheck` is exactly the old per-tick `checkFaint`.

## Mutation testing

There were 44 mutants. For each one I applied it on the working tree, ran `tests/battle_residual_r1_test.lua`, and ran `scripts/test_all.sh` whenever the R1 test still passed. Each was then restored with `git checkout --`. All 40 non-equivalent mutants except M19 and M20 were caught. The selection:

| # | Mutation | Result |
| --- | --- | --- |
| M01 | no `break` after the status tick (F1) | caught (1) |
| M02 | no post-loop finalize (F2) | caught (3) |
| M03 | tick ignores an open sequence | caught (2) |
| M04 | drain heal unclamped | caught (3) |
| M05 / M06 | ooze ignored / ooze read from the receiver | caught (4 / 4) |
| M07 | drain ignores the receiver's 0 HP | caught (2) |
| M08 / M09 | no min 1 / maxHP/16 | caught (1 / 20) |
| M10 | receiver not recorded on an ooze KO | caught (1) |
| M11 | immediate finalize at a seed KO (D2 off) | caught (8) |
| M12 / M13 | Grass before miss / type2 ignored | caught (1 / 2) |
| M14 | Leech Seed no PP | caught (5) |
| M15-M18 | Nightmare repeat allowed / no silent clear / no wake clear / ⅛ | caught (1/1/1/2) |
| **M19** | **no `break` after the Nightmare tick** | **survives both suites** |
| **M20** | **no `break` after the Curse tick** | **survives both suites** |
| M21 | no team check after the Curse tick | caught (1) |
| M22-M28, M41, M42, M44 | Curse variants (above) | all caught |
| M29 / M30 | Rapid Spin: no no-effect roll / no free | caught (1 / 3) |
| M31 | faint keeps the flags | caught (1) |
| M32 | F7 revert | R1 passes; `battle_engine_test` fails (3) |
| M33 / M40 | drain disabled / Nightmare disabled | caught (test errors) |
| M34 / M35 | AI −10 removed | caught (1 / 2) |
| M36 | controller: drain text before HP | caught (3) |
| M39 | Ghost target treated as immune | caught (1) |
| M43 | ooze damage unclamped | caught (1) |
| M37 | Rapid Spin `attacker.hp > 0` guard dropped | survives: **equivalent** (no modelled path) |
| M38 | loop-top `break` → `return` | survives: **equivalent** (`isOver()` implies the sequence is nil) |

## Findings

### 1. Low (test gap, required): F1 is pinned only for the poison/toxic/burn tick

- **What survives.** Mutants M19 and M20 remove the F1 `break` at `BattleEngine.lua:3881` (Nightmare) and `:3889` (Curse). Both pass all 103 R1 checks and `scripts/test_all.sh`. The only F1 test ("F1: no Curse tick and no rampage tick after battleEnd", `tests/battle_residual_r1_test.lua:387`) decides the battle on the **status** tick.
- **The code is correct.** I confirmed it with scratch probes:
  - **Q1.** The foe is faster and seed-KO'd, with no replacement. The asleep, nightmared and cursed player's Nightmare tick decides `playerWon`, and no `curseDamage` follows. Under M19 a `curseDamage` appears after `battleEnd`.
  - **Q2.** The foe is seed-KO'd. The cursed, rampaging player's Curse tick decides, and `rampageTurns` is untouched. Under M20 the rampage counter decrements after `battleEnd`.
- Source: `BattleTurnPassed` stops `DoBattlerEndTurnEffects` once `gBattleOutcome` is set (bm.c:2958-2962). Both ticks run `checkteamslost` through `BattleScript_DoTurnDmg` (bs1.s:3791-3801, then :3681-3686).
- **Correction.** Add those two checks to the deferred-team-check block. Nothing else needs to change.

### 2. Low: the stale "CONFIRMED NO-OP CLASS" header in `AICheckBadMove.lua`

The header at `AICheckBadMove.lua:83-99` and the paragraph at `:505-508` still say no code path sets status2 beyond confusion and flinch, or any status3. R1 now sets STATUS2_NIGHTMARE, STATUS2_CURSED and STATUS3_LEECHSEED. The task file records this as an out-of-scope follow-up, because the file is shared with the Memento owner. The record is accurate, and I accept the deferral. The follow-up should land with the next AICheckBadMove change.

### 3. Info: residue in the 9fb52ef design fold

The fold is accurate against the review: F1-F8 and D1-D6 are all indexed and applied, and I spot-checked the D2, F3, F4 and F7 text. Two small inconsistencies with what was built:

- The proposal still assigns the new `clearHeldBy` helper to R1 (`phase4-residual-effects-design-proposal.md:508`, `:801`, `:857`). The task's "Deviations" section defers it to R2 with a sound reason: R1 holds no field on the other battler. A one-line note in the proposal would keep the two documents consistent.
- The slice table (`:857`) says "AI rows 84 and 107 gain their first −10 test". Row 84 already had the Grass −10. Its new test is the first **already-seeded** −10.

### 4. Info: the out-of-scope secondary-raise case is confirmed

The task's follow-up is accurate. A secondary UP stat effect at +6 is silent in source: `ChangeStatBuffs(…, flags 0)` returns DIDNT_WORK (bsc.c:2516-2536, :6812-6813). The engine's hit-variant path emits `stages = 0, prevented = true` (`BattleEngine.lua:3120-3123`), which prints "won't go lower!". The DOWN case at −6 is right as it stands, because source prints "won't go lower!" through BattleScript_StatDown. A separate ticket should drop the event for the UP case only.

### 5. Info: documented deviations, all acceptable

- **Grass text.** The `noEffect` text uses the controller's generic "It doesn't affect X..." instead of source's line break and "…" (msg.c:70). This is consistent with the other immunity texts.
- **Risk R2 is unchanged.** A seeder that fainted mid-turn gives no drain that turn. Source's already-present replacement would receive it. Tests pin the skip.
- **No Oak first-battle accuracy skip** for Leech Seed. It is unreachable.
- **Not modelled:** Substitute, Lock-On, Protect, Magic Coat, Baton Pass and Spikes. These are documented in the engine header and in the inventory rows.

## Required before merge

1. Finding 1: add the Nightmare-decides and Curse-decides F1 checks.

Nothing else blocks.
