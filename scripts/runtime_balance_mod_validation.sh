#!/usr/bin/env bash
# Proves the actual LÖVE process discovers and resolves the frozen balance mod.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"
: "${POKEPORT_ROM:?error: set POKEPORT_ROM to the verified FireRed US v1.0 ROM}"
for command in love xvfb-run timeout mktemp; do
  command -v "$command" >/dev/null 2>&1 || { echo "error: $command is required" >&2; exit 127; }
done

sandbox_root=$(mktemp -d "${TMPDIR:-/tmp}/firered-recomp-balance-mod.XXXXXX")
trap 'rm -rf -- "$sandbox_root"' EXIT
mkdir -p "$sandbox_root/data" "$sandbox_root/config" "$sandbox_root/cache"
status=0
if output=$(timeout 60s xvfb-run -a env ALSOFT_DRIVERS=null \
  XDG_DATA_HOME="$sandbox_root/data" XDG_CONFIG_HOME="$sandbox_root/config" \
  XDG_CACHE_HOME="$sandbox_root/cache" POKEPORT_ROM="$POKEPORT_ROM" \
  POKEPORT_RUNTIME_REPLAY=route1_wild_defeat POKEPORT_BALANCE_MOD_PROBE=1 \
  love . 2>&1); then :; else status=$?; fi
printf '%s\n' "$output"
[[ "$output" == *RUNTIME_BALANCE_MOD* ]] || { echo "error: balance mod probe did not pass (exit $status)" >&2; exit 1; }
[[ "$output" == *RUNTIME_REPLAY*route1_wild_defeat*PASS* ]] || { echo "error: route replay did not pass (exit $status)" >&2; exit 1; }
echo "PASS: actual LÖVE runtime loaded frozen balance mod"
