# Review: Phase 4 confusion and flinch (status2) design proposal

- Reviewer: independent design Reviewer (Claude), per `AGENTS.md` rule 6
- Date: 2026-10-14
- Artifact: [`work/reports/phase4-confusion-flinch-design-proposal.md`](../reports/phase4-confusion-flinch-design-proposal.md) at commit `edc7b41`
- Project baseline read: `src/core/BattleEngine.lua`, `BattleFormulas.lua`, `StatusConditions.lua`, `AICheckBadMove.lua`, `BattlePartyBridge.lua` at `edc7b41`; `TrainerAI.lua`, `TrainerBattleOrchestrator.lua`, `main.lua` switch paths
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Verdict: **PASS WITH CORRECTIONS**. There are no Blocker findings. Four Medium findings change what C1/C2 must implement or test. Eight Low findings fix wording, citations and test lists. Apply the correction text below before the C1/C2 task contracts are cut.

## Summary

The core mechanics are right:
- the status2 layout;
- the SetMoveEffect guards and the CONFUSION/FLINCH branches;
- the canceller order and the resume-after-push behaviour;
- the self-hit `CalculateBaseDamage` call and `adjustnormaldamage2`;
- family membership and texts;
- the faint and switch-in clearing.

The design (per-battler `confusionTurns`/`flinched`, not persisted, the self-hit reusing `BattleFormulas.calculateBaseDamage` with a Pound-like record) fits the engine.

The corrections are these:
- One flinch-clear citation is wrong: `battle_main.c:2917` runs once at battle start, not at each turn start.
- Snore's "fast asleep" text is currently emitted in the wrong place once the flinch and confusion cancellers exist.
- The flinch turn-order rule should be stated as a turn-order position rule, keyed by side.
- C2 needs explicit RNG handling for no-effect and KO hits.
- The Swagger/Flatter script shape is incomplete.

Process note: commit `7cb1018` ("Confusion/flinch C1") landed on `claude/wizardly-faraday-o45q9z` while this design review was in progress. This review does not review that commit. Findings 2, 3 and 8 apply to it as written: it emits `fastAsleep` inside the sleep canceller, ahead of the new flinch and confusion cancellers.

## Verified correct (no change needed)

