# Task: configure the Local Worker Bridge route for variable-power V3

- Task ID: `P4-VARIABLE-POWER-V3-ROUTE-CONFIG`
- Status: `READY_FOR_REVIEWER` — configuration drafted; independent exact
  review required.
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE / CONFIGURATION`
- Parent: [reviewed V3 route plan](local-worker-bridge-phase4-variable-power-v3-route-plan.md).
- Assigned role: `WORKER`
- Independent reviewer: `REVIEWER`, not the author of this configuration.
- Prerequisites:
  - Route-plan review `3056bc5` returned NEEDS_FIX; the revision `3975948`
    then PASSed delta review `a2752f4`.
  - Plan merged as PR #67, `c435521`.
  - No V3 request or probe exists.
- Risk: `MEDIUM` — a widened route could improperly authorize a later patch.

## Goal

Encode only the reviewed fail-closed `phase4-variable-power-v3-effect` bridge
route. This task authorizes no readiness probe, request or V3 behavior.

## Source of truth

- [Reviewed route plan](local-worker-bridge-phase4-variable-power-v3-route-plan.md)
  with its [review](../reviews/2026-11-15-variable-power-v3-route-plan-review.md)
  and [delta PASS](../reviews/2026-11-15-variable-power-v3-route-plan-delta-review.md).
- [Local Worker Bridge](../../.github/workflows/local-worker-bridge.yml) and
  [bridge procedure](../coordination/LOCAL_RUNNER_BRIDGE.md) at `c435521`.
- Precedent: Magnitude configuration `57d6b05`, plus the effect-45 and
  Viridian roadblock configurations for the required-artifact checks.

## Authority for the coordination edit

The operator approved, on 2026-11-15, Claude taking over the V3 relay's
`work/coordination/LOCAL_RUNNER_BRIDGE.md` edits while Codex is
usage-limited. This closes delta review `a2752f4`, open item 2, and is this
task's authority for the gate-2 bridge-procedure edit.

Like `57d6b05`, this task edits no `STATE.json`, `HANDOFF.md` or
`TASK_REGISTER.md`.

## Erratum to the plan (delta review open item 1)

Plan lines 85-86 say "None of the eight paths exists ... on main". That is
wrong:

- Three of the eight paths exist on main and are modified by the patch:
  `src/core/BattleEngine.lua`, `tests/phase4_move_effect_inventory_test.lua`
  and `work/reports/phase4-move-effect-inventory.md`. Each is unchanged since
  `49d0f45` (`git diff --quiet 49d0f45 c435521 -- <path>`).
- The other five paths are new.

The gate-5 `git apply --check` remains the guard.

## MAY CHANGE

1. `.github/workflows/local-worker-bridge.yml`
2. `work/coordination/LOCAL_RUNNER_BRIDGE.md`
3. This task file.
4. `work/reports/local-worker-bridge-phase4-variable-power-v3-route-configuration.md`

## Required configuration

Add only these `phase4-variable-power-v3-effect` arms. Every edit is an
insertion, and no existing line changes.

1. **Selector:** accept only `phase4-variable-power-v3-effect*.patch` and
   `phase4-variable-power-v3-effect*.probe`.
2. **Patch-target validation:** exactly the 8 plan paths.
3. **Pre-evidence step:** `Verify variable-power V3 artifacts before
   evidence`, gated to patch mode and this route. All 8 must be regular files,
   as in the roadblock precedent.
4. **Focused commands,** in order through `$LUA`:
   - `battle_engine_test.lua`
   - `battle_variable_power_v3_test.lua`
   - `phase4_move_effect_inventory_test.lua`
   - `phase4_variable_power_v3_effect_rom_test.lua`
5. **Replay arm:** the literal echo `No runtime replay is authorized: the
   accepted V3 design specifies none; focused and verified-ROM suite results
   are the evidence.`
6. **Publication staging:** the same 8 paths. Every path must exist before
   any is staged, and each is staged with its own `git add -- "$path"`, as in
   effect-45 and the roadblock.

The shared no-ROM and verified-ROM suite steps stay unchanged. The bridge
procedure documents the same scope, the no-replay rule and the probe gate.

## MUST NOT CHANGE

This task does not change:

- code, tests or any package path;
- requests or probes;
- runner or ROM policy;
- the generic fallback or any existing route;
- `STATE`, `HANDOFF` or `TASK_REGISTER`;
- capability status or V3 behavior.

It adds no wildcard, ninth path or staging-only path.

## Evidence

The [configuration report](../reports/local-worker-bridge-phase4-variable-power-v3-route-configuration.md)
holds all evidence: the additions-only diff proof, the offline stub harness
and its results, and the checks.

## Handoff

The Reviewer returns `PASS | NEEDS_FIX | BLOCK` on the exact revision. A PASS
permits only compiling the gate-3 probe task
`work/tasks/local-worker-bridge-phase4-variable-power-v3-route-probe.md`. It
does not permit a request, and gates 2-4 must not touch any package path.
