#!/usr/bin/env bash
# Run every checked-in Lua test. Set POKEPORT_ROM to also exercise ROM-backed paths.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

if ! command -v lua5.1 >/dev/null 2>&1; then
  echo "error: lua5.1 is required (install the Lua 5.1 interpreter)" >&2
  exit 127
fi
if ! command -v luac5.1 >/dev/null 2>&1; then
  echo "error: luac5.1 is required (install the Lua 5.1 compiler)" >&2
  exit 127
fi

# Tests exercise pure modules, but the live LÖVE entrypoint can still exceed
# Lua 5.1's main-chunk local limit. Compile it in every CI/local suite.
luac5.1 -p main.lua

count=0
for test_file in tests/*_test.lua; do
  lua5.1 "$test_file"
  count=$((count + 1))
done

if [[ -n "${POKEPORT_ROM:-}" ]]; then
  echo "PASS: ${count} test files (ROM mode: ${POKEPORT_ROM})"
else
  echo "PASS: ${count} test files (no-ROM mode; ROM-dependent checks skip cleanly)"
fi

if [[ "${POKEPORT_RUNTIME_REPLAY:-}" == "1" ]]; then
  bash scripts/runtime_replay_smoke.sh
fi
