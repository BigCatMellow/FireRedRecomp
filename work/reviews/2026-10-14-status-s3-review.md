# Review: P4-STATUS-S3 primary status moves

- Reviewer: independent Reviewer (Claude), per `AGENTS.md` rule 6
- Date: 2026-10-14
- Commit under review: `fa9556a` (Status S3: primary status moves (13 moves) and AI status branches)
- Task: [`work/tasks/phase4-status-s3-primary-status.md`](../tasks/phase4-status-s3-primary-status.md)
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Verdict: **PASS** (no Blocker or Major findings. Four Minor findings and two Info findings are listed below. The orchestrator can route them as one small follow-up or take them into S4.)

## Summary

All five scripts match source in gate order and outcomes. PP is spent on
every path, RNG use is correct (no draw before `accuracycheck`, then one
accuracy draw, then the sleep-duration draw), and the `resultmessage`
precedence is right. The AI `if_status`/`if_not_status` branches, the texts,
the 13 ROM fixture records and the inventory arithmetic also match. Changed
files stay inside MAY CHANGE, and `main.lua` is not touched.

Mutation testing killed 26 of the 30 mutants. One survivor (M22) is close to
equivalent: it differs only on a status word this engine cannot produce. The
other three survivors (M1, M9, M25) are missing ordering/branch assertions in
the tests. The implementation is correct in all three cases.

## Verification performed

### Scripts (`data/battle_scripts_1.s`)

| Script | Source gate order (after attackcanceler/attackstring/ppreduce) | Engine order | Result |
| --- | --- | --- | --- |
| Sleep :287-301 | [Substitute] → already asleep → `jumpifcantmakeasleep` (Uproar, Insomnia/Vital Spirit) → STATUS1_ANY → accuracycheck → [Safeguard] → seteffectprimary | already → Insomnia/Vital Spirit → any → acc → apply | match (Uproar/Substitute/Safeguard unmodeled, stated) |
| Poison :984-1003 | Immunity → [Sub] → POISON → TOXIC_POISON → Poison type → Steel type → ANY → acc | same | match |
| Paralyze :1005-1024 | Limber → [Sub] → `typecalc` + `jumpifmovehadnoeffect` → PARALYSIS → ANY → acc | Limber → `BattleFormulas.typeCalc` noEffect → already → any → acc | match |
| Toxic :687-706 | Immunity → [Sub] → POISON → TOXIC_POISON → **ANY** → Poison → Steel → acc | same (any-status before type) | match |
| Will-O-Wisp :2170-2185 | [Sub] → BURN → Fire type → Water Veil → ANY → acc | same | match |

- PP: `resolveMoveCore` subtracts PP once, before `resolvePrimaryStatusMove`.
  The noPP guard and the status cancellers run earlier, as `attackcanceler`
  does in source. Every failure path therefore spends PP, and M13 confirms
  the tests check this.
- Failure targets and texts:
  - `BattleScript_ButItFailed` (:2054-2060) ORs `MOVE_RESULT_FAILED` and then calls `resultmessage`.
  - `Cmd_resultmessage` (bsc.c:1930-2016):
    - A miss path has `MISSED` set without `DOESNT_AFFECT`, so it prints the miss string ("X's attack missed!"). The engine's `miss` event is correct.
    - The paralysis typecalc path has `DOESNT_AFFECT_FOE|FAILED`. Execution reaches `default:`, and `DOESNT_AFFECT` wins, so it prints "It doesn't affect…". The engine's `noEffect` event is correct.
  - `ModulateDmgByType` (bsc.c:1240-1272) sets only `DOESNT_AFFECT_FOE` for x0. For power-0 moves it adds no effectiveness bits.
  - `Cmd_typecalc` (bsc.c:1274-1340): Levitate applies only to Ground moves, and none of the 13 is Ground. Wonder Guard requires `power`, so neither applies here. The foresight-marker walk gives Normal→Ghost x0 for Glare, and the tests cover this.
