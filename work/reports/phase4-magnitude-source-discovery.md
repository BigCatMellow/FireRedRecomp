# Phase 4 — Magnitude source discovery

- Task: `P4-F1-MAGNITUDE-DISCOVERY`
- Scope: source lock only; no admission, runtime, test, route, ROM, or replay
  behavior is changed by this report.
- Source baseline: `pret/pokefirered` `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Project baseline inspected: `src/core/Rng.lua`, `src/core/BattleEngine.lua`,
  and `src/core/BattleFormulas.lua` at FireRedRecomp `0255088`.

## Source contract

Magnitude is move 222, effect 126.  The pinned move record gives it nominal
power 1, Ground type, accuracy 100, PP 30, and
`MOVE_TARGET_FOES_AND_ALLY` (`src/data/battle_moves.h`, `MOVE_MAGNITUDE`).
The nominal power is therefore not its damage power.

`BattleScript_EffectMagnitude` in `data/battle_scripts_1.s` performs, in this
literal order:

1. `attackcanceler`;
2. `attackstring` (the move-use announcement);
3. `ppreduce`;
4. `selectfirstvalidtarget`;
5. `magnitudedamagecalculation`;
6. a short pause, `STRINGID_MAGNITUDESTRENGTH`, and its wait; then
7. `BattleScript_HitsAllWithUndergroundBonusLoop`.

`Cmd_magnitudedamagecalculation` in `src/battle_script_commands.c` calls
`Random() % 100` exactly once, stores the selected transient
`gDynamicBasePower`, replaces the displayed value with the Magnitude level,
prepares `gBattleTextBuff1`, and scans for the first non-absent battler other
than the attacker.  Its exact table is:

| `Random() % 100` | displayed Magnitude | transient base power |
| --- | ---: | ---: |
| 0–4 | 4 | 10 |
| 5–14 | 5 | 30 |
| 15–34 | 6 | 50 |
| 35–64 | 7 | 70 |
| 65–84 | 8 | 90 |
| 85–94 | 9 | 110 |
| 95–99 | 10 | 150 |

This is the sole Magnitude-selection draw, after the script's PP reduction
and initial target selection and before the Magnitude-strength message.  It
is **not** a claim that no common cancellation/announcement helper can draw
RNG internally; this lock concerns the explicit Magnitude command and its
position in the script.

The subsequent shared loop clears move values, applies the Underground
double-damage/ignore-Underground marker only when its current target has
`STATUS3_UNDERGROUND`, then executes `accuracycheck`, `critcalc`,
`damagecalc`, `typecalc`, and `adjustnormaldamage`.  The successful path
then animates, updates HP, presents critical/result messages, processes a
faint, and advances to the next valid target; the miss path also advances to
the next target.  Thus in a bounded singles projection the Magnitude draw
must precede that target's accuracy, critical, and normal-damage random
draws.  Source also explicitly supports more than one target; it is not a
single-target script.

## Current-project seams and limits

- `Rng:next16()` documents that it is one FireRed `Random()` call.  A later
  implementation can express the source table as `rng:next16() % 100` with
  no new RNG primitive.
- `BattleEngine:resolveMove` currently admits effect 126 only through the
  generic positive-power fallback.  The inventory correctly labels it a
  candidate, not represented coverage (`tests/phase4_move_effect_inventory_test.lua`).
- The ordinary bounded-singles path currently emits `useMove`, performs its
  accuracy check, reduces PP, then does critical/base/type/normal-random
  damage.  That is not the source ordering above: Magnitude needs its one
  roll and strength presentation after PP/target selection but before the
  target hit sequence.  This report does not choose an event shape or alter
  that order.
- Existing Flail and Eruption effects create a local copy of move data with a
  transient `power`; that establishes a local non-mutating precedent only.
  It does not authorize a generic dynamic-power framework.
- The project model is two-sided and has no absent-battler target loop or
  `STATUS3_UNDERGROUND` state.  It also does not currently establish the
  source `STRINGID_MAGNITUDESTRENGTH` text/buffer as a project event.  These
  are project-seam uncertainties, not source uncertainties.

## Required exclusions for a bounded later design

The later work must explicitly remain a one-attacker/one-defender projection:

- no foes-and-ally traversal, target reselection loop, doubles, or absent
  battler state;
- no Underground bonus or `HITMARKER_IGNORE_UNDERGROUND` behavior;
- no new abilities, held items, or their source-side interaction surface;
- no expansion of `attackcanceler`/cancellation semantics beyond the already
  represented engine boundary;
- no claim of source visual timing, message rendering, or multi-target
  animation parity; and
- no generic transient/dynamic-power abstraction.

`UNKNOWN`: the exact project event payload and presentation timing for the
Magnitude level are not settled by the current event model.  Source proves
the message occurs before the hit loop, but a later design must choose the
smallest observable project representation rather than inventing ROM UI
parity.  `UNKNOWN`: exact seeded full-turn parity remains outside this source
lock because common cancellation helpers and unsupported multi-target state
are not modeled here.

## Single successor boundary

After independent review, compile one design-only successor,
`P4-F2-MAGNITUDE-DESIGN`: define a dedicated effect-126 bounded-singles path
that (a) samples exactly one `% 100` roll, (b) maps it to the literal table,
(c) uses a non-mutating local move power, and (d) places the minimal
Magnitude-level event before the single defender's shared hit sequence.  The
design must retain the exclusions above and must not authorize code, tests,
bridge routing, replay, or ROM work.

## Evidence anchors

- Pinned script: `data/battle_scripts_1.s`,
  `BattleScript_EffectMagnitude` and
  `BattleScript_HitsAllWithUndergroundBonusLoop`.
- Pinned command: `src/battle_script_commands.c`,
  `Cmd_magnitudedamagecalculation`.
- Pinned metadata: `src/data/battle_moves.h`, `MOVE_MAGNITUDE`.
- Project seams: `src/core/Rng.lua` (`Rng:next16`),
  `src/core/BattleEngine.lua` (`supportsMove`, `resolveMove`, Flail/Eruption),
  and `src/core/BattleFormulas.lua` (accuracy, critical, normal random).
