#!/usr/bin/env bash
# Two-process LÖVE save/restart gate. Every LÖVE write is redirected to a
# fresh temporary XDG sandbox, so it never reads or changes a user's normal
# firered-recomp save directory.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

: "${POKEPORT_ROM:?error: set POKEPORT_ROM to a verified FireRed US v1.0 ROM}"
for command in love xvfb-run timeout mktemp; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "error: ${command} is required for the runtime save/restart gate" >&2
    exit 127
  }
done

sandbox_root=$(mktemp -d "${TMPDIR:-/tmp}/firered-recomp-save-replay.XXXXXX")
trap 'rm -rf -- "$sandbox_root"' EXIT
mkdir -p "$sandbox_root/data" "$sandbox_root/config" "$sandbox_root/cache"
save_file="$sandbox_root/data/love/firered-recomp/firered_recomp.sav"
case "$save_file" in
  "$sandbox_root"/*) ;;
  *) echo "error: invalid runtime save target" >&2; exit 1 ;;
esac

run_replay() {
  local replay_case=$1
  local expected_marker=$2
  local replay_output replay_status=0
  if replay_output=$(timeout 20s xvfb-run -a env ALSOFT_DRIVERS=null \
    XDG_DATA_HOME="$sandbox_root/data" XDG_CONFIG_HOME="$sandbox_root/config" \
    XDG_CACHE_HOME="$sandbox_root/cache" POKEPORT_ROM="$POKEPORT_ROM" \
    POKEPORT_RNG_SEED=0 POKEPORT_RUNTIME_REPLAY="$replay_case" love . 2>&1); then
    :
  else
    replay_status=$?
  fi
  printf '%s\n' "$replay_output"
  if [[ "$replay_output" != *"$expected_marker"* ]]; then
    echo "error: ${replay_case} did not produce ${expected_marker} (exit ${replay_status})" >&2
    return 1
  fi
}

run_replay route1_wild_defeat_save "RUNTIME_REPLAY route1_wild_defeat_save PASS"
if [[ ! -s "$save_file" ]]; then
  echo "error: expected non-empty save was not written inside the temporary sandbox" >&2
  exit 1
fi
run_replay restart_load "RUNTIME_REPLAY restart_load PASS"
echo "PASS: isolated two-process LÖVE save/restart replay"
