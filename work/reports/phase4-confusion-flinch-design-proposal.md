# Phase 4 proposal: confusion and flinch (status2)

- Status: `PROPOSAL — independently reviewed PASS WITH CORRECTIONS (applied)`
- Review: [2026-10-14 design review](../reviews/2026-10-14-confusion-flinch-design-review.md)
- Date: 2026-10-14
- Source pin: pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
- Builds on: the primary status slices S1-S4 (status1) and their reviews.
- Lane: full relay (new cross-turn battle state).

Confusion and flinch are `status2` bits (`include/constants/battle.h:105-107`:
confusion turns in bits 0-2, `STATUS2_FLINCHED` bit 3). Unlike status1 they
are never written to the party copy: they end on switch-out, faint
(`Cmd_cleareffectsonfaint`, `src/battle_script_commands.c:2930-2940`) and
battle end.

## Source facts

### Applying

- `SetMoveEffect` `MOVE_EFFECT_CONFUSION` (`src/battle_script_commands.c
  :2405-2418`): no effect when the target has Own Tempo or is already
  confused (silent); otherwise `STATUS2_CONFUSION_TURN((Random() % 4) + 2)`
  (2-5) and "X became confused!" (`src/battle_message.c:116`,
  `data/battle_scripts_1.s:3893-3897`). It is in the non-status1 branch, so
  the common guards apply: Shield Dust blocks secondary effects with byte
  `<= 9` (confusion is 7), Safeguard `<= 7` (unmodeled), target at 0 HP
  returns (`:2132-2143`).
- `MOVE_EFFECT_FLINCH` (`:2419-2439`): Inner Focus prevents (text only when
  primary/certain, `BattleScript_FlinchPrevention` `:4109-4113`); otherwise
  the bit is set only if `GetBattlerTurnOrderNum(target) >
  gCurrentTurnActionNumber`, i.e. the target has not acted yet this turn.
  Shield Dust also blocks (byte 8).
- Flinch is cleared for every battler after all actions and before the
  end-turn effects (`src/battle_main.c:2940`, `HandleEndTurn_ContinueBattle`;
  `:2917` is the once-per-battle `TryDoEventsBeforeFirstTurn`).

### Move-time cancellers (`src/battle_util.c:1233-1250` order)

Sleep → Frozen → (Truant, Recharge) → **Flinch** → (Disabled, Taunt,
Imprison) → **Confused** → Paralysed → ... The loop stops at the first
canceller with an effect; a script that pushes the cursor returns to
`attackcanceler`, which resumes at the next canceller.

- Flinch (`:1361-1371`): clear the bit, "X flinched!" (`:123`), the move is
  not used (no attackstring/PP).
- Confused (`:1407-1435`): decrement the turn counter first. If still
  confused: "X is confused!" (`:114`) then `Random() & 1`: nonzero → the move
  proceeds (the cursor returns, so the paralysis check still runs after);
  zero → self-hit: `CalculateBaseDamage(attacker, attacker, MOVE_POUND,
  sideStatus 0, power 40, type 0)` (type 0 means no override, so Pound's
  Normal type: a physical base with the
  attacker's own attack/defense, stat stages, burn halving and ability
  terms; no crit, no STAB/typecalc, no screens), then
  `Cmd_adjustnormaldamage2` (`:1620-1660`: the random multiplier draw; Focus
  Band unmodeled), "It hurt itself in its confusion!" (`:337`), HP update,
  `tryfaintmon BS_ATTACKER`, move not used. Reaching 0 → "X snapped out of
  confusion!" (`:115`) and the move proceeds (paralysis check after).
  Quirk: `CalculateBaseDamage` tests `gCurrentMove`'s effect for the
  Explosion defense halving, so a confused Self-Destruct/Explosion user that
  hurts itself halves its own defense.

### Families (inventory rows)

| Family | Moves | Script shape |
| --- | --- | --- |
| 76 Confuse Hit | Psybeam, Confusion, Dizzy Punch, Dynamic Punch, Signal Beam, Water Pulse (6) | Hit + `setmoveeffect CONFUSION` via seteffectwithchance |
| 31 Flinch Hit | Rolling Kick, Headbutt, Bite, Bone Club, Rock Slide, Hyper Fang (6) | Hit + FLINCH |
| 150 Flinch/Minimize | Stomp, Needle Arm, Astonish, Extrasensory (4) | Minimized double (STATUS3 unmodeled → never) + FLINCH |
| 146 Twister | Twister (1) | On-air double (semi-invulnerable unmodeled → never) + FLINCH |
| 49 Confuse | Supersonic, Confuse Ray, Sweet Kiss (3) | Own Tempo text → Substitute → already confused text → accuracy → seteffectprimary |
| 118 Swagger / 166 Flatter | 1 + 1 | accuracy first; `jumpifconfusedandstatmaxed` fail; ATK+2 / SP.ATK+1 then Own Tempo text → seteffectprimary CONFUSION |
| 199 Teeter Dance | 1 | per-target loop; singles: the foe only (Own Tempo / already confused texts, accuracy) |
| 92 Snore | 1 | (now) awake → attackstring/ppreduce → But it failed; asleep → fast asleep text → hit + FLINCH 30% |