- `accuracycheck` miss: the branch jumps to `ButItFailed`. `JumpIfMoveFailed` calls `ABILITYEFFECT_ABSORBING` only on the hit path. In battle_util.c:1891-1943, Volt Absorb and Water Absorb require `power != 0`. Flash Fire has no power check, but every Flash Fire holder is Fire-type, and Will-O-Wisp's Fire-type gate runs before accuracy, so this case is unreachable.
- `SetMoveEffect(primary=TRUE)` (bsc.c:2110-2380), checked for anything that could still fire after the script gates:
  - Shield Dust and Safeguard are skipped because `!primary`.
  - hp==0 cannot occur, because the singles target is alive at move time.
  - Substitute is unmodeled.
  - Sleep's Uproar loop and Soundproof are unmodeled (stated). Its status1/Vital Spirit/Insomnia checks are already covered by the script gates.
  - The Immunity/Water Veil/Limber primary text paths are unreachable, because the script's `jumpifability` runs first. The Poison/Steel/Fire `HITMARKER_STATUS_ABILITY_EFFECT` paths do not apply.
  - The full-word `status1` test (which includes the toxic counter) can differ from STATUS1_ANY only with a counter but no toxic bit. The engine never produces that: `withToxicCounter` is written only alongside toxic, and the bridge clears it.
  - The sleep draw `(Random() & 3) + 2` (:2354) matches `next16() % 4 + 2`.
  - Synchronize (:2375-2384) is unmodeled (stated).
- Cmd_accuracycheck (bsc.c:1003-1098), branch by branch:
  - Protect, Lock-On/Mind Reader (`STATUS3_ALWAYS_HITS`) and semi-invulnerable targets: their families are not admitted (inventory 111, 94, 155-as-plain-hit), so none of these is reachable.
  - Foresight (status2): unmodeled.
  - Weather (Thunder, Sand Veil): unmodeled.
  - Bright Powder/Enigma (held items): unmodeled.
  - Compound Eyes and Hustle: **missing** (F1).
  - First-battle skip (:1006-1018): for player power-0 moves it skips the roll only until `TestState2Flag(2)`. The engine's primary-status path ignores `firstBattle`. This is unreachable: the Oak's-lab starters (Tackle/Scratch + Growl/Tail Whip at level 5) know none of the 13 moves, and the rival never uses one. Info only (F6).
- Move-end: `resolveMove`'s Fire defrost requires `moveDamageDealt > 0`, so a Will-O-Wisp failure against a frozen target does not thaw it. Source sets `MOVE_RESULT_FAILED` on that path, which also prevents the thaw.

### Texts (`src/battle_message.c`)

The following match source, with the line break placement and punctuation
taken from the controller strings:

| Message | Source line |
| --- | --- |
| "is\nalready asleep!" | :85 |
| "is already\npoisoned." (used by Poison and Toxic) | :91 |
| "already\nhas a burn." | :97 |
| "is\nalready paralyzed!" | :107 |
| "stayed awake\nusing its {B_DEF_ABILITY}!" ("INSOMNIA"/"VITAL SPIRIT", via `gUproarAwakeStringIds[B_MSG_STAYED_AWAKE_USING]`) | :174 |
| "It doesn't affect…" | :70 |
| "But it failed!" | :336 |
| "attack missed!" | :65 |
| "fell asleep!" | :83 |
| prevention texts | :270, :272, :280 (S2-reviewed) |

Ability ids 7/15/17/41/72 match `include/constants/abilities.h`.

### AI (`data/battle_ai_scripts.s`, `src/battle_ai_script_commands.c`)

- `Cmd_if_status` and `Cmd_if_not_status` (aisc.c:595-630) test
  `gBattleMons[b].status1 & flags`. STATUS1_ANY (battle.h:101) is SLEEP |
  POISON | BURN | FREEZE | PARALYSIS | TOXIC_POISON, so it excludes
  TOXIC_COUNTER. `StatusConditions.hasAny` (`% 256 ~= 0`) is therefore exact.
