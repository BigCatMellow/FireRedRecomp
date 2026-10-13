Verdict: **NEEDS_FIX** (runtime behavior matches the source on every represented path I checked; one Medium test gap lets the dual-type (`type2`) half of both Conversion type checks regress undetected, plus Low and Nit findings)

# Conversion and Memento (fast lane batch 6): independent review

- Branch `claude/wizardly-faraday-o45q9z`, head `c9d136056be04dadf998aee3a68469ac515f9a93`, base `origin/main`. One commit (`c9d1360`).
- Task: [P4-FL6-CONVERSION-MEMENTO](../tasks/phase4-conversion-memento.md). Lane: AGENTS.md "Battle-effect fast lane".
- Families: 30 Conversion (160), 168 Memento (262). Singles only.
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`. Files: `bs1.s` = data/battle_scripts_1.s, `bsc.c` = src/battle_script_commands.c, `bm.c` = src/battle_message.c, `bmain.c` = src/battle_main.c, `bmv.h` = src/data/battle_moves.h, plus include/constants/pokemon.h, include/pokemon.h, include/battle.h and data/battle_ai_scripts.s, fetched at the pin.
- Reviewer: independent reviewer subagent. It did not construct the change. Nothing was modified, committed or pushed in the checkout. Mutations ran on a `git archive HEAD` copy at `/tmp/claude-0/review6/base`, using the harness `/tmp/claude-0/review6/tools/mut.py` (10 s timeout per test file). Extra probes are in `/tmp/claude-0/review6/probe/dual.lua`.

## Scope

- 8 files. All are MAY CHANGE paths or the task file:
  - `src/core/BattleEngine.lua` (+77/-2)
  - `src/core/BattleSceneController.lua` (+12)
  - `tests/battle_engine_test.lua` (+72)
  - `tests/battle_scene_controller_test.lua` (+38)
  - `tests/phase4_conversion_memento_effect_rom_test.lua` (new, 35 lines)
  - `tests/phase4_move_effect_inventory_test.lua` (2 rows and the totals)
  - `work/reports/phase4-move-effect-inventory.md` (summary table and rows 30 and 168)
  - `work/tasks/phase4-conversion-memento.md` (new)
- No `main.lua` change, no save-format change, no change to runtime replays, no new state that lasts across turns. The batch is eligible for the fast lane.
- Apart from the two inventory rows and the totals, no existing test line was removed or changed.
- There are no ROM bytes, extracted tables or binaries. The fixture holds literals from `bmv.h:2083-2094` and `3409-3420`.
- `git diff --check origin/main...HEAD` is clean.

## Source conformance

| Source (c75f352) | Implementation | Result |
| --- | --- | --- |
| `bs1.s:658-667` attackcanceler → attackstring → ppreduce → `tryconversiontypechange ButItFailed` → PKMNCHANGEDTYPE. No accuracycheck | Excluded from `needsAccuracyCheck` (`BattleEngine.lua:1192`). The shared ppreduce runs at `:1218-1220`, before the handler at `:1256` | Match. PP drops by 1 on success and on failure |
| `bsc.c:7009-7015` counts leading slots until the first `MOVE_NONE`, capped at 4 | `while valid < 4 and moves[valid+1] and moves[valid+1].move ~= 0` (`:1270-1273`) | Match. Battlers never hold move-0 entries, because `BattlePartyBridge.lua:105-113` compacts them out |
| `bsc.c:7021-7027` TYPE_MYSTERY → GHOST if `IS_BATTLER_OF_TYPE(attacker, GHOST)` (type1 or type2), otherwise NORMAL | `slotType` (`:1261-1268`): `types[1]==7 or types[2]==7` → 7, otherwise 0 | Match. The type2 branch is untested (F1) |
| `bsc.c:7028-7038` fails only when every counted slot's type equals type1 or type2 | `any` scan (`:1274-1281`) → `moveFailed` with no RNG | Match. The type2 branch is untested (F1) |
| `bsc.c:7041-7055` `do { while ((Random() & 3) >= valid); type... } while (type is own)`: the inner loop rejects slot indices, the outer loop rejects own types, and Mystery is re-mapped on every draw | Nested `repeat` (`:1282-1287`), `next16() % 4` | Match. Every draw consumes exactly one `Random()` |
| `SET_BATTLER_TYPE` sets type1 and type2 | `attacker.types = { newType, newType }` (`:1288`) builds a new table, so `makeBattler` (`:790`) and the species data stay unchanged | Match |
| `bm.c:122` "{B_ATK_NAME_WITH_PREFIX} transformed\ninto the {B_BUFF1} type!"; `bmain.c:428-448` gTypeNames | `BattleSceneController.lua:51-54, 268-270` | Match. All 18 names checked by hand (0 NORMAL … 9 ??? … 17 DARK). Only FIRE is asserted (F3) |
| How long the type change lasts | Per battler object. A switch or replacement builds a fresh battler from species types. `persistPartyBattler` (`BattlePartyBridge.lua:178-193`) writes back only PP, HP and status | Match (in the source the change is cleared on switch-out). No leak into the save |
| Move lookup | `self.moves` is the full parsed gBattleMoves table on every real call site (`main.lua` `catalog.moves`). `resolveMove` already errors earlier for unknown ids | OK |
| `bs1.s:2199-2232` Memento: attackcanceler → (protect branch) → attackstring → ppreduce → `trymemento` → `setatkhptozero` → (Substitute branch) → ATK −2 / SP.ATK −2, each message skipped when `cMULTISTRING_CHOOSER > B_MSG_DEFENDER_STAT_FELL` → `tryfaintmon BS_ATTACKER`. No accuracycheck | Excluded from accuracy (`:1193`). Order inside the handler (`:1292-1320`): gate → `hp=0`/`mementoHP` → two drops → `checkFaint(attacker)` | Match. Protect and Substitute are not modeled anywhere in the engine and the task excludes them |
| `bsc.c:8681-8698` fails only when ATK **and** SP.ATK are both MIN (unprotected) | `stages.attack == MIN and stages.spAttack == MIN` (`:1297-1301`) → `moveFailed`, HP unchanged | Match ("But it failed!", user survives) |
| `bsc.c:6655-6790` ChangeStatBuffs: if the stage is MIN, the chooser is `B_MSG_STAT_WONT_DECREASE` (>1) and the message is skipped; otherwise the stage drops by 2, clamps, and the text uses STATHARSHLY | `if stages[stat] > MIN then max(MIN, s-2)`, event `stages=-2` (`:1304-1309`). The controller's −2 case gives "harshly fell!" | Match, including 1 → 0 printing "harshly fell". Mist, Clear Body and Hyper Cutter are not modeled in the engine (excluded) |
| RNG | None on any Memento path | Match (asserted: `draws==0`) |
| Oak's first-battle tip on the first DEFENDERSSTATFELL | Mirrors the Tickle block (`:1310-1314`) | Same as the accepted Tickle pattern. Not reachable with fixed Lv5 starters. Untested (F2) |
| Faint of the user | `checkFaint` → `recordFaint` / `finalizeFaintSequence` → `battleEnd` or `forcedSwitchNeeded`. The runTurn loop then returns at `:2211` | Uses the existing path, the same as Explosion and crash (see Notes N1) |
| Controller: the HP bar drops before the stat text | An invisible `{hpSide, hp=0}` entry (`BattleSceneController.lua:271-273`) is applied when "used MEMENTO!" is acknowledged | Match (asserted) |

ROM fixture vs `bmv.h`:
- Conversion: effect 30, type NORMAL 0, acc 0, pp 30, target `MOVE_TARGET_USER` (1<<4 = 0x10), flags 0.
- Memento: effect 168, type DARK 17 (`constants/pokemon.h:114`), acc 100, pp 10, target SELECTED 0, flags `FLAG_PROTECT_AFFECTED (1<<1) | FLAG_MIRROR_MOVE_AFFECTED (1<<4)` = 0x12.

All of these match.

## Regression check

- Every new branch is gated on effect 30 or 168. The ROM fixture's membership loop confirms that only moves 160 and 262 carry these effects.
- The `needsAccuracyCheck` list only gains the two effects. `supportsMove` only gains two clauses.
- All 541 earlier engine assertions and 100 earlier controller assertions still pass unchanged, including every existing RNG-count vector.
- `AICheckBadMove` is unchanged:
  - effect 30 falls through to 0, which matches the source: the CheckBadMove chain has no Conversion entry; `AI_CV_Conversion` belongs to another tier.
  - effect 168 still errors loudly. This is pre-existing (N2).

## Assertions and mutations

The oracles come from the source:
- The 0, 3, 1 draw vector is derived by hand from the nested loop.
- The stages (6−2 = 4, 1 → 0 clamp) come from ChangeStatBuffs.
- Text and names are literals from `bm.c` and `bmain.c`. Nothing is read back from the implementation.

| Mutation | Result |
| --- | --- |
| M1 outer own-type rejection removed | Caught (4) |
| M2 single draw `% valid` / M2b clamped single draw | Caught (2 each) |
| M3 Mystery always NORMAL / M3b Mystery not re-mapped | Caught (2 / 4) |
| **M3c Ghost test uses only type1** | **Survived** (F1) |
| M4 types[2] not set | Caught |
| M5 fail scan only slot 1 | Caught (engine and controller) |
| M5b fail scan without Mystery re-map | Caught (hang, killed by the 10 s timeout) |
| **M5c own-type test uses only type1** | **Survived** (F1) |
| M5d slot count ignores move 0 | Survived. Unreachable, since battlers never hold move 0 |
| M6 / M11 accuracy re-enabled (Conversion / Memento) | Caught |
| M7 drops before HP 0 | Caught (engine and controller) |
| M8 −1 drop / M8b event `stages=-1` | Caught |
| M9 gate on either stat / M9b gate on ATK only | Caught (test errors) |
| M10 user survives / M10b HP not zeroed | Caught |
| M12 PP not spent / M12b PP refunded on failure | Caught |
| M13 MIN stat not skipped | Caught |
| **M14 Memento tutorial block removed** | **Survived** (F2) |
| C1 controller HP entry removed | Caught |
| **C2 gTypeNames "FIGHT" → "FIGHTING"** | **Survived** (F3) |
| C3 message names the wrong side | Caught |
| A1 Conversion admission ignores power | Caught |

The probe (`probe/dual.lua`) confirms that the implementation itself is right for dual types:
- Dark/Ghost user with Conversion, Curse and Bite, draws 1, 2, 0: newType NORMAL after 3 draws.
- Normal/Dark user with Conversion and Bite: fails with 0 draws.

The gap is in the tests only.

Inventory arithmetic:
- represented 68 → 70 families, 160 → 162 moves, zero-power 46 → 48.
- candidate 2 → 0.
- Admitted 261 → 263 (162 + 101 + 0); rejected 93 → 91 (0 + 90 + 1).
- The report table matches the test. Rows 30 and 168 say `R`, admitted `yes`, "ROM fixture pending".

## Test results

- `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh`: exit 0, "PASS: 161 test files (no-ROM mode; ROM-dependent checks skip cleanly)".
- `lua5.1 scripts/check_repository.lua`: "PASS: repository checks (287 tracked Lua, 293 tracked Markdown, 976 local targets)".
- `tests/battle_engine_test.lua`: 560 passed, 0 failed (was 541; +19 = 9 per side × 2 + 1).
- `tests/battle_scene_controller_test.lua`: 102 passed, 0 failed.
- `tests/phase4_move_effect_inventory_test.lua`: partition checked, clean no-ROM SKIP.
- `tests/phase4_conversion_memento_effect_rom_test.lua`: clean SKIP. The ROM run is still pending, as the lane allows.

## Findings

**F1 (Medium): the type2 half of both Conversion type checks is unpinned.**
- Where: `tests/battle_engine_test.lua:2316-2337`.
- Every Conversion vector uses a mono-type user (`{0,0}` or `{7,7}`), so type1 == type2. Mutations M3c and M5c pass the whole suite:
  - M3c: `IS_BATTLER_OF_TYPE` checks only type1.
  - M5c: the own-type test, used by both the fail scan and the outer rejection loop, checks only type1.
- `bsc.c:7023,7029-7030,7046,7052` name type2 explicitly, and Ghost or Dark dual types (Gastly line, Misdreavus, Sableye) are exactly where this matters.
- Fix: add vectors for both sides:
  - (a) User `{17,7}` with moves `{160,174}` and draws `{1,0,4321}` → Curse reads GHOST through type2 and is rejected; result NORMAL; `draws==2`. Under M3c, Curse reads NORMAL and is accepted after 1 draw, so this kills M3c.
  - (b) User `{0,17}` with `{160,44}` (Bite, DARK) → `moveFailed`, `draws==0`. This kills M5c on the fail scan.
  - (c) User `{0,17}` with `{160,44,52}` and draws `{1,0,2,4321}` → result FIRE after 3 draws. This kills M5c in the rejection loop.

**F2 (Low): Memento's first-battle tutorial block is unasserted.**
- Where: `src/core/BattleEngine.lua:1310-1314`. Removing it (M14) passes everything.
- The task design says Memento "mirrors the first-battle defender-stat-fell tutorial block". That claim has no evidence.
- Fix: add one `firstBattle=true` player Memento vector. Assert `tutorialTip` right after the first `statChange` and only once, and that `tutorialPlayerStatDone` is set. A foe Memento should emit no tip. Alternatively, drop the block and document it as unreachable.

**F3 (Low): only one of the 18 gTypeNames is asserted.**
- Where: `src/core/BattleSceneController.lua:51-54`. A typo in any name except FIRE (C2) passes.
- The table was hand-transcribed, and FIGHT, ELECTR and PSYCHC are truncated names that are easy to "fix" by mistake.
- Fix: drive one `conversion` event per type id 0-17 through `_eventMessages`, or expose the table. Assert the full literal list from `bmain.c:430-447`.

**F4 (Nit): a comment now labels the wrong table.**
- Where: `src/core/BattleSceneController.lua:48-55`. The new `TYPE_DISPLAY_NAMES` block sits between the "Real gStatNamesTable…" comment and `STAT_DISPLAY_NAMES`, so that comment now sits above the type table.
- Fix: move the gTypeNames block above the gStatNamesTable comment.

**F5 (Nit): the tests leak a global.**
- Where: `tests/battle_engine_test.lua:2341,2350,2354`. `b,a,d=setup(...)` assigns a global `d`, because `d` is never declared local in this block.
- Fix: `local b,a,d=setup(side,{160,52},{0,3,1,4321})` at `:2324`.

## Notes (pre-existing, not counted against this package)

- **N1:** When Memento's user moves first and faints, the turn halts (`BattleEngine.lua:2211`). The opponent's chosen move is dropped with no RNG and no message. In the probe, with a replacement available, the whole turn consumed 0 draws.
  - This is the engine's documented conservative policy, shared with Explosion and the crash leaves. The header calls the real-source answer ambiguous.
  - Memento makes this the normal case, not an edge case. A follow-up should source-confirm the Gen 3 behavior: `HandleAction_TryFinish` / `HandleFaintedMonActions` and target re-selection at `bmain.c:4110-4130`.
- **N2:** `AICheckBadMove.lua:616` still errors loudly for effect 168. A `AI_SCRIPT_CHECK_BAD_MOVE` trainer that knows Memento therefore fails at AI scoring instead of in the engine; it failed before this change too.
  - The real `AI_CBM_Memento` (`battle_ai_scripts.s:486-493`: target ATK == 0 → −10, SP.ATK == 0 → −8, then falls through to the alive count) is still a separate gap.
- **N3:** `work/reports/phase4-move-effect-inventory.md:25` still says "248 admissions and 106 rejections". The summary table, after this batch, says 263 / 91. This stale narrative predates the batch.
- **N4:** The ROM fixture prints a fixed "3 passed" without counting. This is the same convention as the other fixtures; cosmetic.

— independent reviewer subagent; did not construct the change
