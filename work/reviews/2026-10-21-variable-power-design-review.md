# Review: Phase 4 variable-power design proposal (V1-V5), design

- Reviewer: independent Reviewer (Claude), per `AGENTS.md` rule 6
- Date: 2026-10-21
- Under review: `work/reports/phase4-variable-power-design-proposal.md`
- Base engine: working tree (`src/core/BattleEngine.lua`, 4786 lines; the proposal says `67f6453`)
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
  Every file cited below was fetched fresh from
  `raw.githubusercontent.com/pret/pokefirered/<pin>/…`. The local scratch
  copies `/tmp/claude-0/{bsc.c,bs1.s,bmain.c,bm.c}` are byte-identical to the
  pin's `battle_script_commands.c`, `battle_scripts_1.s`, `battle_main.c` and
  `battle_message.c` (`cmp`).
- Abbreviations as in the proposal (`bsc.c`, `bs1.s`, `bm.c` = battle_main.c,
  `msg.c`, `bu.c`, `pkmn.c`, `ai.s`, `aisc.c`, `moves.h`, `battle.h`, `cb.h`).

## Verdict

**PASS WITH CORRECTIONS.**

Almost every source claim is correct. That includes the surprising ones:

- Present heals a Ghost.
- Fury Cutter is not reset by using a different move.
- Any protected move resets the Fury Cutter counter.
- A protected locked Rollout spends one PP.
- Rollout loses its lock against a semi-invulnerable target.
- The Defense Curl bit is set at +6.
- The power-0 fallback gives power 1.
- Hidden Power is Dark only at typeBits 63 and is never Normal.
- The AI always sees Normal and power 1.

There is one **Major** finding (F1). Hidden Power is *not* on the same reader
set as Weather Ball. A Fire Hidden Power never thaws its target in source, but
the engine's move-end defrost would thaw it. There are also several **Minor**
corrections: a wrong Rollout-versus-Rampage PP rationale, a Rollout ordering
trap, the V4 split, item-use scope, an AI table mislabel, a missing RNG case
and a test-list typo. They must go into the V1-V4 task specs before
implementation. None of them blocks the slicing.

## Verified as stated

