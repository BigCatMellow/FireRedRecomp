# Review: P4-ABILITY-TERMS ability stat and accuracy terms

- Reviewer: independent Reviewer (Claude), per `AGENTS.md` rule 6
- Date: 2026-10-14
- Commit under review: `b2c9665` (Ability stat and accuracy terms (Guts, Marvel Scale, Hustle, Huge Power, Thick Fat, Compound Eyes))
- Task: [`work/tasks/phase4-ability-stat-accuracy-terms.md`](../tasks/phase4-ability-stat-accuracy-terms.md)
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Verdict: **NEEDS_FIX**. There is one Minor parity defect (F1): Explosion combined with Marvel Scale applies the two terms in the wrong order. The fix is small. F2 asks for test additions alongside it. F3 is a reachable gap outside this task's scope and should become a separate follow-up task. F4 and F5 are Info.

## Summary

`abilityAdjustedStats` matches source `CalculateBaseDamage`
(`src/pokemon.c:2437-2491`) in which terms it applies, their order, their
arithmetic and the conditions for each. `calculateBaseDamage` now feeds the
adjusted stats into all four stat reads, normal and crit, physical and
special. That matches source, where `APPLY_STAT_MOD` and the crit raw-stat
assignment both read the already-modified locals. The `accuracyCheck` terms
match `Cmd_accuracycheck` (`battle_script_commands.c:1069-1074`), and all
four engine call sites pass the attacker's ability and the move type. All
ability ids match `include/constants/abilities.h`. Changed files are within
MAY CHANGE.

One commit-introduced divergence remains. BattleEngine halves defense for
Explosion before calling `calculateBaseDamage`, so Marvel Scale's x1.5 now
runs after the halving. Source runs it before (F1). Mutation testing killed
20 of 28 mutants. All 8 survivors are test gaps (crit branches, three of the
four accuracy call sites, the Ice half of Thick Fat). In every one of those
cases the code itself is correct.

## Verification performed

- Read `git show b2c9665` in full, and compared it line by line with local
  `pokemon.c` 2384-2645 and `bsc.c` 1003-1100. Ability ids were checked
  against the pinned `include/constants/abilities.h` (14, 37, 47, 55, 62,
  63, 74).
- Order and arithmetic against source:
  - Huge/Pure Power `attack *= 2`
  - (badges and hold items are not represented)
  - Thick Fat `spAttack /= 2` when the move type is Fire(10) or Ice(15)
  - Hustle `150*attack/100`
  - (Plus/Minus are doubles-only)
  - Guts `150*attack/100` when `status1`
  - Marvel Scale `150*defense/100` when `status1`

  This matches. `idiv` reproduces C truncation for these non-negative
  values. The u16 locals cannot overflow: the worst case is 999 x 2 x 1.5 x
  1.5, about 4.5k. Thick Fat keys on the move type, as in source. Hustle's
  attack term is unconditional on type, as in source. The term only matters
  in the physical branch, and the test "Hustle does not boost special
  attack" covers that.
- Crit branches: source assigns `damage = attack` and `damageHelper =
  defense` from the modified locals, so the commit's change from
  `attacker.attack` to `attack` is correct. The engine's comparisons
  (`<= DEFAULT` gives raw) are equivalent to source's (`> DEFAULT` gives
  stage mod), because the stage-6 ratio is 10/10.
- Status word: `Guts`/`Marvel Scale` test `(status or 0) ~= 0`. The engine
  never leaves only toxic-counter bits set. Cures assign `status = 0`
  (`BattleEngine.lua:981`), the counter is only written together with the
  toxic bit (`StatusConditions.lua:135`, `BattleEngine.lua:2381`), and the
  counter is cleared only on persist (`BattlePartyBridge.lua:193`).
  Sleep-turn bits count as status, as in source. There is no divergence
  here.
- Accuracy: `calc = ratio*acc/div`, then Compound Eyes `*130/100`, then
  Hustle `*80/100` when `IS_TYPE_PHYSICAL(type)`. That is source order.
  Sand Veil sits between them in source and needs weather, so its absence
  does not change the result. `calc` is u16 in source, and its maximum
  300 x 130 fits. Call sites are at `BattleEngine.lua` 1247 (primary status
  moves), 1398 (Explosion), 1485 (main path, which also feeds the crash/miss
  path) and 2269 (per-kick Triple Kick check). All four pass
  `attacker.ability, move.type`. Hidden Power's dynamic type is not modelled
  anywhere in the engine, so `move.type` is the same as source's
  `GET_MOVE_TYPE`.
