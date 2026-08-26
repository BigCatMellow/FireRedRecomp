# Task: canonical Viridian Mart Parcel and Dex progression

## Contract

- Owner: project maintainer
- Source of truth: FireRed `data/maps/ViridianCity_Mart/scripts.inc`,
  `data/maps/PalletTown_ProfessorOaksLab/scripts.inc`, and
  `include/constants/{vars,flags,items}.h`
- Output boundary: the first-Mart Parcel scene and the resulting return-to-Lab
  Dex progression only; no generic all-map script engine claim
- Authority: preserve the runnable current-runtime Mart purchase/capture
  replay while adding canonical story progression behind separately tested
  behavior

## Reference state transitions

1. On entry to Viridian City Mart, the `ON_FRAME_TABLE` entry for
   `VAR_MAP_SCENE_VIRIDIAN_CITY_MART` (`0x4057`) equal to `0` starts
   `ViridianCity_Mart_EventScript_ParcelScene`.
2. That scene locks field input, moves the clerk and player to the counter,
   presents its Parcel messages, sets Mart scene `0 -> 1`, grants
   `ITEM_OAKS_PARCEL` (`349`), and sets
   `VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB` (`0x4055`) to `5`.
3. The Mart clerk's normal `pokemart` branch is therefore unavailable at
   scene `0`; at scene `1` it says to take the Parcel to Oak instead.
4. Returning to Oak's Lab with Mart scene at least `1` enters the Dex scene:
   it consumes Oak's Parcel, sets `FLAG_SYS_POKEDEX_GET` (`0x829`), grants
   five Poké Balls, then sets Lab scene to `6` and Mart scene `1 -> 2`.

## Current boundary

`scripts/runtime_natural_capture_replay.sh` is runnable current-runtime
evidence, but is not canonical retail progression: it reaches the ordinary
clerk/shop path without executing Mart scene `0 -> 1`, Lab scene `5`, or the
Parcel -> Dex -> Mart scene `2` transition.

The existing generic decode cannot run this scene faithfully yet: the Mart
on-frame script stops at `textcolor` (`0xc7`), the on-load script stops at
`setmetatile` (`0xa2`), and the Parcel path requires asynchronous
`applymovement`/`waitmovement`, item-grant presentation, and persistent
scene-variable updates. Do not silently treat those opcodes as no-ops.

## Non-goals

- Full map-script scheduling for every `MAP_SCRIPT_*` hook.
- General movement-script, metatile, fanfare, or item-reward systems.
- Reworking the existing Mart UI, wild capture, or save codec.
- Claiming a canonical title/Oak-intro path.

## Implementation options

1. Add a deliberately bounded first-Mart scene driver that dispatches only
   the verified `ON_FRAME_TABLE` condition and models each listed transition,
   movement wait, message, and item grant with explicit tests.
2. First extend the generic script runtime with a small asynchronous command
   contract (`textcolor`, movement/wait, item grant, scene vars), but retain a
   strict unsupported-opcode failure and prove the Mart scripts before
   advertising broader map-script support.

Option 2 is preferable only if its contracts are independently testable; it
must not turn unsupported commands into successful no-ops.

## Acceptance tests

1. ROM-backed test resolves the real Mart `ON_FRAME_TABLE` entry and proves
   scene `0` selects the Parcel script, while scene `1` does not.
2. A live replay entering the Mart at scene `0` completes the visible Parcel
   scene and persists Parcel ownership, Mart scene `1`, and Lab scene `5`.
3. A live return-to-Lab replay consumes the Parcel, grants the Dex and five
   Poké Balls, and persists Lab scene `6` and Mart scene `2` through save and
   fresh-process load.
4. The ordinary Mart clerk remains inaccessible as a shop at scene `0`, is
   still non-shop at scene `1`, and reaches its real `pokemart` branch only
   after scene `2`.
5. `POKEPORT_ROM=/path/to/pokefirered.gba bash scripts/test_all.sh` passes.

