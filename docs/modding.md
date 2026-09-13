# Modding foundation

FireRed ReComp keeps imported ROM data separate from mod-owned content. Do not
mutate importer tables in place: build a `ModRegistry` and give consumers its
resolved snapshot instead. This preserves a pristine base profile and lets a
failed mod be discarded without leaving partial state behind.

The current stable surface is API v1 in `src/core/ModRegistry.lua`. It is pure
Lua and headless; discovery, manifests, dependency solving, and runtime file
loading are intentionally separate future layers.

`src/core/ModManifest.lua` now validates decoded API-v1 manifests and produces
the deterministic enabled-mod order. A manifest has `id`, semantic `version`,
optional numeric `priority`, `dependencies`, and `conflicts`. Dependencies
always load first; unrelated mods sort by ascending priority then lexical id.
It rejects duplicate ids, missing dependencies, cycles, conflicts, and API
versions this engine does not provide.

`src/core/ModLoader.lua` is the headless bridge between those validated
manifests and a `ModRegistry`. Supply decoded manifest tables plus callback
functions; it resolves order and treats the complete load as a transaction.
If a later callback fails, all contributions from that load attempt are
removed. It does not discover files or execute untrusted packages.

`src/core/ModPackages.lua` adds deterministic package discovery without
coupling the SDK to a particular runtime. Provide filesystem `list`,
`isDirectory`, and `read` methods, plus a manifest decoder and entry compiler.
It reads `mods/<id>/manifest.json` and `mods/<id>/init.lua`, sorts directories
lexically, requires the directory name to equal the validated manifest id, and
returns the `{manifest, callback}` entries accepted by `ModLoader`. The host
still chooses JSON parsing and code-execution policy; package code receives no
implicit filesystem authority from this module.

For the documented manifest format, `src/core/ModJson.lua` supplies the
default strict decoder. It supports standard JSON values and Unicode escapes,
and rejects duplicate object keys and malformed input so a manifest's meaning
does not vary by parser.

`src/core/ModEntrypoint.lua` is the standard `init.lua` compiler. An entry
must return `function(mod) ... end`. Its Lua 5.1 environment contains only
copied `math`, `string`, and `table` libraries plus basic iteration/conversion
functions; it has no ambient `os`, `io`, `require`, filesystem access, or
process-global random-number generator (`math.random`/`math.randomseed`).
Hosts may pass deliberate named capabilities, but should keep those narrow.

`src/core/ModRuntime.lua` composes discovery, `ModJson`, `ModEntrypoint`,
`ModLoader`, and `ModSaveCompatibility` into a single headless lifecycle.
Register namespaces with their immutable base data, call `load(fs, "mods")`,
then consume `resolve(namespace)` and `profile`. `unload()` removes every
mod-owned operation before a changed enabled set is loaded.

For CI or mod-author tooling, `ModRuntime.validate(fs, "mods")` validates
package layout, strict manifests, dependency/conflict order, and sandboxed
entry compilation without executing callbacks or mutating content. Pass an
explicit headless host contract as the optional third argument —
`{ namespaces = { ... } }`, using the same namespace declarations as
`Runtime.new` — to dry-run callbacks transactionally in a fresh registry.
That additionally rejects unknown namespaces and invalid lazy content
operations when the declared namespaces resolve; it never accepts or mutates
a caller-owned registry or hooks.

The game now instantiates this runtime through LÖVE's sandboxed filesystem at
startup. Its live battle namespaces are `battleSpecies`, `battleMoves`,
`battleNatures`, `battleTrainers`, and `battleItems`: patches to existing ids
affect wild and trainer battle construction, while the resolved profile is
stored in the save sidecar. A minimal package is:

```json
{"id":"example","version":"1.0.0","saveImpact":"gameplay"}
```

```lua
-- mods/example/init.lua
return function(mod)
  mod:content("battleMoves"):patch(33, { power = 50 })
end
```

Packages may also wrap the live move resolver through
`mod:hook("battle.resolveMove", function(nextFn, engine, side, slot, events)
...)`. Hooks use the same manifest priority/id ordering as content. Runtime
load failure and `unload()` remove every hook owned by the affected package.
The field equivalent is `field.isWalkTileBlocked`; it receives
`(nextFn, tileX, tileY, mapId)`, allowing coordinate/map-specific collision
rules while retaining the vanilla check through `nextFn`.

`field.playerStep` receives `(nextFn, mapId, tileX, tileY, context)` after a player
step completes and before the normal story, connection, warp, trainer-sight,
and wild-encounter pipeline. A hook can call `nextFn` to retain that pipeline
or deliberately short-circuit it for custom field behavior. Its context has
the same bounded `message`, `setFlag`, and `setVar` operations as interaction
hooks.

