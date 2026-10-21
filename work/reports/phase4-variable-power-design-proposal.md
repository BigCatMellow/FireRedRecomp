# Phase 4 proposal: variable-power and data-derived moves (Present, Fury Cutter, Rollout/Defense Curl, Return/Frustration, Hidden Power, Low Kick)

- Status: `PROPOSAL — independently reviewed PASS WITH CORRECTIONS (applied)`
- Review: [2026-10-21 variable-power design review](../reviews/2026-10-21-variable-power-design-review.md).
  Findings F1-F13 and the decisions D1-D4 are folded in below; "Review
  corrections applied" at the end maps each one to the section it changed.
- Date: 2026-10-21
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Engine baseline: working tree at `67f6453` (after protection P1/P4/P5,
  residual R1-R3, weather W0-W3b, multi-turn M1-M3).
- Builds on: the M1-M3 lock machinery (`lockedSlot`, `isLocked`,
  `lockedThisTurn`, `cancelMultiTurnMoves`, the controller's locked-side
  auto-run), the P1 protected-target gate (`protected`, `protectBlocks`,
  `self.protectedMove`), the Flail/Eruption/Weather Ball local move copy, and
  the Restore HP `restoreHP`/`restoreHPFull` events and texts.
- Lane: mixed, per slice (see "Slices"). Present and the friendship/IV
  formulas (V4a) fit the fast lane. Fury Cutter and Rollout add cross-turn
  battle state, so they take the full relay, as separate packages (D3).
- Ownership: `main.lua` and the party/Dex code belong to another agent. **No
  slice edits `main.lua`.** `BattlePartyBridge.lua` and the Pokémon
  factories are party code too (D1). Two families (V4, V5) need data that
  the battle inputs do not carry today. "Data availability" says exactly
  which field is missing and where it would come from, and the hand-off
  notes are at the end (H1 is also a self-contained note:
  [`work/handoffs/2026-10-21-battle-friendship-ivs-handoff.md`](../handoffs/2026-10-21-battle-friendship-ivs-handoff.md)).

The [move-effect inventory](phase4-move-effect-inventory.md) marks every
family here `B`. All the damaging ones are admitted today through the
positive-power fallback (`BattleEngine:supportsMove`,
`src/core/BattleEngine.lua:1531-1598`), so today they are **plain hits at
their record power**. Return, Frustration, Present, Hidden Power and Low
Kick hit at power 1. Rollout and Ice Ball hit at a flat 30, Fury Cutter at a
flat 10. Defense Curl is rejected.

| Effect | Moves | Today | Inventory row |
| --- | --- | --- | --- |
| 122 `EFFECT_PRESENT` | 217 Present | plain hit, power 1 | `:228` |
| 119 `EFFECT_FURY_CUTTER` | 210 Fury Cutter | plain hit, power 10 | `:225` |
| 117 `EFFECT_ROLLOUT` | 205 Rollout, 301 Ice Ball | plain hit, power 30, no lock | `:223` |
| 156 `EFFECT_DEFENSE_CURL` | 111 Defense Curl | rejected | `:262` |
| 121 `EFFECT_RETURN` | 216 Return | plain hit, power 1 | `:227` |
| 123 `EFFECT_FRUSTRATION` | 218 Frustration | plain hit, power 1 | `:229` |
| 135 `EFFECT_HIDDEN_POWER` | 237 Hidden Power | plain Normal hit, power 1 | `:241` |
| 196 `EFFECT_LOW_KICK` | 67 Low Kick | plain hit, power 1 | `:302` |

Abbreviations follow the earlier proposals. `bsc.c` is
`src/battle_script_commands.c`, `bs1.s` is `data/battle_scripts_1.s`,
**`bm.c` is `src/battle_main.c`**, `msg.c` is `src/battle_message.c`, `bu.c`
is `src/battle_util.c`, `pkmn.c` is `src/pokemon.c`, `ai.s` is
`data/battle_ai_scripts.s`, `aisc.c` is `src/battle_ai_script_commands.c`,
`moves.h` is `src/data/battle_moves.h`, `battle.h` is `include/battle.h`,
`cb.h` is `include/constants/battle.h`, `ctlp.c`/`ctlo.c` are
`src/battle_controller_player.c`/`_opponent.c`. The scratch copy named
`/tmp/claude-0/bm.c` is `battle_message.c`, so this report calls that file
`msg.c`. Every file cited was fetched fresh from the pin for this proposal.

## Summary

1. **V1, Present (fast lane, engine only):** one `Random() & 0xFF` after
   accuracy and PP. Below 204 the move hits at 40, 80 or 120. Otherwise it
   **heals the target** by `maxHP/4`, or prints "HP is full!". No new state.
2. **V2, Fury Cutter (full relay, engine only):** a per-battler counter from
   0 to 5, so power is 10, 20, 40, 80, then 160 from the fifth hit on. It
   resets on a miss or no-effect, at every `CancelMultiTurnMoves` call, on
   any item action (only the ball throw is represented, F5), on a failed run,
   and at faint and switch-in. **It does not reset when the user uses a
   different move.**
3. **V3, Rollout/Ice Ball plus Defense Curl (full relay, engine only):** a
   5-hit lock that uses `STATUS2_MULTIPLETURNS`, with power 30, 60, 120, 240,
   480. The power doubles again after Defense Curl, which sets a sticky
   status2 bit. Any miss, no-effect or protected hit cancels the lock.
   Locked turns spend no PP, **except a protected locked turn, which spends
   one** (as Rampage's protected locked turn does; the families differ only
   on an unprotected locked miss, F2).
4. **V4, Return/Frustration/Hidden Power, split as V4a / H1 / V4b (F4,
   D1, D2):** the formulas are pure. **No battler that the engine receives
   carries friendship or IVs today.** The save record and the generated
   instances do hold them, but `BattlePartyBridge` drops them.
   - **V4a (engine only, fast lane):** optional `friendship`/`ivs` battler
     opts, the formulas, the Hidden Power defrost exclusion (F1), and a
     battler-aware unsupported gate when an attacker lacks the data.
   - **H1 (party/Dex owner):** the bridge and factory lines that fill those
     opts. Not a prerequisite for anything except V4b.
   - **V4b (after H1):** bridge tests and the final inventory flip.
5. **V5, Low Kick (deferred):** it needs the target's Pokédex weight
   (`gPokedexEntries[].weight`). **No weight data exists anywhere in the
   project**: there is no importer, no ROM address and no catalog field. It
   must come from the ROM through a new Dex importer (hand-off H2). The
   engine has no exact default, so it stays deferred.

No slice changes `main.lua`, `AICheckBadMove.lua` (every AI row is already
ported), `TrainerAI.lua` or `EarlyRivalAI.lua`.

