#!/usr/bin/env bash
# Run every checked-in Lua test. Set POKEPORT_ROM to also exercise ROM-backed paths.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

if ! command -v lua5.1 >/dev/null 2>&1; then
  echo "error: lua5.1 is required (install the Lua 5.1 interpreter)" >&2
  exit 127
fi

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
