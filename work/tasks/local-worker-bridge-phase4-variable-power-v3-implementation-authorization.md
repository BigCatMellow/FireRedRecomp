# Task: authorize one guarded variable-power V3 request

- Task ID: `P4-VARIABLE-POWER-V3-IMPLEMENTATION-AUTHORITY`
- Status: `READY_FOR_REVIEWER`
- Type: `IMPLEMENTATION AUTHORITY / GUARDED ROUTE` (gate 4 of the V3 full relay)
- Parent capability gate: Phase 4, effect 117 (Rollout 205, Ice Ball 301) and
  effect 156 (Defense Curl 111)
- Assigned role: `ORCHESTRATOR`; independent authorization reviewer: `REVIEWER`
- Risk: `HIGH` — new cross-turn battle state (a lock family and a status2 bit).

## Prerequisites

| Gate | Artifact | Exact revision | Independent review |
| --- | --- | --- | --- |
| 1. Route plan | [route plan](local-worker-bridge-phase4-variable-power-v3-route-plan.md) | `3975948`, PR #67 merged `c435521` | [NEEDS_FIX](../reviews/2026-11-15-variable-power-v3-route-plan-review.md) `3056bc5`; [delta PASS](../reviews/2026-11-15-variable-power-v3-route-plan-delta-review.md) `a2752f4` |
| 2. Route config | [configuration task](local-worker-bridge-phase4-variable-power-v3-route-configuration.md), [report](../reports/local-worker-bridge-phase4-variable-power-v3-route-configuration.md) | `20d8ba9`, PR #68 merged `5652093` | [PASS](../reviews/2026-11-15-variable-power-v3-route-configuration-review.md) `8d4c2ff` |
| 3. Probe | [probe task](local-worker-bridge-phase4-variable-power-v3-route-probe.md) (merged `63e0269`, [task PASS](../reviews/2026-11-15-variable-power-v3-route-probe-task-review.md) `5a6651f`); probe `ccae04a` | PR #70 merged `87578c8`. Probe SHA-256 `dde12b9f4a687bbaa318dca18714adb34fb4aa2f30353822959e2f473ab9e63e`. Run `43780125346` / job `133015184467`: SUCCESS, with 6 steps succeeding and 9 patch-only steps skipped. | [outcome PASS](../reviews/2026-11-15-variable-power-v3-route-probe-outcome-review.md), PR #71 merged `c981e0c` |

Behavior source:

- PR #58 at `9d761f4` with the bounded
  `work/reviews/2026-10-28-variable-power-v3-implementation-review.md`;
- the Codex reconciliation `fbe5b6f` and its sanity PASS `e733394`, on
  `origin/work/v3-acceptance-reconciliation-20261030`.

This authority re-reviews no behavior. It authorizes only relaying that
reviewed package through the guarded bridge.

## Coordination authority

On 2026-11-15 the operator approved Claude making the V3 relay's
`STATE.json`, `HANDOFF.md` and `TASK_REGISTER.md` edits while Codex is
usage-limited (until about 2026-11-21).

This task makes the gate-4 edits that Magnitude made in `c9ca2ab`, done
minimally and additively:

- a new `v3_relay` object in `STATE.json`;
- a new V3 section at the top of the `HANDOFF.md` relays;
- one `TASK_REGISTER.md` row.

The existing P5-06 top-level state is byte-identical. Codex's newer, unmerged
coordination content on the integration branch is not pulled in.

## Exact future request

Only after this authority receives an independent `PASS`, exactly one bridge
input may be created:

```text
work/local-runner/requests/phase4-variable-power-v3-effect-20261115.patch
```

Requirements for that file:

- It is byte-identical to `git diff --full-index 49d0f45 fbe5b6f`, where
  `49d0f4531ed067370a3024deabcbeb7dc564c597` is the PR #58 base and
  `fbe5b6fff6e6b317cebef373c4e6a4cc8b3699bf` the reconciled head.
- SHA-256: `9643c37ae974216956d09122e5d7b70d23a097bbe96691325e8a68f1456d94eb`
  (93,970 bytes, 1,392 lines).
- It changes exactly these 8 paths, the reviewed route allowlist:
  1. `src/core/BattleEngine.lua`
  2. `tests/battle_variable_power_v3_test.lua`
  3. `tests/phase4_move_effect_inventory_test.lua`
  4. `tests/phase4_variable_power_v3_effect_rom_test.lua`
  5. `work/reports/phase4-move-effect-inventory.md`
  6. `work/reviews/2026-10-28-variable-power-v3-implementation-review.md`
  7. `work/reviews/2026-10-30-variable-power-v3-final-head-review.md`
  8. `work/tasks/phase4-variable-power-v3.md`
