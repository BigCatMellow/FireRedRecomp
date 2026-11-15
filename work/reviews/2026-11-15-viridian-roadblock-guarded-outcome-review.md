# Viridian C0 roadblock guarded outcome — independent review

Verdict: **BLOCK**. The sole guarded request failed at `Run task runtime
replay` because the runner had no `love` on PATH. No item-12 replay evidence
exists, and nothing was published. The allowance is consumed. The gate cannot
pass without an operator environment fix plus a new, separately compiled,
independently reviewed recovery authority.

- Task: [P5-06-VIRIDIAN-ROADBLOCK-IMPLEMENTATION](../tasks/phase5-viridian-roadblock-implementation.md), item 13.
- Reviewed request: PR #57 commit `f5582ff`, merged as
  `2450e158095a531f81abe834c93c008e5232cc57` on 2026-11-01.
- Reviewed package: `git diff 77405ec b04c694` (`b04c694ed2494856d0889f826e1d93ecd99d4c34`).
- Workflow: `.github/workflows/local-worker-bridge.yml` at `2450e15`.
- Public receipt: [run `41273209685`](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/41273209685),
  job `124750051396`, conclusion **failure**; runner `MediaCenter`.

## Independence and boundary

I reviewed this result from independent context and wrote only this review
file. I did not author, submit or dispatch the package or the request. I did
not read a ROM, run LÖVE, edit, commit, push, comment, or touch any
other worktree. All my git use was read-only, in a detached worktree at
`2450e15`. This record copies no private path, ROM name, secret or log body.

## Request and package identity

- `git diff --name-only 49d0f45 2450e15` lists exactly one file:
  `work/local-runner/requests/phase5-viridian-roadblock-20261018.patch`.
  This is the contract's literal request path (contract lines 42–43). Blob
  `69c27034`, SHA-256
  `c16e2c2439abdc7aebf4f1f46a260fb44c769b6c3f2c7867469a7c1fa5b33197`.
- Its `+++ b/` targets are exactly the nine contract paths (lines 48–57).
- The request patch is byte-identical to `git diff 77405ec b04c694`, apart from
  full versus abbreviated `index` hashes.
- The filename matches the `phase5-viridian-roadblock*.patch` selector
  (workflow lines 140–141). The log shows "Selected explicit bridge route:
  phase5-viridian-roadblock".

## Step table (job `124750051396`)

| # | Step | Result | Evidence? |
| --- | --- | --- | --- |
| 1 | Set up job | success | Runner identity only: `MediaCenter`. |
| 2 | Check out trusted main push | success | Yes. HEAD resolved to `2450e15…`. |
| 3 | Identify bridge request | success | Yes. Exactly one changed request (wf 99–115 logic). |
| 4 | Select explicit task route | success | Yes. Route `phase5-viridian-roadblock`. |
| 5 | Verify local toolchain | success | Lua 5.1.5 only. Checks only `git` and `lua` (wf 157–169); **does not check `love`/`xvfb-run`**. |
| 6 | Locate and verify private FireRed ROM | success | Yes. "ROM SHA-1 verified for FireRed US v1.0" against `41cb23d8…` (wf 171–193). |
| 7 | Probe complete | skipped | N/A (patch mode). |
| 8 | Validate bounded patch targets | success | Yes. Nine-path allowlist (wf 274) plus `git apply --check` (wf 283). |
| 9 | Apply bounded patch | success | Yes. `git apply` plus `git diff --check` (wf 284–292). |
| 10 | Verify Viridian roadblock artifacts before evidence | success | Yes. All nine paths exist (wf 294–316). |
| 11 | Run task-focused test | success | Yes, partial. Six focused commands in contract order: 205/86/128/78/25 passed, and the ROM fixture **16 passed, 0 failed (non-skipped)**. |
| 12 | Run no-ROM suite | success | Yes. "PASS: 205 test files (no-ROM mode…)". The roadblock ROM test cleanly SKIPs here, as designed (wf 457–462). |
| 13 | Run verified-ROM suite | success | Yes. "PASS: 205 test files (ROM mode: verified ROM supplied)". **Zero SKIP lines**. `phase5_viridian_roadblock_rom_test: 16 passed, 0 failed` (wf 464–471). |
| 14 | Run task runtime replay | **failure** | **No.** The wrapper exited 127 with "error: love is required for the Viridian roadblock runtime replay" before launching anything (wf 473–577, case at 570–571). |
| 15 | Publish verified bounded implementation | skipped | None. Nothing was staged or pushed (wf 579+, roadblock case 788–798). |

### Item 11: did the non-skipped, SHA-verified ROM test pass?

**Yes, as a receipt; no, as acceptance.**

- In step 13, the fixture ran with the masked private ROM env and produced 16
  passed and 0 failed, with no SKIP. Step 11 shows the same result.
