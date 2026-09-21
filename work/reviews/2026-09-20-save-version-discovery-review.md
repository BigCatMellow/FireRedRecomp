# P0-02-DISCOVERY independent review

- Disposition: `PASS` — exact save-version discovery and bounded successor recommendation.
- Research revision: `b53c3872d4ba41d968b94575ed3fa29c106f65a2`.
- Reviewed relay: `ea0960efdb5e790b995067af587b2726d09097a4`, `READY_FOR_REVIEWER` for `P0-02-DISCOVERY`.
- Independent live-main recovery returned that same relay revision.
- Codec revision: `103c5e1d5b7ad11d5408a2112d81437117a991c9`; historical version 1 at `a01040eab9e8718efcd130b1e1860373439d5bef`.
- Retail source pin: `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Scope: the two authorized task/report text paths; no implementation or compatibility-policy approval beyond the stated successor boundary.

## Findings against the discovery criteria

The historical matrix agrees with repository history and executable code.
`SaveFileCodec.lua` was absent at introduction parent `c01c956`; its two
recorded changes introduce the version-1 wrapper and later add version 2 with
PC sectors. Version 1 uses five 4096-byte sectors per slot and a total length
of 40,968 bytes; version 2 uses fourteen per slot and 114,696 bytes. Both use
an eight-byte project wrapper and two slots. The report correctly distinguishes
these project containers from a retail-save import format and from the partial
field model's preservation limits.

The current decoder explicitly refuses genuine version-1 output before the
version-2 minimum-length check. No disk migration exists. Empty storage supplied
by an in-memory constructor or encoder is not a supported legacy-file migration,
because normal loading decodes and refuses that file first. Decoder suffix and
reserved-byte tolerance are accurately separated from canonical encoder output.
Historical/current refusal ordering, exact-size previous-buffer preservation,
fixed-position IDs, signatures, checksum extents, slot fallback, empty/error
statuses, and counter selection match the described code paths.

The three material observations were independently reproduced:

- Rollover stores counter zero while returning 4294967296; the decoder selects
  the stale 4294967295 slot. A separate footer-byte witness verified the actual
  encoded zero, not only the returned and selected counters. Pinned retail
  `GetSaveValidStatus` explicitly handles the maximum-u32/zero pair, supporting
  the report's narrow divergence claim.
- A suffix-bearing version-2 buffer decodes, but supplying it as previous bytes
  to the next encode loses the previous fallback slot because preservation
  requires exact length. This establishes the stated in-memory behavior;
  it does not demonstrate a real user's data loss or authorize a policy change.
- A mixed-generation slot is accepted and the final valid sector supplies its
  reported counter. Pinned retail validation also overwrites its slot counter
  as it visits valid sectors without requiring counter consistency. The report
  correctly avoids labeling this observation a demonstrated retail divergence.

The filesystem limits are appropriately bounded. Source inspection confirms
one whole-buffer `love.filesystem.write`, with in-memory counter/bytes advanced
only after a reported success, and load rejection before session replacement.
Neither dual-slot memory validation nor the focused roundtrip tests establish
atomic writes, interruption recovery, or protection against a later explicit
overwrite. The report makes none of those guarantees and clearly separates
these application I/O boundaries from codec acceptance.

The stale charter/checklist statements are real: schema versioning already
exists, while the charter still says to add it before the first layout change.
The completed save-file handoff permitted migration or explicit refusal, and
current version-1 refusal is preserved throughout the proposal. The existing
roundtrip assertion labeled prior-slot preservation compares only five header
bytes; identifying that fixture gap is accurate.

## Independent verification and limits

The relevant codec/layout/storage and focused-test paths are unchanged between
the version-2 codec revision and this discovery. The exact research diff changes
only its two allowed text artifacts; `git diff --check` passes.

Checks independently passed:

- `tests/save_file_codec_test.lua`: 45 passed, 0 failed.
- `tests/save_load_roundtrip_test.lua`: 13 passed, 0 failed.
- The inspected 24-check synthetic characterization harness: all 24 passed;
  its SHA-256 matches the report's
  `e3940fc7ae6a2a0dd0220143cb14e0d2b98c3c32956ea95c2ac9ebb535c5276b`.
- The self-contained reproducer extracted from the exact committed report:
  mixed-generation, suffix-preservation, and rollover observations all reproduced.
- An additional independent rollover footer check confirmed encoded u32 zero,
  returned 4294967296, and stale selected generation 4294967295.

All experiments used synthetic state. The existing codec test's scratch-file
roundtrip ran inside a fresh isolated temporary directory; the test removed its
synthetic file and the empty directory was removed afterward. Other generated
save bytes remained in memory. No real user save or ROM was inspected or
modified, no host failure was induced, and no unrelated full suite was rerun.
Filesystem failure safety and broader semantic/nested-record validation remain
unproven, as the report states.

## Exact next allowance

Orchestrator may accept this discovery and compile/dispatch only its proposed
immediate `P0-02-CONTRACT` successor: correct stale version prose, document
existing version-2 output and read/refusal behavior with explicit limits, and
add narrowly scoped compatibility/corruption fixtures to the existing focused
tests. That contract must preserve runtime behavior, version numbers, version-1
refusal, and phase status. Tests should not make the observed rollover or
suffix-preservation defects permanent desired behavior.

Counter-rollover repair, suffix/prior-buffer policy, filesystem failure safety,
overwrite UX, stricter acceptance, and any legacy migration remain separate
future leaves. Retaining the existing refusal policy requires no new migration
choice; supporting legacy conversion would require its own explicit scope and
data-initialization decision. This PASS does not close the broader save-safety
gate or Phase 0 and does not alter the independent private-runner blocker.

Reviewer wrote only this review. No task, coordination, production code/test,
save policy, commit, push, or external execution state was changed.
