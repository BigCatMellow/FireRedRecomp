# Review: Phase 4 residual and volatile end-of-turn effects design proposal (R1-R3)

- Reviewed: `work/reports/phase4-residual-effects-design-proposal.md` (working tree, 2026-10-15, status `PROPOSAL — awaiting design review`)
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Reviewer role: independent design review (full relay). I edited nothing else and committed nothing.
- Source copies: `/tmp/claude-0/bsc.c`, `/tmp/claude-0/bs1.s`, `/tmp/claude-0/status/{battle_util.c,battle_main.c}` and `/tmp/claude-0/bm.c`. I byte-compared each against the pinned raw file, and all are identical. Note that `/tmp/claude-0/bm.c` is `src/battle_message.c`, not `battle_main.c`. I fetched these from the pin: `src/party_menu.c`, `src/strings.c`, `include/constants/battle.h`, `src/data/battle_moves.h`, `data/battle_ai_scripts.s` and `src/data/pokemon/level_up_learnsets.h`.
- Engine checked at the working tree: `src/core/BattleEngine.lua` (3899 lines), `src/core/BattleSceneController.lua` (747), `main.lua` (5216, read only) and the controller/ROM-seam tests.

Abbreviations follow the proposal: `bsc.c`, `bs1.s`, `bu.c` (battle_util.c), `bm.c` (battle_main.c), `msg.c` (battle_message.c), `pm.c`, `ai.s`, `cb.h`.

## Verdict: **PASS WITH CORRECTIONS**

The source facts hold everywhere I checked, and I checked every claim in the six focus areas. In particular:

- the per-battler case order;
- the missing `checkteamslost` in the Leech Seed drain, and the draw it allows;
- the seeder-slot semantics, and "evaded" for both a miss and an already-seeded target;
- Curse's fail matrix and its "won't" texts;
- Nightmare's lifecycle;
- Rapid Spin's else-if chain;
- every RNG claim;
- every escape-prevention site.

The proposed per-battler order fits the existing W0/W3a structure (`resolveStatusEndTurn`: Rain Dish, then status, then the rampage tick).

Corrections are required in two areas, and none of them changes a source fact:

1. **The D2 deferred team check needs two implementation corrections** (F1, F2). As written, a battle decided by a non-fatal tick would keep running that battler's later cases after `battleEnd`. The separate `deferredFaints` list would also collide with `faintSequence`'s asserts, or emit duplicate `faint` events.
2. **R2 does not need `main.lua`** (F4). The same protection can live entirely in the controller (and the engine). The proposed `main.lua:1653` guard should be dropped from R2.

## Source checks performed (all confirmed unless a finding says otherwise)

