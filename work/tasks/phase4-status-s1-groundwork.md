# Task: primary status conditions, slice S1 (groundwork)

- Task ID: `P4-STATUS-S1`
- Status: `CLOSED — REVIEWED PASS` after re-review ([review](../reviews/2026-10-14-status-s1-review.md))
- Lane: full relay (new cross-turn and saved state). Owner delegation
  2026-10-14 ("just continue working where you can"); scoped to battle files
  only, away from in-flight Codex work (main.lua, party/Dex, coordination).
- Design: [status-conditions design proposal](../reports/phase4-status-conditions-design-proposal.md)
  ([design review](../reviews/2026-10-14-status-conditions-design-review.md),
  PASS WITH CORRECTIONS, applied); module
  ([review](../reviews/2026-10-14-status-conditions-module-review.md), PASS).

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

- Cancellers `src/battle_util.c:1266-1308` (sleep: decrement first; still
  asleep → `BattleScript_MoveUsedIsAsleep` unless `MOVE_SNORE`/`MOVE_SLEEP_TALK`;
  0 → woke up and the move proceeds), `:1310-1333` (freeze `Random() % 5`;
  nonzero cancels unless `EFFECT_THAW_HIT`; zero thaws), `:1439-1449`
  (paralysis `Random() % 4 == 0`), `:1513-1525` (thaw-hit thaw). Scripts
  `data/battle_scripts_1.s:3657-3718`: failures go to `BattleScript_MoveEnd`
  before attackstring/ppreduce.
- Burn `src/pokemon.c:2539-2541` (after /50, before Reflect, Guts exempt,
  no crit gate); paralysis speed `src/battle_main.c:3449-3450`.
- Defrost `src/battle_script_commands.c:4103-4116` (target frozen, HP > 0,
  special damage dealt, Fire move).
- End of turn `src/battle_util.c:805-841` (poison/toxic/burn), field before
  battler `src/battle_main.c:2958-2964`, faint/teams-lost per tick
  `data/battle_scripts_1.s:3676-3693`.
- Faint clears status `src/battle_script_commands.c:2930-2938`; toxic counter
  battle-local (design review F1).
- Texts `src/battle_message.c:90,96,100-103,106,162,163`.

## MAY CHANGE

- `src/core/BattleEngine.lua`: battler `status` default; constants;
  `resolveStatusCancellers` before `useMove`; `resolveMove` wrapper with the
  move-end Fire defrost over `resolveMoveCore`; damage tally in
  `applyDamage`; `recordFaint` clears status; `resolveEndTurn`/
  `resolveStatusEndTurn` at every former `decaySideTimers` call site.
- `src/core/BattleFormulas.lua`: burn halving, paralysis `/4`, Guts constant.
- `src/core/BattlePartyBridge.lua`: persist masks the toxic counter.
- `src/core/BattleSceneController.lua`: canceller, defrost and tick texts.
- Tests: new `tests/battle_status_engine_test.lua`; additions to
  `tests/battle_scene_controller_test.lua`, `tests/battle_party_bridge_test.lua`.

No main.lua, save format, replay, AI or move-admission change. No move
applies a status yet (S2/S3), so ordinary play only reaches this through a
party record that already has a status.

## Acceptance

1. Each canceller: event order, PP unchanged on cancel, exact draw count;
   Snore while asleep; auto-Struggle user still cancelled; thaw-hit draw.
2. Burn and paralysis numeric oracles, including tie creation/removal and
   raw-speed run odds.
3. Defrost only for a damaging Fire hit on a surviving frozen target.
4. End-of-turn amounts (poison, burn, toxic sequence, min-1 before multiply,
   cap 15), turn order, field-before-battler, every call site, faint stops
   the phase on a decided battle and continues on a forced switch.
5. Faint clears status; persist masks the toxic counter and keeps sleep turns.
6. Status-free turns keep their draw count; full no-ROM suite and
   repository checker pass.

## Review round 1 (NEEDS_FIX) disposition

- F1/F2 fixed in `finalizeFaintSequence`: a decided battle clears the
  forced-switch queue; the queue stays player-first across faint sequences.
  Engine and controller tests added (fail on the previous commit).
- F3 tests added: paralysis draw 2, failed-capture site, attacker-faint
  early-return site, 0-HP skip.
- F5 partly: asleep Snore now emits "fast asleep" before its use (Snore
  script `data/battle_scripts_1.s:1253-1266`).

## Follow-ups (not in S1)

- AICheckBadMove "confirmed no-op" status branches must be revisited when
  S2/S3 let status be applied (review F4).
- Snore's awake failure (family 92) and flinch remain unmodeled.
- Capture must pass a status multiplier from a masked status word (S4).
- End-of-turn uses an `elseif` chain; equivalent for valid status words.
- Defrost uses the base move type (Hidden Power dynamic type unmodeled).

## Evidence (Worker, 2026-10-14)

Status engine 78/0; controller 119/0 (was 105); party bridge 32/0 (was 29);
battle engine 568/0 unchanged; full suite and repository checker in the PR.