| Claim | Source evidence | Result |
| --- | --- | --- |
| status2: confusion bits 0-2, `STATUS2_FLINCHED` bit 3 | `include/constants/battle.h:105-107` | ✓ |
| `MOVE_EFFECT_CONFUSION` 7, `MOVE_EFFECT_FLINCH` 8, `PRIMARY_STATUS_MOVE_EFFECT` 6 | `include/constants/battle.h:227-229` | ✓ |
| Common guards in order: Shield Dust `!primary && byte <= 9`, Safeguard `!primary && byte <= 7`, `hp == 0` (not Pay Day or Thief), Substitute on the target | `src/battle_script_commands.c:2132-2146` | ✓. Confusion and flinch are both blocked by Shield Dust. Safeguard blocks only secondary confusion. |
| status2 branch: an already-set flag is skipped silently (`:2395-2398`). CONFUSION: Own Tempo or already confused is silent; otherwise `Random() % 4 + 2`, then push `BattleScript_MoveEffectConfusion` | `:2395-2418`; `data/battle_scripts_1.s:3893-3897` | ✓ |
| FLINCH: Inner Focus gives text only when primary or certain (`BattleScript_FlinchPrevention`), otherwise silent; the bit is set only if `GetBattlerTurnOrderNum(target) > gCurrentTurnActionNumber` | `:2419-2439`, `:2092-2100`; `bs1.s:4109-4113` | ✓ |
| Canceller enum order Sleep, Frozen, Truant, Recharge, Flinch, Disabled, Taunt, Imprisoned, Confused, Paralysed, ... The loop stops at the first canceller with an effect. `atkCancellerTracker++` runs before the break, so a pushed cursor re-enters `attackcanceler` at the next canceller | `src/battle_util.c:1235-1251`, `:1531`; `bsc.c:819-835` | ✓ |
| Flinch canceller: clear the bit, then "flinched", no attackstring or PP | `battle_util.c:1361-1371`; `bs1.s:3720-3723` | ✓ |
| Confused canceller: decrement first. On the proceed path (`Random() & 1` nonzero) the cursor is pushed and `BattleScript_MoveUsedIsConfusedRet` returns, so Paralysed and the later cancellers still run. **Snapped out** also pushes the cursor (`BattleScript_MoveUsedIsConfusedNoMore` ends in `return`), so the paralysis check still runs | `battle_util.c:1407-1435`; `bs1.s:3736-3762` | ✓ both paths |
| Self-hit `CalculateBaseDamage(atk, atk, MOVE_POUND, 0, 40, 0, atk, atk)` with `gCritMultiplier` already reset to 1 at move start, then `adjustnormaldamage2` (one `ApplyRandomDmgMultiplier` draw; the Focus Band draw happens only when holding it), the HP update, `tryfaintmon BS_ATTACKER` | `battle_util.c:1423`; `battle_main.c:3974`; `bsc.c:1620-1656`; `bs1.s:3741-3755` | ✓ |
| Attacker equals defender, so Huge Power/Pure Power, Hustle, Guts (×1.5 and burn exemption) and Marvel Scale all apply, along with the attacker's own Atk and Def stages and burn halving. No STAB, no typecalc, no screens (sideStatus 0) | `src/pokemon.c` CalculateBaseDamage | ✓. The project's `calculateBaseDamage(battler, battler, pound, false, nil)` reproduces every modeled term. |
| Explosion quirk: the self-hit tests `gBattleMoves[gCurrentMove].effect == EFFECT_EXPLOSION` | `pokemon.c` ("Self-destruct / Explosion cut defense in half") | ✓ |
| Texts: is confused :114, snapped out :115, became confused :116, flinched :123, hurt itself :337 | `src/battle_message.c` | ✓ |
| status2 is zeroed on faint (`Cmd_cleareffectsonfaint` → `FaintClearSetData`, `battle_main.c:2434-2441`) and on an ordinary switch-in (`SwitchInClearSetData`, `battle_main.c:2350-2368`; Baton Pass n/a) | as cited | ✓. The engine builds every switch-in fresh: `BattlePartyBridge.battlerFromParty` (voluntary and forced) and `TrainerBattleOrchestrator.toBattler`. `persistPartyBattler` writes only PP, HP and status1, so confusion is never persisted. |
| Family membership: 76 = Psybeam, Confusion, Dizzy Punch, Dynamic Punch, Signal Beam, Water Pulse; 31 = Rolling Kick, Headbutt, Bite, Bone Club, Rock Slide, Hyper Fang; 150 = Stomp, Needle Arm, Astonish, Extrasensory; 146 Twister; 49 = Supersonic, Confuse Ray, Sweet Kiss; 118 Swagger; 166 Flatter; 199 Teeter Dance; 92 Snore | `battle_moves.h`, `battle_effects.h` | ✓ |
| Confuse (49) order: Own Tempo text, Substitute "failed", already-confused text, accuracy, Safeguard, `seteffectprimary` | `bs1.s:902-922` | ✓ |
| Teeter Dance in singles: the loop over battlers 0..1 skips the attacker, so it reaches only the foe. Order: Own Tempo, Substitute, already confused, accuracy, Safeguard | `bs1.s:2566-2610` | ✓ |
| Snore: awake (including woke up this turn) gives attackstring, ppreduce, "But it failed". Asleep gives "fast asleep" (skipped when called through Sleep Talk), attackstring, ppreduce, accuracy, then a hit with FLINCH | `bs1.s:1253-1267`; `battle_util.c:1266-1307` | ✓ |
| Stomp/Twister doubling is unreachable. Minimize (EFFECT_MINIMIZE 108, power 0) is in no admitted table, so `supportsMove` returns false and STATUS3_MINIMIZED is never set. STATUS3_ON_AIR is never set because Fly, Dig and Bounce are admitted only as one-turn hits through the positive-power fallback | `BattleEngine.lua` `supportsMove`, `STAT_STAGE_MOVES` | ✓ |
| AI_CBM_Confuse (Confuse, Swagger, Flatter) | `data/battle_ai_scripts.s:132,169,193,390-395` | ✓. See Finding 9 for the exclusive-branch wording. |
| Synchronize n/a (it passes only status1). Multi-hit plus flinch n/a (no Gen 3 multi-hit move carries FLINCH). Confusion has no end-of-turn component | source | ✓ |

## Findings

### 1. Medium: the flinch-clear points are mis-cited

