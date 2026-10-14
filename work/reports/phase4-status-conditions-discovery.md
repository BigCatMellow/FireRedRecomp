# Phase 4 discovery: primary status conditions (read-only)

- Status: `DISCOVERY — no implementation authority`
- Date: 2026-10-14
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Parent: [Phase 4 move/effect matrix](../roadmaps/CAPABILITY_CHECKLIST.md);
  [move-effect inventory](phase4-move-effect-inventory.md)
- Owner request: 2026-10-14, research status conditions ahead of any design.

This report collects source facts for the five primary (status1) conditions so
a later design/task can be scoped quickly. It changes no code, status or plan,
and it is not a design: selection, ordering and authority stay with the
Orchestrator. Items marked `UNKNOWN` were not source-locked here.

## Why it matters

127 used effect families are `blocked_on_state`. About 40 of them name a
status condition in their inventory limits; the core ones that need little
beyond status itself are listed under [Unlock map](#unlock-map).

## State representation (source)

`include/constants/battle.h:90-101` — `gBattleMons[i].status1` bits:

| Bits | Meaning |
| --- | --- |
| 0-2 | `STATUS1_SLEEP` turns remaining (1-7) |
| 3 | `STATUS1_POISON` |
| 4 | `STATUS1_BURN` |
| 5 | `STATUS1_FREEZE` |
| 6 | `STATUS1_PARALYSIS` |
| 7 | `STATUS1_TOXIC_POISON` |
| 8-11 | `STATUS1_TOXIC_COUNTER` |

Only one primary status at a time (`SetMoveEffect` refuses when `status1 != 0`).

Existing project hooks: `BattlePartyBridge.lua:149,171,188` already copies a
`status` number between party record and battler and persists it;
`CaptureRules.lua:22-33` already has a status multiplier hook defaulting to 1/1.
`BattleEngine.lua` does not read `battler.status` anywhere today.

## Application (`SetMoveEffect`, `src/battle_script_commands.c:2110-2350`)

Common guards before the per-status checks (`:2128-2145`): Shield Dust on
secondary effects, Safeguard on the target side, effect battler at 0 HP,
target Substitute (unless self-targeted).

| Status | Fails when (source lines in the `:2148-2330` switch) | Notes |
| --- | --- | --- |
| Sleep | already statused; Uproar active (Soundproof exempt); Vital Spirit/Insomnia | duration `(Random() & 3) + 2` = 2-5 (`:2356`) |
| Poison | Poison- or Steel-type; already statused; Immunity | |
| Burn | Fire-type; already statused; Water Veil | |
| Freeze | Ice-type; already statused; sunny weather; Magma Armor | |
| Paralysis | already statused; Limber | Electric types are **not** immune in Gen 3 |
| Toxic | as Poison; sets toxic counter 0 | |

Primary status moves (Sleep Powder, Toxic, Thunder Wave, Will-O-Wisp, ...) use
their own scripts with `accuracycheck` and explicit failure messages; damaging
`*_HIT` moves apply through `seteffectwithchance` (one `Random() % 100 <=
chance` roll, already modeled for stat hit variants).

## Effects during a turn

| Effect | Source | Detail |
| --- | --- | --- |
| Sleep check | `battle_util.c:1266-1308` (`CANCELLER_ASLEEP`) | decrement first (Early Bird −2); if still asleep the move fails ("fast asleep"), unless Snore/Sleep Talk; reaching 0 wakes and the move proceeds |
| Freeze check | `:1310-1333` (`CANCELLER_FROZEN`) | `Random() % 5`: nonzero → stays frozen (move fails); zero → thaws and acts (20%). Flame Wheel/Sacred Fire (`EFFECT_THAW_HIT`) thaw the user at `CANCELLER_THAW` `:1513-1525` |
| Paralysis check | `:1439-1449` (`CANCELLER_PARALYSED`) | `Random() % 4 == 0` → fully paralyzed (25%); runs after confusion in canceller order (`:1233-1250`) |
| Paralysis speed | `battle_main.c:3449-3450` | speed / 4 in `GetWhoStrikesFirst` |
| Burn attack | `pokemon.c:2540` | physical damage halved unless Guts |
| Defrost by Fire | `battle_script_commands.c:4103-4116` (`MOVEEND_DEFROST`) | a damaging Fire move that affects a frozen target thaws it |

RNG order matters: canceller draws (freeze, paralysis, and confusion when it
exists) happen before the move's accuracy/crit/damage draws.

## End of turn (`battle_util.c:726-845`, `DoBattlerEndTurnEffects`)

Per battler, in this order among the status cases: poison `max(1, maxHP/8)`,
toxic `max(1, maxHP/16) × n` with n incremented first and capped at 15, burn
`max(1, maxHP/8)`. Each can faint the battler. The engine currently has only field-level
end-of-turn effects (screens), so a per-battler end-turn phase is new.

## Outside battle

| Item | Source | Status here |
| --- | --- | --- |
| Capture odds | `battle_script_commands.c:9553-9556` | sleep/freeze ×2, others ×1.5 (hook exists) |
| Field poison damage | `src/field_poison.c` | Resolved in the [design proposal](phase4-status-conditions-design-proposal.md): every 5 steps −1 HP; 0 HP faints (no 1-HP survival) |
| Toxic after switch/battle | `battle_util.c:817-830`, `battle_script_commands.c:2363,4461` | Counter is battle-local and never written to the party copy; it restarts at 0 on each switch-in and after battle |
| Status healing items / Pokémon Center | `pokemon.c:4183,4664` (item cure paths) | not in scope of a first slice |

## Unlock map

Families whose inventory limits name status (effect id, moves):

- **Direct, status only:** 1 Sleep (6), 66 Poison (2), 67 Paralyze (3),
  33 Toxic (1), 167 Will-O-Wisp (1), 2 Poison hit (4), 4 Burn hit (5),
  5 Freeze hit (4), 6 Paralyze hit (8), 202 Poison Fang (1), 209 Poison Tail (1),
  125 Thaw hit (2), 169 Facade (1), 171 Smelling Salt (1), 193 Refresh (1).
- **Status plus another missing piece:** 36 Tri Attack (random status choice),
  37 Rest (sleep 2 + heal), 77 Twineedle (multi-hit + poison), 152 Thunder
  (weather accuracy), 200 Blaze Kick (high crit + burn), 102 Heal Bell (party-wide
  cure), 187 Yawn (delayed sleep), 107 Nightmare, 92 Snore, 97 Sleep Talk,
  124 Safeguard (side guard), 159 Uproar.

## Suggested first slice for a later design (not authority)

State storage on the battler plus party round-trip; the three in-turn
cancellers with their RNG; burn halving and paralysis speed; per-battler
end-of-turn poison/toxic/burn; capture multiplier; then the direct status-only
families. Abilities, Safeguard, Substitute, weather and field poison stay out
until represented. This touches turn order, end-of-turn and save state, so it
belongs in the full relay, not the fast lane.
