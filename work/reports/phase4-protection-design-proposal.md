# Phase 4 proposal: protection and turn-state moves (Protect/Detect, Endure, Fake Out, Focus Punch)

- Status: `PROPOSAL — awaiting design review`
- Date: 2026-10-15
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Builds on: status slices S1-S4, confusion/flinch C1-C2 (`flinched`,
  `flinchTargetPending`, `applySecondaryStatus2`), the multi-turn slices
  M1-M3 (`charging`, `semiInvulnerable`, `rampageTurns`,
  `cancelMultiTurnMoves`), weather W0-W3b (`endTurnOrder`), residual R1-R3
  (Leech Seed, Nightmare, Curse, Ingrain, Mean Look, trapping) and the
  forced/voluntary switch work (`recordFaint`, `resolveForcedSwitch`).
- Lane: full relay. These slices add per-turn and per-battler battle state,
  a gate that touches almost every admitted move family, new RNG draws, a
  pre-turn event and new controller texts. **No slice needs a `main.lua`
  change** (see "main.lua").

The [move-effect inventory](phase4-move-effect-inventory.md) marks every
family here `B`:

| Effect | Moves | Today | Inventory row |
| --- | --- | --- | --- |
| 111 `EFFECT_PROTECT` | 182 Protect, 197 Detect | rejected | `:217` |
| 116 `EFFECT_ENDURE` | 203 Endure | rejected | `:222` |
| 158 `EFFECT_FAKE_OUT` | 252 Fake Out | **admitted as a plain hit** | `:264` |
| 170 `EFFECT_FOCUS_PUNCH` | 264 Focus Punch | **admitted as a plain hit** | `:276` |

Fake Out and Focus Punch are already reachable through the plain-hit path,
so today they diverge (no first-turn rule, no flinch, no lost-focus failure,
no pre-turn text, and a missing discarded draw for Fake Out against a Ghost).

Source paths below are relative to the pin. Abbreviations follow the earlier
proposals: `bsc.c` is `src/battle_script_commands.c`, `bs1.s` is
`data/battle_scripts_1.s`, **`bm.c` is `src/battle_main.c`**, `msg.c` is
`src/battle_message.c`, `bu.c` is `src/battle_util.c`, `ai.s` is
`data/battle_ai_scripts.s`, `aisc.c` is `src/battle_ai_script_commands.c`,
`moves.h` is `src/data/battle_moves.h`, `battle.h` is `include/battle.h`,
`cb.h` is `include/constants/battle.h`, `bsid.h` is
`include/constants/battle_string_ids.h`. (The local scratch copy named
`/tmp/claude-0/bm.c` is `battle_message.c`; this report calls that file
`msg.c`. All local copies were byte-compared against the pinned raw files.)
Engine paths are `src/core/…` at the 2026-10-15 working tree (after R3).

## Summary

- **P1: protected-target gate, no new move admitted.** A per-turn
  `protected` flag and the `attackcanceler` protect step, applied to every
  admitted family with its source-specific outcome (table in §4). Nothing
  sets the flag yet; tests set it directly. No replay changes.
- **P2: Protect and Detect.** `setprotectlike`, the consecutive-use counter
  and its one `Random()`, last-mover failure, `gLastResultingMoves`
  tracking, texts. Admits 182 and 197.
- **P3: Endure.** It shares P2's counter. The survive-at-1-HP clamp goes at
  the source's three adjust sites: Super Fang is exempt, multi-hit stops
  early, and "ENDURED the hit!" is ordered before the effectiveness text.
  Admits 203.
- **P4: Fake Out.** The `isFirstTurn` counter, `jumpifnotfirstturn`, the
  certain flinch (including the Inner Focus text), the discarded draw on a
  no-effect hit, and the AI row `AI_CBM_FakeOut`.
- **P5: Focus Punch.** The pre-turn "tightening its focus" event at the top
  of `runTurn` (with the battle-long run latch), a per-turn "took move
  damage" record, and the lost-focus branch.

P2 and P3 depend on P1. P4 and P5 are independent of P1-P3 and of each
other. They only pick up the "protected" text when P1 has landed. Doing P4
and P5 first is reasonable, because they fix moves that are already
admitted (decision D3).

The protect gate is tractable. Every admitted family's script reaches the
check in one of five shapes (§4). Only eight families need more than "treat
it as a no-draw miss and print the protected text". The rest share one
code path.

## Source facts

### 1. State and its lifetime

| State | Source | Set | Cleared |
| --- | --- | --- | --- |
| `gProtectStructs[b].protected` | `battle.h:179` | `Cmd_setprotectlike` success, effect 111 (`bsc.c:6233-6237`) | `TurnValuesCleanUp(TRUE)` at the start of `BattleTurnPassed`, before any end-of-turn effect (`bm.c:2957`, `:3630-3634`); the whole struct again by `TurnValuesCleanUp(FALSE)` (`bm.c:2970`, `:3637-3639`); `FaintClearSetData` (`bm.c:2461`). **Not** cleared by `SwitchInClearSetData`, which is unobservable because a switch always precedes moves. |
| `gProtectStructs[b].endured` | `battle.h:180` | the same, effect 116 (`bsc.c:6238-6242`) | the same as above |
| `gProtectStructs[b].physicalDmg` / `specialDmg` | `battle.h:206` | `Cmd_datahpupdate` on non-passive HP loss (`bsc.c:1822-1854`) | `TurnValuesCleanUp(FALSE)` only, so they are per turn |
| `gDisableStructs[b].protectUses` (u8) | `battle.h:144` | `++` on success (`bsc.c:6243`) | `= 0` on failure (`:6247`), or when the last resulting move is not Protect/Detect/Endure (`:6225-6226`); zeroed with the whole disable struct on switch-in (`bm.c:2383-2384`), on faint (`bm.c:2458-2459`) and at battle start (`bm.c:2224-2226`) |
| `gLastResultingMoves[b]` | `bm.c:179` | `MOVEEND_UPDATE_LAST_MOVES` (`bsc.c:4235-4262`): `gCurrentMove` if `HITMARKER_OBEYS`, else `MOVE_UNAVAILABLE` (0xFFFF) | `MOVE_NONE` at battle start, on switch-in and on faint (`bm.c:2233`, `:2400`, `:2486`) |
| `gDisableStructs[b].isFirstTurn` | `battle.h:164` | `= 2` at battle start, on switch-in and on faint (`bm.c:2228`, `:2396`, `:2481`) | `--` (if nonzero) in every `TurnValuesCleanUp(FALSE)` (`bm.c:3640-3641`), that is, once in `TryDoEventsBeforeFirstTurn` (`bm.c:2909`) and once at the end of every turn (`bm.c:2970`) |
| `HITMARKER_RUN` (bit 15, `cb.h:168`) | `gHitMarker` | the player's `B_ACTION_RUN` reaching `STATE_WAIT_ACTION_CASE_CHOSEN` (`bm.c:3326-3328`; Safari run `:3340-3342`) | **only** `gHitMarker = 0` in `BattleStartClearSetData` (`bm.c:2257`). No `&= ~HITMARKER_RUN` exists in `battle_main.c`, `battle_script_commands.c`, `battle_util.c`, `battle_util2.c`, the battle controllers or `pokemon.c` at the pin (grep). |

`HITMARKER_OBEYS` is set in `Cmd_attackcanceler` only after
`AtkCanceller_UnableToUseMove`, the move-blocking abilities and the no-PP
check have passed (`bsc.c:828-864`). It is cleared after every action
(`bm.c:4444-4450`, `:4456-4462`). So:

- a move stopped by a canceller (sleep, freeze, recharge, flinch, the
  confusion self-hit, full paralysis) or by "no PP left" records
  `MOVE_UNAVAILABLE`;
- any move that passes `attackcanceler`, even one that then fails, records
  `gCurrentMove`. That includes a charging turn 1, and Struggle records
  `MOVE_STRUGGLE`;
- **an item, run or switch action never reaches moveend**, so the previous
  value survives. A Protect chain survives a turn spent throwing a Poké Ball
  or failing to run.

### 2. The protect check

`DEFENDER_IS_PROTECTED` is `gProtectStructs[gBattlerTarget].protected &&
(gBattleMoves[gCurrentMove].flags & FLAG_PROTECT_AFFECTED)` (`bsc.c:42`).
`FLAG_PROTECT_AFFECTED` is bit 1 (`include/constants/pokemon.h:239`).

**`Cmd_attackcanceler`** (`bsc.c:819-907`). After the cancellers, the PP
check, disobedience, Magic Coat, Snatch and Lightning Rod:

```c
else if (DEFENDER_IS_PROTECTED
 && (gCurrentMove != MOVE_CURSE || IS_BATTLER_OF_TYPE(gBattlerAttacker, TYPE_GHOST))
 && ((!IsTwoTurnsMove(gCurrentMove) || (gBattleMons[gBattlerAttacker].status2 & STATUS2_MULTIPLETURNS))))
{
    CancelMultiTurnMoves(gBattlerAttacker);
    gMoveResultFlags |= MOVE_RESULT_MISSED;
    ...
    gBattleCommunication[MISS_TYPE] = B_MSG_PROTECTED;
    gBattlescriptCurrInstr++;
}
```
(`bsc.c:896-905`)

