# Task: implement bounded effect-45 crash-on-miss behavior

- Task ID: `P4-F3-RECOIL-IF-MISS-IMPLEMENTATION`
- Status: `READY_FOR_REVIEWER — AUTHORITY ONLY`
- Type: `IMPLEMENTATION AUTHORITY / GUARDED ROUTE`
- Parent: [Phase 4 move/effect matrix](../roadmaps/CAPABILITY_CHECKLIST.md).
- Assigned role: `ORCHESTRATOR`; independent authorization reviewer: `REVIEWER`.
- Prerequisites: source `c218da6`, supplement `ba69269`, design `b3280f9`,
  route plan `04636d1`, configuration `1d40f3c`, probe `667fd16`, all
  independently accepted. Probe run `38385071588` / job `115254712929` passed.
- Risk: `HIGH` — miss-time RNG, self-faint and delayed displayed HP can corrupt
  turn progression or produce incorrect persisted HP/PP if ordered wrongly.

## Goal and source of truth

Authorize independent review of one future bounded implementation request.
This draft authorizes no implementation, request, tests, replay or ROM action
until its own exact independent authorization review returns PASS.

Required authorities are the [accepted design](../reports/phase4-recoil-if-miss-design.md)
and [PASS](../reviews/2026-10-12-recoil-if-miss-design-review.md), controlling
[source supplement](../reports/phase4-recoil-if-miss-entry-state-discovery.md),
[route plan](../reports/phase4-recoil-if-miss-route-plan.md),
[configuration PASS](../reviews/2026-10-13-recoil-if-miss-route-configuration-review.md),
and [probe PASS](../reviews/2026-10-13-recoil-if-miss-route-probe-outcome-review.md).
Unknown source state is excluded, never approximated.

## Exact future MAY CHANGE and execution envelope

Only after this authority independently passes, Worker may prepare one patch
for `work/local-runner/requests/phase4-recoil-if-miss-effect-20261013.patch`.
It must select only `phase4-recoil-if-miss-effect`, be the triggering commit's
sole file/input, and target only these ten literal paths:

1. `src/core/BattleEngine.lua`
2. `src/core/BattleSceneController.lua`
3. `tests/battle_engine_test.lua`
4. `tests/battle_scene_controller_test.lua`
5. `tests/battle_party_bridge_test.lua`
6. `tests/phase4_move_effect_inventory_test.lua`
7. `tests/phase4_recoil_if_miss_effect_rom_test.lua`
8. `scripts/runtime_phase4_recoil_if_miss_replay.sh`
9. `work/tasks/phase4-recoil-if-miss-implementation.md` — evidence only.
10. `work/reports/phase4-recoil-if-miss-implementation.md`

All required files must exist before guarded publication. Validation/staging
must remain the reviewed equal ten-path sets. Criteria may not be rewritten.
No eleventh file, shared fixture edit, second request, replacement input,
route change or retry is authorized. The prior probe allowance is consumed.

Worker may construct allowlisted edits in an isolated worktree and perform
no-ROM baseline/focused/regression checks there. Canonical runtime publication
is exclusively through the guarded bridge, never a direct implementation
push. Parent serializes the one request and must freshly verify online/idle
`firered-local`, no queued/running bridge job, unchanged accepted route and
patch applicability against current main immediately before dispatch. Changed
prerequisites stop dispatch. No local/private ROM search or access is allowed;
verified-ROM execution occurs only in the existing guarded job.

## Required bounded behavior

1. Select the conjunction of effect 45 and move ID 26 or 136, only on ordinary
   failed accuracy after retained eligibility/useMove/one-PP handling. Leave
   admission and successful-accuracy behavior unchanged, including its RNG.
2. Before the generic miss event, use the existing pure `typeCalc` noEffect
   result with a harmless positive seed to detect ordinary type immunity;
   discard temporary damage/effectiveness flags. An immune failure produces
   useMove/noEffect and completes: no miss, crash, base calculation,
   adjustment draw, HP update or attacker faint. PP stays spent.
