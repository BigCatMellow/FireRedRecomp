# FireRed ReComp — Oak's Lab Rival Tutorial Battle Continuation

> **Completed (2026-08-17):** full ROM-gated suite passes (104/104 test
> files), `main.lua` loads clean under plain Lua 5.1, `git diff --check` is
> clean. Checklist updated (`firered-recomp-checklist.md`, Phase 3's new
> starter/rival-battle line and the Phase 4 trainer-AI/damage lines). See
> that checklist entry for the authoritative description of what shipped
> and what's still open (capture persistence, general trainer AI, etc).

## Current project snapshot (2026-08-13)

Repository: `/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp/`.
Verified ROM: `/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba`
(`41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`).

The working tree is intentionally **uncommitted** and contains the recent
project slices below. Preserve all changes; never reset/checkout unrelated
files. The full ROM-gated suite passed at each completed milestone; after
the currently in-flight rival-battle changes land, rerun every test before
calling this task done.

### Completed milestones

- Phase 1 importer/canonical data and Phase 2 rendering foundations are
  substantially complete (see the live checklist).
- New-game identity is live: Oak scene → gender → player name → rival name.
- `GameSession` builds a codec-compatible fresh session and enters the real
  Player's House 2F at map group 4/number 1, `(6,6)`, facing north.
- Wild encounters start a live, bounded Fight/Run battle scene with real ROM
  terrain/sprites.  The direct-damage Phase 4 engine has accuracy, crit,
  type, PP, faint, run, and capture-rule core coverage.
- `LevelUpLearnset.lua`, `WildPokemonFactory.lua`, and BoxPokemon encode
  support provide deterministic normal wild generation plus encrypted,
  save-compatible caught-mon party/PC records.
- `BattlePartyBridge.lua` makes live battles consume a real session lead and
  persist its HP/PP. Empty fresh sessions visibly refuse battle rather than
  inventing a starter.
- Authentic starter acquisition is live: bedroom → Pallet north gate →
  abbreviated but source-equivalent Oak-lab setup → Bulbasaur/Squirtle/
  Charmander choice. `StarterPokemonFactory.lua` mirrors `ScriptGiveMon` /
  `CreateMon` (four RNG draws, not wild generation), updates party, Dex,
  flags/vars, removes selected/counter ball objects, and reaches lab scene 3.
  Leaving then reaches the rival-battle gate.

The latest independently run full suite before this handoff had **100** test
files passing; starter acquisition added three focused tests and reported
**102** passing ROM-gated files. Recheck the actual count at pickup.

## Active/in-flight task

`src/core/EarlyRivalAI.lua`, `EarlyRivalRewards.lua`, and
`TrainerPokemonFactory.lua` have appeared in the worktree alongside the
starter/rival implementation. Treat this task as in flight until you inspect
the diff, run its tests, and update the checklist.

The goal is the mandatory Oak's Lab tutorial battle after starter selection:
trainer battle, correct trainer/party, story result, healing, and the first
post-battle scene. Do not fake a victory or skip the battle.

## Source-confirmed contract

### Trigger and mapping

- Lab scene progresses `2` (starter choice) → `3` (rival picked) → `4`
  (battle resolved).
- Scene-3 coordinate triggers are exactly `(5,8)`, `(6,8)`, `(7,8)`.
  The player stays at `y=8`; the existing early-story implementation once
  returned `y-1`, which is incorrect and must be checked/fixed.
- Starter mapping:

  | Player | Rival | Trainer |
  | --- | --- | --- |
  | Bulbasaur | Charmander | 328 |
  | Squirtle | Bulbasaur | 327 |
  | Charmander | Squirtle | 326 |

- Trainers 326–328 are `TRAINER_CLASS_RIVAL_EARLY`, one level-5 counter
  starter, trainer-party IV byte 0, no items, AI flags `0x7`.

### Tutorial mode and outcomes

- `RIVAL_BATTLE_TUTORIAL` is value `3`: tutorial behavior plus
  `RIVAL_BATTLE_HEAL_AFTER`.
- Running is rejected without turn/RNG/foe-action consumption.
- Rival can select Growl/Tail Whip; do not force a damaging move if claiming
  source fidelity.
- Both win **and loss** execute `EndRivalBattle`: full party HP/PP/status
  heal, lab scene `4`, rival hide/remove, `FLAG_BEAT_RIVAL_IN_OAKS_LAB`
  (`0x258`), and the selected trainer flag (`0x646`/`0x647`/`0x648`). Loss
  does not whiteout or lose money.
- Win awards ₽80 plus EXP/EV/friendship (starter reaches level 6); loss
  gives no EXP/EV/money and friendship falls by one. Do not set scene 4 or
  battle flags before acknowledged outcome.

### Required data/persistence details

- Starter creation uses `CreateMon`, not `WildPokemonFactory.generate`.
- Starter/Dex updates require `SaveBlock2.pokedex.owned/seen` and both
  `SaveBlock1.seen1`/`seen2`. `seen2` is real SaveBlock1 offset `0x3A18`;
  ensure the codec/layout covers it before promising save parity.
- Rival battle terrain is `BATTLE_TERRAIN_BUILDING`, not the current wild
  grass terrain. A scene claiming real trainer presentation must not show
  grass or a “Wild X appeared!” message.

## Deliberate boundaries already documented

- Full Oak escort movement/audio, nickname UI, script pagination, trainer
  animation, generic trainer AI, double battles, capture UI/bag/Dex wiring,
  all rewards beyond this rival slice, and PC save sectors remain separate
  work.
- Wild held-item RNG and Unown generation remain omitted by the wild factory.
- Do not grant a starter before its real lab choice or allow exit past scene
  3's battle gate.

## Required validation / finish steps

```bash
cd "/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp"
ROMPATH="/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba"
for f in tests/*.lua; do POKEPORT_ROM="$ROMPATH" lua5.1 "$f" || exit 1; done
lua5.1 -e "assert(loadfile('main.lua'))"
git diff --check
```

Add/verify tests for all starter mappings and lanes, no-run tutorial input,
stat-move behavior/AI, trainer fixture data, win and loss persistence,
healing, money/EXP/EV/friendship, scene/flag/object state, and no regression
to wild battles. Update `firered-recomp-checklist.md` accurately, then move
this brief to `handoffs/completed/` only after all deliverables and checks
are finished. Do not commit code.
