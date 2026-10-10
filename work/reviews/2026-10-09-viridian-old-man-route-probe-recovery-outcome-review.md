# Viridian Old Man route-probe recovery outcome — independent review

Verdict: **PASS** — exact readiness-only P5 route evidence; no behavior or
implementation claim.

- Reviewed revision: `b8dc9014656504f21067493465587532cbc58b82`.
- Public receipt: [run `38009195083`](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/38009195083),
  job `114084995737`.

I reviewed this exact result from independent context and authored only this
review file. The triggering commit adds exactly one probe,
`phase5-viridian-old-man-projection-route-20261009-recovery.probe`. Its bytes
match the original canonical P5 probe and its pinned SHA-256
`ae9485f5348376bf139d45279c5bb773c750cab70227bb2c48c3a25412eff212`.
The filename selects the existing explicit
`phase5-viridian-old-man-projection` route.

The public job completed checkout, request identification, explicit P5 route
selection, Lua verification, private-ROM SHA verification, and `Probe complete`.
It skipped bounded patch validation/application, focused tests, both suites,
replay, and publication. The one-file probe contains no implementation patch
or gameplay assertion, and this result establishes no projection behavior,
traversal, rendering, tutorial, or generic-script evidence.

This is the sole separately authorized recovery probe, not a retry of
`37125167854` or an amendment to `f6b9148`. It authorizes no P5 implementation
patch. Any later implementation authority must be separately compiled and
independently reviewed.

