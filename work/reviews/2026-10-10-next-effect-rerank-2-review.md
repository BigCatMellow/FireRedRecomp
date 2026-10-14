# P4-NEXT-EFFECT-RERANK-2 — independent review

Verdict: **PASS** for the corrected exact uncommitted task/report pair. The
package selects exactly one evidence-backed successor, supplies the required
comparative ranking and pinned source anchors, and remains strictly
read-only. This PASS grants no source-discovery execution, implementation,
route, ROM action, or Magnitude-scope expansion.

## Exact artifacts and review boundary

Reviewed from `/tmp/firered-outcome-reconcile` at base
`e83fc4517dd1d9dc3dbcd236cbf1e5cb94eadeb0`:

- Task `work/tasks/phase4-next-effect-rerank-2026-10-10.md`, SHA-256
  `4b3130b7618f49326f55ad27443c73079fa44bd6a9f86f28c807654c584383c8`.
- Corrected report `work/reports/phase4-next-effect-rerank-2026-10-10.md`,
  SHA-256 `9b449cf357747fc3f13ab22b4b775a74191d535961f49983e737ce919da68d29`.

Both artifacts are untracked at review time. The current worktree also has
separate untracked post-Magnitude rerank artifacts and pre-existing modified
coordination files; those are outside this exact pair and were not reviewed
or changed. `git diff --check` exits 0 with no diagnostics; independent
no-index whitespace checks of both untracked artifacts are also clean.

## Evidence verification

The pinned public source `pret/pokefirered` at
`c75f352304d529f6ba92d4f74b9cf8b5c3810788` supports the selection and the
corrected report's anchors:

1. `EFFECT_RECOIL_IF_MISS` is effect `45` in the pinned effect constants.
   `MOVE_JUMP_KICK` (26) and `MOVE_HI_JUMP_KICK` (136) both use effect 45 in
   the pinned move records; their positive-power, selected-target Fighting
   records are distinct from ordinary effect-48 recoil.
2. Hitmonlee's pinned level-up learnset gives Jump Kick at level 16 and Hi
   Jump Kick at level 26, matching rank 1. The independent source read also
   confirms Koffing learns Haze at level 33 and Hitmontop learns Triple Kick
   at level 20, matching the report's alternative signals.
3. The pinned battle script dispatches effect 45 to
   `BattleScript_EffectRecoilIfMiss`. The miss branch performs the attack
   announcement and PP reduction, emits the crash result, runs damage/type/
   normal-damage adjustment, applies `DMG_RECOIL_FROM_MISS`, updates the
   attacker HP, attempts attacker fainting, and returns to move end; the
   success path enters the ordinary hit sequence. The source-lock questions
   in the report therefore follow directly from the source ordering.
4. The local inventory metadata and test classify effect 45 as `candidate`,
   admitted, positive-power, with exactly members 26 and 136. The local
   `BattleEngine` explicitly documents effect 45 as not ported. The report
   does not claim existing implementation coverage or silently treat generic
   positive-power fallback as effect coverage.
5. The report now explicitly reconciles accepted Restore HP `dc8ad06` and
   bounded Magnitude `7b47c73` through their independent outcome reviews,
   while retaining those leaves' closed scope and exclusions. The inventory
   baseline is the accepted `c10bfa7` classification.

## Ranking and boundaries

The corrected table ranks exactly one selected successor above Haze, Triple
Kick, and the blocked Defense Curl/Trap pair. It provides concrete early
level-up signals, identifies Haze's two-battler zero-power reset prerequisite,
Triple Kick's rising-power/per-hit loop prerequisite, and volatile-state
blockers for Defense Curl/Trap. It preserves exactly one possible successor:
`P4-F1-RECOIL-IF-MISS-DISCOVERY` for effect 45. The report includes pinned
links for the selected effect constant, both move records, Hitmonlee's
learnset, and the effect script, plus accepted-leaf review links.

The task and report prohibit runtime, tests, admission, BattleEngine,
bridge/workflow, routes, runner/ROM, save/UI/AI, private-data, and
implementation changes. They preserve abilities/items, Substitute/
Protect/Endure, doubles/links, cancellation/MoveEnd, target/party, retail
presentation, and all Magnitude exclusions. The report records no ROM or
runtime work and grants only a later separately reviewed source-discovery
successor.

## Exact next allowance

After publication and coordination reconciliation, the Orchestrator may
compile only the separately scoped read-only
`P4-F1-RECOIL-IF-MISS-DISCOVERY` task. That successor requires its own exact
revision and independent review. This PASS does not authorize discovery
execution, effect implementation, admission changes, routing, probe/request,
ROM/replay work, or status advancement beyond this rerank gate.