- **The script continues.** The flag only marks the move `MISSED`, and
  every later step sees it:
  - `attackanimation` is skipped for any `MOVE_RESULT_NO_EFFECT`
    (`bsc.c:1662-1700`).
  - `seteffectwithchance` applies nothing (`bsc.c:2783-2797`).
  - Any later `resultmessage` prints the protected text.
  - A `printstring` on a gate path still prints its own text.
- `CancelMultiTurnMoves` (`bu.c:203-214`) clears `MULTIPLETURNS`,
  `LOCK_CONFUSE`, `UPROAR`, `BIDE`, the semi-invulnerable bits, the Rollout
  timer and the Fury Cutter counter. It does **not** clear `RECHARGE`.
- `IsTwoTurnsMove` covers Skull Bash, Razor Wind, Sky Attack, Solar Beam,
  the semi-invulnerable family and Bide (`bsc.c:7821-7832`). Their first
  turn (no `MULTIPLETURNS` yet) is never blocked.
- **The Curse clause is dead code.** Curse has `flags = 0` (`moves.h`
  Curse record), so `DEFENDER_IS_PROTECTED` is already false for Curse.

**`Cmd_accuracycheck`** (`bsc.c:1003-1105`) re-tests the condition itself.
It does not read the `MISSED` flag left by `attackcanceler`:

- **`ACC_CURR_MOVE`** (and explicit moves): `JumpIfMoveAffectedByProtect`
  runs **first** (`bsc.c:1040-1041`), before `AccuracyCalcHelper`
  (`:1042`).
  - So protect beats the semi-invulnerable miss, Lock-On, `EFFECT_ALWAYS_HIT`,
    Vital Throw and Thunder in rain.
  - The protect path takes **no `Random()`**.
  - It never reaches `CheckWonderGuardAndLevitate` (`:1102`). So, unlike a
    failed roll, it does not set `DOESNT_AFFECT` on an immune target.
- **`NO_ACC_CALC` / `NO_ACC_CALC_CHECK_LOCK_ON`** (`bsc.c:1020-1028`): Lock-On
  (`CHECK_LOCK_ON` only) comes first, then the semi-invulnerable test, then
  `JumpIfMoveAffectedByProtect(0)`. No `Random()` either way.

**`JumpIfMoveAffectedByProtect`** (`bsc.c:945-956`): sets `MISSED`, calls
`JumpIfMoveFailed(7, move)` (`:909-924`, which jumps to the script's
failure pointer because `NO_EFFECT` is now set), then sets `MISS_TYPE =
B_MSG_PROTECTED`.

- Callers: `Cmd_accuracycheck` (both branches, `bsc.c:1026`, `:1040`) and
  `ChangeStatBuffs` for target-side stat drops (`bsc.c:6700-6704`, which
  jumps to `BattleScript_ButItFailed`; the Curse exemption there is dead
  for the same reason).
- For every admitted stat-drop move, an `accuracycheck` runs first, so the
  `ChangeStatBuffs` arm is unreachable. Memento takes its own early jump.
- **`Cmd_jumpifaffectedbyprotect` (opcode 0x40, `bsc.c:931-942`) is used by
  no script in `bs1.s` at the pin.**

**The text.** `Cmd_resultmessage` (`bsc.c:1930-2005`) prints
`gMissStringIds[MISS_TYPE]` when `MISSED && (!DOESNT_AFFECT_FOE ||
MISS_TYPE > B_MSG_AVOIDED_ATK)` (`:1937`).

- `B_MSG_PROTECTED` is 1 and `B_MSG_AVOIDED_ATK` is 2 (`bsid.h:416-417`).
- So **"It doesn't affect" wins over "protected"** whenever a `typecalc`
  has set `DOESNT_AFFECT_FOE`. Three scripts can do that on a protected
  target: Explosion (typecalc before accuracycheck), Earthquake/Magnitude
  (typecalc in the miss path), and Thunder Wave's typecalc gate.
- `gMissStringIds[B_MSG_PROTECTED]` is `STRINGID_PKMNPROTECTEDITSELF`
  (`msg.c:897`): "{B_DEF_NAME_WITH_PREFIX}\nprotected itself!" (`msg.c:66`).
  It names the protected target. The user's own success text is a
  different string with a different line break (§9).

### 3. Protect / Detect / Endure

Records:

| Move | Effect | Type | Priority | Flags | Source |
| --- | --- | --- | --- | --- | --- |
| Protect | 111 | Normal | +3 | 0 | `moves.h:2369-2380` |
| Detect | 111 | Fighting | +3 | 0 | `moves.h:2564-2575` |
| Endure | 116 | Normal | +3 | 0 | `moves.h:2642-2653` |

All three have power 0, accuracy 0, target `USER` and PP 10/5/10.

Script (`bs1.s:1528-1538`, shared): `attackcanceler`, `attackstring`,
`ppreduce`, `setprotectlike`, `attackanimation`, `printfromtable
gProtectLikeUsedStringIds`. So PP is spent even when it fails.

**`Cmd_setprotectlike`** (`bsc.c:6219-6251`):

1. If `gLastResultingMoves[attacker]` is not Protect, Detect or Endure, set
   `protectUses = 0` (`:6225-6226`). **The three moves share one chain.**
2. `notLastTurn = (gCurrentTurnActionNumber != gBattlersCount - 1)`
   (`:6228-6229`). In singles, the user's action is last when it is the
   second of the turn's two actions, **whatever the first one was** (a
   move, a switch, an item or a failed run).
3. `if (sProtectSuccessRates[protectUses] >= Random() && notLastTurn)`
   (`:6231`). **`Random()` is the left operand, so exactly one draw happens
   on every call, including the last-mover failure.**
   - The table is `{0xFFFF, 0x7FFF, 0x3FFF, 0x1FFF}` (`bsc.c:701`).
   - The success probability is (rate+1)/65536: 1, 1/2, 1/4, 1/8.
4. On success: `protected = 1` for effect 111 or `endured = 1` for effect
   116, the string chooser is set, and `protectUses++` (`:6233-6243`).
5. On failure: `protectUses = 0`, `B_MSG_PROTECT_FAILED` and `MISSED`
   (`:6245-6249`).

**Overflow (UNKNOWN, decision D1).** `protectUses` is a `u8` with no cap.
After four consecutive successes, which happens with probability 1 · 1/2 ·
1/4 · 1/8 = 1/64, the fifth consecutive use reads
`sProtectSuccessRates[4]`, past the end of the four-entry table.

- In source order, the next object is `sMovesForbiddenToCopy`
  (`bsc.c:707-714`): `MOVE_METRONOME` (118), `MOVE_STRUGGLE` (165),
  `MOVE_SKETCH` (166), `MOVE_MIMIC` (102), `0xFFFE`, and so on.
- If the compiled ROM keeps that layout, index 4 succeeds with probability
  119/65536 (about 0.18%), index 5 with 166/65536, and so on.
- The layout is a compiler fact, not a source fact. It must be confirmed
  from the verified ROM before the engine models index ≥ 4.

Texts: `gProtectLikeUsedStringIds` (`msg.c:947-952`):

| Result | Text | Source |
| --- | --- | --- |
| Protected | "{B_ATK_NAME_WITH_PREFIX} protected\nitself!" | `msg.c:155` |
| Braced | "{B_ATK_NAME_WITH_PREFIX} braced\nitself!" | `msg.c:206` |
| Failed | "But it failed!" | `msg.c:336` |

### 4. What a protected target does to every admitted family

Every admitted family whose move has `FLAG_PROTECT_AFFECTED` and a
non-`USER` target is affected (flag census from `moves.h`). The behaviour
falls into five shapes.

**Shape A: the ordinary hit path.** `attackcanceler` → `accuracycheck
BattleScript_PrintMoveMissed` → `attackstring`, `ppreduce`, pause,
`resultmessage` (`bs1.s:246-247`, `:276-285`).

- Visible result: "X used M!", then "Foe Y\nprotected itself!".
- PP is spent, guarded at 0 by `Cmd_ppreduce` (`bsc.c:1147`).
- No accuracy, crit, damage or secondary draws, and no effect.

Families in shape A:

- **`EffectHit` and every `setmoveeffect … goto BattleScript_EffectHit`
  variant:**
  - 0 hit, 2/4/5/6 status-hit, 31 flinch-hit, 36 Tri Attack, 43 high crit,
    68-73 stat-down hits, 76 confuse-hit, 103 quick attack;
  - 125 thaw-hit, 138-140 user-stat hits, 146 Twister, 149 Gust, 150
    Stomp, 152 Thunder, 169 Facade, 171 Smelling Salt, 182 Superpower;
  - 200 Blaze Kick, 202 Poison Fang, 203 Weather Ball, 204 Overheat, 207
    Sky Uppercut, 209 Poison Tail;
  - 17 always-hit and 78 Vital Throw (protect precedes `AccuracyCalcHelper`);
  - 101 False Swipe, 99 Flail, 190 Eruption;
  - 129 Rapid Spin (no spin cleanup), 186 Brick Break (no wall shatter);
  - 42 trap (no wrap, no `% 100`, no `& 3`; `bs1.s:829-835`);
  - 48/198 recoil, including Struggle, which carries the flag (no recoil);
    3 absorb (no drain);
  - 80 recharge (no recharge lock, because the `RECHARGE` effect is never
    reached).
