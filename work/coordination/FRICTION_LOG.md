# Friction log

## 2026-11-16 — Low Kick engine contract design

- One batched read-only discovery command used candidate-local importer/core paths while its cwd was the public reference checkout; those paths and an assumed include/rom_header_gf.h do not exist there. No mutation or source uncertainty resulted. Split subsequent searches by checkout and discover actual paths before reads.
- A later batched candidate read again included reference-only linker/header paths; no-match errors were confined to discovery. Repeated cwd mix-up countermeasure: all remaining public-reference reads use absolute /home/home/FireRedRecomp-reference/pokefirered paths; independently re-read constants/header/mapping successfully via that path. No code/prototype executed.

## 2026-11-16 — independent Low Kick contract NEEDS_FIX corrections

- Independent review of e6633f0 identified ambiguous constructor notation (F1) and conflated selection/core lock semantics (F2). Corrected only those report/API/call-site/test paragraphs: preserve new(opts), explicit optional field and full call; one pure planner with mandatory selection/resolution context, projected next-turn expiry versus live direct-resolution locks/fallback. Added literal timer1/timer2/all-zero/cleared-lock witnesses. No runtime prototype or product suite. Countermeasure: bind each preflight call site to the exact phase-specific predicate and literal divergence case, rather than treating isLocked as core equivalence.

## 2026-11-16 — Low Kick bounded implementation recovery

- A candidate test filename guessed from the family name did not exist; discovery now uses `rg --files tests` before reads. No product mutation resulted.
- Local `gh run view 43930415514` could not connect to api.github.com. Recovered accepted public CI through the connected GitHub read-only job tool instead; its first call required `repo_full_name` rather than `repository_full_name`, corrected without external mutation.
- Isolated branch coordination files retain historical base state by design; the amended task and current canonical organizer relay own this dispatch. Worker does not copy or edit shared coordination owners.

- First focused Low Kick test run exposed fixture errors: Psychic defenders halve Fighting damage, battler stages are `statStages` with default6, and makeBattler initializes isFirstTurn2. Corrected fixtures to neutral Water targets/source stage0 and original constructor value; kept literal damage oracles unchanged. Explicit-defender fixture also reset its deliberately nil species before the next independent assertion. No engine relaxation.

- Added real timer1/timer2 call-site witnesses after planner tests passed. One foe-Struggle assertion incorrectly selected the player's earlier Splash useMove event; changed event lookup to literal move165. Source outcome/draw expectations remained unchanged.

- Required V3 regression caught three zero-PP lock failures after extraction into the shared effective-record planner: existing downstream PP/canceller checks still need its core-lock result. Return that pure result to resolveMoveCore as `lockedTurn` rather than recompute a second predicate. Added actual valid Low Kick zero-PP live-lock and saved-cleared-lock witnesses on both sides, then reran focused/V3 checks. This is the exact regression the mandated V3 suite protects; no existing test/oracle changed.

- Additional synthetic actual-resolution witness forced Low Kick into a live Rollout lock at0PP. It correctly stayed Low Kick and dealt literal9/four draws after restoring lockedTurn, but the inherited generic-hit PP path decremented0 to-1 (only real Rollout/rampage records have modeled PP exemptions). Such a Low Kick/Rollout mismatch is not reachable from source; contract limits planner semantics and inherits later canceller/action behavior. Do not repair global PP behavior or assert source parity for this impossible combination. Request parent disposition before changing this extra assertion; mandated literal planner/real V3 assertions remain intact.

- Parent rina explicitly approved removing only the extra source-unreachable Low Kick-as-Rollout-lock PP-preserved assertion: it lacks a source oracle and is outside acceptance. Retained labeled synthetic effective-record/damage/RNG checks, every mandated pure-planner zeroPP/lock immutability witness and actual source-reachable V3 locked0PP assertions. No assertion blesses inherited negative PP; no generic PP repair or contract change.
- First ephemeral public-source inventory proof parser omitted parenthesized bit-shift MOVE_TARGET definitions. Extend its read-only constants parsing to those source expressions, then rerun; this is a proof-script parsing gap, not inventory/engine evidence. No generated source data is saved.

## 2026-11-17 — Low Kick implementation F1 PP-order correction

- Independent review445f3c4 NEEDS_FIX (review SHA-256145d6be17bde215204a0f179d98490680af775316c6f9ff67bb38ccad5b87199) found the Low Kick route inherited generic accuracy-before-PP order; source script2550–2556 explicitly spends PP before weight calculation/accuracy. Final PP/damage/four draws hid the defect in the old400 assertions. Add both-side literal read-only RNG PP observers for hit and accuracy miss as a mechanical safeguard, without changing old oracles/non-Low-Kick PP behavior.

- New observers first reproduced exactly four F1 failures (both sides, hit and accuracy miss), while412 other assertions passed. Moved only Low Kick's PP deduction and action-local weight calculation into its post-canceller/noPP-check attack prefix, excluding that move from generic late deduction. All original400 assertions remain unchanged; new total416/0 and independent pp_order.lua now show19,19,19,19 on both sides. Focused controller/V4a/H1/V4b/WG/V2/V3 checks and final foreground215 suite pass. Prior baseline/source/inventory/differential evidence recovered rather than repeated; no generic PP/unreachable-state repair.
