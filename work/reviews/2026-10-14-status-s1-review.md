# Review: status slice S1 (cancellers, burn/paralysis, defrost, end-of-turn damage)

- Reviewer: independent Reviewer (Claude). Read-only on project source; only this file was written.
- Date: 2026-10-14
- Artifact: commit `b8a5196` on `claude/wizardly-faraday-o45q9z` ("Status S1: cancellers,
  burn/paralysis modifiers, defrost, end-of-turn damage"). Task:
  `work/tasks/phase4-status-s1-groundwork.md`.
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`: local copies of
  `src/battle_util.c`, `src/battle_main.c`, `src/pokemon.c`, `src/battle_script_commands.c`,
  `data/battle_scripts_1.s` and `src/battle_message.c`. `include/constants/{battle_move_effects,moves,abilities,pokemon}.h`
  were fetched at the pin.
- Design basis: `work/reports/phase4-status-conditions-design-proposal.md` plus its review.
- Verdict: **NEEDS_FIX**. The per-mechanic ports match the source: cancellers, RNG, burn,
  paralysis, defrost, tick formulas, field-before-battler order, faint clearing status, and the
  persist mask. The defect is in how end-of-turn faints combine with the existing
  forced-switch queue. That code is new in this slice, and it can strand the scene controller
  (findings 1 and 2, both reproduced). Mutation testing also left four meaningful mutants alive
  (finding 3).

## What was verified (no finding)

**Cancellers** (`battle_util.c:1266-1333, 1439-1449, 1513-1525`)
- They run in source order: sleep, then freeze, then paralysis, then thaw. Flinch, confusion,
  Truant, recharge, Disable and the other cancellers between them are not modelled anywhere in
  the engine, so nothing is missing from the order.
- Sleep decrements first with no RNG draw. A result of 0 emits `wokeUp` and the move proceeds.
  This matches the source, where `BattleScript_MoveUsedWokeUp` returns and the canceller resumes.
- Snore and Sleep Talk use IDs 173 and 214 (`moves.h:177,218`). They are exempt only while the
  battler is still asleep, as in the source.
- Freeze draws `Random() % 5` on every frozen attempt. A thaw-hit move with a nonzero draw falls
  through to CANCELLER_THAW and prints "defrosted by". A zero draw uses `PKMNWASDEFROSTED2`.
  `EFFECT_THAW_HIT = 125` (`battle_move_effects.h:129`).
- Paralysis draws `Random() % 4 == 0` only when the battler is paralyzed.
- No canceller can deduct PP or emit `useMove`, because the call sits before `useMove` and before
  every `ppreduce` site: Magnitude, Explosion, Endeavor and the ordinary path.
- Auto-Struggle passes `MOVE_STRUGGLE` as the move ID, so the canceller still applies to it.
- Nothing in `resolveMoveCore` draws RNG before the canceller.

**Burn** (`pokemon.c:2539-2541`)
- Halving happens after `/50` and before Reflect, in the physical branch only.
- There is no crit gate, and Guts is exempt (`abilities.h:66` = 62). The minimum-1 clamp runs
  after both halvings.
- Struggle and Explosion receive the real attacker, so burn applies to them.
- `EarlyRivalAI.predictedDamage` now sees burn. That is consistent with the source AI damage
  calculation, which reads `gBattleMons` status.

**Paralysis speed** (`battle_main.c:3449-3450`)
- `/4` is applied after the stat stage.
- `effectiveSpeed` is called only from `getWhoStrikesFirst`. Run odds (`BattleEngine.lua:2316`)
  use the raw `.speed`.

**MOVEEND_DEFROST** (`battle_script_commands.c:4103-4116`)
- The conditions are: target frozen, target HP not 0, the target is not the attacker, and a
  Fire move that left `specialDmg` nonzero. Every target-damaging path, including multi-hit,
  goes through `applyDamage` (lines 1240, 1591, 1606, 1623, 1640, 1655, 1742, 2052, 2098).
- The HP changes that bypass `applyDamage` are all self HP or Normal type, so none can be a
  Fire hit: crash damage, Explosion's self-KO, Belly Drum, recoil (Struggle included), drain,
  Restore HP and Pain Split.
- False Swipe at 1 HP adds 0, which matches `gHpDealt = 0`.
- A cancelled move leaves `currentMove == nil` and the tally at 0, so it cannot defrost. The
  `self.currentMove` placement and the `not isOver()` gate are both equivalent to the source
  (mutants M10 and M15). No Gen 3 Fire move has recoil.
- The defrost event comes after all in-move events, matching moveend running after
  `seteffectwithchance` and `tryfaintmon`.

**End of turn** (`battle_util.c:805-841`, `battle_main.c:2958-2964`)
- Formulas: poison is `max(1, maxHP/8)`. For toxic, the counter is incremented first and capped
  at 15, then damage is `max(1, maxHP/16) * n`. Burn is `max(1, maxHP/8)`.
- Battlers at 0 HP are skipped. The tick message comes before the HP bar change
  (`printstring`, then `healthbarupdate`).
- Field effects run before battler effects.
- Battler order is the action order. Hoisted switch, item and run actions put the player first,
  which matches `SetActionsAndBattlersTurnOrder:3559-3592`.
  *(Superseded by weather slice W0: end-of-turn order is now recomputed as
  `ENDTURN_ORDER` does; see `work/tasks/phase4-weather-w0.md`.)*
- All six former `decaySideTimers` call sites now call `resolveEndTurn`, and no other caller
  remains.
- A faint that decides the battle stops the phase, because `BattleTurnPassed` re-tests
  `gBattleOutcome`.

**Faint and persistence**
- `recordFaint` zeroes status for every faint path, including both battlers in an Explosion.
- `persistPartyBattler` masks the toxic counter and keeps sleep turns.
- Every main.lua persist call site only writes the record. None reloads the live battler
  mid-battle, so the battle-local counter survives (`main.lua:1564,1618,1674,1694,4462`).
  Switch-ins reload from the record with counter 0, which matches the source.
- `healParty` clears status (`EarlyRivalRewards.lua:179`).

**Texts** match `battle_message.c` lines 90, 96, 100, 101, 102, 103, 106, 162 and 163 byte for
byte. Both canceller tables (`gWokeUpStringIds`, `gGotDefrostedStringIds`) map as implemented.

**RNG regression**: a status-free battler takes no new draws (test: 6 draws per turn). Existing
records all carry status 0: the starter, wild and trainer factories set 0, and `healParty` sets 0.

**Commands run**
- `lua5.1 tests/battle_status_engine_test.lua`: 69/0
- `lua5.1 tests/battle_scene_controller_test.lua`: 118/0
- `lua5.1 tests/battle_party_bridge_test.lua`: 32/0
- `lua5.1 tests/battle_engine_test.lua`: 568/0
- `bash scripts/test_all.sh`: PASS, 163 files (no-ROM mode)
- `lua5.1 scripts/check_repository.lua`: PASS

## Findings

### 1. Major: an end-of-turn faint that decides the battle leaves an earlier forced switch queued

**Evidence.**
- `finalizeFaintSequence` (`BattleEngine.lua:943-975`) sets `outcome` and returns without
  touching `pendingForcedSwitches`.
- Before S1, at most one faint sequence ran per turn, so the queue could not already hold an
  entry. S1 adds a second sequence per turn: the end-of-turn tick runs after a move-phase faint
  has already queued a replacement.
- Reproduced through the engine: the player is poisoned at 1 HP, KOs a foe that has a
  replacement, and is their side's last Pokémon. The result is `outcome = "playerLost"` while
  `awaitingForcedSwitch = "foe"`.
- Run through `BattleSceneController` with a hook that mirrors `main.lua:1555-1590`
  (`onMessagesComplete` resolves any pending `"foe"`):
  - The trainer sends out the next Pokémon after the loss.
  - The controller goes to `ACTION` instead of `COMPLETE`, so `isComplete()` is false and the
    whiteout or settlement never runs.
  - The next `runTurn` asserts "battle is already over".
- The source behaves differently. `HandleFaintedMonActions` case 4 runs
  `BattleScript_HandleFaintedMon`, whose `checkteamslost` / `gBattleOutcome != 0` path ends
  without a replacement (`battle_util.c:1144-1200`).
- Reachable today whenever the player's party record carries poison, burn or toxic in a trainer
  battle with two or more foe Pokémon. S2 and S3 make that ordinary play.

**Required fix.** When `finalizeFaintSequence` decides an outcome, clear `pendingForcedSwitches`
and `awaitingForcedSwitch`. Add an engine test and a controller-level test for this scenario.

### 2. Major: forced switches from separate faint sequences queue in turn order, not player-first

**Evidence.**
- Within one faint sequence, `finalizeFaintSequence` appends player before foe. The end-of-turn
  phase, however, calls `checkFaint` once per tick, so faints are appended in turn order.
- Reproduced in two cases:
  - Foe faster, both poisoned at 1 HP, both with a bench: the queue is `foe,player`.
  - Player KOs the foe (queued), then dies to poison: the queue is also `foe,player`.
- The source processes replacements in battler ID order, player first, in
  `HandleFaintedMonActions` cases 1 and 4. The project already asserts this as "queues retail
  player then foe order" (`tests/phase4_two_sided_replacement_state_test.lua`).
- Effect on the controller: `_runTurn` computes `after = ACTION` because the queue head is the
  foe. The main.lua-style hook then resolves the foe and returns its messages with `ACTION`. The
  controller ends up in `ACTION` with `awaitingForcedSwitch = "player"` and the player's battler
  at 0 HP, and the next `runTurn` asserts "a forced switch is pending" (reproduced).
- Not covered by any test. The design rule "(e) two forced switches can come out of one phase"
  was not exercised.

**Required fix.** Keep `pendingForcedSwitches` in battler order, player before foe, across
sequences. For example, sort after each append, or after the end-of-turn phase. Add an engine
test for the queue order and a controller test showing that a two-sided end-turn faint opens the
player selector first.

### 3. Minor: test gaps (mutants surviving)

Four meaningful mutants survive (see the table):
- **M2** (`% 4 == 0` changed to `% 2 == 0`). The tests only use paralysis draws 4 and 1. Add a
  draw of 2 (or 6) that must not paralyze.
- **M30** (the capture-failure site left as `decaySideTimers`). No test runs a failed ball with a
  status.
- **M32** (the "attacker fainted / forced switch pending" early-return site not converted). No
  test reaches it with a status. Example: the attacker KOs itself with recoil while a status
  battler remains.
- **M36** (the 0 HP skip removed). The only test where a fainted battler would be skipped gives
  that battler status 0. Add a poisoned battler KO'd by a move in a forced-switch turn, and
  assert one `faint` and one `forcedSwitchNeeded`.

**Required fix:** add these assertions.

### 4. Minor: AICheckBadMove's "CONFIRMED NO-OP CLASS" no longer holds for the target

**Evidence.** `AICheckBadMove.lua:80-95` cites "No status conditions" and treats
`if_status AI_TARGET STATUS1_ANY` and "user not asleep" as provable facts. After S1 the player,
who is the AI's target, can carry status. In S1 the affected branches only score power-0
status-inflicting effects (66, 67, sleep), which `supportsMove` rejects, and foes are always
status 0. So there is no observable change in this slice.

**Required fix:** none for S1 behaviour. S2 must port the `STATUS1_ANY` and user-sleep branches
before any status can reach a foe or a status move is admitted (Poison/Paralyze/Sleep tails,
DreamEater, Nightmare, DamageDuringSleep). The fix for this slice is to record that follow-up in
the task or design.

### 5. Info: Snore's own script body is not modelled

The canceller exemption is correct. However, `BattleScript_EffectSnore` (`battle_scripts_1.s:1253-1269`)
is not ported, because Snore (effect 92, power 40) goes through the plain Hit path:
- Asleep: the source prints "is fast asleep." before "used Snore", then hits with a 30% flinch.
- Awake, including the turn it wakes up: the source prints "But it failed!".

This gap predates S1, but S1 makes the asleep case reachable from a party record. Track it for
S3, or block Snore until then.

### 6. Info: other notes, no action needed for S1

- The defensive 0-PP path (`BattleEngine.lua:1156`) returns before the canceller. In the source
  the PP check comes after the canceller, so sleep would still decrement. This path is
  documented as unreachable in real play.
- `main.lua:4537` passes the raw `liveFoe.status`, toxic counter included, into
  `WildFactory.capture`, which bypasses the bridge mask. It is unreachable until a foe can be
  statused. Mask it in S2.
- The end-of-turn status cases use an `elseif` chain, while the source uses independent cases.
  The difference only matters for invalid words with several status bits.
- Defrost uses the move's base type. Hidden Power's dynamic type is a gap that predates S1.
- Mutants M4 (Sleep Talk is an unsupported move), M10, M14 and M15 are equivalent or
  unreachable under the current engine, as explained above.

## Mutation testing

Method: the four target files were saved, then 50 single mutants were applied one at a time.
Each was run against `battle_status_engine_test`, `battle_scene_controller_test`,
`battle_party_bridge_test` and `battle_engine_test`, with a 60 s timeout. After every mutant the
files were restored from the saved copies and checked with `sha1sum -c`. The final checksums
match the commit and `git status --short` shows only this file.

Result: 42 killed, 8 survived. Of the survivors, 4 are meaningful (M2, M30, M32, M36) and 4 are
equivalent or unreachable (M4, M10, M14, M15).

| # | Mutant | File | Result | Killed by / note |
|---|---|---|---|---|
| M1 | freeze `% 5` → `% 4` | Engine | killed | status: thaw on `% 5 == 0` |
| M2 | paralysis `% 4 == 0` → `% 2 == 0` | Engine | **survived** | draws 4/1 only (F3) |
| M3 | Snore exception removed | Engine | killed | status: Snore while asleep |
| M4 | Sleep Talk exception removed | Engine | survived | equivalent (Sleep Talk unsupported) |
| M5 | sleep check before decrement | Engine | killed | status: counter now 1 |
| M6 | woke-up turn cancels move | Engine | killed | status: wakes and acts |
| M7 | thaw-hit not exempt from frozen cancel | Engine | killed | status: thaw-hit |
| M8 | CANCELLER_THAW removed | Engine | killed | status: thaw-hit |
| M9 | cancellers after `useMove` | Engine | killed | status: sleep 2 |
| M10 | `currentMove` set before cancellers | Engine | survived | equivalent (cancelled move deals 0) |
| M11 | defrost without HP check | Engine | killed | status: Fire KO |
| M12 | defrost without damage check | Engine | killed | status: missed Fire |
| M13 | defrost on any type | Engine | killed | status: non-Fire hit |
| M14 | self damage counted in tally | Engine | survived | equivalent (no self `applyDamage` caller) |
| M15 | defrost `isOver` gate removed | Engine | survived | equivalent (no Gen 3 Fire recoil) |
| M16 | burn halving removed / after Reflect | Formulas | killed | status: burn oracle |
| M17 | burn crit-gated | Formulas | killed | status: no crit gate |
| M18 | Guts exemption removed | Formulas | killed | status: Guts |
| M19 | paralysis `/2` | Formulas | killed | status: tie creation |
| M20 | paralysis before stat stage | Formulas | killed | status: after stage |
| M21 | poison `/16` | Engine | killed | status: poison maxHP/8 |
| M22 | burn tick without min 1 | Engine | killed | status: burn min 1 |
| M23 | toxic min after multiply | Engine | killed | status: toxic min 1 |
| M24 | toxic counter cap removed | Engine | killed | status: counter 15 |
| M25 | toxic increment after multiply | Engine | killed | status: 2,4,6 |
| M26 | end-turn order reversed | Engine | killed | status: turn order |
| M27 | battler effects before field | Engine | killed | status: field first |
| M28 | hoisted order foe-first **[premise superseded by weather W0: the hoisted end-of-turn order is now source order (`ENDTURN_ORDER`, `battle_util.c:484-501`), not player first. Updated mutant: "hoisted end-of-turn order ignores speed and priority", killed by `tests/battle_end_turn_order_test.lua` (switch/capture/run vs faster or priority foe)]** | Engine | killed | status: switch turn |
| M29 | switch site not converted | Engine | killed | status: switch turn |
| M30 | capture site not converted | Engine | **survived** | untested (F3) |
| M31 | run site not converted | Engine | killed | status: failed run |
| M32 | attacker-faint early site not converted | Engine | **survived** | untested (F3) |
| M33 | defender-faint early site not converted | Engine | killed | status: move-KO pending switch |
| M34 | normal end site not converted | Engine | killed | status: poison |
| M35 | deciding faint does not stop phase | Engine | killed | status: stops ticks |
| M36 | 0 HP battler not skipped | Engine | **survived** | untested (F3) |
| M37 | forced-switch faint stops phase | Engine | killed | status: remaining battler ticks |
| M38 | status not cleared on faint | Engine | killed | status: Fire KO clears |
| M39 | persist mask removed | Bridge | killed | bridge: counter masked |
| M40 | persist drops status | Bridge | killed | bridge |
| M41 | fast-asleep text wrong | Controller | killed | controller :162 |
| M42 | Fire-defrost text wrong | Controller | killed | controller :101 |
| M43 | HP before tick message | Controller | killed | controller :90 |
| M44 | paralysis text wrong | Controller | killed | controller :106 |
| M45 | canceller thaw uses defrost-by text | Controller | killed | controller :102 |
| M46 | canceller thaw keeps freeze | Engine | killed | status: thaw clears |
| M47 | paralysis draw taken unconditionally | Engine | killed | status: draw count |
| M48 | freeze draw taken unconditionally | Engine | killed | status: draw count |
| M49 | tick HP entry missing | Controller | killed | controller :90 |
| M50 | per-move tally reset removed | Engine | killed | status (error) |

## Required before PASS

1. Finding 1: clear the forced-switch queue when the outcome is decided, with tests.
2. Finding 2: keep the forced-switch queue player-first across faint sequences, with engine and
   controller tests.
3. Finding 3: add assertions that kill M2, M30, M32 and M36.
4. Finding 4: record the AICheckBadMove follow-up for S2 in the task or design. Finding 5 is
   tracked the same way.

## Worker disposition (2026-10-14)

F1-F3 fixed with tests (see the task file); F5 asleep-Snore order fixed;
re-review R-1 fixed (same-sequence notices player-first again); R-2 left for the party-select UI;
F4/F5 awake failure/F6 recorded as follow-ups in the task file.

## Re-review (fix commit `ca39623`)

- Reviewer: the same independent Reviewer. Date: 2026-10-14.
- Artifact: `git show ca39623` (`BattleEngine.lua` `finalizeFaintSequence` and the sleep
  canceller; new engine and controller tests; follow-ups added to the task file).
- **Final verdict: PASS.**

### Fix verification

**F1 (decided outcome clears the queue): fixed.**
- Code: when an outcome is set, `pendingForcedSwitches = {}` is followed by
  `_syncForcedSwitchHead()`. This matches the source: `HandleFaintedMon` runs `checkteamslost`,
  and with `gBattleOutcome != 0` it ends without a replacement.
- Engine probe: player poisoned on their last Pokémon, KOs a foe that has a replacement, then
  dies to poison. Result: `outcome=playerLost`, nothing pending.
- Controller probe with the main.lua-style hook: the state reaches `complete` and the trainer
  sends out no replacement.
- Still holds: `simultaneous exhaustion` and `one-side exhaustion` in
  `phase4_two_sided_replacement_state_test` (10/0).

**F2 (queue player-first across faint sequences): fixed.**
- The queue is rebuilt in player-then-foe order from the union of the existing and new entries.
  This matches `HandleFaintedMonActions` walking battler IDs from 0 (`battle_util.c:1185-1199`).
- Probes now give `player,foe` for both cases:
  - both poisoned, foe faster;
  - foe KO'd by a move, then the player poisoned out.
- The controller now goes to `party` first.
- Existing callers are unaffected:
  - `TrainerBattleOrchestrator.resolveFoeReplacement` still asserts the head is `"foe"`, and the
    head only becomes foe after the player resolves.
  - main.lua's `onMessagesComplete` / `onForcedSwitchChoice` follow the same player-then-foe
    sequence that `phase4_two_sided_replacement_state_test` already exercised.
  - `phase4_player_forced_replacement_controller_test` passes (7/0).

**F3: fixed.** M2, M30, M32 and M36 are now killed (table below).

**F5 (partial): correct.**
- `BattleScript_EffectSnore` (`battle_scripts_1.s:1253-1266`) prints `PKMNFASTASLEEP` before
  `attackstring`, so emitting `fastAsleep` before `useMove` for an asleep Snore is right.
- Sleep Talk does the same at `:1313-1317`, but it is unsupported anyway.
- The change sits inside the sleep canceller, which is equivalent because no canceller between
  sleep and Snore's script is modelled.
- The awake-failure branch is recorded as a follow-up.

**F4 and F6:** recorded as follow-ups in the task file. Acceptable for S1.

### New observations

**R-1 (Info): `forcedSwitchNeeded` events now follow faint-recording order.**
- For a same-sequence double faint (Explosion, both sides with a bench), the placeholder
  `forcedSwitchNeeded` events now come foe-then-player. Before, they came player-then-foe.
- The queue order is still player-first, and source shows no such message (it is a documented
  placeholder). No test or caller depends on the event order.

**R-2 (Info): the foe's placeholder still prints on a loss.**
- In the F1 scenario, the foe's "must send out a new POKEMON!" placeholder is still printed
  before the player's poison faint ends the battle.
- This is the same cosmetic placeholder class, and it is no longer acted on. Can be revisited
  when the party-select UI replaces the placeholder.

### Checks

- `battle_status_engine_test`: 78/0
- `battle_scene_controller_test`: 119/0
- `battle_party_bridge_test`: 32/0
- `battle_engine_test`: 568/0
- `phase4_two_sided_replacement_state_test`: 10/0
- `phase4_player_forced_replacement_controller_test`: 7/0
- `bash scripts/test_all.sh`: PASS (163 files)
- `check_repository.lua`: PASS

### Mutation re-run

The four source files at `ca39623` were saved, mutated one at a time, and restored. `sha1sum -c`
reports OK for all four.

| # | Mutant | Result | Killed by / note |
|---|---|---|---|
| M2 | paralysis `% 4 == 0` → `% 2 == 0` | killed | "paralysis draw 2 does not fully paralyze" |
| M30 | capture site not converted | killed | "failed capture turn still ticks" |
| M32 | attacker-faint early site not converted | killed | "recoil self-KO with a pending switch still ticks the foe" |
| M36 | 0 HP battler not skipped | killed | "end-of-turn skips a battler at 0 HP" |
| R1 | no queue clear on decided outcome | killed | "decided battle leaves no forced switch pending" |
| R2 | no player-first reorder (append order) | killed | "player's forced switch comes first" |
| R3 | reorder foe-first | killed | same |
| R4 | dedup of already-queued side removed | survived | equivalent: the queue is rebuilt from a set, and a side already queued sits at 0 HP and is skipped by the end-of-turn phase, so it cannot faint again |
| R5 | asleep Snore without `fastAsleep` | killed | Snore fast-asleep order test |
| R6 | queue cleared without head sync | killed | "decided battle leaves no forced switch pending" |

No remaining Blocker, Major or Minor findings for S1.
