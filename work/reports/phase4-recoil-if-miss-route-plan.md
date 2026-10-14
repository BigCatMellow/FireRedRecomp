# Effect-45 guarded bridge route plan

- Task: [P4-F3-RECOIL-IF-MISS-ROUTE-PLAN](../tasks/local-worker-bridge-phase4-recoil-if-miss-route-plan.md).
- Status: `PLAN READY FOR INDEPENDENT REVIEW`; no configuration or behavior acceptance.
- Published/local inspection base: `044c672c7e5a8228b92e53477bcd7eebf23761e8`.
- Authority: [design](phase4-recoil-if-miss-design.md) at `b3280f9` and
  [independent PASS](../reviews/2026-10-12-recoil-if-miss-design-review.md),
  with source lock `c218da6` and controlling supplement `ba69269`.

The smallest proposed route has ten literal patch/staging paths and five
focused Lua commands. The extra evidence owner relative to Magnitude is the
existing party-bridge test: it must persist actual crash-produced HP and PP,
including a fatal crash. Runtime edits remain confined to engine/controller.
This plan authorizes none of the future commands or files below.

## Selector and equal validation/staging surface

Add only the unique explicit selector `phase4-recoil-if-miss-effect`, with
the following basename patterns under the existing request/probe directories:

```text
phase4-recoil-if-miss-effect*.patch
phase4-recoil-if-miss-effect*.probe
```

The one future request uses
`work/local-runner/requests/phase4-recoil-if-miss-effect-<timestamp>.patch`.
The separate future readiness probe uses
`work/local-runner/probes/phase4-recoil-if-miss-effect-route-YYYYMMDD.probe`.
These are filename patterns only, never target wildcards. Existing routes
cannot carry this package; unknown selectors still fail closed.

Validation and publication staging must be exactly set-equal to this list:

| Literal path | Bounded reason |
| --- | --- |
| `src/core/BattleEngine.lua` | Literal effect-45/IDs-26-and-136 failed-accuracy leaf, immutable hit path, model HP/PP and existing faint ownership. |
| `src/core/BattleSceneController.lua` | Dedicated crash announcement followed by invisible attacker HP entry. |
| `tests/battle_engine_test.lua` | Branch/RNG/PP/formula/firstBattle/faint and unrelated-family regression assertions. |
| `tests/battle_scene_controller_test.lua` | Actual engine-result message/HP ordering and completion/forced-party boundary assertions. |
| `tests/battle_party_bridge_test.lua` | Actual crash model results persisted to the matching party record, including HP zero and spent PP. |
| `tests/phase4_move_effect_inventory_test.lua` | Literal row 45 membership/admission and bounded coverage accounting; no unrelated row reclassification. |
| `tests/phase4_recoil_if_miss_effect_rom_test.lua` | New verified-ROM record fixture for precisely both records and complete effect-45 membership. |
| `scripts/runtime_phase4_recoil_if_miss_replay.sh` | New deterministic headless evidence wrapper over the scoped assertions below. |
| `work/tasks/phase4-recoil-if-miss-implementation.md` | Future separately reviewed implementation contract; Worker evidence only, not permission to rewrite criteria. |
| `work/reports/phase4-recoil-if-miss-implementation.md` | Future exact command/branch outcomes, limitations, and review handoff. |

The four new paths do not yet exist; naming them limits a future package and
does not create it. Staging uses individual `git add -- "$path"` operations
in the existing route-specific pattern. No directory expansion, staging-only
path, optional extra fixture, or review/coordination artifact is allowed.
Missing required artifacts are failure, not permission to omit evidence.

No change to `BattleFormulas`, `BattlePartyBridge`, `main.lua`, save codecs,
trainer orchestration, shared test data, importer, or shared test runner is
needed by this plan. Existing modules can be required from allowlisted
tests without becoming patch targets. Local literal fixtures can be defined
inside those tests. A discovered need to modify another owner stops the
package for a separate decision.

## Attainable evidence and its limits

The following maps the accepted design to existing concrete seams, rather
than treating current test existence as future crash coverage.

