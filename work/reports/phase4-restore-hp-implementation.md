# Restore HP implementation evidence

- Task: [P4-F3-RESTORE-HP-IMPLEMENTATION](../tasks/phase4-restore-hp-implementation.md).
- Scope: ordinary, non-intercepted Recover (105) and Slack Off (303) only.
- Source/design authority: accepted source lock `1f89f0d` and design review
  `4863567`; reference pin `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Status: worker evidence only; guarded SHA-ROM execution and independent
  exact-revision review remain required.

## Bounded implementation

`BattleEngine` admits effect 32 only when the caller supplies ID 105 or 303
and the record remains zero-power, USER-targeted. The selected slot ID is
forwarded by both engine and controller callers; record-only/other-ID/wrong
shape effect-32 calls remain refused. The zero-power branch spends its shared
PP once, bypasses accuracy/RNG, and appends either a clamped own-HP
`restoreHP` snapshot or `restoreHPFull` after `useMove`.

`BattleSceneController` expands a successful result into its invisible own-HP
snapshot followed by recovery text; the full result has text and no HP entry.
The inventory reclassifies only effect 32's two members, moving admissions from
248/106 to 250/104 while preserving the 354-record partition and all
positive-power totals. The ROM fixture verifies both retail records and the
two-member family count without retaining ROM data. The replay is a deterministic
represented-state engine/controller trace, not visible LÖVE or animation proof.

## Local evidence

- `lua5.1 tests/battle_engine_test.lua`: 242 passed, 0 failed.
- `lua5.1 tests/battle_scene_controller_test.lua`: 41 passed, 0 failed.
- `lua5.1 tests/phase4_move_effect_inventory_test.lua`: source partition PASS;
  SHA-ROM branch skipped because no local `POKEPORT_ROM` is available.
- `lua5.1 tests/phase4_restore_hp_effect_rom_test.lua`: clean ROM-missing skip.
- `bash scripts/test_all.sh`: 152 no-ROM test files PASS.

The engine test covers both sides, odd/even/max clamp boundaries, PP before
full-HP viability, chosen-zero-PP preservation, negative IDs/shapes and zero
effect RNG. The controller test covers use-message/snapshot/recovery ordering
and full-HP's no-snapshot result. The guarded request must still supply a
non-skipped supported-ROM fixture, inventory admission aggregation, replay and
full-suite evidence before an independent reviewer can decide the task.

## Exclusions retained

No Snatch, cancellation/MoveEnd, status/item/ability handling, Milk Drink or
other recovery family, generic healing abstraction, persistence, AI policy,
doubles/links, animation/timing parity, importer, save, UI-scene or
coordination behavior is introduced or claimed.
