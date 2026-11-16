# Wonder Guard independent source/design review — 2026-10-31

**NEEDS_FIX** — one material predicate/presentation correction is required
before compiling an implementation contract. The source is available and
specific; this is not a source-UNKNOWN blocker. No implementation authorized
or performed by this review.

Reviewed `/tmp/firered-wonder-guard-design-20261031.md`, with context from
`/tmp/firered-ai-ability-history-design-20261030.md`. Independently read the
actual pinned pret checkout at
`c75f352304d529f6ba92d4f74b9cf8b5c3810788` and native engine/formulas/controller
at exact V4a `2139495897c5def7e0bef8fdcad0fd8e359f4dfd` in the retained clean
review worktree. The engine/formulas/controller diff from that revision to
the proposal's `c50c097` H1 base is empty. AGENTS/REVIEWER boundaries remain
in force. No ROM, runner, source-code edits, publication, merge, test-suite
campaign, or phase acceptance occurred.

## Required correction R1: preserve the three distinct scans, including zero × super

The proposal correctly warns that typecalc2 has separate local/global flags,
but its random-miss paragraph says the scan prints ability text even when
type immune without stating the super-plus-immunity exception. Its proposed
net-effectiveness test matrix does not catch this distinction. A blanket
`net effectiveness <= 1` helper is not source-correct across these paths.

Pinned `src/battle_script_commands.c` gives three different algorithms:

- **Cmd_typecalc**, lines1240-1342: actual damage/result flags. A zero row
  sets global DOESNT_AFFECT and clears global super/resist. Later super/resist
  updates are disabled by global NO_EFFECT. Wonder Guard therefore sets
  MISSED/AVOIDED_DMG for a type-immune attack, even if another type row is
  super effective. Its reason3 wins over DOESNT_AFFECT in resultmessage.
- **CheckWonderGuardAndLevitate**, lines1345-1417: scans the whole chart.
  Zero rows set global DOESNT_AFFECT/targetNotAffected but do not terminate
  the scan or clear the separate local super/resist indicators. Its WG
  condition is local resist-present **or** local super-absent, with the
  original-record-power/AttacksThisTurn/Struggle checks. A super-only local
  scan plus global immunity does **not** replace the ordinary miss reason.
  Resultmessage then selects immunity text, not ability text.
- **Cmd_typecalc2**, lines4346-4436: static record type; OR-only local
  super/resist flags, but a zero row sets global DOESNT_AFFECT and **breaks**
  the scan. Thus chart order matters. `!(flags & MOVE_RESULT_NO_EFFECT)`
  tests its local flags, which this scan only populates with super/resist;
  it does not test or suppress preexisting global MISSED/DOESNT_AFFECT.

Concrete source-derived oracles, with record power nonzero, an attacking
turn, defender Wonder Guard, no Foresight, and a failing ordinary accuracy
roll for the miss-helper column:

| Attack / defender types | Cmd_typecalc | Random-miss helper | Cmd_typecalc2 |
| --- | --- | --- | --- |
| Electric / Water+Ground | WG reason3 + immunity | Keeps ordinary reason; immunity text | Super found before zero; no WG reason; immunity text |
| Electric / Ground+Flying | WG reason3 + immunity | Keeps ordinary reason; immunity text | Zero breaks before Flying-super; WG reason3 + immunity |
| Electric / Ground+Ground | WG reason3 + immunity | WG reason3 + immunity | WG reason3 + immunity |
| Fire / Water+Grass | Neutral global flags, WG reason3 | Local super+resist, WG reason3 | Local super+resist, WG reason3 |

Source chart order is explicit at `src/battle_main.c:330-335`: Water-super,
Electric-resist, Grass-resist, Ground-zero, Flying-super, Dragon-resist.
Type order within the battler does not reorder the chart. All rows above
deal no target HP damage; the differing result text is the material issue.
`Cmd_resultmessage:1937-1940` and miss IDs2/3 at
`include/constants/battle_string_ids.h:417-418` resolve the reason precedence.

Smallest correction: replace the blanket miss-helper wording with the
literal separate-local-flags rule; explicitly document typecalc2's break on
zero and table-order consequence; add the counterexamples above to the
acceptance oracles. Do not repair this by changing the existing global
BattleFormulas.typeCalc or by adding Levitate/history behavior.

## Confirmed source claims

- Ordinary typecalc bypasses Struggle, uses GET_MOVE_TYPE, original record
  power, and AttacksThisTurn. The two-turn charging predicate and Solar Beam
  raw-sun exception are source-known (`:7846-7863`). Power0 does not activate
  WG. Opposing damage-effectiveness flags cancel in ordinary ModulateDmgByType;
  the scan-only helpers above differ. V4a Hidden Power/Weather Ball copies
  supply dynamic type before accuracy; source typecalc2 uses static type.
- Ordinary successful accuracy reaches crit/damage/typecalc/random even if
  WG then marks MISSED; target HP, critical presentation, secondary effects,
  recoil/drain damage consequences must respect the source result flags.
  Seteffectwithchance's blocked CERTAIN arm falls through to its random
  else-if (`:2774-2805`). Protect/semi-invulnerability return before the
  random-miss helper; explicit later typecalc/typecalc2 routes are exceptions.
- Rollout/Ice Ball always execute typecalc2 at RolloutHit, then cancel on
  NO_EFFECT before crit/damage random (`scripts:1592-1602`, C`:8161-8167`).
  Fury Cutter's landed blocked hit spends crit but skips damage random,
  re-enters furycuttercalc and resets; accuracy failure resets earlier
  (`scripts:1627-1639`, C`:8205-8226`). These two paths are not interchangeable.
