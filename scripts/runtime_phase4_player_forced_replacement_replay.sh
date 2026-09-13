#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
: "${POKEPORT_ROM:?set POKEPORT_ROM to verified FireRed US v1.0}"
lua5.1 tests/phase4_player_forced_replacement_controller_test.lua
lua5.1 tests/phase4_player_forced_replacement_rom_test.lua
echo "RUNTIME_REPLAY phase4_player_forced_replacement PASS trainer-only=true forced-party=true outgoing-hp-persisted=true live-slot-synced=true save-roundtrip=true"
