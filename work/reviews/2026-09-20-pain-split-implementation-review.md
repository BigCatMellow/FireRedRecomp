# P4-PAIN-04 independent implementation review

- Disposition: `PASS` — bounded represented-state Pain Split effect only.
- Implementation base: `bf36d94ccb20b7457d224c7bd5f94d8b3cfeb89c`.
- Implementation revision: `a739ddc88cb44a33d5e6025e619cf1df3fe6a1a8`.
- Reviewed range: `bf36d94..a739ddc` (six files, 97 added lines).
- Local relay revision: `a430b6fe9741e98b94a01c27636b8a9d189f43b0`,
  with `STATE.json`, task, and register at `READY_FOR_REVIEWER`.
- Independent live GitHub query returned main at the implementation revision.
- Guarded evidence: [run 35493728001](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/35493728001),
  request head `bf36d94ccb20b7457d224c7bd5f94d8b3cfeb89c`.

## Acceptance findings

The implementation meets the existing task's five acceptance criteria within
the stated exclusions. Direct inspection found no correction required.

1. `supportsMove` adds only the literal effect-91 exception after the existing
   null/Dream Eater safeguards. Existing stat/screen admission is preserved;
   unsupported zero-power moves do not gain admission. The ROM record test
   verifies that #220 is the sole effect-91 record, with zero power and flags 18.
2. The existing cancellation/no-PP path and move announcement remain intact.
   Pain Split takes the constant-success represented accuracy path with no
   RNG or accuracy/evasion calculation. PP is decremented once before HP
   calculation or mutation. The no-state accuracy operation is collapsed to
   `hit = true`; its local boolean is assigned before PP, but it has no
   observable state or RNG effect. This preserves the represented source
   sequence without adding the excluded failure states.
3. The average is computed once from both original HP values. Each side then
   receives that frozen average clamped to its own maximum, attacker first.
   This is algebraically equivalent to the source's stored signed deltas;
   the second application cannot recompute from the modified attacker HP.
   Events report original-side identity, actual before/after HP, and actual
   signed change after clamping. The effect returns before ordinary damage,
   type, critical, random-damage, or faint handling. For living battlers the
   average remains positive; equal HP is successful sharing.
4. Committed tests cover lower/higher/odd/equal HP, both asymmetric-max cases,
   ordered actual deltas, PP, zero RNG, admission isolation, no faint,
   controller ordering, shared-pain words, and the exact ROM record. Existing
   ordinary-effect regressions remain in the full suite. Additional independent
   checks below cover both attacker roles and small-HP boundaries.
5. The required guarded route and evidence sequence passed. The configured
   replay exercises deterministic engine/controller behavior, as the active
   contract specifies.

The source comparison used the local public decompilation at
`c75f352304d529f6ba92d4f74b9cf8b5c3810788`: `BattleScript_EffectPainSplit`
in `data/battle_scripts_1.s:1235`, the no-RNG branch in
`src/battle_script_commands.c:1020`, `Cmd_painsplitdmgcalc` at line 7674,
and the own-max healing clamp in `Cmd_datahpupdate` at line 1744. The move
record is `src/data/battle_moves.h:2863`; the flags are defined in
`include/constants/pokemon.h:239` and `:242`.

## Independently checked evidence

The Reviewer read the live run metadata and logs, not only the Worker report.
The logs show the `phase4-pain-split-effect` selector, successful supported-ROM
SHA gate, bounded-target validation, patch application, focused checks,
both full suites, replay, and publication of `a739ddc`.

- Focused engine/controller: **237/0** and **39/0**. The focused ROM test
  explicitly skipped without `POKEPORT_ROM`; it is not counted as ROM proof.
- Full no-ROM suite: **149 test files PASS**.
- Full verified-ROM suite: **149 test files PASS**, including Pain Split
  record **1/0**, after SHA-1
  `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc` verification.
- Verified replay: engine **244/0**, controller **39/0**, record **1/0**,
  followed by the configured `RUNTIME_REPLAY phase4_pain_split PASS` marker.
- Independent local rerun: **149 no-ROM test files PASS**, using
  `/home/home/.local/share/firered-toolchain/bin` on PATH. The relay revision
  has no implementation/test changes beyond the exact reviewed revision.
- Independent, non-persisted Lua checks passed **12,168 living-HP cases**:
  all HP values within each max HP from 1 through 12, both attacker roles,
  Ghost types, extreme accuracy/evasion stages, and RNG that raises on use.
  They checked formula/clamps, event order/identity/deltas, PP, positive HP,
  and no outcome/replacement mutation. Separate checks passed foe-side
  controller display consumption, no-PP cancellation, and admission guards.
  The first ad-hoc controller invocation used a nonexistent helper name;
  correcting the review harness to `advanceMessage` yielded the complete
  passing run. No repository code was changed for these checks.
- Corrected request SHA-256 remains
  `c6170f42df62f45867bbf0c1330584a2c067136ff5811042fbc7d7009856cd69`.
  Reverse patch applicability and `git diff --check` passed.

## Scope, limits, and next allowance

All six changed paths are inside the existing literal nine-path allowlist.
The range contains only Lua source/tests and the shell replay; no ROM, BIOS,
cache, extracted asset, or capture media is included. No workflow, supported-ROM
policy, generic HP/healing API, other effect, or excluded state was changed.

ROM evidence was independently inspected from the user's private runner logs;
the Reviewer did not open a local ROM. The replay is deterministic and headless:
it does not prove visible LÖVE animation, retail timing, or visual parity.
Protect, Substitute, Mirror Move, Lock-On/sure-hit, semi-invulnerability,
items/abilities/status interactions, doubles/links, and generic zero-power or
healing support remain outside this acceptance.

Orchestrator may reconcile `P4-PAIN-03` and `P4-PAIN-04`, close only this Pain
Split leaf, and dispatch the separately bounded `P4-02` effect-family inventory
refresh and its reviewed runner prerequisite. Phase 4 remains `IN PROGRESS`;
Phase 2's trusted retail-reference blocker remains unchanged. This Reviewer
wrote only this review; coordination reconciliation belongs to Orchestrator.
