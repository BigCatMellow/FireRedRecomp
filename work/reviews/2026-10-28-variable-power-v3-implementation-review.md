# Review: variable-power slice V3 (Rollout / Ice Ball, effect 117, and Defense Curl, effect 156)

- Reviewed: `bb2a1e8` on `claude/variable-power-v3-20261028` (PR #58), read as `git diff 49d0f45 bb2a1e8`.
- Specs: `work/reports/phase4-variable-power-design-proposal.md` (§7, §8, "V3", verification plan V3), `work/reviews/2026-10-21-variable-power-design-review.md` (F2, F3, F10, D3), `work/tasks/phase4-variable-power-v3.md`.
- Precedent: `work/reviews/2026-10-21-variable-power-v1-v2-implementation-review.md`.
- Date: 2026-10-28
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`, local read-only copy `/home/home/FireRedRecomp-reference/pokefirered` (`git log -1` confirms the pin).
- Abbreviations: `bsc.c` = `src/battle_script_commands.c`, `bs1.s` = `data/battle_scripts_1.s`, `bm.c` = `src/battle_main.c`, `bu.c` = `src/battle_util.c`, `moves.h` = `src/data/battle_moves.h`, `BE` = `src/core/BattleEngine.lua`, `T` = `tests/battle_variable_power_v3_test.lua`.
- Nothing in the repository was edited except this file. Each mutation was applied to `BE` in place, tested, and reverted with `git checkout -- src/core/BattleEngine.lua`. Probes ran from the scratchpad and wrote nothing to the repository. `git status` was clean before this commit.

## Verdict: **PASS WITH CORRECTIONS**

I re-derived every V3 path from source. The engine matches the source on all of them, and I found no behaviour bug.

- `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh` passes: 204 test files (no-ROM mode), exit 0.
- `lua5.1 scripts/check_repository.lua` passes: 332 Lua, 394 Markdown, 1316 local targets.
- `T` runs 135/0. The ROM fixture skips cleanly without a ROM.
- I ran 7 mutants of my own: 6 were killed and 1 survived (F1).

The corrections are a test gap (F1), a task-file wording fix (F2) and two INFO items. None of them blocks merging the code.

## What was checked

### Rollout / Ice Ball (`BE:2122-2124`, `:2239-2245`, `:2323-2324`, `:2896-2897`, `:2915-2925`, `:3041-3078`)

| Item | Source | Engine | Result |
| --- | --- | --- | --- |
| Script order | `bs1.s:1592-1602`: attackcanceler, attackstring, `jumpifstatus2 MULTIPLETURNS` over ppreduce, `accuracycheck BattleScript_RolloutHit` (the hit and the miss share the label), typecalc2, rolloutdamagecalculation, `HitFromCritCalc` | PP block, then the `not hit` cancel, then the typecalc2 query, then the timer and power, then the ordinary crit/damage/typecalc/random path | Match |
| First hit | `bsc.c:8172-8178`: MULTIPLETURNS clear, so `rolloutTimer = 5`, MULTIPLETURNS, `gLockedMoves` | `rolloutTimer == 0`: set 5 and `lockedSlot = moveSlot` (`BE:3061-3064`) | Match. `rolloutTimerStartValue` is read only by animations (`battle_anim_rock.c:707`, `battle_anim_ice.c:1410/1472`), so leaving it out is correct |
| Decrement / release | `bsc.c:8179-8182`: `--timer`; at 0 MULTIPLETURNS clears | `-1`; at 0 `lockedSlot = nil` under the `not recharging` guard (`BE:3065-3068`) | Match (F3 of the design review). Tested: the hit-5 release, then Tackle on the next turn (`T:174-180`) |
| Power | `bsc.c:8184-8187`: record power, doubled for `i = 1 .. 4 - timer`; `:8189-8190` doubles again under `STATUS2_DEFENSE_CURL` | `for _ = 1, 4 - timer`; `* 2` if `defenseCurl`; on a local copy, so the record keeps 30 | Match: 30/60/120/240/480, curled 60 to 960. I re-derived the oracle `floor(6P/50)+2` = 5/9/16/30/59/117 |
| NO_EFFECT arm | `bsc.c:8163-8167`: CancelMultiTurnMoves, `MoveMissedPause` (`bs1.s:279-285`, resultmessage) | Accuracy, protected and semi-invulnerable misses all cancel, then emit `miss` or `protected` (`BE:2915-2925`). The typecalc2 immunity cancels and emits `noEffect` before the crit (`BE:3049-3055`) | Match. Draws are 1/0/0/1 (the 1 for an immunity is the accuracy draw). `typecalc2` (`bsc.c:4346-4439`) ORs DOESNT_AFFECT on a miss too, but Rock and Ice have no 0x row, so it is unobservable |
| PP (F2/F3) | `jumpifstatus2` reads MULTIPLETURNS **after** the protect step (`bsc.c:896-906`), which cancels any protected move not in `IsTwoTurnsMove` (`:7821-7832`, Rollout absent); ppreduce deducts only while PP > 0 (`:1147`) | One `rolloutLocked` capture after `protectBlocks` (`BE:2306-2324`); spend unless locked, guarded at 0 (`BE:2896-2897`) | Match. Hit 1 spends 1; hits 2-5 spend 0; an unprotected locked miss or Fly/Dig miss spends 0; a protected locked turn spends 1; at 0 PP it stays 0 |
| 0-PP check | `bsc.c:838-839`: bypassed under MULTIPLETURNS. It runs **before** the protect step | It reads the live `rolloutTimer` before the protect step (`BE:2239-2245`) | Match. A locked 0-PP slot hits (`T:300-305`); a protected locked 0-PP turn is protected with PP 0 (`T:270-277`) |
| Cancelled earlier this turn | `bm.c:3989-3991` uses `gLockedMoves` only while MULTIPLETURNS is set; otherwise the old position, with no NO_PPDEDUCT | `turnLocked`: the slot is kept; the 0-PP check applies; PP is spent; the sequence restarts | Match. A probe (freeze applied, then a thaw on the next draw) gave `thawed,useMove,damage=5`, PP 5 to 4, timer 4; at 0 PP it gave `thawed,noPP`. Untested (F4) |
| `isLocked` / `lockedTurn` | `bm.c:3125-3130`: MULTIPLETURNS skips action selection | `rolloutTimer > 0` is added to `isLocked` (`BE:2024`) and `lockedTurn` (`BE:2122-2124`); `runTurn` swaps in `lockedSlot` (`BE:4790-4799`) | Match. The controller runs no AI for a locked foe and opens no menu for a locked player (`T:459-488`). A probe confirms the state is `action` after hit 5 (F3) |
| CancelMultiTurnMoves | `bu.c:203-214`, `:212` zeroes the timer. Callers: recharge `bu.c:1354`, flinch `:1366`, paralysis `bs1.s:3717`, confusion self-hit `:3742`, sleep/freeze applied `bsc.c:2173/:2269`, the protect step `:900`, end-of-turn sleep `bm.c:2941-2942` | `rolloutTimer = 0` is added inside the function (`BE:2010`), so every existing caller gets it | Match; each caller has a test (`T:330-394`). The unrepresented callers are recorded as limits (the same set as V2) |
| End-turn sleep | `bm.c:2941-2942`: SLEEP && MULTIPLETURNS | `rolloutTimer > 0` is added to the gate (`BE:4419-4420`) | Match (`T:383-391`) |
| Existing freeze / sleep | `CANCELLER_FROZEN` and `CANCELLER_ASLEEP` do not cancel | The lock is kept; the end-of-turn cancel ends it for a sleeper | Match |
| Faint / switch-in | Disable-struct clears at `bm.c:2382-2384` and `:2457-2459`; status2 clears at `:2441` (faint) and `:2367` (switch-in) | `recordFaint` clears `rolloutTimer` and `defenseCurl` (`BE:1480-1481`); a switch-in is a fresh `makeBattler` (`BE:1218`, `:1223`) | Match (`T:430-455`) |
| Target faint | Nothing touches the attacker's lock | The lock is kept; hit 3 lands at 120 on the replacement | Match (`T:415-428`) |
| Different move | Locked, so no other move can be chosen | n/a | n/a |
| RNG | No new draws | Hit 3, miss 1, protected or semi-invulnerable 0, immunity 1, Defense Curl 0; a locked foe skips the AI draw | Match |

### Defense Curl (`BE:1661-1665`, `:2801-2809`, `:3354-3359`)

| Item | Source | Engine | Result |
| --- | --- | --- | --- |
| Script | `bs1.s:2010-2021`: attackcanceler, attackstring, ppreduce, `setdefensecurlbit` (`bsc.c:8472-8476`), `setstatchanger STAT_DEF, 1`, `statbuffchange AFFECTS_USER \| ALLOW_PTR` | Effect-11 stat entry `{defense, +1}`, self-target (`0x10`), so no accuracycheck and no protect; PP is spent; the bit is set before the at-limit branch | Match |
| At +6 | `ChangeStatBuffs` (`bsc.c:6797-6815`): `B_MSG_STAT_WONT_INCREASE` sets MISSED and returns WORKED (ALLOW_PTR), and `jumpifbyte` goes to `StatUpPrintString` (`bs1.s:506`) without effect 11's pause (`:498`) | A `prevented` statChange; the controller prints "PLAYER's DEFENSE\nwon't go higher!" (`T:206-217`); the bit is set | Match (F10). MISSED is unobservable here |
| Bit scope | `STATUS2_DEFENSE_CURL` (`include/constants/battle.h:130`). Its only writer is `:8474` and its only reader is `:8189` (grep of the pin) | A per-battler `defenseCurl`; the foe's bit does not double the player's Rollout (`T:222-230`) | Match |
| Text | "used" grammar: `sGrammarMoveUsedTable` (`battle_message.c:1398-1425`) lists Defense Curl and Rollout, but every English mark is "!" | Existing "used" line | Match; no new string |
| AI | `AI_CBM_DefenseUp` (`ai.s:186`) | Already ported (`AICheckBadMove.lua:645`) | Match; no AI change needed |

### Trainer battles that carry Defense Curl (parity check)

Source parties: Camper Liam's Geodude and Sandshrew (`trainer_parties.h:863`, `:869`; `aiFlags` = CHECK_BAD_MOVE, `trainers.h:1422`) and Brock's Geodude (`:5609`; `aiFlags` 7, `trainers.h:4142`). I probed both at `49d0f45` (the parent engine loaded through `package.preload`) and at `bb2a1e8`:

- **Liam (CHECK_BAD_MOVE):**
  - The AI is identical before and after: 1 draw and the same scores. `TrainerAI` does not filter on `supportsMove`.
  - Before V3, when the AI picked Defense Curl, `runTurn` raised `unsupported move effect 156` (`BE` parent `:2118`). `main.lua` does not wrap the live battle in a `pcall`, so this was a hard error.
  - After V3, the foe goes to DEF +1 with the bit set, as in source.
  - The change only replaces a crash with source behaviour: no RNG stream or earlier-correct outcome changes. **No conflict with the parity contract.**
- **Brock (aiFlags 7):**
  - `TrainerAI.choose` delegates to `EarlyRivalAI.choose` (`TrainerAI.lua:144`), which raises `unsupported Oak-lab AI move effect 156` for any non-hit move (`EarlyRivalAI.lua:76-81`). This happens before the engine is reached, both before and after V3.
  - Onix's Bind (effect 42) is still blocked.
  - V3 therefore changes nothing observable for Brock (F2).

### Inventory and ROM fixtures

- Rows 117 and 156 flip to `represented`, with 156's admission going false to true. The counts are consistent:
  - +1 admitted;
  - two positive records (205, 301) leave the uncovered list (22 to 20; 18 effects);
  - represented 131/280/195/85, blocked 66/73/20/53.
- The report rows and the class table match the test.
- The ROM fixture could not run: no ROM is present, and I did not read one. I checked it statically against the pin:
  - Rollout: `moves.h:2668-2679`, 117/30/Rock(5)/90/20/0/selected(0)/0/0x33.
  - Ice Ball: `:3916-3927`, the same with Ice (15).
  - Defense Curl: `:1446-1457`, 156/0/Normal/0/40/0/`MOVE_TARGET_USER` (0x10, `include/battle.h:64`)/0/0x08.
  - The flag bits match `include/constants/pokemon.h:237-242`.
- The family-membership asserts are 2 and 1. "ROM fixture pending" is the correct status.

### Citations

I checked every source citation in the task file, the `BE` comments and the `T` header against the pin, and all are accurate. They are:

- `bs1.s:1592-1602`, `:2010-2021`, `:3717`, `:3742`
- `bsc.c:838-839`, `:896-906`, `:1147`, `:2173`, `:2269`, `:7821-7832`, `:8161-8193` (sub-ranges `:8163-8167`, `:8172-8182`, `:8184-8190`), `:8472-8476`
- `bu.c:203-214`, `:212`, `:1354`, `:1366`
- `bm.c:2367`, `:2382-2384`, `:2441`, `:2457-2459`, `:2941-2942`, `:3125-3130`
- `include/battle.h:156`, `include/constants/battle.h:130`
- `moves.h:2668`, `:3916`, `:1446`
- `AICheckBadMove.lua:645`

### Regressions

- No existing assertion changed except the intended inventory flips.
- `main.lua`, `BattleSceneController.lua`, `AICheckBadMove.lua` and `BattlePartyBridge.lua` are untouched (`git diff --stat 49d0f45 bb2a1e8`).

### Mutation testing (7 mutants of my own; 6 killed)

| Mutant | V3 failures |
| --- | ---: |
| An unprotected locked miss spends PP (`(not rolloutLocked or not hit)`) | 4 |
| `recordFaint` keeps `defenseCurl` (the timer clear left in place) | 1 |
| A semi-invulnerable miss keeps the lock (`if not semiMiss then cancel`) | 2 |
| The first hit does not set `lockedSlot` | run aborts (1 FAIL, then an error) |
| `rolloutLocked` also true when locked at turn start (pre-protect value) | 2 |
| The typecalc2 no-effect arm does not cancel | 1 |
| The Defense Curl doubling only for Rock-type (`move.type == 5`) | **0 (survived, F1)** |

The implementer's 14 recorded mutants are different from these.

## Findings

### F1 (LOW, test gap): no curled Ice Ball test; a Rock-only Defense Curl doubling survives

`bsc.c:8189-8190` doubles for every `EFFECT_ROLLOUT` move. `T:188-205` runs the curled sequence only with Rollout (`playerMoves = { DEFENSE_CURL, ROLLOUT }`, `T:190`), and Ice Ball is only exercised uncurled (`T:152-185`). The mutant `if attacker.defenseCurl and move.type == 5 then` at `BE:3076` passes 135/0.

A probe at `bb2a1e8` shows the engine itself is correct: a curled Ice Ball against a Normal foe does 9, 16, 30, 59, 117.

**Fix:** in `T` §3, run the curled five-hit loop for both `{ ROLLOUT, nil }` and `{ ICE_BALL, { Data.TYPE_NORMAL, Data.TYPE_NORMAL } }`. Build the battle with `playerMoves = { DEFENSE_CURL, id }` and `foeTypes` from the entry, and expect `CURL_DAMAGE` = 9/16/30/59/117 for each.

### F2 (LOW, task accuracy): "Brock's Geodude ... carry it" overstates the behaviour change

`work/tasks/phase4-variable-power-v3.md:132-133` says Defense Curl "is now admitted (Brock's Geodude and Liam's Geodude carry it)". That implies both battles change. Only Liam's does:

- Brock's aiFlags 7 path errors in `EarlyRivalAI.choose` (`EarlyRivalAI.lua:76-81`) before the engine runs, both before and after V3.
- Liam's Sandshrew also carries Defense Curl (`trainer_parties.h:869`).

**Fix:** replace those two lines with:

> **Behavior change:** Defense Curl was rejected before; it is now admitted. Camper Liam's Geodude and Sandshrew (CHECK_BAD_MOVE) previously raised "unsupported move effect 156" when the AI chose it and now follow source (AI scoring and draws unchanged). Brock (aiFlags 7) is unchanged: `EarlyRivalAI.choose` still rejects effect 156 (and Onix's Bind remains blocked).

### F3 (INFO, test strength): the controller test does not assert the menu returns after hit 5

The design verification plan asks that "after hit 5 `isLocked` is false and the next turn offers the menu". `T:473-474` checks `b.turn == 5 and not b:isLocked("player")` but not the controller state. A probe confirms `c.state == BattleSceneController.ACTION` after the loop.

**Fix:** append `and c.state == BattleSceneController.ACTION` to the check at `T:473`.

### F4 (INFO, coverage): the "lock cancelled earlier this turn" path is untested for Rollout

Source (`bm.c:3989-3991`; `bsc.c:838-839`) and the engine (`BE:2119-2129`, `:2239-2245`) agree. When a faster foe's freeze is followed by a thaw, the battler restarts at 30, spends PP, and reports "no PP" at 0 PP. Both outcomes are probe-confirmed above, but no V3 test pins them.

**Optional fix:** add to `T` §6: `primed()`, `e.lockedThisTurn = { player = true, foe = false }`, `applySecondaryStatus("player", "freeze", false, {})`, then `use(e, "player", 1, { 0, 0, 1, 0 })`. Expect `thawed,useMove,damage`, damage 5, PP 18, timer 4. Repeat at PP 0 and expect `thawed,noPP`.

### F5 (INFO, design wording only; no code change)

The design's V3 bullet (`work/reports/phase4-variable-power-design-proposal.md:555-556`) says "The PP block and the 0-PP bypass both read that value [`rolloutLocked`]". The 0-PP check (`bsc.c:838`) runs before the protect step (`:896`), so it must read the live timer, and the implementation correctly does (`BE:2241`). A protected locked 0-PP turn shows the difference: it is protected, not "no PP", and `T:270-277` covers it.

**Fix (optional, at the next design fold):** "the PP block reads `rolloutLocked`; the earlier 0-PP bypass reads the live `rolloutTimer`".

## UNKNOWN

- The ROM fixture against the verified ROM: no ROM was available, and I was not permitted to read one.
- The live LÖVE behaviour of a Liam battle: I did not run LÖVE. The Liam conclusion comes from engine and AI probes only.
