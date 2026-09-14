# Task: Phase 4 move admission-matrix discovery

- Status: `DISCOVERY COMPLETE — PENDING INDEPENDENT REVIEW`
- Type: `PHASE 4 / BATTLE RULES / READ-ONLY DISCOVERY`

## Goal

Produce a source-backed inventory of positive-power FireRed move-effect
families that `BattleEngine:supportsMove` currently admits, distinguishing the
families the engine actually models from those that would incorrectly fall
through its ordinary damage path. Select at most one smallest, independently
testable next implementation leaf; do not implement it in this task.

## Required evidence

1. Enumerate the current admission predicate and every explicit engine effect
   family, with source locations.
2. Join that inventory to verified-ROM move records and FireRed battle-effect
   semantics, identifying reachable positive-power unsupported families.
3. State whether each candidate is safe to defer, must be blocked behind an
   unrepresented prerequisite, or is eligible as the next bounded leaf.
4. Write conclusions only to this task, `STATE.json`, `HANDOFF.md`, and the
   execution map; preserve the Phase 2 external-reference blocker.

## MUST NOT CHANGE

No battle behavior, move admission predicate, UI, AI, trainer layouts, held
items, main wiring, generated data, or bridge configuration. Discovery is not
permission to silently reject or implement a move family.

## Evidence and inventory

`BattleEngine:supportsMove` at `src/core/BattleEngine.lua:735-739` admits every
positive-power record, except effect 8 (Dream Eater), without inspecting the
effect family. Explicit behavior dispatches are: pure stat stages
`459-481`; hit-variant stat stages `493-502`; recoil `526-529`; drain
`561-563`; fixed damage `573-577`; multi-hit `593-596`; screens `615-618`;
and the corresponding resolve branches at `821-1059`. Ordinary direct damage
is correctly represented for effect 0, and effect 103 (Quick Attack) is also
safe because turn ordering consumes the ROM priority field.

Using the supported FireRed US v1.0 ROM through `import/BattleMove.lua`, the
audit found 216 positive-power records: 75 are represented by the explicit
families below, Dream Eater is the one explicitly rejected record, and 140
are currently admitted solely by the broad positive-power fallback.

| Classification | Effect ids (`id: ROM move count`) | Conclusion |
| --- | --- | --- |
| Correctly represented | `0:23, 3:4, 29:12, 41:1, 44:2, 48:3, 68:1, 69:4, 70:6, 71:1, 72:4, 73:3, 87:2, 103:3, 130:1, 138:1, 139:2, 198:2` | Existing direct, drain, multi-hit, fixed-damage, recoil, secondary-stat, and priority behavior covers 75 records. |
| Explicitly rejected | `8:1` | Dream Eater has a sleep precondition absent from the engine; the explicit rejection is correct. |
| **Next leaf** | `17:6` (`EFFECT_ALWAYS_HIT`) | Eligible. All six retail records have accuracy 0; stock `Cmd_accuracycheck` bypasses the roll for effect 17, while this engine currently rolls 0% and misses. No status, UI, item, party, or trainer prerequisite is needed. |
| Eligible but not selected | `43:8` high-critical, `78:1` Vital Throw, `101:1` False Swipe | Each has a narrow direct-damage correction (crit stage, shared always-hit condition, or HP floor), but selecting more than one would violate this task's one-leaf limit. |
| Safe to defer as dedicated formula/sequence work | `7:2, 26:1, 27:3, 34:1, 38:4, 39:1, 40:1, 88:1, 89:1, 99:2, 121:1, 122:1, 123:1, 126:1, 144:1, 189:1, 190:2, 196:1` | Explosion/self-KO; Bide/Rampage; Pay Day; OHKO; charge/fixed/current-HP/random/return-friendship/weight/retaliation formulas all require their own source-locked behavior package. Ordinary fallback is not parity. |
| Blocked on unrepresented prerequisite | `2:4, 4:5, 5:4, 6:8, 31:6, 36:1, 42:6, 45:2, 75:1, 76:6, 77:1, 80:4, 81:1, 92:1, 104:1, 105:2, 117:2, 119:1, 125:2, 128:1, 129:1, 135:1, 140:2, 145:1, 146:1, 147:1, 148:2, 149:1, 150:4, 151:1, 152:1, 154:1, 155:4, 158:1, 159:1, 161:1, 169:1, 170:1, 171:1, 182:1, 185:1, 186:1, 188:1, 197:1, 200:1, 202:1, 203:1, 204:2, 207:1, 209:1` | These depend on absent persistent status/volatile state, turn lock/charge/recharge, held items, weather, party/weight/IV state, switching interception, terrain, or secondary effects. They must not be silently treated as ordinary hits. |

The stock sources are present locally at
`Disassembled_Games/Classic/pokefirered-master`: effect names and ids are in
`include/constants/battle_move_effects.h`; the script routing table is in
`data/battle_scripts_1.s:20-233`; `Cmd_accuracycheck` in
`src/battle_script_commands.c:993-998` explicitly bypasses accuracy for
`EFFECT_ALWAYS_HIT` and `EFFECT_VITAL_THROW`; and `Cmd_critcalc` at
`1184-1191` confirms high-critical is a distinct later leaf. The verified ROM
records for effect 17 are Swift #129, Faint Attack #185, Shadow Punch #325,
Aerial Ace #332, Magical Leaf #345, and Shock Wave #351; each has accuracy 0
and positive power.

## Proposed one next leaf

Scope exactly `EFFECT_ALWAYS_HIT` (17), not Vital Throw or high-critical:
preserve attack cancellation, PP, typecalc, crit, damage, and normal HP paths;
skip only the accuracy RNG/check for this exact effect; prove all six parsed
ROM records and that a forced miss seed cannot miss or consume an accuracy draw.
It is the smallest source-backed correction that requires no new represented
state. It still needs its own explicit bridge route, Worker evidence, and
independent review before any status advancement.
