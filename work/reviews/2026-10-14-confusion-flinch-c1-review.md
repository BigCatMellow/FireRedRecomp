# Review: Phase 4 confusion and flinch, slice C1 (P4-STATUS2-C1)

- Reviewer: independent code Reviewer (Claude), per `AGENTS.md` rule 6
- Date: 2026-10-14
- Task: [`work/tasks/phase4-confusion-flinch-c1.md`](../tasks/phase4-confusion-flinch-c1.md)
- Commits reviewed: `7cb1018` and `2251481` (`git diff 3adc7e8..2251481 -- src tests`)
- Design: [proposal](../reports/phase4-confusion-flinch-design-proposal.md); [design review](2026-10-14-confusion-flinch-design-review.md) (PASS WITH CORRECTIONS)
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Verdict: **PASS**. No Blocker or Medium findings. The implementation matches the pinned source on every point checked. Four Low findings: three test-oracle gaps (shown by surviving mutants) and one doc gap. None of them blocks merge. They can be fixed in C2.

## Scope

The changed files are `src/core/BattleEngine.lua`, `src/core/AICheckBadMove.lua`, `src/core/BattleSceneController.lua`, the new `tests/battle_confusion_flinch_test.lua`, and additions to `tests/ai_check_bad_move_test.lua` and `tests/battle_scene_controller_test.lua`. All are inside the task's MAY CHANGE list. `main.lua`, `BattlePartyBridge.lua`, the save format and admission are untouched. No move applies confusion or flinch yet, which is correct for C1.

## Commands run (at 2251481)

| Command | Result |
| --- | --- |
| `lua5.1 tests/battle_confusion_flinch_test.lua` | 35 passed, 0 failed |
| `lua5.1 tests/battle_status_engine_test.lua` (S1-S4 status1) | 202 passed, 0 failed |
| `lua5.1 tests/ai_check_bad_move_test.lua` | 43 passed, 0 failed |
| `lua5.1 tests/battle_scene_controller_test.lua` | 141 passed, 0 failed |
| `bash scripts/test_all.sh` | PASS: 167 test files (no-ROM mode) |
| `lua5.1 scripts/check_repository.lua` | PASS (294 Lua, 313 Markdown, 1020 local targets) |

## Source conformance (verified)

