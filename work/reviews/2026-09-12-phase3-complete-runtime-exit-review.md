# Independent review: complete Phase 3 runtime exit replay

- Date: 2026-09-12
- Role: REVIEWER
- Task: `work/tasks/phase3-complete-runtime-exit-replay.md`
- Exact implementation revision: `4f4f29ec`
- Verdict: `PASS`

## Scope checked

Reviewed the task acceptance and stop conditions, the exact implementation diff,
the focused static assertion, and recorded ROM-backed replay and suite evidence.
This review evaluates the bounded evidence leaf and supports parent-gate
reconciliation; it makes no Phase 2 or presentation-parity claim.

## Material findings

1. **Continuous normal-runtime path — PASS.** The route begins at normal title
   handling and drives title/Oak/identity, overworld movement, a live Route 1
   wild-battle loss, normal save handling, and fresh-process load without
   constructing a post-Oak, post-battle, or post-save fixture.
2. **Continuity assertions — PASS.** The first process requires the expected
   RED/GREEN/gender identity and reduced defeat money; the reload process requires
   the same identity, persisted reduced money, expected map/location, and party.
3. **Save boundary — PASS.** The replay creates an isolated temporary XDG sandbox,
   verifies the normal-save file exists, then starts a separate LÖVE process that
   loads through the normal load route.
4. **Recorded deterministic evidence — PASS.** The focused test passed, both
   `bash scripts/test_all.sh` and the verified-ROM invocation passed all 123 test
   files, and the two-process runtime replay emitted its PASS markers at
   `4f4f29ec`.
5. **Scope and regression check — PASS.** The changes are limited to replay-driver
   plumbing, its focused test, and its script. Normal gameplay behavior, save
   layout, ROM policy, public-PR policy, and prohibited-content boundaries remain
   unchanged.

## Verdict

`PASS`

The complete Phase 3 runtime evidence leaf satisfies its acceptance criteria at
exact revision `4f4f29ec`. The later Local Worker Bridge duplicate-patch rejection
was a fail-closed publication-process result: the implementation was already on
`main` and the duplicate request did not weaken or invalidate this reviewed
evidence.