| Design obligation | Planned evidence owner and attainable assertion |
| --- | --- |
| Immune/nonimmune failure, literal identity, hit preservation | Engine test: both IDs/sides; immune useMove/noEffect only, nonimmune useMove/miss/crash; unchanged successful hit/ordinary recoil and unrelated miss. Existing scripted RNG and local move-table conventions suffice. |
| Formula, RNG, PP, firstBattle | Engine test: 1/1 noncritical stage/Reflect inputs, type/STAB then adjustment then integer half/minimum/target-max cap, actual-HP clamp; one vs two failure-branch draws plus sentinel; one PP; prior critical cannot leak; preserved player accuracy bypass and no crash tutorial tip. Zero-after-cap is arithmetic evidence only. |
| Fatal crash and forced continuation | Engine test: actual crash to zero, one attacker faint, no target HP change, no duplicate faint, no remaining opponent action when outcome/pending switch stops turn. Test both sides with/without eligible replacements, then existing resolveForcedSwitch and later legal turn. |
| Message before HP and completion | Controller test: consume actual engine events through existing queue; attacker display HP stays old during use/miss/crash text and changes via following invisible entry before faint/continuation. Immune branch has no miss/crash/HP entry. Pending player replacement enters PARTY only after messages; terminal outcome enters COMPLETE only after messages. |
| HP/PP persistence | Party-bridge test: construct a matching encoded party record and battler, resolve an actual scoped crash, call unchanged persistPartyBattler, decode the record, and assert nonfatal/fatal HP plus spent PP and checksum/identity preservation. Immune failure preserves HP but spends PP. |
| Exact supported-ROM records | New ROM fixture checks both IDs' accepted fields and scans for exactly those two effect-45 members; unchanged inventory aggregate runs non-skipped in verified-ROM mode. No ROM bytes/table dump is retained. |

