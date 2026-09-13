# Task: Phase 4 trainer-party construction for no-item layouts

- Status: `BLOCKED ON BRIDGE ROUTE`
- Type: `PHASE 4 / BATTLE DATA ADAPTER / BOUNDED IMPLEMENTATION`
- Risk: `MEDIUM`
- Parent gate: general trainer battles and switching

## Goal

Extend `TrainerPokemonFactory` from the current single supported default layout
to the real no-item trainer-party layouts: `partyFlags` `0` (default moves) and
`1` (custom moves). This is construction only; it must not make multi-Pokémon
trainer battles live yet.

## Source boundary

- `import/TrainerParty.lua` is the ROM-decoded source of party records.
- For `partyFlags == 1`, copy each record's four move slots and obtain actual
  move PP from the existing move catalog; do not invent PP or fallback moves.
- Retain existing deterministic personality/IV/stat construction for both
  layouts. Continue to reject held-item layouts (`2`, `3`) and unsupported
  doubles explicitly.

## MAY CHANGE

- `src/core/TrainerPokemonFactory.lua` and focused factory tests;
- one bounded ROM-backed fixture test and task/review/coordination records.

## MUST NOT CHANGE

- `main.lua` live trainer flow, party-size assertion, forced-switch behavior,
  trainer rewards, battle scene/menu UI, AI policy, held-item behavior, doubles,
  or broad move-effect rules;
- ROM/BIOS/media/artifacts or broader route/security policy.

## Acceptance

1. Existing `partyFlags == 0` output remains pinned by tests.
2. `partyFlags == 1` produces exactly the record's four moves with catalog PP.
3. ROM-backed fixtures prove one default-layout and one custom-move-layout
   trainer record; unsupported item layouts still fail loudly.
4. Focused, no-ROM, and verified-ROM suites pass.
5. Independent review passes the exact published revision. This task does not
   claim multi-mon live battle support.

## Next

After PASS, scope foe-only ordered multi-mon trainer orchestration as a separate
task with explicit reward and forced-replacement evidence.
