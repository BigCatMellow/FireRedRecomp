# FireRedRecomp Coordination Handoff

- Status: `PAUSED BY USER — review queue preserved`
- Task ID: `P0-SAVE-ROLLOVER`, with disjoint CI-check implementation
- Canonical status owner: [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md)
- Active task: [`../tasks/phase0-save-counter-rollover.md`](../tasks/phase0-save-counter-rollover.md)

## Current relay — 2026-09-21

### STOPPING CHECKPOINT — 22:59 UTC

The user explicitly requested a stopping point to conserve weekly tokens.
**Do not continue autonomously. Resume only on a new user request.** This
checkpoint supersedes older active-dispatch/runner-offline prose below and in
derived maps. No phase has been newly marked complete.

The user later supplied an external assessment. Its reconciled, non-authorizing
[triage](../reports/2026-09-21-external-project-review-triage.md) is recorded
for resume planning; it does not replace the queue or independent evidence.

Completed and independently accepted: Pain Split `a739ddc`, save-version/refusal
contract `63592c3`, and CI discovery `b5b317b`. Do not repeat their passed work.

Resume queue, in order:

1. Recover live GitHub and local status. CI implementation `3478822` is pushed;
   public run `35624624210`, job `106415819660`, exact SHA passed both the named
   repository check and no-ROM suite. Worker local evidence: 47/0 focused,
   275 Lua/144 Markdown/166 local targets and 150-file full suite. Finish its
   [independent review checkpoint](../reviews/2026-09-21-ci-repository-checks-review.md)
   against `phase0-ci-repository-checks.md`; no PASS yet. Pending: actual job
   logs/checkout proof, isolated focused/checker/full-suite execution and final
   failure/policy review. Temporary snapshot: `/tmp/firered-ci-review.7x4RP2`;
   recreate from exact Git revision if it no longer exists.
2. Rollover correction `aec377a07e73fb5e5edab5163c0be51c7881bb65` is committed
   and published. Exactly seven authorized files; Worker 93/0 codec, 16/0
   roundtrip, 150-file suite and repository checks PASS. Old-code regressions
   failed 5 codec and 2 roundtrip assertions. Recover its push-triggered public
   CI receipt and assign an independent Reviewer; do not implement it again.
3. Preserve/finish the explicitly incomplete
   [ledger audit](../reports/phase0-behavior-ledger-audit.md), pinned `eac7d69`.
   It is not ready for acceptance or ledger edits. PC-overflow wording is stale,
   but a dedicated full-party capture-to-PC-to-restart acceptance receipt was
   not located; supported-but-unhooked script callbacks need separate wording.
   Complete all nine row mappings, then independent report review.
4. `firered-mint` returned **online, busy=false** at 22:59 UTC. Recheck on resume.
   Route configuration `24f39c4` already passed review. No probe/request exists
   yet: execute only the previously authorized single
   `work/local-runner/probes/phase4-move-effect-inventory-route-20260920.probe`.
   Require probe PASS before transporting only test/report from reviewed
   inventory `688433a` on published branch `work/move-effect-inventory`.
   Preserve newer main task records; do not merge its stale task hunk. Required
   private SHA-ROM execution and final independent review still gate inventory
   acceptance and effect-32 discovery. Do not bypass the existing runner.

After those gates, select the smallest unmet Phase0 clean-clone/ledger gate or
the reviewed inventory's next battle family. Suffix preservation and filesystem
write safety remain separate design tasks; Phase2 still needs user-owned
trusted retail captures. No new migration/overwrite policy is authorized.

Toolchain: prepend `/home/home/.local/share/firered-toolchain/bin` to PATH.
Repository `/home/home/FireRedRecomp`; inventory worktree
`/home/home/FireRedRecomp-inventory`; pinned source
`/home/home/FireRedRecomp-reference/pokefirered` at `c75f3523`.
Network git/gh commands require escalation in this environment. Git identity:
`git -c user.name=Codex -c user.email=codex@users.noreply.github.com commit ...`.
Coordinate the shared index; stage explicit task paths only. Root orchestrates,
Worker implements, a different helper reviews. Never commit ROMs or assets.

### Historical working relay (superseded where noted above)

Critical local task: `P0-SAVE-ROLLOVER` is `READY_FOR_WORKER`.
The explicit save-version/refusal contract is closed at `63592c3` after
[independent PASS](../reviews/2026-09-21-save-version-contract-review.md):
codec 63/0, roundtrip 13/0, 149-file suite, historical-fixture validity and a
targeted discarded-prior-slot mutation were independently reproduced.
Only the counter defect is now dispatched: modulo-u32 increment and the
pinned retail maximum/zero selection exception, with footer/content continuity,
ordinary/tie/fallback controls and an old-code regression witness. Seven literal
code/test/document paths; no format, refusal, suffix or filesystem policy change.
Independent exact-revision review is required before closing this defect.
Suffix preservation, live-write safety and whole Phase 0 remain open.

