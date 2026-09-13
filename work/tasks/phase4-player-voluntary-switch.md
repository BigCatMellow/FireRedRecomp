# Task: Phase 4 trainer-only voluntary player switching

- Status: `BLOCKED ON BRIDGE ROUTE`
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