| Claim | Source | Result |
| --- | --- | --- |
| Present script: attackcanceler, `accuracycheck PrintMoveMissed`, attackstring, ppreduce, **typecalc**, presentdamagecalculation | `bs1.s:1660-1666` | OK |
| Present: one `Random() & 0xFF`; `<102` gives 40, `<178` gives 80, `<204` gives 120, then `HitFromCritCalc`; otherwise `maxHP/4`, min 1, negated; at full HP `AlreadyAtFullHp`, otherwise clear `DOESNT_AFFECT_FOE` and `PresentHealTarget` | `bsc.c:8238-8264` | OK |
| Draw sits after accuracy and PP, before crit/damage | script order above; `HitFromCritCalc` = critcalc, damagecalc, typecalc, adjustnormaldamage (`bs1.s:251-268`) | OK |
| Ghost heal: the pre-roll typecalc sets `DOESNT_AFFECT_FOE` (Normal→Ghost 0x via `ModulateDmgByType`); the heal branch clears it; `healthbarupdate`/`datahpupdate` gate only on `MOVE_RESULT_NO_EFFECT` | `bsc.c:1274-1340`, `:8261`, `:1700-1760` | OK. The Ghost **is** healed |
| Heal ignores Substitute (`orword HITMARKER_IGNORE_SUBSTITUTE`); negative damage clamps at maxHP; no physical/special damage recorded | `bs1.s:2028-2036`; `bsc.c:1781-1786` | OK (so `tookMoveDamage` unchanged and no thaw is right) |
| Wonder Guard in the pre-roll typecalc leaves `MISSED`, so the heal text prints with no HP change | `bsc.c:1326-1336` | OK (unmodeled) |
| Texts: "{B_DEF_NAME_WITH_PREFIX} regained\nhealth!" / "…'s\nHP is full!"; existing `restoreHP`/`restoreHPFull` name `event.side` | `msg.c:124-125`; `BattleSceneController.lua:323-330` | OK (the controller comment "the heal target is the user" becomes stale; update it in V1) |
| Fury Cutter script: ppreduce before accuracy; hit and miss share `FuryCutterHit`; `jumpifmovehadnoeffect` loops back to the calc | `bs1.s:1627-1639` | OK |
| Counter: `!= 5` then `++`; power = 10 doubled `counter-1` times (10/20/40/80/160/160); `NO_EFFECT` zeroes and goes to `MoveMissedPause` | `bsc.c:8205-8226` | OK |
| Writers: furycuttercalc, `CancelMultiTurnMoves` (`bu.c:213`), `ClearFuryCutterDestinyBondGrudge` (`bu.c:3041-3046`), disable-struct clears at switch-in/faint (`bm.c:2382-2384`, `:2457-2459`) | grep of pin | OK. No reset on using another move |
| Protect step: `DEFENDER_IS_PROTECTED && (!IsTwoTurnsMove \|\| MULTIPLETURNS)` → `CancelMultiTurnMoves(attacker)` for **any** protect-affected move; Rollout and Fury Cutter are not in `IsTwoTurnsMove` | `bsc.c:896-906`, `:7821-7832` | OK |
| `CancelMultiTurnMoves` callers listed (flinch `bu.c:1366`, recharge `:1354`, paralysis `bs1.s:3717`, confusion `bs1.s:3742`, sleep/freeze applied `bsc.c:2173/2269`, end-turn sleep needs `MULTIPLETURNS` `bm.c:2941-2942`, and the unmodeled ones) | as cited | OK (see F9 for one modeled caller not listed) |
| Rollout script: `jumpifstatus2 MULTIPLETURNS` over ppreduce; `accuracycheck RolloutHit` (shared); typecalc2; rolloutdamagecalculation | `bs1.s:1592-1602` | OK |
| Rollout calc: `NO_EFFECT` → `CancelMultiTurnMoves` + `MoveMissedPause`; first hit sets timer 5, `MULTIPLETURNS`, `gLockedMoves`; `--timer == 0` clears `MULTIPLETURNS`; power doubled `4-timer` times (30…480); `STATUS2_DEFENSE_CURL` doubles (960) | `bsc.c:8161-8193` | OK |
| Protected locked Rollout: the protect step clears `MULTIPLETURNS` **before** `jumpifstatus2`, so ppreduce runs (guarded by `pp != 0`) | `bsc.c:896-906`, `:1147`; `bs1.s:1595-1596` | OK (but see F2 for the Rampage comparison) |
| Semi-invulnerable target: `AccuracyCalcHelper` misses, the jump goes to `RolloutHit` and the lock is cancelled | `bsc.c:1040-1043`; `bs1.s:1597-1599` | OK |
| `MULTIPLETURNS` locks selection (`bm.c:3125-3130`), uses `gLockedMoves` (`bm.c:3989-3992`), bypasses the 0-PP check (`bsc.c:838-839`) | as cited | OK |
| Defense Curl: `setdefensecurlbit` before `statbuffchange`, so set at +6; bit 30 has no other reader or writer; cleared at faint (`bm.c:2441`) and switch-in (`bm.c:2367`); Baton Pass mask excludes it (`bm.c:2352`) | `bs1.s:2010-2021`; `bsc.c:8472-8476`; `cb.h:130` | OK |
| Return/Frustration: `10*f/25`, `10*(255-f)/25`; power 0 → record power 1 (`if (!powerOverride)`) | `bsc.c:8228-8236`; `pkmn.c:2397-2400` | OK. Oracles recomputed: f=0→0/102, 2→0/101, 3→1/100, 70→28/74, 128→51/50, 253→101/0, 255→102/0 |
| Hidden Power: powerBits = bit 1 and typeBits = bit 0, order HP, Atk, Def, Spe, SpA, SpD; power `40*p/63+30`; type `15*t/63+1`, `>= TYPE_MYSTERY` incremented; flags `F_DYNAMIC_TYPE_1\|2` | `bsc.c:8503-8530`; `pokemon.h:97-115` | OK. Table recomputed for all 64 typeBits: matches the proposal exactly; Dark only at 63; never Normal or `???` |
| `hiddenpowercalc` runs before accuracy | `bs1.s:1735-1738` | OK |
| AI resets `gDynamicBasePower`/`dynamicMoveType` before estimates; power ≤1 → `MOVE_POWER_DISCOURAGED` | `aisc.c:966-1022` (`:981-982`), `:1201-1206` | OK |
| AI_CheckBadMove rows Return `:171`, Present `:172`, Frustration `:173`, Defense Curl `:186`, Low Kick `:206`; none for Rollout/Ice Ball/Fury Cutter/Hidden Power | `ai.s` grep | OK. Ported at `AICheckBadMove.lua:631-633, :645, :664`, power gate `:702` reads the ROM record |
| Friendship/IVs copied at switch-in | `battle_controller_player.c:1540-1547`, `battle_controller_opponent.c:475-482` | OK |
| In-battle level-up adjusts party friendship only; refresh rewrites level/HP/stats | `bsc.c:3314-3329` | OK |
| Trainer IVs `iv * 31 / 255`; `CreateBoxMon` sets species base friendship; `CreateNPCTrainerParty` never sets friendship | `bm.c:1576/1588/1606/1620`; `pkmn.c:1815` | OK |
| Low Kick: script order, `sWeightToDamageTable` with strict `>`, bands 20…120; `PokedexEntry.weight` u16 at +0x0E, size 0x24 | `bs1.s:2550-2556`; `bsc.c:756-764`, `:9074-9089`; `pokedex.h:102-114`; `pokedex.c:11-22` | OK |
| Records: Present Normal/1/90/no contact; Return, Frustration Normal/1/100/contact; HP Normal/1/100/no contact; Fury Cutter Bug/10/95; Rollout Rock, Ice Ball Ice 30/90 contact; Defense Curl power 0, `MOVE_TARGET_USER`; Low Kick Fighting/1/100 | `moves.h:2824, 2811, 2837, 3084, 2733, 2668, 3916, 1446, 874` | OK |
| Data: `battlerFromParty` copies no friendship/IVs; `battlerFromGenerated` neither; trainer instance has `ivs`, no friendship, no `boxData`; `makeBattler` has no such opts | `BattlePartyBridge.lua:124-174`; `TrainerPokemonFactory.lua:121-128`; `WildPokemonFactory.lua:244, 252-261`; `BattleEngine.lua:1126-1240` | OK |
| No Pokédex weight anywhere (only `gPokedexOrder_Weight`, a sort order) | `import/RomAddresses.lua:65`; grep of `import/`, `src/` | OK |
| Engine fit sites (`cancelMultiTurnMoves :1926-1931`, `isLocked :1939-1942`, `lockedTurn :2034-2044`, 0-PP check `:2150-2156`, `rampageLocked :2202`, end-turn sleep `:4165`, capture `:4620`, run `:4663`) | `BattleEngine.lua` | OK |

