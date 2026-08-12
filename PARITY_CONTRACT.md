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

Not started. Will link each runtime subsystem (importer, renderer, script
VM, battle engine, map runtime, save system) to the FireRed source
files/data it's derived from and the automated check that guards it. Starts
in Phase 1 alongside the first schemas.

## Save format versioning

Not started — no save format exists yet. When Phase 3 introduces one: every
save is tagged with a schema version from the first save this project ever
writes, and migrations between versions are explicit functions, not
best-effort field patching.

## Contribution rules

- No ROMs, no GBA BIOS dumps, no extracted game assets (graphics, audio,
  text, maps, sprites) committed to this repository, ever. See `.gitignore`
  and the README's "No-ROM contribution rule."
- Every importer extraction that claims to read a FireRed data table must be
  cross-checked against the reference disassembly
  (`../Disassembled_Games/Classic/pokefirered-master`) before being trusted
  — this is a specification to diff against, not just a target function to
  call.
