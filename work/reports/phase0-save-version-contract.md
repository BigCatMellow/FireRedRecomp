# Save-version contract discovery

- Task: `P0-02-DISCOVERY`.
- Status: `DISCOVERY COMPLETE — PENDING INDEPENDENT REVIEW`.
- Investigated checkout: `ef836a4`; runtime codec last changed at `103c5e1d5b7ad11d5408a2112d81437117a991c9`.
- Scope: read-only history/code and synthetic evidence; no user saves, runtime, production tests, migration policy, or phase status changed.

## Established schema history

`git log -- src/core/SaveFileCodec.lua` contains two revisions. The codec was
absent at `c01c95664e5100d078a35b3d01acf1b9a8c1c542`; its introduction at
`a01040eab9e8718efcd130b1e1860373439d5bef` already included the version wrapper.
The codec and SaveBlockLayout did not change between that introduction and
`068de087f67849a4468e940b35e7c83f1b90c63c`, the parent of `103c5e1`.

| Schema | Wrapper and physical allocation | Modelled state | Decoder policy |
| --- | --- | --- | --- |
| Version 1, `a01040e` through `068de087` | `FRSV`, one version byte `1`, three zero reserved bytes; two 20,480-byte slots; 40,968 total bytes | Five sectors per slot: SaveBlock2 and four SaveBlock1 chunks; no PokemonStorage sectors | Historical decoder accepts version 1; no migration framework |
| Version 2, `103c5e1` onward | Same eight-byte wrapper with version `2`; two 57,344-byte slots; 114,696 total bytes | Fourteen sectors per slot: the prior five plus nine PokemonStorage chunks | Current decoder accepts version 2 only and explicitly refuses version 1; no migration framework |

The historical decoder checks minimum total length before magic/version; the
current decoder checks magic, minimum header length, version, then minimum
total length. Both ignore a trailing suffix and require their own version.
Version 2 refuses a genuine version-1 buffer with a version-specific error,
before its smaller size could become a generic truncation error. There is no
recovered pre-wrapper codec schema or supported unversioned save reader.

Every sector is 4,096 bytes: 3,968 data bytes and 128 footer bytes. SaveBlock2
has 3,876 modelled structure bytes; SaveBlock1 occupies 15,720 bytes split
3,968/3,968/3,968/3,816; PokemonStorage adds 33,744 bytes split into eight
3,968-byte chunks plus 2,000. Version 2 encodes zero reserved/padding bytes,
fourteen fixed-position sectors in its target slot, and an unchanged other
slot only when given an exactly sized previous buffer. First encode uses
counter 1, slot 1; slot 0 starts blank. The next save uses counter 2, slot 0.

