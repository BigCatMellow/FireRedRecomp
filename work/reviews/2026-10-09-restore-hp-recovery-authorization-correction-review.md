# Restore HP recovery authority correction — independent review

Verdict: **PASS** — exact one-artifact fresh authority; not a retry.

- Reviewed correction revision: `fae1fae72422dd017679503ecf591932791eb2b7`.
- Contract: [P4-F3-RESTORE-HP-RECOVERY](../tasks/phase4-restore-hp-recovery.md).

I reviewed this correction from independent context and authored only this
review file. It resolves the prior contradiction by permitting solely
`phase4-restore-hp-effect-20261009-recovery.patch` while prohibiting every
other Restore HP bridge artifact, retries of `37080060017`, and amendments to
`6395a47`.

The contract still pins the canonical request to verified SHA-256
`a5b28ccbbbb9dc4c5ec9ba869c17e9c3abfcb241b2b2bd912a057f79afd5bf0d`.
The recovery filename selects the existing `phase4-restore-hp-effect` route
and its established nine-path allowlist. It forbids source, test, replay,
workflow, route, runner, private-configuration, and ROM changes; demands a
fresh online, idle, `firered-local` runner observation; and requires separate
exact outcome review after the guarded focused/no-ROM/SHA-ROM/replay evidence.
No artifact is authorized before these gates hold.
