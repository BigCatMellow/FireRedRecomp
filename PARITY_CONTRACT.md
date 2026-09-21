# Parity Contract (Phase 0 charter)

Answers the roadmap's Phase 0 items 2–6. Update this file as decisions
change; it's the source of truth for "what does parity mean here."

## Supported ROM and revision policy

- Pokémon FireRed (US) v1.0 only, sha1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`.
- v1.1 (rev1) and LeafGreen are recognized-but-rejected for now (clear error
  message, see `import/RomImporter.lua`), not silently treated as unsupported
  garbage. They become real importer variants after FireRed v1.0 parity.
- No ROM is ever bundled, committed, or distributed by this project.

## What "parity" means

Observable in-game behavior matches retail FireRed (US) v1.0 from the
player's perspective: same text, same numbers, same map layouts, same
script outcomes, same battle results for the same inputs. It does **not**
mean byte-for-byte emulation of GBA hardware internals (memory-mapped I/O,
cycle timing, interrupt behavior) — the disassembly is a behavior/data
specification to port, not a CPU to emulate. See the roadmap's "What this is
—and is not" section.

## Behavior ledger

The maintained ledger is [`docs/behavior-ledger.md`](docs/behavior-ledger.md).
It links each player-visible subsystem to its FireRed source/data basis,
automated evidence, and live-wiring status. New parity claims must add or
update a row in that ledger.

## Save format versioning

`SaveFileCodec` writes project schema version 2 and explicitly refuses
version 1, unknown versions, and unwrapped saves. No automatic migration is
supported. The [save-format contract](docs/save-format.md) defines canonical
output, current decoder tolerance, historical shapes, and remaining safety
limits; codec slot fallback does not prove atomic filesystem writes.
Future save-layout changes must specify supported migrations or explicit
refusals, with deterministic evidence for any supported migration. Never use
best-effort field patching or invent missing legacy data.

## Contribution rules

- No ROMs, no GBA BIOS dumps, no extracted game assets (graphics, audio,
  text, maps, sprites) committed to this repository, ever. See `.gitignore`
  and the README's "No-ROM contribution rule."
- Every importer extraction that claims to read a FireRed data table must be
  cross-checked against the reference disassembly
  (`../Disassembled_Games/Classic/pokefirered-master`) before being trusted
  — this is a specification to diff against, not just a target function to
  call.