## Data availability

What each family reads in source, and whether the engine's battler has it
today:

| Family | Reads (source) | Engine battler today | Where the data exists in the project |
| --- | --- | --- | --- |
| Present | target `hp`, `maxHP` | yes | n/a |
| Fury Cutter, Rollout, Defense Curl | battle-only counters and bits | new battle-only fields | n/a (no save data) |
| Return/Frustration | attacker `gBattleMons[].friendship` | **no** | player party: `decoded.substructs[0].friendship` (`BoxPokemonCodec.lua:161`). Wild/temporary: `instance.boxData.substructs[0].friendship` (`WildPokemonFactory.lua:169-172`, written at `:244`; the bridge can read it there, F13). Trainer: **not in the instance**; source value is `gSpeciesInfo[species].friendship` (`pkmn.c:1815`), which is `catalog.species[s].friendship` (`import/SpeciesInfo.lua:75`) |
| Hidden Power | attacker's six IVs | **no** | player party: `decoded.substructs[3].ivs` (`BoxPokemonCodec.lua:210-217`). Wild/temporary: `instance.ivs` (`WildPokemonFactory.lua:257`). Trainer: `instance.ivs` (`TrainerPokemonFactory.lua:123`, all six = `iv*31/255`) |
| Low Kick | target `gPokedexEntries[SpeciesToNationalPokedexNum(species)].weight` | **no** | **nowhere.** Only the species-to-national map exists (`import/PokedexOrder.lua:45`, `import/RomAddresses.lua:71`) |

The source copies these values into the battle struct once, at switch-in
(`ctlp.c:1540-1547` and `ctlo.c:475-482` copy `friendship` and the six IVs).
An in-battle level-up adjusts the **party** friendship
(`bsc.c:3314`, `AdjustFriendship(..., FRIENDSHIP_EVENT_GROW_LEVEL)`), but
the refresh that follows rewrites only level, HP and stats
(`bsc.c:3316-3329`), so `gBattleMons[].friendship` keeps the switch-in
value. **A snapshot taken when the battler is built is therefore exact**,
including the snapshot from main.lua's rebuild on a switch.

Precondition (F12): this holds because the project applies level-up
friendship after the battle (`EarlyRivalRewards.lua:121-127`), so the party
value cannot drift during a battle today. When in-battle EXP lands, a
mid-battle switch-in rebuild must read the battle-time party friendship:
source re-copies the updated party value at that switch-in.

How the values are lost today:

- `BattlePartyBridge.battlerFromParty` (`src/core/BattlePartyBridge.lua
  :124-152`) decodes the BoxPokemon. It copies species, level, stats, HP,
  types, moves, personality, nature, ability and status, but **not
  friendship or IVs**. It returns `decoded` as its second value, but the
  main.lua callers ignore it, except at `:1634` and `:1690`, where they read
  only the nickname.
- `BattlePartyBridge.battlerFromGenerated` (`:156-174`) copies neither
  field, although the wild instance has `ivs` and `boxData`.
- The trainer instance (`TrainerPokemonFactory.lua:121-128`) has `ivs` but
  no friendship and no `boxData`.
- `BattleEngine.makeBattler` (`src/core/BattleEngine.lua:1126-1240`) has no
  `friendship` or `ivs` option.

There is no engine-only route. `BattleEngine.new` gets its battlers from
main.lua, and the engine has no species table. Every option goes through
the bridge, which is the battle side of the party boundary. The status
groundwork slice S1 edited `persistPartyBattler` under a battle task, so
there is precedent. Whether the bridge counts as "party code" is decision
D1.

### Engine-side defaults considered and rejected

- Friendship: the only exact default is the species base friendship, and
  only for foes (trainer and wild mons start there, `pkmn.c:1815`, and
  `CreateNPCTrainerParty` never overrides it, `bm.c:1539-1640`). The engine
  cannot see the species table. For the player any default invents a value,
  and Return's power ranges from 1 to 102. Rejected (AGENTS rule 8).
- IVs: no default exists. Hidden Power's type and power come entirely from
  the IVs. Rejected.
- Weight: no default exists. The bands give power 20 to 120. Rejected.

So option (b), a hand-off, applies to V4 and V5. **D1 is settled: the
bridge and the factories are party code**, so H1 goes to the party/Dex
owner and no V4 package lists those lines in its MAY CHANGE. V4a lands
without them (see "V4a" under Design).

## Other blocked families checked against "only battler data is missing"

| Family | Missing input | Included? | Why |
| --- | --- | --- | --- |
| 169 Facade, 171 Smelling Salt | status1 | already represented | `BattleEngine.lua:3293-3302` |
| 99 Flail/Reversal, 190 Eruption/Water Spout, 203 Weather Ball, 126 Magnitude, 88 Psywave | HP, level, weather, RNG | already represented | n/a |
| 156 Defense Curl | none: a battle-only bit | **yes, in V3** | Its only consumer is Rollout (`bsc.c:8189`), and it needs no data |
| 154 Beat Up | each eligible party member's base Attack and Defense, level, status and HP | no | Reads the **whole party**, not the battler. It also needs a per-member hit loop and texts |
| 120 Attract | gender (`battlerFromParty` never sets `gender`; see the note at `PartyScreen.lua:83`) | no | It also needs the infatuation lifecycle and action cancellation |
| 105 Thief, 188 Knock Off, 177 Trick, 184 Recycle | held item (`substructs[0].heldItem`, not passed) | no | They also need item transfer, persistence and settlement |
| 197 Secret Power, 173 Nature Power, 213 Camouflage | battle terrain | no | Terrain is battle-environment data, not battler data, and Nature Power needs called-move dispatch |
| 34 Pay Day | money accumulator | no | Post-battle settlement |
| 128 Pursuit, 185 Revenge, 89/144 Counter/Mirror Coat | action or damage history | no | Not battler data |

## Source facts

### 1. How the power override plugs into damage

- `Cmd_damagecalc` (`bsc.c:1209-1216`) passes `gDynamicBasePower` and
  `gBattleStruct->dynamicMoveType` to `CalculateBaseDamage`.
- `CalculateBaseDamage` (`pkmn.c:2383`, F11) checks `if (!powerOverride)` and
  then uses `gBattleMoves[move].power` (`:2398-2401`). It uses the record
  type unless `typeOverride` is set (`:2403-2406`). The physical/special
  split follows that type (`IS_TYPE_PHYSICAL`, `battle.h:475`).
- **A zero override falls back to the record power.** Return at friendship
  0-2 and Frustration at 253-255 compute 0, so they hit at record power 1.
- Both values reset to 0 at turn start (`bm.c:3695-3696`) and after each
  action (`bm.c:4470`). The AI resets them before every damage estimate
  (`aisc.c:981`, `:1205`), so **the AI always sees the record power and
  type**.