- 29/44/77 multi-hit family: `accuracycheck` precedes `setmultihitcounter`
  (`bs1.s:605-611`), so **no hit-count draw**.
- 40 Super Fang, 41/130 fixed damage, 87 level damage, 88 Psywave (no
  sample), 38 OHKO (see shape C).
- 18-24/58-62 stat-down (`BattleScript_EffectStatDown`, `bs1.s:536-560`):
  the Substitute gate, then `accuracycheck PrintMoveMissed`.
- 104 Triple Kick: the loop's first `accuracycheck` jumps to
  `TripleKickNoMoreHits`. With 0 hits it skips the `MISSED` clear and
  `resultmessage` prints the protected text (`bs1.s:1380-1430`).
- 118 Swagger / 166 Flatter: `accuracycheck PrintMoveMissed` precedes
  `attackstring` (`bs1.s:1604-1608`). Same visible result, no draw.
- 27 rampage: shape A, plus the canceller's `CancelMultiTurnMoves`. See §5.
- **Turn 2** of 39/75/145/151/155: `BattleScript_TwoTurnMovesSecondTurn`
  (`bs1.s:784-792`) sets `HITMARKER_NO_PPDEDUCT`, then
  `HitFromAccCheck` → protected. See §5.
- The admitted-but-`B` plain hits with the flag:
  - Pay Day, Rage, Thief, Rollout, Fury Cutter, Return, Present,
    Frustration, Pursuit, Hidden Power, Beat Up, Uproar, Spit Up, Revenge,
    Knock Off, Low Kick and Secret Power;
  - they inherit shape A through the shared path;
  - their own source scripts remain out of scope.

**Shape B: status scripts with gates before `accuracycheck
BattleScript_ButItFailed`** (`bs1.s:287-300` and siblings): 1 sleep, 66
poison, 67 paralyze, 33 Toxic, 167 Will-O-Wisp, 49 confuse, 199 Teeter
Dance, 205 Tickle.

- Gates whose failure path is a `printstring` keep their own text:
  - "already asleep/poisoned/paralyzed/burned/confused";
  - the Insomnia/Vital Spirit/Immunity/Limber/Water Veil/Own Tempo
    prevention texts;
  - Tickle's "won't go lower" (`BattleScript_CantLowerMultipleStats`);
  - the type `BattleScript_NotAffected` and Thunder Wave's typecalc gate
    print "It doesn't affect" (`DOESNT_AFFECT` wins, §2).
- Gates that `goto BattleScript_ButItFailed` (Substitute, "has any
  status1") print **"Foe Y\nprotected itself!"** instead of "But it
  failed!", because `MISSED` is already set.
- Otherwise `accuracycheck` → `ButItFailed` → the protected text, with no
  draw. Teeter Dance uses `BattleScript_TeeterDanceMissed`, which has the
  same `resultmessage`.

**Shape C: `NO_ACC_CALC` checks** (no draw either way):

- 38 OHKO (`bs1.s:761-775`): attackstring and ppreduce come first, then
  `accuracycheck ButItFailed, NO_ACC_CALC_CHECK_LOCK_ON` → protected. The
  typecalc and `tryKO` draw are never reached.
- 91 Pain Split (`bs1.s:1235-1245`): the same.
- 106 Mean Look / Spider Web / Block (`bs1.s:1440-1453`): `accuracycheck
  ButItFailed, NO_ACC_CALC` → protected, before the "already prevented"
  gate.

**Shape D: special cases.**

| Effect | Behaviour against a protected target | Source |
| --- | --- | --- |
| 84 Leech Seed | The failure pointer is the success label. `setseeded` sees `NO_EFFECT` and prints **"Foe Y evaded\nthe attack!"**, not the protected text. No draw. | `bs1.s:1153-1166`; `bsc.c:6436-6456`; `msg.c:160` |
| 107 Nightmare | **No `accuracycheck` at all**, but the move has the flag. Substitute / already-NIGHTMARE / not-asleep go to `ButItFailed` and print the **protected** text. An asleep target takes `NightmareWorked`: the animation is skipped, **but `seteffectprimary` still sets `STATUS2_NIGHTMARE` and "fell into a NIGHTMARE!" prints**. Nightmare lands through Protect. | `bs1.s:1455-1469`; `bsc.c:2678-2681` |
| 168 Memento | `jumpifbyte cMISS_TYPE == B_MSG_PROTECTED` → `MementoTargetProtect`: attackstring, ppreduce, `trymemento` (cannot fail while protected, `bsc.c:8683-8685`), `setatkhptozero`, protected text, `tryfaintmon BS_ATTACKER`. **The user still faints, and no stats drop.** | `bs1.s:2199-2201`, `:2234-2244` |
| 7 Explosion | `setatkhptozero` precedes everything. Each loop pass runs `movevaluescleanup`, critcalc, damagecalc, typecalc and **adjustnormaldamage (crit and random draws taken)**, then `accuracycheck ExplosionMissed` → protected (no accuracy draw). The text is "doesn't affect" for an immune target, else protected. The user faints. | `bs1.s:376-417` |
| 147 Earthquake / 126 Magnitude | Magnitude rolls and prints its strength first. `accuracycheck HitAllWithUndergroundBonusMissed` runs **`typecalc` in the miss path**: an immune (Flying) target prints "doesn't affect", otherwise protected. | `bs1.s:1679-1690`, `:1830-1875` |
| 45 Jump Kick / Hi Jump Kick | `accuracycheck MoveMissedDoDamage` → protected text, then **crash**. The `DOESNT_AFFECT` test after `resultmessage` is false (no `CheckWonderGuardAndLevitate` on the protect path), so the crash happens **even against a protected Ghost**. Crash damage = damagecalc (no crit) + typecalc (0 against a Ghost) + `adjustnormaldamage` (one random draw), then `DMG_RECOIL_FROM_MISS` (0 → 1). | `bs1.s:848-870` |
| 189 Endeavor | `setdamagetohealthdifference ButItFailed` (target HP ≤ user HP) prints the **protected** text, because `MISSED` is set. Otherwise `accuracycheck MoveMissedPause` → protected. Always the protected text, no draw. | `bs1.s:2474-2485` |
| 92 Snore | Awake: `ButItFailed` → **protected** text. Asleep: "fast asleep", then `accuracycheck MoveMissedPause` → protected; no flinch draw. | `bs1.s:1253-1268` |

**Shape E: not affected** (the script runs exactly as it does today):

- **109 Curse, both paths.** `flags = 0`, so **Ghost Curse lays its curse
  through Protect** and the user pays half its HP. The attackcanceler
  clause naming Curse is dead code.
- **143 Psych Up** (`flags = 0`, target `SELECTED`): copies a protected
  target's stages.
- **25 Haze and 164 Hail** carry `FLAG_PROTECT_AFFECTED` but target `USER`.
  The controllers set `gBattlerTarget` to the user for `USER` moves
  (`src/battle_controller_player.c:460-466`,
  `src/battle_controller_opponent.c:1370`, `:1393`), so the protected-ness
  being tested is the user's own, which is false while it acts.
- Every other `USER`-target family: stat-ups, screens, weather, the heals,
  Rest, Focus Energy, Refresh, Ingrain, Splash, Conversion, Belly Drum and
  the dual stat-ups.
- **Turn 1** of every `IsTwoTurnsMove` family: the charge happens, and Fly
  or Dig goes semi-invulnerable, even against a protected target.

### 5. Interaction with lock and multi-turn state

- **Charging turn 2** (Razor Wind, Skull Bash, Solar Beam, Sky Attack,
  Fly/Dig/Dive/Bounce):
  - `MULTIPLETURNS` is set, so the move is blocked.
  - `CancelMultiTurnMoves` clears the lock and the semi-invulnerable bit
    (the Fly user lands).
  - `TwoTurnMovesSecondTurn` sets `NO_PPDEDUCT`, so **no PP** is spent.
  - Text: "used M!", then protected.
  - Solar Beam in sun spends its PP before `attackcanceler`
    (`SolarBeamOnFirstTurn`, already modeled) and is then blocked the same
    way.
- **Rampage:**
  - Turn 1 into Protect: nothing locks, because the lock is set by the
    landed hit's `seteffectwithchance`. One PP is spent.
  - A locked turn into Protect: `CancelMultiTurnMoves` clears
    `MULTIPLETURNS` and `LOCK_CONFUSE`, so **the rampage ends with no
    confusion** (`ENDTURN_THRASH` sees nothing).
  - `PrintMoveMissed`'s `ppreduce` spends one PP if any remain.
- **Recharge:**
  - A protected Hyper Beam sets no recharge.
  - A battler recharging against a protecting foe is unaffected.
- **Semi-invulnerable defender:** never protected in the same turn, because
  a Protect user cannot be mid-Fly. No interaction.
- **Trapping, Leech Seed, Curse, Nightmare, Ingrain, Mean Look:**
  - The protect flag is never read at end of turn, so residual damage and
    heals still run on a protected battler.
  - A wrapped, seeded, rooted or escape-prevented battler can still use
    Protect.
  - Mean Look against a protected target: protected text, no escape lock.
- **Flinch:**
  - Protect has +3 priority, so the user almost always moves first and
    cannot be flinched before acting.
  - Fake Out (+1) into Protect: protected, no flinch.
- **Cancellers:**
  - Sleep, freeze, recharge, flinch, the confusion self-hit and full
    paralysis stop Protect before `setprotectlike`: no draw, PP not spent.
  - The last resulting move becomes `MOVE_UNAVAILABLE`, so the chain resets.
- **Last mover:**
  - Protect against Protect: the slower one fails, after its draw.
  - A foe Protect after the player's switch, Poké Ball or failed run is the
    last action and fails, after its draw.

### 6. Endure

`endured` is read at three adjust sites, all of the form `if
(!SUBSTITUTE && (FALSE_SWIPE || endured || focusBanded) && hp <=
gBattleMoveDamage) { damage = hp - 1; if (endured) flags |= FOE_ENDURED; }`:

| Command | Source | Scripts that use it (admitted families) |
| --- | --- | --- |
| `adjustnormaldamage` | `bsc.c:1577-1615` (clamp `:1600-1610`) | `HitFromCritCalc` (every shape-A hit), Absorb, Explosion, the multi-hit loop, Triple Kick, Earthquake/Magnitude, Brick Break (`bs1.s:255`, `:333`, `:395`, `:625`, `:1401`, `:1849`, `:2422`) |
| `adjustnormaldamage2` | `bsc.c:1620-1660` | confusion self-hit, which targets the user. Unreachable for an Endure user, because it has already acted. |
| `adjustsetdamage` | `bsc.c:5602-5637` (clamp `:5623-5633`) | Dragon Rage, Sonic Boom, level damage, Psywave, Endeavor (`bs1.s:826`, `:1723`, `:1199`, `:1210`, `:2485`) |
| `Cmd_tryKO` | `bsc.c:7158-7163` | OHKO: endured → `hp - 1` and `FOE_ENDURED` (instead of `ONE_HIT_KO`); the `tryKO` draw is still taken |

- **Super Fang has no adjust step** (`bs1.s:808-816`;
  `damagetohalftargethp` = max(1, hp/2), `bsc.c:7191-7197`). **A 1-HP
  Enduring target is knocked out by Super Fang.**
- Pain Split has no adjust step either, but cannot knock out.
- **Multi-hit and Triple Kick stop at the endured hit.** `movevaluescleanup`
  resets the flags per hit. After the hit that sets `FOE_ENDURED`,
  `jumpifbyte … FOE_ENDURED` goes to the print strings
  (`bs1.s:639`, `:1415`). Fewer crit and damage draws follow. The
  hit-count draw is already spent.
- **Text order.** `Cmd_resultmessage`:
  - `flags & ~MISSED == FOE_ENDURED` alone prints "{B_DEF_NAME_WITH_PREFIX}
    ENDURED\nthe hit!" (`msg.c:207`) directly (`bsc.c:1956-1958`).
  - Combined with super- or not-very-effective, the default branch pushes
    the cursor (on `resultmessage` itself), runs `BattleScript_EnduredMsg`
    (`bs1.s:3628-3631`), clears `FOE_ENDURED` and re-executes
    `resultmessage` (`bsc.c:1986-1992`).
  - So **"ENDURED the hit!" prints before "It's super effective!"**, and
    after `critmessage`.
- False Swipe against an Enduring target at `hp <= damage` takes the same
  clamp and prints ENDURED.
- At 1 HP, damage becomes 0; `gHpDealt = 0`, and ENDURED prints.
- Endure never applies to end-of-turn damage, recoil, crash or confusion.

### 7. Fake Out

Record: `moves.h:3279-3290`: power 40, Normal, accuracy 100, chance 0,
**priority +1**, `PROTECT_AFFECTED | MIRROR_MOVE_AFFECTED`.

Script (`bs1.s:2044-2048`):

1. `attackcanceler` (the cancellers, and the protect `MISSED` mark).
2. `jumpifnotfirstturn BattleScript_ButItFailedAtkStringPpReduce`
   (`bsc.c:6504-6512`: passes iff `isFirstTurn != 0`).
   - The fail path is `attackstring`, `ppreduce`, pause, `orbyte FAILED`,
     `resultmessage` (`bs1.s:2050-2059`).
   - It prints "X used FAKE OUT!", then "But it failed!", or the
     **protected** text when the target is protected.
3. `setmoveeffect MOVE_EFFECT_FLINCH | MOVE_EFFECT_CERTAIN`, then
   `goto BattleScript_EffectHit`.
   - That re-enters `attackcanceler`. This is harmless:
     `atkCancellerTracker` is already at `CANCELLER_END`
     (`bu.c:1257-1531`), so nothing re-rolls, and the protect mark is
     idempotent.
   - Then the ordinary hit.

`seteffectwithchance` (`bsc.c:2774-2805`):

- **Landed hit:** `CERTAIN && !NO_EFFECT` → `SetMoveEffect(FALSE, CERTAIN)`,
  with **no draw**.
- **No-effect hit** (a Ghost target): the else-if evaluates `Random() % 100
  <= 0` first, so **one discarded draw**, the same shape as Smelling Salt.
  The engine misses this draw today.

`SetMoveEffect` guards (`bsc.c:2132-2146`), in order:

1. Shield Dust: byte 8 ≤ 9 and `!primary`, so it **blocks silently**.
2. A target at 0 HP returns.
3. Substitute (not modeled).

The flinch case (`bsc.c:2419-2439`):

- **Inner Focus with `certain` prints "{B_EFF_NAME_WITH_PREFIX}'s
  {B_EFF_ABILITY}\nprevents flinching!"** (`msg.c:296`;
  `BattleScript_FlinchPrevention`, `bs1.s:4109-4113`). That path then goes
  to MoveEnd. It is only reached when the target is above 0 HP.
