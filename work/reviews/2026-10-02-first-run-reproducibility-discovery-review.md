# First-run reproducibility discovery — independent review

Verdict: **PASS** for the bounded discovery only. P0-04 remains BLOCK; this is
not documentation implementation, host preparation or desktop acceptance.

- Task: [P0-04-DISCOVERY](../tasks/phase0-first-run-reproducibility-discovery.md).
- Exact report/task revision: `8c92f6765381b37ba63616798ac19b2fb2ef1926`.
- Parent and inspection pin: `1a7c9958ab4ba42a8efac1fab42a8913e97acf36`.
- Artifact: [first-run discovery](../reports/phase0-first-run-reproducibility-discovery.md).
- Prior evidence: P0-04 report `d0e0bad` and its
  [independent constrained-report review](2026-10-01-clean-clone-verification-review.md).

## Independent evidence

Recovered public main at the exact reviewed revision. Read the task/report,
accepted P0-04 report/review, README, configuration, production ROM verifier,
test runner, importer smoke test, public workflow and the normal-load/draw,
screenshot and replay paths. The review is against the existing discovery
criteria, not a new setup or platform requirement.

History comparison confirms the named README/configuration/runtime/importer,
test runner, runtime smoke and public workflow owners are unchanged between
the original observed clone `7a2e7ad` and the discovery pin. The report correctly
preserves the earlier 151-file CLI evidence rather than relabeling it as a
fresh or repaired result.

The exact commit changes only the authorized report and task handoff.
`git diff --check` passes. Independently reran the repository checker through
the existing Lua interpreter's explicit path without changing PATH:
**276 Lua / 171 Markdown / 484 local targets, zero errors**. These are
authored-package checks, not clean-target or gameplay evidence. No full suite,
ROM access, GUI launch, capture, installation, download or environment repair
was performed by this review.

## Findings against the discovery criteria

1. **Each accepted blocker is mapped accurately.** `docs/FIRST_RUN.md` is absent
   from the pinned tree. README's `love .` entry and dispersed prerequisites
   do not supply the missing task-named guide. Command discovery independently
   confirms no `lua5.1`, `lua` or `love` on default PATH while the reported
   shell/hash/headless tools are available. `test_all.sh` already checks
   specifically for `lua5.1` and exits 127 if missing; this is not evidence of
   a runtime tool-discovery defect. A present DISPLAY variable is not proof
   that the display is accessible. The earlier capture failure remains an
   observation limit with UNKNOWN root cause, not a demonstrated app defect.
2. **The proposed edit is the smallest coherent documentation successor.**
   One later contract would edit only `README.md` and `docs/FIRST_RUN.md`, plus
   separately authorized task/evidence records. Consolidating preflight,
   repository-root commands, expected outcomes and stop conditions addresses
   the guide gap without a bootstrap, wrapper, installer, manifest, workflow,
   test or screenshot-hook change. The report does not claim that prose alone
   installs missing tools or fixes the desktop.
3. **Host assumptions are conditional, not new support policy.** The observed
   Linux Mint 22.2/x86_64 profile is explicitly already provisioned. Lua 5.1
   must be discoverable as `lua5.1`; LÖVE 11.5 matches `conf.lua` and prior
   tool evidence. Standalone invalid-input hashing needs `sha1sum`, as the
   production verifier shows. The report neither assumes the private wrapper
   exists on another host nor selects package sources or universal Linux,
   macOS, Windows or mobile support. Broader platform/bootstrap promises remain
   a separate host/product decision and stop condition.
4. **Desktop expectations are source-derived and remain unverified.** Normal
   `love.load` with ROM unset adds an instruction and returns; configured input
   is verified before decode, and status lines are drawn by the ordinary draw
   path. No implemented file-picker flow is inferred. The screenshot dispatch
   requires a capture scene or active game/viewer state, so normal unset-ROM
   or refusal-only output is not covered. The runtime replay script requires
   a valid ROM and gameplay marker. Neither is repurposed as no-ROM first-run
   proof. Visible instruction/refusal and absence of a crash still require
   observation on a usable target display; process liveness is insufficient.
5. **Re-verification and CI are properly separated.** The future matrix covers
   declared prerequisites, a new exact clone, no-ROM checker/full suite,
   configured missing and synthetic-invalid CLI refusals, separate normal
   desktop cases and external XDG/TMP isolation. Negative CLI exits are not
   equated to GUI exit behavior: current desktop refusal is status text.
   Existing public CI installs Lua and runs only the checker/no-ROM suite;
   it does not explicitly run these production refusal entrypoints or desktop
   cases. The narrower importer smoke assertion is not real LÖVE hashing or
   visible refusal. Future CLI coverage is described as feasible, not an
   authorized workflow change. Desktop/isolation proof stays clean-target
   evidence under this proposal.

The matrix retains aggregate-only reporting, external synthetic inputs and
transient outputs, cleared developer overrides, no old save/game cache,
tracked/untracked/ignored cleanliness and no removal of user files. It requires
no valid ROM. Historical evidence, future documentation acceptance, fresh-target
execution and private-ROM/gameplay/retail-parity proof remain distinct.

## Exact next allowance

After reconciliation, the Orchestrator may shape the single proposed docs-only
README/FIRST_RUN contract with the conditional already-provisioned profile.
That change must receive its own exact review before a separately authorized
fresh P0-04 verification. Missing tools, an unusable display or a broader host
support requirement remain blockers, not installation or repair authority.
P0-04 and broader Phase 0 save-safety gates do not close here.

Only this review file was authored. No repair, task/state/coordination change,
commit, push, workflow action or phase advancement was performed.