- Engine fit: the local move copy already used by Flail, Eruption and
  Weather Ball (`BattleEngine.lua:2076-2105`). It carries `power`, and for
  Weather Ball `type`, to every reader without touching the shared ROM
  record.

### 2. Return / Frustration (121/123)

- Script (`bs1.s:1653-1658`): attackcanceler, accuracycheck (a miss goes to
  PrintMoveMissed), `friendshiptodamagecalculation`, then the ordinary hit
  from `HitFromAtkString`.
- `Cmd_friendshiptodamagecalculation` (`bsc.c:8228-8236`): Return
  `10 * friendship / 25`, Frustration `10 * (255 - friendship) / 25`
  (integer division).
- Oracles: friendship 255 gives Return 102, Frustration 0 (so power 1).
  Friendship 70 gives 28 and 74. 128 gives 51 and 50. 0 gives Return 0
  (so power 1) and Frustration 102. 3 gives 1 and 100.
- Records (`moves.h:2811`, `:2837`): Normal, power 1, accuracy 100, contact,
  protect-affected. No RNG beyond the ordinary accuracy, crit and damage
  draws.

### 3. Hidden Power (135)

- Script (`bs1.s:1735-1738`): attackcanceler, `hiddenpowercalc`, then
  `goto BattleScript_HitFromAccCheck`. The type and power are fixed **before
  accuracy**.
- `Cmd_hiddenpowercalc` (`bsc.c:8503-8530`):
  - `powerBits` takes bit 1 of each IV, and `typeBits` takes bit 0. The
    order is HP, Atk, Def, Spe, SpA, SpD, from bit 0 to bit 5.
  - power = `40 * powerBits / 63 + 30` (30 to 70).
  - type = `15 * typeBits / 63 + 1`. If the result is 9 or more
    (`TYPE_MYSTERY`) it is incremented. `dynamicMoveType` then gets
    `F_DYNAMIC_TYPE_1 | F_DYNAMIC_TYPE_2`.
- Type by `typeBits`: Fighting 0-4, Flying 5-8, Poison 9-12, Ground 13-16,
  Rock 17-20, Bug 21-25, Ghost 26-29, Steel 30-33, Fire 34-37, Water 38-41,
  Grass 42-46, Electric 47-50, Psychic 51-54,
  Ice 55-58, Dragon 59-62, **Dark only at 63** (every IV odd). Never Normal
  or `???`.
- The dynamic type reaches these readers through `GET_MOVE_TYPE`
  (`battle.h:469-470`):
  - Hustle's accuracy term (`bsc.c:1038`, `:1073`);
  - the physical/special split, Thick Fat and the pinch abilities in
    `CalculateBaseDamage`;
  - the weather terms;
  - STAB and effectiveness in `typecalc` (`bsc.c:1285`).
- **It does not reach the `datahpupdate` damage record or, through it, the
  move-end defrost (F1).** `Cmd_datahpupdate` picks its own `moveType`
  (`bsc.c:1751-1756`): the record type when `dynamicMoveType == 0`, the
  dynamic type only when `F_DYNAMIC_TYPE_1` is clear, and **the record type
  otherwise**. Hidden Power sets `F_DYNAMIC_TYPE_1 | F_DYNAMIC_TYPE_2`
  (`bsc.c:8527`); Weather Ball sets only `F_DYNAMIC_TYPE_2`
  (`bsc.c:9352-9360`). So `datahpupdate` sees Normal (physical,
  `battle.h:475`) and records `physicalDmg`, never `specialDmg`
  (`bsc.c:1823-1843`). `MOVEEND_DEFROST` needs `specialDmg` **and**
  `moveType == TYPE_FIRE` (`bsc.c:4103-4109`), so **a Fire Hidden Power
  never thaws a frozen target**, while a Fire Weather Ball does. This is
  **not** the Weather Ball reader set: V4a must exclude Hidden Power from
  the engine's move-end defrost (`BattleEngine.lua:1625-1631`, which tests
  only `currentMove.type == TYPE_FIRE` and damage dealt).
- Known limit for later Counter/Mirror Coat work: Hidden Power always
  records physical damage, whatever its type.
- Trainer oracles: party `iv` 0 makes every IV 0, so Fighting at 30 power.
  `iv` 255 makes every IV 31, so Dark at 70 power. The scaled IV is
  `iv * 31 / 255` (`bm.c:1576`, `:1588`, `:1606`, `:1620`).
- Record (`moves.h:3084`): Normal, power 1, accuracy 100, not contact. No
  extra RNG.

### 4. Low Kick (196), deferred

- Script (`bs1.s:2550-2556`): attackcanceler, attackstring, ppreduce,
  `weightdamagecalculation`, `accuracycheck BattleScript_MoveMissedPause`,
  then `HitFromCritCalc`. "Used" and PP come before the miss.
- `Cmd_weightdamagecalculation` (`bsc.c:9074-9089`) looks up the target's
  weight with `GetPokedexHeightWeight(SpeciesToNationalPokedexNum(target
  species), 1)` (`src/pokedex.c:11-22`, `pkmn.c:5210-5216`).
- It walks `sWeightToDamageTable` (`bsc.c:756-764`) with a strict `>`. In
  hectograms: weight below 100 gives 20, 100-249 gives 40, 250-499 gives 60,
  500-999 gives 80, 1000-1999 gives 100, and 2000 or more gives 120.
- Data: `struct PokedexEntry` (`include/pokedex.h:102-114`, size 0x24) has
  `u16 weight` at +0x0E. `gPokedexEntries` is indexed by national dex
  number (`src/data/pokemon/pokedex_entries.h:1`).

### 5. Present (122)

- Script (`bs1.s:1660-1666`): attackcanceler, `accuracycheck
  BattleScript_PrintMoveMissed`, attackstring, ppreduce, **typecalc**,
  `presentdamagecalculation`.
- `Cmd_presentdamagecalculation` (`bsc.c:8238-8264`) draws one
  `Random() & 0xFF` (`rand`):
  - `rand < 102` gives power 40, `< 178` gives 80, `< 204` gives 120. Each
    then goes to `BattleScript_HitFromCritCalc`, the ordinary crit, damage,
    typecalc, adjust and hit.
  - `rand >= 204`: heal amount = target `maxHP / 4`, minimum 1, negated.
    - If the target is at full HP: `BattleScript_AlreadyAtFullHp`
      (`bs1.s:2038-2042`), "<target>'s HP is full!".
    - Otherwise it **clears `MOVE_RESULT_DOESNT_AFFECT_FOE`** and runs
      `BattleScript_PresentHealTarget` (`bs1.s:2028-2036`). That script
      ignores Substitute, applies the heal through
      `healthbarupdate`/`datahpupdate` (clamped at maxHP) and prints
      "<target> regained health!".