- The fixture's own gate calls `RomImporter.verify(path)` before any reads, and
  fails closed on mismatch (fixture lines 19–22). Step 6 independently verified
  SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`.

Items 10 and 11 therefore have valid guarded receipts inside this job. But the
job as a whole failed. The contract says "A failed guarded job stops"
(line 213) and lists "failed guard/test/replay" as a stop condition
(line 201). So these receipts are diagnostic only. They do not support C0
behavior acceptance, and a later recovery cannot cite them in place of its own
complete successful run.

## Root cause of the step 14 failure

**Classification: runner environment defect.** It is not a wrapper defect and
not a package defect.

1. **The wrapper behaved correctly.** `scripts/runtime_viridian_roadblock_replay.sh`
   (package path 8):
   - requires `POKEPORT_ROM` (line 11);
   - then loops over `love xvfb-run timeout mktemp`, and exits 127 on the first
     command it cannot find (lines 12–17).

   This is the same fail-closed guard, and the same order, as the accepted
   LÖVE wrappers `runtime_title_oak_entry_replay.sh` (lines 9–10),
   `runtime_natural_capture_replay.sh` (lines 10–11) and
   `runtime_save_restart_replay.sh` (lines 11–12). The observed exit code and
   message match lines 14–15 exactly. A missing tool made the wrapper refuse,
   which is the intended behavior.

2. **`love` was absent from the job PATH on runner `MediaCenter`.**
   - It was the first command checked, so the job never reached `xvfb-run`.
   - Whether `xvfb-run`, `timeout` and `mktemp` are present is therefore
     **UNKNOWN**.

3. **No LÖVE route has ever run on `MediaCenter`.**
   - The two cited comparison runs did not invoke `love`:
     - Run `38434551595` (job `115425037342`) ran route
       `phase4-recoil-if-miss-effect`.
     - Run `38071195897` (job `114268783871`) ran route
       `phase4-magnitude-effect`.
     - Both ran on `MediaCenter`, and both replay steps succeeded by running
       `lua5.1` only. Their wrappers contain no `love` reference
       (`grep -c love` gives 0). Their markers were
       `RUNTIME_REPLAY phase4_recoil_if_miss PASS…` and
       `RUNTIME_REPLAY phase4_magnitude PASS…`.
   - Every bridge job since the runner moved to `MediaCenter` used a route
     whose replay is Lua-only or explicitly "not applicable": jobs
     `112575360972`, `112575394107`, `112578220899`, `114081150936`,
     `114268783871`, `115425037342` and `117787881344`, and the runs between
     them.
   - LÖVE replays did run on the earlier runner, `firered-mint` (machine
     `kudu`):

     | Run | Job | Marker |
     | --- | --- | --- |
     | `34547647645` | `103103620729` | `RUNTIME_REPLAY natural_capture_save/restart PASS` |
     | `34604493910` | `103279514247` | `RUNTIME_REPLAY title_oak_entry PASS` |
     | `34753297372` | `103713352706` | `RUNTIME_REPLAY phase2_camera_viewport PASS` |

     All three are from September 2026. The move to `MediaCenter` happened by
     2026-10-02. The 2026-10-06 Lua 5.1 toolchain recovery shows that
     `MediaCenter`'s toolchain was rebuilt for Lua only.

4. **The gates did not detect the gap earlier.**
   - Toolchain verification checks only `git` and `lua` (wf 157–169).
   - The readiness probe, run `39165635888` / job `117787881344`, therefore
     could not have detected a missing `love`.
   - The route-configuration and probe task and review records contain no
     `love`/`xvfb` availability check. The only mention is `love.update` in
     the authority review, at line 57.

   This is a process gap, not a package defect. Closing it would need a
   workflow change, which this contract forbids (line 191).

5. **The package is not implicated by the evidence.** All guards and suites
   before the replay passed. `main.lua` at `b04c694` defines the
   `viridian_roadblock` replay case (lines 926 and 3920) and prints the
   `RUNTIME_REPLAY viridian_roadblock …` marker (line 1060).

   **UNKNOWN:** whether the replay would pass once LÖVE is present. It has
   never executed against the real ROM.

## Publication state

- Remote `main` is still `2450e158095a531f81abe834c93c008e5232cc57` (GitHub
  API, 2026-11-15). No commit follows the merge, and no bridge run follows
  `41273209685`.
- The five new paths are absent from `main` (contents API returns 404):
  - `src/core/ViridianRoadblock.lua`
  - `tests/phase5_viridian_roadblock_test.lua`
  - `tests/phase5_viridian_roadblock_integration_test.lua`
  - `tests/phase5_viridian_roadblock_rom_test.lua`
  - `scripts/runtime_viridian_roadblock_replay.sh`
- The four modified paths on `main` are byte-identical to the base `77405ec`
  blobs, not to `b04c694`:

  | Path | Blob on `main` (= base) | Blob at `b04c694` |
  | --- | --- | --- |
  | `main.lua` | `fda67054` | `5fdb6fa1` |
  | `src/core/PlayerMovement.lua` | `9b5a3f51` | `afa71155` |
  | `tests/player_movement_test.lua` | `7f10ebe5` | `6448cfd0` |
  | path 9 task | `c1010b88` | `7c341269` |

- Step 15 was skipped. **No partial publication occurred.**

## Allowance

**Consumed.** The contract authorizes exactly one guarded request (lines
41–43) and states: "No tenth path, report, shared fixture/wrapper change,
route change, replacement input, retry, or second request is authorized"
(lines 61–63). The stop conditions require diagnosing and recording "without
retry, replacement input, silent approximation, or status advancement" on a
"failed guard/test/replay" or a "need for a second request" (lines 200–204).
"A failed guarded job stops" (line 213).

A same-filename resubmission cannot re-trigger the route either:
- Request identification requires the triggering commit to change exactly one
  request (wf 99–107). An unchanged file produces no diff.
- Changing its bytes would be a forbidden replacement input.

## Recovery prerequisites (all required, in order)

1. **Operator environment fix (operator-only).** Make `love` available on the
   PATH of the self-hosted runner service on runner `24` / `MediaCenter`
   (label `firered-local`), together with `xvfb-run`, `timeout` and `mktemp`.
   The operator records an attestation, without private paths, of
   `command -v` for each tool and the `love --version` output, taken as the
   runner service user.
   - The installed LÖVE version should match the version the earlier
     `firered-mint` replays used, which is **UNKNOWN**. The recovery authority
     must state the version it accepts.
   - The bridge cannot self-verify this. Neither a `runner-online*.probe` nor a
     roadblock probe checks `love` (wf 157–169), and adding such a check is a
     workflow change this contract forbids.
2. **New authority.** A separately compiled recovery contract, mirroring the
   P5-04 route-probe recovery precedent, with its own independent PASS before
   any artifact is created. It must:
   - cite this BLOCK and run `41273209685` / job `124750051396`;
   - declare itself a new bounded request, not a retry or amendment of
     `f5582ff`;
   - keep the same nine-path allowlist and the workflow and route unchanged.
3. **Changed request filename.** One new literal request filename that still
   matches the `phase5-viridian-roadblock*.patch` selector (wf 140), for example
   `phase5-viridian-roadblock-<date>-recovery.patch`. Its bytes must be
   pinned to SHA-256
   `c16e2c2439abdc7aebf4f1f46a260fb44c769b6c3f2c7867469a7c1fa5b33197`
   (byte-identical to the failed request, so it is not a replacement input).
   The existing request file stays untouched. If `main` moves before dispatch,
   rebase rules must be stated, because any byte change needs its own review.
4. **Fresh pre-dispatch checks (contract lines 68–71):**
   - `firered-local` is online and idle;
   - no bridge job is queued or running;
   - the route and configuration are unchanged;
   - the patch still applies to the current `main`;
   - the prerequisite revisions and verdicts are unchanged.

   On 2026-11-15, runner `24` `MediaCenter` was online and not busy. That
   observation is informational only and does not satisfy this check.
5. **Complete successful guarded job, then independent outcome review.** Steps
   2–15 must all succeed, including a non-skipped ROM fixture and the exact
   `RUNTIME_REPLAY viridian_roadblock PASS` marker. A separate independent
   item-13 review must follow before C0 behavior acceptance.

## Can item-12 replay evidence be obtained without a recovery? **No.**

- The contract permits LÖVE and ROM execution "only inside the existing
  hash-gated guarded job" (lines 72–73), and forbids local ROM access.
- The Worker's local evidence is explicitly "no ROM, no LÖVE". Its in-test
  `viridian_roadblock` replay function ran against a synthetic harness, which
  is not item-12 evidence (it does not use the private supported ROM, LÖVE or
  `xvfb`).
- No other guarded run exists, and the allowance is consumed.

## UNKNOWNs

- Whether `xvfb-run`, `timeout` and `mktemp` are present on `MediaCenter`.
  The wrapper stopped at the first missing tool.
- Which LÖVE version the September `firered-mint` replays used, and whether
  `MediaCenter` can run LÖVE headlessly under `xvfb` at all.
- Whether the C0 replay passes against the real ROM: it has never executed.
- How `POKEPORT_ROM` reached the focused step 11, which declares no step env.
  It is presumably runner-level env. This is not a defect, because step 13
  is the controlling ROM receipt.

## Bounded conclusion

Items 1–11 have guarded receipts in this job. Item 12 has none. Item 13
cannot pass. No C0 behavior acceptance, status advancement, or Phase 5/7
claim follows. The next action belongs to the operator (prerequisite 1),
followed by a separate recovery authority (prerequisites 2–5).