- Branch order matches source:
  - Sleep :216-222: ability, then status.
  - Poison/Toxic :344-355: type1/type2 Steel/Poison, Immunity, then status.
  - Paralyze :401-407: x0, Limber, then status.
  - Will-O-Wisp :535-543: Water Veil, status, then x0/x0.5/x0.25.
  - Nightmare :237-240: status2 no-op, then not-asleep -8.
  - Dream Eater :242-245: not-asleep -8, then x0 -10.
  - Snore/Sleep Talk :430-432: user not asleep -8.
  - Refresh :567-569: user lacks PSN|BRN|PAR|TOX -10. Sleep and freeze correctly still get -10.
- Dispatch chain :105-205 maps 1→Sleep, 33/66→Poison, 67→Paralyze,
  167→WillOWisp, 8, 107, 92/97 and 193. `EFFECT_HANDLERS` matches.
- Reachability:
  - TrainerAI runs only `AI_CheckBadMove` (flags 0x1), or EarlyRivalAI for 0x7.
  - EarlyRivalAI is bounded to Tackle/Scratch/Growl/Tail Whip and errors loudly on anything else. The early rivals' rosters contain none of the 13, so this edit does not affect it.
  - No AI_CV or other script that reads status is ported, so no other AI path now sees status.
  - The 13 moves' effects are all in `EFFECT_HANDLERS`, not `UNPORTED_EFFECTS`, so foe scoring cannot crash on them. Memento (168) is still an `UNPORTED_EFFECTS` error, as the task states, and is unchanged.
  - Wild foes pick uniformly at random (aiFlags 0).
  - Previously, a wild or trainer foe that picked one of these 13 hit `resolveMoveCore`'s "unsupported move effect" error. Now the move resolves.

### Admission and controller

- `supportsMove` admits the five effects only with `power == 0 and target == 0`. All 13 records are SELECTED/power 0. M19 confirms that widening admission is caught.
- The controller's player-side gate calls `supportsMove`, so player-side admission and engine-side admission are the same.
- The boundary test now uses EFFECT_CONFUSE (49), which `supportsMove` still rejects (inventory row 49 = blocked). This is correct.

### ROM fixture and inventory

- I parsed `src/data/battle_moves.h` independently. All 13 records match the fixture: effect, type, accuracy, pp, chance, power 0, target 0, priority 0, and flags PROTECT|MAGIC_COAT|MIRROR = 0x16 (pk.h:239-242). The family count across the whole table is exactly 13.
- Arithmetic:
  - Admitted: 263+13 = 276, rejected 91-13 = 78.
  - Represented: 76+5 = 81 families, 185+13 = 198 moves, 137 positive, 48+13 = 61 zero.
  - Blocked: 121-5 = 116 families, 168-13 = 155 moves, 78 positive, 90-13 = 77 zero, 78/77 admitted/rejected.
  - The test, the report table and the five rows agree.

### Commands run (all at `fa9556a`, no ROM available: `POKEPORT_ROM` unset)

| Command | Result |
| --- | --- |
| `lua5.1 tests/battle_status_engine_test.lua` | 146 passed, 0 failed |
| `lua5.1 tests/battle_scene_controller_test.lua` | 135 passed, 0 failed |
| `lua5.1 tests/ai_check_bad_move_test.lua` | 37 passed, 0 failed |
| `lua5.1 tests/trainer_ai_test.lua` | 7 passed, 0 failed |
| `lua5.1 tests/phase4_move_effect_inventory_test.lua` | partition checked; ROM part SKIP |
| `lua5.1 tests/phase4_primary_status_effect_rom_test.lua` | SKIP (ROM fixture pending, as stated) |
| `bash scripts/test_all.sh` | PASS: 165 test files (no-ROM mode) |
| `lua5.1 scripts/check_repository.lua` | PASS (292 Lua, 305 Markdown, 1005 local targets) |

## Findings

### F1 (Minor): Compound Eyes and Hustle accuracy modifiers are not applied, and the S3 rows do not state the limit

