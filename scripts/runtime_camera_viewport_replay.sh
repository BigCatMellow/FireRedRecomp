#!/usr/bin/env bash
# ROM-backed proof that the ordinary field renderer uses CameraViewport while
# a live PlayerMovement step scrolls an existing Route 1 map.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

: "${POKEPORT_ROM:?error: set POKEPORT_ROM to the verified FireRed US v1.0 ROM}"
for command in love xvfb-run timeout; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "error: $command is required for the Phase 2 camera runtime replay" >&2
    exit 127
  }
done

output=""
status=0
if output=$(timeout 60s xvfb-run -a env ALSOFT_DRIVERS=null \
  POKEPORT_ROM="$POKEPORT_ROM" POKEPORT_MAP=3,19 POKEPORT_WALK=1 \
  POKEPORT_RUNTIME_REPLAY=phase2_camera_viewport love . 2>&1); then
  :
else
  status=$?
fi
printf '%s\n' "$output"
if [[ "$output" != *"RUNTIME_REPLAY phase2_camera_viewport PASS"* ]]; then
  echo "error: Phase 2 camera viewport runtime replay failed (exit $status)" >&2
  exit 1
fi
echo "PASS: live Route 1 movement uses the 240x160 camera viewport"
