# Review: status leftovers L1 implementation (commit 2560d14)

- Reviewer: independent implementation reviewer (Claude)
- Date: 2026-10-14
- Commit: `2560d14` "Status leftovers L1: Tri Attack, Twineedle, Blaze Kick, crit-stage helper", on branch `claude/wizardly-faraday-o45q9z`
- Design: [proposal](../reports/phase4-status-leftovers-design-proposal.md) (L1 parts), [design review](2026-10-14-status-leftovers-design-review.md), [task](../tasks/phase4-status-leftovers-l1.md)
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`. Local copies: `bsc.c` (`src/battle_script_commands.c`), `bs1.s` (`data/battle_scripts_1.s`), `battle_moves.h`, `battle_message.c`, `battle.h`.
- Verdict: **PASS WITH CORRECTIONS**. There are no Blocker, High or Medium findings. The RNG order and draw count on every path match source for all three families. So do the gates, the KO tail, the crit stages and the inventory and ROM fixture. All 33 mutations I ran were caught. The one correction is a Low documentation and known-limit fix (F1). It concerns a presentation divergence in the multi-hit path that predates this commit and that Twineedle now inherits.

## What was verified (no finding)

### Move records and the fixture

- `battle_moves.h:536-547`, `:2096-2107`, `:3890-3901` give:
  - Twineedle: 77 / 25 / Bug(6) / 100 / 20 pp / 20%, flags protect|mirror = `0x12`;
  - Tri Attack: 36 / 80 / Normal(0) / 100 / 10 / 20%, `0x12`;
  - Blaze Kick: 200 / 85 / Fire(10) / 90 / 10 / 10%, `0x13` (contact).
- Each effect has exactly one member. `tests/phase4_status_leftovers_effect_rom_test.lua` matches these values field for field and asserts that membership is exactly 3. Its structure is a copy of `phase4_status_hit_effect_rom_test.lua`. No ROM was available, so it skips; it is recorded as "ROM fixture pending".
- Inventory: rows 36/77/200 change from `blocked_on_state` to `represented`, still admitted with positive power. The new totals are:
  - represented 105→108 families, 246→249 moves, 178→181 positive;
  - blocked 92→89, 107→104, 37→34;
  - admitted-uncovered positive 37→34.

  The effect list in the report (`phase4-move-effect-inventory.md:56-57`) has exactly 26 entries, with 36/77/200 removed. The 161 that remains is effect 161, which is correct. The inventory test passes.

### H1 `critStageFor` (`BattleEngine.lua:2884-2899`)

- `Cmd_critcalc` (`bsc.c:1184-1194`) adds +1 for each of 43, 75, 200 and 209. The table matches. The clamp is in `BattleFormulas.critRoll` (`:533-537`).
- `critRoll` has exactly four callers, and each now goes through the helper:
  - Explosion (`:1721`);
  - the ordinary hit (`:2331`);
  - `resolveMultiHit` (`:2785`);
  - `resolveTripleKick` (`:2857`).

  No other crit list remains in `src/`. The old inline 43/209/75 test is gone.
- Stages for 43, 75 and 209 are unchanged. Explosion, multi-hit and Triple Kick keep stage 0, the same as their earlier literal 0. The full suite passes unchanged.

### Tri Attack (`BattleEngine.lua:2533-2547`, no-effect list `:2402`)

- **Hit path.** The order is accuracy, crit, damage random, then `% 100` (`<= 20`, `bsc.c:2789`), then `% 3` only when the outer guards pass. The guards follow `SetMoveEffect`'s order (`bsc.c:2131-2143`, `:2466-2475`): Shield Dust (byte 9 <= 9), then HP > 0, then the whole `status1` word, which is not `hasAny` (design-review F2). After that comes the recursive `SetMoveEffect(FALSE, 0)`.
- **`% 3` mapping.** 0/1/2 map to burn/freeze/paralysis, i.e. bytes 3/4/5 (`battle.h:223-225`). `sStatusFlagsForMoveEffects[9] = 0`, so the status2 branch (`bsc.c:2396`) passes.
- **After the draw.** The inner failures are silent because `applySecondaryStatus(..., false)` is called with certain = false: Fire/Water Veil, Ice/Magma Armor and Limber. A freeze runs `cancelMultiTurnMoves`. Electric is not paralysis-immune in Gen 3, and Immunity is irrelevant here. Both are tested.
- **Miss** draws accuracy only, because `PrintMoveMissed` has no `seteffectwithchance`.
- **Ghost** draws accuracy, crit, random and `% 100`, with no `% 3`, through the no-effect list.
- **KO** draws `% 100` and then hits the 0-HP guard, with no `% 3`. The `faint` comes from the caller.
- **Frozen target.** No `% 3` is drawn and the target is not thawed, because Tri Attack is Normal.
- Safeguard and Substitute are documented as known limits.

### Twineedle (`MULTI_HIT_MOVES[77]`, `resolveMultiHit` `:2768-2833`)

- **Source tail** (`bs1.s:1072-1080`, `:613-655`):
  - A single accuracy check and PP deduction. A fixed 2 hits with no hit-count RNG.
  - Each hit is crit → damage → typecalc → (no-effect exit) → random, in source order (`:619-625`).
  - `movevaluescleanup` and `copybyte` re-arm the effect byte on every pass. The only `seteffectwithchance` is at `MultiHitEnd` (`:651`), so exactly one `% 100` is drawn after the loop.
- **KO on hit 1 or hit 2.** The `jumpifhasnohp BS_TARGET` break leads to `PrintStrings`. Then come "Hit N time(s)!" with N = hits landed (`sMULTIHIT_STRING+4` is incremented per landed hit), the roll (`SetMoveEffect` returns on 0 HP), and `tryfaintmon` (`:653`), which is the caller's `checkFaint`.
  - `runTurn`'s move loop (`:3204-3230`) and the switch, capture and run branches (`:3093`, `:3140`, `:3173`) all run the defender faint check after `resolveMove`.
  - With `hasReplacement`, the order is `multiHit` → `faint` → `forcedSwitchNeeded`, and end-of-turn still runs. This is tested.
- **No-effect exit** (synthetic Normal record vs Ghost). It draws crit, then `% 100`, and emits no count. This matches `NoMoreHits` → `resultmessage` → `jumpifmovehadnoeffect MultiHitEnd`.
- **Silent failures.** Shield Dust, Immunity, Poison/Steel and an existing status are all silent, because certain = false (`bsc.c:2176-2216`).
- **End of turn.** A poison applied by Twineedle ticks at end of turn.
- **Families 29/44.** Their behaviour is unchanged. The old shape keeps its in-loop `checkFaint`. Changing `hits = hitCount` to `hits` is equivalent for them, because every early stop in the old shape returns before the event. `tests/battle_engine_test.lua` passes untouched, and the explicit Double Kick KO check (3 draws, no `multiHit`) passes.
- **Replays.** None of the committed replays uses moves 41, 161 or 299.

### Blaze Kick (`STATUS_HIT_MOVES[200]`, `:761`)

- Stage 1 (`% 8`) vs Ember's stage 0 (`% 16`), then burn on `% 100 <= 10`.
- Fire type, Water Veil, Shield Dust and an existing status all fail silently with 4 draws.
- A miss draws accuracy only. A KO draws the roll, applies no burn, then faints.
- **Frozen target.** No burn (`status1 != 0`), then `defrostedByFire` after the hit, which matches `MOVEEND_DEFROST` (`bsc.c:4103-4116`, Fire, damage dealt, HP > 0).
- Flash Fire and contact abilities are listed as known limits.

### Controller texts

- These texts match `battle_message.c`:
  - "Hit N time(s)!" (`:82`);
  - "was poisoned!" (`:88`), "was burned!" (`:94`), "was\nfrozen solid!" (`:98`), "is paralyzed!\nIt may be unable to move!" (`:104`).
- The controller tests check "Hit 1 time(s)!" before the faint and the count before the poison text.

### Scope

- The diff touches only files on the task's MAY CHANGE list. `AICheckBadMove.lua`, `main.lua` and the bridges are untouched.
- The comments named by design-review F5 for L1 are updated. Their content is accurate, with the exception in F1 below.

## Mutation testing

Each mutation was applied to a clean tree, then `lua5.1 tests/battle_status_leftovers_test.lua` and `bash scripts/test_all.sh` were run, then the file was restored with `git checkout -- <file>`. The tree is clean afterwards. All 33 mutations (M01-M33) are caught: the leftovers test fails for every one, and so does the suite:

| Area | Mutations (each caught by at least one check) |
| --- | --- |
| Tri Attack | `% 3` order swapped; `% 3` offset; `hasAny` status guard; Shield Dust / HP / status outer guard dropped; 36 dropped from the no-effect list; `certain = true`; chance hard-coded to 10 |
| Twineedle | in-loop `checkFaint`; `hits = hitCount`; roll skipped on KO; no-effect roll dropped; `multiHit` after the roll; per-hit roll; `fixed = nil`; `statusKind = "toxic"`; entry removed; no break on KO; break→return; `certain = true` |
| H1 | 200/43/75/209 each dropped; each of the four sites reverted to literal 0; stage doubled |
| Blaze Kick | row removed; kind changed |
| Controller | "Hit %d time(s)!" text changed |

## Findings

### F1 — Low: Twineedle prints "It's super effective!" / "not very effective" after every hit; source prints it once, before the count

**Source.** The `BattleScript_MultiHitLoop` body has `critmessage` per hit (`bs1.s:633`). It has no `resultmessage`. The effectiveness text is printed once, at `BattleScript_MultiHitPrintStrings` (`resultmessage`, `bs1.s:644-645`), after the loop and before `STRINGID_HITXTIMES` (`:649`). It reflects the last hit's flags, because `movevaluescleanup` resets them on each pass.

**Engine.** `resolveMultiHit` calls `applyDamage` per hit, and each damage event carries `superEffective`/`notVeryEffective` (`BattleEngine.lua:2696-2703`). The controller turns each damage event into its own text (`BattleSceneController.lua:234-236`). I reproduced this through the real controller: Twineedle against a Grass target prints `It's super effective!` / `It's super effective!` / `Hit 2 time(s)!`, where source prints the line once and then the count.

**Why it matters.** The divergence predates this commit. It is the same path as Double Kick and the 2-5 family. It changes no RNG or state, only text. But L1 now routes a very common matchup through this path: Bug is super effective against Grass, Psychic and Dark and resisted by seven types. Meanwhile:

- the new controller comment (`BattleSceneController.lua:337-341`) and the inventory row 77 present Twineedle's text order as "as in source";
- neither the proposal's Known limits nor the 29/44 follow-up mention this.

**Correction.** Do not change behaviour in L1. Instead:

- record "effectiveness text per hit instead of once after the loop (`bs1.s:644-645`)" in the proposal's Known limits and in the inventory row 77 limits;
- add it to the scope of the separate multi-hit follow-up (`phase4-status-leftovers-design-proposal.md:485-496`), because it applies equally to 29/44;
- optionally qualify the controller comment.

### F2 — Info: `sourceTail` is keyed on `statusKind`

`resolveMultiHit` selects the source tail with `entry.statusKind ~= nil` (`BattleEngine.lua:2775`). That is correct for L1. However, the planned 29/44 follow-up needs the same tail (count before faint, plus the trailing `% 100` with byte 0) for entries that have no status. That follow-up should therefore split this into a separate flag, or make the tail unconditional, rather than give 29/44 a dummy `statusKind`. No change is needed now.

### F3 — Info: the ROM fixture was not exercised

`POKEPORT_ROM` is unset in this environment, so `phase4_status_leftovers_effect_rom_test.lua` skipped. Its expected values match `battle_moves.h` at the pin (checked above), and the task and inventory honestly record it as "ROM fixture pending". It should be run once a verified ROM is available, as for the earlier slices.

## Disposition

Apply F1 to the proposal's Known limits, the inventory row 77 and the follow-up scope. These are wording changes only, and no re-review is needed. F2 and F3 are notes for the follow-up and the ROM run. With F1 recorded, L1 is accepted.
