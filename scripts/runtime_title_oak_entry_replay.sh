#!/usr/bin/env bash
# Deterministic runtime proof for title -> Oak -> identity -> fresh bedroom.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

: "${POKEPORT_ROM:?error: set POKEPORT_ROM to a verified FireRed US v1.0 ROM}"
for command in love xvfb-run timeout mktemp; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "error: ${command} is required for the title/Oak runtime replay" >&2
    exit 127
  }
done

sandbox_root=$(mktemp -d "${TMPDIR:-/tmp}/firered-recomp-title-oak.XXXXXX")
trap 'rm -rf -- "$sandbox_root"' EXIT
mkdir -p "$sandbox_root/data" "$sandbox_root/config" "$sandbox_root/cache"

output=""
status=0
if output=$(timeout 60s xvfb-run -a env ALSOFT_DRIVERS=null \
  XDG_DATA_HOME="$sandbox_root/data" XDG_CONFIG_HOME="$sandbox_root/config" \
  XDG_CACHE_HOME="$sandbox_root/cache" POKEPORT_ROM="$POKEPORT_ROM" \
  POKEPORT_TITLE=1 POKEPORT_RUNTIME_REPLAY=title_oak_entry love . 2>&1); then
  :
else
  status=$?
fi
printf '%s\n' "$output"
if [[ "$status" -ne 0 || "$output" != *"RUNTIME_REPLAY title_oak_entry PASS"* ]]; then
  echo "error: title/Oak runtime replay failed (exit ${status})" >&2
  exit 1
fi
echo "PASS: current-runtime title -> Oak -> identity -> fresh bedroom replay"
