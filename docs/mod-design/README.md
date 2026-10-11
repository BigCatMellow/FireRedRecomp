# FireRed Mod Design Notes

This folder is the FireRedRecomp-side home for the gameplay redesign work discussed for an eventual **mod/ruleset**, not a rewrite of FireRedRecomp core behavior.

## Scope

This design track currently covers:

- anti-grind / trainer progression;
- Training Standard / catch-up training;
- species-specific evolution certification;
- PC-based move loadouts;
- 4-vs-6 active move experiments;
- EV / hidden badge boost reevaluation;
- quest / mission journal design;
- quest discovery, tracking, rewards, and local quest chains;
- decomp-guided quest-state mapping;
- optional breadcrumb navigation / quest arrows;
- mod save-state and compatibility considerations.

## Files

- [TRAINER_PROGRESSION.md](TRAINER_PROGRESSION.md) — full progression / anti-grind design history and current lean prototype direction.
- [QUEST_SYSTEM.md](QUEST_SYSTEM.md) — full quest / mission-system reevaluation, including decomp-backed implementation notes and quest navigation.
- [IMPLEMENTATION_BOUNDARIES.md](IMPLEMENTATION_BOUNDARIES.md) — what belongs in the mod, what may require generic FireRedRecomp hooks, and what must stay out of core gameplay logic.

## Current design status

These are **design notes, not accepted implementation specifications**.

The current strongest progression direction is:

1. keep real Pokémon levels;
2. derive a story/League **Training Standard**;
3. allow optional free Train-to-Standard catch-up at a Center/PC;
4. use species-specific trainer certification for former level-based evolutions;
5. let the PC configure a Pokémon's legal move loadout;
6. prototype 4 active moves versus 6 rather than assuming the historic four-move limit is sacred;
7. test EV-off and hidden-badge-stat-boost-off arms before inventing replacement stat systems;
8. keep Type Mastery out of the first playable prototype unless testing shows a real need.

The current strongest quest direction is:

1. discovery-first, tracking-second;
2. use existing FireRed flags/vars/items/world state as authoritative truth;
3. add only the smallest mod-owned quest state needed;
4. build a journal around people, Pokémon, rumors, and unresolved situations;
5. reuse FireRed's existing event vocabulary where possible;
6. use optional **breadcrumb navigation**, not mandatory GPS routing;
7. support broad map markers, edge arrows, next-exit guidance, and visible-target markers;
8. avoid exact tile-by-tile route lines unless later testing proves they are needed.

## Source references

Primary behavior reference:

`pret/pokefirered@037335f4c725d7c9aecdac87066f2002b4bd7e14`

Original research/design source:

`BigCatMellow/Pilot_Projects`
branch: `pokemon-firered-balance-bootstrap`

Snapshot source blobs imported here:

- Trainer progression source blob: `527cf23af9ff70f8d96c45ed2a953c139576ee70`
- Quest-system source blob: `0a27b3933d5afa1ffa828a6bec43d4b3a3f560e9`

## Important boundary

> **FireRedRecomp remains vanilla-capable when this mod is absent.**

If a future mod needs a hook that FireRedRecomp does not expose, the preferred solution is the smallest generic extension point that could also serve other mods. The gameplay rule itself belongs in the mod.
