#!/usr/bin/env python3
"""Regression coverage for frozen-package extraction, not gameplay values."""

import importlib.util
import argparse
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "balance_generator", ROOT / "scripts/generate_pokemon_firered_balance_mod.py")
GENERATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GENERATOR)
parser = argparse.ArgumentParser()
parser.add_argument("--package", required=True, type=Path,
                    help="exact frozen CSV exported from its pinned Git blob")
PACKAGE = parser.parse_args().package


def expect(condition, name):
    assert condition, name


def changed_copy(old, new):
    value = PACKAGE.read_text()
    expect(value.count(old) == 1, "test mutation must match exactly one frozen row")
    handle = tempfile.NamedTemporaryFile(mode="w", suffix=".csv", delete=False)
    handle.write(value.replace(old, new))
    handle.close()
    return Path(handle.name)


categories, overrides, additions = GENERATOR.parse_frozen_package(GENERATOR.rows(PACKAGE))
expect(categories == {"MOVE_SLUDGE": "physical", "MOVE_SLUDGE_BOMB": "physical"},
       "category overrides derive from frozen rows")
expect(overrides["MOVE_TWINEEDLE"] == {"power": 30}
       and overrides["MOVE_ROCK_TOMB"] == {"power": 60, "accuracy": 90},
       "move override fields derive from frozen rows")
expect(additions["SPECIES_ONIX"] == (30, "MOVE_ROCK_TOMB")
       and additions["SPECIES_SEAKING"] == (38, "MOVE_WATERFALL"),
       "natural additions derive from frozen rows")

for old, new, label in (
    ("MOVE_OVERRIDE,,MOVE_TWINEEDLE,,,30,,,", "MOVE_OVERRIDE,,MOVE_TWINEEDLE,,,31,,,", "override"),
    ("NATURAL_MOVE,SPECIES_ONIX,MOVE_ROCK_TOMB,30,,,,,", "NATURAL_MOVE,SPECIES_ONIX,MOVE_ROCK_TOMB,31,,,,,", "addition"),
):
    candidate = changed_copy(old, new)
    try:
        expect(not GENERATOR.has_locked_hash(candidate, GENERATOR.PACKAGE_SHA256),
               "changed %s row fails frozen hash gate" % label)
    finally:
        candidate.unlink()

print("5 passed, 0 failed")
