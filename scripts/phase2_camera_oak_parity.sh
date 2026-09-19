#!/usr/bin/env bash
# Capture and compare the three Phase 2 camera/Oak cases without storing any
# ROM-derived pixels in the repository. All reference paths are explicit and
# the checker preflights them before this script opens the private ROM.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

manifest=""
reference_dir=""
result=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest) manifest=${2:?missing manifest path}; shift 2 ;;
    --reference-dir) reference_dir=${2:?missing reference directory}; shift 2 ;;
    --result) result=${2:?missing result path}; shift 2 ;;
    *) echo "usage: $0 --manifest FILE --reference-dir DIR --result RESULT.json" >&2; exit 2 ;;
  esac
done
[[ -n "$manifest" && -n "$reference_dir" && -n "$result" ]] || { echo "all arguments are required" >&2; exit 2; }

for command in lua5.1 love xvfb-run timeout mktemp; do
  command -v "$command" >/dev/null 2>&1 || { echo "error: $command is required" >&2; exit 127; }
done

# Fail closed before capture/comparison if the externally supplied corpus is
# absent, malformed, wrong-sized, or altered. This creates a machine-readable
# BLOCKED/FAIL result at the caller-provided result path.
lua5.1 tools/phase2_camera_oak_parity_check.lua --manifest "$manifest" \
  --reference-dir "$reference_dir" --result "$result" --preflight

: "${POKEPORT_ROM:?error: set POKEPORT_ROM to the verified private FireRed US v1.0 ROM}"
sandbox_root=$(mktemp -d "${TMPDIR:-/tmp}/firered-recomp-phase2-parity.XXXXXX")
trap 'rm -rf -- "$sandbox_root"' EXIT
capture_dir="$sandbox_root/captures"
mkdir -p "$capture_dir"

capture_case() {
  local case_id=$1
  local moves=${2:-}
  local run_root="$sandbox_root/$case_id"
  mkdir -p "$run_root/data" "$run_root/config" "$run_root/cache"
  local -a env_args=(
    ALSOFT_DRIVERS=null XDG_DATA_HOME="$run_root/data" XDG_CONFIG_HOME="$run_root/config" XDG_CACHE_HOME="$run_root/cache"
    POKEPORT_ROM="$POKEPORT_ROM" POKEPORT_CAPTURE_240=1 POKEPORT_SCREENSHOT=1
  )
  if [[ "$case_id" == "oak_static" ]]; then
    env_args+=(POKEPORT_OAKSCENE=1)
  else
    env_args+=(POKEPORT_MAP=3,0 POKEPORT_WALK=1)
    env_args+=(POKEPORT_CAMERA_CAPTURE_CASE="$case_id")
    [[ -n "$moves" ]] && env_args+=(POKEPORT_WALK_MOVES="$moves")
  fi
  timeout 60s xvfb-run -a env "${env_args[@]}" love . >"$run_root/runtime.log" 2>&1
  local screenshot="$run_root/data/love/firered-recomp/screenshot.png"
  [[ -f "$screenshot" ]] || { echo "error: $case_id did not produce screenshot.png" >&2; return 1; }
  [[ "$case_id" == "oak_static" || $(<"$run_root/runtime.log") == *"POKEPORT_CAMERA_CAPTURE case=$case_id relation="* ]] || {
    echo "error: $case_id did not prove its requested camera relation" >&2; return 1;
  }
  cp "$screenshot" "$capture_dir/$case_id.png"
}

capture_case oak_static ""
capture_case pallet_edge_clamped ""
capture_case pallet_centered "down,down,down,down"

lua5.1 tools/phase2_camera_oak_parity_check.lua --manifest "$manifest" \
  --project-dir "$capture_dir" --reference-dir "$reference_dir" --result "$result"
