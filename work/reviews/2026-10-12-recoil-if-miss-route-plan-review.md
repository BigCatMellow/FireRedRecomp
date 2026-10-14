# Effect-45 bridge route plan — independent review

Verdict: **PASS** for exact task/report revision
`04636d10de3de18a7cb6009f92838b4156b95cb1`, parent
`044c672c7e5a8228b92e53477bcd7eebf23761e8`. This is route-planning
acceptance only, not configuration, substrate readiness or behavior evidence.

- [Task](../tasks/local-worker-bridge-phase4-recoil-if-miss-route-plan.md)
  SHA-256: `1145075eb849adec3916aa624c0e7acc468179da01d5b77155bec8c2be15cd12`.
- [Report](../reports/phase4-recoil-if-miss-route-plan.md)
  SHA-256: `95ec46b381642cc89c8f14fde71744e0bc4f4e16f40979f7236b720d747ae13f`.
- Independently recovered public parent, then published
  `READY_FOR_REVIEWER` checkpoint
  `fd263e8d4dc75df2239dca330173b21053b9d783`.

## Findings

1. The proposed `phase4-recoil-if-miss-effect` selector is distinct from
   current selectors. Its explicit patch/probe basename patterns follow the
   bridge convention; filename wildcards do not widen patch targets. The
   ten-path validation/staging list is literal and shared, with only the
   accepted engine/controller runtime owners. The four future paths are
   identified as absent artifacts, not existing coverage or authority.

2. The added `tests/battle_party_bridge_test.lua` target is justified.
   Inspection confirms its local encoded-record fixture, battler conversion,
   unchanged persistence call and decoded checksum/identity assertions can
   be extended to obtain HP/PP from actual effect-45 engine resolution.
   Fatal zero HP, nonfatal loss and immune spent-PP cases need no persistence
   runtime change. The plan explicitly limits this to an invoked
   model-to-party bridge (and optional in-memory codec roundtrip), not normal
   lifecycle wiring, live party synchronization, disk save or fresh reload.

3. Fatal crash/continuation and controller evidence are attainable in the
   selected existing tests. Engine tests already exercise real
   `hasReplacement`, pending-switch refusal, `resolveForcedSwitch`, later
   legal turns and self-faint action stopping. Controller construction and
   existing callback/queue seams support actual crash events, stepwise
   text-before-invisible-HP assertions, pending PARTY and terminal COMPLETE.
   The plan requires real engine-produced crash events rather than mocked
   recoil, and does not claim unchanged replacement tests prove new behavior.

4. The five focused commands are literal, ordered and compatible with the
   bridge's `$LUA` selection. Shared no-ROM and SHA-verified-ROM suite commands
   remain unchanged. The shared runner discovers the new `*_test.lua`
   fixture without modification. The plan correctly distinguishes allowable
   no-ROM skips from required non-skipped inventory and two-record ROM
   evidence, and notes that full suites require `lua5.1` despite focused
   fallback. Expected records remain source-derived rather than inferred from
   the engine predicate.

5. The required headless wrapper follows the current Magnitude convention
   but runs all five scoped tests. Its later deterministic sequences must
   cover crash/faint/replacement, ordered controller HP, explicit HP/PP
   persistence and RNG sentinels. The plan correctly limits this receipt to
   represented headless assertions; it is not independent retail playback,
   LÖVE presentation, normal save/reload or whole-turn RNG parity.

6. Trusted-main/single-input, unknown-route rejection, supported SHA, patch
   validation/application/diff and patch-only publication gates are retained.
   A fresh route-specific probe is separately gated after configuration PASS;
   all patch-only steps must skip. Its result cannot prove the ten-path
   allowlist or behavior and creates no retry allowance. Private data and
   environment-bearing suite summaries are excluded from authored receipts.
   Literal family selection, immune early exit, successful-hit preservation,
   ordinary-recoil separation and all accepted design exclusions remain intact.

The future configuration must encode the plan's requirement that missing
required artifacts fail; existing routes' conditional staging loops are not
evidence that this requirement is already enforced for the new route.
This is an existing plan obligation, not an authorization to change shared
guards or other routes.

## Checks and exact next allowance

Inspected the current workflow, bridge procedure, prior route pattern,
headless wrapper, suite discovery, inventory/ROM fixture conventions, and
actual engine/controller/party test seams read-only. The workflow SHA-256
matches `fb98001cd06ab8ff368f9ccbb0d079ebb809865709a1708ce2dfa55b6199edac`.
The exact commit contains only its report and appended task evidence; criteria
are unchanged. Artifact hashes match. Exact whitespace check passed; repository
checker passed: **280 tracked Lua, 272 tracked Markdown, 875 local targets**.
No gameplay tests, runtime/replay, ROM/private-runner or route action occurred.

The sole next allowance is to compile a separately bounded configuration task
for the workflow's new route arms, bridge documentation and that task's own
evidence. It must encode this reviewed ten-path/five-command/replay surface
and receive independent review. This PASS itself authorizes no configuration
edit, probe, request, implementation or gameplay-support/Phase 4 claim.
Configuration, probe outcome, implementation authority and implementation
outcome retain their separate gates.

Only this review file was authored. No correction, coordination edit,
staging, commit or push was performed by the Reviewer.
