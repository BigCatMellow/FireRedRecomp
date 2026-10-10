# Viridian Old Man route-probe recovery authority correction — independent review

Verdict: **PASS** — exact one-probe fresh authority; not a retry.

- Reviewed correction revision: `fae1fae72422dd017679503ecf591932791eb2b7`.
- Contract: [P5-04-ROUTE-PROBE-RECOVERY](../tasks/phase5-viridian-old-man-route-probe-recovery.md).

I reviewed this correction from independent context and authored only this
review file. It resolves the prior contradiction by permitting solely
`phase5-viridian-old-man-projection-route-20261009-recovery.probe` while
prohibiting every other P5 bridge probe, retries of `37125167854`, and
amendments to `f6b9148`.

The contract still pins the canonical probe to verified SHA-256
`ae9485f5348376bf139d45279c5bb773c750cab70227bb2c48c3a25412eff212`.
The recovery filename selects the existing
`phase5-viridian-old-man-projection` route. It prohibits P5 patch/behavior
work plus source, test, workflow, route, runner, private-configuration, and
ROM changes; requires a fresh online, idle, `firered-local` runner observation;
and mandates a separate exact outcome review before any P5 implementation
authority can be compiled. No probe is authorized before these gates hold.
