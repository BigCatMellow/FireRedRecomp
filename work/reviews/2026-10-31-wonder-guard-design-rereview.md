# Wonder Guard design delta re-review — 2026-10-31

**NEEDS_FIX** — the prior material scan/presentation correction is resolved.
One newly added literal RNG oracle needs a narrow qualification before
contract compilation; no broader source/design blocker was identified.

Reviewed corrected `/tmp/firered-wonder-guard-design-20261031.md`, SHA256
`ba0330fe1579d2e1489cd9b4c54acd53b6352f0e028c6c64af6a743579d8fcc4`,
against the frozen original independent review and only the changed claims.
No repeated broad route review or test campaign, implementation, ROM,
runner, publication, merge, phase acceptance, or shared coordination edit.

## Resolved

- R1 now preserves ordinary typecalc's global flags, the full random-miss
  OR scan, and typecalc2's OR scan that stops at zero. The Electric
  Water/Ground versus Ground/Flying counterexamples and result reasons agree
  with the pinned source. The blanket immunity/ability-text error is removed.
- Explosion's displayed-bar versus battle-HP0 command attribution and the
  loop cleanup are corrected.
- Already-locked Rampage explicitly distinguishes WG-only MISSED from true
  type immunity/targetNotAffected; source-history machinery is still excluded.
- Counter/Mirror Coat/Bide are explicitly unrepresented B-row exclusions.
- Parent's RNG decision is recorded: source-correct tails on newly
  WG-blocked represented routes, preserving existing unblocked generic-hit
  and Triple Kick omissions; no global repair or general replay claim.

## Only remaining correction

The new literal RNG paragraph says Psywave consumes accuracy + one value
draw + tail =3 without stating its rejection-loop condition.

Pinned `src/battle_script_commands.c:7557-7565` uses
`while ((randDamage = Random() % 16) > 10);`.
Native V4a `BattleEngine.psywaveDamageFromLevel:704-707` already preserves
that loop. WG does not suppress its evaluation after typecalc.

Smallest correction: say **3 draws when the first value sample is accepted;
3+r draws when r rejected samples precede the accepted sample**, assuming
ordinary accuracy succeeds and the route reaches WG block and the newly
included source tail. Pin an explicit scripted example: successful accuracy,
Psywave samples11,15,10, then tail => **5 total draws**. Require this rejection
case as well as the immediate-accept control. Do not replace the existing
rejection helper with a single-draw approximation or change unblocked RNG.

No correction implemented by this Reviewer.

## Readiness and next allowance

After that one qualification, the corrected source design supports compiling
one coherent modeled-singles implementation task on the agreed candidate
engine/optional opt-in formulas/narrow controller/test/task surface. It does
not require a new refusal approximation or split solely because its known
source behavior spans several existing routes. Preserve original bounded
state-space and history/AI/counter exclusions and revalidate the implementation
base. Parent's controller permission remains permission for a proposal until
the actual task is authorized. This review itself grants no Worker dispatch,
implementation, ROM/runtime execution, or phase authority.
