# Phase 4 — Magnitude guarded bridge route plan

- Task: [P4-F3-MAGNITUDE-ROUTE-PLAN](../tasks/local-worker-bridge-phase4-magnitude-route-plan.md).
- Status: proposed route plan; independent exact-draft review required.
- Authority: accepted [Magnitude source lock](phase4-magnitude-source-discovery.md),
  accepted [bounded-singles design](phase4-magnitude-design.md), and its
  independent [design PASS](../reviews/2026-10-10-magnitude-design-review.md).
- Inspection base: current `.github/workflows/local-worker-bridge.yml` and
  the reviewed Restore HP and P5 bridge-route records.

This is documentation for one later bridge-configuration task.  It neither
edits the workflow nor creates a request or probe, and it grants no Magnitude
implementation, ROM, runner, replay, test, or phase-status authority.

## Exact later selector and patch surface

The configuration successor must add exactly one explicit route named
`phase4-magnitude-effect`.  Its selector must recognize only these filename
forms:

```text
phase4-magnitude-effect*.patch
phase4-magnitude-effect*.probe
```

No other prefix, suffix, fallback, or existing Phase 4 route may select this
route.  The workflow's unknown-route failure remains the result for every
other name.

For a later `.patch` selected by that route, target validation and publication
staging must each contain exactly this same nine-path literal allowlist:

1. `src/core/BattleEngine.lua`
2. `src/core/BattleSceneController.lua`
3. `tests/battle_engine_test.lua`
4. `tests/battle_scene_controller_test.lua`
5. `tests/phase4_move_effect_inventory_test.lua`
6. `tests/phase4_magnitude_effect_rom_test.lua`
7. `scripts/runtime_phase4_magnitude_replay.sh`
8. `work/tasks/phase4-magnitude-implementation.md`
9. `work/reports/phase4-magnitude-implementation.md`

The two lists must be set-equal: no wildcard, directory expansion, optional
sixth test path, or staging-only path is allowed.  Individual `git add --
"$path"` staging, as used by the current bridge, is required.  The later
implementation task/report and focused ROM fixture do not yet exist; naming
them here makes their future scope fail closed rather than authorizing a
substitute file.

This surface follows the accepted design's owner seams: the engine owns the
effect-126 draw/table/local move copy/event, the controller owns the ordered
event presentation, existing engine/controller tests establish regression
boundaries, the inventory test and ROM fixture establish the move-222/effect-
126 record without retaining ROM content, and the headless replay establishes
the represented trace.  It does not authorize an admission, importer, or data
model change.

## Required later execution arms

The configuration successor must retain the bridge's existing trusted-main,
one-input, Lua-toolchain, private-ROM SHA-1, `git apply --check`, `git diff
--check`, and patch-only guards.  Within the patch-only focused-test arm it
must use the bridge-selected interpreter (`$LUA`, where the existing workflow
selects `lua5.1` or `lua`) for exactly these commands, in this order:

```bash
"$LUA" tests/battle_engine_test.lua
"$LUA" tests/battle_scene_controller_test.lua
"$LUA" tests/phase4_move_effect_inventory_test.lua
"$LUA" tests/phase4_magnitude_effect_rom_test.lua
```

The existing full-suite commands must remain unchanged and mandatory after
application:

```bash
env -u POKEPORT_ROM bash scripts/test_all.sh
# Step-level environment: POKEPORT_ROM: ${{ steps.rom.outputs.path }}
bash scripts/test_all.sh
```

The first command is the full no-ROM check.  The second is the full
SHA-verified-ROM check, supplied only from the existing successful private
hash gate.  A focused inventory or Magnitude-ROM-fixture skip with no inherited
ROM is permitted only as a no-ROM result; it is not acceptance.  The verified-
ROM full suite must execute the inventory aggregate and new Magnitude fixture
non-skipped.  No command may discover a ROM path, print one, or loosen the
supported SHA requirement.

## Replay decision

**A deterministic replay is required.**  The later patch-only replay arm must
invoke exactly:

```bash
bash scripts/runtime_phase4_magnitude_replay.sh
```

Magnitude needs a route-specific replay because its accepted bounded contract
adds an ordered level event and one draw before the retained accuracy/critical/
damage path.  The replay must exercise only a represented engine/controller
trace: the residue-to-level/power selection, PP/event ordering, ordinary hit
and miss draw counts, and the retained first-player `firstBattle` accuracy-
bypass branch.  It is not authority or evidence for LÖVE rendering, retail
text/animation timing, full seeded turns, doubles, targeting loops, or a ROM
capture.

## Readiness-probe decision

**One new substrate-only readiness probe is required after independent
configuration review and before any later Magnitude request.**  The already
proven generic runner substrate does not prove this as-yet-unconfigured
selector or its patch/probe control flow.  As with the reviewed Restore HP and
P5 routes, the new selector requires a route-specific fail-closed receipt
before it can carry a patch.

The sole authorized future probe filename form is:

```text
work/local-runner/probes/phase4-magnitude-effect-route-YYYYMMDD.probe
```

That one-file commit may establish only trusted checkout, recognition of
`phase4-magnitude-effect`, the selected Lua toolchain, and the existing
supported-ROM SHA gate.  Patch validation/application, focused tests, both
full suites, replay, staging, commit, and publication must all skip.  A PASS
does not exercise the nine-path allowlist and does not authorize behavior; an
independent probe review is still required before one separately reviewed
bounded implementation request.

## Exclusions and successor boundary

The configuration successor may change only the workflow route arms and bridge
procedure/documentation needed to encode this reviewed plan, plus its own
configuration task/evidence.  It must not create a probe or request, modify a
current route, add a generic selector/allowlist, alter the runner or private
ROM policy, or implement Magnitude.

The later Worker patch excludes `main.lua`, importer/catalog/data-model paths,
save/AI/UI-scene/coordination/workflow files, generic dynamic-power helpers,
admission changes, and every other effect family.  It also retains every
accepted Magnitude design exclusion: multi-target/foes-and-ally traversal,
target reselection, doubles/absent battlers, Underground, abilities, items,
status or cancellation expansion, Substitute/MoveEnd, visual timing,
animation, localization, links, and retail-turn parity.  A need for any
unlisted path or behavior is a stop condition for a new contract, never a
route widening.

## Evidence and handoff

This plan derives its naming and route mechanics from the current explicit
bridge, the reviewed Restore HP nine-path/replay route, and the reviewed P5
literal-route/probe pattern.  It preserves the current private-ROM SHA and
trusted-main failure gates.  No workflow, request/probe, runtime, test, ROM,
runner, or implementation action occurred while authoring it.

Before a configuration successor is compiled, an independent reviewer must
verify this exact report and the task handoff, including selector specificity,
validation/staging equality, all four focused commands, both suite commands,
required replay, required probe, and exclusions.  `git diff --check` is
required for this documentation-only package.
