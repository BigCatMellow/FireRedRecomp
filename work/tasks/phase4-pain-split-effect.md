# Task: Phase 4 Pain Split effect

- Status: `IMPLEMENTATION CONTRACT REVIEWED PASS — READY FOR WORKER`
- Type: `PHASE 4 / BATTLE RULES / BOUNDED IMPLEMENTATION`

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