- Evidence:
  - `Cmd_accuracycheck` applies `calc * 130 / 100` for an attacker with `ABILITY_COMPOUND_EYES` (14) at bsc.c:1069-1070.
  - It applies `calc * 80 / 100` for Hustle when `IS_TYPE_PHYSICAL(type)` (type < TYPE_MYSTERY) at bsc.c:1073-1074. That condition also covers the Normal/Poison status moves Sing, Glare, Lovely Kiss, Poison Powder, Poison Gas and Toxic.
  - `BattleFormulas.accuracyCheck` takes no ability input.
  - Abilities are populated (`BattlePartyBridge.lua:149`, `WildPokemonFactory.lua:256`).
- Why it matters now: S3 makes Butterfree (Compound Eyes, learns Poison Powder, Stun Spore and Sleep Powder by level-up), Venonat and Yanma (Hypnosis) the most exposed case. Their 75% moves really hit at 97%, but this engine rolls them at 75%, which changes both the outcome and the RNG stream. Before S3, Butterfree's damaging moves were all 100% accuracy, so the gap was mostly invisible.
- Existing coverage: this is a shared, pre-existing gap in `BattleFormulas` (outside this task's MAY CHANGE). It is covered only by the engine header's blanket "No abilities, held items, weather" (BattleEngine.lua:242).
- Fix:
  - Add "Compound Eyes/Hustle accuracy modifiers absent" to the S3 task's Follow-ups and to the five inventory rows' limits.
  - Schedule a small shared accuracy-modifier slice for `BattleFormulas.accuracyCheck`, which covers every accuracy-checked family.

### F2 (Minor): three gate orders and one AI branch are not pinned by tests (mutants M1, M9, M25 survive)

- Evidence:
  - M1: moving sleep's Insomnia/Vital Spirit check before the already-asleep check survives. No test uses a sleeping target that has Insomnia. Source order: already asleep, then `jumpifcantmakeasleep`.
  - M9: moving Toxic's already-poisoned check before Immunity survives. Only Poison has the "Immunity first" test.
  - M25: dropping `isBadlyPoisoned` from AI Refresh survives. There is no toxic-only user case.
- Fix: add three assertions:
  - A sleeping Insomnia foe gets `statusAlready` (not `stayedAwake`).
  - An already-poisoned Immunity foe hit by Toxic gets `statusPrevented`.
  - A badly poisoned user scores Refresh at 0.

### F3 (Minor): inventory row text copied across all five rows

- Evidence: all five new rows (1, 33, 66, 67, 167) contain the same two inaccuracies:
  - They say "Script gate order (ability, already-status, type/typecalc immunity, other status)". That is not the order for Sleep (already, then ability), Will-O-Wisp (already, Fire, Water Veil, any) or Toxic (any-status before type).
  - They end "sleep draws 2-5 turns", including on the rows for Poison, Paralyze, Toxic and Will-O-Wisp.
- Acceptance item 1 in the task file has the same generic parenthetical.
- Fix: write "Script-specific gate order (see S3 source lock)" and keep the sleep-duration note on row 1 only.

### F4 (Minor): stale "confirmed no-op" text in the AICheckBadMove header

- Evidence:
  - `src/core/AICheckBadMove.lua:88` still lists `if_status` among the fields that "this engine structurally can never produce the true case for".
  - The example "e.g. 'if user is NOT asleep' -- as an always-applied fixed penalty" now describes no remaining handler.
  - The new STATUS1 paragraph at :80-81 contradicts both.
- Fix: delete `if_status/` from that list and the NOT-asleep example.

### F5 (Info): engine header says "No abilities"

- `BattleEngine.lua:242` ("No abilities, held items, weather, ...") predates the S2/S3 guard abilities (Shield Dust, Immunity, Limber, Water Veil, Magma Armor, Insomnia, Vital Spirit, Damp).
- Rewording it as "No abilities beyond the listed guards" would also make F1's limit explicit.

### F6 (Info): first-battle accuracy skip not applied to the primary-status path

- Source skips the roll for player power-0 moves in FIRST_BATTLE until the Oak-controller flag 2 is set (bsc.c:1006-1018).
- The engine's tutorial-accuracy logic (BattleEngine.lua:1472-1483) is bypassed by `resolvePrimaryStatusMove`.
- This is unreachable today, because no Oak's-lab starter or rival move belongs to these families. No action is needed unless first-battle movesets change.

## Mutation testing

Method:
1. I backed up the three source files to the scratchpad.
2. For each mutant, I applied an exact single-occurrence string replacement (`scratchpad/mut.py`).
3. I ran the status engine, controller, AI and trainer AI tests.
4. I restored each file from its backup before the next mutant.

`git status --short` was clean afterwards, before this file was written.

| # | Mutant | Result |
| --- | --- | --- |
| M1 | Sleep: Insomnia/Vital Spirit before already-asleep | **SURVIVED** (F2) |
| M2 | Sleep: any-status before already-asleep | killed (status engine) |
| M3 | Poison: already-poisoned before Immunity | killed (status engine) |
| M4 | Poison: any-status before type (Toxic order) | killed (status engine) |
| M5 | Paralyze: already-paralyzed before typecalc | killed (status engine) |
| M6 | Paralyze: typecalc removed | killed (status engine) |
| M7 | Paralyze: Limber after typecalc | killed (status engine) |
| M8 | Toxic: type before any-status (Poison order) | killed (status engine) |
| M9 | Toxic: already-poisoned before Immunity | **SURVIVED** (F2) |
| M10 | Will-O-Wisp: Water Veil before Fire type | killed (status engine) |
| M11 | Will-O-Wisp: any-status before Water Veil | killed (status engine) |
| M12 | Will-O-Wisp: Fire type before already-burned | killed (status engine) |
| M13 | PP spent only after gates pass | killed (status engine) |
| M14 | accuracycheck before all gates | killed (status engine) |
| M15 | sleep duration drawn before accuracy | killed (status engine) |
| M16 | Poison type immunity drops Steel | killed (status engine) |
| M17 | typecalc no-effect emits "But it failed" | killed (status engine) |
| M18 | accuracy miss emits "But it failed" instead of miss | killed (status engine) |
| M19 | admission widened (target check dropped) | killed (status engine) |
| M20 | already-asleep emits moveFailed | killed (status engine) |
| M21 | AI Sleep: STATUS1 branch removed | killed (AI) |
| M22 | AI Paralyze: raw `status ~= 0` instead of STATUS1_ANY | **SURVIVED**: near-equivalent (differs only for a counter-only status word the engine never produces; the Poison variant M23 is pinned) |
| M23 | AI Poison: raw `status ~= 0` | killed (AI) |
| M24 | AI Dream Eater: x0 branch removed | killed (AI) |
| M25 | AI Refresh: toxic bit dropped | **SURVIVED** (F2) |
| M26 | AI Will-O-Wisp: STATUS1 branch removed | killed (AI) |
| M27 | AI Snore/Sleep Talk reads target instead of user | killed (AI) |
| M28 | Text: "has a burn." → "has a burn!" | killed (controller) |
| M29 | Text: Insomnia shown as "VITAL SPIRIT" | killed (controller) |
| M30 | Text: already-poisoned line break moved | killed (controller) |

Result: 26 of 30 killed. 1 survivor is near-equivalent, and 3 survivors are test gaps (F2).

## Scope

Changed paths are exactly the MAY CHANGE set:
- `BattleEngine.lua`, `BattleSceneController.lua`, `AICheckBadMove.lua`
- the listed tests and the new ROM fixture
- the inventory report and the task file

`main.lua`, save format, replays and coordination files are untouched.
Acceptance items 1-6 are met. The ROM fixture is pending the next guarded
bridge run, as the fast-lane rule states.

## Worker disposition (2026-10-14)

F1 recorded as a limit (task follow-up, inventory rows); F2 tests added; F3 per-family rows and acceptance text; F4/F5 comments updated.
