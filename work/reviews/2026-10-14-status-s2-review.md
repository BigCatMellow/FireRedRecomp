# Review: P4-STATUS-S2 status-on-hit families

- Reviewer: independent Reviewer (Claude), per `AGENTS.md` rule 6
- Date: 2026-10-14
- Commit under review: `3ba99f7` (Status S2: status-on-hit families (23 moves))
- Task: [`work/tasks/phase4-status-s2-status-hit.md`](../tasks/phase4-status-s2-status-hit.md)
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Verdict: **NEEDS_FIX** (one Major finding, F1. The status-on-hit logic itself matches source.)

## Summary

The core port matches source. The roll semantics, the SetMoveEffect guard
outcomes, the Poison Tail crit stage, the texts, the 23 ROM fixture records
and the inventory arithmetic all check out against the pin. The changed
scripted draws in `tests/battle_engine_test.lua` are correct for source.
Mutation testing killed 25 of the 29 mutants. Three of the survivors are
equivalent: source makes the same silent outcome either way. One survivor
shows a real test gap (F3).

The blocking issue is a side effect. S2 is the first slice that lets a wild
foe carry a status in ordinary play. The Poké Ball path still ignores status,
so catch odds for a statused wild Pokémon are now wrong (F1). The task's
"Known effects" section does not list this.

## Verification performed

- `Cmd_seteffectwithchance` (`src/battle_script_commands.c:2774-2804`): for a
  byte without `MOVE_EFFECT_CERTAIN` (every setmoveeffect status byte here),
  `Random() % 100 <= percentChance` is the first `&&` operand. It is drawn on
  every reached path, including a `MOVE_RESULT_NO_EFFECT` hit, and
  `percentChance >= 100` calls `SetMoveEffect(FALSE, MOVE_EFFECT_CERTAIN)`.
  The engine does the same: `BattleFormulas.secondaryEffectRoll` uses `% 100 <=`,
  the noEffect branch draws and discards, and `>= 100` passes `certain`.
  A miss jumps to `BattleScript_PrintMoveMissed` before the roll, and the
  engine also skips it on a miss.
- Position in the hit: `BattleScript_EffectHit` (`data/battle_scripts_1.s:244-269`)
  runs datahpupdate → critmessage → resultmessage → **seteffectwithchance** →
  tryfaintmon → moveend (`MOVEEND_DEFROST`, bsc.c:4103-4116). In the engine the
  status roll comes after `applyDamage`. It also comes after the
  recoil/drain blocks, which no member of these families uses. It comes
  before the faint record and before `resolveMove`'s defrost. On a KO the
  roll is still drawn and the hp==0 guard blocks the status, which matches
  source.
- `SetMoveEffect` (bsc.c:2110-2370), for each kind:
  - Shield Dust (:2132-2134) has the condition `ability == SHIELD_DUST && !(HITMARKER_STATUS_ABILITY_EFFECT) && !primary && byte <= 9`. There is no certain exemption, and status bytes 1-6 are all `<= 9`, so the port is correct (Zap Cannon is covered too).
  - Safeguard (:2136) and Substitute (:2145) are unmodeled, and the task says so.
  - hp==0 (:2140) is ported.
  - Poison (:2176-2216), Burn (:2218-2256) and Toxic (:2302-2349): Immunity and Water Veil print their text only when `primary || certain`, otherwise they break silently. The type checks, the existing-status check and the ability break all fail silently. The engine checks the ability before `canApply`, which gives the same outcome, and among the 23 moves only Zap Cannon is certain.
  - Paralysis (:2272-2301): Limber is checked first, with text when certain and a silent break otherwise. Electric types have no immunity in Gen 3, and the port matches.
  - Freeze (:2257-2270): Ice type, then existing status, then sun (unmodeled), then Magma Armor (silent). The engine's order gives the same outcome.
  - Toxic's `MOVE_RESULT_DOESNT_AFFECT_FOE` (:2347) is set only for a statusless Poison/Steel target. Its later consumers are `MOVEEND_RAGE`, `MOVEEND_UPDATE_LAST_MOVES` (gLastLandedMoves), `MOVEEND_MIRROR_MOVE` and `MOVEEND_ATTACKER_VISIBLE` (bsc.c:4086-4300). None of them is modeled: Poison Fang is not Fire, so defrost is unaffected. Nothing observable changes today (F4).
