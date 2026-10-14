# Effect-45 implementation — local construction evidence

- Task: [P4-F3-RECOIL-IF-MISS-IMPLEMENTATION](../tasks/phase4-recoil-if-miss-implementation.md).
- Status: `LOCAL PACKAGE READY — GUARDED EXECUTION AND OUTCOME REVIEW PENDING`.
- Isolated construction base: `15c15c22634d48f7fc11ce4366fa4fc60f8e008d`.
- Authority: exact task at `96b10ce`, independently
  [PASS](../reviews/2026-10-13-recoil-if-miss-implementation-authority-review.md).
- Behavior authority: accepted [design](phase4-recoil-if-miss-design.md)
  and controlling [source supplement](phase4-recoil-if-miss-entry-state-discovery.md).

The engine's literal effect-45/IDs-26-and-136 failed-accuracy branch now
checks ordinary immunity before selecting its result. Immune failure emits
noEffect and exits. Nonimmune failure emits miss, computes noncritical
base/STAB/type/random damage, halves with zero-to-one then target-max-HP cap,
clamps actual loss to attacker HP, emits a dedicated crash event, and invokes
existing attacker faint handling. The small effect-specific arithmetic helper
exposes the zero-after-cap boundary without inventing legal battler fixtures.
Successful-hit/admission and unrelated miss/recoil paths are unchanged.

The controller translates crash into text followed by an invisible attacker
HP entry. It does not compute damage, consume RNG, or change model HP. The
inventory changes only row 45 and totals implied by its two represented
ordinary-singles moves; admission totals and all other rows remain unchanged.

## Local evidence

All local gameplay checks cleared both `POKEPORT_ROM` and
`POKEPORT_RUNTIME_REPLAY`. No private ROM discovery/access occurred.

| Check | Result |
| --- | --- |
| Before edits: `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh` | PASS, 154 test files; expected ROM-dependent skips. |
| Focused engine | 332 passed, 0 failed; optional ROM fixture skip. |
| Focused scene controller | 87 passed, 0 failed. |
| Focused party bridge | 29 passed, 0 failed. |
| Focused inventory | Literal expected partition passed; SHA-ROM aggregate explicitly skipped. |
| New focused effect-45 ROM fixture | Explicit no-ROM SKIP, not acceptance evidence. |
| After edits: same no-ROM full-suite command | PASS, 155 test files; expected ROM-dependent skips. |
| Replay wrapper `bash -n` | PASS; wrapper was not executed locally. |

Focused commands used `lua5.1` in the task's required order, with the two
opt-ins cleared. The full after suite includes the final arithmetic test
case distinguishing target-max cap from attacker-max cap. No test failed
during this construction; no retry or substituted request was used.

Added engine assertions cover both move IDs and acting sides, either
position of dual-type immunity, exact event sequences, one PP, one/two
failure-branch draws and the next RNG sentinel, retained hit/immune-hit
draws, numeric stage/Reflect/STAB/type/random order, prior-critical reset,
rounding/minimum/cap edges, zero-after-cap arithmetic, target current versus
maximum HP, actual attacker HP clamp, firstBattle, noPP/auto-Struggle, and
literal ID/effect negatives. Actual fatal crashes cover both sides/IDs with
and without replacements, no remaining opponent action or duplicate faint,
pending-turn refusal, replacement resolution and a later legal turn.

Added controller assertions drive actual engine turns, for both sides and
nonfatal/fatal/replacement/immune outcomes. They advance through use/miss/
crash with old displayed HP, then check the invisible HP update precedes
faint and final COMPLETE or pending player PARTY. Existing foe continuation
remains caller-owned. Party assertions use real crash outcomes for both IDs,
then call unchanged persistence and decode HP/PP/checksum/identity, including
fatal HP zero and immune unchanged HP. Their in-memory save-block roundtrip
proves codec compatibility only, not normal lifecycle, disk save/reload,
live party-slot synchronization, fresh-process loading or trainer rewards.

The new guarded-only ROM fixture verifies supported revision, both complete
source-record fields and exactly two effect-45 members, without retaining
ROM bytes. The replay wrapper requires the supplied ROM environment, runs
the five exact tests through Lua 5.1 under strict failure handling, and only
then prints its bounded represented-state receipt. Neither has supplied
local ROM/replay evidence.

## Pending guarded evidence and handoff

Required and still pending: fresh parent prerequisites, exact patch
applicability, the sole named request, guarded target/apply/diff checks,
focused commands, guarded full no-ROM and SHA-ROM suites, non-skipped
inventory/two-record fixture, mandatory headless replay, guarded publication,
and separate independent exact published-outcome review. There is no guarded
run/job/implementation commit receipt for this package yet. Local PASS cannot
replace these gates; inventory metadata does not independently accept behavior.

Only the ten allowlisted files are changed. Task changes append evidence;
its accepted criteria are untouched. No workflow, shared fixture, main,
formula/party runtime, save/schema/codec, AI, route/probe/request, broader
coordination or capability-status edit occurred. No stage/commit/push or
patch-file creation occurred in Worker construction. Parent mechanically
derives the exact isolated diff and owns serialized dispatch after freshly
checking the task's prerequisites. No second request/retry is authorized.

All accepted exclusions remain: cancellation/interception, Protect/Substitute,
abilities/items, Endure/Focus Band, status/Foresight, semi-invulnerability,
called/mirrored or forced/multi-turn provenance, doubles/links,
malformed/unsupported battlers or party state, animation/timing and generic
MoveEnd/whole-turn parity. Conditional late-only immunity is not an ordinary
fixture. Effect-45 tests do not create broad Gen 3 or Phase 4 completion claims.
The evidence is headless represented-state behavior, not retail/LÖVE parity.

Final whitespace, repository syntax/local-target and exact ten-file scope
checks, plus artifact hashes, accompany the Worker handoff. The independent
Reviewer, not this report, decides final behavior acceptance.
