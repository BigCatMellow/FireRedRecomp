# Review: variable-power slices V1 (Present) and V2 (Fury Cutter), plus the doc fold and the H1 hand-off

- Reviewed: `53e08cd` (V1) and `0663e1d` (V2) on `claude/wizardly-faraday-o45q9z`, read as `git diff 4916b73 0663e1d`. I skimmed `d1ad194` (the proposal fold and `work/handoffs/2026-10-21-battle-friendship-ivs-handoff.md`).
- Specs: `work/reports/phase4-variable-power-design-proposal.md`, `work/reviews/2026-10-21-variable-power-design-review.md`, `work/tasks/phase4-variable-power-v1.md`, `work/tasks/phase4-variable-power-v2.md`.
- Date: 2026-10-21
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
  - Local copies in `/tmp/claude-0`: `bsc.c`, `bs1.s`, `bmain.c`, `rev8src/battle_util.c`, `rev8src/battle_controller_{player,opponent}.c`, `r1src/battle_moves.h`, `src2/pokemon.h`.
  - Fetched at the pin: `src/pokemon.c`.
- Abbreviations: `bsc.c` = `src/battle_script_commands.c`, `bs1.s` = `data/battle_scripts_1.s`, `bmain.c` = `src/battle_main.c`, `bu.c` = `src/battle_util.c`, `BE` = `src/core/BattleEngine.lua`.
- Nothing in the repository was edited except this file. Each mutation was applied to `BE` from a scratchpad backup, tested and restored. `git status` was clean after the run.

## Verdict: **PASS WITH CORRECTIONS**

Both engine slices match the source at the pin on every path I traced, and I found no behaviour bug in V1 or V2.

- `bash scripts/test_all.sh` passes: 202 files at `0663e1d`, and 200 at `53e08cd`, checked in an exported tree.
- `lua5.1 scripts/check_repository.lua` passes.
- V1 runs 72/0 and V2 runs 80/0.
- All 26 mutations were killed (see below).

The corrections are documentation only:

- F1: the H1 hand-off leaves out the battle-start league friendship bump.
- F2: the proposal's H1 section contradicts the hand-off for the wild path.
- F3: an existing, untracked text gap that Present inherits should be recorded as a limit.

None of them blocks merging the code.

## What was checked

### V1 Present (`BE:2960-3008`, `presentPowerFromRoll` `BE:680-689`)

| Item | Source | Engine | Result |
| --- | --- | --- | --- |
| Thresholds | `bsc.c:8240-8248`: `Random() & 0xFF`; `<102` 40, `<178` 80, `<204` 120 | `next16() % 256`; same strict comparisons; the helper asserts a byte | Match |
| Draw position | `bs1.s:1660-1666`: attackcanceler, accuracycheck, attackstring, ppreduce, typecalc, roll | After the miss block and PP spend, before the zero-power branch | Match |
| Miss / protected / Fly-Dig | `bsc.c:1085-1104` (miss: 1 draw); protect re-test and `AccuracyCalcHelper` `:1040-1043` (0 draws); all go to `PrintMoveMissed` (`bs1.s:276-285`, attackstring+ppreduce) | `if not hit` returns before the roll. PP is spent. 1/0/0 draws (tests in §5) | Match |
| Damage branch | `HitFromCritCalc` `bs1.s:251-255`: critcalc, damagecalc, typecalc, adjustnormaldamage | A local copy with the dynamic power goes through the ordinary crit/damage/typecalc/random path. A Ghost gets `noEffect` after 4 draws | Match (plus the tracked `seteffectwithchance` gap) |
| Heal amount | `bsc.c:8250-8253`: `maxHP/4`, 0 to 1, negated | `floor(maxHP/4)`, 0 to 1 | Match |
| Heal clamp | `Cmd_datahpupdate` `bsc.c:1789-1794` clamps at maxHP | `math.min(maxHP, hp+amount)`; the event amount is the HP actually gained | Match |
| Full HP | `bsc.c:8257-8258` to `BattleScript_AlreadyAtFullHp` `bs1.s:2038-2042`, `{B_DEF_NAME_WITH_PREFIX}'s HP is full!` | `restoreHPFull{side=defenderSide}`; controller prints "FOE's\nHP is full!" | Match |
| Ghost heal | `bsc.c:8261` clears `DOESNT_AFFECT_FOE`; `datahpupdate`'s `!NO_EFFECT` gate (`:1758`) passes | The heal ignores type; tested (2 draws) | Match |
| No crit/damage draw on heal | `PresentHealTarget` `bs1.s:2028-2036` has no critcalc or adjust | No draw; `tookMoveDamage` and the tutorial flag untouched | Match |
| Shared record | the AI reads `gBattleMoves` power 1 | `presentMove` shallow copy; `moves[217].power` stays 1 (tested; mutation P8 killed) | Match |
| D4 limits | Substitute ignored by the heal (`bs1.s:2031`); Wonder Guard's leftover `MISSED` blocks `datahpupdate` (`bsc.c:1758`); pre-roll `targetNotAffected` (`bsc.c:1378-1388`) | Recorded in the task, `BE:2991-2993` and inventory row 122 | Correctly scoped |

