#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
: "${POKEPORT_ROM:?set POKEPORT_ROM to verified FireRed US v1.0}"
lua5.1 tests/battle_engine_test.lua
lua5.1 tests/battle_scene_controller_test.lua
lua5.1 tests/phase4_move_effect_inventory_test.lua
lua5.1 tests/phase4_restore_hp_effect_rom_test.lua
echo "RUNTIME_REPLAY phase4_restore_hp PASS effect=32 moves=105,303 represented-state=true singles=true"