Not in scope: 27 Rampage (locked move), 158 Fake Out (first-turn state),
two-turn charge moves (incl. Sky Attack's flinch), King's Rock, Serene Grace,
Safeguard, Substitute, Persim/Lum confusion cures, badge boosts and held
items in the self-hit. Future contact abilities must not trigger on a
self-hit.

### AI

`AI_CBM_Confuse` (`data/battle_ai_scripts.s:390-395`, also Swagger and
Flatter): target already confused → −5; Own Tempo → −10. The current port
treats the status2 branch as a confirmed no-op.

## Design

- State on the battler (not persisted): `confusionTurns` (0-7) and
  `flinched` (bool). Faint clears both; switch-in battlers start clean.
- A small pure helper (or `StatusConditions` additions) for confusion
  apply/decrement; the engine owns RNG order.
- Cancellers inserted in `resolveStatusCancellers` in source order: flinch
  after freeze, confusion after flinch and before paralysis; the self-hit
  reuses `BattleFormulas.calculateBaseDamage` with a Pound-like record
  (power 40, Normal, effect 7 only when the chosen move is Explosion's
  family) and `applyRandomDamageMultiplier`, then the attacker faint path.
- Flinch applies only when the attacker is `order[1]` of a two-move turn
  (the target has not had its turn): never in hoisted switch/capture/run
  turns, never from the second mover; a first mover whose move was cancelled
  still had its turn. Keyed by side (switch-ins are fresh objects); no new
  state. Flinch flags cleared at `runTurn` start (equivalent single point).
- Snore's "fast asleep" is printed by its script after attackcanceler, i.e.
  after the flinch and confusion cancellers (a flinched sleeping Snore user
  prints only "flinched"; a confused one prints "is confused!" then "fast
  asleep"; a self-hit prints no "fast asleep").
- A self-hit KO follows the recoil-KO policy: no replacement ends the
  battle; with a replacement the turn halts and end-of-turn still runs.
- C2 secondary rolls: effects 31, 76, 146, 150 and Snore's asleep path draw
  the seteffectwithchance roll also on a no-effect hit, a KO, Shield Dust or
  an already-confused target (where the `% 4` draw is skipped); Dynamic
  Punch (100%) still draws.
- Swagger/Flatter: Substitute before accuracy; a miss prints "used", spends
  PP, then "missed"; "But it failed" only when confused and the stat is at
  +6; already confused with the stat below +6 raises the stat and skips the
  confusion silently; stat at +6 and not confused prints no stat text and
  still confuses; the Own Tempo text comes after the stat step.
- AI_CBM_Confuse branches are exclusive (confused −5 ends; else Own Tempo
  −10); the Safeguard line is commented out; AI_CV terms out of scope.
- `flinchPrevented` (Inner Focus text) is unreachable in C1/C2: every
  in-scope flinch is a 10-30% secondary, so Inner Focus blocks silently.
- Events: `flinched`, `confusedTurn` (is confused), `confusionSelfHit`
  (amount, hpRemaining), `confusionEnded`, `confusionApplied`,
  `alreadyConfused`, `confusionPrevented` (Own Tempo), `flinchPrevented`
  (Inner Focus, certain only). Source texts above.

## Slices

| Slice | Content |
| --- | --- |
| C1 | state, flinch and confusion cancellers with RNG and self-hit, flinch reset, faint clear, AI_CBM_Confuse status2 branch, texts (no move applies them yet) |
| C2 | families 76, 31, 150, 146 (secondary), 49, 118, 166, 199 (primary), Snore 92 |

## Risks

- RNG: new draws only while confused (one `& 1` per attempt, plus the
  self-hit random multiplier) and on application (`% 4`); C2 adds the
  effect rolls for the flinch/confuse hit families (previously skipped by
  the positive-power fallback, the tracked plain-hit gap).
- The self-hit faint routes through the attacker faint path like recoil.
