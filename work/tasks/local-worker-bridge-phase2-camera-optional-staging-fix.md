# Task: fix optional-document staging for the Phase 2 camera bridge route

- Status: `CLOSED — REVIEWED PASS`
- AGI status: `AGI READY`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE`
- Owner: project maintainer
- Risk: `LOW`
- Parent dependency: `work/tasks/phase2-gba-camera-viewport-proof.md`

## Goal

Correct only the Phase 2 camera route's publish staging so an absent optional
review-document path cannot prevent already-validated, explicitly allowlisted
implementation files from being staged and published.

The guarded run at `34753075794` passed target validation, both focused tests,
both full suites, verified-ROM validation, and the runtime replay, then failed at
the final publish step. The route currently invokes one `git add` with both
required implementation paths and the optional, not-yet-created independent-review
path. Stage each member of the existing explicit list only when it exists; do not
add any path or broaden the route.

## MAY CHANGE

- `.github/workflows/local-worker-bridge.yml` only;
- this task and coordination/review documentation.

## MUST NOT CHANGE

- camera/gameplay/runtime implementation, tests, replay, route selection,
  allowlisted path set, focused commands, public-PR policy, permissions, ROM SHA
  gate, validation/test ordering, or independent-review requirement;
- ROMs, BIOS, screenshots, extracted assets, generated content, or any unrelated
  bridge route.

## Acceptance criteria

1. The existing Phase 2 camera staging list remains exact and visible in the
   workflow; each listed file is staged only if present.
2. A missing optional review document cannot suppress staging of any present,
   explicitly listed implementation file.
3. No wildcard, directory staging, inferred permission, or generic fallback is
   introduced.
4. `bash -n`, deterministic static inspection, and the no-ROM suite pass.
5. Independent Reviewer returns `PASS` on the exact correction revision before
   retrying the unchanged reviewed camera patch.

## Completion / handoff

After independent `PASS`, retry the already-reviewed allowlist-matched camera patch
request. Treat the prior run's focused/full/runtime successes as evidence of the
unchanged implementation, but require the guarded runner's final publish step to
succeed before reconciling the camera leaf.

## Completion evidence

Independent review passed `11394868d1800dcc53526d9b8f068d0042ec4514`.
The retried guarded run `34753297372` completed final staging and publication
successfully without changing its exact path set or evidence gates.
