# Effect-45 represented-singles design and entry-state stop

- Task: [P4-F2-RECOIL-IF-MISS-DESIGN](../tasks/phase4-recoil-if-miss-design.md).
- Worker outcome: `STOPPED — ENTRY-STATE SOURCE FACTS REQUIRED`.
- Review status: `PENDING INDEPENDENT EXACT-REPORT REVIEW`.
- Published inspection revision: `a2d6779d2e86cd322f595b0f9e0b286ca2c77457`.
- Local inspection revision: `a6a055e0a0993da068382f094ba4e9c2f2c052b7`;
  its goal/routing reconciliation does not change the four inspected code files.
- Source authority: the [accepted source lock](phase4-recoil-if-miss-source-discovery.md)
  and [independent PASS](../reviews/2026-10-10-recoil-if-miss-source-discovery-review.md)
  published at `c218da6`, pinning public `pret/pokefirered`
  `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

The source lock establishes the script sequence and crash transform, but it
does not establish the incoming source critical/damage multiplier defaults
needed to select a concrete represented damage calculation on the miss
branch. Current project code has no such incoming state. The task requires
stopping when design needs facts beyond that lock or unrepresented state.
This report therefore preserves the settled design constraints and identifies
the exact remaining decision; it is not a completed executable design,
implementation authority, or claim of current effect-45 support.

## Literal selection and admission

The selected family is the conjunction of effect `45` and move ID `26` or
`136`: Jump Kick (70 power, Fighting, 95 accuracy, 25 PP) and Hi Jump Kick
(85 power, Fighting, 90 accuracy, 20 PP). Both are selected-target,
priority-zero moves with zero secondary-effect chance in the accepted lock.
This is neither all positive-power moves nor a dispatch on an English name.
Synthetic records with another ID or effect do not acquire the crash leaf.
Malformed or modified records are not a new supported input class.

[Current supportsMove](../../src/core/BattleEngine.lua#L876) admits both
through its positive-power fallback. Admission already exists but does not
prove crash support. The future leaf must be selected literally; changing
the broad admission policy is outside this design. The existing
[RECOIL_MOVES table](../../src/core/BattleEngine.lua#L599) covers effects
48 and 198 only, uses actual defender HP damage, and remains independent.
Neither a missed ordinary recoil move nor any other generic miss acquires
effect-45 crash behavior.

A successful accuracy decision continues through the current ordinary hit
path: crit, base damage, type, random adjustment, target HP, and current
common completion. No crash result or extra self-damage follows a successful
hit, including an ordinary successful-accuracy hit that later encounters
Fighting immunity. The design preserves that existing path and its limits;
it does not certify its whole-source parity anew.

## Settled miss sequence and unresolved entry state

The following is a required ordering contract, conditional on the source
entry-state questions below being independently resolved. It translates only
the accepted lock's `battle_scripts_1.s:810-833` sequence.

1. Retain shared eligibility, ordinary accuracy, used-move announcement, and
   one PP deduction. In this engine, `useMove` is appended at
   [line 973](../../src/core/BattleEngine.lua#L973), ordinary accuracy at
   [1080](../../src/core/BattleEngine.lua#L1080), PP at
   [1103](../../src/core/BattleEngine.lua#L1103), and `miss` at
   [1107](../../src/core/BattleEngine.lua#L1107). The source announcement
   occurs after accuracy; the engine queues it before that calculation.
   Preserve the existing observable event order, without claiming identical
   internal instruction timing. Do not repeat accuracy or PP in the crash leaf.
2. After the miss result, test the *pre-existing*
   `MOVE_RESULT_DOESNT_AFFECT_FOE` state. If set, complete the action without
   a crash result, damage-adjustment draw, HP change, or attacker faint caused
   by crash. This is not the later type calculation's immunity result.
3. If that guard permits continuation, emit a distinct crash result before
   the attacker HP presentation. There is no target attack animation, target
   HP update, critical result, or effectiveness presentation on this branch.
4. Compute damage in the locked order: ordinary base calculation with the
   source's incoming multipliers; type/STAB calculation; normal damage
   adjustment; then the crash transform. No `critcalc` occurs here. No
   ordinary actual-hit recoil fraction or actual defender HP loss is an input.
5. For adjusted damage `D`, first take integer `floor(D / 2)`, promote a
   zero result to one, then cap at `floor(target.maxHP / 2)`. There is no
   second minimum clamp. The target's current HP is not the cap, nor is the
   attacker's maximum HP. As arithmetic examples: `D=7`, target max HP 100
   gives 3; `D=1` gives 1; `D=100`, target max HP 9 gives 4; target max HP 1
   gives 0 after the cap. The last example is a transform edge, not a claim
   of a legal retail battler fixture.
6. For a source-eligible attacker HP update, remove at most the attacker's
   remaining HP and record that actual amount and remaining HP. Target HP
   stays unchanged. Run the existing attacker faint handling after this HP
   event, then return to common action completion. The source clears and
   restores `MOVE_RESULT_MISSED` around HP/faint handling; the engine's
   already-queued `miss` result must remain visible and must not be replaced
   with a hit. Adding a global source-flag system is not authorized here.

### Required source clarification; no guessed defaults

The accepted lock explicitly says `Cmd_damagecalc` applies the current
critical and damage multipliers, and explicitly says this branch has no
`critcalc`. It does not lock where those values are reset for an ordinary
action, what their values are on this edge, or whether a preceding critical
action can affect them. Current
[ordinary hit calculation](../../src/core/BattleEngine.lua#L1276) obtains a
fresh local critical result only after the miss early return. Neither
`BattleEngine.new` nor the miss seam carries the source's incoming critical
or damage multiplier state. Substituting `isCrit=false` and neutral
multipliers solely because there is no new critical roll would be an
unsupported inference. This is the decisive stop condition.

The source guard also has no current project owner: `accuracyCheck` returns
a Boolean, and `resolveMove` has no pre-existing move-result bitfield.
Its existing `flags.noEffect` comes from subsequent type calculation. The
accepted lock already excludes the cancellation/protection/interception
systems that can supply the earlier guard. Thus the design can name the
guard and exclude those producers, but cannot claim to test or preserve an
implemented guard in this engine. A fabricated always-false flag or early
Fighting-immunity test would not resolve this gap. Any later bounded
projection must explicitly justify, from locked entry/reset behavior, why
the guard is clear for the admitted ordinary accuracy-miss context.

There is a related edge to settle before executable HP expectations: a type
calculation *inside* the miss branch can introduce a new no-effect result.
The accepted lock distinguishes that result from the earlier guard, but
does not lock the full `datahpupdate` command's handling of that newly set
result. Do not automatically turn zero type damage into a one-HP crash, or
skip the branch before its random adjustment, without establishing the
downstream HP command's result-flag gate. The script command sequence alone
does not prove every command's internal no-effect behavior.

The minimum unblock is a separately authorized, read-only supplement at the
same public-source pin: trace ordinary action entry/reset through effect 45
for those multipliers and result flags, and the attacker HP command's handling
of the newly computed no-effect result. Establish which facts reduce to
represented ordinary singles and which remain excluded. No implementation,
generic flag API, route, ROM observation, or new subsystem is a substitute
for that source evidence. This report does not perform or authorize that
supplement.

## RNG, PP, and firstBattle constraints

For an ordinary represented accuracy comparison, there is one shared
accuracy draw. If the miss guard permits damage adjustment, the represented
[random multiplier helper](../../src/core/BattleFormulas.lua#L415) consumes
one later draw even for zero input damage. No critical, secondary-effect,
second accuracy, or ordinary recoil draw belongs to the crash branch. These
are branch-local draw expectations; turn-order selection and a later action
can consume other RNG. Source item/Endure/Focus Band logic is excluded rather
than modeled by this two-draw outline.

Current `firstBattle` handling deliberately bypasses the first damaging
player accuracy draw while `tutorialPlayerDamageDone` is false
([1080](../../src/core/BattleEngine.lua#L1080)); that branch cannot produce
an ordinary accuracy miss. Foe actions and subsequent player actions retain
ordinary accuracy. A future crash must not bypass this gate, add a critical
draw, set `tutorialPlayerDamageDone`, or emit the damage tutorial tip.
[applyDamage](../../src/core/BattleEngine.lua#L1502) both targets the defender
and advances that tutorial flag, so calling it with switched sides is not a
valid self-damage shortcut. This is preservation of current firstBattle
behavior, not a new claim that the source lock proves effect-45 tutorial
parity or supplies effect-45 moves during the normal tutorial.

Shared PP behavior remains exactly one reduction on hit or ordinary miss,
including a guard-stopped miss and a fatal crash. There is no refund. The
existing selected-zero-PP early return at
[967](../../src/core/BattleEngine.lua#L967) and all-slots-empty auto-Struggle
selection at [905](../../src/core/BattleEngine.lua#L905) retain their current
behavior. Auto-Struggle is effect 48 and cannot become an effect-45 crash.
Other cancellation and no-PP source systems remain excluded.

## Smallest event, faint, controller, and persistence ownership

The engine owns selection, RNG, PP, calculated crash amount, actual attacker
HP, and faint/outcome state. A single dedicated crash result can carry the
attacker side, actual HP loss, and resulting attacker HP. This is a semantic
design, not a finalized event schema or generic self-damage API. Only the
literal miss leaf may emit it. Existing `recoil` and defender `damage` events
must not stand in for it.

The visible sequence is `useMove` → `miss` → crash announcement → attacker
HP presentation → optional attacker `faint` → existing battle-end or
forced-switch continuation. Nonfatal completion returns to the current turn
owner. The crash result must not produce a target faint check itself.
[checkFaint](../../src/core/BattleEngine.lua#L1629) owns attacker faint
recording and delegates to the existing
[faint finalizer](../../src/core/BattleEngine.lua#L842). A bench replacement
can leave the battle outcome unset while queuing a forced switch. The
[runTurn completion guard](../../src/core/BattleEngine.lua#L1804) must retain
its checks for both ended battle and pending forced switch; a remaining
opponent action must not attack the same-turn-fainted attacker. No new
replacement, simultaneous-KO, or common MoveEnd implementation is proposed.

[BattleSceneController._eventMessages](../../src/core/BattleSceneController.lua#L177)
owns translation to message entries. A crash result needs a distinct
announcement associated with the attacker, followed by a separate invisible
attacker-HP entry. The crash message must finish before the HP entry is
consumed; joining HP metadata to the text entry does not supply this ordering.
[_applyInvisibleEntries](../../src/core/BattleSceneController.lua#L103)
changes displayed HP only for entries without text, and
[advanceMessage](../../src/core/BattleSceneController.lua#L133) drains them
after a message advances. Thus the existing ordered queue is sufficient as a
presentation seam; the controller must not compute damage, consume RNG, or
write model HP. The exact source crash wording is not reproduced here; the
lock identifies `STRINGID_PKMNCRASHED`, and timing/animation parity is excluded.

[Controller turn completion](../../src/core/BattleSceneController.lua#L350)
already selects COMPLETE, forced PARTY, or ACTION based on engine state.
Preserve message draining before that transition, including existing
foe-replacement hooks. This design creates no new party UI.

[BattlePartyBridge.persistPartyBattler](../../src/core/BattlePartyBridge.lua#L178)
copies current battler HP and move PP to the party record, re-encoding the
existing boxed data. A future crash changes the same two existing model
values, so no new persisted crash field or save schema is indicated. The
bridge remains the persistence owner; controller display HP is not save
state. Reading this seam does not prove that every battle lifecycle invokes
it correctly for a fatal crash. Later authorized integration evidence must
cover persistence, including HP zero and spent PP, without changing save
policy or claiming an unrun save/reload test.

## Deterministic later acceptance outline, conditional on unblock

No tests or commands are authorized by this outline. A separately scoped
implementation contract would need these observable checks and exact source
oracles after the unresolved entry/HP facts are locked:

| Case | Required later observation |
| --- | --- |
| Both literal records, player and foe | A forced ordinary accuracy miss uses the source-locked formula and ordered crash result; only attacker HP changes. |
| Literal boundary | Other move IDs/effects, including effects 48/198 and unrelated generic misses, retain prior behavior. |
| Successful accuracy | Existing crit/base/type/random/target-HP and faint flow remains unchanged; no crash event or added self-damage. |
| Earlier no-effect guard | Source guard true yields miss/result completion with no crash damage draw or HP event. If this cannot be reached in represented state, document it as excluded and verify that limitation; do not invent a production flag just to obtain a test. |
| Later type immunity | Distinguish successful-hit immunity, earlier guard suppression, and newly computed miss-branch immunity; defer exact HP oracle until the downstream command gate is locked. |
| Transform edges | Odd division, zero-before-minimum, target maximum vs current HP, target vs attacker maximum HP, cap boundary, and zero-after-cap arithmetic; no extra minimum after cap. |
| Attacker HP clamp/faint | Actual amount cannot exceed remaining HP; HP zero precedes one attacker faint, then existing end/replacement behavior; no target HP/faint and no duplicate faint or extra opponent action. |
| RNG and PP | Accuracy then allowed random adjustment, no critical/extra draw, correct next RNG sentinel, one PP deduction, no refund; pre-existing noPP/auto-Struggle behavior retained. |
| First battle | Preserved player accuracy bypass and successful-hit tutorial behavior; later/foe misses cannot create tutorial damage tips or set the player damage flag. |
| Screens and stages | Once neutral critical state is source-locked, represented defender Reflect and attacker/defender stages feed base damage before STAB/type/random/half/cap, without invoking a critical bypass. |
| Controller ordering | Advance message entries one at a time: use, miss, crash while HP still old, then attacker HP change before faint/continuation; defender display unchanged. |
| Persistence | Existing party bridge receives model HP and PP, including fatal crash; no new save state. Integration claims require separately authorized evidence. |
| Regression | Ordinary hit/recoil/drain/miss, current accepted families, common turn completion, forced replacement, and existing tutorial behavior retain prior evidence. |

## Exclusions and exact evidence

All source-lock exclusions remain: cancellation/interception, Protect,
Substitute, abilities, items, Endure/Focus Band, status,
semi-invulnerability, called/mirrored provenance, doubles/links, malformed
battlers, and animation/timing parity. Every other effect family is excluded.
No flag/multiplier API, generic recoil/miss abstraction, move admission repair,
AI, runtime, controller, test, save, route, request, probe, runner, ROM, or
capability-status change was made. No source facts beyond the accepted lock
were investigated; no ROM, private runner state, media, runtime, or gameplay
test was inspected or executed.

Read-only live `git ls-remote origin refs/heads/main` returned the published
revision above. Reading the source-lock task/report from `c218da6` reproduced
the independent review's SHA-256 identities:

- Task: `eef1410841e6cecdc0ca16a8b239b16cae2b15a8119999b8623a352ec412b59a`.
- Report: `53cb79e29f2694c3688fa557a091553858a483312be8a5d021161ddf20d7d125`.
- Accepted review: `91ba7099006f2ecefa1b17e9bdee50985b66f1507fe39162ca36ada572bf9140`.

`git diff c218da6 HEAD --` for the four named code files produced no changes.
Current anchors above were read from the actual files rather than repeating
the historical source-lock line numbers. Inspected SHA-256 identities:

- BattleEngine: `6c37018f218ed3fce5f9d96273740ca2eaa239bb6cf5800d1440127a6bd02b7f`.
- BattleFormulas: `8fd2b574c1de99af13441bcdae3e49224c6b970c5140f5bcc5e46bd59d9ebb5e`.
- BattlePartyBridge: `359c02b5eb10db5c2c526830485a32abc157336aeb6b0c2b1cf4d36fae665e56`.
- BattleSceneController: `386678b34c2d7141eb66b3c4bf702996d5a88095a8866ad35423926cff3caf05`.

The active task's read-only evidence rule applies: baseline/focused checks
were source consistency and code inspection, not test execution. Full
runtime verification is N/A. The Worker must provide the report/task hashes
and final `git diff --check` receipt to the independent Reviewer. The
Reviewer decides PASS, NEEDS_FIX, or BLOCK; the Worker does not self-certify.
Until the identified source requirement is resolved, the concrete handoff is
independent assessment of this stop and its minimum separate discovery
boundary, not route readiness or implementation dispatch. Phase 4 remains
open.