[Engine tests:1262](../../tests/battle_engine_test.lua#L1262) already exercise
`hasReplacement`, pending-switch refusal, replacement resolution, and
[self-faint turn stop:1362](../../tests/battle_engine_test.lua#L1362).
These can receive literal crash cases without another replacement runtime.
[Controller tests:53](../../tests/battle_scene_controller_test.lua#L53)
advance displayed HP in stream order. Existing
[forced-controller fixture](../../tests/phase4_player_forced_replacement_controller_test.lua)
demonstrates callbacks and PARTY/message transitions; it remains unchanged,
with regression coverage supplied by the shared suite. New crash assertions
belong in the allowlisted controller test and must use real crash events,
not merely relabel mocked recoil events.

[Party bridge tests:71](../../tests/battle_party_bridge_test.lua#L71) currently
assign HP/PP directly before persistence, and at line 83 perform an in-memory
save-block codec roundtrip. New crash evidence must obtain the state from the
engine before invoking that same persistence seam. It proves explicit
model-to-party persistence (and codec compatibility if roundtripped), not
that normal gameplay invokes persistence at every lifecycle boundary.
The existing
[trainer replacement ROM test](../../tests/phase4_player_forced_replacement_rom_test.lua)
uses `main.lua` wiring and manually forces a faint; running it unchanged is
regression evidence, not new crash lifecycle proof. This route promises no
normal disk save/reload, fresh process reload, trainer rewards, live party
slot synchronization, or full gameplay lifecycle proof. A requirement for
those additional claims must receive its own bounded contract, not new
targets here.

## Exact ordered execution arms for later configuration

The patch-only focused arm uses the current bridge-selected interpreter
(`lua5.1` preferred, otherwise `lua`) through `$LUA`, in exactly this order:

```bash
"$LUA" tests/battle_engine_test.lua
"$LUA" tests/battle_scene_controller_test.lua
"$LUA" tests/battle_party_bridge_test.lua
"$LUA" tests/phase4_move_effect_inventory_test.lua
"$LUA" tests/phase4_recoil_if_miss_effect_rom_test.lua
```

Keep the two shared suite commands unchanged and mandatory afterward:

```bash
env -u POKEPORT_ROM bash scripts/test_all.sh
# Existing step environment: POKEPORT_ROM: ${{ steps.rom.outputs.path }}
bash scripts/test_all.sh
```

The shared runner already enumerates `tests/*_test.lua`, so it discovers the
new literal ROM fixture without a runner edit. It requires `lua5.1`; toolchain
fallback alone cannot establish full-suite readiness. Inventory/new ROM
fixture may report an explicit skip without an inherited ROM in the focused
or no-ROM run, but those skips never satisfy ROM acceptance. The verified-ROM
suite must show both the inventory aggregate and new two-record fixture
actually passed, non-skipped. The
[Magnitude ROM fixture](../../tests/phase4_magnitude_effect_rom_test.lua)
provides the supported-hash verification/parsing convention, not effect-45
behavior evidence. New record expectations come from the accepted source
chain, not the engine predicate under test.

**A deterministic headless replay is required**, using the existing
patch-only replay arm and its verified-ROM environment:

```bash
bash scripts/runtime_phase4_recoil_if_miss_replay.sh
```

The new wrapper must require the supplied ROM environment, use `set -euo
pipefail`, and invoke `lua5.1` on the same five tests above in that order,
following the [current headless wrapper](../../scripts/runtime_phase4_magnitude_replay.sh).
The actual deterministic sequences live in those tests: real crash events,
fatal/pending replacement progression, stepwise controller HP, bridge HP/PP,
and branch-local RNG sentinels. The wrapper prints its bounded PASS receipt
only after all commands succeed. Re-running a test wrapper is not independent
retail replay, LÖVE presentation proof, normal save/reload, or whole-turn RNG
parity. This explicit replay claim is limited to represented headless state.

## Guards, readiness, and successor

Preserve the current workflow's main-push-only trusted checkout, exactly one
changed request/probe, explicit unknown-route rejection, supported-ROM SHA-1
`41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`, nonempty patch/target checks,
literal target validation, `git apply --check`, post-apply `git diff --check`,
ordered tests/replay, and patch-only staging/commit/push. Do not change
existing route arms or shared guards. A failure leaves implementation
unpublished. No private paths, ROM data, assets, or secrets enter patch or
committed receipts; retain only safe counts/hashes/step outcomes. In
particular, do not copy a shared suite's environment-bearing summary into
public artifacts. This plan does not modify shared logging or ROM discovery.

**One fresh route-specific substrate probe is required**, only after a
separately authorized configuration and independent configuration PASS.
Prior route receipts do not prove this new selector. Before any authorized
submission, recover existing jobs and freshly confirm the required runner
availability under that later task; this plan performs no runner inspection.
The probe may prove trusted checkout, exact selector, Lua toolchain and the
existing private SHA gate. Validation, application, focused tests, both full
suites, replay, and publication must all skip in probe mode. It cannot prove
the ten-path allowlist or behavior. Independent probe-outcome review and a
separately reviewed implementation authority remain prerequisites to a later
single implementation request. No retry allowance is created here.

The only proposed successor after independent plan PASS is a bounded route
configuration task for `.github/workflows/local-worker-bridge.yml`,
`work/coordination/LOCAL_RUNNER_BRIDGE.md`, and that task's own evidence.
It may encode this selector, equal ten-path lists, five focused commands,
replay arm and documentation. It may not submit a probe/request or implement
behavior. Configuration, probe, implementation authority, and implementation
outcome each retain their required independent gates.

All accepted exclusions remain: only effect 45 / IDs 26 and 136; ordinary
successful-hit behavior retained; effects 48/198 and generic misses separate;
late-only immunity conditional and not an ordinary oracle; cancellation/
interception, Protect, Substitute, abilities, items, Endure/Focus Band,
status/Foresight, semi-invulnerability, called/mirrored/nonordinary provenance,
multi-turn/forced selection, doubles/links, malformed/unsupported battlers or
party state, animation/timing and generic MoveEnd/whole-turn parity excluded.
No gameplay support or Phase 4 completion is claimed.

## Evidence and handoff

Live `git ls-remote` reproduced the base above. Design task/report SHA-256
matched the independent PASS (`255bc925...e3ed1`, `9e5c9b4c...a6fb0`), and
the supplement report matched `92b990bf...e4484`; full identities remain in
their accepted reviews. Inspected workflow SHA-256:
`fb98001cd06ab8ff368f9ccbb0d079ebb809865709a1708ce2dfa55b6199edac`.
Read the workflow selector, validation, toolchain, focused/full/replay and
publication arms, bridge procedure, prior route pattern, and the concrete
test/engine/controller/party seams above. No source uncertainty or required
extra runtime owner was found within this bounded evidence surface.

Only this report and task evidence may change. Whitespace and documentation
checker receipts, including this initially untracked report, accompany the
exact artifact hashes in the handoff. No gameplay tests, runtime/replay, ROM,
private runner, workflow/route, request/probe, staging, commit or push ran.
Independent exact-plan review is next; this Researcher does not self-certify.