- Ability population: `BattlePartyBridge.lua:148-149` derives the party
  battler's ability from `speciesInfo.abilities[abilityNum+1]`.
  `battlerFromGenerated` (:170-171) copies `instance.ability`, which
  `WildPokemonFactory.lua:256` and `TrainerPokemonFactory.lua:116,126` set.
  The existing Damp check already relies on this field.
- Poison Tail: `Cmd_critcalc` (bsc.c:1184-1188) adds +1 for
  `EFFECT_POISON_TAIL`, and the engine ports it. In singles there is no
  special handling for Blizzard, Powder Snow or Heat Wave (target BOTH):
  the engine applies no spread reduction, which is correct outside doubles,
  and the probe below applied status from all three. Thunder (152), Tri
  Attack, Twineedle and Blaze Kick are correctly excluded.
- Texts are correct against `src/battle_message.c` lines 83, 88, 92, 94,
  98 and 104 (`B_EFF_NAME_WITH_PREFIX`) and lines 270, 272 and 280
  (`EFF_NAME's DEF_ABILITY`/`EFF_ABILITY`, effect = target here).
  `B_MSG_STATUSED` selects the `gGot*StringIds` entries. Ability names come
  from `src/data/text/abilities.h`: "LIMBER", "IMMUNITY", "WATER VEIL".
  Constants 7, 17, 19, 40 and 41 match `include/constants/abilities.h`.
- ROM fixture: I parsed `src/data/battle_moves.h` independently. All 23
  records (effect, power, type, accuracy, pp, chance, target, flags,
  priority 0) match `tests/phase4_status_hit_effect_rom_test.lua` exactly.
- Inventory arithmetic:
  - Represented: 70+6 = 76 families; 162+23 = 185 moves; 114+23 = 137 positive.
  - Blocked: 127-6 = 121 families; 191-23 = 168 moves; 101-23 = 78 positive; zero-power stays 90.
  - Uncovered: 78 records in 48 effects. The list is exactly the admitted positive `blocked_on_state` keys in the test.
- Changed scripted draws in `battle_engine_test.lua`: each Ember use now
  takes the effect roll after its acc/crit/damage draws. Value 99 gives
  `99 % 100 > 10`, so no burn. The capture test (shakes, then foe Ember
  plus its roll) and the Struggle-miss test (foe Ember's roll is draw 4, the
  Struggle accuracy is draw 5) both follow source order.
- Probe (scratch only): I ran each of the 23 moves through `runTurn` with
  the source records, once at roll = chance and once at chance+1. Each
  applied its mapped kind at the boundary and nothing at chance+1. Zap
  Cannon applied on both rolls (certain). Lick against a Normal target is
  the expected Ghost/Normal no-effect.
- `WildPokemonFactory.capture` passes the status through
  `withToxicCounter(..., 0)`. This matches the design's resolved F1: the
  enemy party copy keeps TOX with counter 0, because `ENDTURN_BAD_POISON`
  only edits `gBattleMons`.
- Commands, all passing:
  - `lua5.1 tests/battle_status_engine_test.lua`: 109/0
  - `battle_scene_controller_test`: 127/0
  - `wild_pokemon_factory_test`: 29/0
  - `battle_engine_test`: 568/0
  - `phase4_move_effect_inventory_test`: expected partition checked
  - `phase4_status_hit_effect_rom_test`: skips without a ROM
  - `bash scripts/test_all.sh`: PASS, 164 files in no-ROM mode
  - `lua5.1 scripts/check_repository.lua`: PASS

