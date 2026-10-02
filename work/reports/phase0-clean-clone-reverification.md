# P0-04 fresh-checkout reverification

Worker result: **BLOCK — documented host prerequisites are not met**.
The guide's prerequisite check ran on a new public clone and stopped as
documented. No passing CLI suite, ROM refusal or desktop result is claimed.
Independent review of this exact report is required.

- Task: [P0-04-REVERIFY](../tasks/phase0-clean-clone-reverification.md).
- Public/clone revision: `6dcb2e609a702d0d02b2547dc133b594800b87b6`.
- Documentation revision: `d4f7fe8aa0cb1825ef6f1f5f13977ead1f7d6e92`, with
  [independent documentation PASS](../reviews/2026-10-02-first-run-documentation-repair-review.md).
- Observation date: 2026-10-02.

## Fresh checkout and declared environment

Public main independently resolved to the recorded full revision. A new
disposable directory received a fresh HTTPS clone of
`BigCatMellow/FireRedRecomp`, with credential helper and interactive credentials
disabled; it was then detached at that exact revision. It was not copied from
either the working repository or the older P0-04 clone. The public origin,
clone/checkout reflog and absence of object alternates were checked.

Both [README](../../README.md) and [FIRST_RUN](../../docs/FIRST_RUN.md) are
tracked in the new clone and unchanged from the reviewed documentation
revision. Their conditional profile requires an already provisioned Linux
host, including `lua5.1` for CLI checks and LÖVE 11.5 for desktop checks. The
current target does not meet that profile; documentation presence is not host
preparation or clean-target acceptance.

Read-only environment observations: Linux Mint 22.2/x86_64, Git 2.43.0,
GNU Bash 5.2.21 and GNU coreutils `sha1sum` 9.4. Default command discovery
finds Git, Bash and `sha1sum`, but not `lua5.1`, `lua` or `love`. No alternate
interpreter, isolated wrapper or changed PATH was supplied. Machine paths,
environment values and private data are omitted from this aggregate report.

## Exact outcome matrix

The first Bash block was read directly from the clone's FIRST_RUN guide and
executed from the clone root. It checks CLI command availability before its
version-printing commands. The separate documented desktop version command was
also checked, without launching the app.

| Documented check | Observed outcome / boundary |
| --- | --- |
| CLI prerequisite block | **Exit 127**, `Missing prerequisite: lua5.1`. It stopped before the block's version-printing commands. Available-tool versions above were collected separately through read-only version queries. |
| Desktop prerequisite `love --version` | **Exit 127**, command not found. No LÖVE version or usable application/display is established. |
| No-ROM repository checker | **NOT RUN**: Lua prerequisite failed. No new file/link-check counts are claimed for this clone. |
| No-ROM full suite | **NOT RUN**: Lua prerequisite failed. No new suite pass or ROM-skip evidence. |
| Configured missing-input CLI refusal | **NOT RUN**: missing Lua is not an importer refusal. No synthetic test input was created. |
| Synthetic invalid-input CLI refusal | **NOT RUN**: same prerequisite blocker. No hashing or production verification result is claimed. |
| Unset/missing/invalid desktop observations | **NOT RUN**: LÖVE prerequisite failed. No window, visible prompt/refusal, display usability, process-liveness or screenshot result. |
| Final clone cleanliness | **PASS for checkout cleanliness only**: no tracked, untracked or ignored changes after the read-only checks. |

The old constrained CLI results in the
[original report](phase0-clean-clone-verification.md) remain evidence for their
original pin and explicit toolchain deviation. They are not repeated here or
transferred to this fresh clone as a pass. Likewise, no CI/private-runner
receipt is substituted for missing local execution.

## Stop boundary and next allowance

The revised documentation now exists and produces a specific prerequisite
failure on this target. This verifies that limited discovery/stop behavior,
not that the conditional environment has become ready. P0-04 remains BLOCK.
Desktop observation remains a separate unfulfilled requirement; no display
injection, Xvfb attempt, environment diagnosis or repair was made.

Only clone data and two local prerequisite logs were created outside the shared
repository. No fixture, ROM, save, game cache, capture or generated game content
entered the clone. Temporary XDG/app-state directories were unnecessary because
no runtime was launched. No dependencies, tools, configuration, PATH, desktop
session, runtime, tests, workflows, documentation or ROM policy were changed.

Independent Reviewer should check the exact clone/prerequisite observations and
NOT RUN boundaries. Parent may record the blocker and choose a separately
authorized prerequisite-ready target or host-preparation decision; this task
does not authorize either preparation or another workaround. Fresh execution
and independent evidence are still required before any clean-target gate can
close. No Phase 0 or broader save-safety status advances here.

Only this report and the task evidence/handoff are authored for publication.
