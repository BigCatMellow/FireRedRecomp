# First run and clean-target verification

This guide documents existing entry points, not an installer or a completed
desktop acceptance result. The [accepted clean-clone evidence](../work/reviews/2026-10-01-clean-clone-verification-review.md)
proves a constrained CLI path only; desktop first-run/refusal remains unverified.
Independent review of this documentation must precede a separately authorized
fresh P0-04 verification. [Canonical status](../work/roadmaps/CAPABILITY_CHECKLIST.md)
remains evidence-gated.

## Conditional host prerequisites

The verification profile is **already provisioned Linux** with Git, Bash,
Lua 5.1 available as `lua5.1`, `sha1sum`, and LÖVE 11.5 for desktop checks.
The observed workstation was Linux Mint 22.2/x86_64; this is not a clean-OS
installation recipe, all-Linux guarantee or a Windows/macOS/mobile claim.
LÖVE 11.5 matches [conf.lua](../conf.lua); a usable graphics/display session is
an additional desktop prerequisite. A DISPLAY variable or installed Xvfb alone
does not prove that session works.

From the repository root, check CLI prerequisites without installing anything:

```bash
(
  for tool in git bash lua5.1 sha1sum; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      printf 'Missing prerequisite: %s\n' "$tool" >&2
      exit 127
    fi
  done
  git --version
  bash --version
  lua5.1 -v
  sha1sum --version
)
```

For desktop checks, also verify `love --version` reports 11.5. CLI-only checks
do not require LÖVE or a display. Record actual versions and stop the affected
check if a tool is missing or incompatible. The suite requires `lua5.1`, not
an arbitrary executable named `lua`. Do not silently supply private wrappers,
change PATH/settings, choose package sources, install dependencies or repair a
display as part of verification. Those need a separately agreed setup scope.

## No-ROM command-line checks

Use a clean shell without inherited developer `POKEPORT_*` overrides. From the
clone root, explicitly disable ROM and replay opt-ins:

```bash
env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY lua5.1 scripts/check_repository.lua
env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh
```

Both commands should exit 0. Record the checker's dynamic file/link counts,
suite file count and explicit ROM-dependent skips. Skips are not ROM evidence.
The checker only enumerates tracked files, so stage an authorized new document
before checking its links during development. It does not validate prose truth
or prove instructions work on an unprepared host.

## Safe refusal checks — no valid ROM needed

During separately authorized verification, choose a deliberately nonexistent
relative input and create a small plain ASCII file outside the clone containing
only synthetic non-game text. Keep all fixture/log files outside the repository.
Assign their local names to `FIRERED_MISSING_INPUT` and `FIRERED_INVALID_INPUT`;
do not use an existing ROM or publish those variable values.

Run these checks separately; a nonzero exit is expected:

```bash
env -u POKEPORT_RUNTIME_REPLAY POKEPORT_ROM="${FIRERED_MISSING_INPUT:?set the nonexistent input name}" bash scripts/test_all.sh
env -u POKEPORT_RUNTIME_REPLAY POKEPORT_ROM="${FIRERED_INVALID_INPUT:?set the synthetic text input name}" bash scripts/test_all.sh
```

The first must report failure to open the input; the second must report an
unrecognized hash and the supported-ROM requirement. Both should stop at ROM
verification before decoding. A missing command, unrelated test failure or
crash is not successful refusal. These cases deliberately fail the suite and
must not be reported as a passing ROM run. Standalone Lua hashing uses
`sha1sum`; the real LÖVE verifier uses `love.data.hash`.

## ROM ownership and privacy

Actual ROM-backed use requires the player's legally obtained FireRed US v1.0
dump, kept privately outside the repository. The importer verifies SHA-1
`41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc` before decoding; a filename or `.gba`
extension is not identity proof. Other revisions, LeafGreen and arbitrary
files are not supported by this gate. Set `POKEPORT_ROM` privately only for
separately intended ROM-backed use; this guide's verification matrix requires
no valid ROM and does not authorize obtaining or copying one.

Errors and ROM-mode suite summaries can contain the supplied path. Keep raw
logs local, review/redact before reporting, and publish only aggregate results.
Never commit/upload ROMs, BIOS dumps, saves, game caches, extracted media,
private paths, environment dumps or credentials.

## Desktop evidence remains a separate gate

On an already usable display, a later clean-target check launches the normal
app from the clone root with all developer overrides absent:

```bash
env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY love .
```

The source-derived expectation is a visible instruction to supply a ROM,
without loaded game content or a fatal error, not a file picker/drop-target
implementation. In separate fresh processes, the same missing and synthetic
invalid inputs supplied via `POKEPORT_ROM` should display verification failure.
GUI refusal is status text, so nonzero GUI exit is not required. Observe the
screen and close only the process created for the check. Process liveness,
an empty log or successful CLI refusal does not prove a visible desktop result.

`POKEPORT_SCREENSHOT=1` requires loaded scene/viewer state and does not capture
normal unset-ROM/refusal-only output. [Runtime replay](../scripts/runtime_replay_smoke.sh)
requires a verified ROM and a gameplay pass marker. Neither substitutes for
these no-ROM desktop observations; do not force a developer view or add a
runtime hook to manufacture evidence. If the screen cannot be observed, record
BLOCK and stop; this documentation does not authorize display repair.

## Clean-target evidence checklist

A later P0-04 task must use a new disposable clone at a recorded exact public
revision, not relabel the old constrained clone as repaired. Use fresh external
temporary XDG data/config/cache and TMP directories, with no prior saves/game
cache or inherited developer overrides; do not delete or overwrite user data.

Record separately: prerequisites/versions; no-ROM checker and suite outcomes;
missing and invalid CLI refusals; visible unset-ROM, missing and invalid
desktop results; and final tracked/untracked/ignored clone cleanliness. Keep
fixtures, logs and transient captures outside Git. Distinguish harmless host
graphics cache from game cache, and publish only aggregate outcomes, exact
revision, versions, exit status, visible-message category and observation method.

[Public CI](../.github/workflows/test.yml) installs Lua on its own hosted runner
and runs the checker/no-ROM suite. It does not explicitly run these configured
refusal entrypoints or launch LÖVE. Its narrow importer assertions are not real
LÖVE hashing or visible refusal. CI is neither this clean-target desktop proof
nor evidence for pristine-machine setup, gameplay, save safety or retail parity.
