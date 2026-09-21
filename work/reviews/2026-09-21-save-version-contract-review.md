# P0-02-CONTRACT independent review

**PASS** — exact implementation
`63592c31051d6f9034355ed978d4e68e5354c2fd`, parent `3a6443f`.
The bounded documentation/compatibility-fixture acceptance criteria are met.
This does not establish filesystem crash safety or close Phase 0.

## Scope and state

- Reviewed the seven-path implementation diff against
  [P0-02-CONTRACT](../tasks/phase0-save-version-contract.md), the repository
  operating contract, current coordination relay, and accepted
  [save discovery](2026-09-20-save-version-discovery-review.md).
- Independently recovered published `main` at
  `6181171a9ce13bd2a4075198f25b41a56645863c`; its relay identifies the exact
  implementation above as `READY_FOR_REVIEWER`.
- Only the authorized charter save section, saving/loading ledger row,
  relevant checklist prose, new save-format document, two focused tests and
  task evidence changed: 214 insertions, 11 deletions. All are text/Lua;
  `git diff --check 3a6443f 63592c3` passes. Runtime, layouts, schema numbers,
  decoder tolerance, refusal policy, workflow and phase status are unchanged.
  No binary/user save, ROM, extracted asset or generated cache was added.

## Material evidence

The new contract accurately distinguishes canonical schema-2 writes (`FRSV`,
eight-byte header, two fourteen-sector slots, 114,696 bytes) from observed
reader tolerance and from retail saves. It records the real schema-1 shape,
explicit legacy/unknown/unwrapped refusal, absence of migration, and the
existing migration-or-refusal policy for future changes. It does not silently
choose a missing-PC-data migration policy.

Direct inspection of the unchanged codec and `main.lua` supports the stated
checksum/fallback and load/write boundaries. Rollover stale selection,
suffix-induced prior-slot loss, unchecked fields and generic refusal display
remain limitations, not accepted desired behaviors. Mixed-sector counters
are not misrepresented as an established retail divergence. Whole-buffer
filesystem writes are not claimed to provide atomic replacement or
interruption recovery. Checklist completion states remain unchanged.

The added fixtures are substantive:

- The legacy constructor uses literal historical layout/footer definitions,
  independently of current encoder/constants. Its two five-sector slots form
  a valid 40,968-byte schema-1 file, not a schema-2 file with its version edited.
  An independent in-memory witness extracted this exact constructor and
  passed its bytes to historical codec `a01040e`: it decoded successfully as
  generation 2, slot 0, with no PokemonStorage. The current codec explicitly
  refused the same bytes by version. Normal tests require neither git history
  nor external save fixtures.
- Literal current header/length, unknown/unwrapped refusal and truncations at
  4, 7, 8 and 114,695 bytes exercise the relevant guards. Existing successful
  state/PC roundtrip assertions remain.
- Each PC sector 5–13, including the shorter final chunk, is corrupted inside
  its checksummed payload without changing the footer. Each case requires
  older generation 1 / slot 1 plus older money and empty PC state, preventing
  a merely non-nil or mixed-generation result from satisfying the check.
- The roundtrip fixture compares all 57,344 bytes of the untouched prior
  slot while retaining newer-generation/location assertions. Independently
  wrapping the encoder to discard prior bytes caused exactly this assertion
  to fail: **12 passed, 1 failed**, exit 1. No runtime file was edited.

## Independent execution

To exclude concurrent CI work, tests ran from a `git archive` snapshot of
exact `63592c3` at `/tmp/firered-save-contract-review.tpfiWs`, using the local
Lua 5.1 toolchain, `POKEPORT_ROM` unset and a fresh scratch `TMPDIR`.

- `lua5.1 tests/save_file_codec_test.lua`: **63 passed, 0 failed**.
- `lua5.1 tests/save_load_roundtrip_test.lua`: **13 passed, 0 failed**.
- `env -u POKEPORT_ROM bash scripts/test_all.sh`: **149 test files PASS**;
  ROM-dependent checks skipped as expected. Local log:
  `/tmp/firered-save-contract-review.tpfiWs/full-no-rom.log`.
- Historical-fixture witness: **PASS**. Prior-slot mutation witness: expected
  targeted failure reproduced as described above.

No ROM/replay or filesystem failure-injection evidence is required or claimed
for this documentation/test-only package.

## Exact next allowance

Orchestrator may reconcile and close `P0-02-CONTRACT` and the proven explicit
save-version/refusal contract gate. A source-locked rollover correction or
another remaining gate needs its own bounded dispatch. Suffix preservation,
live-file safety, migration, stricter validation and broader Phase 0 completion
are not authorized or proven by this PASS. This reviewer changed only this
review file; coordination reconciliation remains with Orchestrator.
