#!/usr/bin/env bash
# Deterministic non-gameplay coverage for Local Worker Bridge patch validation.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
validator="$repo_root/scripts/validate_local_worker_bridge_patch_targets.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

check_rejected() {
  local name="$1"
  local patch="$2"
  local expected="$3"
  if PATCH_FILE="$patch" ROUTE=phase3-complete-runtime-exit-replay bash "$validator" >"$tmpdir/$name.out" 2>"$tmpdir/$name.err"; then
    echo "FAIL: $name was accepted" >&2
    exit 1
  fi
  grep -F "$expected" "$tmpdir/$name.err" >/dev/null
}

allowed="$tmpdir/allowed-mode-only.patch"
printf '%s\n' \
  'diff --git a/main.lua b/main.lua' \
  'old mode 100644' \
  'new mode 100755' > "$allowed"
PATCH_FILE="$allowed" ROUTE=phase3-complete-runtime-exit-replay bash "$validator"

unauthorized_mode="$tmpdir/unauthorized-mode-only.patch"
printf '%s\n' \
  'diff --git a/.github/workflows/local-worker-bridge.yml b/.github/workflows/local-worker-bridge.yml' \
  'old mode 100644' \
  'new mode 100755' > "$unauthorized_mode"
check_rejected unauthorized-mode "$unauthorized_mode" 'Patch target is not authorized'

unauthorized_source="$tmpdir/unauthorized-source.patch"
printf '%s\n' \
  'diff --git a/.github/workflows/local-worker-bridge.yml b/main.lua' \
  'old mode 100644' \
  'new mode 100755' > "$unauthorized_source"
check_rejected unauthorized-source "$unauthorized_source" 'Patch target is not authorized'

malformed="$tmpdir/malformed.patch"
printf '%s\n' 'diff --git a/main.lua' > "$malformed"
check_rejected malformed "$malformed" 'Malformed or unparseable diff header'

echo 'PASS: Local Worker Bridge validates both diff --git paths and rejects unauthorized mode-only targets.'
