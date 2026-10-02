# Ordinary Recover / Slack Off design

- Task: [P4-F2-RESTORE-HP-DESIGN](../tasks/phase4-restore-hp-design.md).
- Status: proposed contract; independent exact-revision design review required.
- Inspection base: `1a312f67751ccdd8fdb1b38ea9d85884cd6ed7d8`.
- Authority: [accepted F1 source lock](phase4-restore-hp-source-discovery.md),
  exact `1f89f0d53b1df3b22ea974eb99d9caed6f86c7f1`, and its
  [independent PASS](../reviews/2026-09-29-restore-hp-source-discovery-review.md).
- Reference pin: `pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

This report specifies one prospective ordinary effect-32 leaf, not current
support, implementation authority, or full retail parity. Runtime owners below
are unchanged from accepted engine `a739ddc88cb44a33d5e6025e619cf1df3fe6a1a8`.
Line numbers refer to the inspection base. No runtime or tests are changed.

## Domain and literal admission

The domain is ordinary permanent-slot use by either living singles battler,
with valid integer HP `0 < H <= M`, positive integer maxHP `M`, available PP,
and no excluded cancellation, interception, status, item or ability interaction.
Only Recover (105) and Slack Off (303), both effect 32, are included. Their
source records are respectively accuracy 0 / PP 20 and accuracy 100 / PP 10;
both have power 0, Normal type, secondary chance 0, USER target 16, priority 0
and flags 8. Metadata remains data, not a replacement for source script order.
Neither the common Snatch flag nor a successful admission check certifies an
unrepresented battle context as safe or equivalent to retail.

At present, `BattleEngine:supportsMove`:859 rejects both records; the controller
at `_runTurn`:324 returns unsupported feedback to MOVE without running a turn.
Direct ordinary engine resolution rejects them before the chosen-slot no-PP
branch. The positive-power fallback does not cover these zero-power moves.
Admission alone would leave the wrong accuracy path and nil stat-entry access.

The proposed admission interface is `supportsMove(move, moveId)`. The second
argument is optional for all existing non-32 behavior, but required for this
new allowance. This is necessary because [BattleMove](../../import/BattleMove.lua)
`parseRecord`:35 contains no move ID; `parseTable`:50 stores identity only in
its table key. Do not add a field to imported records, scan by table identity,
or infer identity from names, accuracy, PP or flags.

| Input | Proposed result |
| --- | --- |
| Missing record | `false`, as today |
| Effect 32, ID 105 or 303, power 0, target exactly USER 16 | `true` for this bounded leaf |
| Effect 32 with absent/other ID, positive/nonzero power, or another target | `false`; no broad fallback for this family |
| Any non-32 record | Existing predicate unchanged: Dream Eater rejection, positive-power fallback, listed stats/screens and Pain Split |

The effect-32 check must precede the broad positive-power predicate. The power
and target guards bound the designed action shape; they are not general ROM
validation. Other source metadata is verified by later source-lock fixtures,
not converted into a new admission framework. A supplied ID is the caller's
existing catalog key, not a security token or new claim to support modified
records. Synthetic invalid-shape cases define refusal controls only.

The two runtime callers already know that key. `resolveMove`:917 passes the
selected slot's ID (or existing Struggle ID when substituted); `_runTurn`:334
passes the player slot ID. Resolve the effective ID before its admission call;
do not change move selection, importer data, AI scoring, or the Struggle policy.
Record-only callers intentionally cannot opt an anonymous effect-32 record in.
Non-32 callers that omit the new argument retain their existing behavior.

## Ordinary action contract

The source authority is `BattleScript_EffectRestoreHp:673`,
`Cmd_tryhealhalfhealth:6332`, the negative-healing branch of
`Cmd_datahpupdate:1789`, and `BattleScript_AlreadyAtFullHp:2038`, as locked in
F1. Existing engine events describe resolved state; they are not an interpreter
for those scripts or their asynchronous controller commands.

After existing selection/admission/no-PP handling, the action order is:

1. Append the existing `useMove` event, identifying acting side and move ID.
2. Deduct exactly one PP from that permanent slot, once, before HP viability.
   Use the existing shared PP owner at `resolveMove`:1065; no second decrement,
   refund, enemy Pressure surcharge, or per-HP-update PP event is introduced.
3. Compute `Q = max(1, floor(M / 2))`. This is a positive requested gain, not
   damage dealt to the other battler. Compare the acting battler's `H` with
   its own `M`; equality selects the distinct full-HP result.
4. If `H < M`, set that battler's HP to `H2 = min(M, H + Q)`, then append the
   success event below with actual gain `A = H2 - H`. Defender HP, PP and all
   other battler fields are unchanged by this action.
5. If `H == M`, leave HP unchanged and append only the full-HP result below.
   It remains an action with one PP spent, not a zero-gain success or retry.
6. Return from the effect-specific zero-power branch before generic stat or
   damage processing. Existing turn continuation/outcome ownership remains;
   this leaf creates no faint, forced replacement, victory or loss itself.

The effect-32 branch belongs in `resolveMove`'s zero-power dispatch, ahead of
the stat-entry dereference at 1097. Its admission guard ensures that shape.
Its accuracy exemption belongs in `needsAccuracyCheck`:1036, alongside the
existing explicit exemptions. This allows the shared PP step to remain the
sole PP owner while skipping both ordinary and tutorial accuracy paths.
Do not use drain, Pain Split, stat changes, generic damage, or a generic healing
API. Do not set either tutorial damage/stat progress flag from recovery.

For maxHP 101, HP 40 becomes 90 (requested 50, actual 50), while HP 100 becomes
101 (requested 50, actual 1). For maxHP 100, HP 1 becomes 51. At maxHP 1 the
only valid living HP is already 1, so the minimum-one formula exists but the
action fails full-HP. A zero-HP fixture would invent revival, not demonstrate
an ordinary successful minimum-one case.

There is no accuracy/evasion, critical, damage RNG, type-effectiveness, or
secondary-effect calculation in either effect-body result. In an isolated
valid `resolveMove` call, its gameplay RNG stream is unchanged. Slack Off's
100 and Recover's 0 do not alter that rule. This is not a zero-RNG whole-turn
guarantee: `getWhoStrikesFirst`:512 can draw on a speed tie, and the other
action and unrepresented cancellation machinery have separate behavior.

Existing no-PP behavior is preserved, not certified as retail parity. A chosen
zero-PP slot while another slot has PP emits existing `noPP` and returns before
`useMove`, PP mutation or recovery. If every slot has zero PP, existing
Struggle substitution owns the action; it is not a recovery result. The player
controller does not currently prevent every chosen zero-PP submission.
`runTurn` skips a battler that faints before acting; direct `resolveMove`
tests for this leaf assume a living battler and do not define resurrection.

## Minimal results and ordered presentation

`resolveMove` still returns nothing and appends events to the caller's list.
No new battle outcome, retained cross-turn state, retail result-bit model or
PP event is needed. Exactly two new event variants distinguish the results:

| Result | Appended event after `useMove` | Meaning |
| --- | --- | --- |
| Success | `{type="restoreHP", side=S, beforeHP=H, hpRemaining=H2, amount=A}` | Own HP has already been updated; `amount` is actual positive gain, never requested `Q` |
| Already full | `{type="restoreHPFull", side=S}` | HP unchanged; no HP-update fields, success event, miss, or generic `moveFailed` |

`S` is the existing `player`/`foe` side value. The preceding `useMove` supplies
move identity, so neither result needs a duplicate move field. Requested `Q`
is internal arithmetic, not a controller bar command: this controller renders
the clamped snapshot `hpRemaining`. `beforeHP` and `amount` provide the same
auditable delta convention used by existing Pain Split HP events; neither
authorizes the controller to recalculate or mutate battle HP.

In [BattleSceneController](../../src/core/BattleSceneController.lua),
`_eventMessages`:177 expands success into an invisible entry
`{hpSide=S, hp=H2}` followed by one recovery feedback entry. Use the bounded
English feedback `<name> recovered HP!`; the full result instead produces
`<name> is already at full HP!` with no HP entry. These are explicit project
presentation choices, not copied ROM text or retail localization claims.
Do not reuse energy-drain, shared-pain, generic-failure, damage or effectiveness
feedback. Both variants name the acting battler, never imply healing from the
defender, and work for either side.

The existing `_applyInvisibleEntries`:103 and `advanceMessage`:133 provide
the ordering: while the used-move announcement is visible, displayed HP is the
prior value; advancing it applies the invisible own-HP entry before showing
recovery feedback. Full-HP feedback leaves displayed HP alone. Whole-turn
engine resolution already precedes playback, so later actions may already
have changed model HP; use the event snapshot, not the current model value.
Remaining turn messages and ACTION/PARTY/COMPLETE transitions use existing
controller behavior after the queue drains.

This preserves announcement / HP display / result ordering only. Source move
animation and wait, requested signed bar delta, retail bar interpolation,
exact text layout/localization, source pauses of 32/64, audio, frame timing
and visual parity are not represented or claimed. The source updates its bar
controller before data HP; the project resolves data first and later plays
ordered snapshots. This design explicitly does not equate those protocols.

## Owner seams and hard exclusions

- [BattleEngine](../../src/core/BattleEngine.lua) owns admission, existing
  effective move selection, PP/HP mutation and result snapshots. `runTurn`:1614
  retains ordinary scheduling, faint checks, switching and side-timer behavior.
- The controller owns its admission call and expansion/playback of the two
  results; no new scene, input mode, animation system or battle caller is needed.
- [BattlePartyBridge](../../src/core/BattlePartyBridge.lua)
  `persistPartyBattler`:178 already copies HP/PP to a player party record.
  [main](../../main.lua):4451 invokes it when the engine turn changes.
  Those are existing integration owners, not requested edits or proof of
  recovery persistence. This design requires no save format/policy/caller
  change and makes no save/reload, restart or filesystem-safety acceptance claim.

The ordinary domain is a precondition, not a runtime detector for missing
systems. Snatch genuinely intercepts both moves through flags 8; its ownership,
PP/announcement markers and cross-battler state remain hard unresolved
exclusions. Do not ignore an actual modeled interception and call it parity.
The same boundary covers shared attack cancellation, inability-to-act/status,
obedience, move restrictions, generic ability/item interactions, called or
intercepted provenance, PP suppression, Substitute and its bypass marker,
and the stateful general `Cmd_moveend`/MoveEnd chain. Existing limited turn
cleanup is not a substitute for that chain. No new whole-turn or FIRST_BATTLE
tutorial parity, AI decision quality, complete trainer roster compatibility,
doubles, links, malformed battlers, revival, persistence or UI parity is implied.

Milk Drink 208/effect 157, Softboiled, field recovery, Rest, Present, Wish,
Swallow, Ingrain, weather recovery and generalized healing remain excluded.
If any proposed implementation needs one of these interactions, new cross-turn
state or a generic abstraction, stop for a different contract. Do not expand
this design or turn its admission result into a full-support certification.

## Later acceptance outline — not implementation authority

Only independent design PASS followed by a separately authorized narrow task
may permit implementation. That task would need to cover the following proof,
without changing this report into an implementation task:

1. Literal IDs/effect/source metadata and ID-aware admission for both moves;
   omitted/other IDs, wrong target/power, Milk Drink and unrelated unsupported
   zero-power records remain rejected. Non-32 admission controls stay unchanged.
2. Both moves and both acting sides; odd/even maxHP, near-full clamp, ordinary
   success and full-HP failure. Assert exact actor/defender state, single PP
   consumption, event sequence/fields and unchanged isolated RNG. Inspect the
   literal minimum-one expression with maxHP-1/full-HP control; do not claim
   an invalid fainted fixture is a valid successful minimum-one witness.
3. Chosen zero-PP versus all-empty Struggle controls; no extra PP deduction,
   revival, tutorial flag mutation, damage/stat/drain/faint or generic-failure
   events. Whole-turn checks separate speed-tie/opponent RNG from effect draws.
4. Controller admission forwards the ID. Success visibly orders useMove,
   invisible own-HP snapshot and feedback; full HP produces no HP entry.
   Check both sides and later-event snapshot ordering without reading final
   model HP early, then existing post-message state transitions.
5. The [inventory test](../../tests/phase4_move_effect_inventory_test.lua)
   currently probes `supportsMove` without an ID and locks rejection for these
   two members. A later contract must explicitly authorize passing the loop ID
   and reconciling only this family and derived totals, not weaken assertions.
   With all other admission unchanged, the expected delta is admitted 248 to
   250 and rejected 106 to 104; 354 members, 214 effects, 216 positive-power,
   138 zero-power and 111 uncovered admitted positive-power moves stay unchanged.
   Preserve the [inventory report](phase4-move-effect-inventory.md)'s historical
   `c10bfa7` baseline/evidence; label any future delta by its new revision.
6. Focused synthetic/controller controls, regression witness against the old
   code, repository checks and full no-ROM suite; then separately authorized
   private-runner SHA-verified, non-skipped ROM metadata/effect/inventory proof
   and independent exact implementation review. Such runs are future gates,
   not evidence obtained or runner/route changes authorized by this design.

## Evidence and handoff

Public main and local inspection HEAD matched `1a312f6` at recovery. Read-only
history comparison confirms engine, controller, formulas, party bridge,
importer and main are unchanged from `a739ddc` through this base. The reference
checkout matches `c75f3523` with no tracked differences. The accepted F1 report
and review, actual admission callers, parser record shape, HP/PP/event owners
and inventory probe were inspected directly; no new gameplay result is inferred.

Only this report and the task evidence/handoff are authored. Link/whitespace
and exact-path checks are recorded in the task. No ROM/private runner,
runtime experiment, gameplay/full-suite test, route, save, coordination or
canonical phase change is part of this package. Next: independent review of
the exact published design commit. Phase 4 remains open; no self-review.
