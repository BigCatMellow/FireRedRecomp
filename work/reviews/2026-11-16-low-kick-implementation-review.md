# Low Kick injected engine slice — independent implementation review, 2026-11-16

**NEEDS_FIX** at exact frozen `445f3c42082cf616cbc6e43fdcefa40a77c975be`, clean
`/home/home/FireRedRecomp-low-kick`. Governing task SHA-256 independently matches
`a3dd549cb079271a2c0bde5665789ed9e94702dce7ece667523f77cdfeff3ebd`;
approved design remains
`be0df3a0044ba1d2ada00bf1dd90882f3d2c33f15573f46a66844e5bb622e682`.
One source-order correction is required. No code fix or target edit performed.

## F1 — Low Kick reduces PP after the first accuracy RNG call

At src/core/BattleEngine.lua:3068 the new Low Kick route executes accuracyRoll;
only then does generic ppreduce at3085–3092 decrement its slot. Pinned source
`data/battle_scripts_1.s:2550–2556` explicitly orders attackcanceler → attackstring
→ **ppreduce** → weightdamagecalculation → **accuracycheck**. This order is already
part of the accepted Low Kick source lock, not a new product criterion.

An ordinary valid move67 with20PP and a valid250hg current-defender weight shows:

| Observation at successive Random calls | Source | Candidate |
| --- | --- | --- |
| PP at accuracy / crit / adjustment / secondary | 19,19,19,19 | **20**,19,19,19 |

Both attacker sides reproduce it. The RNG callback only reads PP; it does not
change battlers, moves, lookup configuration or other engine state. Final
damage9, PP19 and four draws still match, which explains the green400 assertions.
The same source-order mismatch appears in all24 ordinary threshold cases of
the independent probe. This is a bounded source-conformance defect despite
unchanged final ordinary outputs.

Minimal correction inside existing scope: give Low Kick its source-specific
PP prefix after applicable cancellers/no-PP checks and before accuracy, then
exclude it from the later generic deduction. Deduct once on hit/miss/protect/
semi paths, preserve no PP on status cancellation and refusal before mutation,
and leave all non-Low-Kick behavior unchanged. Add literal read-only RNG-order
assertions for both sides, including a successful and accuracy-miss path.
Do not repair generic PP handling or add claims about a source-unreachable
Low-Kick-as-Rollout lock/negative-PP state.

Minimal reproducer from the frozen target cwd:
`env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY lua5.1 /tmp/firered-low-kick-implementation-review-20261116/pp_order.lua`
exits1. Script SHA-256
`cddb1719b7240181f869d3c32aba047ded5a2bc75618d2482aa7adca2959bc44`;
actual log `/tmp/firered-low-kick-implementation-review-20261116/pp-order.log`,
SHA-256 `58bfe64e3eb6d1453780e4be935c730e6efbd8c5b6535dc8e1816a3a961fcc3d`.
It uses eight tiny source-parsed public move records in scratch source_moves.lua,
not ROM data or expected values read back from the implementation.

## Independent remainder checks

Reviewer `/root/native_history_review_resume` is distinct from Worker
`/root/low_kick_engine_worker`; parent root/rina owns reconciliation. Read current
canonical AGENTS/REVIEWER, exact amended eight-path task and approved design.
Parent f903571 root task/frozen/evidence handoff independently PASS, no state
writes. Source pin remains c75f352304d529f6ba92d4f74b9cf8b5c3810788. Prior accepted
domain/ABI/provider findings were recovered; no complete source campaign repeated.

Verified exactly eight allowed changed paths versus dispatch274cbad, all other
product/scripts/import/main paths preserved. Dispatch product matches clean
published WG944df72. All six product/test freeze SHA-256 values in the task
match actual files; final445f3c4 adds only the task receipt after85ec517.
Design report unchanged, friction append-only, no prohibited content/package.

Direct code inspection and independent evidence support the remaining contract:

- constructor validates/copies raw plain-map scalar entries before battler
  isFirstTurn writes; ordinary domain/u16/NaN/metatable/missing rules are bounded;
  closure-private map remains detached from caller mutations and other engines.
