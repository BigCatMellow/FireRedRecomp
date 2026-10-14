# Review: Phase 4 status leftovers design proposal (L1/L2)

- Reviewer: independent design reviewer (Claude)
- Date: 2026-10-14
- Artifact: [`work/reports/phase4-status-leftovers-design-proposal.md`](../reports/phase4-status-leftovers-design-proposal.md)
- Project baseline read: `src/core/BattleEngine.lua`, `BattleFormulas.lua`, `StatusConditions.lua`, `BattleSceneController.lua`, `AICheckBadMove.lua`, `BattlePartyBridge.lua`, `tests/battle_engine_test.lua`, `tests/phase4_move_effect_inventory_test.lua`
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
  - Local copies: `src/battle_script_commands.c` (`bsc.c`), `data/battle_scripts_1.s` (`bs1.s`), `src/battle_util.c`, `src/battle_main.c`, `src/pokemon.c`, `src/data/battle_moves.h`.
  - Fetched at the pin: `src/battle_message.c`, `include/constants/battle.h`, `include/constants/battle_move_effects.h`, `include/constants/battle_script_commands.h`, `src/battle_controller_player.c`, `src/battle_controller_opponent.c`, `data/battle_ai_scripts.s`, `src/battle_ai_script_commands.c`.
- Verdict: **PASS WITH CORRECTIONS**. There are no Blocker or High findings. Every RNG order and count, gate order, text and lifecycle claim checks out against source. The design fits the engine at the sites it names. The corrections are one Medium wording fix to the multi-hit divergence (it decides the scope of the follow-up), plus Low/Info additions to known limits, citations and the list of comments that will go stale. None of them changes L1 or L2 behaviour.

## What was verified (no finding)

### Move records and constants

- All five records (`battle_moves.h:536-547`, `:1511-1522`, `:2031-2042`, `:2096-2107`, `:3890-3901`) match the table: effect, power, type, accuracy, chance, target and the contact flag (Blaze Kick only).
- The effect ids are right: 36/37/43/47/75/77/200/209 (`battle_move_effects.h:40,41,47,51,79,81,204,213`).
- `MOVE_EFFECT_TRI_ATTACK = 9` and burn/freeze/paralysis = 3/4/5 (`battle.h:223-230`). `PRIMARY_STATUS_MOVE_EFFECT = 6` (`:227`), so byte 9 takes the status2 `else` branch (`bsc.c:2396`). `sStatusFlagsForMoveEffects[9]` is 0 (`bsc.c:590-607`), so that test passes.
- `STATUS2_FOCUS_ENERGY = 1<<20` (`battle.h:120`). `STATUS1_SLEEP` is bits 0-2, `TOXIC_POISON` is bit 7 and the counter is bits 8-11 (`:91-98`).

### RNG draw order and count per family

- **Shared roll.** `Cmd_seteffectwithchance` evaluates `Random() % 100 <= percentChance` as the first `&&` operand (`bsc.c:2789`). So the roll is drawn on every reached path, including a byte of 0 and a no-effect hit. `BattleFormulas.secondaryEffectRoll` (`BattleFormulas.lua:552-554`) matches.
- **Tri Attack.** The draw order is accuracy, crit, damage random, `% 100`, then `% 3`.
  - `% 3` is drawn only when all of these hold: the roll passes, the result is not NO_EFFECT, there is no Shield Dust (byte 9 `<= 9`, `bsc.c:2132-2134`), HP > 0 (`:2140-2143`) and status1 == 0 (`:2466-2475`).
  - The recursive `SetMoveEffect(FALSE, 0)` re-runs the guards. Each status case can fail silently after `% 3` has been spent: Fire/Water Veil (`:2218-2256`), Ice/Magma Armor (`:2257-2271`, plus sun) and Limber (`:2272-2301`, silent because `certain == 0`).
  - The sleep draw (`:2356`) is unreachable because the byte is never 1.
  - A Ghost target draws `% 100` and discards it, because `adjustnormaldamage` draws before the engine's no-effect branch. The engine's ordinary path already does this (`BattleEngine.lua:2356-2384`).
