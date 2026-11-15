# Viridian C0 roadblock recovery guarded outcome — independent review

Verdict: **PASS**. The one authorized recovery request ran to completion.
Every guarded step succeeded. The verified-ROM suite ran with zero SKIP lines,
and the replay printed the exact `RUNTIME_REPLAY viridian_roadblock PASS`
marker with `failures=none`. The bridge then published exactly the nine
contract paths, and their bytes equal the reviewed `b04c694` package. Item 13
is satisfied for this bounded C0 slice only. This review makes no Phase 5/7,
traversal, fresh-save or capability-status claim.

- Task: [P5-06-VIRIDIAN-ROADBLOCK-IMPLEMENTATION](../tasks/phase5-viridian-roadblock-implementation.md), item 13,
  under [P5-06-VIRIDIAN-ROADBLOCK-RECOVERY](../tasks/phase5-viridian-roadblock-recovery.md)
  (authority review [PASS](2026-11-15-viridian-roadblock-recovery-authority-review.md)).
- Reviewed request: PR #65, merged as `e0169dc064d67bb436001a5ca0a26a134b5ed9fa`
  (parents `d9c3ba6`, `afdcfc3`).
- Reviewed package: `git diff 77405ec b04c694`.
- Workflow: `.github/workflows/local-worker-bridge.yml` at `e0169dc`, blob
  `87a4a6bb6bc68197cbb2920829256c45969c1763`. This is unchanged from the pinned blob.
- Public receipt: [run `43765541153`](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/43765541153),
  job `132969676622`, event `push`, head `e0169dc`, conclusion **success**,
  runner `MediaCenter`.
- Published commit: `42cd4fd05adaa8273062dbcc3053562eb3d68fe1` (parent
  `e0169dc`), "Apply verified local Worker patch
  (phase5-viridian-roadblock-recovery-20261115.patch)". It is the current
  `origin/main`.

## Independence and boundary

I reviewed this result from independent context. I wrote only this review
file. I did not author, submit or dispatch the package, the recovery
authority or the request. I did not read a ROM, run LÖVE, edit, commit, push,
comment, merge, or touch any other worktree. All my git use was read-only, in a
detached worktree at `42cd4fd`, which I removed afterwards. I fetched the job log
read-only through the GitHub API. This record copies no private path, ROM name,
secret or log body beyond the short public marker and count lines quoted below.

## Request identity (recovery acceptance criterion 3)

- `git diff --name-only d9c3ba6 e0169dc` lists exactly one file:
  `work/local-runner/requests/phase5-viridian-roadblock-recovery-20261115.patch`.
  This is the authority's literal filename.
- Blob `69c270346c7cdbdc204f40d61fb2e18899343ab4`, SHA-256
  `c16e2c2439abdc7aebf4f1f46a260fb44c769b6c3f2c7867469a7c1fa5b33197`. Both match
  the canonical request exactly, so the recovery request is byte-identical to it.
- The log shows `REQUEST_FILE` set to that path and "Selected explicit bridge
  route: phase5-viridian-roadblock".

## Step table (job `132969676622`)

| # | Step | Result | Evidence |
| --- | --- | --- | --- |
| 1 | Set up job | success | Runner `MediaCenter`. |
| 2 | Check out trusted main push | success | HEAD `e0169dc…`. It first cleaned the leftover applied-but-unpublished files from failed run `41273209685` (`git clean -ffdx` and `reset --hard`). See Observations. |
| 3 | Identify bridge request | success | Exactly one request, the recovery patch. |
| 4 | Select explicit task route | success | `phase5-viridian-roadblock`. |
| 5 | Verify local toolchain | success | Lua 5.1.5. Checks only git and Lua, as before. |
| 6 | Locate and verify private FireRed ROM | success | "ROM SHA-1 verified for FireRed US v1.0." The path is masked. |
| 7 | Probe complete | skipped | Expected in patch mode. |
| 8 | Validate bounded patch targets | success | Nine-path allowlist plus `git apply --check`. |
| 9 | Apply bounded patch | success | `git apply` plus `git diff --check`. |
| 10 | Verify Viridian roadblock artifacts before evidence | success | All nine required paths present. |
| 11 | Run task-focused test | success | Six commands in the item-10 order. See counts below. |
| 12 | Run no-ROM suite | success | "PASS: 205 test files (no-ROM mode; ROM-dependent checks skip cleanly)". The roadblock ROM test SKIPs here, as designed. |
| 13 | Run verified-ROM suite | success | "PASS: 205 test files (ROM mode: verified ROM supplied)". **0 SKIP lines** in the step. `phase5_viridian_roadblock_rom_test: 16 passed, 0 failed`. |
| 14 | Run task runtime replay | success | `RUNTIME_REPLAY viridian_roadblock PASS map=769 pos=22,12 c0=2 trainer=2 connection=0 failures=none`, then the wrapper's "PASS: fixture-backed Viridian C0 roadblock runtime replay". |
| 15 | Publish verified bounded implementation | success | Literal nine-path `git add`. "9 files changed, 1173 insertions(+), 5 deletions(-)". `e0169dc..42cd4fd HEAD -> main`. |

