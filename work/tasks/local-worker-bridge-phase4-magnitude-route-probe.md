# Task: establish Magnitude bridge readiness only

- Task ID: `P4-F3-MAGNITUDE-ROUTE-PROBE`
- Status: `READY_FOR_WORKER`
- Type: `GUARDED READINESS PROBE`
- Authority: reviewed configuration `57d6b05` and its independent PASS.
- Assigned role: `WORKER`; independent reviewer: `REVIEWER`.

## Goal

Create exactly one probe, `work/local-runner/probes/phase4-magnitude-effect-route-20261010.probe`, to prove trusted checkout, selector recognition, Lua, and private supported-ROM SHA readiness. It must be its commit's sole bridge input.

## MAY CHANGE

- Only that probe file, with text limiting it to readiness as described above.

## MUST NOT CHANGE

No patch/request, workflow, code, tests, replay, runner/ROM configuration, coordination, capability status, or Magnitude behavior. Probe mode must skip validation/application, focused/full suites, replay, staging, commit, and publication.

## Acceptance and handoff

The guarded job must pass checkout, `phase4-magnitude-effect` selection, Lua, SHA gate, and `Probe complete`. Record no private path/data. Independent outcome review must PASS before any separately reviewed implementation request can exist. On any failure, record it and stop; no retry is authorized.
