# Variable-power V2 equivalent-evidence outcome — independent gate 6b review

Verdict: **PASS — bounded equivalent-evidence adoption only.** Full-relay gates
1–5 and the V2-route-specific parts of 6a are waived by the operator; **entire
gates 1–6a remain MISSING, not satisfied**. Gate 6c remains PENDING and belongs
to ORCHESTRATOR rina. This report does not close the full relay or advance a
phase, capability checklist, publication or merge gate.

- Actual reviewer actor: fresh Codex agent `/root/v2_equivalent_outcome_review`
  in this review session, dispatched as the new independent Sol high Reviewer.
  This actor authored none of V2, either contract, the audit, or receipts
  `02c3cab` / `4819085`. Actor identity, rather than the shared GitHub account,
  establishes this review's independence. The requested model label is a
  dispatch label, not independent model telemetry.
- Frozen input: `001bad93d0c585d264dfe784c9c2b055ada71e8b`, tree
  `51c537725107601c0dd9a69ba2603775fd675e77`, branch
  `work/v2-equivalent-evidence-outcome-20261117`, isolated worktree
  `/home/home/FireRedRecomp-v2-outcome`.
- Current public main independently recovered as
  `df53c7770c1df5884f4c3924e331c5efebe91925`, tree
  `ab5969e91ceade68b729454e4766ca3a788cc0bd`.
- Reviewed against the frozen [active task](../tasks/phase4-variable-power-v2-equivalent-evidence.md),
  current organizer AGENTS/REVIEWER, coordination README, current authoritative
  STATE/HANDOFF/register, and capability checklist. Historical absent-ratification
  notes are superseded by the current explicit dispatch. Read-only handoff check
  at organizer revision `893f0213c4ff04804325391879d3ed482e247c36` with this task,
  frozen input and task evidence returned `PASS: existing task/state handoff
  agrees; no state written` (root record; no `--record`).

## Authority and ledger alignment

