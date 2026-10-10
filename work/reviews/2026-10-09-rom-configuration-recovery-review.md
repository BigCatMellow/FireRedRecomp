# Private-ROM configuration recovery — independent review

Verdict: **PASS** — exact one-probe readiness authority, without a retry or
capability extension.

- Reviewed revision: `196dfdc46afbe674460e2c4f7a3816fa028db01e`.
- Task: [RUNNER-ROM-CONFIG-RECOVERY](../tasks/local-worker-bridge-rom-config-recovery.md).

I reviewed this contract independently and authored only this review file. It
permits exactly one new literal probe,
`work/local-runner/probes/runner-online-rom-config-recovery-20261009.probe`.
That filename is admitted by the existing `runner-online*.probe` selector and
therefore selects the pre-existing `runner-readiness` route. Probe mode runs
checkout, request identification, route selection, Lua verification, the
private-ROM hash guard, and `Probe complete`; it skips every patch, test,
replay, and publication branch.

The prior terminal receipt is correctly treated as exhausted: recovery probe
`992c071` / run `37554725384` reached checkout, route selection, and Lua, then
failed at the ROM guard before hashing or access. This contract is a separately
bounded configuration-inheritance check, not a retry of that probe or either
exhausted P4/P5 artifact. It explicitly prohibits those reruns and treats a
success as substrate evidence only; a subsequent result review and new scoped
authority remain required before P4 or P5 may advance.

The contract neither changes the workflow nor records a private path,
credential, ROM byte, or private hash result. Its only stated local fact is
operator-side verification; the guarded job is the permitted test of service
inheritance. Current GitHub metadata shows runner `24` (`MediaCenter`) online,
idle, and labeled `firered-local`; the contract still correctly requires a
fresh observation immediately before dispatch. Any guard failure must stop
without replacement or retry.