- Otherwise the flinch is set only if the target has not acted yet
  (`GetBattlerTurnOrderNum(target) > gCurrentTurnActionNumber`). This is
  the engine's `flinchTargetPending`.

`isFirstTurn` timeline:

- Leads: 2 → 1 before turn 1 (`bm.c:2909`).
- At the end of every turn, decrement it (`bm.c:2970`, `:3640-3641`).
- Voluntary switch-in on turn N: 2, then 1 at the end of N. Its first turn
  is N+1.
- Forced replacement after turn N (or mid-turn): `SwitchInClearSetData` sets
  2, then the same `BattleTurnPassed`'s `TurnValuesCleanUp(FALSE)` runs after
  `HandleFaintedMonActions` (`bm.c:2964-2970`), giving 1. Its first turn is
  N+1.
- During a turn, a battler that is acting holds 1 (first turn) or 0. The
  value 2 only marks a battler that entered during the current turn, which
  cannot act that turn.

### 8. Focus Punch

Record: `moves.h:3435-3446`: power 150, Fighting, accuracy 100, chance 0,
**priority −3**, `MAKES_CONTACT | PROTECT_AFFECTED`.

**Pre-turn hook: `CheckFocusPunch_ClearVarsBeforeTurnStarts`
(`bm.c:3669-3702`).**

- **When it runs:**
  - `HandleTurnActionSelectionState` has confirmed **both** battlers'
    actions, including the AI's choice and its RNG.
  - `SetActionsAndBattlersTurnOrder` has built the order, including the
    speed-tie `Random()` (`bm.c:3532-3621`).
  - Only then does `gBattleMainFunc` move to the hook (`bm.c:3578-3579`,
    `:3619-3620`).
  - No action has run yet.
- **Move selection is fully resolved** before the text prints.
- **Skip:** the whole loop is skipped while `HITMARKER_RUN` is set
  (`:3671`).
- **Per battler, in battler-id order** (singles: the player, then the foe;
  **not** turn order):
  1. The check is `gChosenMoveByBattler == MOVE_FOCUS_PUNCH`, by move id.
     The chosen move is reset to `MOVE_NONE` each turn (`bm.c:2907`) and
     written only at move selection (`:3288`), so a locked battler never
     qualifies.
  2. **Not asleep** at that moment, before the sleep counter decrements.
     Freeze, paralysis and confusion do **not** suppress the text.
  3. Not Truant-loafing (not modeled).
  4. Not `noValidMoves` (Struggle).
- **Script** (`bs1.s:3649-3655`): an empty string, the setup animation,
  then "{B_ATK_NAME_WITH_PREFIX} is tightening\nits focus!" (`msg.c:224`).
  No RNG.
- **Run latch.** A failed run keeps `HITMARKER_RUN` set for the rest of the
  battle (§1). From that turn on, **no** Focus Punch setup text prints for
  either side. Trainer battles never set it: the trainer veto returns at
  `bm.c:3239-3245`, before `CASE_CHOSEN`. Neither does a trapped run: the
  `IsRunningFromBattleImpossible` veto at `:3246-3253`.

**Move script** (`bs1.s:2255-2261`): `attackcanceler`, then `jumpifnodamage
BattleScript_HitFromAccCheck` (`bsc.c:8757-8763`: passes when
`physicalDmg || specialDmg` is nonzero).

- **Damaged this turn:** `ppreduce`, then "{B_ATK_NAME_WITH_PREFIX} lost
  its\nfocus and couldn't move!" (`msg.c:254`).
  - **There is no `attackstring`, so no "used" line.**
  - No draws.
  - This takes precedence over the protected text.
- **Not damaged:** `HitFromAccCheck`, the ordinary hit (protect applies).
  Its plain-hit `seteffectwithchance` is the tracked zero-byte roll gap
  (inventory `:275`).

