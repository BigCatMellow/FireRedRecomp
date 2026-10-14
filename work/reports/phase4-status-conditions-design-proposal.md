# Phase 4 proposal: primary status conditions design

- Status: `PROPOSAL — independently reviewed PASS WITH CORRECTIONS (applied); no implementation authority`
- Review: [2026-10-14 design review](../reviews/2026-10-14-status-conditions-design-review.md)
- Date: 2026-10-14
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Builds on: [status-conditions discovery](phase4-status-conditions-discovery.md)
- Lane: full relay (new cross-turn and saved state; not fast-lane eligible)

This proposes how to build sleep, poison, toxic, burn, freeze and paralysis in
bounded slices. Scheduling, task contracts and authority remain with the
Orchestrator; nothing here changes coordination files or capability status.

## Discovery `UNKNOWN`s resolved here

- **Field poison** (`src/field_control_avatar.c:710-733`, `src/field_poison.c:92-125`):
  outside secret bases, `VAR_POISON_STEP_COUNTER` increments per step mod 5;
  on 0, each party Pokémon with any poison loses 1 HP. Reaching 0 HP faints
  it and clears its status (`:32-40`); all fainted triggers the field
  whiteout path. FRLG does **not** stop at 1 HP.
- **Toxic counter on switch/after battle** (resolved, review F1): the counter
  is battle-local. `ENDTURN_BAD_POISON` (`battle_util.c:817-830`) increments
  only `gBattleMons[].status1` and emits nothing; the party copy keeps the
  value emitted when Toxic was applied, the TOX bit with counter 0
  (`battle_script_commands.c:2351-2364`). Every switch-in reloads `status1`
  from the party (`battle_script_commands.c:4461,4480`;
  `battle_controller_player.c:1549`), so the counter restarts at 0 on each
  switch-in and after battle the Pokémon stays badly poisoned with counter 0.
  No explicit clear exists; the reset follows from never writing it back.

## Design

### 1. State

- Use the existing `battler.status` number with the source `status1` bit
  layout (sleep turns in bits 0-2, flags in bits 3-7, toxic counter 8-11).
  `BattlePartyBridge` already round-trips it (`:149,171,188`), so the save
  format does not change.
- `persistPartyBattler` must write `status` with the toxic counter bits
  cleared (`status & ~0x0F00`), matching the source party copy; the in-battle
  counter lives only on the battler.
- Sleep turns persist as-is across switch and battle end (the sleep canceller
  emits status1, `battle_util.c:1533-1538`); Snore/Sleep Talk decrement
  without an emit; Rest sets 3 turns (`battle_script_commands.c:6497`).
- On faint (`checkFaint` → `recordFaint`), clear `battler.status` to 0 as
  `Cmd_cleareffectsonfaint` does (`battle_script_commands.c:2930-2938`), for
  faints from move damage, recoil and end-of-turn damage alike.
- New pure module `src/core/StatusConditions.lua`: bit constants, predicates
  (`isAsleep`, `isPoisoned` ...), `canApply(target, kind, ctx)` returning a
  reason, and `apply(target, kind, rng)` (sleep draws `(Random() & 3) + 2`).
  The engine calls it; it never touches presentation.

### 2. Move-time cancellers (start of `BattleEngine:resolveMove`)

Insert after the existing auto-Struggle / no-PP handling and **before** the
`useMove` event and PP deduction, in source order (`battle_util.c:1233-1250`):

1. Sleep (`:1266-1308`): decrement; still asleep → `fastAsleep`, no PP, stop;
   reaches 0 → `wokeUp`, continue.
2. Freeze (`:1310-1333`): `Random() % 5` nonzero → `frozenSolid`, stop; zero →
   `thawed`, continue. Thaw-hit moves thaw at `CANCELLER_THAW` (`:1513-1525`).
3. Paralysis (`:1439-1449`): `Random() % 4 == 0` → `fullyParalyzed`, stop.

These draws come before accuracy/crit/damage. When added, Truant, Recharge,
Flinch, Disabled, Taunt, Imprison and Confusion sit between Freeze and
Paralysis, and Ghost, Love, Bide and Thaw come after. A frozen battler using a
thaw-hit move still consumes the `Random() % 5` draw. None of the three
failures prints "used" or deducts PP (`data/battle_scripts_1.s:3661,3699,3718`).

### 3. Damage and order modifiers

- Burn (`pokemon.c:2540`): physical damage `/2` after `/50`, before Reflect and
  the +2; applies on crits; Guts excluded (no abilities yet).
- Paralysis (`battle_main.c:3449-3450,3474`): speed `/4` inside
  `BattleFormulas.getWhoStrikesFirst` only, after stat stage, badge boost and
  Macho Brace and before Quick Claw (`battle_main.c:3428-3452`). Run odds use
  unmodified speed.
- Defrost (`battle_script_commands.c:4103-4116`): a Fire hit that affects a
  frozen target thaws it after damage if the target is still above 0 HP
  (`battle_script_commands.c:4104-4109`).

### 4. Applying status

- Secondary (`*_HIT` families 2, 4, 5, 6, 202, 209): reuse the existing
  `seteffectwithchance` roll path (one draw even on no-effect), then
  `StatusConditions.canApply` with the `SetMoveEffect` guards: target alive,
  no existing status, type immunity (Poison/Steel vs poison, Fire vs burn,
  Ice vs freeze; Electric not immune), Safeguard/Substitute/abilities excluded
  until represented.
- Primary (families 1, 66, 67, 33, 167): their own scripts with
  `accuracycheck`, explicit "already ..." / "But it failed!" outcomes and
  type-immunity checks; one task per small group.

