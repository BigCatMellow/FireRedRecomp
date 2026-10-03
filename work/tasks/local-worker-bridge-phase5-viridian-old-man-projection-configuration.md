# Task: configure Local Worker Bridge route for Viridian Old Man projection

- Task ID: `P5-04-ROUTE-CONFIG`
- Status: `READY_FOR_WORKER`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE / CONFIGURATION`
- Authority: [reviewed P5-04 route plan](local-worker-bridge-phase5-viridian-old-man-projection-route.md).

## Goal

Encode the reviewed `phase5-viridian-old-man-projection` bridge route without
widening the accepted P5-04 implementation boundary.

## MAY CHANGE

1. `.github/workflows/local-worker-bridge.yml`
2. `work/coordination/LOCAL_RUNNER_BRIDGE.md`
3. this task file
4. `work/reports/local-worker-bridge-phase5-viridian-old-man-projection-configuration.md`

## Required configuration

Add only an explicit selector for matching `.patch` and `.probe` inputs, the
five literal validation and publication targets from the reviewed plan, the
single focused Lua command, and an explicit message that no runtime replay
applies to this pre-spawn data-projection route. Retain existing shared
no-ROM/full verified-ROM suite behavior and fail-closed defaults. Document the
route's five-path scope and no-replay rationale in the bridge procedure.

## MUST NOT CHANGE

Code, tests, requests/probes, runner registration or credentials, generic
selector fallback, any existing route's behavior, ROM handling, canonical
phase status, or P5 implementation behavior.

## Verification and handoff

Run workflow syntax/static checks appropriate to existing repository practice
and inspect all five route arms together. An independent exact configuration
review must PASS before a single substrate-only probe is authorized. The probe
is not an implementation request and must skip patch/test/replay/publication
steps.

## Worker configuration handoff — 2026-10-03

The workflow adds only the five reviewed route arms: explicit request/probe
selection, literal validation, one focused Lua command, explicit no-replay
message, and individual literal staging. Bridge documentation records the same
five-path/no-replay boundary. No probe, request, implementation, test or
canonical status change is included. Independent exact configuration review is
required before the one authorized substrate-only probe.
