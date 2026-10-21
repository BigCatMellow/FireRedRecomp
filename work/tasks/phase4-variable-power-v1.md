# Task: variable-power slice V1 — Present

- Task ID: `P4-VARIABLE-POWER-V1`
- Status: `DONE — independently reviewed PASS WITH CORRECTIONS (applied)`
- Lane: fast lane (one family, engine only, no new state)
- Spec: [variable-power design proposal](../reports/phase4-variable-power-design-proposal.md)
  (§5 "Present", "V1: Present", verification plan V1, RNG notes), status
  `independently reviewed PASS WITH CORRECTIONS (applied)`, with the
  [design review](../reviews/2026-10-21-variable-power-design-review.md)
  folded in: F7 (a Fly/Dig target draws nothing), F8 (the corrected test
  list 40, 80, 80, 120, 120, heal), D4 (the recorded limits).
- Base: `d1ad194` on `claude/wizardly-faraday-o45q9z` (origin/main plus the
  proposal, its review, and the folded-in corrections).

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

Abbreviations: `bsc.c` `src/battle_script_commands.c`, `bs1.s`
`data/battle_scripts_1.s`, `msg.c` `src/battle_message.c`, `moves.h`
`src/data/battle_moves.h`.

- **Script** `BattleScript_EffectPresent` (`bs1.s:1660-1666`):
  attackcanceler, `accuracycheck BattleScript_PrintMoveMissed`,
  attackstring, ppreduce, typecalc, `presentdamagecalculation`.
- **`Cmd_presentdamagecalculation`** (`bsc.c:8238-8264`): `rand = Random() &
  0xFF`; `< 102` → `gDynamicBasePower = 40`, `< 178` → 80, `< 204` → 120,
  each then `BattleScript_HitFromCritCalc` (critcalc, damagecalc, typecalc,
  adjustnormaldamage, the hit; `bs1.s:251-268`). Otherwise
  `gBattleMoveDamage = maxHP / 4`, 0 → 1, negated; target at full HP →
  `BattleScript_AlreadyAtFullHp`; otherwise `gMoveResultFlags &=
  ~MOVE_RESULT_DOESNT_AFFECT_FOE` and `BattleScript_PresentHealTarget`.
- **`BattleScript_PresentHealTarget`** (`bs1.s:2028-2036`): ignores
  Substitute, `healthbarupdate`/`datahpupdate` (negative damage clamps at
  maxHP, `bsc.c:1789-1794`; no physical/special damage record), "regained
  health!". **`BattleScript_AlreadyAtFullHp`** (`bs1.s:2038-2042`): "HP is
  full!".
- **Texts** (`msg.c:124-125`): `"{B_DEF_NAME_WITH_PREFIX} regained\nhealth!"`,
  `"{B_DEF_NAME_WITH_PREFIX}'s\nHP is full!"`: both name the **target**.
- **Accuracy**: `AccuracyCalcHelper` (`bsc.c:1040-1043`) misses a
  semi-invulnerable target before `Random()` (F7); the protect re-test
  (`JumpIfMoveAffectedByProtect`, protection slice P1) draws nothing.
- **Record** (`moves.h:2824-2835`): effect 122, power 1, Normal, accuracy
  90, PP 15, chance 0, `MOVE_TARGET_SELECTED`, priority 0, flags
  `FLAG_PROTECT_AFFECTED | FLAG_MIRROR_MOVE_AFFECTED` = 0x12.
- **AI**: `AI_CBM_HighRiskForDamage` row already ported
  (`AICheckBadMove.lua:632`); the AI reads the record power 1
  (`battle_ai_script_commands.c:981-982`). No AI change.

## Design (as implemented)

- `BattleEngine.EFFECT_PRESENT = 122`;
  `BattleEngine.presentPowerFromRoll(roll)` returns 40 / 80 / 120 below 204
  and `nil` (the heal branch) from 204 to 255; it asserts a byte.
- `resolveMoveCore`: Present takes the ordinary path through accuracy (with
  the P1 protected re-test and the semi-invulnerable miss) and PP. Right
  after the miss block, before the zero-power branch:
  - `roll = rng:next16() % 256` (`& 0xFF`);
  - power: a local copy with that power continues through the ordinary
    crit, damage, typecalc, random and hit. A Ghost target gets the
    existing `noEffect` after the crit and random draws. The shared record
    keeps power 1;
  - heal at full HP: `restoreHPFull{side = <target>}`, return;
  - heal otherwise: `amount = max(1, floor(maxHP / 4))`, HP clamped at
    maxHP, `restoreHP{side = <target>, beforeHP, hpRemaining, amount}` with
    `amount` the HP actually gained, return. Type immunity is ignored (a
    Ghost is healed). No crit or random draw; `tookMoveDamage`, Oak's
    tutorial flag and the move-end defrost are untouched.
- `BattleSceneController`: comments only. The `restoreHP`/`restoreHPFull`
  texts already name `event.side`; the stale "the heal target is the user"
  comment now says the event names the healed battler.
- Header slice list updated.

### Recorded limits (D4)