Recovery acceptance criterion 4 (steps 2–15 succeed) is **met**.

## Test counts

- **Focused (step 11, item 10 order):**

  | Test | Result |
  | --- | --- |
  | `phase5_viridian_roadblock_test` | 205 passed |
  | `phase5_viridian_roadblock_integration_test` | 86 passed |
  | `player_movement_test` | 128 passed |
  | `phase5_player_elevation_input_test` | 78 passed |
  | `early_story_test` | 25 passed |
  | `phase5_viridian_roadblock_rom_test` | 16 passed (non-skipped) |

  Every test reported 0 failed. These match the Worker's local counts for the
  five no-ROM tests.
- **No-ROM suite (step 12):** 205 test files PASS. There are 81 SKIP lines, all
  ROM-gated as designed, including the roadblock ROM test.
- **Verified-ROM suite (step 13):** 205 test files PASS with zero SKIP lines.
  The roadblock ROM test passed 16 times, failed 0 times, and did not skip.

Items 10 and 11 are **met**. The fixture's SHA-1 gate is in package path 6. I
reviewed it in the prior outcome review, and it is byte-unchanged here.

## Publication scope (items 13 / recovery "nine paths")

- `git diff --name-only e0169dc 42cd4fd` lists exactly the nine contract paths,
  and the same set as `git diff --name-only 77405ec b04c694`.
- `git diff b04c694 42cd4fd -- <nine paths>` is **empty**.
- Ignoring `index` lines, `git diff 77405ec b04c694` and
  `git diff e0169dc 42cd4fd` are identical.
- No tenth path is touched. That includes the workflow, the request files,
  `work/roadmaps/CAPABILITY_CHECKLIST.md`, and coordination files.

## Item 12 replay witness

The log prints only the marker summary: map 769, position (22,12), C0 called
twice, trainer called twice, connection never called, `failures=none`. It does
not list per-witness lines. I therefore checked what `world.runViridianRoadblockReplay`
in `main.lua` at `42cd4fd` asserts before it prints PASS:

- PASS is printed only when the failures list is empty.
- Every `expect` failure adds to that list, and so does any `pcall` error.
- Both early-return guards (`fixture_map` and `selected_e3`) record a failure
  before they return, so a short-circuit cannot produce PASS.

The witnesses, with the assertions that cover them:

