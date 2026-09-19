#!/usr/bin/env bash
# Deterministic non-gameplay coverage for Local Worker Bridge patch validation.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
validator="$repo_root/scripts/validate_local_worker_bridge_patch_targets.sh"
cd "$repo_root"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
fake_git_dir="$tmpdir/fake-git"
mkdir "$fake_git_dir"
printf '%s\n' '#!/usr/bin/env bash' 'echo "FAIL: git apply --check was reached" >&2' 'exit 1' > "$fake_git_dir/git"
chmod +x "$fake_git_dir/git"

check_rejected() {
  local name="$1"
  local patch="$2"
  local expected="$3"
  if PATH="$fake_git_dir:$PATH" PATCH_FILE="$patch" ROUTE=phase3-complete-runtime-exit-replay bash "$validator" >"$tmpdir/$name.out" 2>"$tmpdir/$name.err"; then
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

unallowlisted_marker="$tmpdir/unallowlisted-marker.patch"
printf '%s\n' \
  'diff --git a/main.lua b/main.lua' \
  '--- a/.github/workflows/local-worker-bridge.yml' \
  '+++ b/.github/workflows/local-worker-bridge.yml' \
  '@@ -1,4 +1,4 @@' \
  '-name: Local Worker Bridge' \
  '+name: Unallowlisted marker bypass' \
  ' ' \
  ' on:' \
  '   push:' > "$unallowlisted_marker"
git apply --check "$unallowlisted_marker"
check_rejected unallowlisted-marker "$unallowlisted_marker" 'Patch target is not authorized'

allowed_lua_comment="$tmpdir/allowed-lua-comment.patch"
printf '%s\n' \
  'diff --git a/main.lua b/main.lua' \
  '--- a/main.lua' \
  '+++ b/main.lua' \
  '@@ -1,2 +1,2 @@' \
  '--- Phase 1+2 shell: boots a window, verifies a ROM if POKEPORT_ROM points at' \
  '+-- Phase 1+2 shell: boots a window, verifies a ROM if POKEPORT_ROM points at [bridge parser test]' \
  ' -- one, composites a real map into an image and draws it (defaults to' > "$allowed_lua_comment"
git apply --check "$allowed_lua_comment"
PATCH_FILE="$allowed_lua_comment" ROUTE=phase3-complete-runtime-exit-replay bash "$validator"

echo 'PASS: Local Worker Bridge validates actionable file markers and accepts Lua deletion content before git apply.'
