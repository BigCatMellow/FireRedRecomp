# Effect-45 ordinary entry state and HP gates — source supplement

- Task: [P4-F1-RECOIL-IF-MISS-ENTRY-STATE](../tasks/phase4-recoil-if-miss-entry-state-discovery.md).
- Status: `RESEARCH COMPLETE — PENDING INDEPENDENT EXACT-REPORT REVIEW`.
- Project inspection base / freshly observed public `main`:
  `43cae5e1e54bc85a8bc3c10043454f5c6b5e197f`.
- Public source pin: `pret/pokefirered`
  `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Scope: ordinary selected Jump Kick #26 / Hi Jump Kick #136, effect 45,
  represented singles, valid living battlers and ordinary accuracy comparison.

The missing entry/reset and HP-gate facts are resolved by source inspection.
The ordinary crash calculation enters with critical and damage multipliers
both **1**. However, the earlier no-effect guard is **not always clear**:
the ordinary accuracy-miss command already checks type immunity before the
effect-45 miss script. An immune ordinary miss announces no effect and exits
before the crash announcement and damage-adjustment draw. Newly discovered
immunity inside the later crash calculation is not reachable in this bounded
ordinary path; its HP-command consequences below are conditional source
semantics, not an ordinary execution oracle.

This supplements the [accepted source lock](phase4-recoil-if-miss-source-discovery.md)
and resolves questions from the [design BLOCK review](../reviews/2026-10-11-recoil-if-miss-design-review.md).
It changes neither accepted artifact nor the stopped design. Independent
acceptance of this exact supplement is required before any design resumption.

## Verified source and evidence identity

Read-only connected GitHub recovery returned the project `main` above after
shell `git ls-remote` could not resolve the host. The existing public-source
checkout reports the exact pin, has empty `git status --short`, and its
inspected files match `git ls-tree HEAD` / `git hash-object`:

| Pinned file | Git blob |
| --- | --- |
| `src/battle_main.c` | `64c9e59b7efdd2acf399716da40d4848da91a428` |
| `src/battle_script_commands.c` | `67f90a37044db87091b2174f78fe1e31ad2ef10d` |
| `src/pokemon.c` | `66a5c3d233e8b1b85fe5045aeb6667332cd61d4c` |
| `data/battle_scripts_1.s` | `8aa0a1004033e40df8222107b60cc72fa85d9b8f` |
| `include/constants/battle.h` | `d46776ab9b2276e7591d3b964937d3ea69c574c1` |

An independent read-only GitHub fetch of `src/battle_script_commands.c`
lines 1345–1388 at that pin returned the same blob identity and immunity
precheck text. All source links below use the verified pin and current exact
line anchors. Several historical report anchors are displaced at this pin
(for example, effect-45 script entry is 848, not 810; `Cmd_damagecalc` is
1209, not 1158). Use the symbols and exact anchors in this supplement for
these findings; no historical report was silently edited.

Existing SHA-256 identities were reproduced before research:

| Existing artifact | SHA-256 |
| --- | --- |
| Accepted source task at `c218da6` | `eef1410841e6cecdc0ca16a8b239b16cae2b15a8119999b8623a352ec412b59a` |
| Accepted source report at `c218da6` | `53cb79e29f2694c3688fa557a091553858a483312be8a5d021161ddf20d7d125` |
| Accepted source review | `91ba7099006f2ecefa1b17e9bdee50985b66f1507fe39162ca36ada572bf9140` |
| Stopped design task at `f31ae69` | `ccd5a3d38243507d2a04bded621a7a012ccbea4d569fb854f97b0dd07fcfabf9` |
| Stopped design report at `f31ae69` | `6e27a294c916cc91b639c51f5d53ca4598bd91fec81f299e10350325f19bda1b` |
| Design BLOCK review | `8538b01f2632717f121f49de86995a72e52d9b7e4a531c461c0999cb89102003` |

## Ordinary action reset and calculation inputs

`RunTurnActionsFunctions` dispatches the current action through
[`sTurnActionsFuncsTable`](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_main.c#L562-L578)
at [3704–3709](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_main.c#L3704-L3709).
`B_ACTION_USE_MOVE` owns `HandleAction_UseMove`. After rejecting an absent
attacker, that function assigns `gCritMultiplier = 1`,
`gBattleScripting.dmgMultiplier = 1`, `gMoveResultFlags = 0`, and
`gBattleCommunication[MISS_TYPE] = 0`
([3963–3980](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_main.c#L3963-L3980)).
These are assignments on every ordinary move action, not inferred defaults
from static initialization or the absence of `critcalc`.

Ordinary selection takes the current move from the selected move slot
([4017–4020](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_main.c#L4017-L4020)),
uses the chosen target and dispatches the move's effect script
([4114–4132](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_main.c#L4114-L4132)).
The effect-45 script's ordinary miss edge has no multiplier assignment or
`critcalc` before `damagecalc`
([848–871](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L848-L871)).
The ordinary pass through attack cancellation, accuracy, attack announcement,
PP reduction and result presentation does not change those multipliers.

`Cmd_critcalc` can set the previous action's critical multiplier to 2
([1196–1206](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L1196-L1206));
the next `HandleAction_UseMove` overwrites it with 1 before effect dispatch.
The previous action's damage multiplier is likewise overwritten. Thus a
preceding critical cannot leak into this ordinary miss calculation, even
when actions belong to different battlers in the same turn.
`HandleAction_ActionFinished` additionally clears prior result flags,
damage, dynamic type and dynamic base power
([4453–4475](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_main.c#L4453-L4475));
first-action setup clears the two dynamic overrides too
([3687–3701](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_main.c#L3687-L3701)).
Effect 45 does not assign an override, so its ordinary base/type inputs are
the accepted literal move record.

`Cmd_damagecalc` passes attacker, target, target-side screen state, current
move and dynamic overrides into `CalculateBaseDamage`, then multiplies by
the two reset multipliers
([1209–1222](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L1209-L1222)).
The base routine selects record power/type when overrides are zero
([2398–2406](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/pokemon.c#L2398-L2406)).
For physical Fighting damage, multiplier 1 takes ordinary attack/defense
stage handling and allows defender Reflect; it does not use the critical
stage bypass or critical screen bypass
([2509–2549](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/pokemon.c#L2509-L2549)).
This establishes noncritical calculation for the scoped edge without a new
critical RNG draw. It does not establish additional item/ability/status rules.

## Result flags before the guard: ordinary immunity is already known

The actual constants are `MISSED = 0x01`, `DOESNT_AFFECT_FOE = 0x08`,
`FAILED = 0x20`, and `NO_EFFECT = 0x29`, the OR of those three flags
([battle.h:194–203](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/include/constants/battle.h#L194-L203)).
`NO_EFFECT` is a mask, not synonymous with type immunity.

The exact ordinary path is:

1. The action reset clears flags. `Cmd_attackcanceler` ordinarily advances
   to accuracy; its cancellation, obedience, interception and Protect paths
   remain excluded
   ([819–910](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L819-L910)).
2. `Cmd_accuracycheck` resolves `ACC_CURR_MOVE`, passes the excluded Protect
   and special accuracy helpers, and reaches the normal random comparison
   ([1035–1043](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L1035-L1043)).
   On failure, it sets `MISSED`, assigns ordinary `B_MSG_MISSED`, then calls
   **`CheckWonderGuardAndLevitate()` before `JumpIfMoveFailed(7, move)`**
   ([1092–1105](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L1092-L1105)).
3. Despite the helper's name, its ordinary type-table scan sets
   `DOESNT_AFFECT_FOE` for a zero multiplier against either target type
   ([1345–1387](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L1345-L1387)).
   This is not conditional on possessing Wonder Guard or Levitate. The
   Fighting/Ghost immunity row is
   [battle_main.c:422–425](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_main.c#L422-L425).
   Foresight and the helper's ability branches are excluded; ordinary type
   immunity remains relevant and cannot be excluded by the helper's name.
4. `JumpIfMoveFailed` sees `MISSED` within `NO_EFFECT`, selects the script's
   miss pointer, and bypasses its successful-accuracy absorbing-ability arm
   ([913–928](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L913-L928)).
   Flags entering the miss script are therefore `0x01` for a nonimmune
   target or `0x09` for an immune target in this ordinary context.
5. `attackstring` and `ppreduce` do not alter those result bits; the ordinary
   PP cost remains one, with no refund
   ([1108–1167](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L1108-L1167)).
   `Cmd_resultmessage` prints the ordinary miss result for `0x01`, but for
   `0x09` with ordinary miss type it selects `STRINGID_ITDOESNTAFFECT`
   ([1930–1964](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L1930-L1964)).
6. The script's line-858 guard tests only `DOESNT_AFFECT_FOE`. The nonimmune
   miss continues; the immune miss enters MoveEnd immediately, without a
   crash string, base/type/random calculation, attacker HP commands or
   attacker faint command.

The original report's description of the earlier bit as coming from
“cancellation/protection-like paths,” and the stopped design's suggestion
that only excluded producers supply it, are incomplete. This supplement
identifies an ordinary in-scope producer. The prior visible-sequence outline
also needs this qualification: an ordinary immune accuracy failure produces
the no-effect result, not a miss announcement followed by crash. These are
specific source corrections for independent assessment, not a revocation or
rewrite of the previously accepted artifacts.

## Later calculation and downstream HP/faint gates

For an ordinary nonimmune miss, the sequence remains crash announcement/wait,
base calculation, STAB/type calculation, random adjustment, literal crash
transform, clearing `MISSED`, setting `IGNORE_SUBSTITUTE`, attacker health
bar, attacker data HP, attacker faint check, restoring `MISSED`, MoveEnd
([script:859–871](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L859-L871)).
`Cmd_typecalc` and `ModulateDmgByType` apply STAB and type multipliers
([1240–1342](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L1240-L1342)).
While `MISSED` is still set, the super/not-very-effective result-bit updates
are gated by `NO_EFFECT`, although their damage multiplication still occurs.
With no immunity or excluded producers, flags remain `0x01` until cleared
to `0x00` immediately before HP commands; the script restores `0x01` afterward.

`ApplyRandomDmgMultiplier` draws before testing zero damage; it consumes one
draw whenever reached. `Cmd_adjustnormaldamage` calls it first
([1557–1616](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L1557-L1616)).
Excluded held-item/Endure behavior does not become part of the bounded draw
count. The crash transform is still integer half, zero-to-one, then cap at
integer half of **target maximum HP**, with no minimum after the cap
([Cmd_manipulatedamage:6458–6471](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L6458-L6471)).
Neither target current HP nor attacker maximum HP substitutes for that cap.

Both `Cmd_healthbarupdate` and `Cmd_datahpupdate` independently require
`!(gMoveResultFlags & MOVE_RESULT_NO_EFFECT)`
([1708–1741](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L1708-L1741),
[1744–1761](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L1744-L1761)).
Clearing `MISSED` allows ordinary nonimmune crash HP processing. The ignore-
Substitute marker does not bypass the outer no-effect tests. Data HP applies
damage to the script-selected attacker, clamps at the attacker's remaining
HP, records actual HP lost in `gHpDealt`, then emits the HP data update
([1786–1858](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L1786-L1858)).
The bar command precedes the data command; controller-execution guards keep
pending command output from being overwritten. Target HP is never updated
on this leaf.

The ordinary `tryfaintmon` macro selects mode FALSE
([macro:112–117](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/asm/macros/battle_script.inc#L112-L117)).
`Cmd_tryfaintmon` chooses the attacker and checks presence plus actual HP
equal to zero; **it has no move-result-flag gate**
([2851–2872](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L2851-L2872)).
A fatal crash enters `BattleScript_FaintAttacker` after HP processing; its
return resumes the missed-bit restoration and MoveEnd
([FaintAttacker:2801–2808](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/battle_scripts_1.s#L2801-L2808)).
Status-driven faint side effects and general MoveEnd parity remain excluded.

If typecalc were to introduce a *new* immunity after the earlier guard,
`ModulateDmgByType` would set `DOESNT_AFFECT_FOE` and zero damage; random
adjustment would still draw, and the crash transform would still perform
its minimum/cap arithmetic. Clearing `MISSED` would leave `0x08`, so both
HP commands would suppress their updates. The data command's no-effect arm
only sets the selected battler's special damage marker to `0xFFFF` if it was
zero ([1861–1867](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L1861-L1867));
it does not subtract HP or emit an HP update. A living attacker would not
faint, and the script would restore `MISSED`, yielding `0x09`. No later
resultmessage in this leaf would announce that newly computed immunity.
This conditional command trace does not assert reachability: the ordinary
accuracy precheck scans the same move type/target types before the guard,
and the intervening ordinary commands change neither. Reaching late-only
immunity would need another path or state outside this task's boundary.

| Case | Visible result and actual HP | Branch-local RNG |
| --- | --- | --- |
| Ordinary nonimmune accuracy failure | Used move; miss; crash; attacker HP bar/data; optional attacker faint; MoveEnd. Actual loss is the crash amount clamped to remaining attacker HP; target unchanged. | One accuracy draw, then one damage-adjustment draw; no critical draw. |
| Ordinary immune accuracy failure | Used move; no-effect result; MoveEnd. No crash announcement, HP commands or attacker faint command. Both HP values unchanged. | One accuracy draw; no damage-adjustment or critical draw. |
| Conditional late-only immunity, not ordinary reachable | Miss/crash already announced; HP bar/data suppressed by retained no-effect bit; living attacker does not faint. | Accuracy draw if the entry used ordinary comparison; damage-adjustment draw occurs even at zero damage. |
| Literal zero-after-cap arithmetic, not a legal-battler claim | If an otherwise eligible nonimmune leaf has target max HP 1, cap yields 0; bar/data commands remain eligible and transmit zero/unchanged HP, actual loss 0, living attacker does not faint. No second minimum is allowed. | Reached adjustment still draws. |

The last two rows separate arithmetic and command semantics from ordinary
reachability. No synthetic production flag, invented battler, executable
fixture or ROM observation was used. These counts omit turn ordering,
later actions and excluded systems; they are not whole-turn RNG parity.

## Current-project comparison and retained limits

At the inspection base, [resolveMove:1080–1109](../../src/core/BattleEngine.lua#L1080)
performs the firstBattle accuracy bypass or Boolean accuracy call, spends PP,
then emits a generic miss and returns. It lacks the ordinary miss-time type
precheck and effect-45 crash leaf. Its later
[hit calculation:1276–1314](../../src/core/BattleEngine.lua#L1276) rolls a local
critical and computes type flags only after that return. Source reset 1/1
now justifies noncritical input on a future bounded crash calculation;
the ordinary immunity precheck prevents claiming that the source's earlier
guard is always clear. There is still no project incoming result bitfield,
and this report proposes no flag API or design workaround.

[BattleFormulas.calculateBaseDamage](../../src/core/BattleFormulas.lua#L225)
already has noncritical stage/screen inputs;
[applyRandomDamageMultiplier](../../src/core/BattleFormulas.lua#L415) draws even
for zero. Those seams do not establish crash support.
[applyDamage](../../src/core/BattleEngine.lua#L1502) remains a defender-damage
owner, not evidence of source attacker HP gates. The stopped design's
controller outline must distinguish the reachable immune no-effect exit from
the nonimmune miss/crash sequence before it can be accepted. No controller,
faint, persistence or save integration was executed or claimed. The four
previously inspected engine/formula/controller/party-bridge files are
unchanged from `c218da6` to this inspection base.

Retained exclusions: every other effect family (including ordinary recoil
48/198), generic miss/admission repair, cancellation/inability/obedience,
Protect, Substitute, items, abilities, Endure/Focus Band, status including
Foresight and semi-invulnerability, called/mirrored moves and other move
provenance, multi-turn/forced selection, doubles/links/multi-battler behavior,
unsupported target/party state, malformed battlers, animation/timing parity,
and generic MoveEnd/whole-turn parity. FirstBattle's existing accuracy bypass
is preserved as a boundary; this ordinary comparison trace does not supply
a tutorial move-placement or tutorial crash claim.

No missing source fact remains UNKNOWN within the specified ordinary entry
and HP-gate questions. Behavior outside these exclusions is not established,
and runtime/controller/replay/save integration remains unverified. The
conditional late-only immunity trace must not become an ordinary test oracle.
The reviewer must independently assess the correction to the earlier guard
description as well as the reset and HP facts before design may resume.

## Checks and handoff

Baseline `lua5.1 scripts/check_repository.lua` passed: 280 tracked Lua,
255 tracked Markdown, 808 local targets. Baseline `git diff --check` passed.
Final documentation/whitespace receipts and exact report/task hashes are
recorded in the task evidence and Researcher handoff; no self-referential
artifact hash is embedded here. The pending untracked report must be included
explicitly in the documentation check before publication.

Full gameplay suite and ROM/runtime checks: N/A under this source-only task.
Only this report and the task evidence/handoff section were authored. No
code/test/design/acceptance/coordination/route/request/probe/runner change,
staging, commit or push was performed. The parent owns publication and a
separate Reviewer supplies the exact-artifact verdict. Research completion
alone grants no acceptance, implementation or Phase 4 advancement.
