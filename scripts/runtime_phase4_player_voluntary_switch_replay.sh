#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
: "${POKEPORT_ROM:?set POKEPORT_ROM to verified FireRed US v1.0}"
lua5.1 tests/phase4_player_voluntary_switch_controller_test.lua
lua5.1 tests/phase4_player_voluntary_switch_rom_test.lua
echo "RUNTIME_REPLAY phase4_player_voluntary_switch PASS trainer-only=true ben89=true cancel=true stale-rejected=true switch-before-foe=true save-roundtrip=true forced-cancel-proof=true"