- Consequences:
  - The heal branch heals a **Ghost-type target**: the pre-roll typecalc set
    `DOESNT_AFFECT_FOE`, and the heal branch clears it.
  - The damage branch against a Ghost runs `HitFromCritCalc`: crit,
    damage, typecalc, adjust draws, then "It doesn't affect".
  - The pre-roll typecalc multiplies a stale `gBattleMoveDamage`. That value
    is unobservable because damagecalc or the heal overwrites it. Its
    result flags are set again by the second typecalc.
  - Wonder Guard in that typecalc would leave `MISSED` set, so the heal text
    prints with no HP change. Wonder Guard is not modeled in the engine;
    record it as a limit.
  - Recorded limits (D4): the heal ignores Substitute (unmodeled); Wonder
    Guard's leftover `MISSED`; and the pre-roll typecalc's
    `targetNotAffected` mark on a Ghost target, which is unobservable for a
    non-locking move, so the engine does not set it.
- RNG:
  - damage branch: accuracy, Present, crit, damage random, plus the tracked
    plain-hit `seteffectwithchance` gap (see "RNG notes");
  - heal or full HP: accuracy and Present only;
  - miss: accuracy only;
  - semi-invulnerable (Fly/Dig) target: **nothing** (F7).
    `AccuracyCalcHelper` jumps to `PrintMoveMissed` before `Random()`
    (`bsc.c:1040-1043`); the text is "missed" and PP is spent;
  - protected (P1 gate): nothing, and the protected text, because
    accuracycheck re-tests protect first.
- Record (`moves.h:2824`): Normal, power 1, accuracy 90, protect-affected,
  not contact.

### 6. Fury Cutter (119)

- Script (`bs1.s:1627-1639`): attackcanceler, attackstring, ppreduce, then
  `accuracycheck BattleScript_FuryCutterHit`. **Both the hit and the miss
  jump to the same label.** Then `furycuttercalc`, critcalc, damagecalc,
  typecalc, `jumpifmovehadnoeffect BattleScript_FuryCutterHit` (back to the
  calc), adjustnormaldamage, and the hit animation and texts.
- `Cmd_furycuttercalc` (`bsc.c:8205-8226`):
  - If `NO_EFFECT` (miss, protected, semi-invulnerable miss, or no-effect
    after typecalc): `furyCutterCounter = 0` and `MoveMissedPause` (the miss
    or protected text).
  - Otherwise: counter `++` unless it is already 5. Power = 10 doubled
    `counter - 1` times, so 10, 20, 40, 80, 160 and then 160.
- The counter is `gDisableStructs[].furyCutterCounter` (`battle.h:155`). It
  is zeroed by switch-in (`bm.c:2383`) and faint (`bm.c:2458`). **The
  pinned source has exactly four writers:**
  1. `furycuttercalc`, the increment, and the reset on `NO_EFFECT`;
  2. `CancelMultiTurnMoves` (`bu.c:203-214`, `:213`);
  3. `ClearFuryCutterDestinyBondGrudge` (`bu.c:3041-3046`), called by
     `HandleAction_UseItem` (`bm.c:4155`) **before it branches on the item**
     (`bm.c:4150-4157`), so on every item action: balls, Poké Doll/Fluffy
     Tail, Poké Flute, player bag items and trainer AI items (F5; only the
     capture action is represented today), and by a failed run
     (`bm.c:4311`);
  4. the disable-struct clears above (`bm.c:2382-2384`, `:2457-2459`, F11).
- **Using a different move does not reset the counter.** Fury Cutter,
  Tackle, Fury Cutter gives 10, then 20.
- Reset through `CancelMultiTurnMoves`, for any user and whether or not it
  is locked:
  - flinch (`bu.c:1366`);
  - full paralysis (`bs1.s:3717`);
  - confusion self-hit (`bs1.s:3742`);
  - the recharge canceller (`bu.c:1354`);
  - sleep or freeze being applied (`bsc.c:2173`, `:2269`);
  - **attackcanceler's protect step on any of the user's protected moves**
    (`bsc.c:896-906`). A protected Tackle also resets a Fury Cutter streak.
  - Unmodeled callers: Truant `:1340`, Disable `:1378`, Taunt `:1389`,
    Imprison `:1400`, infatuation `:1476`, Torment `:319`, Uproar `:933/944`,
    Yawn `:1040`, Spite `bsc.c:7982`.
  - The end-of-turn sleep cancel (`bm.c:2941-2942`) needs `MULTIPLETURNS`,
    so it does not touch a Fury Cutter user.
  - Two modeled callers were missing from this list (F9): the engine's
    end-of-turn sleep cancel (`BattleEngine.lua:4166`) and the Rampage
    `WasUnableToUseMove` cancel (`:4434`, mirroring `bu.c:958`). Both reset
    the counter once V2 edits `cancelMultiTurnMoves`. `bsc.c:6071` is the
    `cancelmultiturnmoves` script command itself.
- The counter survives the target fainting and a replacement coming in.
- RNG: hit draws accuracy, crit, damage. A miss draws accuracy only. A
  protected or semi-invulnerable miss draws nothing. Bug has no 0x matchup,
  and Wonder Guard is not modeled, so the "no effect after crit" loop is
  unreachable in this engine. In source it would spend the crit draw but not
  the damage random.
- Record (`moves.h:2733`): Bug, power 10, accuracy 95, contact.

### 7. Rollout / Ice Ball (117)

- Script (`bs1.s:1592-1602`): attackcanceler, attackstring, `jumpifstatus2
  BS_ATTACKER, STATUS2_MULTIPLETURNS, BattleScript_RolloutCheckAccuracy`
  (skips ppreduce), ppreduce, `accuracycheck BattleScript_RolloutHit` (the
  hit and miss share the label), typecalc2, `rolloutdamagecalculation`, then
  `HitFromCritCalc`.
- `Cmd_rolloutdamagecalculation` (`bsc.c:8161-8193`):
  - If `NO_EFFECT` (miss, protected, semi-invulnerable, or typecalc2
    immunity): `CancelMultiTurnMoves(attacker)` and `MoveMissedPause`.
  - Otherwise:
    - First hit, when `MULTIPLETURNS` is clear: `rolloutTimer = 5`,
      start value 5, set `MULTIPLETURNS`, set `gLockedMoves`.
    - `--rolloutTimer`. At 0 it clears `MULTIPLETURNS`, so the fifth hit
      ends the lock.
    - Power = record power doubled `4 - timer` times: 30, 60, 120, 240, 480.
    - Doubled again when `STATUS2_DEFENSE_CURL` is set (`:8189`), up to 960.
