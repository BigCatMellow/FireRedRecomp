# Magnitude route configuration — independent review

Verdict: **PASS** for the exact uncommitted
`P4-F3-MAGNITUDE-ROUTE-CONFIG` draft. This PASS accepts bridge
configuration only. It permits no probe, request, Magnitude implementation,
ROM action, runner action, replay receipt, or capability-status advancement.

## Independence and exact scope

I did not author or alter the draft. I independently read `AGENTS.md`, the
active configuration task, the reviewed Magnitude route plan and its PASS,
the current Local Worker Bridge workflow and procedure, and the analogous
Restore HP and P5 configuration reviews.

The exact reviewed worktree artifacts are:

- `.github/workflows/local-worker-bridge.yml` (SHA-256
  `fb98001cd06ab8ff368f9ccbb0d079ebb809865709a1708ce2dfa55b6199edac`);
- `work/coordination/LOCAL_RUNNER_BRIDGE.md` (SHA-256
  `083b060b2f5c3720c80498df1ac7b3345f5bc3bc5f7897cab8f0fb94a5b7f916`);
- `work/tasks/local-worker-bridge-phase4-magnitude-route-configuration.md`
  (SHA-256
  `3a1c4c5b225f335982bdca924e6d65567709f6a53fdc5d241af4a580dd5e954f`);
- `work/reports/local-worker-bridge-phase4-magnitude-route-configuration.md`
  (SHA-256
  `cb103136d7f1b8464603c166f80d6b81ce2cb8e165817d1935f039e6b986a455`).

Against base `1174634`, the draft changes only the permitted workflow,
bridge procedure, task handoff, and configuration evidence report. The
workflow diff is five insertion-only route arms; it has no deletion or edit
to a shared or neighboring route. There is no request/probe, implementation,
test/replay script, ROM, runner/credential, coordination, or capability-status
change.

## Configuration findings

The workflow adds exactly the reviewed `phase4-magnitude-effect` arms:

1. The explicit selector has only the reviewed
   `phase4-magnitude-effect*.patch` and
   `phase4-magnitude-effect*.probe` prefix forms; the existing unknown-route
   failure remains.
2. Validation admits exactly these nine literal paths: engine, controller,
   their two tests, inventory test, Magnitude ROM fixture, Magnitude replay,
   and the later implementation task/report. It has no wildcard, tenth path,
   staging-only target, `main.lua`, importer/data-model, coordination, or
   workflow target.
3. Focused execution uses the selected `$LUA` and has the exact reviewed
   order: engine, controller, inventory, then Magnitude ROM fixture.
4. The route requires exactly `bash
   scripts/runtime_phase4_magnitude_replay.sh`; there is no no-replay or
   optional fallback.
5. Publication enumerates the exact same nine paths in the same order through
   the existing individual `git add -- "$path"` form.

The shared no-ROM command remains exactly `env -u POKEPORT_ROM bash
scripts/test_all.sh`. The verified-ROM step still receives only
`POKEPORT_ROM: ${{ steps.rom.outputs.path }}` and runs `bash
scripts/test_all.sh`. All seven patch-only execution steps retain their
existing guards. The private-ROM/hash policy and every other route are
unchanged.

The bridge procedure and evidence report state the same nine-path scope,
four focused tests, required replay, exclusions, and post-review gate: only
one separately bounded substrate-only probe may follow; no implementation
request is eligible yet.

## Independent static validation

`git diff --check` passed. PyYAML parsed the workflow, and `bash -n` passed
for all 12 workflow shell blocks.

Using the actual extracted control blocks with temporary safe stubs only:

- selector control flow accepted four matching patch/probe examples and
  rejected four nonmatching extension/prefix examples;
- validation accepted all nine literals individually and once as the combined
  set (10 positives), while rejecting eight unlisted/nonliteral paths and an
  unknown route (9 negatives);
- focused-test stubs recorded precisely the four required commands in order;
  the unknown-route branch failed;
- replay stubbing recorded exactly the required Magnitude replay; its
  unknown-route branch failed; and
- parsed validation and staging lists were set- and order-equal to the nine
  reviewed literals.

These checks did not run a bridge input, patch application, game test suite,
private ROM, replay, Git staging, commit, publication, or runner. They are
configuration-control evidence only.

## Exact next allowance

After Orchestrator reconciliation, this PASS allows only the route plan's
separate one-file substrate-only probe. That probe must still skip patch
validation/application, focused and full suites, replay, staging, commit, and
publication, and require its own independent review before a separately
bounded Magnitude request can be considered.

Only this review file was authored by the Reviewer.