3. For nonimmune failure emit miss and a dedicated crash result. Compute
   ordinary base damage with source-backed noncritical 1/1 inputs, represented
   stages and defender Reflect, then STAB/type and normal random adjustment.
   Apply integer half, zero-to-one, then floor(target.maxHP / 2) cap, with no
   second minimum. Clamp actual HP loss to attacker remaining HP. Do not use
   defender current HP or ordinary actual-hit recoil as the damage basis.
4. Only attacker model HP changes; target HP is untouched. Crash carries
   attacker side, actual HP loss and resulting HP in a minimal dedicated
   semantic event, distinct from ordinary recoil/defender damage. Suppress
   critical/effectiveness/hit-damage presentation on this miss branch.
5. Perform existing attacker faint handling after crash/HP, then retained
   action completion. Preserve battle-end/pending-forced-switch guards so a
   later opponent action cannot hit the just-fainted attacker. No replacement
   subsystem, global flag API or generic miss/recoil abstraction.
6. Controller translates crash into an announcement then a separate invisible
   attacker-HP entry. Display HP stays old through the message and changes
   before optional faint/continuation. Controller consumes no RNG and does
   not write model HP. Immune failure has no crash or HP entry.
7. Preserve firstBattle player accuracy bypass, successful-hit tutorial state,
   zero-PP/auto-Struggle and all unrelated moves. Crash cannot set the tutorial
   damage flag or emit its tip; do not swap sides into the defender-damage
   helper. Existing party bridge persists actual model HP/PP unchanged.

## Required acceptance evidence

1. Engine assertions cover both records/sides, literal selection, retained
   successful hits and ordinary recoil/misses, ordinary immune failure
   (including either dual-type position), and nonimmune crash. One PP is spent
   on each admitted result. Nonimmune failure consumes accuracy then damage
   adjustment; immune failure only accuracy. Check next RNG sentinel and no
   critical/extra draw, accounting separately for turn-order/other actions.
2. Source-derived arithmetic assertions cover stages/Reflect, STAB/type order,
   prior critical non-leakage, odd division, zero-before-minimum, target max
   versus current/attacker HP, cap boundaries and actual remaining-HP clamp.
   Zero-after-cap remains arithmetic-only evidence, not a legal retail-battler
   claim. Conditional late-only immunity is not a reachable test oracle.
3. Actual fatal crashes cover attacker zero HP before one faint, unchanged
   defender HP, no duplicate faint/remaining opponent action, both acting
   sides with/without represented eligible replacements, pending-switch
   refusal, existing replacement resolution and later legal turn. Preserve
   firstBattle bypass and unrelated completion/replacement regression checks.
4. Controller tests consume actual engine-produced events and advance through
   use/miss/crash with old displayed HP, then invisible attacker HP before
   faint/continuation. Test nonfatal/fatal and immune outcomes, pending PARTY
   versus terminal COMPLETE after messages. No relabeled mocked recoil proof.
5. Party-bridge tests obtain HP/PP from real scoped engine resolution, call
   unchanged persistPartyBattler on a matching encoded record, decode it and
   assert nonfatal/fatal HP, spent PP, checksum/identity preservation and immune
   unchanged HP. This proves invoked model-to-party persistence only, not
   normal lifecycle wiring, live slot synchronization, disk/fresh reload or
   trainer rewards. Broader integration claims need a separate task.
6. Inventory changes concern only effect-45 membership/admission and bounded
   coverage. The new supported-SHA ROM fixture checks both source-locked move
   records and exactly those two effect-45 members without retaining extracted
   bytes/table dumps. Expected fields come from accepted source, not the engine
   predicate. Required verified-ROM inventory and fixture results are non-skipped.
7. The bridge's focused arm runs these exact ordered commands through `$LUA`:

   ```bash
   "$LUA" tests/battle_engine_test.lua
   "$LUA" tests/battle_scene_controller_test.lua
   "$LUA" tests/battle_party_bridge_test.lua
   "$LUA" tests/phase4_move_effect_inventory_test.lua
   "$LUA" tests/phase4_recoil_if_miss_effect_rom_test.lua
   ```

