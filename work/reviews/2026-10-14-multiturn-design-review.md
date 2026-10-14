# Review: Phase 4 locked multi-turn design proposal (charge and recharge)

- Record role: `REVIEW`
- Reviewer: independent design Reviewer (no authorship of the proposal)
- Date: 2026-10-14
- Subject: `work/reports/phase4-multiturn-design-proposal.md` at commit `5dab7a4`
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
  (`src/battle_main.c`, `src/battle_util.c`, `src/battle_script_commands.c`,
  `data/battle_scripts_1.s`, `src/battle_message.c`, `include/constants/battle.h`,
  `src/data/battle_moves.h`, `data/battle_ai_scripts.s`,
  `src/battle_controller_opponent.c`)
- Project code read at `5dab7a4`: `src/core/BattleEngine.lua`,
  `src/core/BattleSceneController.lua`, `src/core/TrainerAI.lua`,
  `src/core/AICheckBadMove.lua`, `src/core/EarlyRivalAI.lua`,
  `src/core/BattlePartyBridge.lua`, `main.lua` (read only)
- Scope: the design proposal only. Implementation commit `6c23139`, which
  landed on the same branch after `5dab7a4` and before this review, is **not**
  reviewed here (see finding 12).

## Verdict

**PASS WITH CORRECTIONS**

The architecture is sound and source-faithful: lock state on the battler, no
menu and no AI for a locked side, the recharge canceller between freeze and
flinch, a `cancelMultiTurnMoves` helper, `chargeTurn`/`mustRecharge` events,
and turn 2 without PP. Family membership, script line numbers, string texts
and most citations check out. One source fact is misstated (when
`rechargeTimer` is decremented). The cancel-point list and the AI claim are
wrong. Several engine and controller seams that the implementation must
handle are not specified. Apply the correction texts below to the proposal
(or the task file) before implementation is accepted. None of them needs a
redesign or human input. No `UNKNOWN` source behavior remains for M1.

## Verified correct (no change needed)

- `STATUS2_MULTIPLETURNS` = bit 12 and `STATUS2_RECHARGE` = bit 22
  (`include/constants/battle.h:115,122`).
- Action selection, `battle_main.c:3125-3130`: a battler with either bit gets
  `B_ACTION_USE_MOVE` and `STATE_WAIT_ACTION_CONFIRMED_STANDBY`. No
  `BtlController_EmitChooseAction` is sent, so no FIGHT/BAG/POKEMON/RUN menu
  is shown and no item, switch or run is possible. The opponent AI runs only
  inside the opponent controller's handlers:
  `battle_controller_opponent.c:1341` `AI_TrySwitchOrUseItem` (choose action),
  `:1355-1359` `BattleAI_SetupAIData`/`BattleAI_ChooseMoveOrAction`, and the
  wild `Random() & 3` at `:1389` (choose move). None of these handlers is
  called, so a locked foe draws no AI RNG and no wild move-pick RNG.
- Move choice, `battle_main.c:3989-3992`: `gCurrentMove = gLockedMoves[...]`.
  `gCurrMovePos = gChosenMovePos = chosenMovePositions[...]` (`:3980`) keeps the
  slot chosen on turn 1, because selection never rewrites it for a locked
  battler. `GetWhoStrikesFirst` (`:3490,3499`) also reads that slot.
- `CancelMultiTurnMoves` body (`battle_util.c:203-214`). It does **not** clear
  `STATUS2_RECHARGE`.
- Recharge script (`battle_scripts_1.s:1107-1111`): accuracycheck first. A miss
  goes to `BattleScript_PrintMoveMissed` (`:276-284`), which runs attackstring
  and ppreduce but has no seteffectwithchance, so there is no recharge and no
  Random().
- `seteffectwithchance` (`battle_script_commands.c:2774-2800`). The CERTAIN
  branch applies with no Random() when the move had an effect. It runs before
  `tryfaintmon` (`bs1.s:268-269`), so recharge also follows a KO. A no-effect
  hit falls to the rolling branch: `Random() % 100` is the first `&&` operand,
  so it is drawn, and nothing is applied.
- `SetMoveEffect` RECHARGE (`bsc.c:2600-2605`) and CHARGING (`:2477-2481`, which
  also sets `gLockedMoves`).