## Findings

### F1 — Major: catch odds ignore a status that S2 makes reachable in wild battles

- Evidence:
  - Before S2, a wild foe always had status 0: it spawns that way, and S1
    added no applier.
  - S2 lets the player's hits poison, burn, freeze or paralyze a wild foe.
    For example, a starter Charmander's Ember burns 10% of the time.
  - `BattleEngine` capture calls `CaptureRules.tryPokeBall(self.foe, rng)`,
    which hard-codes `statusNumerator = 1, statusDenominator = 1`
    (`src/core/CaptureRules.lua:209-215`).
  - Source `Cmd_handleballthrow` (bsc.c:9553-9556) doubles the odds for
    sleep/freeze and multiplies them by 15/10 for
    poison/burn/paralysis/toxic.
  - So throwing a ball at a statused wild Pokémon now gives the wrong shake
    threshold, the wrong number of shake draws, and possibly the wrong
    capture outcome and RNG stream.
  - The task's "Known effects on existing behavior" section does not list
    this. The design proposal places the capture multiplier in S4, but S2
    makes the state reachable first.
- Fix (either is acceptable, Orchestrator to choose):
  - (a) Bring the capture-status multiplier forward. Map the battler's
    `status` to the source multipliers (bsc.c:9553-9556) in the capture
    call, and add source-oracle tests for each class: sleep/freeze ×2,
    PSN/BRN/PAR/TOX ×15/10, applied after the HP floor. This needs
    `CaptureRules.lua` added to MAY CHANGE.
  - (b) Record it explicitly as a known divergence in the task's "Known
    effects" and in the inventory notes, and schedule S4's capture
    multiplier before any release that includes S2.

### F2 — Minor: Synchronize is neither represented nor listed as a limit

- Evidence:
  - When a POISON/TOXIC/PARALYSIS/BURN status lands, `SetMoveEffect` sets
    `HITMARKER_SYNCHRONISE_EFFECT` (bsc.c:2376-2386).
  - `MOVEEND_SYNCHRONIZE_TARGET` (bsc.c:4121) then calls
    `ABILITYEFFECT_SYNCHRONIZE` (`battle_util.c:2185-2199`; toxic is
    downgraded to poison). This runs `seteffectprimary` on the attacker,
    with HITMARKER_STATUS_ABILITY_EFFECT set, so primary immunities print
    "had no effect".
  - This is reachable: wild Abra is `{ABILITY_SYNCHRONIZE, ABILITY_INNER_FOCUS}`
    (`src/data/pokemon/species_info.h`).
  - The inventory rows and the task list only "Safeguard/Substitute/sun" as
    absent.
- Fix: add Synchronize to the stated limits in the task source lock and the
  six inventory rows, or represent it in a follow-up slice. Implementing it
  needs MOVEEND ordering and attacker status.

### F3 — Minor: no test pins Immunity blocking Poison Fang (toxic)

- Evidence: mutant M27 (`toxic = 0` in `STATUS_BLOCKING_ABILITY`) survived.
  Source checks Immunity separately in the TOXIC case (bsc.c:2303 and
  :2336). Snorlax has Immunity (species_info.h), so this is reachable.
- Fix: add Poison Fang against an `ABILITY_IMMUNITY` target on a passing
  roll. Expect status 0, no `statusPrevented`, and the roll consumed.

### F4 — Info: Poison Fang's DOESNT_AFFECT_FOE flag has no observable effect today

None of its consumers (Rage, last-landed/last-taken move, attacker
visibility) is modeled. The task's follow-up note is accurate. It becomes
relevant when Rage, Mirror Move or Counter-style history lands.

### F5 — Info: pre-existing gaps now worth noting next to status

None of these was introduced by S2. All are out of S2 scope, and could be
added to the inventory notes:

- Serene Grace doubling the chance (bsc.c:2778). It is already called out
  in the `BattleEngine.lua` header.