- Other damage paths: the Jump Kick crash leaf (1513) calls
  `calculateBaseDamage` and so picks up the terms. Source recomputes through
  damagecalc with abilities, so this is correct. Fixed-damage and OHKO paths
  do not call `calculateBaseDamage`, matching source. `EarlyRivalAI`'s
  prediction goes through `calculateBaseDamage`, consistent with source
  `AI_CalcDmg`. Nothing applies a term twice.
- Hand-checked oracles (Lv50, Tackle 35, Atk 100, Def 50, level factor 22):
  - base 32
  - Atk 150 gives 48
  - Atk 200 gives 63
  - Def 75 gives 22

  All are correct.
- Tests at `b2c9665`:
  - `lua5.1 tests/battle_status_engine_test.lua`: 164 passed, 0 failed
  - `tests/battle_formulas_test.lua`: 32/0
  - `tests/battle_engine_test.lua`: 568/0
  - `bash scripts/test_all.sh`: PASS (165 files, no-ROM)
  - `lua5.1 scripts/check_repository.lua`: PASS

## Findings

### F1 — Minor: Explosion halves defense before Marvel Scale (source halves after)

Evidence:
- Source `pokemon.c` applies Marvel Scale at about line 2489. It then halves
  defense afterwards with `if (gBattleMoves[gCurrentMove].effect ==
  EFFECT_EXPLOSION) defense /= 2;`, after the pinch-ability block and before
  the physical branch. So the source result is `floor(floor(150*d/100)/2)`.
- `BattleEngine.lua:1386-1390` builds `explosionDefender` with `defense =
  max(1, floor(d/2))` and then calls `calculateBaseDamage`. Since this
  commit, that call applies Marvel Scale to the already-halved value, giving
  `floor(150*floor(d/2)/100)`.
- Reproduction script (Atk 100, Lv50, power 250, defender Marvel Scale +
  burn):
  - d=51: engine 299, source 291
  - d=53: engine 284, source 284
  - d=101: engine 148, source 148

  The two differ whenever the rounding diverges.
- Reachability in FRLG is very low, because Marvel Scale is Milotic only
  and Feebas/Milotic come only by trade. The engine can still represent the
  state, and the commit introduced the divergence: before it, Marvel Scale
  did not exist.

Fix: move the halving into `calculateBaseDamage`, after
`abilityAdjustedStats`. For example, add `if move.effect == 7 then defense =
math.max(1, idiv(defense, 2)) end`, keeping the existing clamp for the Def-1
case. Then drop the `explosionDefender` copy, or keep the copy but stop
halving in it. Add a d=51 Marvel Scale + Explosion oracle (291). The task's
MAY CHANGE lists only the accuracy call sites in `BattleEngine.lua`, so the
Orchestrator needs to grant the one-line Explosion edit. The alternative is
to make the formula skip the halving when told the defender copy is
pre-halved, but that is less clean.

### F2 — Minor: test gaps (mutation survivors)

The code is correct, but none of the following is pinned by a test:
- the crit branches using adjusted stats (M14, M15, M16)
- the Ice half of Thick Fat (M05)
- three of the four accuracy call sites: Explosion, main path, Triple Kick
  (M25, M26, M27)
- the move type reaching the main call site (M28)

The Thick Fat test also only asserts `<`.

Fix:
- Add a crit oracle with a Guts+status (or Huge Power) attacker at the
  neutral stage, and with Marvel Scale on the defender for the crit defense
  branch.
- Add an exact Thick Fat value for Ember and for an Ice move.
- Add engine tests for a Compound Eyes damaging move (main path), a Hustle
  physical miss at draw 60, and Triple Kick with Compound Eyes.

### F3 — Medium, reachable, outside this task: Overgrow/Blaze/Torrent/Swarm pinch boosts are missing