- **Twineedle.** The draw order is accuracy, then (crit, damage random) per landed hit, then exactly one `% 100`.
  - The script (`bs1.s:1072-1080`) sets `sMULTIHIT_EFFECT = POISON` after accuracycheck. A miss goes to `PrintMoveMissed`, which has no `seteffectwithchance`.
  - Each iteration runs `movevaluescleanup`, which zeroes the byte (`bsc.c:3469-3478`), and then `copybyte cEFFECT_CHOOSER, sMULTIHIT_EFFECT` (`bs1.s:619-620`; `battle_script_commands.h:15,43`).
  - The per-hit `moveendto MOVEEND_NEXT_TARGET` runs states 0-15 (`battle_script_commands.h:124-140`). None of them reads `MOVE_EFFECT_BYTE` (`bsc.c:4056-4330`).
  - The only `seteffectwithchance` is at `BattleScript_MultiHitEnd` (`bs1.s:651-652`). It is reached on all three paths: full count, early exit at `jumpifhasnohp BS_TARGET` (`:615`), and the no-effect exit (`:624`, then `:643-647`).
  - **The proposal's "single roll after both hits" correction to the brief is right.**
- **Twineedle KO order.** The order is "Hit 1 time(s)!" (`bs1.s:648-650`), then the roll, then `SetMoveEffect` returning on the 0-HP guard, then `tryfaintmon` (`:653`). The proposal is right.
- **Blaze Kick.** Dispatch goes to `BattleScript_EffectBurnHit` (`bs1.s:224`, `:364-366`). The draw order is accuracy, crit at stage 1, random, `% 100`. `MOVEEND_DEFROST` (`bsc.c:4103-4116`) runs after `seteffectwithchance`, and a frozen target cannot be burned because status1 != 0.
- **Rest and Focus Energy** draw nothing. Their scripts have no accuracycheck (`bs1.s:735-746`, `:884-894`).

### Tri Attack gates

- The outer guard order (Shield Dust, then Safeguard, then HP, then Substitute, then status1) matches `bsc.c:2131-2146`, `2466-2469`.
- Handing the chosen kind to `applySecondaryStatus(…, false, …)` (`BattleEngine.lua:1306-1327`) reproduces the inner call's silent failures and the freeze `CancelMultiTurnMoves`. The ability-before-type order inside the engine helper does not matter, because every failure is silent and draws nothing.
- Weather is unmodeled (`BattleEngine.lua:262`), so leaving out sun is a correct known limit.

### Rest

- **Fail checks, in order** (`bs1.s:738-740`):
  1. `jumpifstatus SLEEP`.
  2. `jumpifcantmakeasleep` (`bsc.c:6546-6566`): Uproar first, then Insomnia/Vital Spirit on `gBattlerTarget`.
  3. `trysetrest`, whose full-HP check is at `bsc.c:6486-6488`.

  So a full-HP Insomnia user prints "stayed awake", and a statused user at full HP prints "HP is full!" and keeps its status. The proposal is right on both.
- **The target is the user.** `gBattlerTarget` is the user for a USER-target move in singles:
  - the player controller (`battle_controller_player.c:460-461`);
  - the opponent controller, both its AI and random branches (`battle_controller_opponent.c:1370-1371`, `:1393-1394`);
  - `HandleAction_UseMove` copying `moveTarget` (`battle_main.c:4114-4116`).

  The ability check therefore reads the user's ability, and the texts' `B_DEF_NAME` names the user.
- **Status.** The `(u8)~STATUS1_SLEEP` mask is bits 3-7, which includes TOXIC_POISON and excludes the counter. Then `status1 = STATUS1_SLEEP_TURN(3)` overwrites the word, which clears the toxic counter (`bsc.c:6493-6498`). There is no `CancelMultiTurnMoves`. The HP clamp is in `datahpupdate` (`bsc.c:1789-1794`).
- **Sleep length.** `CANCELLER_ASLEEP` decrements and then tests (`battle_util.c:1266-1300`). The engine's canceller does the same: `turns = sleepTurns - 1`, then `withSleepTurns`, then test `turns > 0` (`BattleEngine.lua:1220-1238`). No other site decrements sleep (grep: only `:1223-1224`). So 3 gives "fast asleep" on the next two attempts, then wakes and acts on the third, as in source. The Early Bird arithmetic in the known limits (3-2=1 asleep, then 1<2 clears) is also right.
- **Texts:**
  - :133 "went to sleep!", :134 "slept and became healthy!" (`gRestUsedStringIds` :973-977);
  - :124 "regained health!", :125 "HP is full!";
  - :174 "stayed awake using its…" (`gUproarAwakeStringIds` :1003-1007);
  - :86 "already asleep!" with ATK_NAME.

  `STATUS_ABILITY_NAMES` already has 15/72 (`BattleSceneController.lua:198-200`).
- **Event fit.** The existing `restoreHP`/`restoreHPFull` shapes (`BattleEngine.lua:2076-2086`) and their renderers (`BattleSceneController.lua:241-248`) fit unchanged. The party write-back masks the toxic counter (`BattlePartyBridge.lua:193`).

### Focus Energy

