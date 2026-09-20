# P4-02 independent source/test preflight review

- Preflight disposition: `PASS` — exact source/report/test preparation only.
- Overall P4-02 acceptance: `BLOCKED` — mandatory guarded, non-skipped private-ROM evidence remains absent; the separate route probe has not passed.
- Prepared revision: `688433a3093dc15db32d62bd5a59fd7a84ac0cd0`.
- Preparation base: `82af91015cc438711d7ae9c6cbb001cdfddd36d1`.
- Accepted engine baseline: `a739ddc88cb44a33d5e6025e619cf1df3fe6a1a8`.
- Reviewed worktree: `/home/home/FireRedRecomp-inventory`; independent review relay initially `d7f12003c7930193720fca5fa3dcaa276b60da57`.
- Independent live-main recovery returned `ef836a4f816490daee1cc4b154288edd56c8169a` during this review. Review authority and artifact identity remain the exact prepared revision above.
- Source pin: `pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

## Findings against the existing inventory contract

The exact diff contains only the three allowed paths: the new inventory test,
the source inventory report, and its task evidence record. No runtime, importer,
admission, configuration, coordination, or phase-status change is present.
Numeric membership/classification metadata and source symbols stay within the
approved report boundary; no ROM bytes, full move-record dump, extracted strings,
media, generated cache, or other prohibited content entered the diff.

An independent join of pinned move/effect constants and source move records
against the literal test expectations verified every real move ID 1–354
exactly once, sentinel 0 excluded, all 214 defined effects, 198 used effects,
16 unused definitions, and every positive/zero power classification. Counts
are 216 positive-power and 138 zero-power records. The report's membership,
counts, power classes, admission labels, and semantic labels match the test
for every family. A separate comparison also verified every one of the 214
reported script owners and line anchors against the pinned dispatch table
and actual script definitions, including unused and aliased effects.

Admission and semantics remain separate. Running the actual accepted engine
predicate on independently parsed source effect/power metadata reproduced all
354 literal admission expectations: 248 admitted and 106 rejected. The report
correctly identifies the literal Pain Split exception, Dream Eater's explicit
rejection, and 111 admitted but uncovered positive-power records. Unused effects
make no real-record admission claim. The literal expectations do not construct
their answers from the engine's predicate or exported dispatch tables.

The classification is acceptable as bounded discovery metadata: 137 represented
records, 25 candidates, 191 blocked records, and one intentional rejection.
Represented families correspond to existing explicit engine mechanisms and
referenced tests, with shared state exclusions and mixed-family distinctions
stated. General status, charging, trapping, weather, held items, interception,
delayed effects, and other absent paths are not promoted to coverage by positive
power. Candidate labels propose separate discovery, not proven behavior. In
particular, the report preserves Surf's omitted submerged interaction, Struggle's
special path, source-defined recoil members, unused stat-name aliases, and the
difference between ordinary switching and effect-specific interception.

The single selected successor, effect 32 with move IDs 105 and 303, has concrete
story evidence: both pinned Misty party entries explicitly include Recover.
Independent inspection of `BattleScript_EffectRestoreHp` and
`Cmd_tryhealhalfhealth` confirms the stated own-max-HP half-heal, zero-to-one
minimum, full-HP failure, and cancellation/announcement/PP sequence without
ordinary accuracy or damage. HP/maxHP are represented, so a separate source-lock
leaf is plausible. Brock's Defense Curl and Bind need their stated volatile/
trapping paths; Misty's additional effects, AI, and item remain unresolved.
The report neither authorizes Recover implementation nor bundles adjacent
healing effects or claims the trainer complete.

## Independent verification

The reviewed test validates its literal partition before the no-ROM skip. Its
guarded branch calls the existing ROM verifier and parser, uses the actual
admission predicate for every parsed real record, and checks membership,
power class, per-family counts, totals, and predicate results. Source-only
definition counts are explicitly labeled; semantic classifications remain
reviewed metadata, not an inference from ROM admission. Diagnostics contain
aggregate counts and mismatch categories only.

Independent checks passed:

- Lua syntax and the full isolated-worktree no-ROM suite: 150 test files,
  exit 0; the aggregate test explicitly skips ROM work after partition validation.
- Exhaustive source/test/report join and all 214 dispatch/anchor comparisons
  described above.
- An in-memory source-metadata harness ran the exact test successfully and
  confirmed 354 calls to the actual engine predicate.
- Nine controlled harness defects failed without emitting its final PASS:
  wrong effect, wrong power class, missing record, undefined effect, admission
  drift, predicate exception, non-boolean predicate result, verifier rejection,
  and wrong importer count.
- `git diff --check` passed for the exact prepared range.

The harness deliberately mocks importer, SHA-verification, and file I/O. It
checks test control flow and mismatch detection only. No ROM was opened or
downloaded, no source record dump was printed or written, and neither this
harness nor the no-ROM suite supplies the missing supported-ROM evidence.
Previously reviewed route configuration was not retested or changed here.

## Exact next allowance and remaining gate

No source/test correction is required for this preflight revision. Orchestrator
may preserve it as the independently reviewed preparation for the later bounded
request. It must not publish that inventory request until the private runner
returns and the existing separately authorized route probe passes. The current
offline-runner blocker is retained, not treated as an artifact failure or waived.

After probe PASS, the request must still pass its configured checks, including
the full SHA-verified-ROM suite with this aggregate test executing without a
skip. The resulting exact implementation revision and guarded evidence require
final independent review before P4-02 can close or the selected discovery family
can be dispatched. Any intervening artifact change needs proportionate recheck.
This report does not close P4-02 or Phase 4 and does not affect Phase 2's external
reference requirement.

Reviewer wrote only this report. No artifacts were fixed, no coordination was
edited, and no commit, push, probe, or runner request was performed.
