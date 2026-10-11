# FireRedRecomp Mod Design

**Status:** design/research only. Nothing in this folder is automatically implemented by the recomp runtime.

This directory is the durable home for gameplay-mod concepts that sit on top of FireRedRecomp. Recomp parity work remains governed by the repository's normal contracts; these notes describe optional mod behavior.

## Current design packages

- [Systemic Balance](./systemic-balance/README.md) — Pokémon roles, move ecosystem, physical/special policy, resource scarcity, team synergy, combo techniques, and battle-regression design.

## Boundary

- Recomp correctness/parity is not changed by these documents.
- A design marked **preferred** is still not implemented until a bounded mod task says so.
- A design marked **candidate** or **hold** must not be treated as decided.
- Source/game data should continue to come from the supported FireRed ROM/decomp workflow, not be copied into git.

## Research provenance

The quantitative balance work was developed in the Pilot Projects research branch/PR and is summarized here so FireRedRecomp does not depend on hidden chat context:

- Pilot Projects repo: https://github.com/BigCatMellow/Pilot_Projects
- Research PR: https://github.com/BigCatMellow/Pilot_Projects/pull/14
- Vanilla source pin used by the research: `pret/pokefirered@c75f352304d529f6ba92d4f74b9cf8b5c3810788`

The files under `systemic-balance/` are the FireRedRecomp-facing handoff and should be updated when design conclusions materially change.
