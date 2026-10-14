# Broader Feature Concepts

These ideas are related to the balance project but are **not automatically part of the current player-ecosystem package**.

## Trainer mastery / reduced grind

Design goals discussed:

- Pokémon can benefit from catch-up progression so newly added team members do not require repetitive grinding.
- Trainer progression should increasingly represent understanding/coordination, not just higher numbers.
- Badge/progression gates can control advanced systems without making basic usability painful.

Any catch-up system must preserve normal move-learning logic. Do not let automatic level catch-up silently skip access to important moves.

## Move relearning / PC loadouts

Strong candidate:

> Pokémon permanently remember moves they have learned; the active battle loadout remains limited.

A PC/menu interface can let the player swap remembered moves into the four active slots.

Benefits:

- removes permanent move-deletion anxiety;
- makes preparation meaningful;
- supports team specialization;
- fits the later synergy system;
- lets catch-up Pokémon recover moves appropriate to their current level.

The design should avoid turning the PC into unrestricted access to moves the Pokémon never legitimately learned.

## Four vs six moves

Six active moves was discussed, but the current direction is **do not jump to six**.

More active moves reduce specialization and can make each Pokémon self-sufficient.

Preferred sequence:

1. four active moves;
2. permanent remembered library;
3. test cross-team synergy;
4. only then A/B test an additional restricted utility slot if needed.

## Quest system

The quest system should be reevaluated separately.

Reference point: Pokémon Unbound was identified as a strong example because quests are:

- visible and trackable;
- integrated into exploration;
- clear about goals/progress;
- capable of giving useful side rewards;
- not dependent on hidden chat-like memory.

Future quest work should compare multiple ROM hacks/RPGs rather than copying one implementation.

## Catch-up + move access

If a Pokémon is raised directly to the team's level:

- it must not lose level-up moves it would reasonably know;
- the remembered-move library can solve much of this cleanly;
- alternatively, a move-relearner NPC/PC function can expose every legal move up to current level.

The preferred direction is that **learning a move is permanent character growth**, even when the move is not one of the four currently equipped.

## Team synergy / combined techniques

See [TEAM_SYNERGY.md](./TEAM_SYNERGY.md).

This remains a future layer. It should not be used to justify a weak base ecosystem. First make ordinary roles and moves coherent; then add coordination mechanics on top.
