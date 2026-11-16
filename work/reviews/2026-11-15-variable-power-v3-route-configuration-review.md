# Variable-power V3 bridge route configuration — independent review

Verdict: **PASS**. It applies to exact revision `20d8ba9` (PR #68), based on
main `c435521`. This is route-configuration acceptance only.

- It permits compiling the gate-3 probe task only.
- It grants no probe, request, ROM, runner, merge or status authority.

## Independence and exact scope

I did not author this configuration, the plan, or PR #58.
`git diff --name-only origin/main...20d8ba9` lists exactly the 4 MAY CHANGE
paths. Their SHA-256 values:

| Path | SHA-256 |
| --- | --- |
| `.github/workflows/local-worker-bridge.yml` | `c920505987071b59c2d23def7754e182685f6a940a14bd47a318d0f7ed863dd7` |
| `work/coordination/LOCAL_RUNNER_BRIDGE.md` | `7f5f5625761b1eb981dd15674a209cc14c906cf587e8139d362a316d48db85d2` |
| config task | `493d5b34a1a2f040cef1354a3cc843220fdf4b1b57eb9466fb21b28f03a62ede` |
| config report | `96c64e8fea066947ee752111a8cb45edb02713cf77fffd5001181930cac0bc4e` |

Precedent used: Magnitude config `57d6b05` and its review
`2026-10-10-magnitude-route-configuration-review.md`. I also used the
effect-45 and roadblock staging arms.

## Findings

1. **Existing routes are byte-unchanged.**
   `git diff -U0 origin/main 20d8ba9 -- .github/workflows/local-worker-bridge.yml`
   has 0 `-` lines and 57 additions. The additions form six hunks, each
   inserted next to the precedent arm.
2. **The selector is correct (workflow 137-139).** It accepts only
   `phase4-variable-power-v3-effect*.patch` and `phase4-variable-power-v3-effect*.probe`.
   - It is not a prefix of any existing pattern, and no existing pattern is a
     prefix of it.
   - Unknown names still reach `*)` and fail.
3. **The allowlist is correct (workflow 275).** It lists exactly 8
   `$ROUTE:$path` literals. They are set-equal to
   `git diff --name-only 49d0f45 fbe5b6f`, and to the patch's own extracted
   `--- a/`/`+++ b/` target set (checked with `diff`). There is no wildcard.
4. **The focused commands are correct (workflow 467-472).** The four `$LUA`
   commands match plan lines 96-101 exactly, in order.
5. **The replay arm is correct (workflow 600-602).** It is the literal plan
   echo, byte for byte. It runs nothing else.
6. **Two additions go beyond the plan's literal arms. Both are acceptable.**
   - **Pre-evidence step (workflow 322-342).** It is gated on
     `mode == 'patch' && route == V3`, and requires all 8 paths as regular
     files. This encodes plan line 79 ("All eight must exist after application
     and before evidence"), so it is in plan, not new scope. It mirrors the
     roadblock step.
   - **Require-all check before staging (workflow 817-837).** It follows the
     effect-45 and roadblock arms. It carries out the obligation the effect-45
     plan review recorded: missing artifacts must fail, not be skipped by a
     conditional `-e` loop. It is strictly more fail-closed.
7. **Staging is exactly the 8 paths.** Each path gets its own
   `git add -- "$path"`, and the shared empty-diff guard is retained.
8. **Nothing can trigger for other routes.**
   - Every new arm is keyed on the V3 route name, inside an existing `case`.
   - The single new step's `if` requires the V3 route.
   - The magnitude, recoil, roadblock and runner-online selectors still
     resolve unchanged.
   - The V3 package is rejected under the magnitude route.
9. **Coordination ledger.** The `LOCAL_RUNNER_BRIDGE.md` edit is one inserted
   bullet after Magnitude. That matches the `57d6b05` shape: scope, the 8
   paths, tests, the probe gate and exclusions. It also states no replay.
   - The operator-approved takeover is recorded as authority in the config
     task, lines 32-37.
   - Like `57d6b05`, the task edits no STATE, HANDOFF or TASK_REGISTER file.
   - The plan erratum (delta open item 1) is recorded correctly in the task,
     lines 42-53.
10. **Gate-3 and gate-5 risks: none found.**
    - **Probe mode:** all new patch-mode arms skip, and `Probe complete` prints
      the route.
    - **Request:** `git apply --check` and `git diff --check` pass on
      `c435521`, and none of the 8 paths changed there. With the patch applied
      offline, the no-ROM `test_all.sh` passes 207 files and
      `check_repository.lua` passes.

## Independent offline workflow-logic check

I wrote my own harness rather than reusing the author's. It is Python with
`-I`, using a throwaway `mkdtemp` tree from `git archive origin/main` and a
local bare remote standing in for `origin`. It extracts each step's `run`
from the YAML and executes it with `bash`, using stub env vars and a
logging `lua5.1` stub. It used no network, runner, ROM or LÖVE.

All 21 checks PASS:

- **Selection:** V3 patch and probe names select the V3 route. Four
  near-miss names are rejected. Four existing routes still select correctly.
- **Gating:** the new step requires patch mode.
- **Patch validation:** the real 8-path package passes validation and
  `apply --check`, and is rejected under the magnitude route. Apply and
  `diff --check` pass.
- **Evidence steps:** the pre-evidence step passes. The focused stub log
  equals the 4 commands in order. The replay output is exactly the literal.
- **Publication:** publication succeeds to the stub remote. Its commit's file
  list equals exactly the 8 package paths, even with an untracked stray file
  present. The commit subject matches the bridge convention.

## UNKNOWN

- Real runner behavior and the verified-ROM suite are not exercised here, by
  design. They are gates 3 and 6.

## Exact next allowance

Compile only the gate-3 probe task
`work/tasks/local-worker-bridge-phase4-variable-power-v3-route-probe.md`. Its
own review is required before any probe file is pushed.
- Gates 2-4 must still not touch any package path.
- No request is authorized.
