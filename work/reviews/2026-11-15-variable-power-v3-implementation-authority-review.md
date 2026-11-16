# Variable-power V3 implementation authority — independent review

Verdict: **PASS** for exact revision `2ac6d40` (PR #72), based on main
`c981e0c`. It covers the authority task and its three coordination edits.

The authority task is
[`local-worker-bridge-phase4-variable-power-v3-implementation-authorization.md`](../tasks/local-worker-bridge-phase4-variable-power-v3-implementation-authorization.md)
(SHA-256 `74dbace22968ef74181b2a396b676a99924d3c2ed99b4edc7ee3f2032815187c`).

- This PASS permits only the single literal request after the fresh
  pre-dispatch checks.
- It certifies no V3 behavior and no Phase 4 completion.

## Independence and exact scope

I did not author this authority, its coordination edits, PR #58 or the V3
package.

- **The diff:** `git diff origin/main...2ac6d40` touches exactly the task,
  `STATE.json`, `HANDOFF.md` and `TASK_REGISTER.md`.
- **Additions only:** there are 0 removed lines in `work/coordination/`.
- **No package path:** none of the 8 package paths is touched.
- **Workflow:** byte-unchanged since `5652093`.
- **Checks:** `git diff --check` and `check_repository.lua` pass.

Precedent: Magnitude authority `c9ca2ab` and
`2026-10-10-magnitude-implementation-authorization-review.md`.

## Findings

1. **The patch pin is exact (task lines 56-60).**
   - `git diff --full-index 49d0f45 fbe5b6f | sha256sum` gives
     `9643c37ae974216956d09122e5d7b70d23a097bbe96691325e8a68f1456d94eb`.
   - The patch is 93,970 bytes and 1,392 lines, as stated.
   - It changes exactly the 8 listed paths.
   - `git apply --check` passes on the current tree (`c981e0c` plus
     coordination only).
2. **The request path and route are correct (task lines 51 and 61-72).**
   `work/local-runner/requests/phase4-variable-power-v3-effect-20261115.patch`
   matches the merged `phase4-variable-power-v3-effect*.patch` selector. The
   8 paths equal the merged allowlist (workflow line 275) and staging
   (workflow lines 817-837).
3. **The gate 1-3 receipts are correct (task lines 15-17).**

   | Gate | Revision | Review |
   | --- | --- | --- |
   | 1. Route plan | `3975948`, PR #67 merged `c435521` | `3056bc5` NEEDS_FIX, then delta PASS `a2752f4` |
   | 2. Route config | `20d8ba9`, PR #68 merged `5652093` | PASS `8d4c2ff` |
   | 3. Probe | probe task `63e0269`, task PASS `5a6651f`; probe `ccae04a`, PR #70 merged `87578c8` | outcome PR #71 merged `c981e0c` |

   - The probe hash `dde12b9f…ab9e63e` is correct.
   - Run `43780125346` and job `133015184467` are correct.
   - Non-blocking: the gate-3 row cites the outcome review's merge, not its
     commit `85895dd`. Add `85895dd` for symmetry with the other rows.
4. **The pre-dispatch checks are complete (task lines 83-94).** They cover:
   - the request bytes and hash, and that it is the only file;
   - `git apply --check` on the then-current main;
   - the route arms unchanged since `5652093`;
   - the runner online and idle;
   - no bridge run active or queued;
   - the filename unconsumed.

   Open PRs #59, #61 and #63 touch `BattleEngine.lua` and/or the inventory
   test and report. That makes the stated rule ("a conflict is a stop, not a
   rebase") load-bearing and correct.
5. **No retry, and the outcome-review rules are correct (task lines 98-107
   and 129-153).**
   - **Verbatim quotes required:** the quoted fixture line matches the
     fixture's `print` at `fbe5b6f` exactly. The inventory `inventory
     aggregate moves=` line and the `PASS complete source partition` line
     match test lines 351-354. The ROM-mode line is also required.
   - **SKIP:** a SKIP in the verified-ROM step cannot PASS.
   - **No overclaiming:** no LÖVE, battle-parity, Brock AI or phase claim is
     allowed.
   - **Gate-6 coordination:** follows `e83fc45`.
   - **Expected run:** 13 steps succeed and 2 skip (`Probe complete` and the
     roadblock gate). Together that is all 15 workflow steps.
6. **Accepted: the coordination departure from Magnitude.** `c9ca2ab`
   rewrote the top-level STATE and HANDOFF. This PR instead adds a
   `v3_relay` object, a "Parallel relay" HANDOFF section and one register
   row.
   - `diff <(jq -S . main STATE) <(jq -S 'del(.v3_relay)' PR STATE)` is
     empty.
   - The P5-06 HANDOFF and register text is byte-unchanged.

   This is the correct choice. P5-06 is a live relay with its own owner.
   Overwriting its top-level state would erase Codex's IN_PROGRESS record,
   and Magnitude had no concurrent relay. The operator's approval
   (2026-11-15) is recorded in task lines 31-43, in the HANDOFF section and
   in `v3_relay.coordination_authority`.
7. **Nothing found that would make gate 5 fail.** Notes:
   - The pinned patch has 11 single-space context lines. A request commit
     therefore shows "trailing whitespace" under `git diff --check`. That is
     the same as Magnitude request `1d01fc7`, which has 6 such lines.
   - Public CI (`test.yml`) runs only `check_repository.lua` and
     `test_all.sh`. The bridge's `git diff --check` runs on the applied
     package, which passed offline in config review `8d4c2ff`.
   - Do not "fix" that whitespace. Doing so would break the pinned hash.
   - Non-blocking clarification for task lines 74-76: the probe ran at
     2026-11-16T00:24Z, so "calendar date" is ambiguous by time zone. The
     selector ignores the date. Prefer keeping the literal `-20261115`
     filename, so the reviewed authority's bytes need no post-review edit.
     If a rename is ever needed, record it in a separate receipt commit
     rather than editing this task.

## Exact next allowance

After this PASS is merged, and the fresh pre-dispatch checks pass
immediately before dispatch, exactly one request PR may add only
`work/local-runner/requests/phase4-variable-power-v3-effect-20261115.patch`,
with SHA-256 `9643c37a…94eb`.

- There is no retry, rebase or second request.
- The gate-6 independent outcome review is mandatory.

Only this review file was authored. Nothing was merged, and no runner, ROM or
LÖVE action took place.
