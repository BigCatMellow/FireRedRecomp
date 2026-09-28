# P4-02 independent final inventory review

- Disposition: **PASS** — exact read-only move/effect inventory and its guarded
  verification, not new battle behavior or Phase 4 completion.
- Published implementation: `c10bfa787aef406cdd2ff71659b0a04c92112790`.
- Parent/request head: `1782246ba72ca349ab14352e74aef50681c19716`.
- Contract: [P4-02](../tasks/phase4-move-effect-inventory.md).
- Guarded receipt: [run 36336096049](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/36336096049),
  [job 108667108049](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/36336096049/job/108667108049).
- Reference source: `pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788`,
  independently confirmed in the local public-source checkout.

## Exact artifact and authority

Independent live recovery found public main at the exact implementation above.
Review authority is the current Orchestrator assignment for that revision and
the existing task acceptance criteria. Persisted task/coordination fields still
await final reconciliation; this review does not change them.

The parent-to-implementation diff adds exactly two authorized text paths:

1. `tests/phase4_move_effect_inventory_test.lua` — 354 lines.
2. `work/reports/phase4-move-effect-inventory.md` — 415 lines.

There are no runtime, importer, engine/controller, AI, admission-policy, save,
workflow, task or coordination changes in this implementation. No ROM bytes,
binary fixture, full move-record dump, game strings/art/media or generated cache
entered the diff. Numeric membership, aggregate counts, source symbols and
classification are within the contract's explicit metadata allowance.

The two files are byte-for-byte identical to the preflight-reviewed preparation
`688433a`, but that identity was not used as a substitute for final review:
the published test/report, current engine predicate, pinned source and guarded
logs were independently examined. `BattleEngine.lua`, `BattleMove.lua`,
`RomImporter.lua` and `RomAddresses.lua` are unchanged from accepted engine
baseline `a739ddc` to the published implementation.

Request `phase4-move-effect-inventory-20260927-v1.patch` was introduced at the
exact request head above. Its SHA-256 is
`667e8dac6efc5e5800c575d0ecd19f8ae32a1ff50a7b51ca3374e8131c277775`.
Reverse applicability against an exact implementation snapshot and
`git diff --check 1782246 c10bfa7` both pass. The separate route configuration
and probe have their existing independent PASS receipts, including
[probe 97dcae0](2026-09-27-move-effect-inventory-probe-review.md); no new probe,
request, dispatch or retry was performed by Reviewer.

## Findings against the existing criteria

An independent in-memory join of pinned move/effect constants and move source
records against the published literal test verified all real move IDs 1–354
exactly once, sentinel 0 excluded, every effect ID 0–213, 198 used effects and
16 unused definitions. Every family membership and positive/zero power class
matched: 216 positive-power and 138 zero-power moves. A separate report join
matched all 214 rows' memberships/counts, admission and classification to the
test, and every script owner and line anchor to the pinned dispatch/definition.

The test does not construct expectations from the engine predicate or exported
engine support tables. It validates its literal partition before the optional
ROM branch, SHA-verifies through the existing importer, parses through
`BattleMove.parseTable`, calls actual `supportsMove` for each real record, and
checks membership, power class, per-family counts, aggregate counts, boolean
predicate results and expected admission. It fails rather than updating its
expectations. Diagnostics contain only aggregate counts/mismatch categories;
parsed records remain in memory. The source-only definition count is correctly
identified as `defined_source`, not represented as a ROM enum measurement.

Source metadata plus actual current predicate independently reproduce 248
admitted and 106 rejected moves. Admission and semantic coverage remain distinct:

| Classification | Used families | Moves | Admitted / rejected |
| --- | ---: | ---: | ---: |
| Represented with stated limits | 50 | 137 | 137 / 0 |
| Candidate for separate discovery | 20 | 25 | 10 / 15 |
| Blocked on additional state/path | 127 | 191 | 101 / 90 |
| Intentionally rejected | 1 | 1 | 0 / 1 |

The 111 admitted but uncovered positive-power records are enumerated across
61 effects; generic positive-power admission is not promoted to effect support.
Dream Eater's explicit rejection and Pain Split's literal admission exception
match executable code. Represented classes have explicit bounded engine
mechanisms and existing assertion owners; shared singles/state limitations
remain prominent. Surf's submerged exception, Struggle's special path, both
effect-198 members, unused Hit aliases, effect-specific interception and other
mixed-family distinctions are not silently flattened into full coverage.
Candidate/blocked rows identify absent prerequisites, not accepted behavior.

