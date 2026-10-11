# Systemic Balance Mod Design

**Authority:** design handoff / research summary  
**Implementation status:** not implemented  
**Current direction:** **PREFER HYBRID-MODERN FOR FURTHER INTEGRATION — NOT FINAL FREEZE**

The central rule is:

> **Balance the underlying Pokémon roles, move ecosystem, progression, and team interactions first. Use battles later as regression tests, not as the primary thing being tuned.**

A weak-looking Pokémon should not receive a stat buff until move quality, move access, type ecosystem, evolution timing, resource friction, and role identity have been examined.

## Files

- [CURRENT_STATE.md](./CURRENT_STATE.md) — exact design state, resolved decisions, holds, and next gate.
- [BALANCE_PHILOSOPHY.md](./BALANCE_PHILOSOPHY.md) — role/class model, type affordances, intervention order.
- [PLAYER_ECOSYSTEM.md](./PLAYER_ECOSYSTEM.md) — current move/category/learnset package.
- [TEAM_SYNERGY.md](./TEAM_SYNERGY.md) — team progression, remembered moves, combo/dual-tech concepts.
- [MECHANICS_AND_RESOURCES.md](./MECHANICS_AND_RESOURCES.md) — physical/special branch, TM scarcity, Game Corner friction.
- [BATTLE_REGRESSION.md](./BATTLE_REGRESSION.md) — how trainer/Gym/League fights should validate systemic work.
- [FEATURE_CONCEPTS.md](./FEATURE_CONCEPTS.md) — broader mod ideas that are related but not yet part of the balance package.
- [IMPLEMENTATION_NOTES.md](./IMPLEMENTATION_NOTES.md) — implementation boundaries and handoff notes.
- [SOURCE_EVIDENCE.md](./SOURCE_EVIDENCE.md) — source pins and research provenance.

## Core non-goals

This is **not** a project to:

- make every Pokémon equally strong;
- normalize all BSTs;
- make every type equally good at every role;
- remove all move scarcity;
- tune the whole game around Gym Leaders or the Elite Four;
- give every Pokémon enough coverage to solve every matchup itself.

The intended result is that most choices have a coherent reason to exist, progression feels better, and teams become more coordinated as the player learns the game.
