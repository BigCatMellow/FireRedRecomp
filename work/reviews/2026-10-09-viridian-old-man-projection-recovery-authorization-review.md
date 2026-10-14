# Viridian Old Man projection recovery authority — independent review

Verdict: **PASS** — a bounded five-path implementation authority, with no
current code or bridge-artifact authorization.

- Reviewed revision: `0a6df8506bc7f021891a20a1a2744e8405ebf8bc`.
- Contract: [P5-04-OLD-MAN-PROJECTION-RECOVERY](../tasks/phase5-viridian-old-man-projection-recovery.md).

I reviewed this contract from independent context and authored only this review
file. It is grounded in accepted design `87644b2`, route configuration
`7a45118`, and readiness outcome `b8dc901`. Its five permitted later paths
exactly match the established bridge route: map-specific helper, `main.lua`,
focused test, implementation task, and implementation report.

The authority preserves the design's pre-`ObjectEventState.new` timing and
restricts projection to Viridian group 3/map 1, local ID 4, base graphics 240,
and `session:getVar(0x4051)`. It specifies scene 0 as graphics 34/(21,11)/8,
scene 1 as graphics 32/(21,8)/1, and scene >=2 as graphics 32 with decoded
(21,6)/1. It requires fail-closed refusal for missing/wrong inputs, no source
template-list mutation, unchanged ordinary objects, and no generic callback,
VM, decoder, dynamic-graphics, traversal, tutorial, renderer, save, or UI
hook.

No code, request/probe, or patch is authorized until this review passes and a
fresh online, idle, `firered-local` runner observation occurs. Any later patch
must remain within the five paths, pass focused/no-ROM/SHA-ROM evidence, retain
the explicit no-replay limitation, and receive independent exact-result review
before reconciliation.