These are project containers using retail-derived sector structures, not retail
save-file import support. `SaveBlockLayout` remains a partial field model;
unmodelled fields are not losslessly preserved through decode/re-encode. Hall
of Fame/Trainer Tower and physical sector rotation remain excluded. The wrapper
contains no ROM identity or mod compatibility manifest. Version 2 adds the
14×30 boxed-record container, current-box byte, box names and wallpapers.
[Codec history](https://github.com/BigCatMellow/FireRedRecomp/commit/103c5e1d5b7ad11d5408a2112d81437117a991c9)
explicitly refuses version 1 instead of inventing missing PC data.

`PcBoxes.fromStorage` shares the state's `boxes` table; it is not a migration.
`GameSession.fromSavedState` can supply empty storage to a manually supplied
in-memory state, and the encoder accepts missing storage as empty. Neither
creates a supported disk migration: normal `loadGameFile` decodes/refuses the
file before invoking that constructor. See `main.lua:371`,
`src/core/PcBoxes.lua:46`, and `src/core/SaveFileCodec.lua:253` at `103c5e1`.

## Established code and test evidence

The following is **current behavior**, not a proposal to make every tolerance
a permanent compatibility guarantee. Code references are to the exact
[version-2 codec](https://github.com/BigCatMellow/FireRedRecomp/blob/103c5e1d5b7ad11d5408a2112d81437117a991c9/src/core/SaveFileCodec.lua).

| Boundary | Actual acceptance/refusal | Evidence and remaining limit |
| --- | --- | --- |
| Magic/header/version | `FRSV` required; recognized but fewer than eight bytes returns short-header error; only version 2 accepted | Lines 859–871; existing bad-magic/version-99 tests; synthetic genuine-v1, raw-sector, short-header refusal |
| Length/reserved bytes | Encoder emits exactly 114,696 bytes and three zero reserved bytes; decoder requires at least that length, ignores suffix and reserved-byte contents | Lines 825–842, 870–877; synthetic one-byte truncation refused, nonzero reserved bytes and suffix accepted |
| Sector identity/signature | Every fixed-position ID 0–13 and signature `0x08012025` must match; valid rotated sectors are outside this codec's contract | Lines 743–787; synthetic wrong ID or lost signature in the newest slot selects the older slot |
| Payload checksum | Add little-endian u32 words, wrap at 32 bits, fold high/low halves to u16, using the modelled chunk length | Lines 205–212, 764–766; existing arithmetic/payload fixtures; synthetic last PC-sector corruption falls back or returns ERROR when both copies fail |
| Unprotected bytes | Header, footer counter and data beyond the chunk's checksum extent are not covered by that checksum | Synthetic reserved-byte, counter, and SaveBlock2-padding mutations accepted; checksum validation is not semantic validation of all decoded fields or nested Pokemon checksums |
| Slot status/fallback | No recognized signature gives EMPTY; any signature with fewer than fourteen valid sectors gives ERROR; one valid slot wins; two EMPTY slots return EMPTY; no valid slot with any ERROR returns ERROR | Lines 781–899; existing newest/both-slot payload-corruption tests and synthetic blank-slot/PC-sector cases. A fallback success reports OK without separately telling the caller the other slot was bad |
| Counter consistency | Every valid sector overwrites the slot's counter; sector 13 wins in a fully valid slot; different generations are not rejected | Lines 768 and 891; synthetic first-sector counter 99 ignored, final-sector counter 99 accepted, old sector 1 spliced into a newer slot accepted as generation 2 |
| Counter order | Larger unsigned value wins; equal counters select slot 0; no rollover special case | Lines 885–891; synthetic rollover returns/stores different generation values and selects the stale pre-wrap save, detailed below |
| Previous-buffer preservation | Encoder copies old slots only at exact total length, without checking the old header/version/validity; wrong-length prior bytes are discarded | Lines 831–837; suffix-bearing input can decode successfully but its next encode loses the older fallback slot; an exactly sized bad-magic prior buffer is copied |

The mixed-generation result is a **demonstrated limitation**, not a demonstrated
retail divergence: pinned FireRed
[`GetSaveValidStatus`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/save.c#L466)
also records each valid sector's counter without requiring agreement. Strengthening
this rule would need a separate policy/design decision, not a presumed parity fix.

Rollover **is a reproduced divergence**. Starting with `previousCounter =
4294967294`, the first encode stores `4294967295` in slot 1. The next encode
returns `4294967296` and writes its low 32 bits, zero, to slot 0. Decode chooses
slot 1's stale data and reports `4294967295`. Pinned retail source explicitly
handles the `0xFFFFFFFF`/zero pair at
[`src/save.c:534`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/save.c#L534).
This is an observed edge case, not evidence of an ordinary low-counter failure.
The codec comments saying plain comparison suffices for every produced counter
and saying the counter comes from sector zero are inaccurate.

`main.lua:2425` encodes a complete buffer and writes it with a single
`love.filesystem.write`; only a reported success advances the in-memory counter
and prior bytes. `loadGameFile` at line 2445 returns on decode failure before
replacing the session. This separates in-memory slot validation from filesystem
write safety: no application-level temporary-file/rename/recovery protocol is
present here, and the existing roundtrip test does not exercise these I/O calls.
No atomic-write or interruption-recovery claim is established by codec tests.
The function rewrites the entire file; it does not perform retail flash's
physical write-only-one-slot operation. The other slot surviving inside a
completed memory buffer cannot prove its survival during interrupted file I/O.
No actual host failure or damaged user file was observed or simulated here.

Load rejection does not write the file and leaves the current session unchanged
by source inspection. The UI replaces string errors such as unsupported version
with generic `unreadable save data`, while EMPTY/ERROR statuses remain visible.
There is no persistent guard preventing a later explicit save of the current
session to the same filename after a failed load; refusal is not a backup system.
None of the focused tests invokes `saveGame`/`loadGameFile` with failing filesystem
operations. The codec's existing scratch-file test proves a normal roundtrip,
not failure atomicity or crash recovery.

Focused no-ROM tests already executed on the unchanged runtime:

- `PATH=/home/home/.local/share/firered-toolchain/bin:$PATH env -u POKEPORT_ROM lua5.1 tests/save_file_codec_test.lua`: **45 passed, 0 failed**.
- Same environment, `lua5.1 tests/save_load_roundtrip_test.lua`: **13 passed, 0 failed**.
- Existing baseline: 149 no-ROM test files passed before/after the preceding route-only configuration; no unrelated suite rerun for this report.

Existing codec fixtures cover normal dual-slot saves, current PC metadata,
bad magic, unknown version 99, newest-slot payload corruption with older-slot
fallback, both-slot corruption, and a scratch-file read/write. They do not
explicitly construct historical version-1 bytes. The roundtrip assertion at
`tests/save_load_roundtrip_test.lua:64` labelled preservation of the old slot
compares only the first five header bytes, not the previous slot.

## Synthetic characterization and reproducibility

Executed once successfully after the focused checks:

```sh
PATH=/home/home/.local/share/firered-toolchain/bin:$PATH env -u POKEPORT_ROM lua5.1 /tmp/firered-save-contract-HFR0o6/characterize.lua
```

Result: **24 characterization checks passed; generated bytes remained in memory**.
The temporary source has SHA-256
`e3940fc7ae6a2a0dd0220143cb14e0d2b98c3c32956ea95c2ac9ebb535c5276b`.
It loads the historical codec using `git show a01040e:src/core/SaveFileCodec.lua`
and `loadstring`; the relevant SaveBlockLayout was independently confirmed
unchanged. It encodes minimal states `{saveBlock1={money=N},saveBlock2={}}`;
no user save, ROM, or stored binary fixture is read. The required pre-existing
codec test separately used its own synthetic `/tmp` scratch-file fixture.

The table above records every category tested. To reproduce the most material
findings without the temporary harness, run this from the repo with Lua 5.1:

```lua
local C = require("src.core.SaveFileCodec")
local function state(n) return {saveBlock1={money=n},saveBlock2={}} end
local a, n = C.encode(state(11))
local b, m = C.encode(state(22), n, a)
local H, S, K = C.HEADER_SIZE, C.SLOT_BYTES, C.SECTOR_SIZE
local oldSector1 = a:sub(H+S+K+1, H+S+2*K)
local mixed = b:sub(1,H+K) .. oldSector1 .. b:sub(H+2*K+1)
local ds, info = C.decode(mixed)
assert(ds.saveBlock1.money == 11 and info.saveCounter == 2)
local suffix = b .. "suffix"
assert(C.decode(suffix))
local nextBytes = C.encode(state(33), m, suffix)
assert(nextBytes:sub(H+1,H+S) == string.rep("\0", S))
local last, high = C.encode(state(44), 4294967294)
local rolled, returned = C.encode(state(55), high, last)
local stale, selected = C.decode(rolled)
assert(returned == 4294967296 and selected.saveCounter == 4294967295)
assert(stale.saveBlock1.money == 44)
print("mixed-generation, suffix-preservation, rollover observations reproduced")
```

These are characterization assertions of known limitations, not proposed
production regression expectations that should prevent later authorized fixes.

## Stale prose and smallest proposed successor

`PARITY_CONTRACT.md:35` and `docs/handoffs/firered-recomp-checklist.md:89` still
say a project version must be added before the first layout change. Both
version 1 and the version-2 layout change already exist. The charter's explicit
migration-function requirement also differs from the implemented refusal-only
policy. The completed save-file handoff explicitly permitted migration **or
refusal**; this discovery preserves current version-1 refusal. Phase 3's checklist
line 220 correctly records the new PC sectors but its corruption-safe-write
heading must not be interpreted as proof of filesystem failure safety. The
capability checklist appropriately leaves the save-contract gate open.

Recommend exactly one immediate successor: **`P0-02-CONTRACT` — document the
existing version-2/refusal contract and add focused compatibility fixtures**.
Its bounded output should correct the charter/checklist's stale version claims,
document current output size and read tolerance separately, record the limitations
above, and add independent synthetic version-1 refusal, literal version-2/header/
size, truncation, full previous-slot preservation, and PC-sector corruption
fixtures to the existing codec/roundtrip tests. Preserve decoder behavior,
version numbers, version-1 refusal, and phase statuses. Do not require a migration
function for an unsupported legacy schema or write tests enshrining the known
rollover/suffix bugs as desired behavior. This successor establishes an explicit
compatibility statement; it does not resolve every save-safety gap.

Proposed explicit future contract, subject to independent review: supported
writes remain canonical version 2; supported loads remain the current reader's
version-2 domain; version 1, unknown versions, and unwrapped retail saves are
refused without conversion. No promise of lost PC-data reconstruction, universal
corruption detection, mod migration, or crash-safe disk writes is made. A future
schema change must explicitly choose its supported migrations or refusals and
preserve evidence for the previous schema; this report authorizes no change.

Separate later leaves, not bundled into that immediate successor:

- A source-locked counter-rollover correction with boundary fixtures: demonstrated
  stale selection and mismatch between the returned counter and encoded u32.
- A suffix/prior-buffer design: successful decode followed by exact-length-only
  preservation currently discards the previous fallback. Choose and review the
  intended acceptance/preservation rule before changing behavior.
- A bounded live-write safety design and filesystem failure-injection tests:
  current I/O has no demonstrated atomicity/recovery guarantee; also preserve
  useful refusal diagnostics and define overwrite protection separately.
- Optional mixed-generation or nested-record validation hardening would change
  acceptance, and requires its own policy/source justification.

The genuinely new human compatibility decision is whether to support version-1
migration despite absent PC data, and what any such data-loss/initialization
policy would mean. It is **not required** to retain the current refusal policy
or complete the proposed documentation/fixture successor. Stricter rejection of
currently tolerated files, retail import, mod migration, and recovery/overwrite
UX likewise require explicit future scope; none is silently selected here.

Independent review of this exact report remains required. No Phase 0 completion
or change to the separate private-runner blocker follows from this discovery.
