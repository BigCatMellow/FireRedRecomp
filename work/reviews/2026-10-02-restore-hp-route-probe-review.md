# Restore HP route probe — independent review

Verdict: **PASS** — execution-substrate readiness only.

- Probe revision: `3c038763ea3a3b7d1287025293a7065bbc686aa6`.
- Reviewed artifact: `work/local-runner/probes/phase4-restore-hp-effect-route-20261002.probe`.
- Prerequisite configuration: `4350aa16edf6e1c7064a5d566f1da63342183ecd`, accepted by the [independent configuration review](2026-10-02-restore-hp-route-configuration-review.md).
- Guarded receipt: [run `36981539166`](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/36981539166), job [`110756964873`](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/36981539166/job/110756964873).

## Exact probe boundary

The reviewed commit adds exactly one file, the named `.probe`, and no patch,
implementation, test, workflow, task, state, request, ROM, or generated
content. Its text correctly limits the run to route selection, trusted
checkout, Lua toolchain, and private supported-ROM SHA verification. It also
requires patch validation/application, focused/full tests, replay, and
publication to skip.

The exact configured route remains fail-closed: its selector accepts the
`phase4-restore-hp-effect` patch/probe prefix; the later patch surface is the
reviewed nine literal paths; and it has distinct focused, full-suite, replay,
and individual-publication branches. This probe carries no target headers, so
it cannot exercise or authorize that later patch surface.

## Independently recovered guarded evidence

Public Actions metadata ties the successful `push` run to the exact probe SHA
above. The completed `local-worker` job ran on the expected private label set
(`self-hosted`, `linux`, `x64`, `firered-local`) with runner name
`firered-mint`.

The job log records all required substrate checks as successful:

- trusted-main checkout fetched and checked out the exact probe SHA;
- the selector printed `Selected explicit bridge route: phase4-restore-hp-effect`;
- the selected toolchain was `Lua 5.1.5`;
- the SHA gate printed `ROM SHA-1 verified for FireRed US v1.0.` for the
  configured supported-ROM hash; and
- probe completion printed that the explicit route and checkout/toolchain/hash
  gate were ready.

The receipt separately records **skipped** for every patch-only step:
`Validate bounded patch targets`, `Apply bounded patch`, `Run task-focused
test`, `Run no-ROM suite`, `Run verified-ROM suite`, `Run task runtime replay`,
and `Publish verified bounded implementation`. Thus neither an implementation
nor a request was applied, tested, replayed, staged, committed, or published
by this run.

## Decision and remaining boundary

This PASS closes only the route-probe prerequisite. It permits the
Orchestrator to dispatch one separately bounded Restore HP Worker request
through `phase4-restore-hp-effect`, subject to the reviewed nine-path
allowlist and all focused, no-ROM, verified-ROM, replay, and independent
implementation-review gates. It does not establish Recover/Slack Off behavior,
effect support, persistence, visual parity, or Phase 4 completion; every
ordinary-path exclusion in the accepted design and implementation contract
remains in force.

Only this review file was authored. No implementation, request, task, state,
or commit was changed by the Reviewer.