- Locking reuses M1: `MULTIPLETURNS` locks action selection (`bm.c
  :3125-3130`) and bypasses the 0-PP check (`bsc.c:838-839`). The lock
  survives the target fainting.
  - `CancelMultiTurnMoves` clears it and `rolloutTimer` (`bu.c:212`) at the
    callers listed under Fury Cutter.
  - A sleeping user is cancelled at end of turn (`bm.c:2941-2942`).
  - A freeze that is already present keeps the lock, as for M1 charges.
- **Protect:**
  - `IsTwoTurnsMove` (`bsc.c:7821-7832`) does not list Rollout, so the
    protect step cancels the lock (`bsc.c:898-900`) **before** the script's
    `jumpifstatus2`.
  - A protected **locked** turn therefore reaches ppreduce and **spends one
    PP**. `Cmd_ppreduce` deducts only while PP is above 0 (`bsc.c:1147`,
    F11).
  - **This is the same as Rampage on a protected locked turn (F2).**
    Rampage's lock is also cancelled by the protect step, and its
    accuracycheck re-test jumps to `PrintMoveMissed`, which runs the
    guarded ppreduce (`bs1.s:276-278`; engine
    `rampageLocked and not hit and slot.pp > 0`, `BattleEngine.lua
    :2785-2788`).
  - The real difference is the **unprotected locked miss** (an accuracy
    miss or a semi-invulnerable miss): Rampage spends one PP through
    `PrintMoveMissed`; Rollout spends **none**, because `MULTIPLETURNS` is
    still set at `jumpifstatus2` (`bs1.s:1595`) and the miss jumps straight
    to `RolloutHit`.
  - Accuracycheck then re-tests protect: `MISSED`, `RolloutHit`, cancel
    again (a no-op), and the protected text.
- **Semi-invulnerable target:** `AccuracyCalcHelper` misses, the miss jumps
  to `RolloutHit`, and **the lock is cancelled**. Rampage keeps its lock in
  this case (M3).
- First turn: PP is spent before accuracy, so a first-turn miss costs PP and
  sets no lock.
- Rock and Ice have no 0x matchup and Levitate only stops Ground, so the
  typecalc2 no-effect is unreachable in this engine.
- RNG on every turn, locked or not: hit draws accuracy, crit, damage. A miss
  draws accuracy only. A protected or semi-invulnerable miss draws nothing.
- Records (`moves.h:2668`, `:3916`): Rock and Ice, power 30, accuracy 90,
  contact.

### 8. Defense Curl (156)

- Script (`bs1.s:2010-2021`): attackcanceler, attackstring, ppreduce,
  **`setdefensecurlbit`** (`bsc.c:8472-8476`), then DEF +1 through
  `statbuffchange`. It follows the ordinary stat-up path, `StatUpDoAnim` /
  `StatUpPrintString` (`bs1.s:503-510`), including "won't go higher!" at +6.
  At +6 `ChangeStatBuffs` returns WORKED with `B_MSG_STAT_WONT_INCREASE` and
  sets `MISSED` (`bsc.c:6796-6815`); Defense Curl's `jumpifbyte` goes to
  `StatUpPrintString` **without** the `pause B_WAIT_TIME_SHORT` that effect
  11 runs first (`bs1.s:2016` vs `:493-495`). The text is identical and the
  `MISSED` flag is unobservable in the engine (F10).
- **The bit is set even at +6.** `STATUS2_DEFENSE_CURL` (`cb.h:130`) has no
  other writer or reader except Rollout (grep of the pin). It persists until
  faint (`bm.c:2441`) or switch-out (`bm.c:2367`; Baton Pass's mask at
  `:2352` does not keep it).
- Self-target, so protect never applies. No RNG. Record (`moves.h:1446`):
  power 0, `MOVE_TARGET_USER`.

### 9. Texts

No new strings.

- Present heal: "regained\nhealth!" (`msg.c:124`). Present at full HP:
  "'s\nHP is full!" (`msg.c:125`). Both name the **target** (`B_DEF_NAME`).
  They already exist as the `restoreHP` / `restoreHPFull` events
  (`BattleSceneController.lua:323-330`), which name `event.side`.
- Defense Curl uses the existing stat-up texts.
- The other families use "used", damage, effectiveness, "missed" and the
  protected text.

### 10. AI rows (`ai.s`)

- `AI_CheckBadMove`: Return `:171`, Present `:172`, Frustration `:173` and
  Low Kick `:206` go to `AI_CBM_HighRiskForDamage` (`:372`). Defense Curl
  `:186` goes to `AI_CBM_DefenseUp` (`:254`).
- Rollout, Ice Ball, Fury Cutter and Hidden Power have no row.
- Moves with power 1 or less are `MOVE_POWER_DISCOURAGED`
  (`aisc.c:966-1022`), so Hidden Power never reaches the immunity check.
  The AI always types Hidden Power as Normal (`aisc.c:981`, `:1205`).
- **All of these rows are already ported** (`AICheckBadMove.lua:631-633`,
  `:645`, `:664`, plus the power gate at `:702`). No AI change is needed.
  The other script references stay out of scope, as in earlier slices
  (labels corrected, F6): `ai.s:2846` is
  `AI_SetupFirstTurn_SetupEffectsToEncourage` (Defense Curl), `:2891` is
  `AI_Risky_EffectsToEncourage` (Present) and `:3203` is
  `AI_HPAware_DiscouragedEffectsWhenTargetLowHP` (Fury Cutter). Defense
  Curl's `AI_CheckViability` references are `AI_CV_Protect` (`:2024`) and
  `AI_CV_Snatch` (`:2681`). None of these scripts is ported for general
  trainers: `TrainerAI.choose` accepts only flags 0, 0x1 and the Oak-lab
  0x7 (`TrainerAI.lua:137-150`), and `EarlyRivalAI` accepts only Tackle,
  Scratch, Growl and Tail Whip (`EarlyRivalAI.lua:1-6`, `:79`). So "no AI
  change needed" stands.

## Engine today (fit points)

- `makeBattler` (`BattleEngine.lua:1126-1240`): add battle-only fields.
  `furyCutterCounter = 0`, `rolloutTimer = 0` and `defenseCurl = false` go
  in V2/V3. `friendship` and `ivs` are optional opts in V4.
- `recordFaint` (`:1400-1452`) clears the V2/V3 fields. A switch-in builds a
  fresh battler, so those fields start clear.
- `cancelMultiTurnMoves` (`:1926-1931`): also clear `rolloutTimer` and
  `furyCutterCounter`. It is already called at flinch, full paralysis,
  confusion self-hit, recharge, sleep/freeze application and the protect
  step (`:1684`, `:1691`, `:1713`, `:1760`, `:1844`, `:1862`, `:2221`), and
  at the end-of-turn sleep cancel (`:4166`) and the Rampage
  `WasUnableToUseMove` cancel (`:4434`) (F9).
