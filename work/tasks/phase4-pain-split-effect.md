# Task: Phase 4 Pain Split effect

- Task ID: `P4-PAIN-03` (authorized by `P4-PAIN-02`)
- Status: `READY_FOR_REVIEWER`
- Type: `PHASE 4 / BATTLE RULES / BOUNDED IMPLEMENTATION`
- Parent capability gate: Phase 4 move/effect matrix in `work/roadmaps/CAPABILITY_CHECKLIST.md`.
- Assigned role: `WORKER`; independent implementation reviewer: separate `REVIEWER` helper.
- Risk: `MEDIUM` — battle HP mutation; guarded verification precedes publication.

## Goal

Implement only FireRed `EFFECT_PAIN_SPLIT` (91), Pain Split #220, in the
existing one-opponent engine. Admit effect 91 alone despite its zero power, use
the represented no-RNG accuracy branch, and apply its two-sided HP sequence in
stock order.

## Acceptance

1. `supportsMove` admits effect 91 only; generic zero-power moves stay rejected.
2. Cancellation, announcement, PP, and zero-RNG represented accuracy order are
   retained before source deltas are computed from pre-mutation HP.
3. `average=floor((A0+T0)/2)`; attacker applies first and target second, each
   independently clamped to own max HP. Ordered events report actual
   before/after/applied deltas and scene output retains shared-pain text.
4. Tests prove #220's record, admission isolation, lower/higher/odd/equal,
   asymmetric max HP both sides, ordering, zero RNG, no faint, and ordinary
   regression.
5. Evidence passes only through reviewed/probed `phase4-pain-split-effect`.

## MAY CHANGE

Only the nine paths in `local-worker-bridge-phase4-pain-split-route.md`.

## MUST NOT CHANGE

Generic zero-power admission, generic healing/HP APIs, Protect, Substitute,
Mirror Move, Lock-On/sure-hit, semi-invulnerability, items, abilities, status,
doubles/links, other effects, UI redesign, Phase 2's external blocker, or
Phase 4 completion.

## Independent implementation-scope review

`PASS` at `b1cb14970726f5289b2439a906dcbeff26ad2e28`. The review reconstructed
the source-lock and design contract against the current engine: effect 91 is
currently rejected solely by generic admission; it can receive a literal
exception without widening zero-power acceptance; its no-state accuracy path
has no RNG draw; and the required pre-mutation attacker/target deltas, own-max
clamps, attacker-first event order, shared-pain presentation, and no-faint
boundary are all expressible within the literal nine-path route. Existing
focused no-ROM checks reproduced at 230/0 engine and 38/0 scene-controller.

Exactly one Worker request is authorized through selector
`phase4-pain-split-effect`. It must retain the reviewed route's literal
nine-path allowlist and focused, full no-ROM, SHA-verified-ROM, and replay
sequence. This PASS authorizes neither generic zero-power/healing support nor
any excluded state or Phase 4 completion.

## Worker result

The one authorized request, `87d5e72`, failed before publication in guarded run
`35410055700`. Focused checks and the full SHA-verified-ROM suite reached the
new Pain Split ROM-record assertion; that assertion alone failed because the
request expected flags `51`. Direct private-ROM parsing in the guarded runner
shows #220 has flags `18` (the source-locked Protect/Mirror-Move shape).
No implementation commit was published. Preserve this exact failure as a
bounded test-fixture defect; do not issue another Worker request until its
smallest correction receives independent review.

## Corrected request authorization — 2026-09-19

Independent fixture-scope review now passes at
[`../reviews/2026-09-19-pain-split-fixture-correction-review.md`](../reviews/2026-09-19-pain-split-fixture-correction-review.md),
against base `d793981f950407ee6f469dc50c02e32529cf3cb5`. This supersedes only
the preceding retry hold. The current user directed continued orchestration
with helper agents and explicitly selected the existing private runner.

`P4-PAIN-02` authorizes exactly one new request,
`work/local-runner/requests/phase4-pain-split-effect-20260919-v2.patch`.
It must preserve the failed request byte-for-byte except for Pain Split's
synthetic `flags=51` becoming `flags=18` and `m.flags == 51` becoming
`m.flags == 18`. Expected request SHA-256:
`c6170f42df62f45867bbf0c1330584a2c067136ff5811042fbc7d7009856cd69`.
The six patch targets remain inside the original nine-path implementation
allowlist; request transport and Orchestrator review/relay records are separate
from that implementation allowlist. Preserve the original failed artifact.

Prerequisites: reviewed source/design/route/probe and the new correction review;
private runner `firered-mint` was online and idle at dispatch. Local baseline
passed all 148 no-ROM test files using the isolated Lua 5.1 toolchain. The
Worker must check request digest/applicability, then publish through the existing
`phase4-pain-split-effect` selector under standing bounded publication authority.
Required focused, full no-ROM, SHA-verified full ROM, and configured replay
commands remain exactly those in the route contract. The replay is an engine /
scene deterministic script, not proof of a visible LÖVE battle animation.

Stop on any extra request diff, route change, failed guarded step, unsupported
ROM, or unavailable runner. Record exact run/commit evidence; do not improvise
a broader retry. On success, route the exact published implementation to a
separate independent Reviewer before closure. Eligible successor after PASS:
`P4-02` effect-family inventory refresh from the MAPSL execution plan; no
new move behavior or Phase 4 completion is authorized here.

## Corrected Worker result

Request `bf36d94ccb20b7457d224c7bd5f94d8b3cfeb89c` retained the reviewed
digest. Guarded run
[`35493728001`](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/35493728001)
passed SHA verification, target validation, application, focused checks, both
149-file full suites, and the configured engine/controller replay. Focused
checks: engine 237/0, scene controller 39/0; verified replay: engine 244/0,
scene controller 39/0, Pain Split ROM record 1/0. It published only the six
permitted implementation/test/replay paths at
`a739ddc88cb44a33d5e6025e619cf1df3fe6a1a8`. Independent `P4-PAIN-04`
implementation review remains required before effect closure.
