# Next-effect rerank — independent review

Verdict: **PASS** for the bounded research package, not an effect implementation.

## Exact reviewed artifacts

- Task: `P4-NEXT-EFFECT-RERANK`.
- Worktree/base: `/tmp/firered-p4-rerank` at
  `94211846d1bdd492a2f8655e9dc22738824d7e40`; independently recovered live
  GitHub main matched that revision at review time.
- This review covers the uncommitted two-path draft against that base, pinned
  by SHA-256, not a nonexistent report commit:
  - [Report](../reports/phase4-next-effect-rerank.md):
    `50bdbe92eccd3e0e2bdd10792c588c184f3b7268e929d0f022ff5ffab3b32c6c`.
  - [Task](../tasks/phase4-next-effect-rerank.md):
    `07b0df1d576682a5d9e0585c6504b002675160baf4ad7a8132ef2a1842e50ef6`.
- Public reference checkout independently verified at
  `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

The draft changes only the new report and the task's appended researcher
handoff. No runtime, test, route, status, coordination, ROM, extracted data,
or generated asset is part of it. The Orchestrator explicitly requested this
pre-publication review; the committed coordination row still says
`READY_FOR_WORKER`. This review does not silently change that row.

## Evidence and findings

1. **Coverage is current and bounded.** The accepted Restore HP outcome
   review and register identify `dc8ad06a3b9344dee61021b54c15d5d323650440`.
   Direct engine inspection confirms effect 32 admission requires Recover
   `105` or Slack Off `303`, zero power, and USER target. The inventory is
   unchanged between that revision and the reviewed base. An independent
   read-only recount of its literal rows gives 214 defined/198 used effects,
   354 distinct moves, 216 positive/138 zero-power moves, 51 represented
   families/139 moves, and 250 admitted/104 rejected moves. Effect 157 remains
   separate. The historical 248/106 report is correctly treated as historical,
   and positive-power admission is not claimed as semantic coverage.

2. **The ranking has real source-backed story signals.** The cited party
   entries match Brock's level-12 Geodude/Defense Curl and level-14 Onix/Bind,
   Alan's level-21 Geodude/Magnitude, and Goon's level-37 Koffing/Haze.
   Independently tracing the entries confirms Alan is actually used by
   [Route 9's event](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/scripts/trainers.inc#L553)
   and its map object, while Goon is used by the
   [Three Island encounter](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/maps/ThreeIsland/scripts.inc#L211).
   These support the shortlist's relative story priority; this is not a claim
   to enumerate every learnset or prove the earliest possible acquisition.

3. **Prerequisites are substantive, not inferred from names.** The pinned
   Defense Curl script sets a volatile bit, consumed by Rollout's calculation;
   Ice Ball uses that same effect. Trap initializes wrapped duration/ownership,
   has end-turn residual damage, and participates in escape/switch checks.
   The inventory still marks these and poison-hit blocked on state. Haze's
   source resets all battlers' stages; the report appropriately leaves its
   ordering and policy to a later source lock instead of treating existing
   stat-stage support as completed Haze behavior.

4. **Magnitude remains discovery, not implementation.** Constants confirm
   effect `126` and move `222`. Its source record has positive power `1`, so
   current generic admission does not implement dynamic Magnitude damage.
   Direct inspection of `BattleScript_EffectMagnitude` at script line 1679
   and `Cmd_magnitudedamagecalculation` at command line 8284 confirms the
   reported PP/selection/RNG/message/hit-loop sequence and the seven powers
   10/30/50/70/90/110/150. The shared loop explicitly handles Underground and
   further targets. The report therefore correctly leaves RNG ownership,
   exact event boundaries, and feasibility of a one-target exclusion contract
   to discovery. It selects exactly one successor, `P4-F1-MAGNITUDE-DISCOVERY`.

## Checks, limits, and next allowance

`git diff --check` passed. The untracked report's separate no-index whitespace
check produced no diagnostics; its difference exit code was 1. The inventory
recount verified unique exhaustive move IDs 1–354 without reading a ROM or
executing game code. No gameplay/full-suite/ROM/replay run was required or
performed for this research-only package. Prior Restore HP acceptance was
recovered from its accepted records; its guarded run was not rerun here.

After publishing these exact reviewed artifacts and reconciling coordination,
the Orchestrator may compile only the proposed read-only Magnitude source-lock
task. This PASS grants no implementation, new admission, route/configuration,
private-runner/ROM action, subsystem design, or capability-status advancement.
