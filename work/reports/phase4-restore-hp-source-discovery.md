# Effect-32 restore-HP source discovery

- Task: [P4-F1-RESTORE-HP-DISCOVERY](../tasks/phase4-restore-hp-source-discovery.md).
- Status: ordinary represented-state source lock complete; independent exact-report review required.
- Project inspection base: `e80f9f2cffde02a7987d5c55b45f8a7cd3b834d2`.
- Public source pin: `pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Accepted engine baseline: `a739ddc88cb44a33d5e6025e619cf1df3fe6a1a8`;
  engine/controller/party bridge/main are unchanged between that revision and
  the inspection base. Inventory `c10bfa7` has independent PASS, but neither
  that admission inventory nor this source report implements effect 32.

## Identity and research boundary

The initial task incorrectly called move 303 Milk Drink. Inspection stopped at
that conflict; the Orchestrator corrected the task in `e80f9f2` before research
continued. Pinned [move constants](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/include/constants/moves.h#L109)
identify Recover as 105 and Slack Off as 303 (line 307). Milk Drink is 208
(line 212), has effect 157, and remains explicitly excluded. The accepted
inventory's effect-32/IDs-105-and-303 selection is unchanged.

The source's Snatch interception and general cancellation/MoveEnd paths require
unrepresented cross-component state. That boundary was escalated. On 2026-09-29,
the Orchestrator explicitly authorized completing only the ordinary represented-
state path while recording those interactions as hard unresolved exclusions.
This is not a lock of unrestricted retail behavior, an implementation design,
or permission to silently approximate those interactions.

### Exact source metadata

| Move | ID | Effect | Power | Accuracy field | Base PP | Target | Priority | Flags |
| --- | ---: | ---: | ---: | ---: | ---: | --- | ---: | --- |
| Recover | 105 | 32 | 0 | 0 | 20 | USER (16) | 0 | SNATCH_AFFECTED (8) |
| Slack Off | 303 | 32 | 0 | 100 | 10 | USER (16) | 0 | SNATCH_AFFECTED (8) |

Both are Normal type and have secondary-effect chance zero. The exact records
are [Recover, battle_moves.h:1368](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/data/battle_moves.h#L1368)
and [Slack Off, battle_moves.h:3942](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/data/battle_moves.h#L3942).
[Effect constants:36](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/include/constants/battle_move_effects.h#L36)
defines RESTORE_HP=32;
[pokemon.h:241](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/include/constants/pokemon.h#L241)
defines the Snatch flag as bit 3, and
[battle.h:64](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/include/battle.h#L64)
defines USER as bit 4. The accuracy-field difference does **not** create an
accuracy roll: neither move's effect script executes `accuracycheck`.

## Locked ordinary source path

The owner is [BattleScript_EffectRestoreHp:673](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L673).
The following assumes valid living battlers, available PP, ordinary permanent
move use, and no cancellation/interception or excluded state.

1. **Cancellation precedes the normal effect body.**
   [Cmd_attackcanceler:819](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L819)
   checks battle outcome, a fainted attacker, inability-to-act/ability paths,
   no PP, obedience and interception before ordinary continuation. This is
   not a promise that every cancellation is silent or consumes zero RNG.
2. **Announce, then spend PP.** `Cmd_attackstring:1108` dispatches the used-move
   announcement once unless suppressed by hit-marker state. `Cmd_ppreduce:1122`
   follows it and precedes the HP comparison. Normal self-targeting resolves
   the target to the attacker in
   [GetMoveTarget:3122](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_util.c#L3122),
   so the ordinary default Pressure check does not charge an opposing battler's
   extra PP. In this bounded ordinary path one PP is deducted, on success and
   full-HP failure alike. PP controller writeback for a permanent slot belongs
   to `Cmd_ppreduce`; suppressed/called/intercepted move PP rules are excluded.
3. **Calculate, then branch; do not mutate HP yet.**
   [Cmd_tryhealhalfhealth:6332](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L6332)
   receives `BS_ATTACKER`, assigns target=attacker, computes integer maxHP/2,
   promotes a zero result to one and stores the negative healing amount in
   `gBattleMoveDamage`. It compares current HP to maxHP and jumps to the
   full-HP branch on equality. Calculation alone does not update HP.
4. **Successful use presents the move before HP application.** The script
   dispatches move animation and waits for controller completion
   (`Cmd_attackanimation:1662`, `Cmd_waitanimation:1702`). It then sets
   `HITMARKER_IGNORE_SUBSTITUTE`, issues `healthbarupdate BS_ATTACKER`, and
   follows with `datahpupdate BS_ATTACKER`. The ignore-Substitute marker is a
   real source detail, not authorization to model Substitute here.
5. **Clamp belongs to data HP update.**
   [Cmd_healthbarupdate:1708](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L1708)
   sends the signed bar update to the attacker's controller.
   [Cmd_datahpupdate:1744](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L1744),
   specifically its negative-damage branch at 1789, adds healing and clamps
   to that battler's maxHP; it also dispatches HP data writeback. It is not
   ordinary damage, a type-effectiveness result, or healing derived from damage
   dealt to another battler. The defender's HP is unchanged.
6. **Successful feedback follows the HP operations.** The source then emits
   `STRINGID_PKMNREGAINEDHEALTH`, waits `B_WAIT_TIME_LONG`, and jumps to the
   common `BattleScript_MoveEnd:270` (`moveendall`, then `end`). The effect
   script has no direct critical/type/damage calculation, secondary effect or
   `tryfaintmon` command. Common MoveEnd is not a generic no-op; its broader
   stateful behavior remains excluded rather than newly ported.

### Rounding and full-HP failure

For ordinary valid HP `0 < H <= M`, the requested healing amount is
`Q = max(1, floor(M / 2))`. When `H < M`, successful final HP is
`min(M, H + Q)` and the actual gain is that value minus `H`. The source bar
request is the signed requested amount; the authoritative HP clamp is later.
Requested and actual gains must not be conflated when only a small amount is
missing. Odd maxHP rounds down. This is a derivation from the source, not an
executed gameplay test or new API definition.

Examples of that derivation: maxHP 101 requests 50; HP 40 becomes 90, while
HP 100 becomes 101 with actual gain 1. The minimum-one branch exists even for
maxHP 1, but the sole valid living HP at that maximum is already full and
takes the failure path. Fainted/malformed states are not revival cases.

At `H == M`, PP has already been spent. The jump reaches
[BattleScript_AlreadyAtFullHp:2038](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2038):
short pause, `STRINGID_PKMNHPFULL`, long wait, common MoveEnd. It bypasses
the healing animation, HP-bar update, HP data update and recovery-success
message. It does not branch to the generic failure string or directly set a
failed-move result flag. It is still a used action, not a PP refund or retry.
`B_WAIT_TIME_SHORT=32` and `LONG=64` are source constants in
`include/constants/battle.h:308–310`; these are not established LÖVE timing.
The two distinct message IDs are defined in
`include/constants/battle_string_ids.h:76–77`; no game text is copied here.

### Accuracy, RNG and cancellation limits

The ordinary effect body and its full-HP branch contain no accuracy command,
critical roll, damage RNG or type-effectiveness computation. Slack Off must
not acquire an accuracy/evasion roll merely because its record stores 100;
Recover's zero accuracy field is likewise not a failure percentage.
There is no effect-body gameplay RNG draw in the stated represented-state path.
This does not mean a whole turn or full retail action consumes no RNG:
turn-order ties, the opposing action, general cancellation/obedience and
excluded interactions are outside that claim; animation parity is also absent.

No-PP cancellation is not full-HP failure. The source cancellation jumps to
`BattleScript_NoPPForMove:3509`, which can announce the move and then show its
no-PP feedback without `ppreduce` or healing. The current engine instead has
an existing defensive `noPP` event path and an all-empty-slots Struggle path.
Their precise interface/presentation differences are pre-existing boundaries,
not something this effect discovery silently corrects or certifies as parity.

## Current engine/controller comparison

Project line anchors use the inspection base. Relevant owners are
[BattleEngine](../../src/core/BattleEngine.lua),
[BattleSceneController](../../src/core/BattleSceneController.lua),
[BattleFormulas](../../src/core/BattleFormulas.lua),
[BattlePartyBridge](../../src/core/BattlePartyBridge.lua) and [main](../../main.lua).
The table identifies seams and missing contracts, not an implementation plan.

| Required source action | Existing project seam | Missing or ambiguous boundary |
| --- | --- | --- |
| Admit exactly the in-scope effect | `supportsMove`:859 allows positive power, listed stats/screens and Pain Split | Effect 32 is absent and both moves are rejected. No broader zero-power/healing admission is implied. |
| Schedule an ordinary action and stop a fainted actor | `runTurn`:1614 asserts active battle/no pending switch; its ordinary loop at 1752 checks acting HP | Shared cancellation/status/obedience/interception is not implemented. Direct `resolveMove` is not a full retail cancellation interpreter. |
| Select available move / handle no PP | `resolveMove`:869 checks all-empty slots/Struggle; chosen-slot `noPP` branch starts at 945 | Admission currently fails before an effect-32 no-PP path. Existing no-PP event ordering is not the source script's full announcement sequence; no policy change is authorized. |
| Used-move announcement | `useMove` event at engine:951; controller `_eventMessages`:177 formats it | Reusable ordering seam exists; no recovery-specific result follows it today. |
| Spend PP once before viability | Shared decrement branch at engine:1065; special-effect precedents have distinct order | Must preserve source PP-before-full-HP comparison and ordinary one-PP rule; event/API ownership for a new leaf remains undecided. |
| No accuracy/critical/type/damage path | Engine:1036 constructs accuracy eligibility; formula `accuracyCheck`:431 consumes RNG | Effect 32 is not exempt. Changing admission alone would send it through the wrong accuracy path and, on successful accuracy, reach a nil stat-entry branch at 1097. No code was changed to test that counterfactual. |
| Half-own-max calculation and viability | Battlers already expose HP/maxHP; drain/Pain Split have bounded own-HP updates | No effect-32 calculation/full-HP branch exists. Drain is damage-derived and Pain Split is two-sided; neither is a valid semantic substitute. |
| Animation and wait | Controller has a message queue, not this source move-animation protocol | Exact animation/timing parity is unresolved and excluded. No generic animation system is requested. |
| Ordered own-HP bar/data update before feedback | `_applyInvisibleEntries`:103 updates displayed HP from ordered entries; Pain Split uses it | Existing mechanism is a seam, not an effect-32 event contract. Event name, fields, requested-versus-actual amount and displayed-HP timing remain for later design. |
| Successful recovery feedback | Controller handles `drain` and `painSplit`, but neither describes this source result | A recovery-specific presentation contract is absent. Reusing drain would describe an energy transfer from the defender that never happened. |
| Full-HP feedback without HP mutation | Existing `moveFailed` maps to generic failure | Source uses a distinct HP-full result; its dedicated representation and timing remain undecided. No fake zero-heal success is justified. |
| End action without self-induced faint/terminal mutation | Existing ordinary turn completion and side-timer handling remain | No new effect-specific faint/replacement behavior is needed by the ordinary source path; broader MoveEnd interactions remain a hard exclusion. |
| Persist represented HP/PP | `persistPartyBattler`:178 copies current PP/HP; main:4451 calls it when the engine turn changes | Existing save-backed player seam is present, not verified recovery integration. No schema, save policy, battle caller or persistence changes are authorized. |

The player controller's `_runTurn`:324 currently reports unsupported effect
and returns to MOVE without running the turn. Foe selection/AI is a separate
consumer; the source lock does not make Misty's roster or AI playable.
`getWhoStrikesFirst`:512 can consume tie-break RNG independently of the effect.
HP/PP state has existing storage, but that does not prove a new healing path.

## Hard unresolved exclusions and smallest future design boundary

**Snatch is a real dependency, not an inferred optional feature.** Flags 8
enter the Snatch branch in `Cmd_attackcanceler`; the separate
[BattleScript_SnatchedMove:3617](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L3617)
changes battler ownership and PP/announcement markers. Current engine state
does not represent that interception. This report stops at that boundary;
it neither specifies a substitute nor claims the ordinary path covers it.

Also unresolved/outside the lock: status/obedience and move-prevention paths,
called or intercepted move provenance and PP suppression, generic abilities or
held items, Substitute state despite the source bypass marker, and general
`Cmd_moveend:4056` cleanup/interactions. Protect/Magic Coat/Mirror Move flags
are not set in these two records, but that fact is not blanket certification
of the shared cancellation/interaction machinery. Doubles/links, malformed
state, revival, animation/timing and visual parity are excluded.

If this report independently passes, the smallest possible future design
discussion is one dedicated effect-32 leaf for Recover/Slack Off, valid living
represented singles, available PP, ordinary non-intercepted use, both attacker
sides, own-max rounding/clamping, distinct success/full-HP presentation and
their exact event order. It must explicitly retain the exclusions above and
decide the missing admission/event/presentation contracts rather than reuse
unrelated damage/drain semantics. This paragraph defines a proposed boundary
only; no API shape, patch, implementation task or test package is drafted.

Do not include Milk Drink 208/effect 157, Softboiled, any field healing, Rest,
Present, Wish, Swallow, Ingrain, weather recovery or a generic healing API.
The locked source behavior is not current effect support. Full retail effect-32
parity remains blocked on the excluded shared systems; their behavior and
integration are not proven by this report.

## Evidence and handoff

Only public source and repository history/code were read. The source pin and
project base were independently recovered; source metadata, command/script
anchors and unchanged accepted engine seams were checked. No ROM, private
runner, media, runtime experiment, gameplay test or full suite was used.
Read-only text/path/diff checks are recorded in the task handoff.

Only this report and its task research/handoff may change. The Orchestrator
may publish the bounded research, but independent exact-report PASS must precede
any design task. No self-review or Phase 4 advancement is claimed.
