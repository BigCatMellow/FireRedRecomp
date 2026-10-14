# Phase 4 next-effect rerank

- Task: `P4-NEXT-EFFECT-RERANK` (research only).
- Base: `94211846d1bdd492a2f8655e9dc22738824d7e40`.
- Source pin: `pret/pokefirered` `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Result: nominate exactly one source-lock discovery; no implementation,
  route, ROM, or capability-status claim.

## Reconciled coverage

Restore HP is no longer a candidate: accepted guarded implementation
`dc8ad06` represents only ordinary Recover (105) and Slack Off (303), with
the source-locked exclusions retained. The current inventory test therefore
records effect 32 as `represented`, raising represented coverage to 51
families/139 moves and admission totals to 250/104. This corrects the older
inventory report's historical 248/106 candidate snapshot; it does not convert
ordinary positive-power fallback into effect coverage.

Persistent-status and lifecycle families remain blocked rather than merely
unimplemented: poison-hit effect 2 needs status/residual/save/UI ownership;
Defense Curl effect 156 needs its volatile bit and Rollout/Ice Ball consumer;
Trap effect 42 needs duration/residual/switch-veto state. Those are early
needs, but not isolated next leaves.

## Shortlist

| Rank | Family / source-backed story signal | Prerequisite and bounded-testability assessment | Disposition |
| --- | --- | --- | --- |
| 1 | Defense Curl 156: Brock's level-12 Geodude explicitly has `MOVE_DEFENSE_CURL` ([party](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/data/trainer_parties.h#L5604)). | Existing Defense stages alone are insufficient because the source sets a volatile bit consumed by Rollout/Ice Ball. | Blocked on volatile-state design. |
| 2 | Trap 42: Brock's level-14 Onix explicitly has `MOVE_BIND` ([party](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/data/trainer_parties.h#L5615)). | Bind needs persistent duration, residual HP, and run/switch veto. | Blocked on trap-lifecycle design. |
| 3 | Magnitude 126 / move 222: Hiker Alan's level-21 Geodude explicitly has `MOVE_MAGNITUDE` ([party](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/data/trainer_parties.h#L1493)). | Candidate rather than represented: the existing singles damage path can support a source investigation, but the random magnitude table, source text/event ordering, target loop, and Underground/doubles exclusions require a literal contract. | **Discovery-ready.** |
| 4 | Haze 25 / move 114: Biker Goon's level-37 Koffing has `MOVE_HAZE` ([party](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/data/trainer_parties.h#L7316)). | Existing stat stages help, but resetting both battlers, accuracy/event order, and prevention interactions require source policy; it is later than the early/midstory cases above. | Candidate, lower priority. |

## One successor

Propose exactly one successor: **`P4-F1-MAGNITUDE-DISCOVERY` — a read-only
source lock for effect 126 / move 222 in represented singles.** The pinned
[Magnitude script](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L1679)
orders cancellation, announcement, PP reduction, target selection, random
magnitude calculation, message, then the shared hit loop. The pinned
[command](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L8284)
maps `Random() % 100` to levels 4–10 and powers 10/30/50/70/90/110/150 before
choosing a valid target. Discovery must lock RNG draw/order, exact table,
dynamic-power ownership, message/event boundary, and whether a one-target
singles subset can explicitly exclude Underground, all-target looping,
doubles, abilities/items, cancellation, and visual timing.

This is source-lock authority only. It does not admit Magnitude, implement a
damage rule, infer parity from positive-power fallback, open a ROM, or select
an implementation route.

## Evidence boundary

Read-only inspection covered the accepted register, inventory/test
classification, Restore HP result, current `BattleEngine` boundary, and the
pinned public source files above. No ROM, extracted data, runtime test, or
implementation was used. Independent review must assess this exact report and
the appended task handoff before an Orchestrator compiles the proposed source
lock.
