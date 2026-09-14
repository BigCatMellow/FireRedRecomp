#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
: "${POKEPORT_ROM:?set POKEPORT_ROM to verified FireRed US v1.0}"

lua5.1 tests/battle_engine_test.lua
lua5.1 tests/phase4_fixed_damage_effect_rom_test.lua
echo "RUNTIME_REPLAY phase4_fixed_damage PASS dragon-rage=40 level=attacker-level sonicboom=20 immunity=true no-crit-random=true nikolas204=true"
