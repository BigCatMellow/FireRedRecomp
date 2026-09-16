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
MOVE_OVERRIDES = {
    "MOVE_TWINEEDLE": {"power": 30}, "MOVE_SILVER_WIND": {"pp": 10},
    "MOVE_ROCK_TOMB": {"power": 60, "accuracy": 90},
    "MOVE_ROCK_BLAST": {"power": 25, "accuracy": 90},
    "MOVE_GIGA_DRAIN": {"pp": 10}, "MOVE_WING_ATTACK": {"power": 65},
    "MOVE_AIR_CUTTER": {"power": 65, "accuracy": 95},
    "MOVE_AURORA_BEAM": {"power": 70},
}
LEARNSET_ADDITIONS = {
    "SPECIES_ONIX": (30, "MOVE_ROCK_TOMB"), "SPECIES_KABUTOPS": (46, "MOVE_ROCK_BLAST"),
    "SPECIES_ARBOK": (30, "MOVE_POISON_FANG"), "SPECIES_GOLBAT": (35, "MOVE_POISON_FANG"),
    "SPECIES_NIDOQUEEN": (30, "MOVE_POISON_FANG"), "SPECIES_NIDOKING": (30, "MOVE_POISON_TAIL"),
    "SPECIES_JYNX": (25, "MOVE_AURORA_BEAM"), "SPECIES_ELECTRODE": (32, "MOVE_SHOCK_WAVE"),
    "SPECIES_MAGNETON": (32, "MOVE_SHOCK_WAVE"), "SPECIES_FLAREON": (36, "MOVE_FLAME_WHEEL"),
    "SPECIES_DODRIO": (37, "MOVE_DRILL_PECK"), "SPECIES_GENGAR": (36, "MOVE_SHADOW_BALL"),
    "SPECIES_SEAKING": (38, "MOVE_WATERFALL"),
}


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


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


def assert_package(package_rows):
    assert len(package_rows) == 23, "frozen package must contain exactly 23 rows"
    expected = {"CATEGORY_OVERRIDE": 2, "MOVE_OVERRIDE": 8, "NATURAL_MOVE": 13}
    actual = {}
    for row in package_rows:
        actual[row["row_kind"]] = actual.get(row["row_kind"], 0) + 1
    assert actual == expected, "frozen package row kinds differ from the approved contract"
    assert {(r["move"], r["category_override"]) for r in package_rows if r["row_kind"] == "CATEGORY_OVERRIDE"} == {
        ("MOVE_SLUDGE", "PHYSICAL"), ("MOVE_SLUDGE_BOMB", "PHYSICAL")}, "category exceptions differ"


def render(categories, move_ids, species_ids):
    out = ["-- GENERATED FILE. DO NOT EDIT.",
           "-- Source lock: FireRed %s; PokeAPI moves.csv sha256 %s." % (FIRERED_COMMIT, POKEAPI_SHA256),
           "return function(mod)", "  local categories = {"]
    for move_id in range(355):
        out.append("    [%d] = %r," % (move_id, categories[move_id]))
    out += ["  }", "  for moveId = 0, 354 do", "    mod:content(\"battleMoves\"):patch(moveId, {category=categories[moveId]})", "  end"]
    for move, changes in sorted(MOVE_OVERRIDES.items(), key=lambda item: move_ids[item[0]]):
        fields = ", ".join("%s=%d" % item for item in sorted(changes.items()))
        out.append("  mod:content(\"battleMoves\"):patch(%d, {%s})" % (move_ids[move], fields))
    for species, (level, move) in sorted(LEARNSET_ADDITIONS.items(), key=lambda item: species_ids[item[0]]):
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
    assert sha256(args.pokeapi_moves) == POKEAPI_SHA256, "PokeAPI moves.csv hash differs from source lock"
    assert sha256(args.package) == PACKAGE_SHA256, "frozen package hash differs from source lock"
    assert_package(rows(args.package))
    move_ids = constants(args.firered_source / "include/constants/moves.h", "MOVE_")
    species_ids = constants(args.firered_source / "include/constants/species.h", "SPECIES_")
    assert set(range(355)) == set(move_ids.values()) & set(range(355)), "move ids are not exactly 0..354"
    modern = {row["move"]: row["category_modern"].lower() for row in rows(args.modern_categories)}
    assert len(modern) == 355 and set(modern) == {name for name, value in move_ids.items() if value < 355}, "category map must cover every FireRed move exactly once"
    categories = {move_ids[name]: category for name, category in modern.items()}
    categories[move_ids["MOVE_SLUDGE"]] = "physical"
    categories[move_ids["MOVE_SLUDGE_BOMB"]] = "physical"
    assert set(categories) == set(range(355)) and set(categories.values()) <= {"physical", "special", "status"}, "invalid generated categories"
    for name in set(MOVE_OVERRIDES) | {move for _, move in LEARNSET_ADDITIONS.values()}:
        assert name in move_ids and move_ids[name] < 355, "unknown package move " + name
    for species in LEARNSET_ADDITIONS:
        assert species in species_ids, "unknown package species " + species
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(render(categories, move_ids, species_ids))


if __name__ == "__main__":
    main()
