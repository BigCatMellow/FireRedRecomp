# Task: add Local Worker Bridge route for Phase 4 no-item trainer parties

- Status: `ACTIVE`
- Type: `INFRASTRUCTURE / EXECUTION SUBSTRATE`
- Parent dependency: `work/tasks/phase4-trainer-party-no-item-layouts.md`

## Goal

Add one explicit fail-closed route for the bounded Phase 4 trainer-party
constructor task before any implementation is dispatched.

## MAY CHANGE

- `.github/workflows/local-worker-bridge.yml`;
- `work/coordination/LOCAL_RUNNER_BRIDGE.md` and route probe/documentation.

## MUST NOT CHANGE

- battle/factory/main/test implementation, routing security, trusted-main-only
  policy, public-PR policy, ROM SHA gate, test order, permissions, or content
  boundaries.

## Acceptance

1. Exact task selector has literal bounded target, focused-test, runtime (only
   if actually justified), and staging lists.
2. Unknown routes remain fail closed; no generic/wildcard fallback or broad
   staging is added.
3. Existing validation, ROM, focused/no-ROM/verified-ROM, and publication
   invariants remain intact.
4. One-file non-gameplay probe and independent PASS precede Worker eligibility.
