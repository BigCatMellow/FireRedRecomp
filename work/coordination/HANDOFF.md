# FireRedRecomp Coordination Handoff

- Status: `READY_FOR_INDEPENDENT_REVIEW`
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Active task: [`../tasks/local-worker-bridge-phase4-flail-route.md`](../tasks/local-worker-bridge-phase4-flail-route.md)

## Published evidence

Phase 2 camera is closed at `4c5456f3`. The deterministic Oak/reference
implementation harness is closed and independently reviewed at `0017727c`:
guarded run `34767029627` passed validation, focused/no-ROM/verified-ROM suites,
two exact 240×160 Oak captures, two exact 240×160 Pallet captures, repeat
self-diffs, and publication. Capture media remains outside git.

## Parallel critical path

Phase 2 comparison remains blocked only on user-owned retail captures. That does
not block independent Phase 4 work. No-item trainer-party construction is now
published and independently reviewed at `f40c4021` (guarded run `34776145784`).
Foe-only multi-Pokémon orchestration is now independently reviewed and published
at `8533cf6a` (guarded run `34777072801`): it uses the forced-switch primitive
only after faint messages, settles EXP/EV per foe, and flags the trainer only
after the final foe. The next separate leaf is player forced-replacement UI
discovery; do not infer it from the foe-only path. The bounded implementation is
now independently reviewed and published at `8fd9a397` (guarded run
`34783304717`), proving forced PARTY choice, persistence, state sync, and the
no-bench loss branch. Next dispatch is Phase 4 battle-rule/trainer-matrix
discovery, not an assumption that voluntary switching is complete. Discovery
selected trainer-only voluntary switching as the next leaf. It is closed and
published at `3140e267`; it opens a selector only for a current legal
save-backed bench, rejects cancel/stale/forged choices, invokes the existing
switch-before-foe engine action, and preserves both party records. Do not mark
broader player switching or Phase 4 complete from that leaf. Fixed-damage
effects are now closed and published at `c65cf838` (guarded run `34798961274`):
Dragon Rage (40), level damage (attacker level), and SonicBoom (20) reuse the
existing accuracy/PP/type path; type immunity remains a no-effect, while
nonzero effectiveness does not alter fixed damage or presentation. The
admission-matrix discovery is independently reviewed PASS at `784a5188`: the
verified ROM has 216 positive-power records, 75 explicitly represented, one
explicit rejection, and 140 broad-fallback records classified. The active next
leaf is only EFFECT_ALWAYS_HIT (17): Swift #129, Faint Attack #185, Shadow
Punch #325, Aerial Ace #332, Magical Leaf #345, and Shock Wave #351 have
positive power and accuracy zero, so the stock accuracy command takes a no-roll
branch. Always-hit effects are now closed and published at `89673e16` (guarded
run `34828443860`): effect 17 skips only accuracy RNG while retaining PP, type
immunity, crit, normal random damage, and HP application. The next active task
high-critical discovery is independently reviewed PASS at `47f3748e`. Stock
effect 43 routes through ordinary Hit but advances only the existing critical
stage from 0 (1/16) to 1 (1/8), with the same single critical RNG draw. The
eight records are Karate Chop #2, Razor Leaf #75, Crabhammer #152, Slash #163,
Aeroblast #177, Cross Chop #238, Air Cutter #314, and Leaf Blade #348. The
effect-43 stage selection is now closed and published at `a4b02e35` (guarded
run `34829358780`), preserving one crit RNG draw, PP, type, normal damage, and
HP paths. False Swipe discovery is independently reviewed PASS at `f9874ecd`:
its one record, #206, is ordinary Hit with a post-formula lethal-damage cap to
target HP minus one. It is self-contained in this stateless engine after the
existing immunity return and before shared HP application. The active
effect-101 route and probe passed. The bounded patch caps only lethal final
damage at target HP minus one after immunity handling and before shared HP
application; it is now published at `a3e9d058` (guarded run `34830527499`).
Vital Throw discovery is independently reviewed PASS at `c872c16c`. Its sole
record is #233 (Fighting, 70 power, 100 stored accuracy, PP 10, priority -1).
Effect 78 uses ordinary Hit but takes `Cmd_accuracycheck`'s no-random-accuracy
branch, so it ignores accuracy/evasion and does not consume an accuracy RNG
draw. Its -1 priority is already represented by the engine's normal move-order
comparison. The effect-78 route and one-file probe passed (run `34902016950`).
The bounded patch is published and independently reviewed at `37f1f22e`
(guarded run `34903062946`): effect 78 alone joins the no-roll predicate while
preserving priority -1 and ordinary PP, critical, type, random-damage, and HP
paths. Explosion discovery is independently reviewed PASS at `61b2c60f`.
Explosion self-KO/faint/RNG-order design is independently reviewed PASS at
`ac15cba9`: retail completes target-then-attacker faint scripts before later
replacement/outcome handling, while the engine has one pending forced-switch
slot. Ordered replacement-state design is independently reviewed PASS at
`f407b775`: the engine needs a two-phase record-faints/finalize-sequence API,
not merely a replacement queue. The terminal-policy source lock is independently
reviewed PASS at `e7f5d779`: local simultaneous whole-team exhaustion produces
`B_OUTCOME_DREW`, and the post-action faint handler traverses player battler 0
then foe battler 1. The active design defines a queue-head-compatible two-sided
state/API migration, controller handoff, persistence/reward boundaries, and
loss-equivalent `playerDrew` settlement. The design is independently reviewed
PASS at `6ac44924`. The exact route configuration passed review at `b6f63284`,
and its one-file probe `4630aad4` passed guarded run `34906202097` on
`firered-mint`, including trusted checkout, route selection, Lua, and private
ROM verification. The two-sided state/API implementation is now closed and
independently reviewed at `4a583b6a` after guarded run `34907113705`: it has
ordered queue-head-compatible replacement state, `playerDrew`, and validated
trainer/Oak/wild loss settlement. Explosion is therefore eligible only for the
next separate gate: a fail-closed Worker Bridge route plan. That route passed
review at `2355a194` and probe `8e5ed551` passed guarded run `34952628535`.
The effect-7-only Explosion task is closed and independently reviewed at
`507b5ac0` after guarded run `34953677822`: it is limited to
Damp/self-KO/defense/RNG/faint-order behavior and focused evidence. The
canonical range `1ee658a9..507b5ac0` independently passed review after
publication. Select the next source-locked effect family separately; do not
bundle formulas or other stateful families. Held-item trainer layouts remain
deferred because battlers do not retain or apply item state.

Flail #175 and Reversal #179 effect-99 discovery is source-locked and awaits
the independent review of its exact Worker route plan. That plan permits no
workflow configuration or gameplay code yet; after review PASS its next gate is
literal route configuration followed by a separate one-file probe.

Super Fang effect 40 discovery independently passed: it is a single
current-target-HP-halving formula record. The next gate is a separate
fail-closed Worker Bridge route plan; no implementation is authorized yet.

That route is now independently reviewed and probed: config `4b62344d`, probe
`ce50565f`, guarded run `34954489129`. The active task is only Super Fang
effect 40 through this route; it may not bundle fixed damage or other formulas.

Super Fang is now closed and independently reviewed at `2671c5de` after guarded
run `34954873576`. Select the next source-locked effect family separately; do
not infer broader formula or Phase 4 completion.

## Phase 2 resume point

The remaining input is user-owned trusted retail captures for both documented
anchors, with FireRed revision, emulator/device, frame/timing, 240×160 crop, and
filter provenance. Do not commit that media. On receipt, execute the scoped
comparison task, create text-only discrepancy records, and independently review
them before any parity claim. Phase 2 remains `IN PROGRESS`.
