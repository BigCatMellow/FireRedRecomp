# Variable-power V2 closure-eligibility audit — delta review

Verdict: **PASS** for PR #78, delta `276d374..98bac30`, head `98bac30`.

- All three findings from `276d374` are resolved.
- The row-6a unit-test claim, which the author inferred, is now
  independently verified from the live log.
- The two uncommitted scratch proposals are reviewed separately below. Their
  verdict is **NEEDS_FIX before adoption**. That does not block this PR,
  because nothing in them is committed or adopted.

## Prior findings

1. **Resolved: what option (a) waives (report lines 59-86).**
   - (a) is now "operator ratification", and only the operator can make it.
   - The new "What (a) waives" paragraph lists the five items I asked for:
     pre-merge authority (PR #55 had 0 reviews), V2 route checks, bridge
     provenance, the V2 probe, no precedent, and the AGENTS.md:116-117
     exception being operator-only.
   - Each waived item is stated to stay MISSING.
2. **Resolved and verified: row 6a.** The author inferred this from the suite
   script. I checked it against the log myself. I streamed the log of job
   `133021540905` once, through `awk`/`grep`, and did not save it.
   - **The test prints no name.** `tests/battle_variable_power_v2_test.lua`
     prints only `%d passed, %d failed`. Run locally at the same bytes
     (unchanged `65fceaa..98bac30`), it gives `80 passed, 0 failed`.
   - **No-ROM step** (the group ending `PASS: 207 test files (no-ROM mode;
     ...)`). The lines immediately before `battle_weather_test: 220 passed, 0
     failed` are, in order:
     - `102 passed, 0 failed` (status_leftovers)
     - `72 passed, 0 failed` (V1)
     - **`80 passed, 0 failed` (V2)**
     - `144 passed, 0 failed` (V3)
   - **Verified-ROM step** (the group ending `PASS: 207 test files (ROM mode:
     verified ROM supplied)`): the identical sequence, with **`80 passed, 0
     failed`** at the V2 position.
   - **Identification.** The V2 line is identified by its position in suite
     order (`battle_status_leftovers`, `battle_variable_power_v1`, `_v2`,
     `_v3`, `battle_weather`) and by the count matching local runs of each
     file (102, 72, 80, 144). It is not identified by a name.
   - **Optional wording fix.** Replace "passed in both" (inferred from the
     script) with "printed `80 passed, 0 failed` in both suites (unlabeled
     output, identified by suite order; verified in this review)".
3. **Resolved: the status-line link.** The code span now closes before the
   `[closure-eligibility audit](…)` link.

`check_repository.lua` and `git diff --check` pass. The delta changes only
the report and the V2 task status line.

## Uncommitted contract and proposal (not in PR #78)

The files are:

- `/tmp/claude-1000/-home-home/ef96493a-7728-4d7a-9ad9-24921ed690d4/scratchpad/v2-equivalent-evidence-contract.md`
- `/tmp/claude-1000/-home-home/ef96493a-7728-4d7a-9ad9-24921ed690d4/scratchpad/v2-coordination-proposal.md`

**Accurate:**

- **The waived gates.** The contract's lines 100-110 keep gates 1-6a
  MISSING, and "waived" is never "satisfied". Gate 5 forbids any empty or
  docs-only stand-in patch. Gates 6b and 6c are not waived.
- **The operator-only determination is properly cited.** I checked each cite
  at `98bac30`:
  - AGENTS.md:7 ("subordinate to explicit human direction");
  - AGENTS.md:87 (envelope limits and escalation);
  - AGENTS.md:91-92 (the fast lane is human-approved);
  - AGENTS.md:116-120 (full relay; the review and no-self-review rules
    still apply);
  - `PROJECT_GOAL.md:20` ("never waived completion criteria");
  - design proposal lines 17-18;
  - V2 task line 5;
  - V3 final-head review line 30 ("cannot retrospectively supply ...
    authority");
  - V3 plan lines 14-16 and 142;
  - `HANDOFF.md:384`.

  The conclusion "YES, explicit operator ratification" follows from these.
- **The proposal file.** Its option (a) text now carries the waiver list and
  the operator-only wording. Its insertion points and JSON are unchanged from
  my `276d374` check, which passed.

**NEEDS_FIX before adoption:**

1. **The approval wording is not unambiguous.** Contract lines 74-76 and
   131-132 require "the operator's ratification ... verbatim, with the
   date". They give no required text, so "ambiguous" (stop condition, line
   164) becomes a judgment call. That is the failure mode in which vague
   operator input gets read as delegation.

   **Fix:** add a literal ratification sentence that the operator must state
   or affirm verbatim:

   > I, the operator, ratify the PR #55 merge of V2 Fury Cutter (`0663e1d`) in lieu of full-relay gates 1-5, as an exception to AGENTS.md:116-117, waiving pre-merge implementation authority, V2 route checks, bridge-published provenance and a V2 probe; and I accept the verified-ROM step of run `43782148986` as gate-6a substitute evidence. Gates 6b and 6c remain required.

   Also add: "Approvals such as 'ok', 'go ahead', 'proceed', or an approval of
   a different item do not count."
2. **The "not waived" list is incomplete (contract lines 112-114).** Add:
   - **No required evidence is waived.** Only the process gates 1-5, and
     the route-specific parts of 6a, are waived. The ROM-fixture evidence
     and the 6b review stay required. This reconciles the contract with
     `PROJECT_GOAL.md:20`, which it cites itself.
   - **The reopen rule.** A later failing V2 ROM fixture or V2 test reopens
     V2, mirroring the fast lane's rule 4.
   - **The merge gate.** Merging the adoption and coordination commits still
     needs the operator's normal merge approval. The ratification is not a
     merge delegation.
   - **Source-derived test oracles.** The source-derived test-oracle rule
     still applies to any later V2 change.
3. **The 6a citation (contract line 107).** It says "Already verified
   against the log in review `4819085`". That review verified only the V2
   ROM-fixture line. The `battle_variable_power_v2_test.lua` lines (`80
   passed, 0 failed` in both suites) were verified here, positionally.
   **Fix:** cite this review for that part, and note that the output is
   unlabeled.

Only this review file was authored. Nothing was merged, no log was stored,
and no coordination or scratch file was edited.