| Item | Source | Implementation | Result |
| --- | --- | --- | --- |
| Canceller order Sleep, Frozen, (Truant, Recharge unmodeled), Flinch, (Disabled, Taunt, Imprisoned unmodeled), Confused, Paralysed, ..., Thaw | `battle_util.c:1233-1250` enum | `resolveStatusCancellers`: sleep, freeze, flinch, confusion, paralysis, thaw-hit, then Snore `fastAsleep` | ✓ |
| Staying asleep or staying frozen stops the loop (no flinch consumed, no confusion tick). Waking or thawing pushes the cursor and continues | `:1266-1333` | `return true` on stay; fall-through on wake/thaw. Tested both ways | ✓ |
| A frozen user of a thaw-hit move passes the frozen canceller on `%5 != 0` and reaches flinch/confusion before CANCELLER_THAW | `:1310-1333`, `:1513-1525` | Same (pre-existing frozen logic, new cancellers inserted between) | ✓ |
| Flinch: clear the bit, "flinched", no attackstring/PP, no draw | `:1361-1371`; `bs1.s:3720-3723` | Flag cleared, `flinched` event, `return true` before `useMove`/ppreduce, 0 draws (tested) | ✓ |
| Confusion: decrement first; still confused → "is confused!", then `Random() & 1`; nonzero pushes the cursor and continues (paralysis still checked); zero → self-hit and stop. Reaching 0 → "snapped out", cursor pushed, continue, no draw | `:1407-1435`; `bs1.s:3736-3762` | `confusionTurns - 1`; `next16() % 2 == 0` gives self-hit (`&1 == 0`); proceed and snapped-out both fall through to paralysis; snap-out draws nothing | ✓ |
| Self-hit: `CalculateBaseDamage(atk, atk, MOVE_POUND, 0, 40, 0, ...)`, `gCritMultiplier` 1 (reset at `battle_main.c:3974`), then `adjustnormaldamage2` = one `ApplyRandomDmgMultiplier` draw (Focus Band/Endure unmodeled), HP update, `tryfaintmon BS_ATTACKER` | `battle_util.c:1423`; `bsc.c:1558-1570`, `:1620-1656`; `bs1.s:3741-3755` | `calculateBaseDamage(battler, battler, {power 40, type 0}, false, nil)`; `applyRandomDamageMultiplier` (one draw); HP clamp; `checkFaint(side)`. No STAB/typecalc (applied outside `calculateBaseDamage` in this engine), no screens (nil), no crit | ✓ |
| Explosion quirk: defense halved when `gBattleMoves[gCurrentMove].effect == EFFECT_EXPLOSION` | `pokemon.c:2505-2507` | `effect = EXPLOSION` when the chosen move's effect is 7. Tested (50 vs 26) | ✓ |
| Self-hit KO: no replacement ends the battle with no further action and no end-turn; with a replacement the turn halts under the documented recoil-KO policy and end-turn still runs | design review F7 | `runTurn` `isOver()` / `awaitingForcedSwitch` gates. Tested both ways (first mover, wild) | ✓ |
| Snore/Sleep Talk "fast asleep" printed after `attackcanceler` | `bs1.s:1253-1266`; design review F2 | `snoreAsleep` flag, emitted after every canceller, only when not cancelled. Flinched gives only `flinched`; self-hit gives no `fastAsleep` (tested) | ✓ |
| Flinch cleared between turns | `battle_main.c:2917` (pre-battle), `:2940` (`HandleEndTurn_ContinueBattle`) | Cleared at `runTurn` start (covers switch/capture/run/halt early returns) and in `resolveEndTurn` | ✓ |
| Faint clears status2 | `FaintClearSetData`, `battle_main.c:2434-2441` | `recordFaint` zeroes `confusionTurns` and `flinched` | ✓ |
| Switch-ins start clean | `SwitchInClearSetData` | `makeBattler` initialises `confusionTurns = 0`, `flinched = false`. Every switch-in goes through `BattlePartyBridge.battlerFromParty` / `battlerFromGenerated` → `makeBattler` (`main.lua:1226,1265,1298,1388-1390,1525-1538,1619,1675`; `TrainerBattleOrchestrator` `toBattler = battlerFromGenerated`) | ✓ |
| Not persisted | — | `persistPartyBattler` writes only PP, HP and status1 (toxic masked) | ✓ |
| AI_CBM_Confuse: already confused → −5 and end (`Score_Minus5` ends the script), else Own Tempo → −10; Safeguard line commented out | `data/battle_ai_scripts.s:390-395` | `confusionTurns > 0 → -5` before the Own Tempo `-10`. Effects 49/118/166 mapped. The header "no-op class" comment is updated | ✓ |
| Texts: is confused `:114`, snapped out `:115`, flinched `:123`, hurt itself `:337` | `src/battle_message.c` | Exact strings, including line breaks | ✓ |
| Self-hit text before the HP update | `bs1.s:3743-3751` (printstring, then healthbarupdate/datahpupdate) | Text entry, then `{hpSide, hp}` entry. Tested | ✓ |
| No status1 regression; confusion-free battles keep RNG draws | — | S1-S4 suite 202/0. Confusion block guarded by `confusionTurns > 0` (no draw otherwise). Draw-count test (6) passes | ✓ |

## Findings

### 1. Low: the self-hit "attacker as both sides" is not pinned by an asymmetric fixture

Evidence: mutant M6 (`calculateBaseDamage(battler, <opponent>, ...)`) survives. Every self-hit test uses a player and foe with identical defense (20) and neutral defense stages. Burn, Explosion and the attack stage are all read from the attacker either way.

Fix (C2 or follow-up): add a self-hit test where the opponent's defense or defense stage differs from the attacker's, for example foe `defense = 40` or `statStages.defense = 8`, and assert the attacker-only oracle (6).

### 2. Low: "no crit" in the self-hit is not pinned

Evidence: mutant M7 (`isCrit = true`) survives. In this engine the crit ×2 is applied outside `calculateBaseDamage`, so the crit flag changes only stage handling and screens. Fixtures have no lowered attack stage and no raised defense stage, and the Reflect test passes `nil` screens.

Fix: add a self-hit test with `statStages.attack = 4` (lowered) or `statStages.defense = 8` (raised), with the hand-derived oracle. A crit would ignore those stages.

### 3. Low: the self-hit KO event payload is untested

