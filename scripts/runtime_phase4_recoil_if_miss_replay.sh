#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
: "${POKEPORT_ROM:?set POKEPORT_ROM to verified FireRed US v1.0}"
lua5.1 tests/battle_engine_test.lua
lua5.1 tests/battle_scene_controller_test.lua
lua5.1 tests/battle_party_bridge_test.lua
lua5.1 tests/phase4_move_effect_inventory_test.lua
lua5.1 tests/phase4_recoil_if_miss_effect_rom_test.lua
echo "RUNTIME_REPLAY phase4_recoil_if_miss PASS effect=45 moves=26,136 represented-singles=true explicit-party-persistence=true"
