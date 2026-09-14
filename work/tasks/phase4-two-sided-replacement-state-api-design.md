# Task: Phase 4 two-sided replacement-state/API migration design

- Status: `ACTIVE`
- Type: `PHASE 4 / BATTLE RULES / READ-ONLY IMPLEMENTATION DESIGN`

## Goal

Design the smallest compatible migration from one immediate faint decision and
one scalar forced-switch side to an ordered, two-sided post-faint sequence.
The design must preserve all existing ordinary single-faint paths and make the
future Explosion leaf testable without implementing either change.

## Required evidence

1. Specify engine sequence-recording, terminal evaluation, pending-request,
   and resolution APIs, including the legacy one-side compatibility boundary.
2. Specify controller and `main.lua` handoff behavior for player-first then
   foe replacement, message timing, persistent party synchronization, and
   no action-menu gap while any request remains.
3. Specify terminal settlement for `playerWon`, `playerLost`, and the newly
   required `playerDrew`, including ordinary trainer, Oak-lab rival, and wild
   paths.
4. Define focused unit/controller/ROM/replay test requirements, exact
   implementation files, exclusions, and the criterion for a later bridge
   route. Update only task/STATE/HANDOFF/EXECUTION_MAP.

## MUST NOT CHANGE

No battle behavior, tests, bridge configuration, UI, AI, trainer layouts,
held items, move-effect dispatch, or Phase-completion status. Do not create a
Local Worker route or implement the state migration or Explosion.

## Design conclusion

### Engine contract

`BattleEngine` must retain its current scalar `awaitingForcedSwitch` as a
read-compatible view of the queue head for existing callers, but make an
ordered `pendingForcedSwitches` collection authoritative. The new sequence
boundary is explicit:

1. `beginFaintSequence()` starts an empty ordered record for one completed
   action resolution.
2. `recordFaint(side, events)` clamps HP to zero and appends the existing
   `{type="faint", side=...}` event, but creates neither terminal outcome nor
   forced-switch request.
3. `finalizeFaintSequence(events)` evaluates both sides' whole-team survival
   exactly once using the caller-supplied team-availability predicate. If both
   teams have no living member, it emits exactly one `playerDrew` terminal
   `battleEnd`; otherwise, player-only exhaustion emits `playerLost` and
   foe-only exhaustion emits `playerWon`. Only when neither team is exhausted
   may it queue the recorded fainted sides (each now necessarily has a legal
   replacement) in retail battler order player then foe, emit
   `forcedSwitchNeeded` in that same order, and expose the first side through
   `awaitingForcedSwitch`. Terminal cases create no pending request.
4. `resolveForcedSwitch(side, newBattler)` must accept only the queue head,
   replace it, pop it, update the scalar view to the next side or nil, and
   emit one existing `forcedSwitchResolved` event. `runTurn` remains blocked
   while the queue is nonempty.

For compatibility, existing single-faint callers may use a narrow wrapper that
begins, records one side, and finalizes in the same call. Default/no-party
tracking remains the existing immediate single-faint result. No code may
evaluate a terminal outcome or request a replacement until a multi-faint
producer has explicitly finalized its entire sequence. Recoil/drain and
ordinary hits retain their present one-faint wrapper and event ordering;
Explosion is the first future producer allowed to record both target and
attacker before finalization.

### Presentation and persistence contract

`BattleSceneController` needs a single "after messages" resolver based on the
queue head, rather than hard-coding only `awaitingForcedSwitch == "player"`.
After faint messages drain, it must: enter cancel-proof PARTY only for a player
head; invoke the existing opt-in message-complete hook for a foe head; and
remain in MESSAGES/PARTY until the queue is empty or terminal outcome is set.
When a player selection pops the head and reveals a foe head, its return
messages must route back through the same resolver—not ACTION—so the foe is
automatically replaced before another input/action menu can occur.

`main.lua` retains the save-backed eligibility validation and outgoing HP/PP
persistence at every player transition. It must adapt both its forced-choice
callback and its `onMessagesComplete` foe replacement hook to consume only the
current queue head. `TrainerBattleOrchestrator:resolveFoeReplacement` similarly
continues to settle one defeated foe exactly once, but verifies the foe head
instead of assuming the scalar is the only pending state. In the both-sides
case the player outgoing record is persisted before its selector, then the foe
reward/replacement happens only after that legal player replacement and its
messages; no trainer victory flag/reward is settled until a later real
`playerWon` terminal result.

### Terminal settlement contract

`playerDrew` is a loss-equivalent/whiteout terminal result for local play,
matching retail `B_OUTCOME_DREW`'s `IsPlayerDefeated` classification. General
trainer settlement must apply the existing loss money/heal/respawn path for
both `playerLost` and `playerDrew`, never award EXP or set the trainer flag on
a draw. Wild settlement must do the same. The Oak-lab rival's presently
two-outcome assertion must explicitly accept and handle `playerDrew` as its
loss-equivalent completion rather than crashing; the task that implements this
must source-check the special-script consequence before changing that bespoke
story path.

### Required implementation surface and tests

The later implementation task is limited to `src/core/BattleEngine.lua`,
`src/core/BattleSceneController.lua`, `src/core/TrainerBattleOrchestrator.lua`,
`main.lua`, existing focused tests, and narrowly named new tests/replays if
needed. Required coverage is:

1. Legacy/default and ordinary one-side forced-switch behavior remains exact,
   including scalar visibility, cancellation rules, message ordering, and
   timer behavior.
2. A synthetic two-faint sequence with both benches records both faint events
   before any request, queues player then foe, blocks turns throughout, and
   reaches no ACTION menu between player choice and foe automatic send-out.
3. Player-only, foe-only, and both-team exhaustion emit respectively
   `playerLost`, `playerWon`, and `playerDrew`, with one `battleEnd` and no
   pending request. Draw settlement whiteouts without EXP/trainer flag.
4. Save-backed player persistence, foe reward exactly-once semantics, stale or
   forged party selection rejection, and existing one- and two-foe trainer
   ROM fixtures remain covered.
5. Full no-ROM suite plus focused and verified-ROM/replay evidence pass before
   publication.

No Local Worker Bridge route is eligible until this design receives independent
PASS. Even then the first route is the state/API migration only; Explosion,
doubles, links, held-item survival, and other self-KO families stay excluded.