- `isLocked` (`:1939-1942`): add `rolloutTimer > 0`. Also update the locked
  0-PP check (`:2150-2156`) and the `lockedTurn` set (`:2034-2044`).
- End-of-turn sleep cancel (`:4165`): add `rolloutTimer > 0` to the
  `MULTIPLETURNS` test.
- Local move copy (`:2076-2105`): Return, Frustration and Hidden Power
  (power plus type, with a no-defrost marker for Hidden Power, F1) before
  the cancellers. Rollout and Fury Cutter set
  their power after accuracy (see below).
- Ordinary accuracy and PP (`:2757-2790`), then crit (`:3271`): Present's
  roll and branch sit between them. Rollout's PP skip goes here too.
- `runTurn` capture (`:4620`) and failed run (`:4663-4680`): reset the
  player's `furyCutterCounter`.

## Design

### V1: Present (122)

- In `resolveMoveCore`, Present takes the ordinary path: accuracy (with the
  P1 protected re-test), PP, then `rand = rng:next16() % 256` (`& 0xFF`).
- `rand < 204`: local copy with power 40, 80 or 120, then the ordinary
  crit, damage, typecalc, random and hit path. A Ghost target gives the
  existing `noEffect`.
- `rand >= 204`:
  - target `hp == maxHP`: emit `restoreHPFull{side = defenderSide}`;
  - otherwise heal `max(1, floor(maxHP/4))` clamped to maxHP and emit
    `restoreHP{side = defenderSide, beforeHP, hpRemaining, amount}`.
  - Type immunity is ignored. Crit and damage random are not drawn. This
    does not count as move damage (`tookMoveDamage` unchanged), does not
    advance Oak's tutorial flag, and does not thaw.
  - A Fly/Dig target misses with no draw at all (F7); PP is spent.
  - Limits (D4): Substitute, Wonder Guard's leftover `MISSED`, and the
    unobservable `targetNotAffected` mark on a Ghost target.
  - The controller comment on `restoreHP` ("the heal target is the user")
    becomes stale and is updated: the event names the healed side.
- New event fields: none. A `present` event is not needed, because source
  prints nothing for the roll.
- Fast lane: one family, no new state.

### V2: Fury Cutter (119)

- State: `furyCutterCounter` (0-5), battle-only.
- After the accuracy and PP step:
  - Miss, protected or semi-invulnerable miss: counter 0, then the existing
    miss or protected event.
  - Hit: `if counter ~= 5 then counter = counter + 1 end`. Local copy power
    = `10 * 2^(counter-1)`, then the ordinary hit.
  - A post-typecalc `noEffect` (unreachable today) would also reset the
    counter.
- Resets: `cancelMultiTurnMoves` (all existing callers, including the
  protect step for **any** move and the two F9 callers), `recordFaint`, the
  player's capture action (any item action in source; only capture is
  represented, F5), and a failed run. A switch-in is a fresh battler, so it
  starts at 0. **No reset when the user uses another move.**
- Full relay (cross-turn state).

### V3: Rollout / Ice Ball (117) and Defense Curl (156)

- State: `rolloutTimer` (0-5; for this family "nonzero" equals
  `MULTIPLETURNS`) and `defenseCurl` (bool), both battle-only.
- PP (F3): capture **one** value, `rolloutLocked = rolloutTimer > 0`,
  right after the protect step's `cancelMultiTurnMoves` (unlike
  `rampageLocked`, which is captured before it) and **before** the hit
  branch changes the timer. The PP block and the 0-PP bypass both read that
  value: spend one PP unless `rolloutLocked`. So a protected locked turn
  spends one PP while above 0, hit 1 spends one, hits 2-5 spend none, and
  an unprotected locked miss spends none (F2).
- After accuracy:
  - Miss, protected or semi-invulnerable miss: `cancelMultiTurnMoves`, then
    the miss or protected event.
  - Hit: if `rolloutTimer == 0`, set it to 5 and set `lockedSlot`. Then
    `rolloutTimer = rolloutTimer - 1`; at 0 the lock clears: the fifth hit
    sets `lockedSlot = nil` with the same `not recharging` guard as
    `cancelMultiTurnMoves` (`:1930`), as Rampage does at `:4436` (F3).
  - Power = `30 * 2^(4 - rolloutTimer)`, times 2 if `defenseCurl`. Then the
    ordinary hit.
- Lock plumbing: add `rolloutTimer > 0` to `isLocked`, to `lockedTurn` and
  the 0-PP bypass, and to the end-of-turn sleep cancel. The controller's M1
  auto-run needs no change.
- Defense Curl: admit 156 in `supportsMove` (power 0, `MOVE_TARGET_USER`).
  Set `defenseCurl = true` after PP and before the DEF +1 branch, which
  reuses the `STAT_STAGE_MOVES` defense +1 path ("won't go higher!" at +6:
  the same text as effect 11; source only skips effect 11's short pause,
  F10). Clear it in `recordFaint`.
- Full relay (cross-turn state, lock change).

### V4: Return / Frustration / Hidden Power (121/123/135), split V4a / H1 / V4b

D1 makes the bridge and factories party code, and D2 forbids a silent
fallback, so V4 splits (F4).

- **V4a (engine only, fast lane):**
  - `makeBattler` accepts optional `opts.friendship` (0-255) and
    `opts.ivs` (`{hp, attack, defense, speed, spAttack, spDefense}`). The
    precedent is `catchRate`, optional and asserted only at use
    (`BattleEngine.lua:1129-1133`, `:4622`).
  - The local copy sets:
    - Return: `power = floor(10*f/25)`, Frustration
      `floor(10*(255-f)/25)`, with **0 replaced by the record power**
      (`pkmn.c:2398-2399`);
    - Hidden Power: `power` and `type` as in §3, before accuracy, plus a
      marker that excludes it from the move-end defrost (F1).
  - Effects 121/123 for an attacker with no `friendship`, and 135 for one
    with no `ivs`, are **unsupported for that attacker**, through a
    battler-aware `supportsMove`. The controller already turns an
    unsupported player move into "That move's effect is not available
    yet." with no turn and no RNG (`BattleSceneController.lua:715-721`). A
    foe reaches the existing resolution error (`BattleEngine.lua
    :2071-2074`), exactly as every other `B` effect does today.
  - Tests use synthetic battlers that carry the opts, plus one test that
    shows the unsupported gate when they are absent.
  - Inventory rows read "represented when the battler carries
    friendship/IVs; needs H1".
  - Behavior change to note: these are TM moves (TM27/TM21/TM10), so the
    live reach is player mons taught them and custom-move trainer parties.
    V4a turns them from a silently wrong plain hit into a visible "not
    available yet" (player) or an unsupported-effect error (foe), the same
    treatment Defense Curl gets today. **Before merging V4a, confirm against
    the ROM fixture that no trainer reachable in the currently playable
    area carries 216/218/237 in custom moves.** If one does, V4a waits for
    H1.
