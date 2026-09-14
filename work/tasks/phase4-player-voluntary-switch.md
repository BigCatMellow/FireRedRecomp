# Task: Phase 4 trainer-only voluntary player switching

- Status: `IMPLEMENTED — PENDING INDEPENDENT REVIEW`
- Type: `PHASE 4 / BATTLE UI / BOUNDED INTEGRATION`

## Goal

Wire the existing voluntary `switch` action through trainer battle UI and the
save-backed party bridge. A legal incoming Pokémon replaces the active battler
before the foe acts in that same normal turn.

## Boundaries

May change `main.lua`, `BattleSceneController.lua`, exact focused tests/replay,
and task/coordination/review records. Must not change BattleEngine,
BattlePartyBridge, PartyScreen, save codec, trainer layouts, held items, doubles,
wild/Oak paths, item UI, or AI policy.

## Acceptance

1. ACTION POKEMON opens a voluntary selector only with a current legal bench;
   no bench cannot consume turn/RNG or mutate active state.
2. Cancel returns to ACTION unchanged; active/fainted/Egg/stale/forged choices
   are revalidated and rejected.
3. Legal choice persists outgoing HP/PP, builds from current save record, calls
   existing engine switch once, and lets foe act against incoming battler.
4. Slot/record/display/back-sprite update only after legal selection and records
   survive SaveFileCodec roundtrip. Forced replacement remains cancel-proof.
5. Verified-ROM `startTrainerBattle(89)`, focused/runtime/full-suite/review
   evidence pass.

## Worker evidence

The bounded implementation is ready for independent review on the explicit
bridge route. Focused controller coverage passed (8 assertions), verified-ROM
`startTrainerBattle(89)` coverage passed (8 assertions) against the supported
FireRed US v1.0 ROM, and the deterministic runtime replay passed. Full
no-ROM and verified-ROM suites each passed all 134 checked-in test files. The
change keeps `BattleEngine`, `BattlePartyBridge`, `PartyScreen`, save codec,
wild/Oak, items, doubles, and AI untouched. This is not a Phase 4 completion
claim pending independent review and guarded publication.