`P0-03-DISCOVERY` is closed after
[independent PASS](../reviews/2026-09-20-ci-proof-discovery-review.md) at exact
`b5b317b`: first-run/current public receipts and pinned syntax/docs
characterization were reproduced. `P0-03-CHECKS` is `READY_FOR_REVIEWER`
at published `3478822`: 47/0 focused, 275 Lua/144 Markdown/166 local targets,
and 150-file full suite passed in an exact committed-tree snapshot, excluding
parallel unfinished save edits. Its required exact public run and independent
implementation review are pending. First-run proof alone does not close P0-03.

`P0-01-DISCOVERY` now audits the existing behavior-ledger rows against pinned
`eac7d69` source/runtime/test/review evidence. Only its own task/report may
change; no ledger edit or new completeness claim is authorized. It can proceed
independently of both implementations; their reviews take priority when ready.

`P4-02` is blocked on the private runner. Source/test preparation
`688433a3093dc15db32d62bd5a59fd7a84ac0cd0` is on GitHub branch
`work/move-effect-inventory` and in `/home/home/FireRedRecomp-inventory`.
[Independent preflight PASS](../reviews/2026-09-20-move-effect-inventory-preflight-review.md)
covers the exhaustive 354-move/214-effect source inventory, 150-file no-ROM
suite and mismatch checks. This is not private-ROM acceptance. Route
configuration `24f39c4` has independent PASS; no probe/request was submitted.
`firered-mint` was still offline at 2026-09-21 16:12 UTC. When online, resume
the single authorized `phase4-move-effect-inventory-route-20260920.probe`,
then transport only the prepared test/report through the guarded route,
preserving the newer task record on main. Final non-skipped SHA-ROM evidence
and independent review must precede inventory closure or effect-32 discovery.

Pain Split is closed at `a739ddc` after independent implementation PASS and
guarded run `35493728001` (both 149-file suites and deterministic replay).
Its exclusions and broader Phase 4 gate remain intact. Historical Pain Split
holds below are superseded by this closure.

User-owned needs for later: restore the private runner if it remains offline;
supply the trusted Phase 2 retail captures/provenance. The user requested
continuous independent work while unavailable, without repeated questions,
and explicit GitHub synchronization. Keep main and task handoffs current;
preserve incomplete preparation on its named branch without claiming acceptance.

Local checkout: `/home/home/FireRedRecomp`. Isolated Lua/LÖVE tools:
`/home/home/.local/share/firered-toolchain/bin`. Pinned source `c75f3523`:
`/home/home/FireRedRecomp-reference/pokefirered`. Completed reviews and the
task register preserve exact revisions; no need to repeat passed evidence.

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

Flail #175 and Reversal #179 effect-99 is closed and independently reviewed at
`656c1f1b` after guarded run `34995558611`. Its route was configured at
`d0e151e2` and probed by `883536b0` (run `34994516318`). Select the next
source-locked effect family separately; do not infer broader dynamic-formula or
Phase 4 completion.

Eruption #284 and Water Spout #323 effect 190 are closed and independently
reviewed at `89cf1dae` after guarded Worker run `34997543211`. The published
canonical range `53d78236..89cf1dae` passed post-publication review, with
213/0 no-ROM checks, 220/0 SHA-verified-ROM checks, the focused ROM-record
test, and the required replay passing. The implementation remains bounded to
the existing singles target; multi-target/doubles and pre-seeded dynamic-power
interactions remain unauthorized. Select the next source-locked effect family
separately; do not infer broader dynamic-formula or Phase 4 completion.

Psywave #149 effect 88 source-lock discovery independently passed. It is one
80-accuracy Psychic record whose stored power is not ordinary base power:
after ordinary accuracy/PP/type it rejection-samples `Random() % 16` until
0..10, then deals floor(level × 50..150% in 10% steps), without ordinary
critical/base/random-damage commands. Type immunity still consumes its full
post-typecalc rejection sample before suppressing HP. The current generic Hit
path is therefore wrong for effect 88. The literal route plan independently
passed and its seven-path selector/allowlist/focused-test/replay/staging
configuration independently passed review. Require one separate probe before
any request. Probe `2e69f25c` passed guarded run `35026144931`; the active task
was Psywave effect 88 through that route. It is now closed and independently
reviewed at `40cfdffe` after guarded run `35026622346`; canonical range
`79c31598..40cfdffe` passed post-publication review with 219/0 no-ROM checks,
226/0 SHA-verified-ROM checks, the focused record test, and replay passing.
It preserves shared accuracy/PP/type/no-effect, samples after typecalc even on
immunity, and avoids ordinary critical/base/random damage. Select the next
source-locked family separately; no broad random-formula support,
held-item/endure state, or Phase 4 completion is authorized.

