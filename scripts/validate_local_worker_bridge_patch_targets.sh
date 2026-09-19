#!/usr/bin/env bash
# Validate every git diff header before the Local Worker Bridge applies a patch.
set -euo pipefail

: "${PATCH_FILE:?PATCH_FILE is required}"
: "${ROUTE:?ROUTE is required}"
test -s "$PATCH_FILE"

headers=0
pending_old_marker=''

validate_target() {
  local target="$1"
  case "$ROUTE:$target" in
    oak-parcel-dex-presentation-north:main.lua|oak-parcel-dex-presentation-north:src/core/OakParcelDexPresentation.lua|oak-parcel-dex-presentation-north:tests/oak_parcel_dex_presentation_test.lua|oak-parcel-dex-presentation-north:scripts/runtime_natural_capture_replay.sh|oak-parcel-dex-presentation-north:work/tasks/oak-parcel-dex-presentation-north.md)
      ;;
    phase3-title-oak-entry-proof:main.lua|phase3-title-oak-entry-proof:tests/phase3_title_oak_entry_test.lua|phase3-title-oak-entry-proof:scripts/runtime_title_oak_entry_replay.sh|phase3-title-oak-entry-proof:work/tasks/phase3-title-oak-entry-proof.md|phase3-title-oak-entry-proof:work/tasks/phase3-exit-proof.md)
      ;;
    phase3-complete-runtime-exit-replay:main.lua|phase3-complete-runtime-exit-replay:tests/phase3_complete_runtime_exit_replay_test.lua|phase3-complete-runtime-exit-replay:scripts/runtime_phase3_complete_exit_replay.sh|phase3-complete-runtime-exit-replay:work/tasks/phase3-complete-runtime-exit-replay.md|phase3-complete-runtime-exit-replay:work/tasks/phase3-exit-proof.md)
      ;;
    *)
      echo "Patch target is not authorized for explicit route '$ROUTE': $target" >&2
      exit 1
      ;;
  esac
}

while IFS= read -r header || [ -n "$header" ]; do
  case "$header" in
    'diff --git '*)
      headers=$((headers + 1))
      if [[ ! "$header" =~ ^diff\ --git\ a/([^[:space:]]+)\ b/([^[:space:]]+)$ ]]; then
        echo "Malformed or unparseable diff header: $header" >&2
        exit 1
      fi
      for target in "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"; do
        validate_target "$target"
      done
      ;;
    'diff --git')
      echo "Malformed or unparseable diff header: $header" >&2
      exit 1
      ;;
    '--- '*)
      if [ -n "$pending_old_marker" ]; then
        echo "Malformed or unpaired old file marker: $header" >&2
        exit 1
      fi
      if [[ ! "$header" =~ ^---\ (a/([^[:space:]]+)|/dev/null)([[:space:]].*)?$ ]]; then
        echo "Malformed or unparseable old file marker: $header" >&2
        exit 1
      fi
      if [ "${BASH_REMATCH[1]}" = '/dev/null' ]; then
        pending_old_marker='/dev/null'
      else
        pending_old_marker="${BASH_REMATCH[2]}"
        validate_target "$pending_old_marker"
      fi
      ;;
    '+++ '*)
      if [ -z "$pending_old_marker" ]; then
        echo "Malformed or unpaired new file marker: $header" >&2
        exit 1
      fi
      if [[ ! "$header" =~ ^\+\+\+\ (b/([^[:space:]]+)|/dev/null)([[:space:]].*)?$ ]]; then
        echo "Malformed or unparseable new file marker: $header" >&2
        exit 1
      fi
      if [ "$pending_old_marker" = '/dev/null' ] && [ "${BASH_REMATCH[1]}" = '/dev/null' ]; then
        echo "Malformed creation/deletion markers: both paths are /dev/null" >&2
        exit 1
      fi
      if [ "${BASH_REMATCH[1]}" != '/dev/null' ]; then
        validate_target "${BASH_REMATCH[2]}"
      fi
      pending_old_marker=''
      ;;
  esac
done < "$PATCH_FILE"

if [ "$headers" -eq 0 ]; then
  echo "Patch contains no parseable diff --git headers." >&2
  exit 1
fi

if [ -n "$pending_old_marker" ]; then
  echo "Malformed or unpaired old file marker: $pending_old_marker" >&2
  exit 1
fi

git apply --check "$PATCH_FILE"
