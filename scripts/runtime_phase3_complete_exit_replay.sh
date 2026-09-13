#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"
: "${POKEPORT_ROM:?set POKEPORT_ROM to the verified FireRed US v1.0 ROM}"
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/firered-phase3-complete.XXXXXX")
trap 'rm -rf -- "$sandbox"' EXIT
run() {
  local route=$1 expected=$2 output status=0
  if output=$(timeout 60s xvfb-run -a env ALSOFT_DRIVERS=null XDG_DATA_HOME="$sandbox/data" XDG_CONFIG_HOME="$sandbox/config" XDG_CACHE_HOME="$sandbox/cache" POKEPORT_ROM="$POKEPORT_ROM" POKEPORT_TITLE=1 POKEPORT_RNG_SEED=0 POKEPORT_RUNTIME_REPLAY="$route" love . 2>&1); then :; else status=$?; fi
  printf '%s\n' "$output"
  [[ "$output" == *"$expected"* ]] || { echo "missing $expected (exit $status)" >&2; return 1; }
}
run phase3_complete_runtime_exit_save 'RUNTIME_REPLAY phase3_complete_runtime_exit_save PASS'
test -s "$sandbox/data/love/firered-recomp/firered_recomp.sav"
run restart_load 'RUNTIME_REPLAY restart_load PASS'
echo 'PASS: continuous Phase 3 runtime exit replay'