Evidence: source `pokemon.c` (right after Marvel Scale, before the Explosion
halving) sets `gBattleMovePower = 150*power/100` for a move of the matching
type when `hp <= maxHP/3`. The abilities are ids 65-68. All three Kanto
starters, and the rival's starter, have Overgrow, Blaze or Torrent, and
Ember, Vine Whip and Bubble/Water Gun are learned within the first few
levels. That makes this the most reachable ability term in normal play. It
is not implemented. The header comment only covers it generically ("abilities
other than those listed"). Mud Sport/Water Sport, which halve power in the
same block, depend on status3, which is not modelled. Flash Fire (special
branch, needs the absorb flag) is already documented as a gap.

Fix: open a bounded follow-up task. Apply the pinch boost to `power` after
the stat terms, with `hp <= idiv(maxHP, 3)` and truncating `150*power/100`.
Test oracles should cover exactly 1/3 HP and 1/3 HP + 1. This review does
not block on F3, because it is outside P4-ABILITY-TERMS's source block.

### F4 — Info: stale header comment

`BattleFormulas.lua` lines 98-104 still list "Explosion's defense halving"
as not ported, but BattleEngine implements it. This was true before the
commit. Update it with the F1 fix.

### F5 — Info: magic type numbers

`abilityAdjustedStats` uses `10`/`15` for Fire/Ice. The values are correct,
but named constants (Data or `BattleFormulas.TYPE_*`) would match the
surrounding style.

## Mutation table

Each mutant was applied to a pristine copy, then the three battle test files
and `scripts/test_all.sh` were run. Both files were restored byte-for-byte
afterwards (`cmp` clean, and `git status --short` was empty before this
review file was written).

| # | Mutant | Result |
|---|---|---|
| M01 | Huge Power x2 removed | killed (2) |
| M02 | Pure Power dropped from condition | killed |
| M03 | Thick Fat removed | killed |
| M04 | Thick Fat halves attack (physical) instead of spAttack | killed |
| M05 | Thick Fat Fire only (Ice dropped) | **survived** (F2) |
| M06 | Hustle attack term removed | killed |
| M07 | Hustle 140/100 | killed |
| M08 | Guts ignores status | killed |
| M09 | Guts boost removed | killed (2) |
| M10 | Marvel Scale tests attacker status | killed |
| M11 | Marvel Scale keyed on attacker ability | killed |
| M12 | Marvel Scale removed | killed |
| M13 | Marvel Scale ignores status | killed |
| M14 | crit physical uses raw `attacker.attack` | **survived** (F2) |
| M15 | crit physical uses raw `defender.defense` | **survived** (F2) |
| M16 | crit special uses raw `attacker.spAttack` | **survived** (F2) |
| M17 | non-crit uses raw `attacker.attack` | killed (5) |
| M18 | non-crit uses raw `defender.defense` | killed |
| M19 | Compound Eyes removed | killed (2) |
| M20 | Compound Eyes 120/100 | killed (2) |
| M21 | accuracy factors swapped (CE 80, Hustle 130) | killed (3) |
| M22 | Hustle accuracy applies to special moves | killed |
| M23 | Hustle accuracy removed | killed |
| M24 | status-move call site drops ability | killed |
| M25 | Explosion call site drops ability | **survived** (F2) |
| M26 | main call site drops ability | **survived** (F2) |
| M27 | Triple Kick call site drops ability | **survived** (F2) |
| M28 | main call site drops move type | **survived** (F2) |

Killed 20/28. No survivor is an equivalent mutant: each would change
behavior in a reachable configuration.

## Required to reach PASS

1. Fix F1, with a Marvel Scale + Explosion oracle.
2. Add the F2 tests, so that M05, M14-M16 and M25-M28 are killed.
3. Route F3 as its own task. It does not block this one.

## Worker disposition (2026-10-14)

F1 fixed (halving moved into calculateBaseDamage after the ability terms; Def 51 oracle 291); F2 tests added (crit branches, Thick Fat Ice, every accuracy call site, Hustle move type); F3 pinch abilities implemented with oracles; F4/F5 header and named constants. New tests fail on b2c9665 (6 failures).

## Re-review (commit `f73ccf4`, 2026-10-14)

- Verdict: **PASS**. F1-F5 are resolved. There are no new findings.

### F1: Explosion order

Resolved. `calculateBaseDamage` now applies `defense = max(1, idiv(defense,
2))` when `move.effect == 7`. This runs after `abilityAdjustedStats` and the
pinch term, and before the physical branch, which is source order
(`pokemon.c`: Marvel Scale, then the pinch block, then `defense /= 2`).
BattleEngine no longer builds the pre-halved copy.

The oracles check out by hand:
- Def 51 with Marvel Scale: 51 -> 76 -> 38, and 550000/38/50 + 2 = 291
- plain Def 51: 25, and 440 + 2 = 442

The max(1) guard is the existing behavior for the Def-1 case, which in source
is a division by zero. That edge is still out of scope, as before. No other
`calculateBaseDamage` caller carries effect 7: the crash leaf, multi-hit,
Triple Kick and EarlyRivalAI all use other effects. Magnitude/Flail/Eruption
copy the move but keep their own effect.

### F2: tests

Resolved. All 8 survivors from round 1 are now killed: the crit
branches, Thick Fat on Ice (85 -> 43), and the Explosion, main-path and
Triple Kick call sites, plus the move type at the main site. The exact
Thick Fat and Ember oracles (37 -> 19) check out by hand.

### F3: pinch abilities

Resolved, matching source `pokemon.c:2496-2503`:
- The ids map 65 to Grass(12), 66 to Fire(10), 67 to Water(11) and 68 to
  Bug(6).
- The condition is `hp <= idiv(maxHP, 3)`, and the arithmetic is
  `150*power/100` with truncation.
- In source this sits after Marvel Scale and changes `gBattleMovePower`
  before either branch multiplies by power. The port changes the local
  `power` before both branches, which is equivalent.

Dynamic power: source sets `gBattleMovePower = powerOverride`
(`gDynamicBasePower`) at the top of `CalculateBaseDamage` and only applies
the pinch term after that. So the pinch boost does apply to the transient
power. The engine passes Flail/Eruption/Magnitude as a move copy whose
`power` holds the transient value, so the boost lands on that value. That
matches source. Eruption (Fire) with Blaze and Water Spout with Torrent are
the only type-matching cases; Flail, Reversal and Magnitude never match a
pinch type.

Explosion sets the user's HP to 0 before damagecalc, but Explosion is Normal
type and so never matches a pinch type. EarlyRivalAI's prediction now
includes the pinch term, which is consistent with source `AI_CalcDmg` calling
`CalculateBaseDamage`.

The Blaze 33/100 vs 34/100 boundary oracles (54 / 37) check out by hand. One
small weakness: the Overgrow and Swarm tests assert only `>`. The type-map
mutants below are still killed, so this does not need a change.

### F4/F5

Resolved. The header comment is updated, and named constants (`TYPE_FIRE`,
`TYPE_ICE`, `EFFECT_EXPLOSION`) replace the hard-coded numbers.

### Tests at `f73ccf4`

- `battle_status_engine_test.lua`: 182/0
- `battle_formulas_test.lua`: 32/0
- `battle_engine_test.lua`: 568/0
- `scripts/test_all.sh`: PASS (165 files)
- `scripts/check_repository.lua`: PASS

### Re-review mutation table

Same harness as round 1, using pristine copies of `f73ccf4`. Both files were
restored byte-for-byte afterwards (`cmp` clean).

| # | Mutant | Result |
|---|---|---|
| R05 | Thick Fat Fire only | killed |
| R14 | crit physical raw `attacker.attack` | killed |
| R15 | crit physical raw `defender.defense` | killed |
| R16 | crit special raw `attacker.spAttack` | killed |
| R25 | Explosion accuracy site drops ability | killed |
| R26 | main accuracy site drops ability | killed (2) |
| R27 | Triple Kick accuracy site drops ability | killed |
| R28 | main accuracy site drops move type | killed |
| P01 | pinch `hp < maxHP/3` | killed |
| P02 | pinch threshold `ceil(maxHP/3)` | killed |
| P03 | pinch threshold real division `maxHP/3` (no floor) | survived (**equivalent**: for integer `hp`, `hp <= x` iff `hp <= floor(x)`) |
| P04 | pinch threshold `maxHP/2` | killed |
| P05 | Overgrow mapped to Water | killed |
| P06 | Blaze mapped to Grass | killed |
| P07 | Torrent mapped to Fire | killed (2) |
| P08 | Swarm mapped to Poison | killed |
| P09 | pinch ignores move type | killed (2) |
| P10 | pinch factor x2 | killed (2) |
| P11 | pinch removed | killed (4) |
| E01 | Explosion halving removed | killed (2) |
| E02 | Explosion halves defense before the ability terms | killed |
| E03 | Explosion halves spDefense instead | killed (2) |

Killed 21/22. The one survivor is an equivalent mutant.