**What counts as damage.** `Cmd_datahpupdate` (`bsc.c:1822-1854`) records
`gHpDealt` into `physicalDmg` or `specialDmg` (by move type) for any HP
loss without `HITMARKER_PASSIVE_DAMAGE`, except that **Pain Split is
excluded** (`gCurrentMove != MOVE_PAIN_SPLIT` on the physical arm; Pain
Split is Normal, so neither arm fires).

- In singles, the only damage that can reach the Focus Punch user before it
  moves is the opponent's move: any damaging hit, fixed damage, Super Fang,
  Endeavor, OHKO or Explosion.
- **A hit that deals 0 HP records 0, which keeps focus.** Example: False
  Swipe against a 1-HP Focus Punch user.
- End-of-turn damage is passive and comes later anyway. The records reset
  each turn (§1).

### 9. Texts

| Event | Text | Source |
| --- | --- | --- |
| Protect/Detect success | "X protected\nitself!" (user) | `msg.c:155` |
| Endure success | "X braced\nitself!" (user) | `msg.c:206` |
| Protect-like failure | "But it failed!" | `msg.c:336`, `:951` |
| Move blocked by Protect | "Y\nprotected itself!" (target) | `msg.c:66`, `:897` |
| Leech Seed blocked | "Y evaded\nthe attack!" | `msg.c:160`, `:967` |
| Endured hit | "Y ENDURED\nthe hit!" | `msg.c:207` |
| Fake Out vs Inner Focus | "Y's INNER FOCUS\nprevents flinching!" | `msg.c:296` |
| Focus Punch setup | "X is tightening\nits focus!" | `msg.c:224` |
| Focus Punch lost | "X lost its\nfocus and couldn't move!" | `msg.c:254` |

### 10. AI rows (`ai.s`)

| Effect | `AI_CheckBadMove` | Engine today | CheckViability (out of scope, as in earlier proposals) |
| --- | --- | --- | --- |
| 111 | no `if_effect` row; falls through to 0 | not in `AICheckBadMove.lua`'s table, so 0 | `AI_CV_Protect` `:2014` (uses `get_protect_count`, `aisc.c:1847`) |
| 116 | no row; 0 | 0 | `AI_CV_Endure` `:2081` |
| 158 | `AI_CBM_FakeOut` `:187`, `:510-513`: `is_first_turn_for AI_USER`; 0 → −10 | **`UNPORTED_EFFECTS[158]` errors loudly** (`AICheckBadMove.lua:676`) | `AI_CV_FakeOut` `:2374` (+2) |
| 170 | `AI_CBM_HighRiskForDamage` `:196` | already ported (`AICheckBadMove.lua:647`) | `AI_CV_FocusPunch` `:2413` (reads `is_first_turn_for`) |

`Cmd_is_first_turn_for` returns the raw `isFirstTurn` (`aisc.c:1778-1790`)
at selection time. For the battler on the field, that is 1 on its first
turn and 0 afterwards.

### 11. Reachability

Counts are `grep` counts over the pinned `level_up_learnsets.h` and
`trainer_parties.h` (custom-move parties only; default-moveset trainers
derive from learnsets and are not counted).