- It is the sole changed file of its PR, and the merge's first-parent diff
  contains exactly this one bridge input.
- It selects only `phase4-variable-power-v3-effect`.

If the calendar date is not 2026-11-15 at creation, the Orchestrator records
one new date-stamped literal filename here before dispatch. The bytes and
hash do not change.

Check on 2026-11-15: the patch passes `git apply --check` on `origin/main`
`c981e0c`, run against a scratch index. Gates 2-4 touched no package path.

## Fresh pre-dispatch checks

The Orchestrator runs these immediately before the one merge that publishes
the request. Any failure is a stop.

1. The request bytes match the SHA-256 above, and the file is the PR's only
   changed path.
2. `git apply --check` passes on the then-current `origin/main`. Open PRs
   #59-#63 may touch the same files; a conflict is a stop, not a rebase.
3. The workflow's `phase4-variable-power-v3-effect` arms are unchanged since
   `5652093`.
4. The `firered-local` runner is online and idle.
5. No Local Worker Bridge run is active or queued.
6. The request filename has not been consumed.

## No retry

One publication consumes the sole allowance. A failed guard, test or job is
terminal for this authority. Record only the failing step and its status. Do
not:

- retry, or create a replacement or second request;
- substitute a probe;
- rebase or edit the patch;
- widen the route.

A fix needs a new reviewed authority.

## Expected guarded run

- **Steps that must succeed:**
  - checkout;
  - identify (`mode=patch`);
  - route selection;
  - toolchain;
  - ROM SHA check;
  - target validation and `git apply --check`;
  - apply and `git diff --check`;
  - the V3 pre-evidence artifact check;
  - the four focused commands;
  - the no-ROM suite;
  - the verified-ROM suite;
  - the replay arm, which echoes the literal no-replay text;
  - publish (`Apply verified local Worker patch (phase4-variable-power-v3-effect-20261115.patch)`).
- **Steps that skip:** `Probe complete` and the roadblock pre-evidence step.

## Outcome review (gate 6) requirements

The independent outcome review,
`work/reviews/YYYY-MM-DD-variable-power-v3-implementation-outcome-review.md`,
must verify the following:

1. **Publish commit.** It touches exactly the 8 paths, and its tree equals
   the base with the pinned patch applied.
2. **V3 fixture line.** It quotes the non-SKIP line from the verified-ROM
   step: `phase4_variable_power_v3_effect_rom_test: 4 passed, 0 failed; exact
   2-member and 1-member source families`.
3. **Inventory output.** It quotes both non-SKIP inventory lines: the
   `inventory aggregate moves=...` line and `phase4_move_effect_inventory_test:
   PASS complete source partition and SHA-verified ROM admission; ...`.
4. **ROM-mode line.** It quotes `PASS: N test files (ROM mode: verified ROM
   supplied)`.
5. **Missing evidence.** Any V3 or inventory `SKIP` in the verified-ROM step
   means the full-relay evidence is missing, and the review cannot PASS.
6. **No LÖVE claim.** This relay supplies no live LÖVE or runtime observation,
   and the outcome review must not claim one. It also makes no general
   battle-parity, Brock AI or phase-completion claim.

Gate-6 coordination, per Magnitude `e83fc45`, happens after that review:

- reconcile `STATE.json` and the `TASK_REGISTER.md` row;
- advance the status of `work/tasks/phase4-variable-power-v3.md` only after
  an outcome PASS.

## MUST NOT CHANGE

This authority does not change:

- the workflow, bridge route or procedure;
- the runner, credentials or private-ROM configuration;
- probes, or any request other than the one above;
- the capability checklist;
- PR #58, or Codex's branches and worktrees.

It also does not touch:

- any of the 8 package paths before the request;
- `main.lua`, the controller, party, AI, save or any other effect family;
- ROMs, BIOS files, private paths, ROM-derived assets or caches.

## Review and handoff

The Reviewer decides `PASS | NEEDS_FIX | BLOCK` on this exact authority and
its coordination edits.

- A PASS permits only the one request after the fresh checks above.
- It certifies no behavior and no Phase 4 completion.
- PR #58 is not merged by this relay. After publication, the operator decides
  whether to close it as superseded.

No runner, ROM or LÖVE action happened while this authority was compiled.
