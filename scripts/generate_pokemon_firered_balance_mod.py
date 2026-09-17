#!/usr/bin/env python3
"""Generate the frozen FireRed balance mod from its pinned, auditable inputs.

This is deliberately a build-time tool, never part of the game runtime.  It
fails closed unless the FireRed constants, extracted PokeAPI category map, and
frozen package each match the bounded contract described in SOURCE_LOCK.md.
"""

import argparse
import csv
import hashlib
import re
import subprocess
from pathlib import Path

FIRERED_COMMIT = "c75f352304d529f6ba92d4f74b9cf8b5c3810788"
POKEAPI_SHA256 = "8aafd37bf78f19471495c05b201545180f50f0a08a2a2a844d69f9837dd39ac9"
PACKAGE_SHA256 = "6f3b1e4d32b6d02aff15a368c89e01c1d24e1c8987391aea790e43e582bae087"


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def has_locked_hash(path, expected):
    return sha256(path) == expected


def exact_commit(source):
    return subprocess.check_output(
        ["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip() == FIRERED_COMMIT


def constants(path, prefix):
    values = {}
    pattern = re.compile(r"^#define\s+(%s\w+)\s+(\d+)\s*$" % prefix)
    for line in Path(path).read_text().splitlines():
        match = pattern.match(line)
        if match:
            values[match.group(1)] = int(match.group(2))
    return values


def rows(path):
    with Path(path).open(newline="") as handle:
        return list(csv.DictReader(handle))


def parse_frozen_package(package_rows):
    """Return every generated content value from the immutable CSV itself."""
    assert len(package_rows) == 23, "frozen package must contain exactly 23 rows"
    expected = {"CATEGORY_OVERRIDE": 2, "MOVE_OVERRIDE": 8, "NATURAL_MOVE": 13}
    actual = {}
    category_overrides, move_overrides, learnset_additions = {}, {}, {}
    for row in package_rows:
        kind = row["row_kind"]
        actual[kind] = actual.get(kind, 0) + 1
        if kind == "CATEGORY_OVERRIDE":
            assert row["move"] and row["category_override"], "category override is incomplete"
            assert not row["final_species"] and not row["learn_level"], "category override has unrelated fields"
            assert row["move"] not in category_overrides, "duplicate category override"
            category_overrides[row["move"]] = row["category_override"].lower()
        elif kind == "MOVE_OVERRIDE":
            assert row["move"] and not row["final_species"] and not row["learn_level"], "move override is malformed"
            changes = {}
            for source, target in (("power_override", "power"), ("accuracy_override", "accuracy"), ("pp_override", "pp")):
                if row[source]:
                    assert row[source].isdigit() and int(row[source]) > 0, "move override field must be a positive integer"
                    changes[target] = int(row[source])
            assert changes and row["move"] not in move_overrides, "duplicate or empty move override"
            move_overrides[row["move"]] = changes
        elif kind == "NATURAL_MOVE":
            assert row["final_species"] and row["move"] and row["learn_level"], "natural move is incomplete"
            assert row["learn_level"].isdigit() and 1 <= int(row["learn_level"]) <= 100, "natural move level is invalid"
            assert not any(row[field] for field in ("category_override", "power_override", "accuracy_override", "pp_override")), "natural move has unrelated fields"
            assert row["final_species"] not in learnset_additions, "duplicate natural-move species"
            learnset_additions[row["final_species"]] = (int(row["learn_level"]), row["move"])
    assert actual == expected, "frozen package row kinds differ from the approved contract"
    return category_overrides, move_overrides, learnset_additions


def render(categories, move_ids, species_ids, move_overrides, learnset_additions):
    out = ["-- GENERATED FILE. DO NOT EDIT.",
           "-- Source lock: FireRed %s; PokeAPI moves.csv sha256 %s." % (FIRERED_COMMIT, POKEAPI_SHA256),
           "return function(mod)", "  local categories = {"]
    for move_id in range(355):
        out.append("    [%d] = %r," % (move_id, categories[move_id]))
    out += ["  }", "  for moveId = 0, 354 do", "    mod:content(\"battleMoves\"):patch(moveId, {category=categories[moveId]})", "  end"]
    for move, changes in sorted(move_overrides.items(), key=lambda item: move_ids[item[0]]):
        fields = ", ".join("%s=%d" % item for item in sorted(changes.items()))
        out.append("  mod:content(\"battleMoves\"):patch(%d, {%s})" % (move_ids[move], fields))
    for species, (level, move) in sorted(learnset_additions.items(), key=lambda item: species_ids[item[0]]):
        out.append("  mod:content(\"battleLearnsetAdditions\"):register(%d, {{level=%d, move=%d}})" % (species_ids[species], level, move_ids[move]))
    out += ["end", ""]
    return "\n".join(out)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--firered-source", required=True, type=Path)
    parser.add_argument("--modern-categories", required=True, type=Path)
    parser.add_argument("--pokeapi-moves", required=True, type=Path)
    parser.add_argument("--package", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    assert exact_commit(args.firered_source), "FireRed source is not the pinned commit"
    assert has_locked_hash(args.pokeapi_moves, POKEAPI_SHA256), "PokeAPI moves.csv hash differs from source lock"
    assert has_locked_hash(args.package, PACKAGE_SHA256), "frozen package hash differs from source lock"
    category_overrides, move_overrides, learnset_additions = parse_frozen_package(rows(args.package))
    move_ids = constants(args.firered_source / "include/constants/moves.h", "MOVE_")
    species_ids = constants(args.firered_source / "include/constants/species.h", "SPECIES_")
    assert set(range(355)) == set(move_ids.values()) & set(range(355)), "move ids are not exactly 0..354"
    modern = {row["move"]: row["category_modern"].lower() for row in rows(args.modern_categories)}
    assert len(modern) == 355 and set(modern) == {name for name, value in move_ids.items() if value < 355}, "category map must cover every FireRed move exactly once"
    categories = {move_ids[name]: category for name, category in modern.items()}
    for move, category in category_overrides.items():
        assert move in move_ids and move_ids[move] < 355, "unknown category-override move " + move
        assert category in {"physical", "special", "status"}, "invalid category override"
        categories[move_ids[move]] = category
    assert set(categories) == set(range(355)) and set(categories.values()) <= {"physical", "special", "status"}, "invalid generated categories"
    for name in set(move_overrides) | {move for _, move in learnset_additions.values()}:
        assert name in move_ids and move_ids[name] < 355, "unknown package move " + name
    for species in learnset_additions:
        assert species in species_ids, "unknown package species " + species
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(render(categories, move_ids, species_ids, move_overrides, learnset_additions))


if __name__ == "__main__":
    main()