`field.mapLoaded` receives `(nextFn, mapId, tileX, tileY, context)` exactly
once after a map load has completed and the player's final destination tile
has been assigned. It is not a raw decode callback and does not run again on
ordinary player steps. Its context has only `message`, `setFlag`, and `setVar`;
it intentionally exposes no renderer, filesystem, object spawning, or map
mutation authority.

`field.interact` receives `(nextFn, mapId, tileX, tileY, facing, context)`
for an A-button field interaction, before the vanilla object/sign lookup.
`context.message(text)` adds a short field status line; `context.setFlag(id)`
and `context.setVar(id, value)` persist u16 save-state values for an active
session. The context intentionally exposes no filesystem, arbitrary world, or
rendering access.

`field.wildEncounter` receives `(nextFn, encounter, mapId, tileX, tileY)` after
the stock encounter roll and before its battle begins. It may call `nextFn` with
the original or a replacement `{species=..., level=..., slot=...}` record, or
omit it to cancel the encounter. Species and level are validated at the live
battle boundary; replacement levels must be integers from 1 through 100.

`field.warp` receives `(nextFn, destination, sourceMapId, tileX, tileY)` for a
stock warp tile. `destination` is `{mapId=..., warpId=...}`; a hook may delegate
with a replacement destination or omit `nextFn` to suppress the warp. The live
host accepts only existing imported map ids and u8 warp ids, so this seam can
redirect maps without inventing unverified map data.

Save safety is defined by `src/core/ModSaveCompatibility.lua`. Each manifest
declares `saveImpact = "cosmetic"` or `"gameplay"` (the conservative default).
An exact profile loads normally; cosmetic differences load with a visible
classification; any gameplay mismatch rejects unless the caller supplies an
explicit migration for that exact saved-to-active profile pair. The current
game host has no migration executor, so it rejects a migration-required save
rather than loading it without applying that migration.

`src/core/ModSaveProfileCodec.lua` persists that profile as a deterministic
`FRMP` sidecar appended after the complete `SaveFileCodec` buffer. This leaves
all FireRed sectors untouched and accepts old saves with no sidecar. A host
should call `extract` before decoding the base save, compare the returned
profile to the active profile, then call `attach` when writing. `main.lua`
now does this for its active runtime profile and preserves the
decoded base buffer for the next alternating-slot save. Migration execution
remains the host's explicit responsibility.

The game keeps one rolling `firered_recomp.backup.sav` before replacing its
primary save and automatically uses it when the primary is missing or corrupt.
It does not bypass an incompatible gameplay-mod profile or a required migration.

```lua
local Registry = require("src.core.ModRegistry")
local mods = Registry.new()
mods:registerNamespace("moves", { semantics = "deep", base = importedMoves })

assert(mods:apply({ id = "example-balance", api = 1, priority = 0 }, function(mod)
  mod:content("moves"):patch(100, { power = 70 })
  mod:content("moves"):register(900, { name = "CUSTOM MOVE", power = 60 })
end))

local effectiveMoves, owners = mods:resolve("moves")
```

Namespaces use one of two explicit semantics:

- `record` replaces whole records. Registering an occupied id is an error;
  use `override` when that is intentional.
- `deep` composes keyed table fields with `patch`. Arrays replace as a whole.
  Use `Registry.DELETE` in a patch to remove one keyed field.

Enabled contributions resolve in ascending `priority`, then lexical mod id,
then source order within a mod. This is independent of filesystem order.
`resolve` returns a separate table and an id-to-last-writer provenance map.

The runtime now discovers `mods/` packages and executes their constrained
entrypoints. Gameplay-profile changes require the explicit compatibility
decision described above; new integrations must preserve deterministic
ordering, rollback, and that save-safety boundary.

For behavior extensions, `src/core/ModHooks.lua` provides a similarly pure
around-call chain. Hooks resolve by ascending priority, then mod id, then
registration order; a callback receives `nextFn` and may transform arguments
or results, or intentionally short-circuit a call. A hook may call `nextFn`
at most once, protecting vanilla side effects from accidental duplication.
Consumers should expose narrow named seams (for example `battle.damage`) and
keep their existing implementation as the vanilla function.

The first live seam is `battle.resolveMove`: pass a `ModHooks` instance as
`hooks` when creating `BattleEngine`. A wrapper receives
`(nextFn, engine, attackerSide, moveSlot, events)`. Calling `nextFn` delegates
to the exact canonical resolver; omitting hooks leaves battle behavior
unchanged.
