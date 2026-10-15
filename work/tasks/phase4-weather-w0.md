# Task: weather slice W0 — source end-of-turn order (`ENDTURN_ORDER`)

- Task ID: `P4-WEATHER-W0`
- Status: `DONE — independently reviewed PASS WITH CORRECTIONS (applied)`
- Review: [implementation](../reviews/2026-10-15-weather-w0-implementation-review.md)
- Lane: full relay (weather design, decision D1)
- Spec: [weather design proposal](../reports/phase4-weather-design-proposal.md)
  ("End-of-turn order (W0, implemented)", R1, R2), with the
  [design review](../reviews/2026-10-14-weather-design-review.md)
  (PASS WITH CORRECTIONS) findings F1, F3 and F8 and decision D1 folded in.
- Base: `43d2d52` on `claude/wizardly-faraday-o45q9z`.

## Source lock (pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`)

- `src/battle_util.c:484-501` `ENDTURN_ORDER`: `gBattlerByTurnOrder[i] = i`,
  then for each pair `GetWhoStrikesFirst(order[i], order[j], FALSE)` and
  `SwapTurnOrder` on a nonzero result. In singles that is one call,
  (battler 0 = player, battler 1 = foe). It is the first field case
  (`:451-463`), and every field case precedes every battler case
  (`src/battle_main.c:2953-2965`).
- `src/battle_main.c:2930-2950` `HandleEndTurn_ContinueBattle`: flinch
  clear and the sleeping multi-turn cancel come before `BattleTurnPassed`.
- `src/battle_main.c:3400-3530` `GetWhoStrikesFirst`:
  - speed = raw × weather multiplier × stage ratio (`:3428-3430`), then
    badge boost, Macho Brace, paralysis `/4` and Quick Claw
    (`:3443-3452`, `:3466-3475`). Quick Claw compares
    `gRandomTurnNumber` and draws nothing; it is not modeled (no items);
  - with `ignoreChosenMoves = FALSE`, a battler whose
    `gChosenActionByBattler` is `B_ACTION_USE_MOVE` contributes
    `moves[chosenMovePositions]` (or `MOVE_STRUGGLE` when
    `noValidMoves`); any other action contributes `MOVE_NONE`, priority 0
    (`:3478-3503`);
  - an exact speed tie at equal priority draws `Random() & 1` in both the
    nonzero-priority (`:3510`) and zero-priority (`:3523`) branch. So
    `ENDTURN_ORDER` makes **0 or 1 draws in singles**.
- `src/battle_main.c:2990-2994`: `gChosenActionByBattler` is reset only
  after the end of turn, so `ENDTURN_ORDER` sees this turn's actions.
  `:3125-3130`: a locked/recharging battler is forced to
  `B_ACTION_USE_MOVE` with its stale slot. `:3623-3634`
  `TurnValuesCleanUp(TRUE)` clears only `protected`/`endured`.
- Switch (`B_ACTION_SWITCH`), Poke Ball (`B_ACTION_USE_ITEM`) and run
  (`B_ACTION_RUN`) are therefore `MOVE_NONE`, priority 0.

## Design (as implemented)

- `BattleEngine:endTurnOrder(playerMove, foeMove)`: if either battler is at
  0 HP, return player first with no draw (review F1). Otherwise one
  `BattleFormulas.getWhoStrikesFirst(self.player, self.foe, playerMove,
  foeMove, self.rng)` call; any nonzero result puts the foe first.
- `BattleEngine:resolveEndTurn(events, playerMove, foeMove)`: flinch clear,
  sleep cancel, `endTurnOrder`, `decaySideTimers`,
  `resolveStatusEndTurn(events, sides)`. `HOISTED_ORDER` and `sidesOf` are
  removed.
- `BattleEngine:chosenMoveRecord(side, action)`: the parsed record of the
  (lock-substituted) chosen slot. Turn start now uses it too; it returns
  the same record as before.
- Call sites (review F3; line numbers at `43d2d52`):

  | Site | Branch | Player | Foe |
  | --- | --- | --- | --- |
  | `:3226` | switch | `nil` (switched-in `self.player`) | `chosenMoveRecord(FOE, foeAction)` |
  | `:3271` | failed capture | `nil` | same |
  | `:3301` | failed run | `nil` | same |
  | `:3348` | early exit, attacker's own faint | `playerMove` | `foeMove` |
  | `:3354` | early exit, defender faint with a switch pending | `playerMove` | `foeMove` |
  | `:3364` | normal exit | `playerMove` | `foeMove` |

## MAY CHANGE

