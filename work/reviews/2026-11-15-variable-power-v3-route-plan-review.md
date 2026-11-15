# Variable-power V3 guarded bridge route plan — independent review

Verdict: **NEEDS_FIX** for exact plan revision
`6ae170d` (parent `794b919`), task
[`local-worker-bridge-phase4-variable-power-v3-route-plan.md`](../tasks/local-worker-bridge-phase4-variable-power-v3-route-plan.md)
(SHA-256 `4f2b922b6a70894845a3199a64aed2a226af8cb718b5038d02f4fc8c840e05cb`).
Workflow inspected at `794b919` (SHA-256
`1087b126d2a8903e9e46f0c6dbfb21016963be0d38b5e45d16c01397598b443f`).
This review grants no configuration, probe, request, ROM, runner, merge or
status authority.

## Independence and checks

I did not author this plan, PR #58 or any V3 review. Read: `AGENTS.md`
(fast lane, full-relay triggers, rules 3/9), the variable-power design
(V3 section, verification plan, RNG notes), the bridge workflow, PR #58's
three-dot diff, the Magnitude chain (`1347e5e` .. `e83fc45`), effect-45
(`04636d1`) and Flail (`16c436c`) plans and reviews, and the Codex
2026-10-30 final-head and status-reconciliation reviews (`fbe5b6f`,
`e733394`).

Run read-only (all exit 0): `git apply --check` of `49d0f45..9d761f4` and of
`49d0f45..fbe5b6f` on `794b919`; `git merge-tree --write-tree origin/main
9d761f4` (clean); none of the seven paths changed on main since `49d0f45`;
`git diff --check origin/main`; `lua5.1 scripts/check_repository.lua`. No ROM,
LÖVE, runner or workflow was run.

## Findings

1. **NEEDS_FIX — the request would publish a rejected `DONE` status.**
   Plan lines 61-62 and 130-131 require the request to be the `9d761f4` diff
   unmodified. At that head, `work/tasks/phase4-variable-power-v3.md:4` says
   `Status: DONE`. The Codex final-head review rejected that as premature.
   Reconciliation `fbe5b6f` corrected it to `IMPLEMENTED ... full-relay
   acceptance unresolved`. Byte-identical relay would put the rejected status
   on main before any outcome review. That breaks the AGENTS.md rule that
   status advances only after review and Orchestrator reconciliation.
   **Fix:**
   - Make the request `git diff 49d0f45 fbe5b6f`, an 8-path package. The eighth
     path, `work/reviews/2026-10-30-variable-power-v3-final-head-review.md`, is
     documentation only and already independently reviewed (`e733394`).
   - That path is required. The corrected task links to it, and public CI
     (`.github/workflows/test.yml:18`) runs the `check_repository.lua` link
     check.
   - This package passes `git apply --check` on `794b919`.
   - Update plan lines 49-58, 60, 62-64 and 130-131 to match.
   - If the Orchestrator treats the eighth path as re-shape, escalate to the
     operator. Do not relay `9d761f4` unchanged.
2. **NEEDS_FIX — the source of truth is not publicly recoverable.**
   - Plan lines 28-31 cite the Codex reviews on branch
     `work/v3-acceptance-reconciliation-20261030`. That branch exists only
     locally, not on `origin`.
   - **Fix:** push it (`fbe5b6f`, `e733394`) before configuration, and cite
     both SHAs.
   - Also amend lines 31-33. That review also lists "any live LÖVE/runtime
     observation" as missing. State that this relay does not supply it, and
     that the outcome review must not claim it.
