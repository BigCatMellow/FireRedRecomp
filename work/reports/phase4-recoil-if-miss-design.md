# Effect-45 represented-singles design

- Task: [P4-F2-RECOIL-IF-MISS-DESIGN](../tasks/phase4-recoil-if-miss-design.md).
- Worker outcome: `DESIGN READY FOR INDEPENDENT REVIEW`.
- Review status: `PENDING INDEPENDENT EXACT-REPORT REVIEW`.
- Published/local inspection revision:
  `4dd22e1d80ea40e485ee134e59499183e31847f3`.
- Source authority: the [accepted source lock](phase4-recoil-if-miss-source-discovery.md)
  and [independent PASS](../reviews/2026-10-10-recoil-if-miss-source-discovery-review.md)
  published at `c218da6`, pinning public `pret/pokefirered`
  `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Controlling supplement: [entry-state source report](phase4-recoil-if-miss-entry-state-discovery.md)
  at `ba692697221e50aa054d0f981684771bf51ccaed` and its
  [independent PASS](../reviews/2026-10-12-recoil-if-miss-entry-state-review.md).

The accepted supplement resolves the historical source stop. This bounded
design distinguishes two ordinary accuracy-failure outcomes: an immune
target produces a no-effect result and immediate completion; a nonimmune
target produces miss, crash, and attacker HP/faint handling. The source
resets critical/damage multipliers to 1/1 before the ordinary action. Those
facts permit the represented leaf below without inventing an incoming flag
system. This is design only, pending its own independent review; it does not
authorize implementation or claim current effect-45 support.

## Historical stop, preserved separately

The previous report at `f31ae69` stopped for missing multiplier/reset,
ordinary no-effect-producer, and downstream HP facts. Its SHA-256 is
`6e27a294c916cc91b639c51f5d53ca4598bd91fec81f299e10350325f19bda1b`;
the paired task was
`ccd5a3d38243507d2a04bded621a7a012ccbea4d569fb854f97b0dd07fcfabf9`.
The [independent BLOCK](../reviews/2026-10-11-recoil-if-miss-design-review.md)
accepted that stop, not design completion. Its original inspection was
published `a2d6779` / local `a6a055e`. Those exact artifacts remain in Git
history. In particular, their suggestion that the earlier immunity guard
only had excluded producers and their universal miss-then-crash outline are
superseded by the accepted supplement. The current sections below govern
this resumed design; the historical claims must not be used as instructions.

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

## Ordinary accuracy-failure sequence

This contract translates the accepted source chain. The supplement supplies
the corrected exact script anchor `battle_scripts_1.s:848-871`, ordinary
reset `battle_main.c:3963-3980`, accuracy failure/precheck
`battle_script_commands.c:1092-1105` and `1345-1387`, and result selection
`1930-1964`. Historical anchors in the original lock are displaced.

1. Retain shared eligibility, ordinary accuracy, used-move announcement, and
   one PP deduction. In this engine, `useMove` is appended at
   [line 973](../../src/core/BattleEngine.lua#L973), ordinary accuracy at
   [1080](../../src/core/BattleEngine.lua#L1080), PP at
   [1103](../../src/core/BattleEngine.lua#L1103), and `miss` at
   [1107](../../src/core/BattleEngine.lua#L1107). The source announcement
   occurs after accuracy; the engine queues it before that calculation.
   Preserve the existing observable event order, without claiming identical
   internal instruction timing. Do not repeat accuracy or PP in the crash leaf.
2. On failed ordinary accuracy, and only for the literal family, determine
   ordinary type immunity before choosing the result event. The source
   accuracy command sets MISSED then scans immunity, so the source result
   is `0x09` for an immune target and `0x01` for a nonimmune target. Emit
   existing `noEffect` for the immune branch, naming the defender, and
   complete immediately: no generic miss announcement, crash result,
   base-damage calculation, damage-adjustment draw, HP update, or attacker
   faint check. PP remains spent. This preserves the source's pre-existing
   DOESNT_AFFECT_FOE guard; it is not a later damage-type immunity decision.
3. Otherwise emit the existing `miss` result, then a distinct crash result
   before the attacker HP presentation. There is no target attack animation, target
   HP update, critical result, or effectiveness presentation on this branch.
4. Compute damage in the locked order: ordinary base calculation with
   explicit neutral critical/damage multipliers 1/1; type/STAB calculation;
   normal damage adjustment; then the crash transform. No `critcalc` occurs here. No
   ordinary actual-hit recoil fraction or actual defender HP loss is an input.
   Use the represented noncritical stage behavior and defender-side Reflect;
   do not ignore lowered attack, raised defense, or screens as a critical
   calculation would. Move power/type stay the immutable literal record.
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

### Represented seams and limits of the projection

Current `accuracyCheck` returns a Boolean, and the
[miss return](../../src/core/BattleEngine.lua#L1107) has no immunity precheck.
The bounded owner is this literal failed-accuracy leaf in `resolveMove`,
before appending `miss`. The existing pure
[typeCalc](../../src/core/BattleFormulas.lua#L347) can determine ordinary
immunity from the same parsed type rows, move type, and defender types:
inspect only its `noEffect` result using a harmless positive seed amount;
discard the temporary damage and super/not-very-effective flags. It consumes
no RNG and changes no model state. This preliminary immunity query is
distinct from the later real damage/STAB/type calculation, does not supply
crash damage, and introduces no generic accuracy or flag API. Do not hardcode
a species/Ghost check or enable the source helper's excluded ability/Foresight
branches. The pure seam matches ordinary zero type rows in either target
type; other computed flags have no meaning for this precheck.

[calculateBaseDamage](../../src/core/BattleFormulas.lua#L225) then receives
noncritical input and the defender's current screen state for the nonimmune
leaf. The accepted per-action resets justify these inputs even after another
action rolled a critical; there is no persistent multiplier to inherit or
critical draw to insert. Subsequent `typeCalc` supplies the actual STAB/type
damage, followed by `applyRandomDamageMultiplier`. Its presentation flags
must not become damage/effectiveness messages: the source leaves MISSED set
through type calculation, suppressing those result-bit updates while still
applying damage multipliers. Current successful-hit logic at
[1276](../../src/core/BattleEngine.lua#L1276) retains its existing local
critical calculation and must not be rerouted through this noncritical leaf.

The supplement establishes that both attacker HP commands independently
test `NO_EFFECT = MISSED | DOESNT_AFFECT_FOE | FAILED`. For the ordinary
nonimmune miss, clearing MISSED permits both updates, then its restoration
preserves the missed result on completion. For ordinary immune failure,
the earlier guard exits before either command. These two reachable branches
are sufficient within valid living ordinary singles; no fabricated source
bitfield is needed in the project.

If a different, excluded path introduced immunity only during the later
type calculation, the retained DOESNT_AFFECT_FOE bit would suppress both HP
updates despite clearing MISSED and setting IGNORE_SUBSTITUTE. Adjustment
would still draw if reached, the arithmetic transform would still run,
and a living attacker would not faint. This is conditional source semantics
only. The ordinary precheck sees the same move and target types, and no
intervening ordinary command changes them. A late-only immunity fixture is
therefore not a reachable ordinary oracle, not a one-HP crash case, and not
permission to add new flags/state. Encountering a requirement for such state
would trigger the task's existing stop rule.

## RNG, PP, and firstBattle constraints

For an ordinary represented accuracy comparison, there is one shared
accuracy draw. Immune failure then completes with no additional draw.
For nonimmune failure the represented
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

The immune-failure visible sequence is `useMove` → `noEffect` → current
common completion, with both HP displays unchanged. It cannot also emit
`miss`, crash, effectiveness, or faint events for this action.

The nonimmune sequence is `useMove` → `miss` → crash announcement → attacker
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

## Deterministic later acceptance outline

No tests or commands are authorized by this outline. A separately scoped
implementation contract would need these observable checks against the
accepted source-chain oracles:

| Case | Required later observation |
| --- | --- |
| Both literal records, player and foe | A selected move with a controlled failing accuracy draw against a nonimmune target uses the source-locked formula and ordered crash result; only attacker HP changes. This is ordinary selected-move provenance, not a forced/called move mechanic. |
| Literal boundary | Other move IDs/effects, including effects 48/198 and unrelated generic misses, retain prior behavior. |
| Successful accuracy | Existing crit/base/type/random/target-HP and faint flow remains unchanged; no crash event or added self-damage. |
| Ordinary immunity guard | A failing accuracy draw against ordinary Fighting-immune target types, including either position of a dual type, yields only useMove/noEffect for this action, one spent PP, no crash/base-damage/adjustment/HP/faint, and unchanged HP. Use real type rows, not injected flags. |
| Immunity distinction | Successful-accuracy immunity stays on the existing hit path with its existing draws. Failed-accuracy immunity exits before crash. Conditional late-only immunity remains a documented exclusion, not a reachable battle fixture or minimum-one HP oracle. |
| Transform edges | Odd division, zero-before-minimum, target maximum vs current HP, target vs attacker maximum HP, cap boundary, and zero-after-cap arithmetic; no extra minimum after cap. |
| Attacker HP clamp/faint | Actual amount cannot exceed remaining HP; HP zero precedes one attacker faint, then existing end/replacement behavior; no target HP/faint and no duplicate faint or extra opponent action. |
| RNG and PP | Nonimmune failure consumes accuracy then adjustment; immune failure only accuracy; no critical/extra draw, correct next RNG sentinel, one PP deduction, no refund. Scope counts to the action or account separately for speed ties/other actions. Pre-existing noPP/auto-Struggle behavior retained. |
| First battle | Preserved player accuracy bypass and successful-hit tutorial behavior; later/foe misses cannot create tutorial damage tips or set the player damage flag. |
| Screens, stages, and reset | Neutral 1/1 calculation honors represented defender Reflect and attack/defense stages before STAB/type/random/half/cap, with no critical bypass. A preceding critical action cannot alter the crash oracle. |
| Controller ordering | Nonimmune: advance use, miss, crash while display HP still old, then attacker HP changes through the invisible entry before faint/continuation; defender display unchanged. Immune: use/noEffect only, with no HP entry. Model HP may already be final while messages drain. |
| Persistence | Existing party bridge receives model HP and PP, including fatal crash; no new save state. Integration claims require separately authorized evidence. |
| Regression | Ordinary hit/recoil/drain/miss, current accepted families, common turn completion, forced replacement, and existing tutorial behavior retain prior evidence. |

## Exclusions and exact evidence

All source-lock exclusions remain: cancellation/interception, Protect,
Substitute, abilities, items, Endure/Focus Band, status,
semi-invulnerability, called/mirrored and other nonordinary move provenance,
multi-turn/forced selection, doubles/links, unsupported target/party state,
malformed battlers, animation/timing parity, and generic MoveEnd/whole-turn
parity. Every other effect family is excluded.
No flag/multiplier API, generic recoil/miss abstraction, move admission repair,
AI, runtime, controller, test, save, route, request, probe, runner, ROM, or
capability-status change was made. No source facts beyond the accepted chain
were investigated; no ROM, private runner state, media, runtime, or gameplay
test was inspected or executed.

Read-only live `git ls-remote origin refs/heads/main` returned the published
revision above. Reading the source-lock task/report from `c218da6` reproduced
the independent review's SHA-256 identities:

- Task: `eef1410841e6cecdc0ca16a8b239b16cae2b15a8119999b8623a352ec412b59a`.
- Report: `53cb79e29f2694c3688fa557a091553858a483312be8a5d021161ddf20d7d125`.
- Accepted review: `91ba7099006f2ecefa1b17e9bdee50985b66f1507fe39162ca36ada572bf9140`.

The supplement at `ba69269` matches its independent review's task/report
SHA-256 identities:

- Task: `99a045f0c8a4079dbf822b9e2a778519c77fa42c462c984333a6abb3aa92d587`.
- Report: `92b990bf18b91729a468eab599fdced128238a6712c76a5f29ea730db56e4484`.

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
The read-only repository checker passed after the report revision: 280
tracked Lua, 269 tracked Markdown, 846 local targets. Baseline and revised
whitespace checks passed. Final pair receipts are recorded in the task
handoff and Worker delivery, without embedding self-referential hashes.
No unresolved source requirement remains within this design's ordinary
represented boundary. The concrete handoff is independent review of the
revised task/report against the reactivated criteria and accepted supplement.
Only a design PASS may permit the Orchestrator to compile one separately
bounded route or implementation-authority decision; this report grants no
such authority. Phase 4 remains open.
