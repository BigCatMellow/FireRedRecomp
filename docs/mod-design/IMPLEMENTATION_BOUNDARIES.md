# Implementation Boundaries

## Purpose

This file records the architectural boundary for the progression and quest redesign.

The design is intended for a **FireRedRecomp gameplay mod/ruleset**.

It is not permission to rewrite baseline FireRedRecomp behavior.

## Core rule

```text
NO MOD
↓
FireRedRecomp behaves like FireRed.

Progression / Quest mod enabled
↓
new gameplay rules and UI are layered on top.
```

## What belongs in the mod

- Training Standard tables and logic;
- Train-to-Standard service;
- species-specific evolution-certification rules;
- PC move-loadout rules;
- 4-vs-6 move experiment configuration;
- optional EV suppression or replacement rules;
- optional hidden badge-stat-boost suppression;
- quest definitions;
- quest discovery/tracking state;
- journal UI/data;
- quest reward logic;
- quest navigation state;
- region-map markers;
- same-map/offscreen quest arrows;
- next-map-transition breadcrumb guidance;
- mod save/version metadata.

## What may require generic FireRedRecomp hooks

The mod may eventually need neutral hooks such as:

- on Pokémon caught;
- on Pokémon EXP/level change;
- on evolution eligibility;
- on battle victory;
- on trainer/Gym victory;
- on item obtained/removed;
- on map entered/departed;
- on script start/end;
- on flag/var change;
- on field move used;
- on Pokémon Center / PC interaction;
- on move-loadout query;
- on save/load extension data.

These should be generic mod seams, not hard-coded "TrainerProgression" or "QuestSystem" behavior in core.

## What should stay untouched unless a separate decision explicitly reopens it

- vanilla behavior when no mod is active;
- ROM-imported source truth;
- frozen balance-package assumptions such as one-copy TM scarcity;
- core save compatibility assumptions beyond explicit mod-extension support.

## Decomp rule

Before designing a quest/progression mechanic around assumed FireRed behavior:

1. inspect `pret/pokefirered`;
2. identify existing flags, vars, inventory state, trainer flags, map state, object-hide flags, and relevant event boundaries;
3. reuse that state where possible;
4. add mod-only state only when FireRed does not persist what the feature needs.

## Quest-state priority

Use this order:

1. existing durable FireRed flag/var/trainer flag;
2. inventory / Pokémon / world state;
3. normalized gameplay event;
4. mod-only discovery/hint/counter state;
5. new quest-specific state only when necessary.

## Navigation rule

Preferred navigation is:

```text
tracked quest
↓
broad Region Map destination
↓
arrow toward next usable transition
↓
same-map edge arrow
↓
marker over visible target
```

Do not start with exact tile-by-tile GPS pathfinding.

## Save rule

This is a ruleset mod, not a cosmetic toggle.

Any persistent mod data should carry:

- mod/ruleset identifier;
- schema/version;
- migration policy.

Do not promise clean mid-save disabling if the mod has already changed irreversible game state.
