#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
: "${POKEPORT_ROM:?set POKEPORT_ROM to verified FireRed US v1.0}"
lua5.1 tests/battle_engine_test.lua
lua5.1 tests/battle_scene_controller_test.lua
lua5.1 tests/phase4_pain_split_effect_rom_test.lua
echo "RUNTIME_REPLAY phase4_pain_split PASS effect=91 represented-state=true singles=true"