- Present's first typecalc precedes its power/heal random. The heal branch
  clears only DOESNT_AFFECT; WG's MISSED prevents both HP-update commands,
  while the unconditional regained-health print still occurs. Full HP uses
  full-HP text. This oddity is confirmed, not UNKNOWN
  (`scripts:1660-1666,2028-2043`, C`:8238-8264,1713,1758`).
- Triple Kick increments its presentation counter before crit/typecalc;
  damage random precedes NO_EFFECT. The counter-positive exit clears MISSED
  before resultmessage. Therefore a first blocked neutral kick reports one
  hit with no ability text/HP loss; resisted typing also prints resisted
  text; type immunity retains DOESNT_AFFECT and suppresses count. The tail
  seteffectwithchance still executes (`scripts:1380-1435`). Current native
  post-damage hit counter cannot alone represent this result.
- Explosion self-faint and pre-accuracy crit/type/random order, plus
  protect/random-miss reason precedence, are correctly identified
  (`scripts:376-418`, C`:913-929,945-953,1092-1104`). Clarify the minor
  command attribution: **tryexplosion** checks Damp and drops the displayed
  HP bar; **setatkhptozero** writes battle HP0 (`:6255-6306`). The loop's
  movevaluescleanup clears prior result/miss flags before typecalc
  (`:3469-3484`), so typecalc establishes the new WG result before accuracy.
- Fixed/level/Super Fang/Psywave clear only super/resist after typecalc;
  Psywave still draws its value. Endeavor's HP failure precedes accuracy.
  OHKO checks NO_EFFECT before tryKO, so WG blocks before KO RNG/Sturdy/level.
  Their shared hit-animation tail still contains seteffectwithchance.
- Multi-hit fixed/random count selection occurs before per-hit crit/typecalc;
  blocked first typecalc skips damage random and hit count, but reaches the
  trailing secondary draw. All current native multi-hit entries use sourceTail;
  no older unused-tail implementation is needed for this package.
- Jump Kick's random miss can choose WG text without DOESNT_AFFECT and still
  crash. The crash's second typecalc is followed by clearing MISSED only,
  allowing recoil HP loss unless true type immunity remains. The source
  order and native special path in the proposal are correctly identified.
- Earthquake/Magnitude explicitly typecalc on their miss label and may replace
  prior miss/protect reason. Magnitude's strength draw comes before accuracy.

## Contract decisions still needed; exact candidate surface

The corrected design can support **one coherent modeled-singles leaf**:
an action-local source-result calculation with three explicit entry modes,
route-specific timing, and a narrow presentation arm. The cross-route work
is larger than one ordinary-hit conditional, but it requires no new persistent
battle state and the inspected source behavior is known. There is no source
reason to manufacture a new refusal for otherwise represented move families
or silently skip Present/Triple Kick. Splitting off individual represented
routes while claiming Wonder Guard gameplay support would need an explicit
partial-support/admission contract; that is not currently proposed.

Before Worker dispatch, the task must settle the following existing draft
choices rather than asking the Worker to improvise:

1. **RNG scope:** choose whether new WG-specific exits consume every cited
   source tail draw while preserving the known preexisting no-WG generic
   hit/Triple Kick omissions, or whether a separately approved RNG correction
   is included. The former is the smaller bounded option; label the resulting
   parity limits explicitly. A draft cannot simultaneously require every
   source draw and preserve every old expected count without identifying
   exactly which paths change. Compile literal per-route draw expectations,
   including Present2 on heal, blocked Rollout1 on ordinary roll/0 on protect,
   blocked Fury Cutter2 after a landed roll/1 on failed roll, and
   Triple Kick4 on a first neutral blocked hit if its source tail is included.
   Explosion has two pre-accuracy draws plus an ordinary accuracy draw,
   or just the two on protect; fixed/OHKO source tail draws are separate.
   These examples assume no held items or other unmodeled random producers.
2. **State acceptance:** include an already-locked Rampage control: WG-only
   MISSED must not be relabeled as true type immunity/targetNotAffected.
   The distinction affects existing lock cleanup, not merely text. No new
   history, trapping, recoil-ability, or persistent-state feature is authorized.
3. **Actually represented routes:** native inventory records Counter89,
   Mirror Coat144 and Bide26 as B, admitted only through the positive-power
   fallback. There is no record-counter implementation in the inspected
   engine. Keep them explicitly outside this leaf; do not implement counters
   or claim their source behavior is now represented. Typecalc2 is needed
   here for represented Rollout/Ice Ball, not as counter authority.

Candidate paths for a subsequent reviewed task: BattleEngine; optional
BattleFormulas opt-in pure helper with existing typeCalc/AI behavior unchanged;
BattleSceneController only the new ability-result text arm and any narrowly
specified existing event presentation needed without fake HP loss; a focused
synthetic no-ROM test plus explicit controller assertion; task source-lock/
evidence documentation. An unchanged-HP restoreHP event and existing multiHit
effectiveness/count presentation can express the confirmed Present/Triple
Kick oddities without inventing visible damage. Parent has permitted the
controller **proposal**, not its implementation.

No TrainerAI, main/bridge/factories, ability-history storage, Rock Head,
Liquid Ooze, Levitate, generic battle architecture, save, workflow, runner,
ROM fixture execution, inventory/phase advancement, or publication authority
is created. History recording remains an explicit excluded dependency; this
leaf cannot certify Brock AI parity or full runtime/replay equivalence.

**Next allowance:** author corrects R1 in the design and pins the contract
choices above; parent can then compile/review the bounded implementation
task. This Reviewer did not apply the correction or change shared coordination.
