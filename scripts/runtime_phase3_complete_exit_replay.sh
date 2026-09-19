#!/usr/bin/env bash
# One normal-boot Phase 3 route followed by a fresh-process normal load.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

: "${POKEPORT_ROM:?error: set POKEPORT_ROM to a verified FireRed US v1.0 ROM}"
for command in love xvfb-run timeout mktemp; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "error: ${command} is required for the complete Phase 3 replay" >&2
    exit 127
  }
done

sandbox_root=$(mktemp -d "${TMPDIR:-/tmp}/firered-recomp-phase3-complete.XXXXXX")
trap 'rm -rf -- "$sandbox_root"' EXIT
mkdir -p "$sandbox_root/data" "$sandbox_root/config" "$sandbox_root/cache"
save_file="$sandbox_root/data/love/firered-recomp/firered_recomp.sav"

run_replay() {
  local replay_case=$1
  shift
  local output status=0 expected_marker
  if output=$(timeout 60s xvfb-run -a env ALSOFT_DRIVERS=null \
    XDG_DATA_HOME="$sandbox_root/data" XDG_CONFIG_HOME="$sandbox_root/config" \
    XDG_CACHE_HOME="$sandbox_root/cache" POKEPORT_ROM="$POKEPORT_ROM" \
    POKEPORT_RNG_SEED=0 POKEPORT_TITLE=1 POKEPORT_RUNTIME_REPLAY="$replay_case" love . 2>&1); then
    :
  else
    status=$?
  fi
  printf '%s\n' "$output"
  for expected_marker in "$@"; do
    [[ "$output" == *"$expected_marker"* ]] || {
      echo "error: ${replay_case} did not produce ${expected_marker} (exit ${status})" >&2
      return 1
    }
  done
}

run_replay phase3_complete_exit_save \
  "RUNTIME_REPLAY phase3_complete_exit_save PASS" \
  "identity=RED/GREEN/0"
[[ -s "$save_file" ]] || { echo "error: normal save callback did not produce an isolated save file" >&2; exit 1; }
run_replay restart_load \
  "RUNTIME_REPLAY restart_load PASS" \
  "identity=RED/GREEN/0"
echo "RUNTIME_REPLAY phase3_complete_exit PASS title=true oak=true identity=asserted bedroom=true pallet=true route1=true wild=playerLost money=2960 hp=recovered saved=true reload=true party=1"
