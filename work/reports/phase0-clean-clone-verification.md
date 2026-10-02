# P0-04 clean-clone verification

Worker result: **BLOCK** for complete first-run/desktop verification.
The constrained README command-line path **passed** with explicitly supplied,
pre-existing tools. This is neither pristine-machine setup success nor Phase 0
acceptance. Independent review of this report is still required.

## Revision and environment

On 2026-09-29, public main independently resolved to
`7a2e7ad7f6eec1a41c97f613143598b5de9c5a10`. A new disposable directory received
a fresh HTTPS clone from `BigCatMellow/FireRedRecomp`, with credential helper
and interactive credentials disabled. The clone was detached at that exact
revision; it was not copied from the working checkout or populated from local
project files. Initial and final Git status were clean.

The observation was resumed on 2026-10-01 without replacing its pin. The later
dispatch at `1a312f6` does not change the observed README, runtime entrypoints,
test runner or public test workflow. Results below certify only the pinned
clone and environment actually used.

Environment: Linux Mint 22.2, Linux x86_64; Git 2.43.0; GNU Bash 5.2.21;
Lua 5.1.5; LÖVE 11.5. Xvfb, timeout and ImageMagick capture utilities were
already available. No tool, dependency, configuration or project repair was
installed or applied during this task. Machine paths and private data are
omitted; all logs and synthetic inputs remained outside the clone.

Explicit deviations:

- The task names `docs/FIRST_RUN.md`, but no such tracked file exists at the
  observed revision. It could not be followed or verified; no replacement
  guide was invented. The available [README](../../README.md) was used.
- Default PATH had neither `lua5.1` nor `love`. The Orchestrator authorized
  constrained observation using an already provisioned isolated toolchain,
  exposed by an explicit per-command PATH prefix. Its existing LÖVE wrapper
  also supplies its packaged library/Lua module paths. This is a declared
  environment prerequisite, not a documented fresh-machine installation.
- Headless desktop observation required pre-existing Xvfb and temporary XDG
  directories outside the clone. Its capture failed, as recorded below;
  neither the display nor the project was repaired.

## Commands and observed results

The README commands ran from the new clone root with the toolchain PATH
prefix. `POKEPORT_ROM` and `POKEPORT_RUNTIME_REPLAY` were unset for no-ROM
checks. A fresh external TMPDIR isolated the suite's temporary file fixture.

| Documented entrypoint / supplied input | Observation |
| --- | --- |
| `lua5.1 scripts/check_repository.lua` | Exit 0: **276 tracked Lua, 158 tracked Markdown, 428 local targets PASS**. |
| `bash scripts/test_all.sh`, no ROM/replay environment | Exit 0: **151 test files PASS in no-ROM mode**; ROM-dependent checks explicitly skipped. |
| `POKEPORT_ROM=<nonexistent-relative-input> bash scripts/test_all.sh` | Exit 1 at ROM verification: could not open input / no such file. No successful ROM-suite result is claimed. |
| `POKEPORT_ROM=<synthetic-text-input> bash scripts/test_all.sh` | Exit 1 at ROM verification: unrecognized hash, with the supported FireRed US v1.0 requirement. No successful ROM-suite result is claimed. |
| `love .`, ROM environment unset, under isolated Xvfb/XDG | Process was still present at the observation check, but the capture utility could not open its X display. No visible first-run prompt or refusal was verified. The owned process was deliberately stopped. |

The invalid input was newly authored plain ASCII text outside the clone, not
a ROM or game-derived fixture. No valid ROM was found, opened, copied, retained
or supplied. The refusal runs use the README's existing environment-variable
test entrypoint and its production identity gate; no importer mock, test edit
or undocumented runtime hook was introduced. These observations establish
command-line missing/invalid-input refusal, not desktop UX behavior.

For the one desktop attempt, all inherited `POKEPORT_*` variables were removed,
the existing runtime was launched through `xvfb-run`, audio was directed to its
null driver and XDG data/config/cache were isolated outside the clone. The
observation wrapper had a bounded timeout and cleanup for its own child.
The capture utility returned an X-server-open error, the wrapper exited 1,
and no usable capture was produced. Later missing-file/invalid-input desktop
cases were **not attempted**. A running process alone is not accepted window,
prompt, gameplay or visual-parity evidence. No additional GUI experiment or
repair followed the failure.

## Public CI comparison and evidence limits

At the observed revision, [public CI](../../.github/workflows/test.yml) checks
out the repository, installs Lua 5.1 on its hosted runner, then invokes the
same repository checker and no-ROM suite. It runs on push/pull request with
read-only contents permission. The two passing local commands match that
coverage, but this report's counts are **fresh-clone local observations**, not
a new CI-run receipt.

That public workflow does not launch LÖVE or independently demonstrate the
configured-missing/synthetic-invalid cases. Conversely, this task used
pre-existing tools rather than reproducing CI's installation or a clean OS
setup. No workflow was dispatched or rerun and no private-runner/verified-ROM
test, runtime replay, game-media or valid-save evidence is claimed.

The fresh clone stayed clean: no tracked or untracked project additions,
dependency lockfiles, ROM, save, game cache, screenshot or generated artifact
were introduced there. Transient environment output remained outside it.
Only this report and the assigned task's evidence/handoff are authored in the
shared repository.

## Blocker and exact next allowance

Preserve the constrained CLI PASS; do not repeat it merely because desktop
proof is incomplete. Overall **BLOCK** remains because the named first-run
guide is absent, default-PATH prerequisites required an explicit environmental
deviation, and the isolated display failure prevented observable desktop
first-run/refusal verification. These are evidence/setup gaps, not proof of a
runtime defect and not authorization to install or repair anything.

Independent Reviewer should assess this exact report and its limits. The
Orchestrator must select any documentation/prerequisite or usable-desktop
follow-up separately; this task authorizes none. Phase 0, general save safety,
private-ROM evidence and retail presentation parity remain open.