OHKO effect 38 is the next read-only source-lock discovery. Guillotine #12,
Horn Drill #32, Fissure #90, and Sheer Cold #329 share a special level-based
KO roll rather than ordinary accuracy/damage. The candidate is restricted to
the engine's represented state: Lock-On, Protect, invulnerability, Sturdy,
Focus Band, Endure, Destiny Bond, abilities, and held items remain explicitly
excluded. A lower-level ordinary attempt still consumes its single KO roll;
only type immunity branches before it. It is pending independent review only;
no implementation is authorized.

The active task is the OHKO fail-closed Worker-route plan: seven literal later
implementation, test, replay, task, and coordination paths only; one probe
must pass before any request. The route plan and its seven literal workflow
surfaces independently passed review; its separate probe also passed before
request eligibility.

OHKO effect 38's configuration and probe are now independently evidenced:
probe `31abae7c` passed guarded run `35027693336`. The active task is only the
represented-state OHKO implementation through that route. It must preserve the
strict level/one-roll contract and immunity-before-roll boundary without adding
Lock-On, Protect, invulnerability, Sturdy, Focus Band, Endure, Destiny Bond,
ability/item, or doubles/link state.

OHKO effect 38 is now closed and independently reviewed at `3afcd988` after
guarded run `35080163638`. Its canonical range `49ea4b93..3afcd988` passed
post-publication review with 225/0 focused no-ROM checks, 147 full-suite files
passing, 232/0 SHA-verified-ROM checks, the exact four-record fixture, and
replay passing. It closes only the represented-state subset; Lock-On, Protect,
invulnerability, Sturdy, Focus Band, Endure, Destiny Bond, abilities/items,
doubles/links, and Phase 4 completion remain excluded. Select the next family
separately.

Endeavor #283 effect 189 source-lock discovery independently passed. Its
viability comparison runs after PP but before accuracy: target HP <= attacker
HP fails with no accuracy draw; otherwise its target-minus-attacker HP amount
then follows ordinary accuracy/type/no-effect and shared HP handling. It is
bounded to the engine's represented state: Protect, Substitute, Focus
Band/Endure, and their absent state/RNG paths remain explicitly excluded. The
The literal fail-closed Worker route passed independent configuration review and
its separate non-gameplay probe `b3090013` passed guarded run `35081185726`.
Independent candidate review rejected reuse of the screen-only `screenFailed`
event for Endeavor's generic `BattleScript_ButItFailed` outcome. The active
route amendment adds only `BattleSceneController` and its focused test to make
that generic event present correctly. Amendment and literal nine-path
configuration reviews passed. Amended probe `14c164e9` passed guarded run
`35206557769`; Endeavor effect 189 is now closed and independently reviewed at
`3a489b94` after guarded run `35207142939`. Its actual canonical range
`50537277..3a489b94` changed only six permitted files and passed source-order,
generic-failure event/presentation, positive-HP/no-faint, exclusion, and
evidence review. Select the next source-locked effect family separately; do
not infer broader formula/state/UI/controller or Phase 4 completion.

Pain Split #220 effect 91 is source-locked. It has zero power and is correctly
rejected by current generic admission; stock's represented no-state accuracy
command consumes zero RNG, then computes/stores signed deltas from average
attacker/target HP; the script applies attacker first and target second.
Substitute, Protect, Mirror Move, Lock-On/sure-hit, semi-invulnerability,
items/abilities/status, doubles/links, and generic zero-power/healing support
remain excluded. Discovery and the two-sided-HP/admission design independently
passed. The literal nine-path Worker route configuration independently passed
and its non-gameplay probe `7409ad54` passed guarded run `35290005345`.

The independent implementation-scope review passed at
`b1cb14970726f5289b2439a906dcbeff26ad2e28`. It verified literal effect-91-only
admission; pre-mutation deltas; per-side own-max clamps; attacker-before-target
actual HP events; shared-pain presentation; zero RNG; no faint; and all stated
exclusions. A single Worker request is now authorized only through selector
`phase4-pain-split-effect`, with the literal nine-path allowlist and its
focused/full/verified-ROM/replay evidence sequence. Do not widen zero-power or
HP/healing support, and do not mark Phase 4 complete.

The one authorized request at `87d5e72` failed before publication in guarded
run `35410055700`. The focused checks and full verified-ROM suite passed until
the new record test asserted #220 flags `51`; direct verified-ROM parsing shows
the source-locked record has flags `18` (Protect/Mirror Move). This is a
request-fixture defect only; no implementation commit exists. The active gate
is independent review of the smallest correction. Do not issue a replacement
request or widen scope until that review states the exact allowance.

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
