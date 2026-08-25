# FireRed ReComp — Phase 4 Core Battle Engine Kickoff (independent, parallel-safe — but read the risk note first)

## Context you need

This project (`/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp/`)
is a **recomp** of Pokémon FireRed: real decompiled C source
(`/home/mellow/Documents/Projects/Pokemon ReComp/Disassembled_Games/Classic/pokefirered-master/`)
ported by hand into Lua/LÖVE2D, pulling every asset directly out of a
verified real ROM at load time. Nothing is placeholder — every module is
verified against real ROM bytes or real source, documented in its header
comment.

Verified ROM:
`/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba`
(SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`).

Checklist: `/home/mellow/Documents/Projects/Pokemon ReComp/docs/handoffs/firered-recomp-checklist.md`.
This is **Phase 4 — Full Gen 3 battle engine**, currently entirely
unchecked. The checklist's own header note for this phase: *"Opus, xhigh
for the core damage/turn-order rules engine... Highest-risk isolated
subsystem in the roadmap — deterministic rules and edge cases (multi-turn
moves, forced switching) are exactly where a bad first design costs the
most rework."* Take that seriously: prioritize getting the core data
flow and rules-vs-presentation separation right over covering breadth of
moves/abilities. A clean minimal slice beats a broad shaky one.

## What NOT to touch

Do not edit `main.lua`. This is a pure engine task — build in `src/core/`
and `tests/`. A concurrent handoff may be doing new-game naming/gender UI
work in `main.lua` at the same time; that's a different file, no
conflict, but don't go anywhere near it.

## Scope: a real, bounded vertical slice — not the whole battle system

Don't try to build "Gen 3 battle engine, complete" in one pass. Build the
**minimum real subset that can resolve an actual single-Pokémon-vs-single-
Pokémon fight to a real conclusion (faint or run), using only real direct-
damage moves** — matching this project's established pattern of scoping
every phase down to a provably-correct vertical slice first (see how
Phase 3 was scoped, or how the wild-encounter-selector handoff stopped
short of a real battle). Multi-turn moves, status conditions, abilities,
held items, weather, screens, and doubles are all explicitly Phase 4
follow-up work, not this task.

### What's already built and reusable

- `import/TypeChart.lua` — `gTypeEffectiveness` (Phase 1, verified).
- `import/BattleMove.lua` — `gBattleMoves` (power, accuracy, PP, type,
  category — check its real fields; FireRed-era `category` on the move
  record itself doesn't yet encode the physical/special split the way
  later gens do, see the type-split checklist line below).
- `src/core/PokemonStats.lua` — real `CalculateMonStats` (final stats
  from base+level+IV+EV+nature).
- `src/core/BoxPokemonCodec.lua`/`PartyModel.lua` — the Pokémon-instance
  data model this engine operates on (HP, PP, current stats).
- `src/core/Rng.lua` — real LCG, needed for accuracy/crit/damage-roll
  randomness (check `src/battle_script_commands.c`/`src/pokemon.c` for
  which real RNG calls feed which rolls — don't assume a single unified
  "roll" the way a simplified reimplementation might).
- `src/core/TaskScheduler.lua` — available if the engine needs its own
  internal step sequencing, though pure-Lua turn resolution likely
  doesn't need it (this project's established pattern: keep rules logic
  itself as plain synchronous Lua functions/state machines, testable
  without love2d — see `ScriptInterpreter.lua`/`WildEncounterSelector.lua`
  for the house style of "pure logic module + a caller-driven world/RNG
  interface").

### The task

1. **Read the real damage formula** (`src/pokemon.c`'s `CalculateBaseDamage`
   or equivalent real function — confirm the exact name from source, this
   project has a history of double-checking real names rather than
   assuming community-lore names are exactly right) — the real Gen 3
   formula: `((((2*level/5+2)*power*atk/def)/50)+2) * modifiers`, where
   modifiers include STAB (1.5x if move type matches user type), type
   effectiveness (from `TypeChart.lua`), critical hit (2x in Gen 3, not
   1.5x — confirm this exactly, it changed across generations), and a
   real random damage-roll factor (a real 85-100% range, confirm exact
   bounds/rounding from source). Port it exactly, don't approximate.
2. **Type-based physical/special split — FireRed-era, not later per-move
   split**: confirm from real source exactly how FireRed decides
   physical vs. special (Gen 1-3 rule: by the move's *type*, not a
   per-move flag — e.g. all Normal/Fighting/etc. moves are physical,
   all Fire/Water/etc. are special, with real exceptions like
   Fire/Ice/Electric-type moves that are conventionally special in this
   era). Get the real type→category mapping from source, don't guess
   which types are which category.
3. **Accuracy/evasion**: real accuracy check using the move's real
   accuracy stat plus real accuracy/evasion stat-stage modifiers (even
   if stat-stage-changing moves aren't implemented yet, model the stage
   multiplier table itself, since accuracy checks need it structurally
   — default stage 0 for now).
4. **Turn order / priority**: real speed-stat comparison (with a real
   speed-tie tiebreak — check what FireRed actually does, don't assume
   "player always goes first" or a naive coin flip without checking
   source) plus real move priority values (most moves are priority 0;
   if you don't implement any priority-nonzero moves yet, the ordering
   logic should still structurally support a priority field for later).
5. **PP, faint, catch/run**: PP decrements on move use (real "Struggle
   when PP exhausted" can be a documented stub, not required); faint
   detection (HP <= 0) ends the battle in a minimal 1v1 slice; "run"
   should use the real run-chance formula if you have room, or a
   documented always-succeeds stub if not (say clearly which).
   Catching is NOT required for this task (needs a Poké Ball capture-
   rate formula, a reasonable follow-up but out of scope here unless
   you have room after everything else is solid).
6. **`src/core/BattleEngine.lua`** (or split into a few cleanly-separated
   modules — your call, but keep rules logic separate from any future
   presentation/animation layer per the checklist's own Phase 4 line
   "Battle animation event stream separate from rules engine"): a pure,
   testable, turn-resolution state machine — given two Pokémon instances
   and a chosen move each turn, resolves one turn (or a full battle via
   a scripted move sequence) deterministically given a seeded RNG.
7. **Golden test**: hand-verify at least one real, complete damage
   calculation against independently known real numbers (e.g. a
   documented real Gen 3 damage calc from a reliable source, or derive
   one by hand from the formula + real Bulbasaur/Charmander stats this
   project already has verified) — the same standard this project has
   held everywhere else (e.g. `PokemonStats.lua`'s hand-verified level-5/
   level-100 stat lines). Then a scripted multi-turn battle (e.g.
   "Bulbasaur Tackle vs Charmander Tackle, repeat until one faints")
   as a deterministic seeded replay test, confirming the whole turn loop
   holds together, not just one isolated calculation.

### Explicitly out of scope for this pass

- Status conditions (paralysis/burn/poison/sleep/freeze/confusion).
- Abilities, held items, weather, screens (Reflect/Light Screen), stat-
  stage-changing moves' actual application (structure the stage-
  multiplier table but you don't need moves that call it yet).
- Multi-turn moves (Solar Beam, Fly, etc.), forced switching, trapping.
- Trainer AI, double battles.
- Any animation/presentation layer or `main.lua` wiring.
- Catching (Poké Ball capture-rate formula) — stretch goal only.
- Fuzz testing across the full move/species matrix — one solid golden
  scenario plus the deterministic replay test is the bar for this pass;
  broader stress testing is real future work once more moves/mechanics
  exist to stress.

## Conventions to follow

- Every module's header comment cites the real function/formula/source
  file and states exactly what was verified — this is the highest-risk
  module in the project so far, hold it to the highest documentation
  standard already established (see `PokemonStats.lua`/`ExperienceTable.lua`
  for the bar).
- No `bit` library / Lua 5.3 bitwise operators (LuaJIT + plain Lua 5.1
  compatibility).
- Tests: plain-Lua unit tests, no ROM needed for the formula/turn-order
  logic itself (though double-check the real formula/constants against
  `pokefirered` source, don't guess). Run the full suite before
  finishing:
  ```
  cd "/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp"
  for f in tests/*.lua; do lua5.1 "$f" || echo "FAILED: $f"; done
  ```
- **Don't commit anything** — leave changes in the working tree.
- Update the checklist's Phase 4 lines for exactly what you finished —
  be honest about what's a real ported formula vs. a documented stub.

## Deliverable

What real formula/source you read for damage/accuracy/turn-order, what's
a real verified calculation vs. a documented simplification/stub, the
golden test scenario and its expected values, what's explicitly deferred
(status/abilities/items/etc.), and the file list touched.