- **Crit arithmetic** (`bsc.c:1184-1194`): `2*FE + [43] + [75] + [200] + [209]` (+ items), clamped to index 4 of `{16,8,4,3,2}` (`:588`).
  - FE alone gives 1/4.
  - FE with a +1 move gives 1/3, which is Blaze Kick at stage 3, i.e. `% 3`.
  - Blaze Kick alone gives 1/8.
  - `BattleFormulas.critRoll` clamps at 4 and indexes `[0]=16..[4]=2` (`BattleFormulas.lua:207`, `:533-537`).
- **Script.** `jumpifstatus2` goes to "But it failed!" (`bs1.s:888`, `battle_message.c:336`). Otherwise `setfocusenergy` (`bsc.c:7383-7396`) and "is getting pumped!" (`:153`; table `:1058-1062`).
- **Clearing.** `FaintClearSetData` zeroes status2 (`battle_main.c:2441`). `SwitchInClearSetData` zeroes it (`:2367`) except under Baton Pass (`:2350-2352`). The engine's switch-ins are fresh `makeBattler` objects (`BattlePartyBridge.lua:138`, `:158`), and `recordFaint` is the right faint hook (`BattleEngine.lua:1061-1081`).
- **AI.** `AI_CBM_FocusEnergy` (`battle_ai_scripts.s:131`, `:386-388`) maps to the port's row 47 (`AICheckBadMove.lua:532`). `AICheckBadMove.score` receives engine battlers (`:637-665`), so `user.focusEnergy` is readable. There are no CBM entries for 36/37/77/200.

### Engine fit and call sites

- **Crit sites.** `critRoll` has exactly four callers: `BattleEngine.lua:1690` (Explosion), `:2303` (ordinary), `:2724` (`resolveMultiHit`) and `:2783` (`resolveTripleKick`).
  - Every other source `critcalc` script maps onto the ordinary site or is blocked: Absorb `bs1.s:330`, Earthquake `:1846`, Brick Break `:2419`, Fury Cutter `:1634` (positive-power fallback).
  - The remaining scripts have no engine path: Dream Eater `:440` (rejected), Beat Up `:1947` and Pursuit switch-out `:3085`.
  - H1 therefore covers every site.
  - The Explosion site rolls after `attacker.hp = 0` but before `recordFaint`, so FE is still set, as in source.
- **Other sites.** These are named and correct:
  - `STATUS_HIT_MOVES` (`:744`);
  - the no-effect list (`:2366-2384`);
  - the landed-hit status site (`:2494-2502`);
  - `MULTI_HIT_MOVES` (`:889`);
  - `makeBattler` (`:924-960`);
  - `supportsMove` (`:1134`);
  - the Refresh branch (`:1797`), which runs after `useMove` and the cancellers and before any accuracy roll.
- **Twineedle's KO tail** relies on the caller's faint check. That check exists on every path that calls `resolveMove`: the `runTurn` move loop (`:3141`), and the switch, capture and run branches (`checkFaint(SIDE_PLAYER)`). `resolveTripleKick` already uses the same break-then-caller-faint shape, and tests assert it (`tests/battle_engine_test.lua:2271`, `:2276`).
- **Inventory.** Rows 36/37/47/77/200 are `blocked_on_state` with admitted = true/false/false/true/true (`tests/phase4_move_effect_inventory_test.lua:48,49,59,89,212`). The totals 283/71 (`:230`) become 285/69 as stated.

## Findings

### F1 — Medium: the multi-hit KO divergence is wider than "mid-sequence"

The proposal's Risks section says `resolveMultiHit`, "on a mid-sequence KO", emits `faint` and omits the hit count.

- **It is any KO, including the last hit.** `checkFaint` runs after every landed hit (`BattleEngine.lua:2752-2757`). A Double Kick whose second hit KOs, or a Fury Attack whose rolled final hit KOs, also loses "Hit N time(s)!". In source the loop exits through `decrementmultihit`, then `goto BattleScript_MultiHitPrintStrings` (`bs1.s:640-641`), which prints the count (`:649`) before `tryfaintmon` (`:653`).
- **The existing rationale is also wrong.** The comment at `BattleEngine.lua:2696-2707` and `BattleSceneController.lua:335-341` justifies the omission because the faint "already ends the battle". That is false when `hasReplacement` returns true: the faint leaves a forced switch pending and does not end the battle.
- **A second divergence on these paths.** Families 29/44 also skip the trailing `% 100` draw on the no-effect path (`bs1.s:624` to `:651-652`), not only after landed hits. The 7-draw assertion at `tests/battle_engine_test.lua:993-994` locks in the landed-hit omission.