### V2 Fury Cutter (`BE:2838-2846`, `:2947-2960`, `:3451-3463`, `:1974`, `:1452`, `:4756`, `:4828`)

| Item | Source | Engine | Result |
| --- | --- | --- | --- |
| Doubling and cap | `bsc.c:8216-8222`: `if (c != 5) c++`; power doubled `c-1` times | Same; 10/20/40/80/160/160 tested as 3/4/6/11/21/21 (oracle re-derived: `floor(6P/50)+2`) | Match |
| Miss, protected, Fly/Dig | `bs1.s:1631`: both arms reach `furycuttercalc`; `NO_EFFECT` zeroes and goes to `MoveMissedPause` | The counter is zeroed at the top of `if not hit`; existing miss/protected events; 1/0/0 draws | Match |
| No-effect hit | `bs1.s:1636` `jumpifmovehadnoeffect` precedes `adjustnormaldamage`; the second `furycuttercalc` zeroes | `furyCutterNoEffect`: counter 0, random skipped, crit already drawn; tested with a synthetic 0x row (2 draws) | Match. The implementer's deviation from the design is source-faithful |
| `cancelMultiTurnMoves` | `bu.c:213` | The reset is added inside the function, so every caller gets it | Match |
| Caller audit | Source callers: attackcanceler protect `bsc.c:900`; SetMoveEffect sleep/freeze `:2173/:2269`; `cancelmultiturnmoves` cmd `:6071` (used at `bs1.s:3717` paralysis, `:3742` confusion self-hit); recharge `bu.c:1354`; flinch `:1366`; end-turn THRASH `:958`; end-turn sleep `bmain.c:2942`. Unrepresented: Torment `bu.c:319`, Uproar `:933/:944`, Yawn `:1040`, Truant `:1340`, Disable `:1378`, Taunt `:1389`, Imprison `:1400`, love `:1476`, Spite `bsc.c:7982`. (`bu.c:1444` paralysis is commented out in C, but the script still cancels at `bs1.s:3717`.) | Engine call sites: `BE:1722` (recharge), `:1729` (flinch), `:1751` (paralysis), `:1798` (sleep/freeze secondary), `:1882` (sleep status move), `:1900` (confusion self-hit), `:2266` (protect step), `:4295` (end-turn sleep, gated on a lock, as `MULTIPLETURNS` is in source), `:4563` (rampage `targetNotAffected`). Every one now resets the counter. No inline copy of the cancel bypasses the function (`BE:2235` turn-2 lock clear and `:4686` recharge lapse are not `CancelMultiTurnMoves` in source either) | Match; each caller has a test |
| Capture / failed run | `HandleAction_UseItem` `bmain.c:4155` before the item branch; failed run `:4311` | `BE:4756`, `:4828` (player only; the foe's counter is kept, tested) | Match |
| Faint / switch-in | `bmain.c:2382-2384`, `:2457-2459` zero `gDisableStructs` | `recordFaint` `BE:1452`; switch-in installs a fresh `makeBattler` from `BattlePartyBridge` (`BE:4707-4717`) | Match |
| Different move | The only writers are `bsc.c:8209/:8217`, `bu.c:213`, `bu.c:3043` and the struct clears | No reset; a Tackle in between keeps the counter, a protected Tackle resets it (protect step) | Match |
| Target faint | Nothing touches the attacker's struct | Counter kept, next hit at 40 against the replacement (tested) | Match |
| Shared record | | `cutterMove` copy; `moves[210].power` stays 10 (mutation F10 killed) | Match |

### Inventory and ROM fixtures

- Rows 119 and 122 flip to `represented`. The counts move 24 to 22 uncovered positive, and represented goes to 129/277/193 and blocked to 68/76/22. The uncovered list loses 119 and 122 (19 effects). Row 117 no longer names Fury Cutter. The no-ROM partition check passes.
- The ROM fixtures could not run: no ROM is in the container. I checked them statically against `battle_moves.h:2733-2744` and `:2824-2835`, and the flag bits against `include/constants/pokemon.h:238-243`:
  - Present: 122/1/Normal/90/15/0/selected/0/0x12.
  - Fury Cutter: 119/10/Bug(6)/95/20/0/selected/0/0x33.
- Each fixture also checks that its family has exactly one member. "ROM fixture pending" is the correct status.

### Regressions

- No existing assertion changed except the intended inventory flips.
- `main.lua`, `BattlePartyBridge.lua` and `AICheckBadMove.lua` are untouched.
- V1 changes only comments in `BattleSceneController.lua`. V2 does not touch that file, as its task requires.
- The full suite passes at both commits.

### Mutation testing (26 mutants, all killed)

Present:

| Mutant | V1 failures |
| --- | ---: |
| 102 to 101 | 2 |
| 178 to 179 | 2 |
| 204 to 205 | 7 |
| `% 256` to `% 100` | 25 (test_all exits 1) |
| no heal minimum | 1 |
| no clamp | 1 |
| full-HP event names the attacker | 2 |
| writes power into the shared record | 1 |
| crit draw added on the heal branch | 6 |
| Ghost refused the heal | 1 |
| roll drawn on miss/protect/semi paths | 4 |
| heal maxHP/2 | 10 |

Fury Cutter:

| Mutant | V2 failures |
| --- | ---: |
| cap 6 | 4 |
| doubled `counter` times | 16 |
| no miss reset | 4 |
| no `cancelMultiTurnMoves` reset | 10 (test_all exits 1) |
| no faint reset | 1 |
| no capture reset | 1 |
| no failed-run reset | 1 |
| no-effect hit draws the random | 1 |
| no-effect hit keeps the counter | 1 (test_all exits 1) |
| writes into the shared record | run aborts |
| default 1 | 31 |
| reset on any other move | 4 |
| protect step bypasses the counter reset | 2 |
| increment disabled | 30 |

## Findings

### F1 (LOW, hand-off accuracy): H1 leaves out the battle-start league friendship bump that the snapshot must include

The hand-off's §4 says "Battle never changes them: an in-battle level-up adjusts the party friendship only (`bsc.c:3314`)", and §5 says the snapshot "is exact today". At the pin, battle setup also changes the party value **before** the battlers are copied in:

- `CB2_InitBattleInternal` runs `AdjustFriendship(&gPlayerParty[i], FRIENDSHIP_EVENT_LEAGUE_BATTLE)` for every party slot (`bmain.c:711-713`).
- It applies only in trainer battles against a Leader, Elite Four or Champion (`pokemon.c:5478-5487`).
- The deltas are +3/+2/+1 by friendship band (`pokemon.c:1623`), ×1.5 with Soothe Bell (`:5490-5492`).
- The switch-in copy then reads that adjusted value (`battle_controller_player.c:1540`).

This changes the result: friendship 70 gives Return power `10*70/25 = 28`, but in a gym battle the battler holds 73, which gives 29. `AdjustFriendshipOnBattleFaint` (`bsc.c:2878`) is a second in-battle party change. It does not affect the snapshot, because a fainted battler cannot come back in without an in-battle Revive, which is not represented.

No gym, Elite Four or Champion battle exists yet (`src/` has no trainer-class check outside `WhiteoutRules.lua`), so this does not show today.

**Fix:** in the hand-off's §4/§5, and in proposal H1 items 5 and 7:

- state that the league-battle bump must be applied to the party record before the battlers are built, by whichever lane owns battle start;
- otherwise record it as a V4b limit;
- mention the faint adjustment for completeness;
- keep the "no write-back" rule, which stays correct.

### F2 (LOW, doc consistency): the proposal's H1 item 2 contradicts the hand-off for wild instances

Proposal H1 item 2 (`work/reports/phase4-variable-power-design-proposal.md:640-641`) says to pass `friendship = instance.friendship` from `battlerFromGenerated`. Item 3, three lines later, calls adding `friendship` to the wild factory "optional".

A wild instance has no top-level `friendship` (`WildPokemonFactory.lua:252-261`). Following item 2 without item 3 would therefore give wild foes, and the developer temporary player (`main.lua:1280`), a nil friendship. V4a's gate would then make Return/Frustration unsupported for them.

The hand-off (§2) is correct: read `instance.boxData.substructs[0].friendship`. The proposal says the hand-off is the self-contained note, but its own list is the stale pre-F13 version.

**Fix:** reword item 2 to match hand-off §2, or replace the list with a pointer to the hand-off.

### F3 (LOW, pre-existing, inherited by V1): a missed Present against a Ghost prints "missed"; source prints "It doesn't affect"

On an accuracy failure, `Cmd_accuracycheck` calls `CheckWonderGuardAndLevitate` (`bsc.c:1102`). For any move with nonzero record power it sets `DOESNT_AFFECT_FOE` on a 0x matchup (`:1345-1390`). Present has power 1, so this applies. `resultmessage` (`bsc.c:1937`) then prints `STRINGID_ITDOESNTAFFECT` instead of the miss string.

A probe confirms the engine prints "PLAYER's attack missed!" for Present, and also for an ordinary Tackle (`useMove,miss`, 1 draw). The engine handles this text only for Rampage (`BE:2929-2940`) and Jump Kick (`BE:2887-2900`).

- The draw count (1) and PP are unaffected, so only the text differs.
- V1 did not introduce this, and Fury Cutter cannot hit it (Bug has no 0x row).
- I found no record of the generic ordinary-path gap in the task files, inventory or reviews.
- Present's V1 limits (D4) do not list it.

**Fix:** add "a missed Present against a Ghost prints 'missed' (generic ordinary-path gap; source prints 'It doesn't affect')" to the V1 task limits and to inventory row 122. Track the generic ordinary-path fix as its own follow-up.

### F4 (INFO, wording): "every caller ... whether or not the battler is locked"

The `cancelMultiTurnMoves` comment (`BE:1964-1969`) and V2 task line 75 ("locked or not") list the end-of-turn sleep cancel among callers that reset "whether or not the battler is locked". That caller is itself gated on a lock (`BE:4293-4294`, mirroring `MULTIPLETURNS` at `bmain.c:2941`), and the test at `tests/battle_variable_power_v2_test.lua:366-372` correctly shows an unlocked sleeper keeps its counter. The behaviour is right; only the sentence overreaches. Suggest: "the function resets the counter unconditionally; the end-of-turn sleep caller only runs for a locked sleeper".

### F5 (INFO, citations)

- V1 task: the source lock cites `bsc.c:1781-1786` for the negative-damage clamp. At the pin it is `bsc.c:1789-1794`, and `:1781-1786` is the Substitute-fade branch.
- Proposal §6: the engine line references `BattleEngine.lua:4166` and `:4434` were design-time references and now sit at `:4292-4295` and `:4562-4563`.

### F6 (INFO): the H1 hand-off is otherwise accurate and self-contained

I checked every repository citation:

- `BattlePartyBridge.lua:124-152`, `:156-174`
- `BoxPokemonCodec.lua:161`, `:210-217`
- `StarterPokemonFactory.lua:123`
- `WildPokemonFactory.lua:169-172`, `:244`, `:257`
- `TrainerPokemonFactory.lua:121-128`, `:123`, and `info = args.speciesInfo` (`:81`)
- `import/SpeciesInfo.lua:75`
- `EarlyRivalRewards.lua:121-127`
- the ten `main.lua` call sites
- the "That move's effect is not available yet." text (`BattleSceneController.lua:721`)

I checked every source citation:

- `bsc.c:8228-8236`, `:8503-8530`, `:3314`, `:3316-3329`
- `battle_controller_player.c:1540-1547`, `battle_controller_opponent.c:475-482`
- `pokemon.c:1815`
- `bmain.c:1539-1640`, `:1576`

The note names its owner, scope, status, what blocks and what does not, and the acceptance tests. A reader needs nothing else, apart from F1.