- **Protect:**
  - Squirtle 28 / Wartortle 31 / Blastoise 31 (the player's starter line),
    Shellder 29 / Cloyster 1, Krabby 38, Omanyte 37.
  - Custom parties: Cooltrainer Berke's and Lorelei's Cloyster, Painter
    Edna's Smeargle.
- **Detect:** Hitmonchan 44, Zapdos 37. No custom party.
- **Endure:** Hitmonlee 41, Kangaskhan 37, Kabuto line 37, Moltres 37.
  Custom parties: Cooltrainer Leroy's Kangaskhan (×2).
- **Fake Out:**
  - Kangaskhan 19, Meowth 43, Persian 55.
  - Custom party: Painter Edna's Smeargle, which today makes
    `AICheckBadMove` error.
- **Focus Punch:** no FRLG-native level-up learner (Vigoroth only). Custom
  party: Painter Daisy's Smeargle.
- **Wild foes never choose these moves.** The wild AI picks the first
  damaging slot (`main.lua:1300-1308`), so Fake Out or Focus Punch is used
  only when it is that first slot.

## Engine today (fit points)

- **Battler state.** `makeBattler` (`BattleEngine.lua:1105-1192`) has the
  canceller, lock and residual fields. Nothing exists for protect, endure,
  the counter, the last resulting move, the first-turn counter or the
  per-turn damage record.
  - A switch-in or replacement is a fresh `makeBattler` (`runTurn` switch
    branch `:4194-4231`; `resolveForcedSwitch` `:3662-3688`).
  - `recordFaint` (`:1335-1375`) clears the fainted battler's fields.
- **Turn start.** `runTurn` (`:4125-4380`):
  - it asserts, emits `turnStart` (`:4148`), clears `flinched` and
    `targetNotAffected` (`:4155`), records `lockedThisTurn` (`:4157`),
    substitutes locked actions and runs the recharge timer (`:4169-4177`);
  - then the hoisted branches: switch `:4194`, capture `:4233`, run `:4276`;
  - then the move order (`:4317-4362`, with `flinchTargetPending` at
    `:4334`).
- **Move resolution.** `resolveMove` (`:1536-1551`) wraps
  `resolveMoveCore` (`:1869`):
  1. Struggle and locked-slot selection.
  2. The cancellers (`:2005`) and the locked 0-PP check (`:2011-2017`).
     This position is source `attackcanceler` up to the protect step.
  3. The charge block (`:2019-2052`), then `useMove` (`:2054`).
  4. Per-family early branches: Explosion `:2070` (its accuracy roll is
     `:2107`, after the crit and damage draws), Endeavor `:2129`, Confuse
     and Teeter Dance `:2138`, Swagger `:2160`, Snore `:2195`, weather,
     Refresh, Leech Seed `:2243`, Nightmare `:2270`, Curse `:2287`,
     Ingrain, Mean Look `:2366`, Rest, Focus Energy, primary status
     `:2444`.
  5. The shared accuracy step: `needsAccuracyCheck` `:2474`,
     `scriptHasAccuracyCheck` `:2502`, PP `:2527-2535`, the miss branch
     `:2537-2601`.
  6. The power-0 families (Memento `:2642`, Tickle `:2768`).
  7. Multi-hit `:2854`, fixed damage `:2865`, Super Fang `:2882`, OHKO
     `:2931`, crit `:2966`, the no-effect discarded rolls `:3031-3061`,
     False Swipe `:3072`, `applyDamage` `:3077`, the secondary tails
     `:3082-3300`.
- **Shared damage.** `applyDamage` (`:3381-3402`) is the one defender-HP
  path for every adjust-site family, plus Super Fang (`:2893`) and Endeavor
  (`:2910`). Multi-hit `:3474`, Triple Kick `:3575`.
- **Flinch.** `applySecondaryStatus2` (`:1798-1813`) is silent for Inner
  Focus (correct for a non-certain flinch, wrong for Fake Out).
- **`cancelMultiTurnMoves`** (`:1815-1820`) mirrors `CancelMultiTurnMoves`
  for the represented state.
- **Move flags.** The importer already decodes `flags` and `priority`
  (`import/BattleMove.lua:45-46`). `getWhoStrikesFirst` already orders +3,
  +1 and −3 (`BattleFormulas.lua:661-685`).
- **End of turn.** `resolveEndTurn` (`:3832-3850`). No step reads the new
  per-turn state.
- **Controller.** `runTurn` returns the whole turn's events and
  `_runTurn` (`BattleSceneController.lua:680-724`) sets them as messages.
  A pre-turn event at the head of the list is therefore shown before any
  action text, with no flow change. `_eventMessages` (`:279`) maps event
  types to texts.

## Design

### State (all slices)

Added to `makeBattler`, all battle-only and never persisted
(`BattlePartyBridge.persistPartyBattler` writes HP, status1 and PP only):

```lua
protected = false,          -- gProtectStructs.protected (P1/P2); per turn
endured = false,            -- gProtectStructs.endured (P3); per turn
tookMoveDamage = false,     -- gProtectStructs.physicalDmg||specialDmg != 0 (P5); per turn
protectUses = 0,            -- gDisableStructs.protectUses (P2)
lastResultingMove = 0,      -- gLastResultingMoves (P2); 0 = MOVE_NONE, 0xFFFF = MOVE_UNAVAILABLE
isFirstTurn = 2,            -- gDisableStructs.isFirstTurn (P4); 2 = entered this turn
```

The engine adds:

- `self.runAttempted = false` (P5): `HITMARKER_RUN`, latched for the battle.
- `self.protectedMove` (P1): this action's `MISS_TYPE == B_MSG_PROTECTED`,
  reset in `resolveMove`.
- `self.actionIsLast` (P2): this action is the turn's second.

Lifetimes:

| Field | Reset |
| --- | --- |
| `protected`, `endured`, `tookMoveDamage` | both battlers at `runTurn` start, beside `targetNotAffected` (equivalent to `TurnValuesCleanUp(TRUE/FALSE)`: nothing reads them between turns); `recordFaint` |
| `protectUses`, `lastResultingMove` | fresh battler on switch-in; zeroed in `recordFaint` |
| `isFirstTurn` | `makeBattler` 2; `BattleEngine.new` sets both leads to **1** (`bm.c:2909`); the switch branch keeps 2; **`resolveForcedSwitch` sets 1** (it runs after `resolveEndTurn`, while source decrements after the replacement arrives, `bm.c:2964-2970`); decrement both (if > 0) at the end of `resolveEndTurn`; `recordFaint` sets 2 |

The counter mirrors source rather than a turn number (decision D6). The AI
can then read `user.isFirstTurn` directly, as `is_first_turn_for` does, and
a future Speed Boost can use the `!= 2` test (`bu.c:1858`).

### P1: the protected-target gate

**Predicate** (Lua 5.1, no bit ops):

```lua
-- DEFENDER_IS_PROTECTED (src/battle_script_commands.c:42) with the singles
-- target reduction: a USER-target move's gBattlerTarget is the user
-- (battle_controller_player.c:460-466), never protected while it acts.
function BattleEngine:protectBlocks(defender, move)
  if not defender.protected then return false end
  if math.floor((move.flags or 0) / 2) % 2 ~= 1 then return false end   -- FLAG_PROTECT_AFFECTED
  return math.floor((move.target or 0) / MOVE_TARGET_USER) % 2 ~= 1
end
```

**The attackcanceler step.** In `resolveMoveCore`, after the cancellers and
the locked 0-PP check, and **after the charge block's second-turn arm**:

- Turn 1 is exempt and returns inside the block. Turn 2 has already cleared
  the lock and the semi-invulnerable bit and set `noPPDeduct`, which is
  exactly what `CancelMultiTurnMoves` plus `TwoTurnMovesSecondTurn` do.
  Placing the step after the arm avoids clearing `charging` before the
  block reads it.
- Solar Beam in sun reaches the arm with `charging` already set, so it is
  gated, as in source.

The step itself:

1. `local rampageLocked = <as today>`. Capture this **before** the cancel,
   so the PP rule is unchanged.
2. `if self:protectBlocks(defender, move) then self.protectedMove = true;
   self:cancelMultiTurnMoves(attacker) end`.

Then each family reads `self.protectedMove`. The `protected{side, target}`
event replaces the generic texts:

| Engine site | Change when `protectedMove` |
| --- | --- |
| Shared accuracy step (`:2502-2515`) | Treat it as a miss **before** the semi-invulnerable test and the roll (no draw). Applies to every family that reaches the shared step with an `accuracycheck` or `NO_ACC_CALC` in source: shape A, OHKO and Pain Split (shape C), always-hit and Vital Throw. **Not** when `tickleGateFails`: Tickle's gate text wins. |
| Miss branch (`:2537-2601`) | Order: (a) `HITS_UNDERGROUND` → the existing typecalc query, `noEffect` if immune, else `protected`; (b) Jump Kick → `protected`, then the crash, **skipping** the immunity query (like `semiMiss`); (c) rampage → `protected`, **no** `targetNotAffected` query; (d) OHKO and Pain Split → `protected` (not `moveFailed`); (e) otherwise `protected`. PP: unchanged rule, using the captured `rampageLocked`. A charge turn 2 spends none (`noPPDeduct`). |
| Explosion (`:2107`) | No `accuracyRoll`. `noEffect` if immune, else `protected`. The user still faints (`settleExplosion(false)`). The crit and damage draws stay before. |
| Endeavor HP gate (`:2132-2135`) | `protected` instead of `moveFailed`. Otherwise the shared step gives `protected`. |
| Confuse / Teeter Dance (`:2138-2157`) | The Own Tempo and already-confused texts stay. The accuracy step gives `protected`, no draw. |
| Swagger / Flatter (`:2170`) | No roll; `protected` (PP spent as today). |
| Snore awake (`:2195-2199`) | `protected` instead of `moveFailed`. The asleep path reaches the shared step and gives `protected`. |
| Leech Seed (`:2256`) | No roll. `leechSeed{result="evaded"}`. |
| Nightmare (`:2270-2285`) | The fail paths emit `protected` instead of `moveFailed`. **The success path is unchanged (it lands).** |
| Curse, Psych Up, Haze, Hail, all `USER` moves | Never gated (the predicate is false). |
| Mean Look (`:2366-2381`) | After the semi-invulnerable test, `protected` before the already-prevented gate. |
| Primary status (`resolvePrimaryStatusMove`, `:1691-1748`) | `failed()` emits `protected`. `already`, `prevented`, `stayedAwake` and `notAffected` stay. The final `accuracyRoll` is replaced by `protected`, no draw. |
| Memento (`:2642`) | Before the both-at-minimum gate: `mementoHP`, `protected`, `checkFaint(attacker)`. No stat change. |
| Triple Kick (`resolveTripleKick`) | The first iteration's accuracy is `protected` (0 hits, no count event). |
| Multi-hit, fixed damage, Super Fang, Psywave, trap, Rapid Spin, Brick Break, recharge, Struggle | Covered by the shared step. They never reach their tails. |

The miss and `noEffect` rows also guarantee that no protected path calls
`applyDamage`, the secondary tails or the no-effect discarded rolls.

**Events and texts:** `protected{side, target}` → "<target>\nprotected
itself!". No other P1 event.

**P1 changes no replay.** `protected` is never set until P2.

### P2: Protect and Detect

- `supportsMove`: admit `EFFECT_PROTECT` (111) with power 0 and target
  `USER`.
- `runTurn` sets `self.actionIsLast`:
  - true for the second entry of the move loop;
  - true for the foe's move in the switch, capture and failed-run branches
    (it follows the player's action);
  - false otherwise.
- **Last resulting move.** `resolveMoveCore` sets `self.moveObeyed = true`
  at the attackcanceler step, that is, after the cancellers, the locked
  0-PP check and the defensive noPP return.
  - `resolveMove` then writes `attacker.lastResultingMove = moveObeyed and
    effectiveMoveId or 0xFFFF`. Struggle gives 165.
  - Item, run and switch actions never call `resolveMove`, so the value is
    kept (§1).
  - A battler that faints or switches is reset as described under State.
- **Branch** (after the cancellers, beside Refresh):
  1. Emit `useMove`, then spend PP.
  2. If `lastResultingMove` is not 182, 197 or 203, set `protectUses = 0`.
  3. `local r = self.rng:next16()` (always one draw).
  4. Look up the rate in `PROTECT_SUCCESS_RATES[protectUses]` = `{[0]=0xFFFF,
     0x7FFF, 0x3FFF, 0x1FFF}`. Index ≥ 4 follows decision D1.
  5. If `rate >= r and not self.actionIsLast`: set `protected = true`,
     `protectUses += 1`, and emit `protect{side, result="protected"}`.
  6. Otherwise: `protectUses = 0` and `protect{side, result="failed"}`.
- **AI:** none. `AI_CheckBadMove` has no row, so it scores 0 (already
  true).
- **Texts:** "X protected\nitself!" / "But it failed!".

### P3: Endure

- Admit `EFFECT_ENDURE` (116). It uses the same branch, setting
  `endured = true` and `result = "braced"` ("X braced\nitself!").
- **Clamp.** `applyDamage(…, opts)` gains `opts.noAdjust` (passed only by
  Super Fang, `:2893`).
  - Before the HP subtraction: `if not opts.noAdjust and defender.endured
    and defender.hp <= damage then damage = defender.hp - 1; endured = true
    end`.
  - The event gets `endured = true`.
  - The False Swipe clamp (`:3072`) stays where it is. When both apply, the
    result is the same `hp - 1` and the ENDURED text still prints, because
    `endured` is checked independently (`bsc.c:1606-1609`).
- **OHKO** (`:2942`): the clamp applies through `applyDamage`. There is no
  OHKO text in the engine today, so only ENDURED is added.
- **Multi-hit / Triple Kick:** after a hit whose damage event has
  `endured`, stop the loop, as for a KO. Emit `multiHit` with `endured =
  true`. Then follow the existing tail (one `seteffectwithchance` roll for
  the 2-5 family and Double Kick/Twineedle).
- **Pain Split, crash, recoil, confusion and end-of-turn damage** do not use
  `applyDamage` and are unaffected (correct).
- **Text order.** The controller prints "<target> ENDURED\nthe hit!" after
  the invisible HP entry and **before** the effectiveness lines (the
  `damage` event), or before effectiveness and "Hit N time(s)!" (the
  `multiHit` event).

### P4: Fake Out

- **The `isFirstTurn` counter**, as described under State.
- **Branch** after the cancellers. The P1 step has already run.
  - `if attacker.isFirstTurn == 0`: emit `useMove`, spend PP, then
    `protected` if `protectedMove`, else `moveFailed`.
  - Otherwise fall through to the ordinary hit with a new
    `FLINCH_CERTAIN_MOVES[158]` tail.
- **Tail on a landed hit:** no roll.
  - If the target is above 0 HP: Shield Dust → silent; Inner Focus →
    `flinchPrevented{side=target, ability=39}`; else set `flinched` if
    `flinchTargetPending`.
  - `applySecondaryStatus2` gains a `certain` parameter so that the Inner
    Focus text is emitted only for this caller.
- **No-effect hit:** add 158 to the discarded-roll list (`:3044-3055`).
- **AI:** port `AI_CBM_FakeOut`: `user.isFirstTurn == 0` → −10. Remove
  `UNPORTED_EFFECTS[158]` and its header paragraph
  (`AICheckBadMove.lua:111-115`, `:676`).
- **Text:** "<target>'s INNER FOCUS\nprevents flinching!".

### P5: Focus Punch

- **Pre-turn hook** in `runTurn`, right after `turnStart` and the
  locked-action substitution, before every branch:
  - `if playerAction.action == "run" then self.runAttempted = true end`.
    This is set before the hook, as source sets `HITMARKER_RUN` at
    selection. The controller vetoes for trainer and trapped runs never
    reach `runTurn`, which matches the source vetoes.
  - Then, unless `self.runAttempted`, for side in {player, foe}: if the
    side was not locked at turn start, its action is a move whose slot
    holds move id **264** (`MOVE_FOCUS_PUNCH`), it is not asleep and not
    all-0-PP (Struggle), emit `focusPunchSetup{side}`.
  - No RNG. Its position relative to the speed-tie draw is unobservable.
- **Damage record.** `applyDamage` sets `defender.tookMoveDamage = true`
  when `defenderSide ~= attackerSide` and the **actual** damage is > 0.
  - Pain Split, end-of-turn damage, crash and recoil do not use
    `applyDamage` for the defender, which matches the source exclusions.
- **Branch** after the cancellers (`move.effect == 170`):
  - If `attacker.tookMoveDamage`: spend PP (guarded) and emit
    `focusLost{side}`. **No `useMove`.** Return. This comes before the P1
    protected handling.
  - Otherwise continue on the ordinary hit path; P1 applies.
- **Text:** "X is tightening\nits focus!" and "X lost its\nfocus and
  couldn't move!".

### main.lua

**No slice changes `main.lua`.**

- The pre-turn text is an engine event at the head of `runTurn`'s list.
  The controller already shows a turn's events in order once both actions
  are chosen. That is the same point as the source hook: after selection
  and ordering, before the first action.
- The voluntary-switch callback (`main.lua:1653-1697`) renames the player
  before `_runTurn`. A foe's setup text names the foe, and a player cannot
  both switch and use Focus Punch, so nothing changes.
- The run latch and every counter are engine fields.
- The forced-switch replacement goes through `resolveForcedSwitch`, which
  P4 extends.
- The AI change lives in `AICheckBadMove.lua`, called from `TrainerAI.lua:112`
  with `engine.foe`.

### Deferred and dropped

- **`protectUses` ≥ 4** beyond the ROM-verified words (D1).
- **Substitute** (the gates and the Focus Punch record), **Focus Band** (an
  Endure-like clamp with a `% 100` draw at every adjust site), **Lock-On /
  Mind Reader** (they do not bypass Protect anyway, `bsc.c:1040-1042`),
  **Magic Coat / Snatch** precedence, **Truant** (Focus Punch hook),
  **Quick Claw**.
- **Bide, Counter, Mirror Coat, Future Sight, Rollout, Fury Cutter, Uproar,
  Pursuit:** `CancelMultiTurnMoves` also resets Rollout, Fury Cutter, Uproar
  and Bide, which is not represented.
- **Sleep Talk, Metronome, Mirror Move or Assist calling Protect.**
- **Levitate's `B_MSG_GROUND_MISS`** text in the Earthquake miss path (no
  Levitate model).
- **Doubles:** the attackcanceler target, `MOVE_TARGET_BOTH` and the
  last-action rule.
- **The AI CheckViability rows** (`AI_CV_Protect`, `AI_CV_Endure`,
  `AI_CV_FakeOut`, `AI_CV_FocusPunch`, `get_protect_count`).

## Events and controller texts

The P1-P5 task files should list `BattleSceneController.lua` under MAY
CHANGE (texts only) and `main.lua` under MUST NOT CHANGE.

| Event | Text (source) | Order |
| --- | --- | --- |
| `protected{side, target}` (P1) | "Y\nprotected itself!" (`msg.c:66`) | after "used", where the miss text would be |
| `leechSeed{result="evaded"}` (reused) | "Y evaded\nthe attack!" (`msg.c:160`) | |
| `protect{side, result}` (P2/P3) | "X protected\nitself!" / "X braced\nitself!" / "But it failed!" (`msg.c:155`, `:206`, `:336`) | after "used" |
| `damage{…, endured=true}` (P3) | "Y ENDURED\nthe hit!" (`msg.c:207`) | after the HP entry, before effectiveness |
| `multiHit{…, endured=true}` (P3) | the same | before effectiveness and "Hit N time(s)!" |
| `flinchPrevented{side, ability}` (P4) | "Y's INNER FOCUS\nprevents flinching!" (`msg.c:296`) | after effectiveness |
| `focusPunchSetup{side}` (P5) | "X is tightening\nits focus!" (`msg.c:224`) | immediately after `turnStart`, player first |
| `focusLost{side}` (P5) | "X lost its\nfocus and couldn't move!" (`msg.c:254`) | no "used" line |
| `moveFailed` (reused) | "But it failed!" | Fake Out after turn 1 |

Also update the header event list (`BattleEngine.lua:21-100`).

## Slices

| Slice | Content | Unlocks (inventory test authoritative) |
| --- | --- | --- |
| P1 | Field `protected` (and its reset); `protectBlocks`; the attackcanceler step (after the charge arm, with `rampageLocked` captured first); every row of the P1 table; `protected` event and text | none (no admission change); documents shapes A-E |
| P2 | Fields `protectUses`/`lastResultingMove`; `moveObeyed`; `actionIsLast`; Protect/Detect branch with one draw; `recordFaint` reset; D1 table; texts | 182, 197 admitted (expected 301/53); row 111 → R |
| P3 | Field `endured`; Endure branch; the `applyDamage` clamp with the Super Fang opt-out; OHKO; multi-hit and Triple Kick stop; text order | 203 admitted (expected 302/52); row 116 → R |
| P4 | Field `isFirstTurn` (`new`, `resolveForcedSwitch`, end-of-turn decrement, `recordFaint`); first-turn gate; certain flinch with the Inner Focus text; no-effect roll; `AI_CBM_FakeOut` | 158 leaves the uncovered list (`admitted_uncovered_positive` 26 → 25); row 158 → R |
| P5 | Field `tookMoveDamage`; `runAttempted` latch; the pre-turn hook; lost-focus branch; texts | 170 leaves the uncovered list (→ 24); row 170 → R |

P2 depends on P1. P3 depends on P2 (shared branch and counter). P4 and P5
depend on nothing. Recommended order: P4, P5, P1, P2, P3 (D3).

## Verification plan

- **P1** (the flag set directly on the defender):
  - Shape A on a representative of every table row:
    - "used", then `protected`; no RNG consumed (compare the stream);
    - PP −1, and 0 stays 0 on a locked rampage;
    - no damage, no secondary, no wrap, no recoil or drain, no recharge
      lock;
    - no multi-hit count draw; Brick Break keeps the screens; Rapid Spin
      keeps the seed.
  - Always-hit, Vital Throw and Thunder in rain are protected (protect
    precedes the sure-hit). OHKO and Pain Split give `protected`, not
    `moveFailed`.
  - Shape B: each gate text keeps priority; the Substitute and "any status"
    `moveFailed` → `protected`; Thunder Wave against a Ground target keeps
    "doesn't affect".
  - Shape D:
    - Leech Seed `evaded`, no draw.
    - Nightmare on an asleep target **lands**; on an awake one it gives
      `protected`.
    - Memento: the user faints, no stat change, and it never fails at
      −6/−6.
    - Explosion: crit and damage draws taken, no accuracy draw, the user
      faints; "doesn't affect" against a Ghost.
    - Earthquake against a Flying target gives `noEffect`, otherwise
      `protected`.
    - Jump Kick into a protected Ghost: `protected`, then a 1-HP crash.
    - Endeavor in both HP orders gives `protected`.
    - Snore awake and asleep.
  - Shape E: Ghost Curse curses a protected target; Psych Up copies; Haze
    and Hail work.
  - Multi-turn:
    - a protected turn-2 Fly lands with no PP spent, and the next turn is
      unlocked;
    - a protected locked Thrash: rampage over, no fatigue confusion,
      unlocked;
    - turn-1 charge against a protected target still charges.
  - Residuals still tick on a protected battler.
  - `protected` resets at the next `runTurn`.
- **P2:**
  - Draw count: exactly one on success, on probability failure and on
    last-mover failure; zero when a canceller stops the user.
  - The success thresholds 0xFFFF, 0x7FFF, 0x3FFF and 0x1FFF on fixed
    streams (r = threshold passes, r = threshold+1 fails).
  - The chain:
    - Protect → Detect → Endure share one counter;
    - an intervening Tackle resets it;
    - a full paralysis, flinch, sleep or confusion self-hit resets it
      (`0xFFFF`);
    - **a Poké Ball turn or failed run does not reset it**;
    - a switch or faint resets it;
    - a failure resets to 0 (the next use is certain).
  - Last-mover: Protect against Protect; a foe Protect after a player
    switch, ball or failed run fails with its draw.
  - Texts. AI score 0.
- **P3:**
  - Endure at full HP against an over-kill hit: 1 HP left and ENDURED
    before "super effective".
  - At 1 HP: 0 damage, ENDURED.
  - False Swipe + Endure prints ENDURED.
  - Super Fang KOs a 1-HP Enduring target.
  - Sonic Boom, Seismic Toss, Psywave and OHKO are clamped (OHKO still
    draws).
  - Explosion is clamped.
  - A multi-hit stops at the endured hit (count, draws, the final roll).
  - Triple Kick stops.
  - The endured flag clears next turn; end-of-turn poison still KOs.
- **P4:**
  - Turn 1 succeeds; turn 2 gives `moveFailed`.
  - A voluntary switch-in on turn N succeeds on N+1 only. A forced
    replacement after turn N succeeds on N+1 only. Leads succeed on turn 1
    only.
  - Flinch only when Fake Out moves first. Shield Dust is silent. Inner
    Focus gives the text.
  - A Ghost target: `noEffect` plus one discarded draw. A KO: no flinch, no
    text. Against a protected target: `protected` on both paths.
  - AI −10 after turn 1, 0 on the first turn.
- **P5:**
  - Setup text order (player then foe, before every action text including
    a switch or ball).
  - No text: when locked, asleep, on Struggle, after any failed run (for
    the rest of the battle, both sides), and on the run turn itself.
  - Text when frozen, paralyzed or confused.
  - Lost focus after any damaging hit this turn, with PP spent and no
    "used".
  - Focus kept: no hit, a miss, a protected or no-effect hit, a Pain Split,
    a 0-damage False Swipe, damage taken last turn.
  - When the user moves first (the foe switches or throws a ball), Focus
    Punch hits.
- **All slices:**
  - Controller text order through the real engine.
  - ROM record fixtures for moves 182, 197, 203, 252 and 264 (effect,
    priority, flags).
  - The no-ROM suite, the repository checker, and an independent review.

## Decisions for review

- **D1 (protect-rate overflow).** `protectUses` reaches 4 after four
  consecutive successes (1/64 of five-use chains). The fifth use reads past
  `sProtectSuccessRates`.
  - Recommendation: P2 includes a guarded ROM probe. Locate the 8-byte
    table `FF FF FF 7F FF 3F FF 1F` in the verified ROM and record the
    following u16 words. In source order they are expected to be
    118, 165, 166, 102, 0xFFFE.
  - Extend `PROTECT_SUCCESS_RATES` with the verified words through index 7,
    and `error()` beyond. Index 8 is unreachable in practice: about
    1e-13 per chain.
  - Until the probe runs, P2 records index ≥ 4 as `UNKNOWN` and errors
    loudly rather than inventing a cap.
- **D2 (P1 as infrastructure).** Ship the gate before any move can set it,
  tested by setting the flag directly.
  - Recommendation: yes. It is the riskiest change (every family), and
    isolating it keeps replays stable and reviews focused.
  - The alternative is merging P1 into P2.
- **D3 (order).** P4 and P5 fix moves that are already admitted and are
  independent.
  - Recommendation: land them first; P1-P3 follow.
- **D4 (run latch).** Model `HITMARKER_RUN`'s battle-long suppression of the
  Focus Punch setup text.
  - Recommendation: yes. It is one engine flag, and it is source behaviour,
    not a bug fix.
- **D5 (protect bypasses).** Model Nightmare landing through Protect, and
  Ghost Curse and Psych Up ignoring it, exactly as source.
  - Recommendation: yes. Mark them in tests as surprising-but-source.
- **D6 (`isFirstTurn` representation).** A mirrored 2/1/0 counter
  (recommended) or a "first turn number" field.
  - The counter matches `is_first_turn_for`'s raw value and Speed Boost's
    `!= 2` test.
  - It needs the `resolveForcedSwitch` = 1 special case, because the engine
    resolves replacements after its end-of-turn step.
- **D7 (Endure event shape).** An `endured` flag on `damage` / `multiHit`
  (recommended, because it keeps the HP entry and the text adjacent) or a
  separate event between them.

## RNG notes

- **P1:** none on its own (the flag is never set).
- **P2:** one `Random()` per Protect/Detect that passes the cancellers.
  Against a protected target, the blocked move **loses** every draw from
  its `accuracycheck` onward: accuracy, crit, damage random, secondary
  `% 100`, multi-hit count, Psywave sample, OHKO, trap duration, the
  Conversion and Tri Attack rolls. The exceptions keep their pre-accuracy
  draws:
  - Explosion (crit and damage random);
  - Magnitude (strength);
  - the cancellers (freeze, confusion, paralysis);
  - Jump Kick, which adds one crash `adjustnormaldamage` random draw.
- **P3:** one `Random()` per Endure. The multi-hit and Triple Kick early
  stop removes the remaining per-hit crit and damage draws (and Triple
  Kick's per-hit accuracy draws).
- **P4:** a Fake Out against a Ghost gains its discarded `% 100`. **Replays
  with a Fake Out against a Ghost diverge from its first use.** A landed
  Fake Out draws nothing (unchanged). Fake Out after turn 1 loses all its
  hit draws (it now fails).
- **P5:** a lost-focus Focus Punch loses all its hit draws. The hook draws
  nothing.
- Pre-existing and unchanged: the tracked plain-hit zero-byte roll gap
  (Focus Punch's successful hit inherits it), `gRandomTurnNumber`, and the
  battle-start tie draw.

## Risks

- **R1. Breadth of P1.** The gate touches about 40 engine sites.
  Mitigation: D2 (flag-only slice), one helper, and the table above as the
  review checklist. Existing tests cannot change, because the flag is
  false.
- **R2. The charge-arm ordering hazard.** Running `cancelMultiTurnMoves`
  **before** the charge block would clear `charging` and send a protected
  turn-2 Fly down the turn-1 arm (charging again).
  - Likewise, computing `rampageLocked` after the cancel would decrement a
    locked 0-PP rampage below 0.
  - Both are pinned by tests.
- **R3. Today's divergences.** Fake Out and Focus Punch are admitted as
  plain hits, so seeded replays containing them shift when P4 or P5 lands:
  - a no-effect Fake Out gains a draw;
  - a turn-2 Fake Out stops hitting;
  - a hit Focus Punch user stops attacking.
- **R4. Mid-turn halt (existing).** The engine halts a turn after certain
  faints, and the halted battler never acts. That does not affect Protect's
  last-action rule (a halted battler takes no action). It is unchanged
  here.
- **R5. Non-move actions.** The chain survives a ball or failed run, and a
  Focus Punch user is "first mover" after a foe switch. Both are easy to
  break by resetting state in the hoisted branches. Tests pin both.
- **R6. D1 evidence.** P2 cannot reach `R` for index ≥ 4 without a verified
  ROM environment.
- **R7. Ownership.** The controller changes are texts only. If the
  controller belongs to another lane, P1-P5 need that owner's sign-off for
  the text cases and nothing else. `main.lua` is untouched.

## Surprising source behaviour (summary)

1. **A failed wild run silences Focus Punch for the rest of the battle.**
   `HITMARKER_RUN` is never cleared after it is set (only `gHitMarker = 0`
   at battle start, `bm.c:2257`). The setup text then never prints for
   either side, although Focus Punch still works.
2. **Protect's consecutive-use counter has no cap.** The fifth consecutive
   use after four successes reads past the four-entry rate table, probably
   into `sMovesForbiddenToCopy` (about 0.18%). This needs ROM confirmation.
3. **A last-moving Protect still draws `Random()`** before failing (operand
   order, `bsc.c:6231`).
4. **Protect does not stop Ghost Curse or Psych Up** (`flags = 0`; the
   Curse clause in `attackcanceler` is dead code). It also does not stop
   **Nightmare on a sleeping target**: Nightmare has no accuracy check, so
   only its failure texts change.
5. **Leech Seed into Protect prints "evaded the attack!"**, not "protected
   itself!".
6. **Memento into Protect still knocks out the user** and can no longer
   fail.
7. **Jump Kick into Protect crashes even against a Ghost.** The protect path
   skips the immunity scan that a normal miss runs.
8. **"But it failed!" turns into "protected itself!"** for Fake Out after
   turn 1, an awake Snore, Endeavor's HP gate and the status moves'
   Substitute or "already statused" gates, whenever the target is
   protected. The `MISSED` mark set by `attackcanceler` drives
   `resultmessage`.
9. **Endure does not survive Super Fang at 1 HP.** Super Fang has no adjust
   step. It does survive fixed damage, OHKO and Explosion.
10. **"ENDURED the hit!" prints before "It's super effective!"**:
    `resultmessage` re-enters itself.
11. **A protected locked Thrash ends the rampage without confusion. A
    protected turn-2 Fly or Solar Beam lands, spends no PP and unlocks.**
12. **The Protect chain survives a Poké Ball turn or a failed run**, but any
    cancelled move resets it.
13. **Focus Punch's lost-focus path prints no "used" line.** Pain Split
    damage and a 0-HP False Swipe do not break focus. The setup text
    ignores freeze and paralysis (only sleep suppresses it), and it follows
    battler-id order, not turn order.
14. **Haze and Hail carry `FLAG_PROTECT_AFFECTED`** but target the user, so
    they are never blocked in singles.
15. **`jumpifaffectedbyprotect` (0x40) is unused.** Protect is checked only
    in `attackcanceler`, `accuracycheck` and `ChangeStatBuffs`.
16. **Fake Out re-runs `attackcanceler`** (via `BattleScript_EffectHit`)
    harmlessly. Against a Ghost it still takes a discarded `% 100` draw,
    which the engine misses today.