The actual operator ratification is dated **2026-11-16T23:20:47.288Z**, zole
user exchange 38, independently recovered by the parent from the actual user
field. The parent also verified the operator retained it after explanation:
user exchange 42, **2026-11-17T10:58:54.195Z**, “might as well keep it”. Those
human transcript observations are attributed to the parent, not claimed as a
fresh transcript read by this reviewer. I independently read the durable public
[PR78 comment 6932377350](https://github.com/BigCatMellow/FireRedRecomp/pull/78#issuecomment-6932377350),
created 2026-11-16T23:21:07Z, which quotes the same sentence:

> I, the operator, ratify the PR #55 merge of V2 Fury Cutter (0663e1d) as an exception to AGENTS.md:116-117, waiving full-relay gates 1-5 (V2 route plan, route configuration including the V2 allowlist, target validation and focused-test arm, V2 probe, pre-merge implementation authority, and the bridge request and bridge-published provenance) and the V2-route-specific parts of gate 6a; I accept the no-ROM and verified-ROM suite steps of run 43782148986 (job 133021540905) as gate-6a substitute evidence. Gates 1-6a stay MISSING, not satisfied. Gates 6b (independent V2 outcome review) and 6c (coordination) remain required.

I verified these external artifact SHA-256 values:

- `/home/home/FireRedRecomp_v2-equivalent-evidence-contract.md`:
  `2509e1a5de4bdf0c62a3c4a8236b970aae3f700557619c9f9359332a2a94a6ee`.
- `/home/home/FireRedRecomp_v2-contract-final-review.md`:
  `3ce71d5bc596986e889ab49976ec8683b985d87a0b72a0aaf6c81949eff3a885`.

The peer final review's N1–N3 delta is PASS; its initial NEEDS_FIX is historical.
The corrected peer sentence differs only in backtick formatting. Its ledger,
the actual operator quote and active task agree on process waivers, both shared
suites as substitute evidence, all of 6a remaining MISSING, required independent
6b and parent 6c. No contradiction or inferred approval from “continue” was used.

## Tested-source provenance and covering reviews

`git merge-base --is-ancestor 0663e1d6e5e9a3da507a81c8c98cafed7c9409d6
65fceaaef74ccc3321972b77ce734caa324dd33d` exited 0. The run's `65fceaa` head
is the **pre-apply checkout**. The actual patched, tested and published revision
is `b8cede0db0a8070c8fd86516bdb73c806081a7a4`, whose parent is `65fceaa`.
The accepted [V3 outcome review](2026-11-15-variable-power-v3-guarded-outcome-review.md)
`922ee70b8431a6f2730c56105e6bab554e9e7d35` independently accepted that tree.

I independently verified the pinned request SHA-256:
`9643c37ae974216956d09122e5d7b70d23a097bbe96691325e8a68f1456d94eb`.
A read-only Python unified-diff helper reconstructed its eight postimages in
memory from `65fceaa`: every result equals the corresponding `b8cede0` blob,
and the path set equals the complete published diff. No source/index/worktree
was mutated. All eight published blobs also equal accepted source candidate
`fbe5b6fff6e6b317cebef373c4e6a4cc8b3699bf`.

The V2 unit and ROM-fixture files are byte-identical from `0663e1d` through the
review input. The only later commits touching the engine or these two files are:

- `1ff5ff38b1115b0488a44124ca38e0298cd4553f`: engine comment only; applies F4
  from the [V1/V2 implementation review](2026-10-21-variable-power-v1-v2-implementation-review.md),
  clarifying that end-turn sleep cancellation requires a lock.
- `b8cede0`: later V3 engine changes, already source-reviewed at
  `bb2a1e83ab63d8ea687e0cb953f2f29a61521069` by the
  [V3 implementation review](2026-10-28-variable-power-v3-implementation-review.md).
  Engine bytes equal that reviewed engine. The
  [final-head correction review](2026-10-30-variable-power-v3-final-head-review.md)
  accepts correction-only head `9d761f49488156619c3cf87a49bb1958437083c8`;
  `fbe5b6f` preserves that engine and reconciles the evidence boundary. Outcome
  `922ee70` covers the published postimages. No uncovered engine drift exists.

`git diff --exit-code b8cede0 df53c7770c1df5884f4c3924e331c5efebe91925 --
src tests scripts import main.lua` and the same comparison from current main
to frozen input both exited 0. The fresh checks therefore run current-main
product bytes, also identical to the tested published product. I directly
inspected the current counter/reset/power/no-effect paths, all 80 V2 assertions,
and fixture source/family checks; recovered the original source-locked design
and bounded implementation/correction reviews without repeating their source
or mutation campaigns. These are prerequisites, not retroactive relay authority.

## Accepted shared-suite receipts and fresh public metadata

No private log was fetched or reread. The following are exact receipt quotes,
with their independent verification attributed precisely:

- [Inventory receipt review](2026-11-15-variable-power-v2-inventory-receipt-review.md)
  `481908596f9841a4cd178798d2e603b40857c6e0`, finding 1, verified the
  **verified-ROM step** of run `43782148986`, job `133021540905`:
  `phase4_variable_power_v2_effect_rom_test: 2 passed, 0 failed; exact 1-member source family`.
  It identifies that step by `PASS: 207 test files (ROM mode: verified ROM supplied)`
  and explicitly records **no V2 SKIP** in that step. Its no-ROM-step V2 SKIP
  is expected and belongs to the separate preceding step. The fixture proves
  the supported-ROM record and exact family membership, not runtime behavior.
- [Audit delta review](2026-11-16-variable-power-v2-closure-eligibility-delta-review.md)
  `e02bffd9bb3f85669f99e5068b1a240456df37e7`, finding 2, independently verified
  `80 passed, 0 failed` in **both** suites. This is unlabeled output, identified
  by exact order: status_leftovers 102, V1 72, **V2 80**, V3 144, then
  `battle_weather_test: 220 passed, 0 failed`. I confirmed the unchanged V2
  bytes and suite glob order locally. Review `4819085` did not verify this
  unit-test claim; `e02bffd` did.
- Outcome `922ee70` independently quotes
  `PASS: 207 test files (ROM mode: verified ROM supplied)` and records zero
  SKIP and zero FAIL lines in that verified-ROM suite. This agrees with the
  V2-specific no-SKIP receipt above; no contradictory accepted record appeared.

Fresh public metadata from
[run 43782148986](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/43782148986)
confirms `push`, main head `65fceaa`, completed `success`, **attempt 1**.
The available jobs metadata tool confirms job `133021540905`, `local-worker`,
completed `success`; select-route, apply-patch, V3 artifact check, focused test,
no-ROM suite, verified-ROM suite and publish steps all succeeded. The generic
single-job fetch endpoint was unsupported; the read-only run-jobs tool supplied
the metadata instead (friction recorded). No logs/artifacts were requested.

The V3-only request pathname, route-selection/allowlist workflow arms and
accepted outcome receipt establish selector `phase4-variable-power-v3-effect`;
metadata itself only names the successful selection step. V2 is cited solely
as a **shared-suite** result. There was no V2-selected guarded run. A successful
runtime-replay step label is not a replay witness: the accepted receipt records
the authorized V3 arm ran no replay.

## Fresh current-main-product checks

At frozen input `001bad9`, with **both** variables unset, these completed
foreground checks exited 0:

```text
env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY lua5.1 tests/battle_variable_power_v2_test.lua
80 passed, 0 failed

env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh
PASS: 207 test files (no-ROM mode; ROM-dependent checks skip cleanly)

env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY lua5.1 scripts/check_repository.lua
PASS: repository checks (336 tracked Lua, 419 tracked Markdown, 1368 local targets)

git diff --check
exit 0
```

The current no-ROM suite's V2 fixture SKIP is expected; it is not the historical
verified-ROM receipt. Product evidence is unchanged by this review's docs-only
outputs; final staged-link/repository/whitespace checks are recorded in own task
progress before commit.

## Remaining limits and precise next allowance

Unrepresented `CancelMultiTurnMoves` callers remain Torment, Uproar, Yawn,
Truant, Disable, Taunt, Imprison, infatuation and Spite. Unrepresented other
item actions (bag/trainer items, Poké Doll/Fluffy Tail, Poké Flute) must reset
the counter when implemented. Baton Pass is unrepresented and must clear the
disable struct/counter. The ordinary-hit zero-chance `seteffectwithchance`
RNG gap remains: source spends its `% 100` draw, current plain-hit path omits
it. V2 changes power and KO timing without new normal hit draws, so repeated
Fury Cutter seeded outcomes diverge from the second hit; no whole-stream parity
follows. The synthetic no-effect branch spends accuracy/crit but no damage
random; Bug has no real-chart immunity and Wonder Guard is unrepresented.
UNKNOWN/unproven behavior stays UNKNOWN; no live LÖVE/runtime, whole-battle,
Brock AI, phase or capability claim follows.

A later failing V2 test or ROM fixture **reopens V2**. Future test oracles must
remain source-derived. No source/test/inventory/main-task-status/coordination
authority was changed, and no ROM access/search, replay, probe, request, new
job, publication or merge was performed.

Rina may receipt this exact clean local review commit/digest and perform the
contract's **gate 6c coordination only**, preserving the operator quote, all
MISSING gate states and bounded-equivalent wording. Review PASS grants no
normal main-merge authority; the separate real FireRed operator/opcmd gate
still applies. No actionable finding remains within gate 6b.