**Correction.** Reword the Risks bullet to "any KO during the sequence (including the final hit)". State that the follow-up must cover a last-hit KO, a KO with a replacement available, and the 29/44 trailing draw on landed and no-effect paths. Keeping it out of L1 is still right.

### F2 — Low: the Tri Attack status1 guard must test the whole word

The source tests `if (gBattleMons[gEffectBattler].status1)` (`bsc.c:2467`), i.e. the full word including toxic-counter bits.

- The proposal says "status1 == 0", which is right.
- The engine, however, has two predicates. `StatusConditions.hasAny` masks the counter (`StatusConditions.lua:59-62`). `canApply` deliberately tests `status ~= 0` (`:100-102`).

**Correction.** State in L1 that the outer guard is `(defender.status or 0) ~= 0`, and not `hasAny`, so that a counter-only word also skips the `% 3`. The state is believed unreachable, but the predicate should mirror source and `canApply`.

### F3 — Low: Focus Energy has two other setters

The lifecycle section lists only the move as a setter. Source also sets `STATUS2_FOCUS_ENERGY` from:

- the Lansat Berry (`HOLD_EFFECT_CRITICAL_UP`, `battle_util.c:2681-2688`);
- the Dire Hit battle item (`pokemon.c:4090-4092`, `:4611`).

Neither is represented: there are no held items, and the engine has no in-battle item use beyond Poké Ball capture. So the design is unaffected.

**Correction.** Add both to Known limits so a future held-item or bag-in-battle slice knows it must set `focusEnergy`.

### F4 — Low: Blaze Kick's known limits miss Flash Fire

Flash Fire absorbs a Fire move in `attackcanceler` (`bsc.c:925`; `battle_util.c:1918-1924`), before accuracy. Against a Flash Fire target, source therefore draws none of "accuracy, crit, random, `% 100`".

The engine does not model Flash Fire (no reference in `BattleEngine.lua`). This gap already exists for Ember and every other Fire move, so it is not introduced here.

**Correction.** List it next to the contact-ability limit, because the proposal states Blaze Kick's RNG sequence as unconditional.

### F5 — Low: comments and docs that L1/L2 must update

The design names every behavioural site, but not these comments, which become stale:

- The `BattleEngine.lua` header event list (`:60-80`) needs `restSlept` and `focusEnergy`. The header family notes at `:252`, `:363` and `:389` describe the multi-hit and status-hit families.
- `resolveMultiHit`'s doc comment (`:2668-2708`). After L1 it no longer holds for Twineedle (no in-loop `checkFaint`, a trailing roll, `hits` = hits landed).
- The `MULTI_HIT_MOVES` comment (`:875-888`), which documents only 29/44.
- `BattleSceneController.lua:335-341`. Its `multiHit` comment says the event is emitted only on completion, which is false for Twineedle and Triple Kick.
- The `AICheckBadMove.lua:532` comment "status2 unmodeled".

**Correction.** Add these to the L1/L2 touch lists.

### F6 — Info: Twineedle KO tests must go through `runTurn`

The existing multi-hit tests call `battle:resolveMove` directly (`tests/battle_engine_test.lua:1003-1016`). Under the new design the Twineedle faint is emitted by the caller (`runTurn`, `:3141`), not inside `resolveMultiHit`.

**Correction.** The "count 1, the roll, then the faint" oracle must drive `runTurn`, or call `checkFaint` explicitly. Otherwise it will see no `faint` at all. The verification plan's "through the real engine" covers this; make it explicit.

### F7 — Info: "Uproar (159) is blocked" is imprecise

EFFECT_UPROAR is `blocked_on_state` but admitted as a positive-power plain hit (`tests/phase4_move_effect_inventory_test.lua:171`). Move 253 runs today as an ordinary hit that never sets `STATUS2_UPROAR`.

The conclusion still holds: the engine has no uproar state, so `UproarWakeUpCheck` cannot fire and Rest's Uproar branch is unreachable.

**Correction.** Reword to "Uproar state is not represented (effect 159 runs as a plain hit)".

### F8 — Info: citation nits

- The `EFFECT_BLAZE_KICK` term in `Cmd_critcalc` is at `bsc.c:1187`, not `:1186`.
- The Refresh branch starts at `BattleEngine.lua:1797`; `:1798` is its first comment line.

Neither is substantive.

## Disposition

Apply F1-F5 to the proposal text (F1 to Risks; F2 to the Tri Attack design; F3/F4 to Known limits; F5 to the slice touch lists). F6-F8 are optional clarifications. With those edits, L1 and L2 can be cut as designed. No re-review is needed for these wording changes.
