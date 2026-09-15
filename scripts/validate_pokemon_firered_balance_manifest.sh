#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 /absolute/path/to/integrated_player_package_v1.csv" >&2
  exit 64
fi

package_csv=$1
repo_root=$(cd "$(dirname "$0")/.." && pwd)
manifest="$repo_root/work/evidence/pokemon-firered-balance-translation-manifest.md"

test -f "$package_csv"
test -f "$manifest"

package_rows=$(awk 'NR > 1 { count += 1 } END { print count + 0 }' "$package_csv")
manifest_rows=$(awk '
  /^\| [0-9]+ \|/ {
    id = $2
    count += 1
    if (seen[id]++) duplicate = 1
  }
  END {
    if (count != 23 || duplicate) exit 1
    print count
  }
' "$manifest")

test "$package_rows" -eq 23
test "$manifest_rows" -eq "$package_rows"

for path in \
  src/core/BattleFormulas.lua src/core/BattleEngine.lua src/core/ModRuntime.lua \
  src/core/ModRegistry.lua import/BattleMove.lua import/LevelUpLearnset.lua \
  import/Trainer.lua import/Item.lua import/WildEncounters.lua import/RomAddresses.lua \
  main.lua; do
  test -f "$repo_root/$path"
done

grep -q 'BattleFormulas.isPhysicalType' "$repo_root/src/core/BattleFormulas.lua"
grep -q 'gWildMonHeaders' "$repo_root/import/RomAddresses.lua"
grep -q 'gTrainers' "$repo_root/import/RomAddresses.lua"
grep -q 'gItems' "$repo_root/import/RomAddresses.lua"
grep -q 'battleTrainers' "$repo_root/main.lua"
grep -q 'battleItems' "$repo_root/main.lua"

echo "PASS: frozen package rows=$package_rows manifest rows=$manifest_rows target paths verified"