- **H1 (party/Dex owner):** the hand-off below.
- **V4b (small, after H1):** bridge tests and the final inventory flip.
- Keeping today's silent power-1 Normal hit as the fallback is **not**
  acceptable: it is known-wrong behavior in a row that would be marked
  represented (AGENTS rules 8 and 9).

### V5: Low Kick (196), deferred

- Engine, once data exists: read the target's `weight` (hectograms) and use
  the band from §4, after PP and before accuracy. It draws nothing.
- Blocked on H2. The inventory row stays `B` with the reason "species weight
  not imported".

## Hand-off notes for the party/Dex owner

### H1: friendship and IVs into battlers (needed by V4b only)

The self-contained note for the owner is
[`work/handoffs/2026-10-21-battle-friendship-ivs-handoff.md`](../handoffs/2026-10-21-battle-friendship-ivs-handoff.md).
H1 is not a prerequisite for V1, V2, V3, V4a or V5. Fields to add to the
battler opts. No `main.lua` change; every main.lua
call site (`:1241`, `:1280`, `:1313`, `:1403`, `:1405`, `:1540`, `:1542`,
`:1553`, `:1634`, `:1690`) keeps working.

1. `BattlePartyBridge.battlerFromParty` (`:124-152`): pass
   `friendship = decoded.substructs[0].friendship` and `ivs =
   decoded.substructs[3].ivs` (a copy) to `makeBattler`.
2. `BattlePartyBridge.battlerFromGenerated` (`:156-174`): pass
   `friendship = instance.friendship` and `ivs = instance.ivs`.
3. Optional (F13): `WildPokemonFactory.generate` return table
   (`:252-261`) could add `friendship = speciesInfo.friendship`. It is not
   needed: the bridge can read `instance.boxData.substructs[0].friendship`
   (`WildPokemonFactory.lua:169-172`, written at `:244`), which also covers
   the developer temporary player (`main.lua:1280-1281`).
4. `TrainerPokemonFactory.generate` return table (`:121-128`): add
   `friendship = info.friendship`. Source: `CreateBoxMon`, `pkmn.c:1815`.
   `CreateNPCTrainerParty` never overrides it. `info` is
   `args.speciesInfo`; `friendship` is imported at
   `import/SpeciesInfo.lua:75`. A trainer instance has no `boxData`, so this
   item is needed.
5. `persistPartyBattler` must **not** write either field back: battle never
   changes them.
6. The player starter already stores the species friendship in its record
   (`StarterPokemonFactory.lua:123`), so item 1 covers it.
7. Precondition (F12): when in-battle EXP lands, a mid-battle switch-in
   rebuild must read the battle-time party friendship.

### H2: Pokédex weight (needed by V5)

1. An importer for `gPokedexEntries` (`struct PokedexEntry`, stride 0x24,
   `u16 weight` little-endian at +0x0E, indexed by national dex number).
   Its ROM address is **not** in `import/RomAddresses.lua`, and it must be
   verified against the supported SHA-1 ROM (`UNKNOWN` here).
2. Map species to national dex with the existing
   `PokedexOrder.speciesToNationalDexNum` and `sSpeciesToNationalPokedexNum`.
3. Expose the weight per species, for example as `catalog.species[s].weight`
   at load. The bridge then copies `weight` onto both battlers: Low Kick
   reads the **target**, which may be the player.
4. No weight values may be checked in (no extracted game content). Tests use
   synthetic weights.

## Slices

| Slice | Content | Lane | Data |
| --- | --- | --- | --- |
| V1 | Present (122) | fast lane | none |
| V2 | Fury Cutter (119) | full relay | none |
| V3 | Rollout/Ice Ball (117) plus Defense Curl (156) | full relay | none |
| V4a | Return/Frustration/Hidden Power (121/123/135), engine only | fast lane | none (synthetic battlers) |
| H1 | friendship/IVs into battlers | party/Dex owner | n/a |
| V4b | bridge tests, inventory flip | fast lane | H1 |
| V5 | Low Kick (196) | deferred | H2 |

Order: V1, V2, V3 (separate packages, D3; V3 rebased on V2's
`cancelMultiTurnMoves` edit), V4a, then V4b once H1 lands. V5 waits for H2.
V2 before V3 because V3 extends the same `cancelMultiTurnMoves` resets.

## Verification plan

All checks are no-ROM engine and controller tests with source-derived
oracles and scripted RNG. Each slice's ROM fixture rides along and skips
without a ROM.

- **V1:**
  - Roll values 101, 102, 177, 178, 203 and 204 select 40, 80, 80, 120,
    120 and heal (F8), with exact damage from the record stats.
  - Heal: `maxHP/4`, minimum 1, clamped. A full-HP target gives
    `restoreHPFull`. A Ghost target is healed. The Ghost damage branch gives
    `noEffect` after the crit and damage draws.
  - Draw counts per branch (see "RNG notes"); a miss draws 1; protected
    draws 0 and gives the protected text; a Fly/Dig target draws 0, misses
    and spends PP (F7).
  - Texts name the target.
- **V2:**
  - Consecutive hits give 10, 20, 40, 80, 160, 160.
  - A miss, a protected turn or a Fly target resets to 0.
  - Tackle between two Fury Cutters keeps the counter (20 on the second).
  - A protected Tackle resets it. Flinch, full paralysis, confusion
    self-hit, sleep application, a ball throw (the represented item
    action, F5) and a failed run reset it; so do the end-of-turn sleep
    cancel and the Rampage cancel paths (F9).
  - Faint and switch-in start at 0.
- **V3:**
  - Five-hit sequence 30, 60, 120, 240, 480; the lock is released after
    hit 5; and 960 at hit 5 after Defense Curl.
  - Hit 1 spends 1 PP, hits 2-5 spend 0; after hit 5 `isLocked` is false
    and the next turn offers the menu (F3). A first-turn miss spends PP
    with no lock. A locked Rollout that misses normally, or misses a Fly
    target, spends 0 PP (F2).
  - A locked miss cancels and the next use restarts at 30.
  - A protected locked turn spends one PP and cancels. A locked 0-PP slot
    still hits.
  - A Dig/Fly target cancels the lock.
  - The controller skips the menu and AI for a locked side.
  - Sleep at end of turn cancels.
  - Defense Curl at +6: "won't go higher!" (same text as effect 11, F10)
    and the bit still set.
  - The bit is cleared by faint and switch.
