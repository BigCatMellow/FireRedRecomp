# Task: Phase 4 Pain Split two-sided HP/admission design

- Status: `CLOSED — REVIEWED PASS`
- Type: `PHASE 4 / BATTLE RULES / DESIGN`

## Goal

Define the smallest represented-state design for only Pain Split #220,
`EFFECT_PAIN_SPLIT` (91): a literal zero-power admission exception and ordered
attacker-then-target HP applications. Do not configure a route or implement.

## Design contract

`supportsMove` must not gain generic zero-power acceptance. A later change may
admit effect 91 alone after its normal null/Dream Eater safeguards. Resolution
must retain cancellation, announcement, PP, then the source no-RNG represented
accuracy branch. With pre-mutation values `A0` and `T0`, it computes
`average = floor((A0 + T0)/2)` and stores source deltas `A0-average` and
`T0-average` before mutation. The script applies attacker first, yielding
`A1 = min(Amax, average)`, then applies target second, yielding
`T1 = min(Tmax, average)`, followed by the shared-pain message. Each event
must report its own actual before/after/applied delta after that side's clamp,
not an overlarge stored healing delta. The source command itself does not
mutate HP; no ordinary crit/base/random/type path runs.

The existing engine needs explicit ordered HP-change events that can represent
both gain and loss without calling ordinary attack-damage/faint behavior. They
must preserve original-side identity and independently clamped HP, and prove
event ordering for attacker-lower, attacker-higher, odd sums, equal HP, and
asymmetric maxima where either side's max HP lies below the average.
Equal HP is successful sharing, not a generic failure. Because a living
attacker/target average stays positive, represented-state Pain Split emits no
faint event. A separate scene mapping may render its established shared-pain
text only; it may not add generic healing support.

## Explicit exclusions

Do not add generic zero-power admission, generic HP/healing APIs, Protect,
Substitute, Mirror Move, Lock-On/sure-hit, semi-invulnerability, items,
abilities, status, doubles/links, UI redesign, generic effects, or Phase 4
completion. The later route must be separately planned, reviewed, configured,
and probed before any Worker request.

## MUST NOT CHANGE

No code, tests, bridge configuration, Worker request, or behavior in this
design task.

## Review

Independent design review passed. The next gate is one separate literal
fail-closed Worker-route plan; no configuration or implementation is authorized
by this design closure.
