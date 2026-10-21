# Hand-off H1 to the party/Dex owner: friendship and IVs into battlers

- Created: 2026-10-21
- Repository: `BigCatMellow/FireRedRecomp`
- From: the battle-engine lane (variable-power slices)
- To: the owner of the party/Dex code, which includes
  `src/core/BattlePartyBridge.lua` and the Pokémon factories (decision D1 of
  the variable-power review)
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Origin: [variable-power design proposal](../reports/phase4-variable-power-design-proposal.md)
  ("H1"), reviewed in
  [2026-10-21-variable-power-design-review.md](../reviews/2026-10-21-variable-power-design-review.md)
  (F4, F12, F13, D1, D2)
- Status: `OPEN — for the party/Dex owner; no battle-lane edits to these files`

## Why

Three moves get their power or type from data that the engine's battlers do
not carry today:

- **Return** (effect 121, move 216): power = `10 * friendship / 25`
  (`src/battle_script_commands.c:8228-8236`).
- **Frustration** (effect 123, move 218): power =
  `10 * (255 - friendship) / 25` (same lines).
- **Hidden Power** (effect 135, move 237): its type and power come from bit 0
  and bit 1 of the six IVs (`src/battle_script_commands.c:8503-8530`).

In source these values are copied into `gBattleMons[]` once, at switch-in
(`src/battle_controller_player.c:1540-1547`,
`src/battle_controller_opponent.c:475-482`). The engine has no species table
and no default that would be exact, so the values must come in with the
battler. Today `BattlePartyBridge` drops them, and the three moves hit as
plain Normal moves at power 1.

The battle lane will land slice **V4a** without your change. V4a adds optional
`friendship` and `ivs` options to `BattleEngine.makeBattler` and treats the
three moves as unsupported for any battler that lacks the data: the player
sees "That move's effect is not available yet.", and a foe reaches the
existing unsupported-effect error. Once H1 lands, slice **V4b** adds the
bridge tests and marks the inventory rows represented.

## What H1 needs

Both fields are plain values passed to `BattleEngine.makeBattler`:

- `friendship`: an integer from 0 to 255.
- `ivs`: a table `{hp=, attack=, defense=, speed=, spAttack=, spDefense=}`,
  each 0-31. Pass a copy so the battler cannot alias the save record.

### 1. `BattlePartyBridge.battlerFromParty` (`BattlePartyBridge.lua:124-152`)

The decoded BoxPokemon is already in hand. Pass:

- `friendship = decoded.substructs[0].friendship` (`BoxPokemonCodec.lua:161`)
- `ivs = <copy of> decoded.substructs[3].ivs` (`BoxPokemonCodec.lua:210-217`)

The player starter already stores its species base friendship in the record
(`StarterPokemonFactory.lua:123`), so this item covers it.

### 2. `BattlePartyBridge.battlerFromGenerated` (`BattlePartyBridge.lua:156-174`)

- `ivs = <copy of> instance.ivs`. Wild instances (`WildPokemonFactory.lua:257`)
  and trainer instances (`TrainerPokemonFactory.lua:123`) both carry it.
- `friendship`: a **wild** instance has no top-level `friendship`, but its
  `boxData` holds the species base friendship. Read
  `instance.boxData.substructs[0].friendship` (`WildPokemonFactory.lua:169-172`,
  written at `:244`). This also covers the developer temporary player
  (`main.lua:1280-1281`). Adding `friendship` to the wild factory's return
  table is optional (review F13).
- A **trainer** instance has no `boxData`, so it needs item 3.

### 3. `TrainerPokemonFactory.generate` return table (`TrainerPokemonFactory.lua:121-128`)

Add `friendship = info.friendship`, the species' base friendship. `info` is
`args.speciesInfo`, and `friendship` is imported at `import/SpeciesInfo.lua:75`
(`gSpeciesInfo[].friendship`). Source: `CreateBoxMon` sets the species base
friendship (`src/pokemon.c:1815`), and `CreateNPCTrainerParty` never
overrides it (`src/battle_main.c:1539-1640`). The trainer IVs are already
right (`iv * 31 / 255`, `src/battle_main.c:1576`).

### 4. No write-back

`persistPartyBattler` must **not** write either field back from the battler.
The battle-time battler fields are snapshots: an in-battle level-up adjusts
the party friendship only (`src/battle_script_commands.c:3314`), and the
refresh after it rewrites only level, HP and stats (`:3316-3329`).

**Battle-setup friendship raise (implementation review F1).** Before the
battlers are built, source raises every party member's friendship for
Leader, Elite Four and Champion battles (`src/battle_main.c:711-713` ->
`AdjustFriendship(..., FRIENDSHIP_EVENT_LEAGUE_BATTLE)`, `src/pokemon.c:5478-5487`:
+3/+2/+1 by friendship band, `:1623`). The battler must carry the raised
value (e.g. friendship 70 -> 72 before Return computes its power). A
friendship drop on faint (`src/battle_script_commands.c:2878`) is applied to
the party, not the battler. Neither applies yet (no gym battles), but the
party side must apply the league raise before building the battler once
they exist.

### 5. Precondition to keep in mind (review F12)

The snapshot taken when a battler is built is exact today because the
project applies level-up friendship after the battle
(`EarlyRivalRewards.lua:121-127`). When in-battle EXP lands, a mid-battle
switch-in rebuild must read the battle-time party friendship, as source
re-copies the party value at that switch-in.

No `main.lua` change is needed. Every call site (`:1241`, `:1280`, `:1313`,
`:1403`, `:1405`, `:1540`, `:1542`, `:1553`, `:1634`, `:1690`) keeps working.

## Not a prerequisite

H1 blocks only slice V4b. It is **not** a prerequisite for anything else:
V1 (Present), V2 (Fury Cutter), V3 (Rollout/Defense Curl) and V4a (the
engine formulas and gate) all land without it, and V5 (Low Kick) waits on a
different hand-off (H2, Pokédex weight).

## Suggested acceptance (for V4b, after H1)

- A party record's friendship and six IVs reach the battler from
  `battlerFromParty`, and the battler's `ivs` table is not the record's.
- A wild instance's `boxData` friendship and its `ivs` reach the battler from
  `battlerFromGenerated`.
- A trainer instance's species friendship and its `ivs` reach the battler.
- `persistPartyBattler` leaves the record's friendship and IVs unchanged.
