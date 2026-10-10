# Viridian Old Man route-probe recovery authority — independent review

Verdict: **NEEDS_FIX** — the fresh-authority design is sound, but the contract
contains a contradictory probe prohibition.

- Reviewed revision: `15229f813eed9ded881d5ba4412560bed37fe679`.
- Task: [P5-04-ROUTE-PROBE-RECOVERY](../tasks/phase5-viridian-old-man-route-probe-recovery.md).

I reviewed this contract independently and authored only this review file. It
is a separately bounded new probe, not a retry: it requires one new literal
filename, pins the canonical probe to SHA-256
`ae9485f5348376bf139d45279c5bb773c750cab70227bb2c48c3a25412eff212`,
and forbids rerunning `37125167854` or amending the original `f6b9148` probe.
The digest matches the original probe, and its filename selects the existing
`phase5-viridian-old-man-projection` route. It forbids any patch, source,
workflow, runner, private-config, ROM, P4, and behavior-scope change; requires
a fresh online/idle `firered-local` observation; and mandates an independent
outcome review before any separately compiled P5 implementation request.

## Required correction

`MAY CHANGE` authorizes exactly one new recovery probe, but `MUST NOT` says
“Do not ... create another P5 probe.” Those literal instructions conflict.
Amend the latter to forbid every probe **other than the one literal recovery
filename** (while retaining the prohibitions on retrying the run and amending
the original). Do not create an artifact until the corrected contract receives
an independent PASS.