- `src/core/BattleEngine.lua` (end-of-turn order only)
- `tests/battle_end_turn_order_test.lua` (new), `tests/battle_engine_test.lua`,
  `tests/battle_status_engine_test.lua` (deliberate draw-count updates only),
  `tests/battle_confusion_flinch_test.lua`, `tests/battle_rampage_test.lua`
  (direct `resolveEndTurn` calls updated to the new signature)
- `work/reports/phase4-status-conditions-design-proposal.md` (supersession note)
- `work/reports/phase4-weather-design-proposal.md` (fold in the review)
- `work/reviews/2026-10-14-status-conditions-design-review.md` (supersession
  note on correction (b)), `work/reviews/2026-10-14-status-s1-review.md`
  (M28 note)
- this task file

## MUST NOT CHANGE

`main.lua`, the party/Dex code, coordination and roadmap files,
`src/core/AICheckBadMove.lua`, and any W1-W3 behaviour.

## Changed assertions (intentional, source-cited)

1. `tests/battle_status_engine_test.lua:193-205` "paralysis /4 creates a
   speed tie …": draws 3 → 4 (script `{0, 4, MISS}` → `{0, 4, MISS, 0}`).
   The paralyzed player (40 / 4 = 10) still ties the foe (10) at end of
   turn, so `ENDTURN_ORDER` draws `Random() & 1` (`battle_util.c:484-501`,
   `battle_main.c:3523`).
2. `tests/battle_engine_test.lua:1097-1102` "a switch consumes no RNG of its
   own …": draws 3 → 4 (script `{0,0,0}` → `{0,0,0,0}`). The switched-in
   battler (Charmander stats, speed 11) ties the foe (11); switch is
   `MOVE_NONE` vs Tackle, both priority 0 (`battle_main.c:3486-3496`,
   `:3523`). The switch itself still draws none.
3. `tests/battle_status_engine_test.lua:551-555` comment only: the hoisted
   tick order is source order, not "player-first order". The assertion is
   unchanged (the incoming battler, 20, is faster than the foe, 10).

No other assertion changed. An instrumented run of the whole no-ROM suite
found exactly two end-of-turn tie draws (the two above). The other turns
whose end-of-turn order changes (hoisted turns against a faster foe, and
0-HP early exits) have only one ticking battler, so nothing observable
changes.

## Acceptance

- `tests/battle_end_turn_order_test.lua` (42 checks), all with exact
  `scriptedRng` draw counts:
  - faster foe first at end of turn on a move-vs-move turn;
  - String Shot mid-turn reorders the end of turn (player acted first,
    foe ticks first); Thunder Wave mid-turn creates the tie draw;
  - ties: exactly one extra draw, draw 0 → player first, 1 → foe first,
    including the equal nonzero-priority branch;
  - priority: Quick Attack at end of turn on a move-vs-move turn (no draw),
    and on switch, capture and run turns against a Quick Attack foe (foe
    first at equal or lower speed, no tie draw; source uses priority,
    `ignoreChosenMoves = FALSE`);
  - switch, failed-capture and failed-run turns against a faster foe; the
    switched-in battler's speed decides; run odds use the raw stat while
    the order uses staged/paralyzed speed;
  - 0-HP battler (move KO and hoisted KO, replacement pending): the other
    battler still ticks, no recompute and no draw.
- Old-engine check: 20 of the 42 new checks fail against `43d2d52`. Removing
  the 0-HP guard fails 2; passing `nil` for the foe at each hoisted site
  fails 2, 2 and 1.
- `bash scripts/test_all.sh` and `lua5.1 scripts/check_repository.lua` pass.

## Known limits

- 0-HP rule (F1, under R2): source compares the replacement at
  `ENDTURN_ORDER` and draws if it ties; the engine keeps the fainted
  battler until after the turn and makes no draw.
- Quick Claw and the badge boost/Macho Brace are not modeled, as at turn
  start.
- Struggle: source uses priority 0 for `noValidMoves`; the engine passes the
  chosen slot's record, as turn start does. They differ only when every
  slot is at 0 PP and the chosen slot holds a priority move.
- Replays: any recorded battle with a tied end of turn now consumes one
  more draw from that point on.

## Review corrections (2026-10-15)

- F1: `tests/battle_confusion_flinch_test.lua:117` and
  `tests/battle_rampage_test.lua:344` called `resolveEndTurn` with the old
  order-list argument (silently read as the player's move record); now
  `(events, nil, nil)`.
- F2: supersession notes added to the status-conditions proposal (rule (b))
  and the S1 review (end-of-turn order bullet).
- F3: old-engine failure count corrected to 20 of 42.
- F4-F6 informational; the ROM tests and runtime replays still need a run
  with a verified ROM (a tied end of turn now draws one more `Random()`).
