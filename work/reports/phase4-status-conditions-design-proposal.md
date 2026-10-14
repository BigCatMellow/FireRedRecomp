# Phase 4 proposal: primary status conditions design

- Status: `PROPOSAL — awaiting independent design review; no implementation authority`
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
- **Toxic counter on switch/after battle**: still `UNKNOWN`. No counter reset
  appears in `battle_main.c` or `battle_script_commands.c`; the controller
  copy paths were not read. Slice 1 must source-lock this before persisting
  the counter.

## Design

### 1. State

- Use the existing `battler.status` number with the source `status1` bit
  layout (sleep turns in bits 0-2, flags in bits 3-7, toxic counter 8-11).
  `BattlePartyBridge` already round-trips it (`:149,171,188`), so the save
  format does not change.
- New pure module `src/core/StatusConditions.lua`: bit constants, predicates
  (`isAsleep`, `isPoisoned` ...), `canApply(target, kind, ctx)` returning a
  reason, and `apply(target, kind, rng)` (sleep draws `(Random() & 3) + 2`).
  The engine calls it; it never touches presentation.

### 2. Move-time cancellers (start of `BattleEngine:resolveMove`)

Insert after the existing auto-Struggle / no-PP handling and **before** the
`useMove` event and PP deduction, in source order (`battle_util.c:1236-1250`):

1. Sleep (`:1266-1308`): decrement; still asleep → `fastAsleep`, no PP, stop;
   reaches 0 → `wokeUp`, continue.
2. Freeze (`:1310-1333`): `Random() % 5` nonzero → `frozenSolid`, stop; zero →
   `thawed`, continue. Thaw-hit moves thaw at `CANCELLER_THAW` (`:1510-1522`).
3. Paralysis (`:1439-1449`): `Random() % 4 == 0` → `fullyParalyzed`, stop.

These draws come before accuracy/crit/damage. Confusion would sit between
freeze and paralysis when added.

### 3. Damage and order modifiers

- Burn (`pokemon.c:2540`): physical damage `/2` after `/50`, before Reflect and
  the +2; applies on crits; Guts excluded (no abilities yet).
- Paralysis (`battle_main.c:3449-3450,3474`): speed `/4` inside
  `BattleFormulas.getWhoStrikesFirst` only. Run odds use unmodified speed.
- Defrost (`battle_script_commands.c:4103-4116`): a Fire hit that affects a
  frozen target thaws it after damage.

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
`BattleTurnPassed`): for each living battler in turn order, poison `maxHP/8`,
toxic `maxHP/16 × n` (n incremented first, cap 15), burn `maxHP/8`, each
minimum 1 (`battle_util.c:805-841`). Faints route through `checkFaint` and the
existing forced-switch/battle-end paths. The engine's early-return turn
policy (see the Memento follow-up) means the end-of-turn phase must also run
on turns that currently return early, where the source would run it; that
interaction needs its own test matrix.

### 6. Presentation

New events with source texts (`battle_message.c`): fell asleep (83), was
poisoned (88), badly poisoned (92), was burned (94), frozen solid (98), is
paralyzed / may be unable to move (104), fast asleep (162), woke up (163),
is frozen solid (100), was defrosted (101), can't move (106), hurt by poison
(90), hurt by its burn (96), and the "already" texts (85, 91, 97). The battle
HP box status label is presentation polish for a later slice.

### 7. Outside battle

- Capture: feed `CaptureRules` its existing multiplier hook (sleep/freeze ×2,
  others ×1.5; `battle_script_commands.c:9553-9556`).
- Field poison (above) needs the field step loop in `main.lua`: a separate,
  later slice coordinated with whoever owns field/menu work at that time.

## Proposed slices

| Slice | Content | Unlocks |
| --- | --- | --- |
| S1 | `StatusConditions` module, battler state, cancellers + RNG, burn/paralysis modifiers, end-of-turn damage, defrost, events/texts; toxic-counter source lock | groundwork, no new moves |
| S2 | Secondary status on hit: 2, 4, 5, 6, 202, 209 | 23 moves |
| S3 | Primary status moves: 1, 66, 67, 33, 167 | 13 moves |
| S4 | 125 thaw-hit, 169 Facade, 171 Smelling Salt, 193 Refresh; capture multiplier | 5 moves |
| S5 | Field poison (main.lua; coordinate) | out-of-battle parity |

Later, needing more state: 36 Tri Attack, 37 Rest, 77 Twineedle, 152 Thunder,
200 Blaze Kick, 102 Heal Bell, 187 Yawn, 107 Nightmare, 92 Snore,
97 Sleep Talk, 124 Safeguard, 159 Uproar.

## Verification plan

Per slice: source-derived oracles (exact draws and sentinels for each
canceller and application, HP thresholds for end-of-turn damage, type
immunity tables), controller text order through the real engine, party
round-trip of `status` through `BattlePartyBridge`, no-ROM suite and
repository checker, ROM record fixtures for each new move family, and an
independent review. Replays touched by turn-order or RNG changes need the
guarded verified-ROM run before acceptance, like the tracked plain-hit gap.

## Risks

- RNG ordering: cancellers add draws before existing ones only when a status
  is present, so status-free battles keep today's sequences.
- End-of-turn on early-return turns changes existing turn flow; isolate with tests.
- Toxic persistence stays blocked on its source lock.
