#!/usr/bin/env bash
# Produce implementation-only Phase 2 evidence captures.  Files are written
# outside the repository and are deliberately not retail-reference media.
set -euo pipefail

repo_root=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

external_temp_dir() {
  # Deliberately ignore TMPDIR and all caller-selected output roots.  The
  # capture can contain ROM-derived implementation pixels, so it must be a
  # canonical /tmp sibling of (never a path inside) the working tree.
  local created canonical
  created=$(mktemp -d "/tmp/firered-recomp-phase2-${1}.XXXXXX")
  canonical=$(cd -P "$created" && pwd)
  case "$canonical" in
    /tmp/*) ;;
    *) echo "error: temporary capture root is not under canonical /tmp: $canonical" >&2; return 1 ;;
  esac
  case "$canonical" in
    "$repo_root"|"$repo_root"/*)
      echo "error: temporary capture root resolves inside repository: $canonical" >&2
      return 1
      ;;
  esac
  printf '%s\n' "$canonical"
}

: "${POKEPORT_ROM:?error: set POKEPORT_ROM to the verified FireRed US v1.0 ROM}"
expected_sha1=41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc
actual_sha1=$(sha1sum "$POKEPORT_ROM" | awk '{print $1}')
if [[ "$actual_sha1" != "$expected_sha1" ]]; then
  echo "error: POKEPORT_ROM SHA-1 is $actual_sha1, expected $expected_sha1" >&2
  exit 1
fi
for command in love xvfb-run timeout mktemp lua5.1 sha1sum; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "error: $command is required for Phase 2 evidence capture" >&2
    exit 127
  }
done

# Never accept a caller-selected output directory: captures can contain
# ROM-derived implementation pixels and must remain in canonical /tmp.
output_dir=$(external_temp_dir evidence)

capture_once() {
  local anchor=$1
  local ordinal=$2
  shift 2
  local sandbox_root
  sandbox_root=$(external_temp_dir capture)
  local expected="$sandbox_root/data/love/firered-recomp/screenshot.png"
  local output="$output_dir/${anchor}-${ordinal}.png"
  local log="$sandbox_root/runtime.log"
  # The sandbox root is newly created for exactly this invocation.  Refuse a
  # pre-existing path anyway, so the subsequent file check proves that this
  # run—not an earlier renderer attempt—created the evidence image.
  if [[ -e "$expected" ]]; then
    rm -rf -- "$sandbox_root"
    echo "error: $anchor capture target was not fresh" >&2
    exit 1
  fi
  local status=0
  if timeout 60s xvfb-run -a env ALSOFT_DRIVERS=null \
    XDG_DATA_HOME="$sandbox_root/data" XDG_CONFIG_HOME="$sandbox_root/config" \
    XDG_CACHE_HOME="$sandbox_root/cache" POKEPORT_ROM="$POKEPORT_ROM" \
    POKEPORT_CAPTURE_SURFACE=1 POKEPORT_SCREENSHOT=1 \
    POKEPORT_EVIDENCE_ANCHOR="$anchor" "$@" love . >"$log" 2>&1; then
    :
  else
    status=$?
  fi
  local marker="PHASE2_CAPTURE_SURFACE PASS anchor=$anchor dimensions=240x160"
  # Different supported LÖVE/Xvfb runners report love.event.quit(0) as either
  # 0 or 1.  Whitelist only those normal outcomes, and require this run's
  # canvas draw-completion marker and fresh image; a screenshot by itself can
  # be an earlier frame left after a renderer error.
  if [[ "$status" -ne 0 && "$status" -ne 1 ]] || [[ ! -f "$expected" || "$(<"$log")" != *"$marker"* ]]; then
    cat "$log" >&2 || true
    rm -rf -- "$sandbox_root"
    echo "error: $anchor capture failed (exit $status)" >&2
    exit 1
  fi
  mv -- "$expected" "$output"
  rm -rf -- "$sandbox_root"
  printf '%s\n' "$output"
}

oak_a=$(capture_once oak-static a POKEPORT_OAKSCENE=1)
oak_b=$(capture_once oak-static b POKEPORT_OAKSCENE=1)
pallet_a=$(capture_once pallet-camera-anchor a POKEPORT_MAP=3,0 POKEPORT_WALK=1)
pallet_b=$(capture_once pallet-camera-anchor b POKEPORT_MAP=3,0 POKEPORT_WALK=1)

for image in "$oak_a" "$oak_b" "$pallet_a" "$pallet_b"; do
  dimensions=$(lua5.1 - "$image" <<'LUA'
package.path = package.path .. ";./?.lua"
local PNG = require("tools.pixeldiff.png")
local image, err = PNG.decodeFile(arg[1])
assert(image, err)
assert(image.width == 240 and image.height == 160,
  ("expected 240x160, got %dx%d"):format(image.width, image.height))
print(image.width .. "x" .. image.height)
LUA
)
  printf 'CAPTURE anchor=%s dimensions=%s sha1=%s\n' "$(basename "$image" .png)" "$dimensions" "$(sha1sum "$image" | awk '{print $1}')"
done

lua5.1 tools/pixeldiff/main.lua "$oak_a" "$oak_b"
lua5.1 tools/pixeldiff/main.lua "$pallet_a" "$pallet_b"
printf 'PHASE2_EVIDENCE_CAPTURE PASS output_dir=%s anchors=oak-static,pallet-camera-anchor repeats=identical reference_input=absent\n' "$output_dir"
