# Restore HP recovery authority — independent review

Verdict: **NEEDS_FIX** — the fresh-authority design is sound, but the contract
contains a contradictory artifact prohibition.

- Reviewed revision: `15229f813eed9ded881d5ba4412560bed37fe679`.
- Task: [P4-F3-RESTORE-HP-RECOVERY](../tasks/phase4-restore-hp-recovery.md).

I reviewed this contract independently and authored only this review file. It
is properly framed as new, separately reviewed authority rather than a retry:
it requires a newly named, sole triggering artifact, pins the existing
canonical patch to SHA-256
`a5b28ccbbbb9dc4c5ec9ba869c17e9c3abfcb241b2b2bd912a057f79afd5bf0d`,
and forbids rerunning `37080060017` or amending the original `6395a47`
request. The digest matches the canonical artifact, and its filename selects
the existing `phase4-restore-hp-effect` route with the established nine-path
allowlist. It also prohibits source, workflow, runner, private-config, and ROM
changes; requires a fresh online/idle `firered-local` observation; and requires
a separate exact outcome review after guarded focused/no-ROM/SHA-ROM/replay
evidence.

## Required correction

`MAY CHANGE` authorizes exactly one new recovery patch, but `MUST NOT` says
“Do not create another Restore HP artifact.” Those literal instructions
conflict. Amend the latter to forbid every artifact **other than the one
literal recovery filename** (while retaining the prohibitions on retrying the
run and amending the original). No artifact should be created until the
contract has this unambiguous boundary and an independent PASS.
