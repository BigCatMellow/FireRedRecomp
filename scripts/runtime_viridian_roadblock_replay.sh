#!/usr/bin/env bash
# Guarded deterministic runtime witness for the bounded Viridian City C0
# roadblock (work/tasks/phase5-viridian-roadblock-implementation.md). Runs
# main.lua's viridian_roadblock case headlessly against the verified ROM:
# fixture-backed C0 execution, not a fresh-save walk or northbound proof.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

: "${POKEPORT_ROM:?error: set POKEPORT_ROM to a verified FireRed US v1.0 ROM}"
for command in love xvfb-run timeout mktemp; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "error: ${command} is required for the Viridian roadblock runtime replay" >&2
    exit 127
  }
done

sandbox_root=$(mktemp -d "${TMPDIR:-/tmp}/firered-recomp-viridian-roadblock.XXXXXX")
trap 'rm -rf -- "$sandbox_root"' EXIT
mkdir -p "$sandbox_root/data" "$sandbox_root/config" "$sandbox_root/cache"

output=""
status=0
if output=$(timeout 60s xvfb-run -a env ALSOFT_DRIVERS=null \
  XDG_DATA_HOME="$sandbox_root/data" XDG_CONFIG_HOME="$sandbox_root/config" \
  XDG_CACHE_HOME="$sandbox_root/cache" POKEPORT_ROM="$POKEPORT_ROM" \
  POKEPORT_MAP=3,1 POKEPORT_WALK=1 \
  POKEPORT_RUNTIME_REPLAY=viridian_roadblock love . 2>&1); then
  :
else
  status=$?
fi
printf '%s\n' "$output"
if [[ "$status" -ne 0 || "$output" != *"RUNTIME_REPLAY viridian_roadblock PASS"* ]]; then
  echo "error: Viridian roadblock runtime replay failed (exit ${status})" >&2
  exit 1
fi
echo "PASS: fixture-backed Viridian C0 roadblock runtime replay"
