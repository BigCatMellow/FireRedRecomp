# Wild battle scene integration — completed 2026-08-13

## Landed scope

- A completed real tall-grass encounter now launches the existing bounded
  `BattleEngine` from `main.lua` instead of only printing species/level.
- `src/core/BattleSceneController.lua` keeps input/menu/message/HP-display
  state pure and consumes the engine's one-way event stream.
- FIGHT, the current direct move, and RUN are live. BAG and POKEMON report
  their bounded gap visibly. Win/run return to the field; loss explicitly
  reports that whiteout/healing is deferred.
- `import/BattleSceneAssets.lua` decodes the real grass battle terrain and
  real species front/back sprites + normal palettes from the verified ROM.
- Field movement, NPC ticking, view hotkeys, and interactions are frozen
  during battle. A warp step no longer also rolls the destination tile's
  encounter table.

## Real-source anchors

- `src/battle_setup.c`: `StartWildBattle`, `DoStandardWildBattle` field lock.
- `src/battle_controller_player.c`: `HandleInputChooseAction` and
  `HandleInputChooseMove` 2x2 cursor behavior.
- `src/battle_bg.c`: `sBattleTerrainTable[BATTLE_TERRAIN_GRASS]` and the
  screenSize=1 BG3/palette-slot layout.
- `src/battle_anim_mons.c`: single-battle player/opponent sprite positions.
- `src/battle_message.c`: appeared/go/used/run/effectiveness/faint wording.

## Intentional boundaries / next pickup

- Main has no persistent live party bridge yet. The battle currently uses a
  fresh Lv5 Bulbasaur with Tackle; the rolled wild species/level also uses
  Tackle. HP/PP do not persist and there is no XP/reward/capture/whiteout.
- Wild generation still omits `GenerateWildMon` personality/nature/IV/
  moveset RNG draws, so the correct shared RNG stream enters battle earlier
  than retail.
- Next high-value step is a real party/moveset bridge plus defeat XP/reward
  or capture; full transition, healthbox tile art, and move animations can
  remain presentation follow-ups.

## Verification

- `tests/battle_scene_controller_test.lua`: 17 pure checks.
- `tests/battle_scene_assets_test.lua`: 7 verified-ROM checks.
- Full verified-ROM suite: 95 test files, 0 failures.
- `main.lua` Lua 5.1 syntax and `git diff --check`: pass.
- Live xvfb/LÖVE screenshot: Pidgey Lv3 vs Bulbasaur Lv5 action menu with
  real ROM background, sprites, and font.

Changes intentionally left uncommitted for owner review.