### 5. End of turn

Add a per-battler phase after `decaySideTimers` (field before battler, as in
`BattleTurnPassed`): for each living battler in turn order, poison
`max(1, maxHP/8)`, toxic `max(1, maxHP/16) × n` (n incremented first, capped at
15), burn `max(1, maxHP/8)` (`battle_util.c:805-841`). Faints route through `checkFaint` and the
existing forced-switch/battle-end paths. The engine's early-return turn
policy (see the Memento follow-up) means the end-of-turn phase must also run
on turns that currently return early, where the source would run it; that
interaction needs its own test matrix.

Rules (review F3): (a) run the phase at every site where `decaySideTimers`
runs, under the same `not isOver()` gate (today `BattleEngine.lua:2101,2146,
2176,2220,2226,2236`). (b) Battler order is the turn's action order: hoisted
switch, item and run actions first, otherwise the `getWhoStrikesFirst`
result. (c) Skip battlers at 0 HP. (d) After each faint call `checkFaint`; if
that decides the battle, stop the phase; if it only queues a forced switch,
continue with the remaining battlers and resolve the replacement after the
phase. (e) Two forced switches can come out of one phase. (f) Future
per-battler effects (Ingrain, Leftovers/`ITEMS1`, Leech Seed) precede Poison
for the same battler, and `ITEMS2` follows Burn (`battle_util.c:723-743`).

### 6. Presentation

New events with source texts (`src/battle_message.c` line : STRINGID): fell
asleep (`:83` `PKMNFELLASLEEP`), was poisoned (`:88` `PKMNWASPOISONED`), badly
poisoned (`:92` `PKMNBADLYPOISONED`), was burned (`:94` `PKMNWASBURNED`), was
frozen solid (`:98` `PKMNWASFROZEN`), is paralyzed / may be unable to move
(`:104` `PKMNWASPARALYZED`), is fast asleep (`:162` `PKMNFASTASLEEP`), woke up
(`:163` `PKMNWOKEUP`), is frozen solid (`:100` `PKMNISFROZEN`), attacker
defrosted by the canceller thaw (`:102` `PKMNWASDEFROSTED2`), target defrosted
by a Fire move (`:101` `PKMNWASDEFROSTED`), defrosted by a thaw-hit move
(`:103` `PKMNWASDEFROSTEDBY`, S4), fully paralyzed "is paralyzed! It can't
move!" (`:106` `PKMNISPARALYZED`), hurt by poison (`:90` `PKMNHURTBYPOISON`),
hurt by its burn (`:96` `PKMNHURTBYBURN`), and the "already" texts (`:85`
`PKMNALREADYASLEEP`, `:91` `PKMNALREADYPOISONED`, `:97` `PKMNALREADYHASBURN`,
`:107` `PKMNISALREADYPARALYZED`). The battle
HP box status label is presentation polish for a later slice.

### 7. Outside battle

- Capture: feed `CaptureRules` its existing multiplier hook (sleep/freeze ×2,
  others ×1.5; `battle_script_commands.c:9553-9556`). Today the seam
  (`CaptureRules.calculateCatchValue`) is unreachable: `tryPokeBall`
  hard-codes 1/1 and `BattleEngine.lua:2120` calls it, so S4 must pass 2/1 for
  sleep/freeze and 15/10 for the others.
- Field poison (above) needs the field step loop in `main.lua`: a separate,
  later slice coordinated with whoever owns field/menu work at that time.
  The faint also applies the outside-battle faint friendship event
  (`field_poison.c:36`).

## Proposed slices

| Slice | Content | Unlocks |
| --- | --- | --- |
| S1 | `StatusConditions` module, battler state, cancellers + RNG, burn/paralysis modifiers, end-of-turn damage, defrost, faint clears status, events/texts; toxic counter battle-local (masked on persist) | groundwork, no new moves |
| S2 | Secondary status on hit: 2, 4, 5, 6, 202, 209 | 23 moves |
| S3 | Primary status moves: 1, 66, 67, 33, 167 | 13 moves |
| S4 | 125 thaw-hit, 169 Facade, 171 Smelling Salt, 193 Refresh (capture multiplier moved into S2) | 5 moves |
| S5 | Field poison (main.lua; coordinate) | out-of-battle parity |

Later, needing more state: 36 Tri Attack, 37 Rest, 77 Twineedle, 152 Thunder,
200 Blaze Kick, 102 Heal Bell, 187 Yawn, 107 Nightmare, 92 Snore,
97 Sleep Talk, 124 Safeguard, 159 Uproar.

## Verification plan

Per slice: source-derived oracles (exact draws and sentinels for each
canceller and application, HP thresholds for end-of-turn damage, type
immunity tables), controller text order through the real engine, party
round-trip of `status` through `BattlePartyBridge` (toxic counter masked;
a faint while statused persists `status = 0`), no-ROM suite and
repository checker, ROM record fixtures for each new move family, and an
independent review. Replays touched by turn-order or RNG changes need the
guarded verified-ROM run before acceptance, like the tracked plain-hit gap.

## Risks

- RNG ordering: new draws occur only when a status bit is set: the freeze
  `% 5` and paralysis `% 4` draws on each move attempt, the sleep-duration
  `& 3` on application, and the speed-tie `& 1`, which paralysis can add or
  remove. A battle in which no status is ever present keeps today's
  sequences. A party record loaded with a nonzero `status` (for example from
  an imported save) will change behavior once S1 lands; today that field is
  ignored.
- End-of-turn on early-return turns changes existing turn flow; isolate with tests.