| Area | Checked | Result |
| --- | --- | --- |
| Per-battler order | `bu.c:720-742`, `:743-1060` | Confirmed: Ingrain, Abilities, Items1, Leech Seed, Poison, Toxic, Burn, Nightmare, Curse, Wrap, Uproar, Thrash, ... One battler's whole list runs before the next (`turnEffectsTracker` and `turnEffectsBattlerId`). Absent battlers are skipped (`:751-754`). Every case the proposal models tests the battler's own `hp != 0`, except Uproar and Thrash. The engine's faint already clears the rampage, so the missing test is harmless there. |
| Phase re-entry | `bm.c:2953-2965` | Confirmed. Only a set `gBattleOutcome` skips the rest of `DoBattlerEndTurnEffects`. `HandleFaintedMonActions` runs afterwards either way. |
| Drain script | `bs1.s:3223-3243` | Confirmed: seeded HP update; `copyword gBattleMoveDamage, gHpDealt`; Liquid Ooze (seeded battler's ability) → damage, otherwise `manipulatedamage 0` → heal; receiver HP update; text after both; `tryfaintmon` attacker then target; **no `checkteamslost`**. Receiver `hp != 0` gate at `bu.c:790-792`. |
| `DoTurnDmg` | `bs1.s:3676-3688`, `:3769-3801` | Confirmed: `tryfaintmon` then `checkteamslost` on every poison/toxic/burn/nightmare/curse/wrap-damage tick. `WrapEnds` (`:3775-3778`), `IngrainTurnHeal` (`:3553-3560`) and Rain Dish (`:3938-3944`) have no team check. |
| Team check | `bsc.c:3385-3420`, `:2831-2905`; `cb.h:76-78` | Confirmed. LOST and WON are ORed independently from whole-party HP (both together = DREW 3). `tryfaintmon` never sets the outcome. |
| `setseeded` | `bsc.c:6436-6456`; `bs1.s:1153-1166`; `cb.h:203` | Confirmed. `MOVE_RESULT_NO_EFFECT` (which includes MISSED) **or** already seeded → `LEECH_SEED_MISS`. Then Grass in either slot → `FAIL`. Otherwise OR the attacker slot into bits 0-1. The accuracy miss pointer is `BattleScript_DoLeechSeed`, and a semi-invulnerable target reaches it with no draw (`bsc.c:966-990`). There is no `typecalc`. |
| Leech Seed texts | `msg.c:70`, `:159-161`, `:290`, `:964-971` | Confirmed. "evaded" names `B_DEF`. The drain text names `B_ATK` = the seeded battler. |
| Clearing | `bm.c:2329-2431` (`:2338-2342`, `:2350-2353`, `:2365-2368`, `:2371-2377`), `:2433-2452`; `bsc.c:2925-2938` | Confirmed. Nothing clears another battler's `LEECHSEED`. Baton Pass keeps `ESCAPE_PREVENTION`, `CURSED`, the seed (with its slot bits) and `ROOTED`. |
| Nightmare | `bs1.s:1455-1469`; `bsc.c:2678-2681`; `bu.c:841-860`, `:1272`, `:1300` | Confirmed. There is no accuracy check and no type check. The fail order is Substitute, already nightmared, not asleep. At end of turn: asleep → ¼ damage, otherwise the flag clears silently. The wake-up in the canceller clears it. Other clears (berries `bu.c:2761-2941`, Poké Flute `bsc.c:6165`, Heal Bell, Shed Skin) are not modeled. |
| Curse | `bs1.s:1478-1523`; `bsc.c:6655-6824`, `:8093-8108`, `:1020-1028`; `moves.h:2265-2276` | Confirmed. The Ghost test (type1 or type2) comes before `attackcanceler`. It fails only at −6/+6/+6. `ALLOW_PTR` returns WORKED at a limit and prints "won't go lower/higher". Mist, Protect and Clear Body exempt `MOVE_CURSE`. Ghost path: `NO_ACC_CALC_CHECK_LOCK_ON` sends a semi-invulnerable target to `ButItFailed`; an already-cursed target fails; the cost is `max(1, maxHP/2)` clamped by `datahpupdate`; HP, then text, then `tryfaintmon BS_ATTACKER`. |
| Ingrain | `bs1.s:2372-2380`; `bsc.c:8933-8944`; `bu.c:760-773` | Confirmed. |
| Mean Look | `bs1.s:1440-1453`; `bsc.c:2673-2677` | Confirmed. |
| Trap | `bs1.s:829-835`, `:239-270`; `bsc.c:2132-2146`, `:2483-2506`, `:2774-2805`; `cb.h:234`; `msg.c:143-149`, `:1042-1050` | Confirmed. `Random() % 100` is drawn on a landed hit and on a no-effect hit, but not on a miss. The 0-HP and already-wrapped guards stop the `& 3` draw. The counter is `(Random() & 3) + 3`. Whirlpool sets `IGNORE_UNDERWATER` and ×2 only against `UNDERWATER`. |
| Wrap tick | `bu.c:872-903` | Confirmed. A counter of 3-6 gives 2-5 damage ticks, then one release turn. |
| Rapid Spin | `bs1.s:1711-1713`, `:3441-3454`; `bsc.c:8435-8469`, `:2788-2792` | Confirmed. It is an else-if chain, so one cleanup per use. Against a Ghost, `CERTAIN && !NO_EFFECT` fails, so the `else if` draws `Random() % 100`. A landed hit draws nothing. The cleanup runs before `tryfaintmon BS_TARGET`. |
| RUN veto | `bm.c:3239-3253`, `:3002-3058`, `:4229-4280`, `:4309-4324`; `bs1.s:3038-3040`; `msg.c:333`, `:903-910` | Confirmed. Trainer check first, then the selection script "Can't escape!" with no turn, no draw and no `runTries`. Run Away returns SUCCESS early. `TryRunFromBattle`'s Run Away branch has no draw and no `runTries++` (`:4246-4251`, `:4272`). |
| Switch veto | `bm.c:3196-3200`; `pm.c:5916-5968` (`:5960-5966`); `strings.c:256`; `bsc.c:4536-4548` | Confirmed. The menu opens with `PARTY_ACTION_CANT_SWITCH`, and choosing a mon prints "{STR_VAR_1} can't be switched\nout!" (active mon's nickname) with the player staying in the menu. There is no Run Away bypass. |
| AI | `ai.s` `AI_CBM_LeechSeed`, `_Nightmare`, `_Curse`, `_CantEscape`, `_Ingrain` | Confirmed as tabulated. |
| Reachability | pinned `level_up_learnsets.h` | Confirmed: Bulbasaur Leech Seed at 7; Ekans and Dratini Wrap at 1 (first move); Onix Bind at 8; Gastly Curse at 13 (Mean Look at 48); Tangela Ingrain at 1; Staryu Rapid Spin at 10. Wild foe picks the first damaging slot (`main.lua:1301-1306`), so a wild Ekans uses Wrap every turn. |
| Engine fit | `BattleEngine.lua:1239-1311`, `:2175-2250`, `:2723-2750`, `:2814-2957`, `:3286-3292`, `:3477-3639`, `:3653-3815`; `BattleSceneController.lua:583-747`; `main.lua:1637-1697` | Line citations accurate. Insertion points are correct. |
| Inventory | `phase4-move-effect-inventory.md:148`, `:190`, `:212`, `:213`, `:215`, `:235`, `:287` | Rows exist as cited. The record counts per slice (3, 4, 6) are consistent. |

## Findings

### F1 — Moderate (D2): a battle decided by a non-fatal tick must stop the rest of that battler's list

- **Source.** With D2, a `checkteamslost` after a **non-fatal** tick can end the battle when a deferred Leech Seed KO is pending (`bs1.s:3681-3686`). `BattleTurnPassed` then skips the rest of `DoBattlerEndTurnEffects` (`bm.c:2958-2962`). That includes the **same** battler's remaining cases: Nightmare, Curse, Wrap and Thrash.
- **Engine.** `resolveStatusEndTurn` tests `isOver()` only at the top of each side (`BattleEngine.lua:3584`). Today this is safe, because only a fatal tick can decide the battle, and the fainted battler's later work is already cleared by `recordFaint`.
- **The new failure.** Under D2, the surviving battler would go on to:
  - tick Nightmare and Curse after `battleEnd`;
  - run its rampage tick (`:3621-3637`), which can emit `fatigueConfusion` after `battleEnd`.
- The proposal's verification plan expects "a later Curse tick on the player does not run", but the step list never adds the guard.
- **Required.** After **every** `endTurnTeamCheck`, stop the phase if `isOver()`: `break` out of the side loop, then skip the remaining steps. Add a test where the player survives its poison tick and has Curse and a rampage pending.

### F2 — Moderate (D2): implement the deferral with the existing `faintSequence`, and record only the ticking battler

The proposal adds a separate `self.deferredFaints` list. `recordFaintDeferred` "runs the existing `recordFaint` clearing and emits `faint`", and `endTurnTeamCheck` then "records the deferred sides plus any battler this tick left at 0 HP". This conflicts with the current primitives:

- `recordFaint` asserts that a sequence is open (`BattleEngine.lua:1243`), and `beginFaintSequence` asserts that none is (`:1236`).
- Its duplicate check covers only the current sequence (`:1255-1257`). Re-recording a deferred side in a later sequence emits a **second** `faint` event, and a second "fainted!" text.
- "Any battler … at 0 HP" also catches a battler that fainted **mid-turn** and is still waiting for its replacement (Risk R2). That battler's sequence was already finalized, so it would print "fainted!" twice.
- If poison, toxic or burn keep their `checkFaint` (`:3617`) while a deferred faint is pending, `beginFaintSequence` trips its assert.

**Recommended shape.** No new list is needed:

1. **Leech Seed KO.** Open `faintSequence` if none is open, then call `recordFaint(seeded)`, and for an ooze KO also `recordFaint(receiver)`. Do not finalize.
2. **Each `DoTurnDmg`-shaped tick** (poison, toxic, burn, Nightmare, Curse, and in R3 wrap damage): if the ticking battler is at 0 HP **or** a sequence is open:
   - open the sequence if needed;
   - call `recordFaint(tickingSide)`, which is a no-op while that battler's HP is above 0;
   - call `finalizeFaintSequence`.

   This replaces the `checkFaint` call inside `resolveStatusEndTurn`.
3. **After the loop**, stand in for `HandleFaintedMonActions`: if a sequence is still open, finalize it. Every early exit from the loop must reach this step, so use `break`, never `return`.

`resolveWeatherEndTurn`'s `checkFaint` (`:3554`) is safe, because the field cases run before any Leech Seed. Add tests for:

- the deferred-KO-then-non-fatal-tick case: exactly one `faint` event per side;
- a mid-turn foe faint followed by a player poison tick: no second foe `faint`.

### F3 — Low: the Curse accuracy predicate must depend on the attacker's type, not only on effect 109

- The non-Ghost path has **no** `accuracycheck` at all (`bs1.s:1478-1485`).
- The Ghost path has `NO_ACC_CALC_CHECK_LOCK_ON`, which fails a semi-invulnerable target (`bsc.c:1020-1025`).
- In the engine, the `:2239` "But it failed!" branch is reached only through `scriptHasAccuracyCheck` and `semiInvulnerableMiss` (`BattleEngine.lua:2203-2208`).
- If Curse is added to that predicate by effect id, a non-Ghost Curse used against a foe in mid-Fly or mid-Dig fails wrongly. Source plays it, because its stat changes target the user.

Spec, for every effect in R1/R2:

| Move | `needsAccuracyCheck` | `scriptHasAccuracyCheck` | Notes |
| --- | --- | --- | --- |
| Ghost Curse | no | yes | |
| Mean Look / Spider Web / Block | no | yes | Their effect ids are in neither `HITS_AIR` nor `HITS_UNDERGROUND`, so `semiInvulnerableMiss` already gives the source answer. |
| Non-Ghost Curse | no | no | |
| Nightmare | no | no | |
| Ingrain | no | no | |

### F4 — Moderate (scope/ownership): R2 can and should be done without editing `main.lua`

**Why the proposed guard exists.** `main.lua:1653-1697` mutates party state before it calls `controller:_runTurn({action="switch"})` (`:1690`): it persists the outgoing battler, sets `activePartySlot`/`partyRecord`/`playerName` and rebuilds the sprite (`:1675-1689`). So a veto inside `_runTurn` or `runTurn` comes too late, and the veto must happen **before main's callback runs**. The proposal's reason for a `main.lua` guard is "any caller that bypasses the controller veto (the trainer test seam)".

**Who can reach the callback today:**

- `main.lua` passes `onVoluntarySwitchChoice` as an anonymous closure in the `Controller.new` opts table (`main.lua:1653`), so it holds no other reference. The controller stores it as `self.onVoluntarySwitchChoice` (`BattleSceneController.lua:98`) and invokes it only from the PARTY A-press (`:714-725`).
- The trainer test seam (`configureTrainerBattleTest`, `main.lua:5206-5215`) does not call the callback. `tests/phase4_player_voluntary_switch_rom_test.lua:26-34` drives it through `controller:processInput`.
- The only direct field call in the tree is `tests/phase4_player_voluntary_switch_controller_test.lua:67`, and that targets the test's own stub.
- `runBattle()` (`main.lua:3882-3901`) also goes through `processInput`.

So every live path passes through the controller.

**Recommended R2 structure.** No `main.lua` edit:

1. **Engine** (this lane). `runBlocked(side)` / `switchBlocked(side)` as proposed, plus `runTurn` asserts at the top of the run and switch branches. These are the last line of defence and are never reached through the controller.
2. **Controller, RUN.** In `_runTurn`, after the `runDisabledMessage` test: if the action is `run` and `self.engine.runBlocked and self.engine:runBlocked("player")`, show `{ "Can't escape!" }` and return to ACTION. There is no turn, no RNG and no `runTries` change.
3. **Controller, PARTY.** In the A-press, voluntary mode only, before invoking the callback: if `self.engine.switchBlocked and self.engine:switchBlocked("player")`, show `"<playerName> can't be switched\nout!"` with after-state `PARTY`. Keep `partyMode = "voluntary"` so that B still cancels, as in `pm.c:5960-5966`. `voluntarySwitchChoices` still lists the bench, because source opens the menu anyway (`bm.c:3198-3200`).
4. **Controller, defence in depth** (this replaces the `main.lua` guard). In `Controller.new`, store the voluntary callback wrapped:

   ```lua
   local onVoluntary = opts.onVoluntarySwitchChoice
   self.onVoluntarySwitchChoice = onVoluntary and function(choice)
     if self.engine.switchBlocked and self.engine:switchBlocked("player") then return nil end
     return onVoluntary(choice)
   end
   ```

   Because the controller field is the only route to main's closure, this guards every caller, including a direct `controller.onVoluntarySwitchChoice(...)`. Main's party mutation then cannot run while the player is trapped. Do not wrap the forced callback: a forced replacement is never blocked.

**What changes in `main.lua`:** nothing. `main.lua` would have to change only if it later gains a second path that mutates party state and then calls `_runTurn({action="switch"})` outside this callback. None exists.

**Optional hand-off note for the `main.lua` owner** (non-blocking hardening, not a prerequisite for R2):

> "R2 (residual effects) adds `BattleEngine:switchBlocked(side)`. `BattleSceneController` already refuses a voluntary switch while the player is trapped, and wraps `onVoluntarySwitchChoice` with the same check. If you want belt-and-braces, add `if engine.switchBlocked and engine:switchBlocked("player") then return nil end` beside the `awaitingForcedSwitch` guard at the top of `onVoluntarySwitchChoice` (`main.lua:1657`), before `persistPartyBattler`. No behaviour changes for any reachable path."

**Edits to the proposal.** Remove the `main.lua` guard from:

- the Summary (R2 bullet);
- the "Lane" line;
- the R2 Design section ("`main.lua` change (explicit, one guard)");
- the Slices table (R2 row);
- the R2 verification bullet ("party state unchanged (the `main.lua` guard)" becomes "(the controller veto and callback wrapper)");
- D3;
- Risk R5.

**Lane.** R2 stays full relay, because it adds new cross-turn battle state (`AGENTS.md`, "Use the full relay instead when…").

### F5 — Low: the controller checks must tolerate stub engines

The existing controller tests build stub engines without the new methods:

- `tests/phase4_player_voluntary_switch_controller_test.lua:16-24`;
- `tests/phase4_player_forced_replacement_controller_test.lua`;
- `tests/phase4_foe_only_multimon_controller_test.lua`.

The proposal's unguarded `engine:runBlocked("player")` and `engine:switchBlocked("player")` would raise errors in the voluntary PARTY A-press test. Use the existing nil-safe idiom, as `_runTurn` already does for `self.engine.isLocked` (`BattleSceneController.lua:603`). The F4 snippets already do this.

### F6 — Low: ownership statement for the controller

The proposal says the controller is "owned by the controller agent" (Design R2; Events table; Risk R5). Earlier Phase 4 effect tasks put `src/core/BattleSceneController.lua` in their MAY CHANGE list (for example `work/tasks/phase4-confusion-flinch-c2.md:29`). The R1-R3 task files should state this explicitly:

- **MAY CHANGE:** `BattleSceneController.lua` (texts, RUN/PARTY vetoes, callback wrapper);
- **MUST NOT CHANGE:** `main.lua`.

If the controller really belongs to another lane now, R2 needs that owner's sign-off on F4 items 2-4, and nothing else.

### F7 — Low: Curse's capped-stat events need signed `stages`

- The controller picks "won't go higher!" only when `event.stages > 0` (`BattleSceneController.lua:329`).
- The existing stat-move and hit-variant paths emit prevented changes with `stages = 0` (`BattleEngine.lua:2524`, `:2936`), which always prints "won't go lower!".
- Curse's prevented events must therefore carry `stages = -1` (Speed) and `stages = +1` (Attack and Defense). Otherwise the −6/+6/+5 case prints "ATTACK won't go lower!".
- **Observed, out of scope:** the same `stages = 0` shape makes a self-target UP move at +6 (for example Swords Dance) print "won't go lower!". Source prints "won't go higher!" through `ALLOW_PTR`, `bsc.c:6799-6810`. Suggest a separate ticket.

### F8 — Info: smaller notes

1. **Run Away flee text (D4).** It is sourced as `sText_PkmnFledUsing`, "{B_ATK_NAME_WITH_PREFIX} fled\nusing {B_ATK_ABILITY}!\p" (`msg.c:322`). `HandleEndTurn_RanFromBattle` selects it for `fleeType == FLEE_ABILITY` (`bm.c:3798-3812`, `:4246-4251`). The `run` event needs a flag for it.
2. **Teleport** (effect 153, inventory row `:259`, currently `B`) uses `getifcantrunfrombattle` (`bs1.s:1921-1928`). When it is admitted, it should reuse `runBlocked`. The single-query rationale in the proposal already covers this; consider naming it in the Deferred table.
3. **CANT_SWITCH checks.** In this mode, source tests fainted, already-in-battle and Egg before the trap text (`pm.c:5928-5966`). The controller lists only legal choices, so every listed entry gets the trap text, which matches source.
4. **`MOVE_RESULT_MISSED` side effect.** `ChangeStatBuffs` sets `MOVE_RESULT_MISSED` when Curse's Attack or Defense is at +6 (`bsc.c:6810-6811`). Nothing the engine models observes it.
5. **Exp timing.** `HandleFaintedMonActions` gives exp (`bu.c:1162-1172`) before `BattleScript_HandleFaintedMon`'s team check. Any exp-text timing the presentation uses is pre-existing and not changed by D2.
6. **Citation nit.** `HandleFaintedMonActions` begins at `bu.c:1143`. The proposal cites `:1144`.

## Decisions

| # | Recommendation |
| --- | --- |
| D1 | **Accept.** Ingrain goes to R2. `STATUS3_ROOTED` is part of every veto (`bm.c:3047-3048`, `:3198`; `bsc.c:4543-4545`). Split Rapid Spin: seed arm in R1, wrap arm in R3. The R1 chain is trivially correct while effect 42 sets no wrap. |
| D2 | **Accept with F1 and F2.** The source behaviour is real: it decides win versus draw and whether later ticks print. It is cheap when built on `faintSequence`. `main.lua` already handles `playerDrew` (`main.lua:4316`, `:4352`, `:4416`), so D2 needs no `main.lua` work. |
| D3 | **Accept, amended by F4.** Engine queries and `runTurn` asserts; RUN and PARTY vetoes in the controller; the callback wrapper in `Controller.new` instead of the `main.lua` guard. `main.lua` is not edited. The hand-off note is optional. |
| D4 | **Accept.** Make it a separate commit in R2: Run Away gives a no-draw, no-`runTries` escape (`bm.c:4246-4251`) with the `msg.c:322` text. Without it, a trapped Run Away holder passes the veto and then takes the ordinary speed roll, which is a hybrid of two behaviours and matches neither. |
| D5 | **Accept** as a separate follow-up. It needs the same ability constant (64) and text (`msg.c:290`). |
| D6 | **Accept, keep it in R3.** It is two lines. Reachability is low (Dive only in two trainer movesets, Whirlpool in no FRLG learnset or trainer moveset). Pin it with a test. |

## Required before implementation

1. Fold F1 and F2 into the R1 task's D2 design and its tests.
2. Fold F3 and F7 into R1's accuracy and Curse specification.
3. Rewrite R2 per F4 and F5: no `main.lua` edit; controller veto plus callback wrapper. Record the controller's MAY CHANGE status and `main.lua`'s MUST NOT CHANGE status in the task file (F6).
