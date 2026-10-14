# Effect-45 design and source-certainty stop — independent review

Verdict: **BLOCK** for completion of `P4-F2-RECOIL-IF-MISS-DESIGN`.
The report accurately records the task's required source-certainty stop;
it is not an accepted complete design and grants no route or implementation
allowance. This verdict does not revoke the previously accepted source lock.

- Exact reviewed task/report revision:
  `f31ae695a6e72f73c1a2dbe747024a445d4ca950`.
- Independently recovered live `main` and coordination checkpoint:
  `b85d281bde37f773e9637c338e3609dd8575d19d`, `READY_FOR_REVIEWER`.
- [Task](../tasks/phase4-recoil-if-miss-design.md) SHA-256:
  `ccd5a3d38243507d2a04bded621a7a012ccbea4d569fb854f97b0dd07fcfabf9`.
- [Report](../reports/phase4-recoil-if-miss-design.md) SHA-256:
  `6e27a294c916cc91b639c51f5d53ca4598bd91fec81f299e10350325f19bda1b`.
- Source authority: accepted task/report and
  [independent review](2026-10-10-recoil-if-miss-source-discovery-review.md)
  at `c218da6e844ada8bbf2b5f840919e4f6f428e932`.

## Independent findings

The exact two-file diff adds the report and a task evidence/stop handoff only.
The original design criteria, scope and stop conditions remain unchanged.
The later coordination commit does not change either reviewed artifact.
No runtime, test, event schema, admission policy, save, workflow, route,
request, runner, ROM, or canonical capability state is changed by the pair.

The accepted source lock establishes that the miss branch omits `critcalc`
but `damagecalc` uses the current critical and damage multipliers. It does
not establish the ordinary action reset owners or the actual incoming values
on that edge. Direct project inspection confirms the existing ordinary hit
path rolls and stores a fresh local critical result only after the miss
early return; no corresponding source multiplier state is carried into the
miss branch. Absence of a new critical roll alone is insufficient evidence
for the concrete critical/stage/screen calculation. The report correctly
leaves that conclusion unresolved rather than inventing neutral defaults.

The earlier no-effect guard and later type immunity are also distinct.
The accepted lock places the guard before the branch's `typecalc`; project
`accuracyCheck` supplies a Boolean and project `flags.noEffect` is produced
by later type calculation. The project has no equivalent incoming result
bitfield. The lock names attacker health-bar/data HP commands but does not
lock their internal handling of newly set no-effect flags. Consequently,
neither a fabricated always-clear flag, an early type-immunity return, nor
automatic minimum-one attacker damage is justified from this record alone.
The report poses these as unresolved questions, not newly discovered source
semantics. This review has not fetched or inferred the missing answers.

Those gaps trigger the existing stop clause requiring a halt when the design
needs source facts beyond the accepted lock or unrepresented source state.
They prevent an executable interpretation of criteria 2 and 4 and the final
HP/event outcomes under criterion 3. The accurate stop is accepted as an
evidence finding, not converted into a design PASS.

The settled portions are consistent with the permitted evidence:

- Literal effect 45 / IDs 26 and 136 selection is kept separate from existing
  broad admission, generic misses, and ordinary effects 48/198 actual-hit
  recoil. The successful-hit path remains unchanged.
- Accuracy, one PP deduction, miss, the earlier guard, a distinct crash
  result, base/type/random adjustment, integer half/minimum-one/target-max-HP
  cap, attacker-only HP, attacker faint and common completion remain in the
  locked order. The zero-after-cap arithmetic example is explicitly not a
  claim of a legal retail battler. Unresolved HP gating remains conditional.
- Direct code inspection confirms the random helper consumes a draw even
  with zero input, the firstBattle player accuracy bypass, and the existing
  damage helper's defender/tutorial side effects. The report does not turn
  its branch-local draw outline into a whole-turn parity assertion.
- The existing faint and runTurn completion owners stop at battle end or a
  pending forced switch. Controller invisible HP entries are consumed only
  between message entries, so a dedicated announcement followed by an
  invisible attacker HP entry is a coherent bounded presentation seam.
  The report correctly avoids reusing ordinary recoil and does not propose
  a new party UI or generic source-flag API.
- The party bridge already persists model HP/PP. Its availability is not
  relabeled as fatal-crash integration, save/reload proof, or a save change.
  Later acceptance rows remain conditional outlines, not test execution or
  implementation authority. All source-lock exclusions remain explicit.

## Checks and evidence limits

Independently reproduced both exact artifact hashes and all four reported
project-code hashes. The inspected `BattleEngine`, `BattleFormulas`,
`BattlePartyBridge`, and `BattleSceneController` are unchanged between
`c218da6` and `f31ae69`. The source review's recorded hash also matches.
Read the accepted lock/review and actual current owner code rather than
treating the Worker's assertions as proof.

`git diff --check f31ae69^ f31ae69` passed. Repository checker passed at the
review checkpoint: **280 tracked Lua, 253 tracked Markdown, 795 local
targets**. The Worker session's reported service interruption does not supply
a final Worker verification receipt; these checks are independently rerun
Reviewer evidence. No gameplay tests, ROM, private runner, runtime experiments,
new source discovery, or route actions were used or needed for this verdict.

## Minimum unblock and next allowance

The Orchestrator may compile one separately bounded read-only source supplement
at the same `pret/pokefirered` pin
`c75f352304d529f6ba92d4f74b9cf8b5c3810788`. Its minimum questions are:

1. Trace ordinary selected-move entry/reset through the effect-45 accuracy
   miss to establish the incoming critical and damage multipliers, reset
   timing, and whether previous-action state can survive into this edge.
2. Trace result-flag reset/producers only far enough to establish the earlier
   no-effect guard for represented ordinary singles; classify excluded
   cancellation/protection/interception producers without implementing them.
3. Lock the relevant attacker health-bar/data HP command gates after the
   branch's type calculation, including newly computed immunity, the clearing
   and restoration of MISSED, and consequences for actual HP/faint behavior.
   Preserve command/RNG ordering and distinguish damage-transform arithmetic
   from an authorized HP application.

That supplement requires its own exact independent review. It may narrow or
resolve these facts, but may not add a generic flag system, broaden effect
coverage, inspect a ROM, or grant route/implementation authority. After an
accepted supplement, resume this design with those source facts explicitly
incorporated and obtain a new exact-design review. Until then, this design
remains blocked; Phase 4 and all other capability gates remain unchanged.

Only this review artifact was authored. The parent owns coordination and
publication; no correction, staging, commit, or push was performed here.