Evidence: `src/battle_main.c:2917` is inside `TryDoEventsBeforeFirstTurn` (from `:2856`). It runs once before the first turn, not at the start of every turn. The only per-turn clear is `:2940` in `HandleEndTurn_ContinueBattle`, which runs after every action of the turn has resolved (`:3711-3714`, `sEndTurnFuncsTable[0]`) and before `BattleTurnPassed`'s end-turn effects. The engine plan ("cleared at `runTurn` start and in the end-turn phase") is observably equivalent, because nothing reads a flinch across a turn boundary. Only the source description is wrong.

Correction (replace the "Flinch is cleared ..." bullet):
> Flinch is cleared for every battler once before the first turn (`TryDoEventsBeforeFirstTurn`, `src/battle_main.c:2917`) and after each turn's actions, before the end-turn effects (`HandleEndTurn_ContinueBattle`, `:2940`). Battle end and faint (`FaintClearSetData`) also drop it. In the engine, clearing both battlers' `flinched` at the top of `runTurn` (which also covers the switch, capture, run and halted-turn early returns) is the equivalent single clear point. A clear in the end-turn phase is optional.

### 2. Medium: Snore's "fast asleep" must follow the flinch and confusion cancellers

Evidence: for Snore and Sleep Talk, `CANCELLER_ASLEEP` decrements the sleep counter and has no effect while the battler stays asleep (`battle_util.c:1289-1296`). The cancellers continue. "X is fast asleep." is printed by `BattleScript_EffectSnore` after `attackcanceler` returns (`bs1.s:1259-1262`). So in source:
- a flinched sleeping Snore user prints only "X flinched!";
- a confused one prints "X is confused!" before "fast asleep";
- one that hurts itself never prints "fast asleep".

The baseline engine, and `7cb1018`, emit `fastAsleep` inside the sleep canceller (`BattleEngine.lua` `resolveStatusCancellers`), so the new cancellers would produce the wrong order.

Correction (add under Design → cancellers, C1):
> For Snore/Sleep Talk while the user stays asleep, the sleep canceller emits nothing. The `fastAsleep` event is emitted after `resolveStatusCancellers` returns false, immediately before `useMove`, matching `BattleScript_EffectSnore`'s print after `attackcanceler`. C1 tests: a sleeping and flinched Snore user gives `flinched` only. A sleeping and confused Snore user gives `confusedTurn` then `fastAsleep` (proceed), or `confusedTurn` then `confusionSelfHit` with no `fastAsleep` (self-hit). The sleep counter is decremented in every case.

### 3. Medium: state the flinch rule as a turn-order position, keyed by side

Evidence: `GetBattlerTurnOrderNum(target) > gCurrentTurnActionNumber` compares positions in `gBattlerByTurnOrder`. It does not test whether the target has actually acted. A first mover that was asleep, frozen, paralysed, flinched or hurt itself still holds the earlier position. Hoisted switch, item and run actions occupy position 0 (`SetActionsAndBattlersTurnOrder`). The engine allows those only for the player, and the foe always moves after them. The proposal's `actedThisTurn`, "set when a side's action resolves", invites two bugs:
- not setting it for a cancelled first move;
- storing it on the battler object, where a voluntarily switched-in battler is a fresh object that would read "not acted" and be flinched silently.

The second case is unobservable, because the flag is cleared next turn, but it is wrong.

Correction (replace the `actedThisTurn` bullet):
> Flinch is applied only when the target's turn-order position is later than the current action's. In this singles engine that means only when the attacker is `order[1]` of a two-move turn and the target is `order[2]`. It is never applied in a hoisted switch, capture or run turn (the player's action holds position 0 and the foe's move position 1). It is never applied by the second mover. Position, not completion, decides: a first mover whose move was cancelled still counts. No new persistent state is needed. Pass the attacker's position (first or second) into the move resolution.

### 4. Medium: C2 RNG on no-effect, KO and blocked hits

Evidence: `Cmd_seteffectwithchance` evaluates `Random() % 100 <= percentChance` first (`bsc.c:2789`). The draw is consumed on every non-miss hit that reaches the command:
- a typecalc ×0 hit, for example Headbutt, Hyper Fang, Stomp, Dizzy Punch or Snore into a Ghost; the effect is then blocked by `MOVE_RESULT_NO_EFFECT`;
- a hit that KOs the target; `SetMoveEffect` returns at `hp == 0` (`:2140`);
- a Shield Dust target (`:2132`).

