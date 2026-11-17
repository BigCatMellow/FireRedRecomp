# Variable-power V2 closure-eligibility audit — independent review

Verdict: **NEEDS_FIX** for exact revision `f94f3f0` (PR #78), based on main
`df53c77`. The NOT ELIGIBLE conclusion and every gate verdict are correct.
The fixes are needed in how option (a) is presented to the decision-maker.

## Gate verdicts: all independently confirmed

**Preconditions (rows 0a and 0b).** SATISFIED is correct.

- Design proposal line 62 labels V2 "full relay, engine only". Line 55 shows
  that V1 Present is the fast-lane slice.
- The implementation review (lines 3 and 12) reviewed `0663e1d` as PASS WITH
  CORRECTIONS. Its lines 65-68 confirm that the ROM fixture could not run.

**Full-relay trigger.** AGENTS.md lines 116-117 require the full relay for
"cross-turn battle state", and the audit cites them correctly.

**Gates 1-5: MISSING.**

- No V2 route-plan, configuration, probe, authority or request artifact
  exists. The tree contains no V2 workflow arm or `variable-power-v2`
  bridge file.
- `git log --all -i --grep='fury cutter'` returns exactly `02c3cab`,
  `77405ec`, `0663e1d`, `d1ad194` and `7016f4d`, as the audit says.
- `gh pr view 55`: MERGED `77405ec` on 2026-10-21 by `BigCatMellow`, with
  0 GitHub reviews.

**Gates 6a-6c: MISSING.**

- **6a.** The substitute evidence is quoted correctly. It is the verified-ROM
  V2 line I verified from the live log in `4819085`. `0663e1d` is an
  ancestor of `65fceaa`.
- **6b.** `4819085` verifies only the receipt, and `922ee70` does not quote
  V2. MISSING is correct.
- **6c.** None of the coordination files mention V2 or Fury Cutter.

**Runtime replay: NOT-APPLICABLE.** Correct. It matches the design and V3
review `3056bc5` finding 3.

## Status line: does not overstate

The status line says `IMPLEMENTED … receipt recorded … full-relay closure
NOT ELIGIBLE — gates 1-5, 6a-6c missing`. This is accurate. It removes the
unsupported `DONE`, as V3's `fbe5b6f` did.

## Findings

1. **NEEDS_FIX — option (a) does not say it is unprecedented, or what it
   waives (report lines 59-69).** No in-repo precedent exists for ratifying a
   merge in place of relay gates. `grep -ri ratif` finds nothing outside this
   audit.

   The nearest analogue is the AGENTS.md fast-lane rule 4. It takes ROM
   evidence "from the next guarded bridge run's full verified-ROM suite". But
   AGENTS.md lines 116-117 exclude V2 from the fast lane. So option (a) is, in
   effect, retroactive fast-lane treatment of a full-relay family.

   **Fix:** add a "What (a) waives" paragraph under (a). It must state that
   (a) is unprecedented, and that it waives:
   - the independent pre-merge implementation authority (PR #55 had 0
     GitHub reviews; only the in-repo bounded review existed);
   - a V2-specific reviewed allowlist, target validation and focused arm;
   - bridge-published provenance (the code reached main by direct merge,
     not by SHA-gated bridge publication);
   - a V2-selected readiness probe.

   It should also add: "this is an exception to AGENTS.md:116-117 that only
   the operator can grant."
2. **Fix, for accuracy in V2's favor (report line 49, row 6a).** The audit
   says "a V2 focused arm ... never ran". That is true of the arm, but the V2
   tests did run.
   - `tests/battle_variable_power_v2_test.lua` (added in `0663e1d`) is one of
     the 207 files that both shared suites of run `43782148986` ran under
     `set -euo pipefail`. Both suites ended `PASS: 207 test files`, so it
     passed in no-ROM and ROM mode.
   - **Fix:** add that sentence as further substitute evidence. It still
     closes no gate.
3. **Minor fix (task status line).** The `[closure-eligibility audit](…)`
   link sits inside the backtick code span, so it renders as literal text.
   **Fix:** close the code span before the link.

## Coordination proposal (uncommitted scratch file)

The proposal file is
`/tmp/claude-1000/-home-home/ef96493a-7728-4d7a-9ad9-24921ed690d4/scratchpad/v2-coordination-proposal.md`.
I checked it against current `origin/main` `df53c77`:

- **STATE.json:** line 82 is `"legal_content_boundary"`, directly after the
  closing `},` of `v3_relay`. After inserting the `v2_relay` block there, the
  JSON parses (`jq -e`). `jq -S 'del(.v2_relay)'` equals main.
- **TASK_REGISTER.md:** line 95 is the V3 authority row.
- **HANDOFF.md:** line 38 is `## Current relay — 2026-10-28`, directly after
  the V3 section.
- **Content:** every insertion is additive, and P5-06 is untouched. Nothing
  is closed or self-adopted. `coordination_authority` names rina as the
  adopter.

Before adoption, apply finding 1 to the proposal's option (a) text (STATE
`next_after_success`, TASK_REGISTER row, HANDOFF bullet): call it "exception
to AGENTS.md:116-117; operator only".

## Checks

`check_repository.lua` and `git diff --check` pass.

Only this review file was authored. Nothing was merged, and no coordination
file was edited.
