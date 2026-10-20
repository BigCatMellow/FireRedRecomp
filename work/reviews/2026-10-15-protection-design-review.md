# Review: Phase 4 protection design proposal (P1-P5)

- Reviewed: `work/reports/phase4-protection-design-proposal.md` (status `PROPOSAL — awaiting design review`)
- Date: 2026-10-15
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`. Pinned files were fetched from raw.githubusercontent.com. The local `/tmp/claude-0` copies of `bsc.c`, `bs1.s`, `bm.c` (which is battle_message.c) and `bmain.c` are byte-identical to them. A sparse checkout of the pin was used for repository-wide greps.
- Engine: `src/core/BattleEngine.lua`, `AICheckBadMove.lua`, `TrainerAI.lua`, `BattleSceneController.lua` and `main.lua` in the working tree. Nothing was edited except this file.
- Abbreviations follow the proposal: `bsc.c` = `src/battle_script_commands.c`, `bs1.s` = `data/battle_scripts_1.s`, `bm.c` = `src/battle_main.c`, `msg.c` = `src/battle_message.c`, `bu.c` = `src/battle_util.c`.

## Verdict: **PASS WITH CORRECTIONS**

The proposal is well grounded. Most of its source claims check out exactly at the pin. That includes the attackcanceler / accuracycheck re-test, the resultmessage priority, the Protect counter and its single draw, the lifetimes, the run latch, the Endure adjust sites, the Fake Out flinch and discarded draw, the Focus Punch hook and damage record, and the AI rows.

Three medium findings must be fixed in the task files before P1 and P3 are implemented:

- F1: the Thunder Wave gate order.
- F2: what a Jump Kick crash does against a protected Ghost.
- F3: how False Swipe and Endure interact in the engine design.

None of them changes the slice structure, and none needs a `main.lua` change.

## Findings

### F1 (MEDIUM): EFFECT_PARALYZE (67): when the target is protected, "already paralyzed" and "has any status" are unreachable

`BattleScript_EffectParalyze` (`bs1.s:1005-1022`) runs these steps in order:

1. the Limber gate;
2. the Substitute gate;
3. `typecalc`;
4. **`jumpifmovehadnoeffect BattleScript_ButItFailed`** (`:1011-1012`);
5. only then the already-paralyzed and `STATUS1_ANY` gates.

`jumpifmovehadnoeffect` tests `MOVE_RESULT_NO_EFFECT`, which includes `MISSED` (`asm/macros/battle_script.inc:1370-1372`; `include/constants/battle.h:203`). The attackcanceler has already set `MISSED` on a protected target. So every protected Thunder Wave, Stun Spore or Glare jumps to `ButItFailed` at step 4:

- If typecalc found an immunity (a Ground target), `DOESNT_AFFECT` is set and "It doesn't affect" prints.
- Otherwise "Foe Y protected itself!" prints, **even when the target is already paralyzed**.

Two parts of the proposal are wrong for effect 67:

- Shape B (§4) lists "already … paralyzed" among the gate texts that keep priority.
- The P1 row for `resolvePrimaryStatusMove` ("`already` … stay") has the same error.

Fix: in the paralysis arm (`BattleEngine.lua:1721-1726`), when `protectedMove` is set, apply Limber, then the typecalc immunity check (`notAffected`), then emit `protected`. Skip `already()` and `failed()`. Add a test: protect plus an already-paralyzed target gives `protected`. Sleep, poison, Toxic and Will-O-Wisp have no such gate, so the proposal is correct for them (`bs1.s:287-300`, `:687-700`, `:984-1003`, `:2170-2185`).

### F2 (MEDIUM): Jump Kick into a protected Ghost prints the crash text but does not lose HP

The proposal (§4 shape D row 45, the verification plan, and surprising-behaviour item 7) claims "then a 1-HP crash". The source does something else.

`BattleScript_MoveMissedDoDamage` (`bs1.s:853-870`):

1. prints the protected text;
2. passes the `DOESNT_AFFECT` test, as the proposal says;
3. prints "kept going and crashed!";
4. runs `damagecalc`, then **`typecalc`**. Against a Ghost, `ModulateDmgByType(TYPE_MUL_NO_EFFECT)` sets `MOVE_RESULT_DOESNT_AFFECT_FOE` (`bsc.c:1246-1250`, called from `Cmd_typecalc` `:1312-1318`);
5. runs `adjustnormaldamage`, which takes its random draw (`ApplyRandomDmgMultiplier` draws before its zero test, `bsc.c:1558-1569`);
6. runs `manipulatedamage DMG_RECOIL_FROM_MISS` (0 becomes 1);
7. runs `bicbyte gMoveResultFlags, MOVE_RESULT_MISSED`, which clears **only MISSED** (`:865`);
8. runs `healthbarupdate BS_ATTACKER` and `datahpupdate BS_ATTACKER`. Both are gated on `!(gMoveResultFlags & MOVE_RESULT_NO_EFFECT)` (`bsc.c:1713`, `:1759`), so both are skipped.

The visible result is "used HI JUMP KICK!", then "Foe Y protected itself!", then "X kept going and crashed!", **with no HP change**. One random draw is taken.

The existing engine semi-invulnerable crash leaf (`BattleEngine.lua:2556-2580`) applies the 1-HP loss for an immune target. That is a pre-existing divergence with the same root cause (reachable only against a Ghost in a semi-invulnerable turn). P1 must not copy it into the protected path. Record the existing leaf as a separate follow-up; it is out of P1's scope unless the Orchestrator widens it.

Fix the shape-D row, the miss-branch item (b), verification "Jump Kick into a protected Ghost", and surprising-behaviour item 7. A non-immune protected target still crashes normally.

### F3 (MEDIUM): as designed, False Swipe plus Endure would not print ENDURED

The engine clamps False Swipe **before** `applyDamage` (`BattleEngine.lua:3072-3074`: `damage >= hp` gives `damage = hp - 1`). P3 adds the Endure test inside `applyDamage` as `defender.hp <= damage`. After the False Swipe clamp that test is `hp <= hp - 1`, which is false. No `endured` flag is set, and the proposal's own test ("False Swipe + Endure prints ENDURED") would fail.

Source evaluates a single condition against the unclamped damage (`bsc.c:1600-1610`): `(FALSE_SWIPE || endured || focusBanded) && hp <= damage`, then `FOE_ENDURED` if `endured`.

Fix: route the False Swipe clamp through the same adjust helper, for example `applyDamage(..., {falseSwipe = true})` or one `adjustDamage` helper. Evaluate `(falseSwipe or endured) and hp <= rawDamage` once, and set `endured` from the defender's flag. This is also where a later Focus Band would hook in. The `noAdjust` opt-out for Super Fang is unchanged.

### F4 (LOW): `moveObeyed` must be set before the charge block

§1 says correctly that a charging turn 1 passes attackcanceler and records `gCurrentMove`. P2 places `moveObeyed = true` "at the attackcanceler step". P1 places that step **after** the charge block, and the charge turn-1 arm returns early (`BattleEngine.lua:2019-2043`). The task file should name the position exactly: after the cancellers and the locked 0-PP check (`:2005-2017`), before `chargeKind`.

Today this is unobservable, because any value that is not Protect, Detect or Endure resets the chain. It matters for any later consumer of `lastResultingMove`.

### F5 (LOW): a protected Triple Kick still draws `Random()` in source

The protected path goes `TripleKickNoMoreHits` → `PrintStrings` → `TripleKickEnd`, then `seteffectwithchance` (`bs1.s:1429-1430`). Its `Random() % 100` is evaluated whenever the effect is not `CERTAIN` (`bsc.c:2783-2797`).

The engine already omits this draw under the tracked trailing-roll gap (inventory row 104). The P1 verification line "no RNG consumed" and the RNG note "loses every draw from its accuracycheck onward" should name Triple Kick as covered by that gap, not state it as a source fact. Multi-hit (29/44/77) has no such draw on the protected path, because `PrintMoveMissed` bypasses `MultiHitEnd`.

### F6 (LOW): ENDURED placement for Triple Kick

The engine prints effectiveness on every kick's `damage` event (inventory row 104). In source, `resultmessage` runs once at `TripleKickPrintStrings`: ENDURED first, then the last kick's effectiveness. If the flag goes on `multiHit`, as D7 proposes, "super effective" from the endured kick's damage event prints **before** ENDURED.

Fix: for Triple Kick, put `endured` on the endured kick's `damage` event (ENDURED before its effectiveness), or explicitly accept the existing per-kick divergence. The 29/44/77 `multiHit` placement is correct (`bs1.s:639`, `:645-650`).

### F7 (LOW, wording): which operand holds `Random()`

The proposal says "`Random()` is the left operand" (`bsc.c:6231`). Strictly, `Random()` is the right operand of `>=`. The whole comparison is the left operand of `&&`, so it always runs. The behaviour claim is correct: exactly one draw, including the last-mover failure.

### F8 (INFO): `HITMARKER_RUN` can also come from the foe

The latch is set for **any** battler whose chosen action reaches `B_ACTION_RUN` at `CASE_CHOSEN` (`bm.c:3326-3328`). The AI's `AI_CHOICE_FLEE` emits `B_ACTION_RUN` for the opponent (`src/battle_controller_opponent.c:1355-1367`, roamer and Safari AI). The engine has no roamers, so player-only latching is correct today. Note this where roamers will be added.

Repository-wide grep at the pin confirms the only writes are `gHitMarker = 0` (`bm.c:2257`) and the two `|=` sites. No mask clears bit 15.

### F9 (INFO): D1's `error()` would crash in live play

A player can spam Protect, and Lorelei's or Berke's Cloyster can be chosen repeatedly while CheckViability is out of scope. A fifth use after four successes (1/64 of the chains that get there) would make `error()` a crash in a real battle, not only a test failure. See the D1 recommendation.

### F10 (INFO): reachability note

"Wild foes never choose these moves" holds for the engine's first-damaging-slot rule only (`main.lua:1300-1308`). Source wild foes pick `Random() & 3` (`battle_controller_opponent.c:1383-1388`). That divergence already exists and is not this proposal's to fix, but the sentence should say "in the engine".

## Verified as stated (spot checks, with citations)

**Protect check**

- `DEFENDER_IS_PROTECTED` is at `bsc.c:42`.
- The attackcanceler clause is at `bsc.c:896-905`. Curse has `flags = 0` (`battle_moves.h` Curse record), so the Curse clause is dead.
- The `IsTwoTurnsMove` set is at `bsc.c:7821-7832`.
- `CancelMultiTurnMoves` (`bu.c:203-214`) does not touch `RECHARGE`.
- In `ACC_CURR_MOVE`, `JumpIfMoveAffectedByProtect` runs before `AccuracyCalcHelper` (`bsc.c:1040-1043`): no draw, and no `CheckWonderGuardAndLevitate`.
- In `NO_ACC_CALC`, Lock-On is tested first, then semi-invulnerable, then protect (`bsc.c:1020-1027`).
- `Cmd_jumpifaffectedbyprotect` is unused in `bs1.s`.

**Text priority**

- The resultmessage priority is at `bsc.c:1937`, with `B_MSG_PROTECTED` = 1 and `AVOIDED_ATK` = 2 (`bsid.h:416-417`).
- The protected and protected-2 strings are different (`msg.c:66`, `:155`).

**Families (more than 10 in depth)**

- Shape A hit path: `bs1.s:244-285`.
- Multi-hit: no count draw (`bs1.s:605-611`).
- Rampage: PP on a locked protected turn comes from `PrintMoveMissed` (`bs1.s:585-593`, `:276-278`).
- Charge turn 2 sets `NO_PPDEDUCT` (`bs1.s:784-792`, `:1997-2008`). Solar Beam in sun spends its PP before attackcanceler (`:1909-1914`).
- Shape B: the sleep, poison, Toxic, confuse, Will-O-Wisp, Tickle and Teeter Dance gates (`bs1.s:287-300`, `:687-700`, `:902-917`, `:984-1003`, `:2170-2185`, `:2566-2618`, `:2644-2677`).
- Shape C: OHKO, Pain Split and Mean Look (`bs1.s:761-775`, `:1235-1245`, `:1440-1453`).
- Shape D:
  - Leech Seed: `setseeded` tests `NO_EFFECT` first, so the result is "evaded" (`bsc.c:6436-6456`; `msg.c:967`).
  - Nightmare: no accuracycheck; `seteffectprimary` ignores `MISSED` (`bs1.s:1455-1469`; `bsc.c:2678-2681`).
  - Memento: the `MISS_TYPE` jump, and `trymemento` cannot fail while protected (`bs1.s:2199-2201`, `:2234-2244`; `bsc.c:8681-8696`).
  - Explosion: `movevaluescleanup` and the draws come before accuracycheck (`bs1.s:376-417`).
  - Earthquake and Magnitude: typecalc runs in the miss path (`bs1.s:1830-1875`).
  - Endeavor (`bs1.s:2474-2485`) and Snore (`:1253-1268`).
  - Brick Break: accuracycheck comes before `removelightscreenreflect` (`bs1.s:2413-2418`).
  - Swagger and Flatter (`bs1.s:1604-1608`, `:2147-2151`).
- Shape E: Haze and Hail target the user. `HandleAction_UseMove` keeps the controller's target in singles (`bm.c:4114-4116`), and `GetMoveTarget(USER)` returns the attacker (`bu.c:3119-3122`). Psych Up's flags are `SNATCH` only.

**Protect counter**

- The rate table is at `bsc.c:701`, followed in source order by `sMovesForbiddenToCopy` (`:707-716`).
- `protectUses` is a `u8` with no cap (`battle.h:144`).
- The reset and success paths are at `bsc.c:6220-6251`. The success probabilities are (rate+1)/65536.
- The last-move update is at `bsc.c:4235-4262`. `HITMARKER_OBEYS` is set after the cancellers and the no-PP check (`bsc.c:829-864`) and cleared after each action (`bm.c:4444-4462`).
- Item, run and switch actions never reach moveend, so the chain survives them.
- It resets on switch-in, faint and battle start (`bm.c:2224-2233`, `:2383-2400`, `:2458-2486`).

**Endure**

- Clamp sites: `bsc.c:1600-1610`, `:1641-1652` and `:5623-5633`; `tryKO` at `:7158-7163`.
- Super Fang has no adjust step and does max(1, hp/2) (`bs1.s:808-816`; `bsc.c:7191-7197`).
- The multi-hit and Triple Kick ENDURED exits are at `bs1.s:639` and `:1415`.
- The `EnduredMsg` re-entry is at `bsc.c:1986-1992`.

**Fake Out**

- The move record is at `battle_moves.h:3279-3290` and the script at `bs1.s:2044-2059`.
- `jumpifnotfirstturn` is at `bsc.c:6504-6512`.
- `seteffectwithchance`: `CERTAIN` means no draw, and a no-effect hit draws (`bsc.c:2783-2797`).
- `SetMoveEffect` guard order: Shield Dust (byte 8 ≤ 9), then 0 HP, then Substitute (`bsc.c:2132-2146`).
- Inner Focus with `certain` goes to `FlinchPrevention`, which does `goto MoveEnd` (`bsc.c:2419-2439`; `bs1.s:4109-4113`; `msg.c:296`).
- Re-entering attackcanceler is harmless: the tracker is reset only in `HandleAction_UseMove` (`bm.c:3976`).

**`isFirstTurn` timeline**

- It is set to 2 at battle start, switch-in and faint (`bm.c:2228`, `:2396`, `:2481`).
- It is decremented in `TurnValuesCleanUp(FALSE)` (`bm.c:3640-3641`), once before turn 1 (`:2909`) and after `HandleFaintedMonActions` at the end of every turn (`:2965-2970`).
- `is_first_turn_for` returns the raw value (`aisc.c:1778-1790`).
- `AI_CBM_FakeOut` is at `ai.s:187` and `:510-513`.
- **AICheckBadMove errors on Fake Out today**: `UNPORTED_EFFECTS[158]` (`AICheckBadMove.lua:676`) and the `error()` at `:724-728`. This is only reached against a non-immune target, because the step 1-2 typecalc returns −10 first against a Ghost (`:701-704`).

**Focus Punch**

- Hook timing: `SetActionsAndBattlersTurnOrder` then the hook (`bm.c:3578-3579`, `:3619-3620`).
- The hook runs in battler-id order and checks the chosen move id, not asleep, no Truant and not `noValidMoves` (`bm.c:3669-3685`).
- Locked and recharging battlers skip selection, so their chosen move stays `MOVE_NONE` (`bm.c:3125-3130`, `:3288`).
- Trainer and trapped run vetoes return before `CASE_CHOSEN` (`bm.c:3239-3253`).
- Script: `jumpifnodamage` (`bsc.c:8757-8763`); no `attackstring` on the lost-focus path (`bs1.s:2255-2261`).
- Damage record: Pain Split is excluded from the physical arm and is Normal type, so neither arm fires; passive damage is excluded; `gHpDealt` 0 records 0 (`bsc.c:1822-1854`).

**Engine fit**

- `applyDamage` is the single defender-HP path for every adjust family plus Super Fang and Endeavor (`BattleEngine.lua:2121`, `:2878-2942`, `:3077`, `:3532-3535`, `:3599`).
- Pain Split (`:2750-2765`), crash, recoil, the confusion self-hit (`:1758-1773`) and end-of-turn damage bypass it.
- The halted-turn and forced-switch flow runs `resolveEndTurn` before `resolveForcedSwitch` (`:4334-4362`, `:3662-3688`), so the `isFirstTurn = 1` special case in `resolveForcedSwitch` is correct.
- Each battle builds one engine (`main.lua:1315`, `:1390`, `:1538`), so setting the leads to 1 in `new` is safe.

**Ordering traps (R2)**

Both traps are real.

- Running `cancelMultiTurnMoves` before the charge block would send turn 2 down the turn-1 arm (`:2019-2052`).
- Reading `rampageLocked` after the cancel would decrement a locked 0-PP rampage unconditionally (`:2522-2535`).

Placing the step after the turn-2 arm and capturing `rampageLocked` first fixes both.

**No `main.lua` change**

- The pre-turn event at the head of `runTurn`'s list is shown first by `_runTurn` (`BattleSceneController.lua:680-724`).
- The voluntary-switch callback adds no text of its own before `_runTurn` (`main.lua:1653-1697`).
- The player's forced switch goes through `engine:resolveForcedSwitch` (`main.lua:1621`) and the foe's through `TrainerBattleOrchestrator.lua:36`.
- Trainer and trapped runs are vetoed before `runTurn` (`BattleSceneController.lua:681-694`).
- `persistPartyBattler` writes HP, status1 and PP only.

## Decision recommendations

- **D1 (rate overflow): accept, with a condition.** Run the ROM probe: locate `FF FF FF 7F FF 3F FF 1F` and record the following words.
  - P2 must not reach `R`, and should not merge into a player-facing build, while index ≥ 4 is an `error()` (F9).
  - If the bridge run cannot happen first, keep P2 unmerged rather than inventing a cap.
  - The expected words come from source order (`sMovesForbiddenToCopy`: 118, 165, 166, 102, 0xFFFE). They are a hypothesis until the ROM confirms them (AGENTS rule 8).
- **D2 (P1 as infrastructure): yes.** It keeps replays stable. Fold F1 and F2 into the P1 table first.
- **D3 (order P4, P5, P1, P2, P3): yes.** P4 and P5 fix moves that are already admitted. P4 also removes a live AI `error()` (Painter Edna's Smeargle). Their only dependency on P1 is the protected-text branch, which shows up once P1 lands.
- **D4 (run latch): yes.** It is verified source behaviour, reachable through the TM01 Focus Punch in wild battles, and it is one engine flag. Note F8 for future roamers.
- **D5 (Nightmare, Ghost Curse and Psych Up bypass Protect): yes**, exactly as source.
- **D6 (2/1/0 counter): yes.** Make the decrement the last statement of `resolveEndTurn`, and keep the `resolveForcedSwitch` = 1 case.
- **D7 (endured flag on `damage`/`multiHit`): yes** for single hits and for 29/44/77. Triple Kick needs the F6 decision.

## Required changes before the P1/P3 task files are approved

1. F1: the paralysis gate order in shape B and in the P1 primary-status row, plus a test.
2. F2: Jump Kick into a protected Ghost shows the crash text, takes one random draw and loses no HP. Fix the row, the miss-branch item (b), the verification line and surprising-behaviour item 7.
3. F3: a single adjust condition for False Swipe and Endure.
4. F4 and F6: wording and placement, settled in the task files.