- Substitute: the heal ignores it in source; Substitute is not represented.
- Wonder Guard: the pre-roll typecalc would leave `MISSED`, so source prints
  the heal text with no HP change; Wonder Guard is not represented.
- The pre-roll typecalc sets `targetNotAffected` on a Ghost target; it is
  unobservable for a non-locking move, so the engine does not set it.
- The tracked plain-hit `seteffectwithchance` zero-chance gap applies to the
  damage branch, as for every `HitFromCritCalc` family.

## File ownership

- **MAY CHANGE:** `src/core/BattleEngine.lua`;
  `src/core/BattleSceneController.lua` (comments only);
  `tests/battle_variable_power_v1_test.lua` (new);
  `tests/phase4_variable_power_v1_effect_rom_test.lua` (new);
  `tests/phase4_move_effect_inventory_test.lua` (row 122 and the counts);
  `work/reports/phase4-move-effect-inventory.md` (row 122 and the counts);
  this task file.
- **MUST NOT CHANGE:** `main.lua`, party/Dex code, `BattlePartyBridge.lua`,
  the Pokémon factories, coordination and roadmap files,
  `AICheckBadMove.lua` (the row is already ported).

## RNG change and changed assertions

- **RNG:** Present gains one draw after accuracy and PP on every
  non-missed, non-protected use. The heal branch loses the crit and damage
  draws. Seeded replays with Present diverge from its first use. A miss
  draws 1, a protected or Fly/Dig target 0.
- **Changed assertions** (inventory only, the intended flip):
  `tests/phase4_move_effect_inventory_test.lua` row 122
  `blocked_on_state` → `represented`; `admitted_uncovered_positive` 24 → 23;
  represented 127/275/191 → 128/276/192 (families/moves/positive);
  blocked 70/78/24 → 69/77/23. Admission stays 299/55. No other existing
  assertion changes; no existing test used move 217 or effect 122.
- Inventory report: row 122 → `R`, the class table, the uncovered list
  (122 removed; 23 records in 20 effects) and the admission note.

## Acceptance

- `tests/battle_variable_power_v1_test.lua`: 72 checks, exact `scriptedRng`
  draw counts.
  - The helper at every boundary (0, 101, 102, 177, 178, 203 → 40, 40, 80,
    80, 120, 120; 204, 255 → heal; 256 rejected).
  - F8 through `resolveMove`: rolls 101, 102, 177, 178, 203 (drawn as
    `0x100 + r`, testing the mask) give damage 6, 11, 11, 16, 16 with 4
    draws each; roll 204 heals the foe 200 → 300 with 2 draws; roll 255 also
    heals.
  - A crit doubles 6 to 12; random 85% at 120 gives 13; the shared record
    keeps power 1; a Ghost on the damage branch gets `noEffect` with 4
    draws and no HP change.
  - Heal: a Ghost is healed (2 draws); the clamp (350 → 400, amount 50);
    the minimum 1 (maxHP 3); floor(7/4) = 1; full HP gives `restoreHPFull`
    on the target with 2 draws and PP spent; the foe's Present heals the
    player; a frozen target stays frozen; `tookMoveDamage` stays false.
  - Miss: 1 draw, PP spent; the accuracy-90 boundary. **F7:** Fly and Dig
    targets: 0 draws, "missed", PP spent. Protected: 0 draws, the protected
    text, no heal, PP spent.
  - Controller texts: "FOE regained\nhealth!", "FOE's\nHP is full!", and
    "PLAYER regained\nhealth!" for the foe's Present.
  - `runTurn`: a heal turn takes 2 draws, a damage turn 4; in the first
    battle (accuracy skipped) a heal draws 1 and does not set the damage
    tutorial flag.
- `tests/phase4_variable_power_v1_effect_rom_test.lua`: the record and the
  one-member family against the verified ROM; skips without a ROM (ROM
  fixture pending).
- Mutation spot-checks (each applied to the working tree from a fresh
  scratchpad backup, then restored with `cp` and confirmed with `cmp`):
  threshold 102 → 101 fails 2; 178 → 177 fails 2; 204 → 205 fails 7; the
  mask as `% 100` fails 25; no heal minimum fails 1; the full-HP event
  naming the attacker fails 2; a crit draw on the heal branch fails 5; no
  maxHP clamp fails 1; writing the power into the shared record fails 1.
- `bash scripts/test_all.sh` and `lua5.1 scripts/check_repository.lua`
  pass; `main.lua` unchanged.

## Deviations from the design

None.

## Known limit added by review (F3)

A damaging move that misses a type-immune target prints "missed" in the
engine; source prints "It doesn't affect..." (`bsc.c:1102`, `:1345-1390`,
`:1937`). Draws and PP match; only the text differs. This is a pre-existing
engine-wide gap (Tackle shows it too) that Present inherits; tracked as its
own follow-up.

## Review (2026-10-21)

[Implementation review](../reviews/2026-10-21-variable-power-v1-v2-implementation-review.md):
PASS WITH CORRECTIONS (documentation only). 26/26 mutations caught across V1
and V2. F1 (league friendship raise) and F2 (wild friendship source) applied
to the hand-off and proposal; F3 recorded above and on inventory row 122;
F4/F5 wording and citations fixed.