- current defender and prospective unlocked voluntary-switch target are used;
  shared source move remains power1/Fighting. Complete singleton record guard
  prevents malformed/fallback records. No default/native provider is supplied.
- one pure effective-record planner implements mandatory selection versus
  resolution contexts, projected recharge expiry/new snapshot versus live/saved
  locks and passed-slot fallback. Its returned lockedTurn is retained downstream;
  Struggle/0PP ordering remains intact. No planner mutation or global PP repair.
- controller Low Kick refusal precedes chooser; runTurn/direct wrapper/core
  preflights precede their own state writes. Retained prior chooser RNG/main
  switch/capture effects and no automatic retry remain honest explicit limits.
- threshold powers/damage, action-local record isolation, HP timing at RNG
  boundaries, Ghost immunity and exactly one WG/ordinary secondary tail pass
  independent source oracles, apart from F1's PP timing.

Additional independent stock differential harness compares full serializable
engine state, events, RNG seed/draws, HP/PP, flags/timers/locks/turn and records
against immutable944df72 Engine. **372 scenarios /996 non-Low-Kick transitions
match**, including both sides' natural Hyper Beam/recharge/lastPP/sleep-timer1,
Rollout locked0PP, Fly/Dig/rampage, faster sleep cancellation, direct saved-lock/
flinch/sleep/confusion/recharge, Struggle, voluntary switch, capture and run.
No parity claim for malformed/unreachable states. **28 Low Kick source cases**
check ordinary thresholds, both sides, copied caller inputs/shared record and
HP timing/blocked tails; **2768 assertions pass**, with F1's24 first-draw PP
violations separately diagnosed. Harness SHA-256
`077f3d6005d1e61e82691d8eab616d07ce9231ebc0620276b1c861d9d251e0d5`;
log `1a2022994bb457cba0a53e4b15fac9d59ab08906ccba5d91fa63db0c4059bdae`.

Independent pinned-source354 parser matches complete inventory membership/power.
Only row196/singleton67 changes default true→false, remaining class B. Actual
four source-fact admission scopes independently pass299/55,296/58,300/54,297/57;
uncovered positives16 without weights/17 with weights. Every other literal row
and report receipts117/119/156 are unchanged. No represented-family flip.
Inventory parser SHA-256
`204164aafadae6eac6b330f6f1aac73c81ab248b02ff864fb5309a4af119e3db`;
generated probe `5fce6a1206e3fdc515d8c8ef1c0d984261ee69101a9b70af9d2198f5992ec084`.

Recovered final foreground215 no-ROM log, SHA-256
`fec13252ddf0483ac1d56223c1c14ae86d23c244edde99e23890f0e694f9e13b`;
PASS line/no FAIL lines and tracked215 count verified. No redundant full run.
Independently reran LowKick400/0, controller144/0, V3 144/0, WG768/0; inventory
partition PASS, new SHA-first ROM fixture explicitly SKIP/provider unproven.
Repository checker344Lua/432Markdown/1385targets and whitespace PASS.
Focused log SHA-256
`dbf9a606109c192e25fb87acb7ddc276ec42cab570286e8335f6e85628697a48`.
These green receipts do not supersede the source-order finding.

## Handoff and boundaries

Next role **WORKER via parent root/rina**: smallest F1-only implementation/test/
task/friction correction under the existing task, then freeze for independent
delta review with applicable regressions. Keep approved design/source/provider
limits; no additional package or general PP/RNG cleanup. Parent receipts only,
not wholesale replacement of its larger private/native runtime.

Numeric provider/address/delivery remain UNKNOWN/unimplemented and native merge
blocked until reviewed delivery+non-skipped supported-ROM proof or complete
live-scope absence proof. No whole-family/represented/AI/runtime/phase/ROM/F4/
full-relay/CI/publication/main-merge acceptance. No branch push, GitHub write,
operator ask, local ROM/search/private logs/jobs/replay or target edit occurred.
Tool/source-parser and actual adversarial failures were captured before handoff
in `/tmp/firered-low-kick-implementation-review-20261116/FRICTION_LOG.md`.
Frozen target remains clean.
