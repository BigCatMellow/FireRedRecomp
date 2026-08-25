# FireRed ReComp behavior ledger

This is the evidence index for claims of parity. A subsystem is not complete
merely because it has code: it needs a source/data basis, automated evidence,
and a reachable runtime path where applicable. Add a row whenever a subsystem
becomes player-visible; do not silently replace the source basis with a
convenient approximation.

| Runtime subsystem | Reference basis | Automated evidence | Runtime status |
| --- | --- | --- | --- |
| ROM identity and import boundary | FireRed US v1.0 SHA-1; `RomImporter.lua` and `RomAddresses.lua` citations | `tests/rom_importer_test.lua` | Wired at boot |
| Species, moves, types, items, trainers | ROM tables decoded by `import/`; table layouts cited in importer headers | `tests/species_integration_test.lua`, `tests/full_sweep_validation_test.lua` | Wired to viewer, battles, and menus |
| Map data and rendering | ROM map headers, layouts, tilesets, events, and connections | `tests/map_*_test.lua`, `tests/map_generalization_test.lua` | Playable map/camera path |
| Script execution | FireRed script-bytecode formats and opcode semantics | `tests/script_interpreter*_test.lua`, `tests/map_scripts_test.lua` | Partial; unsupported opcodes must remain explicit |
| Wild encounters and capture persistence | FireRed encounter tables and party/PC routing rules | `tests/wild_*_test.lua`, `tests/capture_rewards_test.lua`, `tests/phase3_exit_path_rom_test.lua` | Wild battle and catch path wired; PC overflow remains incomplete |
| Tutorial trainer battle | Oak's Lab scripts, trainer data, and early-rival rules | `tests/early_rival_battle_test.lua`, `tests/early_story*_test.lua` | Bounded live slice only |
| Saving and loading | FireRed dual-slot sector/checksum behavior | `tests/save_file_codec_test.lua`, `tests/save_load_roundtrip_test.lua` | Hotkey UI; incomplete sectors are documented |
| Rendering, input, and scenes | GBA display/OAM/task behavior where ported | `tests/title_screen*_test.lua`, `tests/object_sprite*_test.lua`, `tests/viewport_scale_test.lua` | Partial; see Phase 2 exit criterion |

The canonical phase status is [work/roadmaps/CAPABILITY_CHECKLIST.md](../work/roadmaps/CAPABILITY_CHECKLIST.md).