- `CANCELLER_RECHARGE` (`battle_util.c:1349-1358`) sits after ASLEEP/FROZEN/TRUANT
  and before FLINCH. It clears the bit and the timer, calls
  `CancelMultiTurnMoves`, and runs `BattleScript_MoveUsedMustRecharge`
  (`bs1.s:1113-1116`, "{B_ATK_NAME_WITH_PREFIX} must\nrecharge!",
  `battle_message.c:185`). No attackstring, no PP.
- Turn 1 (`bs1.s:794-806`): attackcanceler, `printstring STRINGID_EMPTYSTRING3`
  (empty, so turn 1 has **no** "used" text), ppreduce, attackanimation,
  `MOVE_EFFECT_CHARGING | AFFECTS_USER` through seteffectprimary, then
  `gFirstTurnOfTwoStringIds`. The four texts match `battle_message.c:135-138`.
  Skull Bash raises DEF +1 after the text (`bs1.s:1812-1818`). At +6 it is
  silent: `ChangeStatBuffs` with `STAT_CHANGE_ALLOW_PTR` returns WORKED with
  `B_MSG_STAT_WONT_INCREASE` (`bsc.c:6796-6815`), and the `jumpifbyte` skips the
  text.
- Turn 2 (`bs1.s:784-792`): attackcanceler, then `clearstatusfromeffect`
  clears MULTIPLETURNS and sets `HITMARKER_NO_PPDEDUCT`, and the hit runs from
  accuracycheck, with attackstring printed (also on a miss). Sky Attack:
  `MOVE_EFFECT_FLINCH` with `secondaryEffectChance` 30, plus one crit stage
  (`bsc.c:1186`). Both happen on turn 2 only, because turn 1 has no
  critcalc/seteffectwithchance.
- Solar Beam (`bs1.s:1899-1913`): Cloud Nine/Air Lock force the charge
  branch, sun fires on turn 1, and every other case charges.
- Family membership (`battle_moves.h` / `include/constants/battle_move_effects.h`):
  EFFECT_RAZOR_WIND 39 = Razor Wind; EFFECT_SKY_ATTACK 75 = Sky Attack;
  EFFECT_RECHARGE 80 = Hyper Beam, Blast Burn, Hydro Cannon, Frenzy Plant (all
  150 power / 90 acc / 5 PP); EFFECT_SKULL_BASH 145 = Skull Bash;
  EFFECT_SOLAR_BEAM 151 = Solar Beam. No other move uses these effects.
  Razor Wind has no extra crit stage (it is not in `Cmd_critcalc`).
- Faint clears status2 (`recordFaint`). Lock state is battle-only:
  `BattlePartyBridge.persistPartyBattler` writes only hp/status/moves(pp), and
  `battlerFromParty` builds a fresh battler.

## Findings

### 1. `rechargeTimer` decrement timing misstated — severity MEDIUM

Evidence: the proposal says the timer is "decremented at the turn's action
start (`src/battle_main.c:3641-3646`)". Those lines are inside
`TurnValuesCleanUp`. The `FALSE` (full) variant that decrements is called from
`BattleTurnPassed` at `:2970`, i.e. at **end of turn**. It runs after
`DoFieldEndTurnEffects`/`DoBattlerEndTurnEffects` and `HandleFaintedMonActions`
(the replacement send-out), and before the next `HandleTurnActionSelectionState`.
`TurnValuesCleanUp(TRUE)` at `:2957` does not touch the timer.
Consequences:
turn N Hyper Beam sets 2 → end of N: 1 (still RECHARGE, so turn N+1 selection
is skipped) → turn N+1: the canceller clears it. If the canceller is never
reached on N+1 (the battler is still asleep, still frozen, or does not act),
end of N+1 takes the timer to 0 and silently clears RECHARGE, so turn N+2 is
unlocked. "2" exists so the bit survives the same turn's end-of-turn cleanup.

Correction (replace the "Next turn:" bullet):