Dynamic Punch (chance 100) still draws and passes `MOVE_EFFECT_CERTAIN`. A miss draws nothing. The engine's no-effect branch draws only for the effect tables it lists (`BattleEngine.lua`, the `flags.noEffect` block).

Correction (add to C2 / Risks):
> C2 adds EFFECT_FLINCH_HIT 31, CONFUSE_HIT 76, TWISTER 146, FLINCH_MINIMIZE_HIT 150 and SNORE 92 (asleep path) to the no-effect roll-consumption list. On an effective hit the roll is drawn after `applyDamage`. A KO'd target (`hp == 0`), a Shield Dust target and an already-confused target each consume the roll but apply nothing, and the confusion `% 4` draw does not happen. Tests cover each of these draw counts. The flinch check (Finding 3) adds no draw.

### 5. Low: the Swagger/Flatter shape is incomplete

Evidence (`bs1.s:1604-1624`, `:2147-2167`; `bsc.c:8196-8203`, `ChangeStatBuffs` `:6797-6815`):
- Substitute (unmodeled) goes to `MakeMoveMissed` before accuracy.
- A miss goes through `PrintMoveMissed`: attackstring, ppreduce, then "missed". PP is spent.
- `jumpifconfusedandstatmaxed` fails ("But it failed!", after PP) only when the target is confused **and** the stat is at +6.
- A target that is already confused with the stat below +6 has the stat raised. The confusion is then skipped silently by SetMoveEffect's status2 check, with no "already confused" text.
- A target with the stat at +6 that is not confused gets no stat text. With `STAT_CHANGE_ALLOW_PTR`, `B_MSG_STAT_WONT_INCREASE` sets `MOVE_RESULT_MISSED` and returns WORKED, the `jumpifbyte` skips the message, and confusion is still applied.
- The Own Tempo text comes after the stat step.

