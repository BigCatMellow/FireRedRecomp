# Phase 4 next-effect rerank refresh

- Task: `P4-NEXT-EFFECT-RERANK-2`; read-only.
- Baseline: accepted inventory `c10bfa7`, Restore HP `dc8ad06`, Magnitude
  `7b47c73`; source pin `pret/pokefirered` `c75f352`.

## Selection

Select exactly one successor: **`P4-F1-RECOIL-IF-MISS-DISCOVERY`**, effect 45,
Jump Kick 26 and Hi Jump Kick 136. The source has an explicit miss/crash branch
and Hitmonlee reaches Jump Kick at level 16 and Hi Jump Kick at level 26. A
source lock can isolate branch order, PP/accuracy, `DMG_RECOIL_FROM_MISS`,
type/no-effect handling, attacker HP/faint ownership, and result ordering
without first adding persistent volatile or multi-target state.

## Ranked exclusions

| Rank | Candidate | Early-story/source evidence and disposition |
| --- | --- | --- |
| 1 | effect 45, Jump Kick/Hi Jump Kick | Hitmonlee learns Jump Kick at 16 and Hi Jump Kick at 26; the pinned effect script has an explicit miss-recoil branch without persistent state. **Selected.** |
| 2 | Haze, effect 25 | Koffing learns Haze at 33; its `normalisebuffs` script resets both sides' stages and needs a zero-power two-battler event/admission contract. Deferred. |
| 3 | Triple Kick, effect 104 | Hitmontop learns it at 20; its source has a three-hit, rising-power loop with per-hit checks. Deferred pending multi-hit design. |
| blocked | Defense Curl 156 / Trap 42 | Both depend on volatile state consumed by later turns/moves. Not a source-discovery successor. |

Accepted Restore HP is `dc8ad06` ([outcome review](../reviews/2026-10-09-restore-hp-implementation-outcome-review.md)); accepted bounded Magnitude is `7b47c73` ([outcome review](../reviews/2026-10-10-magnitude-implementation-outcome-review.md)). Neither is re-ranked.

Pinned anchors: [effect 45](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/include/constants/battle_move_effects.h#L47), [Jump Kick](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/data/battle_moves.h#L314), [Hi Jump Kick](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/data/battle_moves.h#L1634), [Hitmonlee learnset](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/data/pokemon/level_up_learnsets.h#L1382), and [recoil-if-miss script](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L810).

The selected discovery must not implement effect 45, change admission,
BattleEngine, tests, routes, ROM, or private data. It must preserve exclusions
for abilities/items, Substitute/Protect/Endure, doubles/links, cancellation or
MoveEnd expansion, target/party state, retail animation/text parity, and every
Magnitude exclusion. `git diff --check` passes; no ROM/runtime work occurred.