8. Guarded `git apply --check`, `git diff --check`, full no-ROM suite
   (`env -u POKEPORT_ROM bash scripts/test_all.sh`), and full SHA-ROM suite
   (`bash scripts/test_all.sh` with only the existing hash-gated environment)
   must pass. No-ROM skips do not satisfy verified-ROM acceptance. Local
   no-ROM baseline/after checks use
   `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh`;
   local checks never substitute for guarded execution.
9. `bash scripts/runtime_phase4_recoil_if_miss_replay.sh` must pass in the
   guarded replay arm. The wrapper requires supplied ROM environment and
   `set -euo pipefail`, runs the same five tests through `lua5.1`, then prints
   a bounded receipt. Deterministic sequences live in those tests and cover
   actual crash/faint/replacement, displayed HP order, explicit persistence
   and RNG sentinels. This is headless represented-state evidence, not retail
   playback, LÖVE/timing, normal save/reload or whole-turn RNG parity.
10. Independent exact published-outcome review must verify target scope,
    guarded receipts, assertions and exclusions before behavior acceptance.

## MUST NOT CHANGE / stop conditions

No workflow/procedure/shared runner, requests other than the sole input,
probes, credentials or ROM configuration. No canonical runtime push, `main.lua`,
formulas/party-bridge runtime, save/schema/codec, importer/catalog, AI, UI scene,
shared test data, coordination, capability status or other effect family.
Keep cancellation/interception, Protect/Substitute, abilities/items,
Endure/Focus Band, status/Foresight, semi-invulnerability, called/mirrored or
forced/multi-turn provenance, doubles/links, malformed/unsupported battlers or
party state, animation/timing and generic MoveEnd parity excluded.

Stop for an unlisted path, source/design uncertainty, missing required state,
changed prerequisite, failed guard/test/replay/SHA, missing non-skipped ROM
evidence or need for a second request. Diagnose and record failure without
retry or silent approximation. No ROM, BIOS, private paths/secrets, extracted
content, caches or private media may enter public artifacts or copied logs.

## Completion and handoff

First Reviewer decides `PASS | NEEDS_FIX | BLOCK` on this exact authority.
After PASS Worker constructs/verifies only the allowed package, records exact
local receipts and honestly pending guarded checks, then hands one patch to
the parent for serialized guarded publication. A failing guarded job stops;
a successful one requires a separate independent outcome review. Orchestrator
reconciles only bounded effect-45 behavior, never Phase 4 completion, then
selects the next evidence-backed eligible gate under the standing goal.

### Worker isolated-construction evidence — 2026-10-13

Following authority PASS `96b10ce` and reconciliation `15c15c2`, Worker
constructed only the ten allowed outputs in isolation. The
[implementation report](../reports/phase4-recoil-if-miss-implementation.md)
records the literal crash/immunity leaf, distinct controller event, concrete
test coverage and remaining guarded gates. Criteria above are unchanged.

Baseline full no-ROM suite passed 154 files. Focused checks passed engine
332/0, controller 87/0, party bridge 29/0; inventory partition passed with
ROM aggregate skipped, and new ROM fixture explicitly skipped. The final
full no-ROM suite passed 155 files, including final engine assertions.
All local checks cleared ROM and runtime-replay opt-ins; no ROM discovery or
access occurred. Replay wrapper syntax passed; guarded replay remains pending.

Only literal effect 45/IDs 26 and 136 gain crash behavior. Real fatal crashes,
replacement continuation, controller text-before-HP and invoked encoded-party
HP/PP persistence have local assertions. The report distinguishes codec
compatibility from unclaimed lifecycle/disk save/reload. All exclusions remain.

Final whitespace passed, including all three new files. The repository
checker explicitly included the new outputs and passed: 281 Lua, 281
Markdown, 928 local targets. Exact ten-file scope, empty staging index and
verbatim preservation of the original task were checked. Hashes accompany
Worker delivery. Parent must freshly validate prerequisites and mechanically derive
the sole request from this exact diff. No Worker staging, commit, push,
request creation or canonical runtime publication occurred. Guarded
focused/full/SHA-ROM/non-skipped inventory/record/replay/publication receipts
and independent exact outcome review are pending; local readiness is not
behavior acceptance or Phase 4 completion.
