# Effect-45 entry state and HP gates — independent source review

Verdict: **PASS** for the bounded source supplement at exact revision
`ba692697221e50aa054d0f981684771bf51ccaed`, parent
`73cf530`. This resolves the named source questions and accepts the explicit
ordinary-immunity correction. It is not acceptance of the stopped design or
authority for implementation, routes, probes, requests, or Phase 4 completion.

- [Task](../tasks/phase4-recoil-if-miss-entry-state-discovery.md) SHA-256:
  `99a045f0c8a4079dbf822b9e2a778519c77fa42c462c984333a6abb3aa92d587`.
- [Report](../reports/phase4-recoil-if-miss-entry-state-discovery.md) SHA-256:
  `92b990bf18b91729a468eab599fdced128238a6712c76a5f29ea730db56e4484`.
- Independently recovered public `main` and `READY_FOR_REVIEWER` checkpoint:
  `7586ac31d60e151bfb7c0247e2b2572e0d086a8f`.
- Verified source: `pret/pokefirered`
  `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

## Independent source reconstruction

Before receiving the final pair, I independently traced the task's source
questions from the clean pinned checkout. I then compared the exact published
pair against that reconstruction and rechecked the material owners. The five
reported source blob identities match both the pinned tree and actual file
hashes. The source and stopped-design artifact identities match the prior
accepted records; the original source artifacts remain unchanged.

1. **Reset values are explicit ordinary-action assignments.**
   `HandleAction_UseMove` sets `gCritMultiplier` and
   `gBattleScripting.dmgMultiplier` to 1, result flags to zero, and miss type
   to zero before ordinary move/effect dispatch (`battle_main.c:3963–3980`).
   The miss script has no intervening critical calculation or multiplier
   assignment. Prior-action critical state therefore cannot carry into this
   ordinary miss calculation. First-action setup and action completion clear
   dynamic power/type overrides; effect 45 does not set them. The report's
   noncritical stage and Reflect interpretation follows the actual
   `CalculateBaseDamage` branches, not an assumption based on no critical draw.

2. **Ordinary type immunity supplies the earlier guard.**
   After the random accuracy failure, `Cmd_accuracycheck` sets MISSED and
   calls `CheckWonderGuardAndLevitate` before `JumpIfMoveFailed`
   (`battle_script_commands.c:1092–1105`). Despite its name, that helper
   scans ordinary type immunity and sets DOESNT_AFFECT_FOE for zero type
   multipliers (`1345–1387`), including the Fighting/Ghost row. This is an
   in-scope producer, not only an excluded ability/interception path.
   Ordinary entering flags are therefore `0x01` or `0x09`. The report
   explicitly corrects the prior incomplete producer description while
   preserving the earlier accepted script ordering and arithmetic.

3. **The immune result is presented before the guard exits.**
   `Cmd_resultmessage` selects the ordinary miss message for `0x01`, but
   no-effect for `0x09` with ordinary miss type (`1930–1964`). The script's
   DOESNT_AFFECT_FOE guard then exits before crash announcement, damage
   calculation/adjustment, HP commands, and attacker faint command
   (`battle_scripts_1.s:848–871`). The supplement correctly rejects the
   previous universal miss-then-crash outline for ordinary immune targets.
   One PP deduction remains; this path consumes the accuracy draw only.

4. **Nonimmune crash ordering, formula, and HP ownership are literal.**
   Base calculation with reset 1/1 multipliers precedes STAB/type, then the
   adjustment draw and integer half/zero-to-one/target-max-HP cap. There is
   no second minimum after the cap and no critical draw. While MISSED remains
   set, type damage multipliers still apply but super/not-very-effective
   result-bit updates are suppressed by NO_EFFECT. The script clears MISSED
   before attacker HP processing, then restores it after faint handling.
   Target HP is not mutated by this leaf. The reported zero-after-cap case
   is explicitly arithmetic/command semantics, not a legal retail-battler
   or executed fixture claim.

5. **Downstream flags do not become an invented ordinary path.**
   NO_EFFECT is the mask `MISSED | DOESNT_AFFECT_FOE | FAILED` (`battle.h:203`).
   Both health-bar and data HP commands test that mask independently
   (`battle_script_commands.c:1713`, `1758`); IGNORE_SUBSTITUTE does not
   bypass it. A retained immunity bit would suppress both HP updates even
   after MISSED is cleared. The data command's no-effect arm records its
   special marker without subtracting HP. The ordinary attacker faint mode
   checks presence and actual zero HP, without a move-result-flag gate
   (`2851–2872`). A living attacker with suppressed HP updates therefore
   does not faint. The report correctly labels newly introduced late-only
   immunity conditional: the earlier helper already scans the same ordinary
   move/target types, and the intervening commands do not change them.

6. **Evidence remains bounded.**
   The branch-local draw counts distinguish ordinary nonimmune failure
   (accuracy then adjustment) from ordinary immune failure (accuracy only).
   Adjustment draws even for zero input if reached, but conditional late-only
   immunity is not made into an ordinary test oracle. Whole-turn RNG,
   animation/timing, cancellation, abilities/items/status, Protect/Substitute,
   called/mirrored or forced/multi-turn provenance, doubles/links, unsupported
   party state and other effects retain their exclusions. The report adds no
   generic flag API, executable fixture, runtime evidence, or design authority.

## Exact scope and checks

The reviewed commit changes only its permitted report and the task evidence/
handoff section. Original criteria and stop conditions are unchanged; the
accepted lock, stopped design, runtime, tests, workflows, routes, requests,
ROM policy and canonical phase state are untouched. The intervening mod-design
documents do not alter the four inspected engine/formula/controller/party
seams, which remain unchanged from `c218da6` through the reviewed revision.

Independent `git diff --check ba69269^ ba69269` passed. Repository checker
at checkpoint `7586ac3` passed: **280 tracked Lua, 268 tracked Markdown,
831 local targets**. Exact task/report hashes match the dispatch. Those
checks are documentation/source-review evidence, not gameplay or ROM proof.
No runtime, ROM, private runner, replay, route, or request action was performed.

## Exact next allowance

After reconciliation, the Orchestrator may add this accepted supplement to
the stopped design's source authority and reactivate only the bounded
`P4-F2-RECOIL-IF-MISS-DESIGN` task. The resumed design must incorporate the
explicit neutral reset values, ordinary immunity precheck and no-effect
presentation/early exit, distinct nonimmune crash ordering, and the distinction
between reachable outcomes and conditional downstream HP semantics. Its
event/acceptance outline must no longer treat the earlier guard as necessarily
clear or an immune ordinary failure as a generic miss followed by crash.

That revised design requires its own exact independent review. This PASS
supplies only additional source evidence; it does not close the design,
authorize implementation or routes, or advance Phase 4. No unresolved source
question remains within this supplement's stated ordinary boundary; excluded
systems and all behavior/integration evidence remain outside this acceptance.

Only this review file was authored. The parent owns coordination/publication;
no corrections, staging, commit, or push were performed by the Reviewer.