- Contact abilities that status the attacker (Static, Poison Point, Flame
  Body, Effect Spore; `battle_util.c:1997-2060`).
- The `BATTLE_TYPE_POKEDUDE` early return.
- `Cmd_critcalc` skips `Random()` against Battle Armor/Shell Armor
  (bsc.c:1196-1198, short-circuit). This is an RNG divergence for wild
  Krabby/Shellder and is unrelated to status.

### F6 — Info: AI regression check, no new crash path

- `AICheckBadMove`'s "CONFIRMED NO-OP CLASS" header (the claim that status1
  is never set) and the `if_status AI_TARGET STATUS1_ANY` branches of
  Poison, Paralyze, WillOWisp and Sleep, plus Refresh's user check, are now
  stale.
- Those effects are primary-status moves. `supportsMove` rejects them, and
  `resolveMoveCore` errors (:1216) if a foe picks one. That crash path
  already existed and S2 does not add it.
- AI_CheckBadMove has no labels for effects 2/4/5/6/202/209. `EarlyRivalAI`
  and `TrainerAI` do not read status. This is the tracked S1 F4 follow-up.
- New events are consumed only by `BattleSceneController`. `main.lua` has no
  event switch that could reject them.

## Mutation testing

Files used: `BattleEngine.lua`, `BattleSceneController.lua`,
`WildPokemonFactory.lua` and `BattleFormulas.lua` (for the shared roll).
Tests run per mutant: status engine, controller, wild factory and battle
engine. Originals were restored byte-for-byte and verified with `cmp`.

| # | Mutant | Result |
| --- | --- | --- |
| M1 | No-effect hit skips the status roll | Killed (status engine) |
| M2 | Roll `<=` → `<` | Killed (status engine, battle engine) |
| M3 | Certain threshold `>= 100` → `> 100` | Killed |
| M4 | Shield Dust guard removed | Killed |
| M5 | Shield Dust exempts certain | Killed |
| M6 | Shield Dust moved after hp check | Survived: equivalent, both silent |
| M7 | Ability prevention text when not certain | Killed |
| M8 | Ability blocks only when certain | Killed |
| M9 | Magma Armor removed | Killed |
| M10 | Magma Armor checked before type/status | Survived: equivalent, both silent |
| M11 | Type immunity removed (status-only check) | Killed |
| M12 | hp guard removed | Survived: equivalent, because `canApply` also rejects hp 0 |
| M13 | Poison Tail crit stage removed | Killed |
| M14 | Poison Fang maps to poison | Killed |
| M15 | Freeze Hit maps to paralysis | Killed |
| M16 | Poison Tail dropped from family table | Killed |
| M17 | Certain chance skips the roll | Killed |
| M18 | Status applied to the attacker | Killed |
| M19 | Status applied on a no-effect hit | Killed |
| M20 | "was poisoned!" typo | Killed (controller) |
| M21 | Toxic uses the poison text | Killed (controller) |
| M22 | "prevents burns!" typo | Killed (controller) |
| M23 | "WATER VEIL" name typo | Killed (controller) |
| M24 | Capture toxic-counter mask removed | Killed (wild factory) |
| M25 | Electric made immune to paralysis | Killed |
| M26 | Status roll moved before damage | Killed (status engine, battle engine) |
| M27 | Immunity no longer blocks toxic | **Survived (F3)** |
| M28 | Water Veil no longer blocks burn | Killed |
| M29 | Limber no longer blocks paralysis | Killed |

Score: 25 of 29 killed. Three survivors are equivalent and one is a real
test gap (F3).

## Required before PASS

- F1: resolve by fix (a) or (b).
- F2 and F3 are small and can go in the same fix commit.

## Worker disposition (2026-10-14)

F1 fixed by option (a): `CaptureRules.statusMultiplier` feeds `tryPokeBall`
with source oracles; F2 recorded as limits/follow-ups; F3 test added.
