# Task: scope Phase 4 player forced-replacement UI

- Status: `IMPLEMENTED — AWAITING INDEPENDENT REVIEW`
- Type: `PHASE 4 / BATTLE UI / BOUNDED INTEGRATION`

Implement trainer-only forced player replacement after a player faint using the
existing engine and party bridge. Do not implement voluntary switching, wild/Oak
paths, items, doubles, or broad party-menu parity.

## Boundaries

May change only `main.lua`, `BattleSceneController.lua`, focused tests, one
runtime replay, and task/coordination records. Do not change BattleEngine,
BattlePartyBridge, PartyScreen, Save codec, or add an orchestrator.

## Acceptance

1. After the real faint/message sequence drains and the engine awaits a player
   switch, controller enters forced PARTY state—not ACTION. A legal bench choice
   resolves once, queues the replacement message, then returns to ACTION.
2. Cancel/invalid/active/fainted/egg choices cannot clear pending replacement;
   no legal bench takes the ordinary player-loss path without opening selector.
3. Main trainer seam persists outgoing HP zero before replacement, updates only
   after legal choice, synchronizes live record/slot/name/back-sprite callback,
   and preserves both records across SaveFileCodec roundtrip.
4. Focused controller test, verified-ROM main seam, deterministic runtime replay,
   no-ROM/verified-ROM suites, and independent review pass.

## Explicit exclusions

Voluntary ACTION-menu POKEMON, field menu integration, SUMMARY/SWITCH/ITEM
submenus, wild/Oak-rival wiring, trainers with more than two foes, items,
doubles, trapping/Baton Pass, and retail party-menu visual parity.

## Worker evidence

Implementation is prepared for the explicit guarded bridge route. Focused
controller coverage passed (7 assertions); the verified-ROM main seam passed
(9 assertions) against the supported FireRed US v1.0 ROM; the deterministic
runtime replay passed; and both full no-ROM and verified-ROM suites passed
(132 test files each). Pending independent review and guarded publication,
not a Phase 4 completion claim.