| Witness | Assertions |
| --- | --- |
| Fixture and admission | `session:setVar(0x4051,0)` and `setLocation(769,22,12)` from verified data. One real UP tick (`ordinary_step`: dest (22,11), no C0 yet). Fifteen idle ticks (`no_premature_c0`). C0 is selected at completion on (22,11) at elevation 3 (`selected_e3`). No eligibility is injected. |
| Page1 lock | `page1_lock` after RIGHT+START+SELECT. `print_lock` and `no_reveal_all` on every print tick. |
| NEW B clear | Pass 1 `pageButton = B`. `page_waits_for_new_press` (held/idle does not advance), then `page_clear`: page 2, fresh printer, token 0. |
| Page2 NEW A | Pass 1 `finalButton = A`. `final_ack`: CLOSE_PENDING, frame retained, `acknowledgedBy == "A"`. |
| Close before motion | `closed_before_motion`: WALK_DOWN, printer nil, not moving. Then `forced_start`: dest (22,12), facing DOWN, pixel Y = 176. |
| 16 forced pixels | `sixteen_forced_pixels`: exact pixel Y = 176+i for i = 1..16, X fixed, moving until i = 16. |
| Release barrier | `wait_before_release` (C0 still owns, RELEASE_PENDING, session at (22,12) facing south). Then `release_barrier` on a tick with fresh RIGHT+START+A: C0 cleared, not moving, (22,12), unlocked. |
| End at (22,12) | Asserted in `release_barrier`. The marker also shows `pos=22,12`. |
| Unchanged scene/vars/flags/bag/party | `state_location_facing_only`: the full `SaveFileCodec.encode` of the session equals the pre-state with only location and facing changed. `getVar(0x4051) == 0`. |
| NPC lock and no nested dispatch | `npc_lock` (no NPC ticks while owned). `no_nested_dispatch`: C0 count +1 only, no trainer or connection call, same map, same RNG. `trainer_single_call`: c0 = 2, trainer = 2, connection = 0, which matches the marker. |
| Input leakage | LEAK (RIGHT+START+SELECT+A+B) is pressed fresh on alternating forced-pixel ticks, and direction and START are pressed on the close and forced-start ticks. Exact pixels, plus `unlocked()` (no start menu, mart, battle, trainer approach or dialogue), prove no leakage. |
| Re-entry | A second full `pass("reentry_", A, B)` runs with swapped buttons (NEW A clears page 1, NEW B gives the final acknowledgment) and repeats every check above. |

Exit 0:
- The log does not print an exit code, so I inferred it from the wrapper
  (package path 8, lines 25–38).
- The wrapper exits 1 unless `love` returns status 0 within `timeout 60s` and
  its output contains the marker. It prints its trailing PASS line only on
  that success path.
- `love.event.quit()` without a code is used only when there are zero
  failures.
- The step succeeded and printed that trailing line, so the exit was 0.

Item 12 is **met**.

## Exclusions

- `42cd4fd` touches no CAPABILITY_CHECKLIST, coordination, workflow, route or
  request file.
- The only text that path 9 adds is the Worker's 2026-10-28 local no-ROM
  evidence section. It explicitly states that "no status, guarded, behavior
  or phase gate is advanced".
- No Phase 5 or Phase 7 completion, northbound traversal or fresh-save claim
  appears in the published diff.
- The replay is labelled fixture-backed C0 execution throughout (the
  `main.lua` comment, the wrapper header, and the PASS line).

## Observations (non-blocking)

1. **Leftover workspace state.** The runner workspace still held the applied
   but unpublished package from failed run `41273209685`: four modified and
   five untracked files. Checkout step 2 removed them with `git clean -ffdx`
   and `reset --hard` before the fetch, and step 8's `git apply --check`
   passed on the clean tree. So this run's evidence comes from a clean
   `e0169dc` tree. However, the workflow does not explicitly guarantee this;
   it relies on `actions/checkout` defaults.
2. **No Lua-tests run on `42cd4fd`.** The only "Lua tests" CI run is on
   `e0169dc`, because a bridge push does not trigger CI. The guarded steps
   12–13 are the controlling test receipts.
3. **Toolchain step still checks only git and Lua.** That `love`, `xvfb-run`,
   `timeout` and `mktemp` are present is shown indirectly: the wrapper's
   fail-closed loop passed, and the replay ran. The prior process gap remains
   (a workflow change is out of scope).

## UNKNOWNs

- **Per-witness runtime output.** The replay prints only the aggregate
  marker. Individual witness results are inferred from the code and
  `failures=none`, not observed line by line.
- **Exit status.** Not printed. It is inferred from the wrapper's success-path
  logic, as above.
- **LÖVE version.** The version used at run time is not printed in the log.
  The 11.5 figure comes from operator attestation, not from guarded evidence.

## Bounded conclusion

| Item | Result |
| --- | --- |
| 10 (focused, no-ROM and ROM suites) | Met |
| 11 (non-skipped SHA-verified fixture) | Met |
| 12 (replay witness with exact marker) | Met |
| 13 (nine paths, scope, receipts, assertions, exclusions) | Met |

The recovery request was consumed successfully, and no retry is needed. The
Orchestrator may reconcile bounded C0 behavior acceptance for this slice
only. It must preserve the history of the failed `41273209685` attempt. No
Phase 5/7 completion, northbound traversal or fresh-save claim follows.
