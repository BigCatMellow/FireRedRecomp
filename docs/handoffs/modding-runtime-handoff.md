# Mod runtime extension — active

Status: active, uncommitted worktree; do not duplicate or move to `completed/`.

## Goal

Extend the API-v1 mod runtime with small, deterministic live seams while
preserving ROM data immutability and save compatibility. This is Phase 10
partial progress, not authorization to invent a map renderer, mod save schema,
or unrestricted host access.

## Landed in this worktree

- Live battle data namespaces and `battle.resolveMove`.
- Field collision, completed-step, interaction, wild-encounter, and warp hooks.
- `field.mapLoaded` runs exactly once after a destination map and final player
  tile are established, with only bounded message/flag/variable context.
- Field interaction/step contexts limited to message, flag, and variable writes.
- Profile-sidecar compatibility: cosmetic differences are reported; migrations
  are rejected until a host executor exists.
- `ModRuntime.validate(fs, root)` validates packages without applying content.
- `ModRuntime.validate(fs, root, {namespaces=...})` dry-runs callbacks against
  a fresh declared host, resolves every namespace to catch invalid lazy
  operations, then rolls every operation and hook back.
- Saves retain one rolling backup and recover from it only for missing/corrupt
  primary files, never to bypass mod-profile safety.

## Verification

Run from the repository root:

```sh
luac5.1 -p main.lua
lua5.1 tests/mod_runtime_test.lua
lua5.1 tests/mod_save_compatibility_test.lua
git diff --check
POKEPORT_ROM=/home/mellow/Documents/Projects/Pokemon_ReComp_FireRed/FireRed/pokefirered-master/pokefirered.gba bash scripts/test_all.sh
```

Latest result: PASS, 138 test files in both no-ROM and verified-ROM modes
(ROM-dependent assertions skip only in the former).
`scripts/test_all.sh` now compiles `main.lua` first, catching its Lua 5.1
main-chunk local-variable limit in CI as well.

## Next bounded work

Prefer another narrow live seam or a consumer for the map/sprite/UI/audio
content namespaces. The declared-host package-validation improvement and the
map-entry field seam are complete.
Keep package entrypoints sandboxed; do not expose filesystem, process, or raw
LÖVE rendering authority. Update `docs/modding.md` and the Phase 10 checklist
when behavior changes. Human review/commit remains the owner boundary.