- **V4a:**
  - Friendship oracles 0, 2, 3, 70, 128, 253, 254 and 255 for both moves,
    including the power-1 fallback.
  - A frozen target hit by a Fire Hidden Power stays frozen; a Fire Weather
    Ball control still thaws (F1).
  - Hidden Power: all-0 IVs give Fighting/30, all-31 give Dark/70. A Steel
    case (typeBits 30) and a Fire case (typeBits 34) check effectiveness,
    STAB and the special split.
  - A missing input makes the move unsupported for that attacker: the
    player gets "not available yet" with no turn and no RNG; a foe hits the
    existing resolution error (F4).
- **V4b (after H1):** bridge tests: a party record's friendship and IVs
  reach the battler, as do wild and trainer instances.
- **Inventory:** each slice moves its rows to `represented` and updates
  `tests/phase4_move_effect_inventory_test.lua`.

## RNG notes

- **V1:** Present gains one draw after accuracy on every non-miss,
  non-protected use. The heal branch loses the crit and damage draws.
  **Seeded replays with Present diverge from its first use.**
- **V1, Fly/Dig target:** no draw at all (F7).
- **V2, V3, V4:** no new draws. The changed power changes damage and KO
  timing, not the draw count. V3 makes the battler's later turns locked, so
  it skips the AI choice and its `Random()` for a locked foe (as in M1).
- Pre-existing and unchanged: the tracked plain-hit zero-byte
  `seteffectwithchance` roll gap. In source `Random() % 100` is the first
  operand of the `else if` (`bsc.c:2789-2791`), so every landed hit through
  `HitFromCritCalc` spends it. Every family here inherits that gap from the
  ordinary path.

## Decisions for review

Settled by the review:

- **D1: party code.** `BattlePartyBridge.lua` and the factory return tables
  belong to the party/Dex owner. H1 goes to that owner as a hand-off; no V4
  package lists those lines in its MAY CHANGE.
- **D2: no silent fallback; split V4** into V4a (engine, optional opts,
  formulas, the F1 defrost exclusion, a battler-aware unsupported gate,
  synthetic-battler tests), H1 (owner) and V4b (bridge tests, inventory
  flip). Confirm the F4 ROM-fixture trainer check before merging V4a.
- **D3: separate packages** for V2 and V3, in that order, V3 rebased on
  V2's `cancelMultiTurnMoves` edit.
- **D4: accepted as recorded limits**, widened: Present's heal ignores
  Substitute; Wonder Guard's leftover `MISSED` (heal text with no HP
  change); Present's pre-roll typecalc sets `targetNotAffected` on a Ghost,
  unobservable for a non-locking move; Hidden Power always records physical
  damage (F1), for future Counter/Mirror Coat work.

## Risks

- V3 is the fourth lock family. The `lockedTurn`, 0-PP bypass, end-turn
  sleep and controller paths must all test `rolloutTimer`. Missing one gives
  a menu on a locked turn or Struggle instead of Rollout.
- Rollout's PP rule matches Rampage's on a protected locked turn (both
  spend one, guarded at 0) and differs on an **unprotected locked miss**
  (Rampage spends one, Rollout none) (F2). Do not "invert" Rampage; use the
  single `rolloutLocked` capture (F3). Writing the timer before the PP read
  would skip hit 1's PP and spend on hit 5.
- Fury Cutter resets come from many existing call sites. A new
  `cancelMultiTurnMoves` caller added later must keep resetting the counter
  for unlocked battlers too.
- V4b depends on code another agent owns (H1). V4a does not.
- Hidden Power's type must not reach the engine's move-end defrost (F1).

## Surprising source behaviour (summary)

1. **Fury Cutter is not reset by using a different move.** Only a
   miss/no-effect, `CancelMultiTurnMoves`, a ball throw or failed run, and
   faint or switch reset it.
2. **Any protected move resets the user's Fury Cutter counter** and cancels
   its Rollout, through attackcanceler's `CancelMultiTurnMoves`.
3. **A protected locked Rollout spends one PP.** The protect step clears
   `MULTIPLETURNS` before the script's PP-skip test.
4. **Rollout loses its lock on a semi-invulnerable target**; Rampage keeps
   its lock in that case.
5. **Present's heal branch heals Ghost-type targets.** It clears
   `DOESNT_AFFECT_FOE` from the typecalc that runs before the roll.
6. **Return at friendship 0-2 and Frustration at 253-255 compute power 0,
   which falls back to the record power 1.**
7. **Hidden Power is Dark only when all six IVs are odd** (typeBits 63). It
   is never Normal, and the AI always treats it as Normal.
8. **The Defense Curl bit is set even when Defense is already at +6**, and
   it lasts until faint or switch.
9. **In-battle level-up does not refresh battle friendship**, so a snapshot
   taken when the battler is built is exact (precondition, F12).
10. **A Fire Hidden Power never thaws a frozen target** (F1): its
    `F_DYNAMIC_TYPE_1` flag makes `datahpupdate` record Normal physical
    damage, so `MOVEEND_DEFROST` never fires. A Fire Weather Ball does
    thaw.

## Review corrections applied

| Finding | Severity | Where applied |
| --- | --- | --- |
| F1 Hidden Power and the move-end defrost | Major | §3 reader list; Engine fit; V4a design; V4a tests; Risks; Surprising 10; D4 limit |
| F2 Rollout vs Rampage PP rationale | Minor | Summary 3; §7; V3 design; V3 tests; Risks |
| F3 single `rolloutLocked` capture, fifth-hit release | Minor | V3 design; V3 tests; Risks |
| F4 V4 split, unsupported gate | Minor | Summary 4; V4 design (V4a/H1/V4b); Slices; tests; D2 |
| F5 every item action resets Fury Cutter | Minor | Summary 2; §6; V2 design; V2 tests |
| F6 AI table labels | Minor | §10 |
| F7 Present against Fly/Dig draws 0 | Minor | §5 RNG; V1 design; V1 tests; RNG notes |
| F8 V1 test-list typo | Minor | V1 tests (40, 80, 80, 120, 120, heal) |
| F9 two unlisted `cancelMultiTurnMoves` callers | Info | §6; Engine fit; V2 design; V2 tests |
| F10 Defense Curl at +6 is not silent | Info | §8; V3 design; V3 tests |
| F11 citation nits | Info | §1 (`pkmn.c:2383`); §6 (`bm.c:2382-2384`, `:2457-2459`); §7 (`bsc.c:1147`) |
| F12 friendship snapshot precondition | Info | Data availability; H1 item 7; hand-off note |
| F13 H1 minimal; wild path via `boxData` | Info | Data availability; H1 items 3, 4, 6; hand-off note |
| D1-D4 | Decisions | "Decisions for review" (settled) |