> - Timer: `rechargeTimer` is decremented in `TurnValuesCleanUp(FALSE)`
>   (`src/battle_main.c:3641-3646`), which `BattleTurnPassed` calls at the end of
>   every turn (`:2970`), after end-turn effects and faint replacement and
>   before the next action selection. When it reaches 0 it clears RECHARGE. So
>   2 → 1 at the end of the Hyper Beam turn. On the next turn the side skips
>   selection, and `CANCELLER_RECHARGE` clears the bit and the timer, calls
>   `CancelMultiTurnMoves` and prints "X must recharge!". The move is not used
>   and no PP is spent. If that canceller is not reached on the recharge turn
>   (still asleep, still frozen, or the battler did not act), the end-of-turn
>   decrement 1 → 0 clears RECHARGE with no message. The engine may decrement at
>   the end of `resolveEndTurn`, so that `isLocked = charging or recharging`.
>   Or it may decrement at the start of `runTurn`, provided `isLocked` treats
>   `recharging and rechargeTimer == 1` as unlocked. Either is equivalent, but
>   the design must name one.

### 2. Recharge canceller stops the canceller chain; wake/thaw continue into it — severity MEDIUM

Evidence: `AtkCanceller_UnableToUseMove` loops `while (... && effect == 0)`
(`battle_util.c:1531`). The recharge case sets `effect = 1`, so CONFUSED
(decrement and `Random() & 1`), PARALYSED (`Random() % 4`), FLINCH and IN_LOVE
never run on a recharge turn. Waking up (`:1297-1303`) and thawing
(`:1325-1331`) return `effect = 2` after `BattleScriptPushCursor()`. The
attackcanceler is re-entered with the tracker already advanced, so "woke up!"
or "was defrosted!" is followed by "must recharge!". Still asleep
(`BattleScript_MoveUsedIsAsleep`) or still frozen ends the action with no
recharge message, and finding 1 then applies.

Correction (add after the CANCELLER_RECHARGE bullet):

> - The recharge canceller ends the canceller chain (`effect = 1`,
>   `battle_util.c:1531`). On a recharge turn the confusion counter is **not**
>   decremented, and no confusion, paralysis or other canceller RNG is drawn.
>   A pending flinch prints nothing (it is cleared at end of turn). A recharger
>   that wakes up or thaws this turn prints that message, then "must recharge!".
>   One that stays asleep or frozen prints only "fast asleep"/"frozen solid",
>   and RECHARGE lapses at end of turn (finding 1). In `resolveStatusCancellers`
>   the recharge check returns immediately, before the flinch and confusion
>   blocks.

### 3. CancelMultiTurnMoves call sites incomplete; freeze sentence misleading — severity LOW-MEDIUM

Evidence (`grep CancelMultiTurnMoves|cancelmultiturnmoves` at the pin), all call sites:

| Site | Trigger | M1 relevance |
| --- | --- | --- |
| `battle_util.c:319` | Torment selection | n/a (locked battler never selects) |
| `battle_util.c:933,944,958` | Uproar end-turn | n/a (later slice) |
| `battle_util.c:1040` | Yawn puts battler to sleep | Yawn unmodeled |
| `battle_util.c:1340` | CANCELLER_TRUANT | Truant unmodeled |
| `battle_util.c:1354` | CANCELLER_RECHARGE | **yes** |
| `battle_util.c:1366` | CANCELLER_FLINCH (proposal says `:1364`) | **yes** |
| `battle_util.c:1378,1389,1400` | Disabled / Taunted / Imprisoned cancellers | unmodeled |
| `battle_util.c:1444` | CANCELLER_PARALYSED — **commented out** in C | the script does it instead |
| `battle_util.c:1476` | CANCELLER_IN_LOVE (can't attack) | unmodeled |
| `bsc.c:900` | attackcanceler: target protected and (not two-turn move, or MULTIPLETURNS set) | Protect unmodeled (later) |
| `bsc.c:2173` | SetMoveEffect sleep applied | **yes** |
| `bsc.c:2269` | SetMoveEffect freeze applied | **yes** |
| `bsc.c:6071` | `various CANCEL_MULTI_TURN_MOVES` (the script command) | via the two scripts below |
| `bsc.c:7982` | Spite leaves PP 0 | Spite blocked |
| `bsc.c:8165` | Rollout no effect | later slice |
| `bs1.s:3717` | `BattleScript_MoveUsedIsParalyzed` | **yes** |
| `bs1.s:3742` | `BattleScript_DoSelfConfusionDmg` | **yes** |
| `battle_main.c:2941-2942` | end of turn: asleep and MULTIPLETURNS | **yes** (defensive) |

The proposal lists the freeze application as a caller and also says "freeze
keeps the lock (CANCELLER_FROZEN does not cancel)". That is contradictory in
practice. Applying freeze clears MULTIPLETURNS, so a frozen battler never
holds a charge lock. The canceller distinction matters only for RECHARGE,
which `CancelMultiTurnMoves` never clears.

Correction (replace the last Source-facts bullet and the "Callers" sentence):

> - Cancel points represented in M1: sleep applied (`bsc.c:2173`, primary or
>   secondary), freeze applied (`bsc.c:2269`), the flinch canceller
>   (`battle_util.c:1366`), the recharge canceller (`:1354`), full paralysis
>   (`bs1.s:3717`, the script, since the C call at `battle_util.c:1444` is
>   commented out), the confusion self-hit (`bs1.s:3742`; "is confused!"
>   without a self-hit keeps the lock and the move fires), and end of turn
>   while asleep (`battle_main.c:2941-2942`). Unmodeled cancel points, to be
>   added with their features: Truant (`:1340`), Disable/Taunt/Imprison
>   (`:1378,1389,1400`), infatuation (`:1476`), Protect on turn 2 (`bsc.c:896-900`;
>   Protect does **not** stop turn 1), Spite to 0 PP (`bsc.c:7982`), Yawn
>   (`battle_util.c:1040`), Uproar (`:933-958`). None of these clears RECHARGE.
>   Applying sleep or freeze cancels the charge lock but not a pending
>   recharge, which then lapses by the timer if the sleep/freeze canceller
>   blocks the action.

### 4. Locked turn must bypass the engine's in-action Struggle and 0-PP guards — severity MEDIUM

Evidence: in source, `noValidMoves` is set only by `AreAllMovesUnusable`
(`battle_util.c:405-424`), which is called only during selection
(`battle_main.c:3147`). It is cleared every turn when `gProtectStructs` is
zeroed in `TurnValuesCleanUp(FALSE)` (`:3636-3639`). A locked battler skips
selection, so the `noValidMoves` branch (`:3982-3988`) never applies to it and
the order of `:3982` versus `:3989` does not matter. On turn 2 the attackcanceler
0-PP check is skipped while MULTIPLETURNS is set (`bsc.c:838-839`). So a charge
move whose last PP was spent on turn 1 still fires on turn 2, even if every
other slot is at 0 PP. The project engine computes `allMovesUnusable` and the
`slot.pp <= 0` → `noPP` guard **inside `resolveMoveCore` at action time**
(`BattleEngine.lua` at 5dab7a4, `resolveMoveCore` head). Without a bypass, it
would auto-Struggle or `noPP` a locked turn.

Correction (add to Design):

> - Locked turn in `resolveMoveCore`: when the attacker is charging or
>   recharging, skip the in-engine `allMovesUnusable` → Struggle substitution
>   and the `slot.pp <= 0` → `noPP` guard, and use `lockedSlot`. Source: no
>   selection, so `noValidMoves` is never set (`battle_util.c:405-424`, cleared
>   at `battle_main.c:3636-3639`). The attackcanceler PP check is skipped under
>   MULTIPLETURNS (`bsc.c:838-839`), and the recharge canceller runs before it.
>   Test: a charge move whose turn-1 ppreduce takes the last PP of the last
>   usable slot still hits on turn 2, and Struggle starts only on turn 3.

### 5. Foe lock must override every `runTurn` branch; locked player gets no non-move action — severity MEDIUM

Evidence: `runTurn` resolves the foe's move from `foeAction.moveSlot` in the
switch (`player switch`), capture and failed-run branches as well as the move
branch. `getWhoStrikesFirst` reads `moves[moveSlot]`. A locked foe still uses
its locked move while the player switches, throws a ball or fails to run
(source: the foe's action is USE_MOVE with `gLockedMoves`, whatever the player
does). The voluntary switch reaches the engine through
`controller:_runTurn({action="switch"})` (`main.lua:1689`). For the player
side, source offers no menu, so `run`, `capture` and `switch` cannot occur.

Correction (replace "runTurn ignores a locked side's chosen action and uses the locked slot"):

> - `runTurn`: a locked foe's action becomes `{action="move", moveSlot=lockedSlot}`
>   in **every** branch (player move, switch, capture, failed run). A locked
>   player's action becomes `{action="move", moveSlot=lockedSlot}`. The
>   controller never offers run/capture/switch to a locked player, and the
>   engine asserts or overrides if it receives one. It must not consume a ball,
>   run attempt or switch. Turn order uses the locked slot's move, as
>   `chosenMovePositions` does in source.

### 6. Controller skip needs explicit entry points — severity MEDIUM

Evidence: the controller reaches `ACTION` from `advanceMessage` (end of
messages), from `_setMessages` (an empty list falls through to the after-state),
from the `onMessagesComplete` follow-up (`main.lua:1556-1594`; the foe
replacement's "sent out" messages, then ACTION), and from forced or voluntary
switch callback entries. A locked player must run its turn at each of these,
without input. `main.lua`'s drive loops press A in MESSAGES/ACTION/MOVE
(`main.lua:3797-3890`), so they keep working if ACTION is never left resting.

Correction (replace the controller sentence):

> - Controller: one helper, called wherever the controller would enter ACTION
>   (`advanceMessage` end, the empty-list fall-through in `_setMessages`, which
>   also covers the `onMessagesComplete` follow-up and the switch-callback
>   entries). If the battle is not over, nothing is awaiting a forced switch,
>   and `engine:isLocked("player")` is true, it immediately calls
>   `_runTurn({action="move", moveSlot=player.lockedSlot})`, so no menu is
>   shown. `_runTurn` calls `chooseFoeMove` only when the foe is not locked.
>   Tests through the controller: (a) a locked player never rests in
>   ACTION/MOVE; (b) a locked foe does not call `chooseFoeMove` (spy) and RNG
>   draw counts match; (c) a non-locked foe facing a locked player still calls
>   it; (d) the foe-replacement follow-up path auto-runs a locked player's turn.

### 7. AI statement wrong — severity LOW

Evidence: `AI_CheckBadMove_CheckEffect` **does** contain
`if_effect EFFECT_RAZOR_WIND / EFFECT_RECHARGE / EFFECT_SKULL_BASH, AI_CBM_HighRiskForDamage`
(`data/battle_ai_scripts.s:128,151,183`, target `:372-380`). These are already
ported (`AICheckBadMove.lua:179-182,529,552,582`). Sky Attack (75) and Solar
Beam (151) have no CBM entry. `AI_CheckViability` has
`AI_CV_ChargeUpMove` (39/75/145/151, `:683,707,739,740`) and `AI_CV_Recharge` (80,
`:710,1694`). `EarlyRivalAI` (the only CHECK_VIABILITY user) errors on
unsupported effects (`EarlyRivalAI.lua:79`).

Correction (replace the AI bullet):

> - AI: AI_CheckBadMove already scores 39/80/145 through
>   `AI_CBM_HighRiskForDamage` (`battle_ai_scripts.s:128,151,183,372-380`; ported in
>   `AICheckBadMove.lua`), so nothing changes there. 75/151 have no CBM entry.
>   The AI_CheckViability terms `AI_CV_ChargeUpMove`/`AI_CV_Recharge` are out of
>   scope, and `EarlyRivalAI` keeps rejecting these effects loudly. The AI is
>   never consulted for a locked foe.

### 8. Turn-1/turn-2 details to pin down — severity LOW

Evidence: `bs1.s:784-806`, `bsc.c:819-860,2774-2800`.

Correction (append to the two-turn section):

> - Turn 1 runs the full canceller chain first. If any canceller stops it, there
>   is no PP, no lock and no text beyond the canceller's own. Turn 1 has no
>   accuracycheck, critcalc, damage or seteffectwithchance, so it draws no RNG
>   beyond the cancellers. PP is −1 from the turn-1 slot (`gCurrMovePos`).
> - Turn 2: MULTIPLETURNS is cleared **after** attackcanceler. Every turn-2
>   canceller therefore runs with the lock still set, and the cancelling ones
>   (finding 3) end it. The obedience check is also skipped under MULTIPLETURNS
>   (`bsc.c:848-849`; obedience unmodeled). `clearstatusfromeffect` zeroes the effect
>   byte, so Razor Wind/Skull Bash/Solar Beam turn 2 is a plain hit, and the
>   engine's existing tracked plain-hit seteffectwithchance gap applies
>   unchanged. Sky Attack rolls flinch with the existing
>   `secondaryEffectRoll` (`Random() % 100 <= 30`), under the existing
>   first-mover flinch rule.
> - Recharge: CERTAIN means no roll when the hit had an effect (including a KO
>   or a Substitute hit). A no-effect hit (Normal vs Ghost) draws one roll and
>   does not recharge. A miss draws nothing and does not recharge.

### 9. Lock across opponent faint/switch and skipped actions — severity LOW

Evidence: `HandleFaintedMonActions` runs before `TurnValuesCleanUp(FALSE)`
(`battle_main.c:2965-2970`). The lock bits belong to the attacker and are not
touched by the opponent's faint or switch-in. In singles the target is
re-resolved to the new opposing battler (`battle_main.c:4026-4080`). The
project engine halts a turn early after a faint that queues a forced switch.

Correction (add a Design bullet):

> - Persistence: a charge lock survives the opponent's faint, replacement or
>   voluntary switch and hits the new opponent on turn 2. A recharge after a KO
>   still costs the next turn. If a locked battler does not act in a turn
>   (the engine halts the turn after a faint, or the battle ends), the charge
>   lock is unchanged and a recharge lapses by the timer (finding 1). The locked
>   battler cannot switch voluntarily (no menu). Its own faint clears all lock
>   state (`recordFaint`). Lock state is never persisted to the party record.
>   Edge: if the lock is cancelled by sleep/freeze before the battler acts and
>   the move still proceeds that turn (20% thaw), HandleAction_UseMove picks
>   `moves[gCurrMovePos]` and turn 1 runs again (new charge text, PP spent again).

### 10. Solar Beam limit wording — severity INFO

Evidence: no weather source (Sunny Day, Drought) is supported by the engine,
so "always charges" is exact for every reachable state. For the later weather
slice: in sun, `BattleScript_SolarBeamOnFirstTurn` runs `ppreduce` **before**
jumping to the turn-2 script's attackcanceler (`bs1.s:1909-1914`), so a cancelled
sun Solar Beam still spends PP. Cloud Nine/Air Lock force charging.

Correction: replace "(limit)" with "(exact for every reachable state, since no
weather source is supported; a weather slice must add `bs1.s:1899-1913`,
including ppreduce before attackcanceler in sun)".

### 11. Minor citation fixes — severity INFO

- Flinch canceller `:1364` → `:1366` (the case starts at `:1361`).
- End-of-turn sleep cancel `src/battle_main.c:2941` → `:2941-2942`
  (`HandleEndTurn_ContinueBattle`, before end-turn effects).
- Skull Bash at +6 also sets `MOVE_RESULT_MISSED` (`bsc.c:6809-6810`). This is
  harmless on a no-damage turn and needs no event.

### 12. Process observation — severity INFO (for Orchestrator)

Implementation commit `6c23139` ("Multi-turn M1 ... Awaiting review", plus
`work/tasks/phase4-multiturn-m1.md`) landed on
`claude/wizardly-faraday-o45q9z` four minutes after the proposal, before this
design review. That work needs its own independent implementation review
against the corrected design. A brief look (not a review) shows it uses a
turn-start decrement with `isLocked` requiring `rechargeTimer > 1`, which is
equivalent to source under finding 1. It also adds a controller `_enterAction`
hook at the `advanceMessage`/`_setMessages` ACTION entries. The implementation
reviewer should check findings 2, 4, 5, 6 and 9 explicitly, including the
foe-locked switch/capture/run branches and the KO-recharge ordering relative
to the engine's faint checks.

## Disposition (Worker, 2026-10-14)

Corrections applied to the proposal. Implementation 6c23139 already followed F1 (equivalent turn-start decrement + timer>1 rule), F2, F4, F5, F6; tests added for F2, F5, F9 and the turn-1 canceller case.