The shortlist uses real trainer/learnset evidence and distinguishes early need
from prerequisite readiness. Direct inspection of Misty's two party entries,
`BattleScript_EffectRestoreHp` and `Cmd_tryhealhalfhealth` confirms the selected
effect-32 discovery rationale: represented HP/maxHP, half-max integer healing
with minimum one, full-HP failure and the cancellation/announcement/PP sequence.
Exactly one next discovery is proposed, IDs 105/303; no effect implementation,
generic healing, adjacent recovery family or complete-trainer claim is authorized.

## Independently recovered guarded evidence

The successful push run was created `2026-09-27T17:12:54Z`; the job ran on
`firered-mint` from `17:12:56Z` to `17:13:20Z`. Run/job metadata and direct job
logs were independently read, not inferred from a green summary or Worker claim.

| Required gate | Direct evidence |
| --- | --- |
| Trusted checkout | Fetch and `git log -1 --format=%H` identify exact request head `1782246ba72ca349ab14352e74aef50681c19716` at `17:12:58.7437768Z`. |
| Explicit selector/toolchain | Actual selector output is `phase4-move-effect-inventory` at `17:12:58.8231445Z`; Lua identifies version 5.1.5. |
| Private supported ROM | Existing fail-closed `sha1sum` comparison passed against `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`; confirmation at `17:12:58.9532323Z`. |
| Bounded target validation/application | Both patch steps succeeded; the resulting canonical diff has only the two allowed paths above. |
| Focused inventory | At `17:12:59.0757335Z`, partition validation completed and ROM work explicitly skipped. This is permitted by the task and is not ROM proof. |
| Full no-ROM suite | **151 test files PASS** at `17:13:02.4841818Z`; inventory ROM work skipped as expected. |
| Full verified-ROM suite | Explicit workflow environment injects the verified path. Inventory executes without skipping at `17:13:08.9933125Z`, followed by its final PASS; **151 test files PASS** at `17:13:17.1644429Z`. |
| No-replay branch | Actual output at `17:13:17.1840714Z` says no runtime replay applies to this read-only inventory. A successful step with that name is not gameplay replay evidence. |
| Guarded publication | Commit output identifies `c10bfa7`, two files/769 additions, at `17:13:17.2430762Z`; push confirms `1782246..c10bfa7 HEAD -> main`. |

The non-skipped verified-ROM aggregate is:

```text
moves=354 positive=216 zero=138 defined_source=214 used=198 unused=16
admitted=248 rejected=106 admitted_uncovered_positive=111
```

These observations independently confirm the source-derived expectations; no
discrepancy was hidden or coerced. ROM data confirms record membership/power and
actual admission, not semantic behavior. The run artifact API returns zero
artifacts. Reviewer did not access/copy a local ROM or retain its private path.

The transported report deliberately remains the exact prepared artifact: its
149-file baseline, 150-file preparation suite and pending-ROM language describe
that preparation stage. They are not the final run's counts. This final review
supplies the subsequent 151-file/non-skipped private evidence; Orchestrator may
reconcile current status without treating earlier preparation as ROM proof.

## Independent local verification

Checks ran from an immutable `git archive` of exact `c10bfa7` at
`/tmp/firered-inventory-review.llUlL4`, using the local Lua 5.1 toolchain with
`POKEPORT_ROM` unset. No implementation file was edited.

- Lua `loadfile` syntax check: PASS.
- Focused exact inventory: partition validates, then clean explicit ROM skip.
- Full `env -u POKEPORT_ROM bash scripts/test_all.sh`: **151 test files PASS**.
- Source/test/report join and all 214 dispatch-owner/anchor comparisons: PASS.
- An in-memory source-metadata harness executes the exact published test:
  its positive case invokes actual engine admission 354 times. Nine controlled
  cases fail without the final PASS: wrong effect, wrong power, missing record,
  undefined effect, admission drift, predicate exception, non-boolean predicate,
  rejected SHA and wrong importer count. This harness deliberately mocks
  importer/SHA/file I/O; it proves test rejection behavior, not ROM verification.
- Exact diff whitespace, two-path scope and reverse-request checks: PASS.

## Exact next allowance

No blocking correction was found. Orchestrator may accept/reconcile only
`P4-02` at the exact implementation and receipt above, then compile the single
proposed effect-32 source-lock discovery contract. This is not authority to
implement healing, expand state/AI/UI, infer full move parity, or close Phase 4.
Phase 2's trusted-reference requirement remains unchanged.

Reviewer wrote only this review. No implementation, task, state, handoff,
register or other coordination edit, commit or push was performed.
