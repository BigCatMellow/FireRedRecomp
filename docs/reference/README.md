# FireRed ReComp Reference

This folder is the reference shelf for the native FireRed ReComp project. It
deliberately contains notes and pointers, not duplicated ROMs, BIOS files, or
disassembly trees.

The actual project lives at the repository root.

## Read first

1. [Roadmap](../roadmap.md) — the end-to-end build plan.
2. [Source inventory](source-inventory.md) — local source locations, what
   they provide, and how they fit the project.

## Core conclusion

FireRed ReComp should be a new sibling runtime to Gen1Recomp. Reuse the LÖVE
application shell, input, settings, mod infrastructure, logging, and test
patterns; build a new FireRed importer, 240×160 GBA renderer, Gen 3 battle
engine, map/script runtime, menus, audio layer, and save format.

## Current related deliverable

The independent FireRed battle-sprite mod is at:

`../standalone/definitive_firered_sprites/`

It is a useful asset/import experiment, but it is not the FireRed ReComp
runtime.
