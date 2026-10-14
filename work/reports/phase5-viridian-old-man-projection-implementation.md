# Viridian Old Man projection — Worker preparation

- Task: [P5-04 implementation](../tasks/phase5-viridian-old-man-projection-implementation.md)
  under the accepted [recovery authority](../tasks/phase5-viridian-old-man-projection-recovery.md).
- Result: local preparation only; guarded evidence and independent exact
  review pending. No playable-Viridian or Phase 5 completion claim.
- Base: `8ec48cfe7e131ab62d54021ed5d382514314b2a2`; isolated detached worktree
  `/tmp/firered-p5-worker`. Existing main-checkout changes were not inputs.
- Source/design: public `pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788`,
  accepted [design `87644b2`](../reviews/2026-10-02-viridian-old-man-projection-design-review.md),
  [five-path route](../reviews/2026-10-03-viridian-old-man-projection-route-configuration-review.md),
  and [recovery authorization](../reviews/2026-10-09-viridian-old-man-projection-recovery-authorization-review.md).

## Exact implementation

[ViridianOldManProjection](../../src/core/ViridianOldManProjection.lua) accepts
only map ID `3*256+1`, one normal (`kind=0`) decoded object with local ID 4
and base graphics 240, and a session supplying `getVar`. It reads only
`session:getVar(0x4051)`, once after admission. It returns a shallow list copy
with only the selected template copied and projected; all unrelated record
identities/fields and the original list/template remain unchanged.

| Persisted scene | Graphics | Position | Movement |
| --- | --- | --- | --- |
| 0 | 34 | 21,11 | 8 |
| 1 | 32 | 21,8 | 1 |
| Integer >=2 | 32 | decoded position (source template 21,6) | decoded type (source template 1) |

Missing session/getter/list/object, another map, non-normal template,
non-240 base graphic, duplicate local ID, failed scene read, and missing,
non-number, fractional, negative or non-finite scene return the original
list with an explicit reason. Refusal does not replace the dynamic graphic
with a fallback. The global graphics decoder still rejects dynamic ID 240.

The sole [main](../../main.lua) integration is nine added lines inside
`loadMapObjectEvents`, after the existing hide/story filter and before
`ObjectEventState.new`. Only Viridian invokes the helper. Refusals are logged;
existing NPC construction proceeds unchanged with the unprojected input.
`world.mapObjectEventTemplates` continues to reference the original decoded
list. Hidden objects are not recreated. The helper is not a post-spawn update
or generic map callback, and it never writes the scene, graphics variable,
flags, saved template state, or RNG.

Each map load derives a new result from decoded templates, so scene 0→1→2
does not retain the earlier projected coordinates. This is the accepted
project reconstruction boundary, not a new retail persistent-template model.
Movement type 1 remains the existing LOOK_AROUND value; this task does not
implement its currently unsupported ticking or any tutorial motion.

## Focused evidence

[Focused test](../../tests/phase5_viridian_old_man_projection_test.lua):
115 passed, zero failed, with no ROM or LÖVE dependency.

- Literal scene 0/1/2/65535 outputs, static graphics acceptance, selected-field
  preservation, unchanged unrelated normal/dynamic/clone objects, and immutable
  source/session inputs.
- Re-entry from the same decoded input; >=2 preserves decoded fields rather
  than hardcoding the prior scene's coordinates.
- Wrong map/group/local ID/kind/base graphics, missing session/getter/list/
  object, ambiguous ID, getter failure, nil/string/boolean/table/fractional/
  negative/infinite/NaN scenes; ineligible inputs never read the scene.
- Global dynamic-ID-240 refusal remains active.
- Direct execution of the **actual production loader function body** extracted
  from `main.lua`, using synthetic decoded templates and stubbed unrelated
  external services. It constructs ordinary ObjectEventState NPCs for each
  scene and checks wrong-map bypass, refusal diagnostics, existing hide
  filtering and untouched raw template storage. No new main export is added.
- Static ordering assertions require event decode before the loader and the
  projection before NPC construction. These checks are not a gameplay replay.

## Commands and outcomes

Executed from the isolated worktree using available Lua 5.1.5:

```sh
env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh
# Baseline: PASS, 152 test files; ROM-dependent checks skip.
env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY lua5.1 tests/phase5_viridian_old_man_projection_test.lua
# PASS: 115 passed, 0 failed.
luac5.1 -p src/core/ViridianOldManProjection.lua main.lua tests/phase5_viridian_old_man_projection_test.lua
# PASS: syntax only.
env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh
# Post-change: PASS, 153 test files; focused test 115/0 included.
git diff --check
# PASS.
env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY lua5.1 scripts/check_repository.lua
# PASS after staging exactly five paths: 279 Lua, 219 Markdown, 675 local targets.
```

Local logs outside the repository:
`/tmp/firered-p5-evidence.4mX9tb/baseline-no-rom.log`, `focused.log`, and
`post-no-rom.log`. No private paths/data or generated game content were used.

Exactly five paths are changed: the helper, `main.lua`, focused test, task and
this report. No decoder, generic dynamic-graphics resolver, scripts/VM,
movement, tutorial/battle, Parcel, renderer, save, UI, route or coordination
behavior changes. No bridge artifact, private-runner dispatch or push was
performed by Worker. A later separately authorized guarded artifact must
still pass focused, shared no-ROM and SHA-ROM suites; its explicit **no-replay**
route does not prove rendering or traversal. Independent exact-result review
must precede reconciliation.
