# Review: StatusConditions module and tests

- Reviewer: independent Reviewer (Claude), read-only on project source
- Date: 2026-10-14
- Artifact: `src/core/StatusConditions.lua` and `tests/status_conditions_test.lua`
  at commit `7915237` ("Add pure StatusConditions module (status S1 groundwork, not yet wired)")
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`:
  `include/constants/battle.h:90-101` (local copy `/tmp/claude-0/status/battle.h`),
  `src/battle_script_commands.c:2110-2370` SetMoveEffect (local copy `/tmp/claude-0/bsc.c`),
  `include/constants/pokemon.h:96-114` (fetched at the pin), plus
  `src/battle_util.c` / `src/pokemon.c` copies in `/tmp/claude-0/status/` for counter-clearing sites.
- Design basis: `work/reports/phase4-status-conditions-design-proposal.md`
- Verdict: **NEEDS_FIX** (tests only). The module is source-correct for everything it
  claims to represent; no implementation defect was found. Mutation testing left 8 of
  27 mutants alive, including one that drops a source-mandated type immunity
  (Poison type vs Toxic). The tests need four to six added assertions before the
  module counts as verified groundwork for S1.

## What was verified (no finding)

- **Bit layout.** `SLEEP_MASK 7`, `POISON 8`, `BURN 16`, `FREEZE 32`, `PARALYSIS 64`,
  `TOXIC_POISON 128`, counter unit `256` over bits 8-11 match `battle.h:91-101`.
- **Type ids.** `TYPE_POISON 3`, `TYPE_STEEL 8`, `TYPE_FIRE 10`, `TYPE_ICE 15`
  match `pokemon.h:100,105,107,112`.
- **Arithmetic without a bit library.** `hasBit` (`floor(v/b) % 2`), `sleepTurns`
  (`% 8`), `toxicCounter` (`floor(v/256) % 16`), `hasAny` (`% 256 ~= 0`, which equals
  `STATUS1_ANY` = bits 0-7) are correct for all non-negative integers, including
  values >= 4096 (bits 12+ are ignored by the readers and preserved by
  `withToxicCounter`, whose high part is `floor(v/4096)*4096`). `nil` status reads as 0
  in every reader and both `with*` helpers; `nil` `types` is handled by `isType`.
- **Guards and order vs SetMoveEffect.** Fainted check first (`bsc.c:2140`, before the
  switch) — module checks `hp <= 0` first. Sleep: status1 only (`:2161`; Uproar and
  abilities not represented). Poison: Poison/Steel type before status1 (`:2206-2211`).
  Burn: Fire type, then status1 (`:2247-2252`). Freeze: Ice type, then status1
  (`:2260-2263`; sun not represented). Paralysis: status1 only (`:2287`; Electric not
  immune in Gen 3 — correct). Toxic: status1 before type (`:2332`), Poison/Steel with
  status1 == 0 sets `MOVE_RESULT_DOESNT_AFFECT_FOE` (`:2334-2346`) — module returns
  `"hasStatus"` then `"immune"` in that order.
- **Sleep duration.** `STATUS1_SLEEP_TURN((Random() & 3) + 2)` (`:2356`).
  `Rng:next16()` returns `floor(value/65536)`, an integer in 0..65535
  (`src/core/Rng.lua:56-59`), so `% 4` equals `& 3`; one draw per sleep, no draw
  for other kinds — matches `:2355-2358` (only the sleep branch calls Random).
- **Apply result.** Source ORs the flag into a status1 that the guard has proven is 0,
  so the module's replace/add produces the same word. Toxic: source ORs only
  `STATUS1_TOXIC_POISON`; with status1 == 0 the counter is 0, matching
  `withToxicCounter(..., 0)`.
- **Persistence masking.** The design requires the counter be masked on persist;
  `withToxicCounter(status, 0)` does exactly that and preserves flags and higher bits.

## Mutation testing

Each mutant was applied to `src/core/StatusConditions.lua`, the suite was run with
`lua5.1 tests/status_conditions_test.lua` (baseline: 52 passed, 0 failed), and the
original was restored from a byte copy. After the run, sha256 matched the original
(`6c2f683b...bb30`) and `git diff --stat src` was empty.

| # | Mutation | Result |
|---|---|---|
| 1 | sleep `% 4` -> `% 3` | killed (3 fails) |
| 2 | sleep `+ 2` -> `+ 1` | killed |
| 3 | drop Steel from poison immunity | killed |
| 4 | drop Steel from toxic immunity | killed |
| 5 | **drop Poison from toxic immunity** | **survived** |
| 6 | drop Poison from poison immunity | killed |
| 7 | drop Fire burn immunity | killed |
| 8 | drop Ice freeze immunity | killed |
| 9 | `withToxicCounter` high part = 0 | killed |
| 10 | `withToxicCounter` low = `% 128` | killed |
| 11 | `withToxicCounter` drops `* 256` | killed |
| 12 | `withToxicCounter` keeps old counter | killed |
| 13 | **`hasAny` uses `% 128` (Toxic flag not a status)** | **survived** |
| 14 | `hp <= 0` -> `hp < 0` | killed |
| 15 | **`toxicCounter` `% 16` -> `% 8`** | **survived** |
| 16 | `isType` ignores second type | killed |
| 17 | toxic apply without counter reset | killed |
| 18 | `withSleepTurns` returns turns only | killed |
| 19 | `sleepTurns` `% 8` -> `% 4` | killed |
| 20 | **`hasBit` without `math.floor`** | **survived** |
| 21 | canApply uses raw `status ~= 0` (see F5) | survived (expected) |
| 22 | **`toxicCounter` without `% 16`** | **survived** |
| 23 | `hasAny` uses raw `~= 0` | killed |
| 24 | **`withToxicCounter` high part masks at 2048** | **survived** |
| 25 | burn apply sets FREEZE | killed |
| 26 | swap toxic guard order (type before status) | killed |
| 27 | **poison: status before type** | **survived** |

## Findings

### F1 — Medium — Poison-type immunity to Toxic is untested

- Evidence: mutant 5 (`if isType(target, TYPE_STEEL) then` for toxic) passes all 52
  checks. Source `bsc.c:2334` excludes both `TYPE_POISON` and `TYPE_STEEL`. The only
  Poison-type toxic test (`"toxic checks status before type"`) has a BURN status, so it
  returns `"hasStatus"` regardless of the immunity.
- Fix: add `canApply(mon({POISON, POISON}, 0), "toxic")` expecting `false, "immune"`
  (and ideally a secondary-type case such as `{NORMAL, POISON}`).

### F2 — Medium — Toxic flag as a blocking status is untested

- Evidence: mutant 13 (`hasAny` = `% 128 ~= 0`) survives. The "existing status blocks"
  loop uses only PARALYSIS and sleep 2; no test has status1 = 128 (or 128 + counter).
  A badly poisoned battler must block every kind (`bsc.c:2161,2210,2251,2262,2287,2332`).
- Fix: extend the loop with `S.TOXIC_POISON + 3 * 256` expecting `"hasStatus"` for all
  six kinds, and assert `S.hasAny(128)`.

### F3 — Medium — Toxic counter values >= 8 and words with bits >= 12 are under-tested

- Evidence: mutants 15, 22 and 24 survive. `toxicCounter` is only checked at 3 with no
  higher bits; `withToxicCounter` is only checked from old counters 0 and 2, so bit 11
  of the old counter is never exercised. The battle_util end-turn path uses counter
  values up to 15 (`battle_util.c:822-824`), so 8-15 are reachable.
- Fix: assert `toxicCounter(128 + 15*256) == 15`, `toxicCounter(4096 + 128 + 256) == 1`,
  and `withToxicCounter(128 + 9*256, 0) == 128` (also covers the persistence mask
  required by the design), `withToxicCounter(4096 + 128 + 15*256, 2) == 4096 + 128 + 512`.

### F4 — Low — Predicates are only tested on single-bit words

- Evidence: mutant 20 (`hasBit` without `math.floor`) survives, yet it is wrong for any
  word with lower bits set (e.g. `isPoisoned(8 + 3)` would return false). Every
  predicate test uses a pure power of two.
- Fix: add composite words, e.g. `isPoisoned(8 + 3)`, `isBadlyPoisoned(128 + 5*256)`,
  `isFrozen(32 + 4096)`, `not isBurned(8 + 32 + 64 + 128)`.

### F5 — Low — `canApply` gates on `STATUS1_ANY`, source gates on the whole status1 word

- Evidence: every source guard is `if (gBattleMons[gEffectBattler].status1) break;`
  (`bsc.c:2161,2210,2251,2262,2287,2332`) — raw truthiness, counter bits included. The
  module uses `hasAny` (bits 0-7), and tests "hasAny ignores a stray toxic counter" and
  "toxic resets a stray counter to 0" codify that. In source a counter without the
  flag is unreachable: every cure clears `STATUS1_PSN_ANY | STATUS1_TOXIC_COUNTER`
  together (`battle_util.c:2093,2736,2879`, `pokemon.c:4181`), and mutant 21 (raw
  `status ~= 0`) passes all tests. So this has no observable effect in source, but it is
  undocumented divergence that can matter if project code ever clears only the flag bits.
- Fix: either switch the guard to `status ~= 0` (source-literal), or keep `hasAny` and
  state in the header comment that a stray counter is unreachable in source and that
  callers must clear the counter together with the poison flags. No change required
  for S1 correctness.

### F6 — Low — Reason order for poison/burn/freeze is unpinned

- Evidence: mutant 27 (status check before Poison/Steel immunity for `poison`) survives.
  The module's comment says only the toxic order is exposed, but `canApply` returns a
  reason for every kind, and a Poison-type target with an existing status returns
  `"immune"` today. If S1 uses the reason for message selection, that order matters.
- Fix: add `canApply(mon({POISON, POISON}, S.BURN), "poison")` expecting `"immune"`, and
  a matching Fire/burn and Ice/freeze case, or document that the reason is unspecified
  for non-toxic kinds.

### F7 — Info — `apply` and the `with*` helpers do not defend against misuse

- Evidence: `apply` uses `+` rather than OR, so calling it on an already-set flag
  carries into the next bit (`apply` poison on status 8 gives 16, which is BURN).
  `withSleepTurns(s, 8)` and `withToxicCounter(s, 16)` likewise spill into bit 3 and
  bit 12. Behavior is correct under the documented "caller already checked canApply"
  contract, and the inputs come from the 2..5 draw and a counter that is capped at 15.
- Fix (optional): `assert(turns >= 0 and turns <= 7)` and `assert(n >= 0 and n <= 15)`,
  and add a flag only when `not hasBit(status, flag)`.

## Required before PASS

F1-F3 (test additions only). F4 and F6 are recommended in the same change. F5 needs a
one-line decision: change the guard or document the divergence. F7 is optional.

## Re-review (2026-10-14, uncommitted working tree on top of `7915237`)

- Revision under review: working-tree diff (`src/core/StatusConditions.lua` +8/-7,
  `tests/status_conditions_test.lua` +23). Module sha256 `1428fb36...cd76`. Suite: 74 passed, 0 failed.
- Change to `canApply`: both "hasStatus" guards are now `status ~= 0` (the whole status1
  word), matching `if (gBattleMons[gEffectBattler].status1)` at
  `bsc.c:2161,2210,2251,2262,2287,2332`. This resolves F5 in the source-literal direction.
  The reason-order comment now cites each kind's source lines. I checked the cited
  lines against my local copy and they are correct.
- Method: copied the fixed module and `git diff` output first, applied each mutant to
  the fixed module, ran the suite, restored from the copy. Afterwards the module sha256
  matched and `git diff` was byte-identical to the saved pre-run diff.

| Mutant | Result now |
|---|---|
| 5 drop Poison from toxic immunity | killed ("Poison type immune to toxic") |
| 13 `hasAny` -> `% 128` | **survived** (see R1) |
| 13b canApply guard -> `status % 128 ~= 0` (Toxic flag not blocking) | killed (12 fails) |
| 15 `toxicCounter` `% 8` | killed |
| 20 `hasBit` without floor | killed |
| 22 `toxicCounter` without `% 16` | killed |
| 24 `withToxicCounter` high masks at 2048 | killed |
| 27 poison/burn/freeze: status before type | killed (one fail per kind) |
| 26 toxic: type before status | killed |
| F5 revert, both guards -> `hasAny` | killed (6 fails, counter-only word) |
| F5 revert, toxic guard only | killed |

F1, F2 (the canApply part), F3, F4, F5 and F6 are resolved. F7 stays as documented
(callers must check `canApply` first). That is acceptable.

### R1 — Low — `hasAny` is never tested on a word with a status flag set

- Evidence: canApply no longer calls `hasAny`. The only `hasAny` checks are negative
  (`nil`, `5*256`), so `hasAny` = `% 128` (Toxic not counted) passes all 74 checks.
  `hasAny` is still a public helper meant to equal `STATUS1_ANY` (`battle.h:101`), and
  no engine code calls it yet.
- Fix: add `S.hasAny(128)`, `S.hasAny(1)` and `S.hasAny(128 + 3*256)`. This does not
  block S1. Do it with the next change to this test file.

**Re-review verdict: PASS.** The module is source-correct. All the original
blocking gaps (F1-F3) are closed. R1 is a Low test gap for a helper nothing calls yet.