## Findings

### F1 (Major): Hidden Power's dynamic type does not reach the move-end defrost. A Fire Hidden Power never thaws.

The proposal (§3) says the dynamic type reaches every reader through
`GET_MOVE_TYPE`, "the move-end defrost" included, and that this is "the same
reader set as Weather Ball". The second half is wrong.

- `Cmd_datahpupdate` picks its own `moveType`, and it does not use
  `GET_MOVE_TYPE` (`bsc.c:1751-1756`):
  - if `dynamicMoveType == 0`: the record type;
  - else if `!(dynamicMoveType & F_DYNAMIC_TYPE_1)`: the dynamic type;
  - **else: the record type**.
- Hidden Power sets `F_DYNAMIC_TYPE_1 | F_DYNAMIC_TYPE_2` (`bsc.c:8527`).
  Weather Ball sets only `F_DYNAMIC_TYPE_2` (`bsc.c:9352-9360`).
- So for Hidden Power, `datahpupdate` sees Normal, which is physical
  (`battle.h:475`). It records `physicalDmg`, never `specialDmg`
  (`bsc.c:1823-1843`).
- `MOVEEND_DEFROST` requires `gSpecialStatuses[target].specialDmg` **and**
  `moveType == TYPE_FIRE` (`bsc.c:4103-4109`). `gSpecialStatuses` is cleared
  for every action (`bm.c:4457`). A Fire Hidden Power therefore never thaws a
  frozen target. A Fire Weather Ball does thaw it.
