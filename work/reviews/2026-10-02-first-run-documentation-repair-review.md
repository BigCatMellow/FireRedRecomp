# First-run documentation repair — independent review

Verdict: **PASS** for the documentation package only. Desktop first-run/refusal
and the full P0-04 clean-target gate remain unverified.

- Task: [P0-04-DOCS](../tasks/phase0-first-run-documentation-repair.md).
- Exact revision: `d4f7fe8aa0cb1825ef6f1f5f13977ead1f7d6e92`.
- Parent: `c08494181a91f8c487561af6431b4bd2ed1c775f`.
- Discovery: `8c92f6765381b37ba63616798ac19b2fb2ef1926` and its
  [independent review](2026-10-02-first-run-reproducibility-discovery-review.md).
- Guide: [FIRST_RUN](../../docs/FIRST_RUN.md).

## Independent evidence and scope

Recovered public main at the exact reviewed revision. Read the full task,
guide, README diff, accepted discovery and prior P0-04 evidence/review; checked
the documented commands against the current test runner, configuration, ROM
verifier, normal-load/screenshot/replay paths and public workflow. Relevant
runtime/importer/script/workflow owners are unchanged since the accepted
discovery. This review does not repeat or relabel the earlier clean-clone run.

The exact diff contains only `README.md`, new `docs/FIRST_RUN.md` and the
authorized task completion/handoff section. No task criteria/status, runtime,
tests, scripts, workflows, dependency files, toolchain, user configuration,
other documentation, ROM policy or canonical phase state changed.

Independent local checks passed:

- Repository checker, using the pre-existing interpreter by explicit path:
  **276 tracked Lua / 174 Markdown / 498 local targets, zero errors**.
- Each of the four guide Bash blocks separately passed syntax-only `bash -n`.
- Exact three-path diff and `git diff --check` passed.

Those checks validate the authored package, not fresh-host command execution
or desktop behavior. No game suite, fresh clone, negative-input runtime run,
GUI launch, ROM access, installation, download or persistent environment change
was performed for this review.

## Findings against the existing acceptance

1. **Conditional profile, no bootstrap promise.** README links the guide and
   both describe already provisioned Linux rather than universal platform
   support. The guide identifies observed Mint 22.2/x86_64, requires Git/Bash,
   Lua 5.1 as `lua5.1`, `sha1sum` and LÖVE 11.5 for desktop, and distinguishes
   CLI-only requirements. LÖVE 11.5 matches `conf.lua`. The preflight only
   discovers commands/prints versions; missing or incompatible prerequisites
   stop the affected check. It does not choose installers/package sources,
   promise fresh-OS bootstrap, supply private wrappers or certify an unobserved
   OS. Display/Xvfb presence is correctly insufficient for display proof.
2. **Safe no-ROM and refusal guidance.** No-ROM commands explicitly unset ROM
   and replay opt-ins, with a stated clean-shell/no-developer-overrides
   precondition. The refusal cases require a deliberately nonexistent input
   and separately authored small ASCII text outside the clone, never a real
   ROM. Quoted task-specific variables must be nonempty before invocation.
   Expected missing-file/unrecognized-hash failures are distinguished from an
   unrelated crash or missing command and from a passing ROM suite. These
   expectations agree with `test_all.sh` and the production verification gate
   before decode. The standalone `sha1sum` versus LÖVE hashing distinction is
   accurate.
3. **Private ROM boundary retained.** The supported US v1.0 SHA remains exact;
   filenames/extensions are not identity proof, and other revisions/LeafGreen
   are not newly supported. Valid ROM use is separate and privately supplied;
   this verification matrix requires none. The guide explicitly warns that
   error/suite output may contain paths, keeps raw logs local and requires
   review/redaction before aggregate reporting. No private path, game content,
   ROM acquisition/copy step or data publication is introduced.
4. **Desktop remains an observation gate.** The guide labels visible no-ROM
   instructions and configured-input refusal as source-derived expectations,
   not newly observed success or a file-picker implementation. It correctly
   allows GUI refusal as status text rather than requiring nonzero process
   exit. The screenshot hook requires active scene/viewer state; the replay
   script requires a verified ROM/gameplay marker. Neither is advertised as
   no-ROM desktop proof. Missing visibility means BLOCK, not process-liveness
   acceptance, a forced developer view or authorization to repair the display.
5. **Fresh verification remains separate from CI and prose acceptance.** The
   guide calls for a new exact-revision clone, external fresh XDG/TMP state,
   separate CLI and visible desktop cases, and final tracked/untracked/ignored
   cleanliness without deleting user data. Historical P0-04 results are not
   called repaired results. Current public CI covers checker/no-ROM commands,
   not these configured refusal entrypoints or LÖVE visibility. No pristine-
   machine, gameplay, save-safety or retail-parity claim follows from CI or
   this documentation PASS.

## Exact next allowance

The Orchestrator may reconcile the documentation repair and separately dispatch
a fresh P0-04 verification against the published guide on a declared,
prerequisite-ready target. This PASS is not permission to install tools,
change PATH/settings, acquire a ROM or repair a display. If the target is not
ready or desktop evidence remains unavailable, retain the precise blocker.
P0-04 completion and broader Phase 0 save safety remain open until their own
required evidence and independent review exist.

Only this review artifact was authored. No task/state/coordination change,
repair, commit, push, workflow action or phase advancement was performed.