3. **PASS with fix — replay decision (lines 86-101): no V3 replay is
   required.** Reasons:
   - AGENTS.md lists "touches ... a runtime replay" as one trigger for the
     full relay. It does not say every full relay needs a replay.
   - Rule 3 requires replays "when the task requires them". The accepted V3
     verification plan names none, and the Codex review declines to invent
     one.
   - The precedent battle-effect replays (`scripts/runtime_phase4_magnitude_replay.sh`,
     `..._recoil_if_miss_replay.sh`) only re-run the focused tests with
     `POKEPORT_ROM` set, then echo a receipt. They witness nothing beyond the
     focused arm plus the verified-ROM suite this plan already mandates.
   - Adding one would only grow the package.

   **Fix:**
   - Line 88 elides the echo text. Make it literal: `echo "No runtime replay
     is authorized: the accepted V3 design specifies none; focused and
     verified-ROM suite results are the evidence."`.
   - Do not reuse the inventory wording "changes no runtime behavior"; it
     would be false here.
   - Lines 89-90 omit the closer precedent, the trainer-party arm (workflow
     line 502, "No runtime replay is authorized: ..."). Cite it.
4. **NEEDS_FIX — the authority gate is underspecified (lines 127-128).**
   - In Magnitude, the authority commit `c9ca2ab` created the implementation
     task. It also edited `work/coordination/STATE.json`, `HANDOFF.md` and
     `TASK_REGISTER.md`.
   - Here the patch itself creates `work/tasks/phase4-variable-power-v3.md`.
     If any earlier gate puts a package path on main, `git apply --check`
     fails.
   - **Fix:** name the authority artifact, e.g.
     `work/tasks/local-worker-bridge-phase4-variable-power-v3-implementation-authorization.md`.
   - Add: "gates 2-4 MUST NOT create or modify any package path on main".
   - List the coordination edits for gates 4 and 6, following
     `c9ca2ab`/`e83fc45`.
5. **Fix — name the evidence lines (lines 80-84).** The outcome review must
   cite these lines from the verified-ROM step:
   - `phase4_variable_power_v3_effect_rom_test: 4 passed, 0 failed`;
   - the non-`SKIP` inventory output;
   - `PASS: N test files (ROM mode: verified ROM supplied)`.

   Any V3 or inventory `SKIP` in that step means the full-relay evidence is
   absent. This is structurally expected: the fixture skips only when
   `POKEPORT_ROM` is empty, and the step sets it from the SHA gate.
6. **PASS — the rest.**
   - **Selector:** `phase4-variable-power-v3-effect` is distinct, and no
     existing pattern captures it. It fails closed via `*)`.
   - **Probe and request paths:** they mirror Magnitude
     (`phase4-magnitude-effect-route-20261010.probe` and
     `-20261010.patch`).
   - **Focused commands:** the four `$LUA` commands are literal and ordered.
     `battle_engine_test.lua` is an unchanged regression check. Controller
     coverage sits inside `battle_variable_power_v3_test.lua`, and the full
     suite runs `battle_scene_controller_test.lua`.
   - **Suites:** both commands exactly match workflow lines 461-471.
   - **Required-artifact step:** it mirrors the roadblock precedent (line 295).
   - **Probe:** the substrate-only probe is required, matching the Magnitude
     and effect-45 chains.
   - **Gate order:** plan → config → probe → authority → request → outcome
     matches `57d6b05`/`92cbba8`/`c9ca2ab`/`1d01fc7`/`7b47c73`/`e83fc45`.
7. **Coordination ledger.** Gate 2 touching
   `work/coordination/LOCAL_RUNNER_BRIDGE.md` matches Magnitude `57d6b05`.
   The last six edits to that file (`38e7d79`, `1d40f3c`, `57d6b05`,
   `7a45118`, `4350aa1`, `24f39c4`) are all authored by Codex, so the
   configuration gate must be dispatched to, or coordinated with, the Codex
   coordination owner. The same applies to the gate-4 and gate-6
   STATE/HANDOFF/TASK_REGISTER edits.

## UNKNOWN

- Whether `fbe5b6f`/`e733394` exist on any remote other than `origin`.
- V2 Fury Cutter (`0663e1d`) is labeled full relay in the design but landed
  without a bridge route. This is out of scope here, but its relay status may
  need the same reconciliation.

## Exact next allowance

The author may revise this plan for findings 1-5 and resubmit for independent
re-review. No route-configuration task may be compiled until a PASS.