- The engine's defrost tests only `self.currentMove.type == TYPE_FIRE` and
  `moveDamageDealt > 0` (`BattleEngine.lua:1625-1631`). If V4 uses the
  Weather Ball local-copy pattern, setting `type` on the copy, the engine
  **would** thaw on a Fire Hidden Power. That is a parity bug.

Required correction:

- V4 must exclude Hidden Power from the move-end defrost, for example with a
  marker on the local copy, and add an oracle test: a frozen target hit by a
  Fire Hidden Power stays frozen.
- Record the same quirk as a known limit for future Counter/Mirror Coat work:
  Hidden Power always records physical damage, whatever its type.
- Fix the §3 reader list: the split, STAB/typecalc, Hustle, Thick Fat and
  weather use the HP type. The `datahpupdate` damage record and, through it,
  the defrost use the record type.

### F2 (Minor): the Rollout-versus-Rampage PP rationale is wrong. The rule itself is right.

§7 says a protected locked Rollout spending one PP "is the opposite of
Rampage". The Risks section says that reusing `rampageLocked` "would get the
protected-turn PP wrong". In fact both families spend one PP, guarded at 0, on
a **protected** locked turn:

- Rampage's protected turn also has its lock cancelled by the protect step.
  Its accuracycheck re-test then jumps to `PrintMoveMissed`, which runs
  ppreduce (`bs1.s:276-278`). The engine models this as
  `rampageLocked and not hit and slot.pp > 0` → spend
  (`BattleEngine.lua:2785-2788`). The M3 design review confirmed it ("a missed
  locked turn does spend PP").
- The real difference is the **unprotected locked miss**:
  - an accuracy miss or a semi-invulnerable miss;
  - Rampage spends one PP through `PrintMoveMissed`;
  - Rollout spends none, because `MULTIPLETURNS` is still set at
    `jumpifstatus2` (`bs1.s:1595`) and the miss jumps straight to `RolloutHit`.

The proposed rule ("spend unless `rolloutTimer > 0` read after the protect
step") gives the right answer in all four cases. Correct the rationale and the
risk line, so an implementer does not "invert" Rampage. Add a test: a locked
Rollout that misses normally, or misses a Fly target, spends 0 PP.

### F3 (Minor): Rollout's locked-or-not read must happen before the hit branch changes the timer, and the fifth hit must free `lockedSlot`.

In source, ppreduce runs before accuracy. In the engine, the PP block runs
**after** the accuracy result (`BattleEngine.lua:2775-2790`). The design says
both "PP: … read it after `cancelMultiTurnMoves`" and "After accuracy: hit: if
`rolloutTimer == 0`, set it to 5 …; then decrement". The order of those two
steps is not stated. If the timer is written first:

- hit 1 (timer set to 5, then 4) would skip its PP;
- hit 5 (timer to 0) would wrongly spend.

The spec should require one value, `rolloutLocked = rolloutTimer > 0`,
captured right after the protect step (as `rampageLocked` is, but **after**
`cancelMultiTurnMoves` rather than before). The PP block and the 0-PP bypass
should both read that value.

The design also says "at 0 the lock clears". It should state that the fifth
hit sets `lockedSlot = nil`, with the same `not recharging` guard as
`cancelMultiTurnMoves` (`:1930`), as Rampage does at `:4436`.

Tests should check:

- hit 1 spends 1 PP;
- hits 2-5 spend 0;
- after hit 5, `isLocked` is false and the next turn offers the menu.

### F4 (Minor, D2): V4 can and should split. Use the existing "unsupported" gate, not a new crash path.

The proposal says V4 "lands only together with H1, otherwise a live battle
that uses one of these moves would hit the error". There is a cleaner split
that needs no party-code edit:

- **V4a (engine, this lane):**
  - `makeBattler` accepts optional `friendship`/`ivs`; the precedent is
    `catchRate`, which is optional and asserted only at use
    (`BattleEngine.lua:1129-1133`, `:4622`).
  - Add the formulas and the F1 defrost exclusion.
  - Treat effects 121/123 (no `friendship`) and 135 (no `ivs`) as
    **unsupported for that attacker**, through a battler-aware
    `supportsMove`. The controller already turns an unsupported player move
    into "That move's effect is not available yet." with no turn and no RNG
    (`BattleSceneController.lua:715-721`). A foe reaches the existing
    resolution error (`BattleEngine.lua:2071-2074`), exactly as every other
    `B` effect does today.
  - Tests use synthetic battlers that carry the opts, plus one test that
    shows the unsupported gate when they are absent.
  - The inventory rows read "represented when battler carries
    friendship/IVs; needs H1".
- **H1 (party owner):** below.
- **V4b (small, after H1):** bridge tests and the final inventory flip.

Keeping today's silent power-1 Normal hit as the fallback is **not**
acceptable. It is known-wrong behavior in a row that would be marked
represented (AGENTS rules 8 and 9).

Note the behavior change. These are TM moves, so the live reach is player
mons taught TM27/TM21/TM10 and custom-move trainer parties. V4a turns them
from a silently wrong plain hit into a visible "not available yet" (player)
or an unsupported-effect error (foe). This is the same treatment Defense Curl
gets today. Before merging, the coordinator should confirm against the ROM
fixture that no trainer reachable in the currently playable area carries
216/218/237 in custom moves. If one does, V4a should wait for H1.

### F5 (Minor): `ClearFuryCutterDestinyBondGrudge` runs on every item use, not only on ball throws.

`HandleAction_UseItem` calls it before it branches on the item
(`bm.c:4150-4157`). Balls, Poké Doll/Fluffy Tail, Poké Flute, player bag
items and trainer AI items (`:4157-4200`) all reset the counter.

The engine has only the capture action today, so V2's behavior is right. But
§6, V2 "Resets" and the V2 test list should say "any item action (only
capture is represented)". Then a later bag-item or trainer-item slice keeps
the reset.

### F6 (Minor): AI table labels are wrong, and the conclusion stands.

§10 calls `ai.s:2846`, `:2891` and `:3203` "AI_CheckViability terms". They
are:

- `AI_SetupFirstTurn_SetupEffectsToEncourage` (Defense Curl);
- `AI_Risky_EffectsToEncourage` (Present);
- `AI_HPAware_DiscouragedEffectsWhenTargetLowHP` (Fury Cutter).

The Defense Curl references in AI_CheckViability are `AI_CV_Protect`
(`:2024`) and `AI_CV_Snatch` (`:2681`).

None of these scripts is ported for general trainers:

- `TrainerAI.choose` accepts only flags 0, 0x1 and the Oak-lab 0x7
  (`TrainerAI.lua:137-150`);
- `EarlyRivalAI` accepts only Tackle, Scratch, Growl and Tail Whip and errors
  on anything else (`EarlyRivalAI.lua:1-6`, `:79`).

So "no AI change needed" is correct. Fix the labels.

### F7 (Minor): Present's semi-invulnerable miss is missing from the RNG list and the tests.

Against a Fly or Dig target, `AccuracyCalcHelper` jumps to `PrintMoveMissed`
before `Random()` is called (`bsc.c:1040-1043`). So the draw count is **0**,
not "miss: accuracy only". The text is "missed", and PP is spent. Add this
case to §5's RNG list and to the V1 tests.

### F8 (Minor): V1 test-list typo.

"Roll values 101, 102, 177, 178, 203 and 204 select 40, 80, 120, 120 and
heal" gives six inputs but five outputs. It should read 40, 80, 80, 120, 120,
heal.

### F9 (Info): two existing `cancelMultiTurnMoves` callers are not listed.

The engine also calls `cancelMultiTurnMoves` at the end-of-turn sleep cancel
(`BattleEngine.lua:4166`) and at the Rampage `WasUnableToUseMove` cancel
(`:4434`). The second mirrors `bu.c:958`, a source `CancelMultiTurnMoves`
caller that the proposal's lists also omit.

Both are correct reset paths for the Fury Cutter counter once V2 edits
`cancelMultiTurnMoves`. Nothing changes; list them for completeness.
`bsc.c:6071` is the `cancelmultiturnmoves` script command itself.

### F10 (Info): Defense Curl at +6 differs from effect 11 only in a pause. "silent" is misleading.

At +6, `ChangeStatBuffs` returns WORKED with `B_MSG_STAT_WONT_INCREASE` and
sets `MISSED` (`bsc.c:6796-6815`):

- Defense Curl's `jumpifbyte CMP_EQUAL … StatUpPrintString` prints "won't go
  higher!" **without** the `pause B_WAIT_TIME_SHORT` that effect 11 runs
  first (`bs1.s:2016` vs `:493-495`);
- the text is identical, and the `MISSED` flag is unobservable in the engine.

Reusing the effect-11 path is fine. Replace "silent" with "same text; source
skips effect 11's short pause".

### F11 (Info): citation nits.

- The ppreduce guard is `bsc.c:1147`, not `:1146`.
- `CalculateBaseDamage` begins at `pkmn.c:2383`.
- The disable-struct zeroing loops are `bm.c:2382-2384` and `:2457-2459`.

### F12 (Info): the friendship snapshot is exact today, but has a precondition.

Battle friendship is copied only at switch-in (`ctlp.c:1540`). In-battle
level-up changes only the party value (`bsc.c:3314`). The project applies
level-up friendship after the battle (`EarlyRivalRewards.lua:121-127`), so no
drift exists today.

When in-battle EXP lands, a mid-battle switch-in rebuild must read the
battle-time party friendship. Source would re-copy the updated party value.
Add this to the H1 note.

### F13 (Info): H1 is correct and close to minimal.

- Items 1-2 (bridge) and 4 (trainer factory) are needed.
  - `decoded.substructs[0].friendship` and `decoded.substructs[3].ivs` are
    the right fields (`BoxPokemonCodec.lua:161`, `:210-217`).
  - A trainer has no `boxData`, so `TrainerPokemonFactory` must expose
    `friendship = info.friendship`. `info` is `args.speciesInfo`, and
    `friendship` is imported at `import/SpeciesInfo.lua:75`.
- Item 3 is optional. The bridge can read
  `instance.boxData.substructs[0].friendship` (`WildPokemonFactory.lua:169-172`),
  and that also covers the developer temporary player (`main.lua:1280-1281`).
- The player starter already stores species friendship in its record
  (`StarterPokemonFactory.lua:123`), so it is covered by item 1.
- Item 5 (no write-back) is correct.

## Recommendations on the decisions

- **D1: yes, party code.** Per the ownership ruling for this review,
  `BattlePartyBridge.lua` and the factories belong to the party/Dex owner.
  H1 goes to that owner as a hand-off. Do not list those lines in a V4 MAY
  CHANGE.
- **D2: no silent fallback. Split V4.** Land V4a, engine only:
  - optional opts, formulas, the F1 defrost exclusion;
  - an attacker that lacks the data makes the move unsupported: the existing
    "not available yet" gate for the player, the existing unsupported-effect
    error for a foe;
  - tests on synthetic battlers.
  
  Then H1 (owner), then V4b (bridge tests, inventory flip). Confirm the
  ROM-fixture trainer check from F4 before merging V4a.
- **D3: keep V2 and V3 as separate packages,** in the proposed order (V2,
  then V3 rebased on V2's `cancelMultiTurnMoves` edit). V3 carries all of the
  lock risk (F2, F3, the five lock sites), and a small V2 review keeps that
  risk isolated.
- **D4: accept as recorded limits,** and widen the list:
  - Present's heal ignores Substitute;
  - Wonder Guard's leftover `MISSED` (heal text with no HP change);
  - Present's pre-roll typecalc sets `targetNotAffected` on a Ghost, which is
    unobservable for a non-locking move;
  - Hidden Power always records physical damage (F1), for future
    Counter/Mirror Coat work.

## Required spec changes before tasking

1. F1: exclude Hidden Power from the move-end defrost, add the test, and fix
   the §3 reader list.
2. F2: correct the Rampage comparison and the risk line. Add the
   unprotected-locked-miss 0-PP tests.
3. F3: name the single `rolloutLocked` capture point and the fifth-hit
   `lockedSlot` release. Add the per-hit PP tests.
4. F4/D2: rewrite V4 as V4a/H1/V4b.
5. F5, F6, F7, F8: wording, labels, the RNG case and the test typo.
