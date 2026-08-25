#!/usr/bin/env bash
# Opt-in LÖVE smoke check for the real fixed-tick/input/warp runtime path.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

: "${POKEPORT_ROM:?error: set POKEPORT_ROM to a verified FireRed US v1.0 ROM}"
for command in love xvfb-run timeout; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "error: ${command} is required for the runtime replay smoke check" >&2
    exit 127
  }
done

replay_status=0
if replay_output=$(timeout 20s xvfb-run -a env ALSOFT_DRIVERS=null \
  POKEPORT_ROM="$POKEPORT_ROM" POKEPORT_RUNTIME_REPLAY=house_to_pallet love . 2>&1); then
  :
else
  replay_status=$?
fi

printf '%s\n' "$replay_output"
if [[ "$replay_output" != *"RUNTIME_REPLAY house_to_pallet PASS map=768"* ]]; then
  echo "error: runtime replay did not produce its canonical pass marker (exit ${replay_status})" >&2
  if [[ "$replay_status" -eq 0 ]]; then exit 1; fi
  exit "$replay_status"
fi