Correction (replace the 118/166 row's shape cell):
> attackcanceler; [Substitute → missed]; accuracycheck (miss: attackstring, ppreduce, missed); attackstring; ppreduce; target confused AND stat == +6 → But it failed; stat +2 ATK (Swagger) or +1 SP.ATK (Flatter), with the rise text unless the stat is already +6 (silent); Own Tempo → prevents-confusion text; [Safeguard]; seteffectprimary CONFUSION (already confused → silent; otherwise `% 4` draw and "became confused").

### 6. Low: the self-hit type wording and inherited gaps

Evidence: `typeOverride` 0 means "no override" (`if (!typeOverride) type = gBattleMoves[move].type`), so the hit is Pound's type, Normal (TYPE_NORMAL is also 0). It is not typeless. Normal-gated terms apply. Silk Scarf would apply, but held items are unmodeled. Badge boosts apply to both the attack and the defense of the same player battler. That is the engine's existing unrepresented-badge gap and is inherited here.

`BattleScript_DoSelfConfusionDmg` also runs `cancelmultiturnmoves` and sets `HITMARKER_IGNORE_SUBSTITUTE | HITMARKER_PASSIVE_DAMAGE`. `confusionSelfDmg` suppresses Rough Skin, Effect Spore, Poison Point and Static (`battle_util.c:1985-2038`). None of these is modeled today.

Correction:
> Replace "typeless Normal-physical base" with "Normal-type physical base (type 0 = no override, so Pound's Normal type)". Add: "Inherited gaps: badge boosts and held items (Silk Scarf, Choice Band, Focus Band) are not represented. Future contact abilities must not trigger on the self-hit (`confusionSelfDmg`)."

### 7. Low: say what happens when the self-hit ends the battle or forces a switch

Evidence: `tryfaintmon BS_ATTACKER` leads to `checkteamslost`. Once `gBattleOutcome` is set, the next action's `attackcanceler` finishes immediately (`bsc.c:823-827`). The engine's `checkFaint` inside the canceller, followed by `runTurn`'s `isOver()` / `awaitingForcedSwitch` test, matches this when the battle is decided. When a replacement exists, the engine halts the turn under its already-documented recoil-KO policy.

Correction (replace the last Risks bullet):
> The self-hit faint uses `checkFaint(attackerSide)`, as recoil does. With no replacement the battle ends at once (no further action, no end-turn phase). With a replacement it queues the forced switch and the turn halts under the existing documented recoil-KO policy, with end-turn effects still run. C1 tests cover both, plus a first mover's self-KO in a wild battle.

### 8. Low: the C1 acceptance list lacks the status1 interplay

Evidence: sleep (no push, `effect = 2`) and staying frozen stop the loop before Flinch and Confused, so the confusion counter is **not** decremented that turn. "Woke up" and "thawed" push the cursor and continue into Flinch and Confused. Snore/Sleep Talk while asleep pass the sleep canceller and run the confusion canceller (`battle_util.c:1266-1333`).

Correction (add to C1):
> Tests: a confused battler that stays asleep (non-Snore) or stays frozen keeps its `confusionTurns`. Waking or thawing proceeds to flinch, then confusion, in the same attempt. A confused, paralysed battler that passes confusion still draws the `% 4` paralysis roll, on both the proceed and snapped-out paths. Snapping out draws nothing.

### 9. Low: the AI section wording

Evidence: `Score_Minus5` ends the script (`battle_ai_scripts.s:616-618`), so the branches are exclusive. An already-confused target scores −5 and Own Tempo is not checked. The Safeguard line is commented out (an Emerald change). AI_CV_Confuse, AI_CV_Flatter and the confusion terms in AI_CV_Substitute, Counter, Mirror Coat, Focus Punch and Revenge (`:1553-1569`, `:1681`, `:1728`, `:2246`, `:2418`, `:2584`) are not ported. CHECK_VIABILITY runs only through `EarlyRivalAI`'s bounded move set (`TrainerAI.choose`), so this is not a regression.

Correction:
> AI_CBM_Confuse: target already confused → −5 and end; else Own Tempo → −10. C1 changes only the first test. AI_CV terms that read STATUS2_CONFUSION stay out of scope while CHECK_VIABILITY is limited to EarlyRivalAI's moves.

### 10. Low: `flinchPrevented` is unreachable in C1/C2

Evidence: the Inner Focus text needs `primary == TRUE || certain` (`bsc.c:2423`). Every in-scope flinch move has a chance of 10, 20 or 30, and Fake Out (CERTAIN) is out of scope. In C2, Inner Focus is always a silent block.

Correction:
> Inner Focus silently blocks every C2 flinch. The `flinchPrevented` event (text `src/battle_message.c:296`) is reserved for Fake Out and is not emitted or tested in C1/C2.

### 11. Low: citation hygiene

Evidence: in the Confused bullet, `:1620-1660` refers to `src/battle_script_commands.c` and `:114/:115/:337` refer to `src/battle_message.c`, yet both sit under a `battle_util.c` context. The faint clear of status2 is `FaintClearSetData`. Missing texts: already confused `battle_message.c:117`, Own Tempo prevents `:273`, Inner Focus `:296`, fast asleep `:162`.

Correction: qualify every bare `:NNN` with its file, cite `FaintClearSetData` (`src/battle_main.c:2434-2441`) and `SwitchInClearSetData` (`:2350-2368`), and add the four text citations.

### 12. Low: the inherited C2 secondary-effect gaps are not listed

Evidence: `Cmd_seteffectwithchance` doubles the chance for Serene Grace (`bsc.c:2778-2781`). `BattleFormulas.secondaryEffectRoll` does not model it (an existing gap shared with the S2 status-hit families). Safeguard and Substitute are unmodeled. Sky Attack (EFFECT_SKY_ATTACK 75, 30% flinch) stays a plain hit through the positive-power fallback, as an out-of-scope two-turn move.

Correction (add to "Not in scope"):
> Serene Grace doubling (an existing gap), Safeguard, Substitute, Sky Attack's flinch (two-turn), King's Rock, and Persim/Lum confusion cures (held items unmodeled).

## Recommendation

Apply Findings 1-5 to the proposal text and carry Findings 2, 3, 7 and 8 into the C1 task's acceptance list. With those changes the design is source-conformant for C1 and C2. Commit `7cb1018` needs Finding 2 (the Snore `fastAsleep` placement) and the Finding 8 tests before its C1 review can pass.

## Disposition (Worker, 2026-10-14)

Corrections 1-12 applied to the proposal; F2/F7/F8 implemented and tested in C1 (task file); F3/F4/F5 carried into the C2 design text.
