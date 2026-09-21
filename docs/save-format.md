# Project save compatibility

`SaveFileCodec` writes a versioned project container around retail-derived
sector structures. It is not a retail `.sav` importer. The current schema is
version 2; no automatic migration is supported. This contract describes the
existing codec and its limits; it does not establish filesystem crash safety.

## Canonical version-2 output

The encoder emits exactly **114,696 bytes**:

- An eight-byte header: ASCII `FRSV`, version byte `2`, then three zero bytes.
- Two 57,344-byte slots, each containing fourteen 4,096-byte sectors.
- Sector IDs 0–13 at fixed positions: SaveBlock2, four SaveBlock1 chunks,
  and nine PokemonStorage chunks. Each sector has 3,968 data bytes and a
  128-byte footer containing ID, checksum, signature `0x08012025`, and counter.

The first save writes generation 1 to slot 1, leaving slot 0 blank. Normal
subsequent saves alternate slots and preserve the entire other slot when the
caller supplies the prior counter and an exactly sized previous buffer.
For supported u32 counters, increment wraps through `0xFFFFFFFE` →
`0xFFFFFFFF` → `0` → `1`; the returned generation matches all written footer
counters. With both slots valid, zero wins over `0xFFFFFFFF` in either
ordering. Every other unequal pair uses unsigned larger-value selection,
and equal counters retain slot 0. This is the literal
[retail counter special case](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/save.c#L534),
not general serial-number ordering or a change to accepted file formats.

SaveBlock1/2 remain partial field models. PokemonStorage includes current box,
14×30 boxed records, names and wallpapers; Hall of Fame/Trainer Tower sectors
and physical sector rotation are not modelled. Unmodelled fields are not
preserved through decode/re-encode.

## Historical schemas and current refusal policy

| Input | Historical shape | Current behavior |
| --- | --- | --- |
| Version 1, introduced at `a01040e` | Eight-byte `FRSV`/version-1 header; two five-sector slots; 40,968 bytes; SaveBlock2 and SaveBlock1 only | Explicit version refusal; absent PC data is not filled in as a migration |
| Version 2, introduced at `103c5e1` | Eight-byte header; two fourteen-sector slots; 114,696 canonical bytes | Decode the selected valid slot into the modelled state |
| Unknown version | Unrecognized version in a project wrapper | Refuse; do not guess or patch fields |
| Unwrapped sector data / retail save | No recognized project wrapper | Unsupported; no retail import or conversion path |

Version 1 already had an explicit wrapper at codec introduction; there is no
supported unversioned predecessor. Future save-layout changes must specify the
accepted schemas and explicit migrations **or refusals**. Any supported
migration needs deterministic evidence; best-effort field patching is forbidden.
Supporting version-1 conversion would require a separate missing-PC-data policy.
In-memory constructors that default missing storage to empty do not migrate
disk files, because normal loading first passes through the decoder.

## Validation and limits

The decoder requires `FRSV`, at least eight header bytes, version 2, and at least
114,696 total bytes. It currently ignores the three reserved bytes and any
trailing suffix. These observations are separate from canonical encoder output
and are not promises that unchecked data is safe or permanently compatible.

A slot must contain all fourteen expected fixed-position IDs with the expected
signature and payload checksums. Checksums add little-endian u32 words within
the modelled chunk length, wrap at 32 bits, and fold to u16. They do not protect
all padding/header/footer bytes or validate every nested record's semantics.
When the newer slot fails validation, an older valid slot is used. Two blank
slots yield EMPTY; no valid slot with a partially invalid slot yields ERROR.
A successful fallback reports OK without a separate degraded-slot indication.

Other known limitations remain separate tasks, documented and reproduced in the
[reviewed discovery](../work/reports/phase0-save-version-contract.md):

- A suffix-bearing buffer can decode successfully, but its noncanonical length
  prevents preserving the previous slot on the next encode.
- Sector counters are not required to agree; the final valid sector supplies
  the selected generation. This limitation also exists in pinned retail
  validation and is not an assumed parity defect.

`main.lua` writes the whole encoded buffer in one `love.filesystem.write` call
and advances in-memory save state only after reported success. Codec slot
fallback does **not** prove atomic disk replacement or interruption recovery.
Load refusal leaves the active session untouched and does not write the file,
but does not prevent a later explicit save from overwriting that filename.
The UI currently hides detailed string refusal reasons behind a generic error.
Filesystem failure safety, overwrite/diagnostic UX, stricter validation, retail
import and mod compatibility require separate work.

## Evidence

[Codec fixtures](../tests/save_file_codec_test.lua) independently construct a
40,968-byte version-1 buffer, assert the literal version-2 header and length,
and cover unknown/unwrapped refusal, truncation, all nine PC-sector corruption
fallbacks, ordinary payload corruption and normal state/PC roundtrips.
[Session roundtrip fixtures](../tests/save_load_roundtrip_test.lua) compare all
57,344 bytes of the preserved prior slot and verify the newer loaded position
and generation. Counter boundary fixtures inspect all fourteen serialized
footer counters, distinct saved content, both ordering predicates, ordinary
and equal-counter controls, corruption fallback, and load/resave continuity
through wrap. The new rollover assertions fail against the pre-correction
codec; exact evidence and independent review are tracked in the
[rollover task](../work/tasks/phase0-save-counter-rollover.md).
Reverse physical ordering is a synthetic project-decoder control, not a
claim that retail physical I/O ignores parity. No binary or user-save fixture
is needed.

Run `env -u POKEPORT_ROM lua5.1 tests/save_file_codec_test.lua`,
`env -u POKEPORT_ROM lua5.1 tests/save_load_roundtrip_test.lua`, and
`env -u POKEPORT_ROM bash scripts/test_all.sh`. These are no-ROM compatibility
checks, not filesystem failure-injection tests. Exact Worker results and the
independent-review gate are recorded in the
[bounded task](../work/tasks/phase0-save-version-contract.md).
