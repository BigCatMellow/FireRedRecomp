#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
: "${POKEPORT_ROM:?set POKEPORT_ROM to verified FireRed US v1.0}"
lua5.1 tests/phase4_foe_only_multimon_controller_test.lua
lua5.1 tests/phase4_foe_only_multimon_rom_test.lua
echo "RUNTIME_REPLAY phase4_foe_only_multimon PASS main-start=true ordered-foe-replacement=true per-foe-settlement=true final-flag-gate=true"
