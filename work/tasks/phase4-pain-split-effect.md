# Task: Phase 4 Pain Split effect

- Status: `IMPLEMENTATION CONTRACT COMPLETE — PENDING INDEPENDENT REVIEW`
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
