# P4-F1-RECOIL-IF-MISS-DISCOVERY — independent review

Verdict: **PASS** for the exact task/report pair at inspection base
`dad1274d6fbab88ca99a56169fde22142ec19bf6`. The pair is a bounded,
read-only source lock for effect 45 and does not authorize a design,
implementation, route, runner/ROM action, or status change.

## Exact artifacts and review boundary

Reviewed from `/tmp/firered-outcome-reconcile`:

- Task `work/tasks/phase4-recoil-if-miss-source-discovery.md`, SHA-256
  `eef1410841e6cecdc0ca16a8b239b16cae2b15a8119999b8623a352ec412b59a`.
- Report `work/reports/phase4-recoil-if-miss-source-discovery.md`, SHA-256
  `53cb79e29f2694c3688fa557a091553858a483312be8a5d021161ddf20d7d125`.
- Inspection base `dad1274d6fbab88ca99a56169fde22142ec19bf6` exists exactly.

The task/report were untracked at review time. The worktree also contains
unrelated modified coordination files and separate rerank artifacts; these
were outside this exact review boundary and were not changed. `git diff
--check` produced no diagnostics for the existing worktree changes. The
review is based on read-only inspection; no ROM, private runner state, media,
or runtime experiment was used.

## Source-lock verification

The pinned `pret/pokefirered` revision `c75f352304d529f6ba92d4f74b9cf8b5c3810788`
supports the report's core claims:

1. The effect table maps effect 45 to `BattleScript_EffectRecoilIfMiss`.
   The pinned move table gives exactly the two effect-45 records: Jump Kick
   #26 (70 power, Fighting, 95 accuracy, 25 PP, selected target, priority 0,
   secondary chance 0, contact/Protect/Mirror Move/King's Rock flags) and Hi
   Jump Kick #136 (85 power, Fighting, 90 accuracy, 20 PP, selected target,
   priority 0, secondary chance 0, the same flags). The report correctly
   distinguishes ordinary effect 48 recoil and effect 198 Double-Edge.
2. The pinned script orders `attackcanceler`, accuracy check, and the normal
   hit continuation. Its miss branch runs attack announcement and PP reduce,
   waits/results, checks the pre-existing `MOVE_RESULT_DOESNT_AFFECT_FOE`
   bit, prints `STRINGID_PKMNCRASHED` only when that bit is absent, then runs
   `damagecalc`, `typecalc`, `adjustnormaldamage`,
   `manipulatedamage DMG_RECOIL_FROM_MISS`, attacker HP-bar/data updates,
   attacker `tryfaintmon`, restores the missed bit, and reaches common
   `BattleScript_MoveEnd`. The report's successful-hit sequence and its
   target-vs-attacker ordering match the source.
3. The pinned `Cmd_manipulatedamage` implementation halves the computed
   damage with integer division, promotes zero to one, and caps it at
   `target.maxHP / 2`. The report correctly preserves the target-max-HP cap,
   attacker application, and the zero-after-cap edge; it does not substitute
   ordinary 25%/33% recoil or an attacker-max-HP cap.
4. The report correctly records that the crash branch has no `critcalc`, that
   ordinary accuracy precedes the branch, and that `adjustnormaldamage` owns
   its post-damage random and item/endure/focus-band state. It does not make a
   whole-turn RNG claim or imply that those broader systems are represented.

## Current-project comparison

The report's comparison is supported by the inspection base. `BattleEngine`
admits positive-power moves through the broad fallback and explicitly records
effect 45 as not ported. Its ordinary `resolveMove` path performs accuracy,
PP reduction, and emits a generic `miss` event before returning. The ordinary
successful path has the existing crit/base/type/random damage and defender HP
seams; its no-effect route is after type calculation and is distinct from the
source miss branch's pre-existing no-effect-bit gate. Existing recoil is
derived from actual defender damage and targets the attacker, so it is not a
substitute for the effect-45 crash formula. The controller has generic miss,
damage, recoil, no-effect, and faint mappings but no crash-specific message
or ordered effect-45 event. The report accurately identifies these as gaps,
not as current support.

## Scope and future boundary

The task and report stay within source discovery: no runtime/controller/test
edit, admission change, formula/API draft, workflow/route/bridge change,
runner/ROM action, or implementation authority is created. The report
preserves exclusions for ordinary recoil, generic miss handling, abilities,
items, Protect/Substitute/Endure, semi-invulnerability, status, cancellation,
called/mirrored provenance, doubles/links, malformed battlers, animation and
timing parity, and unsupported target/party state. The proposed future
effect-45 boundary is explicitly labeled a design boundary only and does not
authorize implementation. The only valid successor is a separately scoped,
independently reviewed design discussion.

No blocking discrepancy was found. **PASS**.