Evidence: mutant M26 (HP clamp removed) survives. `recordFaint` resets `hp = 0`, so only the event's `amount`/`hpRemaining` change (−3 instead of 0, which the controller would feed to the HP bar). The KO tests do not assert the `confusionSelfHit` payload.

Fix: in the KO test, assert `hpRemaining == 0` and `amount == 3` (the attacker's HP before the hit).

### 4. Low: doc comments not updated for the new cancellers

Evidence: the `resolveStatusCancellers` header still cites only `:1266-1333, :1439-1449, :1513-1525`. Its "Draws:" sentence lists freeze and paralysis but not the confusion `Random() & 1` or the self-hit multiplier draw. The `BattleEngine.lua` file header's supported-features list (the "Primary status (status1) EFFECTS" bullet) does not mention status2 confusion/flinch support. The inline comments at each canceller are correct.

Fix: add `:1361-1371, :1407-1435` and the confusion/self-hit draws to that header. Add a one-line status2 bullet to the file header.

## Mutation testing

All three source files were saved to the scratchpad. Each mutant was applied by exact single-occurrence string replacement, then the four targeted test files were run, then the files were restored. After the run, sha1 checksums matched the saved originals.

| # | Mutant | Result | Killing test |
| --- | --- | --- | --- |
| M1 | Flinch canceller after confusion | Killed | flinch precedes confusion |
| M2 | Confusion before freeze/flinch | Killed | flinch precedes confusion; frozen: confusion does not tick |
| M3 | Confusion after paralysis | Killed | confusion then paralysis; self-hit ends the cancellers |
| M4 | No decrement-first (test before decrement) | Killed | 1 turn left: snapped out; snapped out then paralysis |
| M5 | `&1` inverted | Killed | &1 nonzero proceeds; &1 zero hurts itself |
| M6 | Self-hit uses the opponent as defender | **Survived** | (Finding 1) |
| M7 | Self-hit with crit | **Survived** | (Finding 2) |
| M8 | Self-hit with STAB ×1.5 | Killed | self-hit damage oracle |
| M9 | Self-hit with the attacker side's screens | Killed | burn halves, Reflect ignored |
| M10 | No random multiplier draw | Killed | self-hit draws; random multiplier |
| M11 | Explosion quirk removed | Killed | confused Self-Destruct user halves its own defense |
| M12 | No faint check after the self-hit | Killed | self-hit KO tests |
| M13a | Paralysis skipped after the proceed path | Killed | confusion then paralysis; Snore confused order |
| M13b | Paralysis skipped after snap-out | Killed | snapped out then paralysis |
| M14a | Flinch not cleared at turn start | Killed | flag from a previous turn cleared |
| M14b | Flinch not cleared at end-turn | Killed | end-of-turn phase clears flinch |
| M15 | Faint does not clear confusion | Killed | faint clears confusion |
| M16 | Flinch flag not consumed | Killed | the flinch flag is consumed |
| M17 | Flinch does not cancel the move | Killed | flinched battler: no use, no PP |
| M18 | Snore `fastAsleep` before the cancellers (pre-fix placement) | Killed | flinched / confused sleeping Snore user |
| M19 | AI −5 branch removed | Killed | AI_CBM_Confuse confused target −5 |
| M20 | AI −5 after Own Tempo | Killed | confusion branch precedes Own Tempo |
| M21 | "flinched!" typo | Killed | controller flinched (:123) |
| M22 | "It hurt itself" line-break typo | Killed | controller hurt itself (:337) |
| M23 | HP entry before the self-hit text | Killed | controller hurt itself then HP |
| M24 | "snapped out" line-break typo | Killed | controller snapped out (:115) |
| M25 | Snap-out consumes a draw | Killed | snapped out, no confusion draw |
| M26 | Self-hit HP clamp removed | **Survived** | (Finding 3) |
| M27 | Move proceeds after the self-hit | Killed | &1 zero: move not used |

Score: 26 of 29 killed. All three survivors are behaviour-preserving for the current code, which is correct. They are oracle gaps, recorded as Findings 1-3.

## Recommendation

PASS for C1. Apply Findings 1-4 (tests and comments only) in C2 or a small follow-up. They do not gate this slice.

## Worker disposition (2026-10-14)

Findings 1-3 tests added (own-defense/no-crit oracle 4; KO event clamp); finding 4 comments updated.
