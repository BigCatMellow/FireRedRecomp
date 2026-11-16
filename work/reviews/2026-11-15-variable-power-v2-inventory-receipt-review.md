# Variable-power V2 inventory ROM-fixture receipt — independent review

Verdict: **PASS** for exact revision `02c3cab` (PR #77), based on main
`5df0b21`.

## Findings

1. **The quoted line is verified in the live job log.** I streamed the log
   of job `133021540905` (run `43782148986`) once through `awk`/`grep`
   only; it was never saved to a file. The log has one group per step.
   - **Verified-ROM step.** I identified it as the group that ends
     `PASS: 207 test files (ROM mode: verified ROM supplied)`. It contains
     exactly
     `phase4_variable_power_v2_effect_rom_test: 2 passed, 0 failed; exact 1-member source family`.
     There is no V2 `SKIP` in that step.
   - **No-ROM step.** The preceding group, which ends `(no-ROM mode; ...)`,
     shows the expected
     `SKIP phase4_variable_power_v2_effect_rom_test (set POKEPORT_ROM)`.

   So the PR's quote, `... 2 passed, 0 failed`, is a verbatim prefix of the
   non-skipped verified-ROM line.
2. **The wording is accurate.**
   - Run `43782148986`, job `133021540905` and head `65fceaa` are correct.
   - The run selected `phase4-variable-power-v3-effect`, not a V2 route. The
     row says so explicitly. It cites the V2 fixture only as a shared-suite
     result, consistent with outcome review `922ee70`'s exclusion note.
   - Clarification: `922ee70` does not itself quote the V2 line. This review
     is the independent verification of that line.
   - The fixture checks only the supported-ROM record and family membership.
     The row makes no behavior, LÖVE or phase claim.
3. **Nothing else changed.**
   - The only change is one hunk, in row 119 of
     `work/reports/phase4-move-effect-inventory.md`.
   - Row 119's text before the trailing "ROM fixture pending." is
     byte-identical.
   - The PR merges cleanly with main, by `git merge-tree`.
   - `check_repository.lua`, the no-ROM `test_all.sh` (207 files) and
     `git diff --check` all pass.

Only this review file was authored. Nothing was merged, and no log was
stored.
