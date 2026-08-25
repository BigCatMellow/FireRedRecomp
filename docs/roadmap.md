# FireRed ReComp: End-to-End Roadmap

## Objective

Create a native desktop/mobile recreation of **Pokémon FireRed (US v1.0)**
that follows the same model as Gen1Recomp:

- The player supplies a legally obtained, verified ROM on first launch.
- An importer reads the ROM into a private generated cache; no ROM is
  bundled or retained.
- Gameplay runs in a native runtime, not through an embedded GBA emulator.
- Modding, modern display options, save management, input remapping, and
  accessibility are first-class engine features.

The supplied FireRed disassembly is a reference and asset/data crosswalk. It
does **not** replace the ROM-verification/import path required for a public
project.

## What this is—and is not

This is not a skin conversion of Gen1Recomp. FireRed runs on GBA hardware and
has a different display format, save layout, map model, scripting system,
battle system, and progression set. Gen1Recomp provides useful product and
engine patterns, but its Gen 1 gameplay implementation cannot simply be
pointed at FireRed data.

The right technical target is a new sibling engine, for example:

```
Pokemon-ReComp/
  firered-recomp/
    src/           native runtime
    import/        verified-ROM importer and cache writer
    data/          schemas, defaults, generated-data readers
    assets/        engine-owned art only
    mods/          examples and test mods
    tests/         headless and replay tests
```

## Scope decisions to lock before implementation

| Decision | Recommended first-release answer |
| --- | --- |
| Base game | FireRed US v1.0 only |
| LeafGreen | Later importer variant, after FireRed parity |
| Platform/runtime | LÖVE2D/native Lua, matching the current product model |
| Display | 240×160 native canvas, scalable to arbitrary windows |
| Pokémon data | FireRed's normal Gen 3 National Dex data, gated by story exactly as FireRed does |
| Link play | Local deterministic link only after single-player parity |
| Wireless/Mystery Gift | Out of first release |
| Cheats/debug tools | Developer-only until save/link safety is proven |
| Mods | API designed from day one; public registry after parity |

These boundaries prevent the project from becoming “FireRed, LeafGreen,
Emerald, online multiplayer, and a randomizer” before the title screen works.

## Phase 0 — Charter, repository, and parity contract

**Model/effort:** Sonnet, medium. Boilerplate, config, CI wiring — low
ambiguity.

Create the project before porting mechanics.

1. Create a standalone repository and CI pipeline.
2. Record the exact supported ROM SHA-1 and revision policy.
3. Define what “parity” means: observable game behavior, not byte-for-byte
   emulation of GBA internals.
4. Establish a behavior ledger linking each runtime subsystem to FireRed
   source files, data, and automated checks.
5. Define save migration/versioning from the first save format.
6. Set contribution rules: no ROMs, generated caches excluded from git,
   every importer extraction cross-checked against the reference game.

**Exit criterion:** a clean checkout builds, launches, verifies a supported
ROM, creates an empty cache, and runs the test suite in CI.

## Phase 1 — ROM importer and canonical data model

**Model/effort:** Opus, high. Wrong schema choices here propagate through
every later phase; decoding/validation logic rewards careful reasoning.

Build the bridge from ROM/disassembly concepts to engine data. This is the
foundation for every later system.

### Importer responsibilities

- Verify ROM identity before parsing.
- Decode text/charmap data and control codes.
- Decode GBA LZ77-compressed graphics, palettes, tilemaps, sprites, music,
  cries, and sound effects.
- Extract maps, layouts, tilesets, connections, warps, object events,
  trainers, encounters, items, species, moves, evolutions, and scripts.
- Preserve source addresses/labels in generated metadata for debugging.
- Generate a compact, versioned cache that can be rebuilt safely.

### Data schemas to establish

- `pokemon`, `moves`, `abilities`, `items`, `types`, `natures`, `trainers`
- `maps`, `layouts`, `tilesets`, `encounters`, `warps`, `objectEvents`
- `scripts`, `messages`, `flags`, `vars`, `quests`, `decorations`
- `music`, `sfx`, `cries`, `animations`, `palettes`, `sprites`
- `saveDefaults`, `regionalDex`, `nationalDex`, and story gates

### Required validation

- Counts and identifiers match the ROM/disassembly.
- Randomly sampled decoded maps and sprites match reference screenshots.
- Every extracted script target resolves.
- Every map connection, warp, trainer, and item reference is valid.

**Exit criterion:** import completes deterministically and produces a
read-only data viewer capable of displaying every map, species, move, and
trainer record.

## Phase 2 — GBA-native rendering, input, and scene runtime

**Model/effort:** Opus, high (xhigh for the layer-composition/task-scheduler
core). Layer priority, affine transforms, and the task scheduler are the kind
of subsystem that's expensive to redesign later.

Gen1Recomp's 160×144 Game Boy renderer is not reusable as the final renderer.
Build a 240×160 GBA-oriented presentation layer.

### Engine work

- 240×160 virtual canvas with integer and arbitrary-window scaling.
- 4bpp/8bpp tiled backgrounds, palettes, transparency, affine-capable
  transforms where FireRed uses them, and sprite/OAM-style composition.
- Layer priority, window masks, blend/fade effects, weather, and palette
  animation.
- Text windows, fonts, text speed, message control codes, and input repeat.
- Scene stack and task scheduler compatible with the game’s callback/task
  style without reproducing GBA memory registers.
- Audio mixer with FireRed sequence/music, SFX, cries, loops, and fades.
- Controller, keyboard, touch, pause, screenshots, and display settings.

### Early visual target

Render the title screen, Oak intro, and one static Pallet Town screenshot
from imported assets at correct layer order and palette behavior.

**Exit criterion:** screenshots can be compared against the reference game
at representative scenes, with a clear discrepancy report rather than manual
guessing.

## Phase 3 — Playable vertical slice

**Model/effort:** Sonnet, medium–high (Opus, high, for the script interpreter
core). Movement/collision/camera is well-trodden game-engine work; the
interpreter's command-dispatch design is worth the upgrade.

Do not attempt all maps or all battle mechanics first. Prove the entire game
loop in a small path:

```
Boot → new game → Oak intro → bedroom → Pallet Town → Route 1
→ first wild battle → catch/defeat → save → reload
```

### Systems required

- New-game naming and initial flags/variables.
- Player movement, collision, ledges, grass, doors, warp transitions, and
  camera behavior.
- Object-event spawning, facing, movement, interaction, and dialogue.
- Basic script interpreter: message, choice, flag/var operations, movement,
  warp, give item, give Pokémon, trainer trigger, fade, and callback.
- Party model, Pokédex ownership/seen data, bag, money, and PC stub.
- Wild encounter selection and a minimal single battle.
- Save/load with schema versioning and corruption-safe writes.

**Exit criterion:** a fresh save can complete this path repeatedly without
desyncing flags, party state, map state, or saves.

## Phase 4 — Full Gen 3 battle engine

**Model/effort:** Opus, xhigh for the core damage/turn-order rules engine
(Fable worth considering for that core design pass); Sonnet, medium, for
UI/animation plumbing. Highest-risk isolated subsystem in the roadmap —
deterministic rules and edge cases (multi-turn moves, forced switching) are
exactly where a bad first design costs the most rework.

Battle parity is the largest isolated gameplay workstream. Implement it as a
deterministic rules engine with a UI shell around it.

### Core battle model

- Gen 3 stats, experience, level-up, natures, abilities, held items, gender,
  friendship, status, and volatile battle state.
- Physical/special is type-based in FireRed, not the later per-move split.
- Damage, accuracy, critical hits, STAB, type chart, priority, switching,
  targeting, PP, Struggle, fainting, capture, and run logic.
- Move-effect dispatcher for FireRed's move set, including multi-turn moves,
  weather, screens, trapping, stat stages, and forced switching.
- Trainer AI, battle facilities that FireRed actually uses, and scripted
  battles.
- Double-battle-capable architecture even if most story battles are singles;
  this prevents a later Sevii/link feature rewrite.
- Battle animation event stream separate from the rules engine.

### Test strategy

- Golden tests for formula edge cases and move effects.
- Deterministic seeded battle replays.
- Differential tests against reference saves/screens where practical.
- Fuzz tests for invalid targets, fainting mid-turn, forced replacements, and
  save/load during every legal battle phase.

**Exit criterion:** the early-game gyms, rival battles, catching, evolution,
and a stress matrix of all supported moves/species complete without known
rules divergences.

## Phase 5 — Overworld, maps, and field systems

**Model/effort:** Sonnet, medium. High-volume, repetitive per-map/per-tile
logic — scale-out work, not deep design work.

Scale the vertical-slice world engine to the complete region.

- Import and render every map, connection, layout, tileset, and map script.
- Implement map/object templates, hidden items, signs, trainers, cut trees,
  rocks, strength puzzles, surf, waterfalls where relevant, and field effects.
- Implement all field moves and their story gates: Cut, Flash, Fly, Strength,
  Surf, and Rock Smash.
- Implement bike modes, running shoes, fishing, Itemfinder, Repel, daycare,
  breeding, Safari Zone, and the Game Corner.
- Implement time-free FireRed map behavior, dynamic map changes, and
  postgame world-state edits.
- Build map-walk and warp-graph tests: every legal connection reaches a valid
  target, and every story-critical map remains reachable.

**Exit criterion:** a scripted test player can traverse Kanto's required
progression path from Pallet Town through the Elite Four without a missing
map, blocked script, or invalid warp.

## Phase 6 — Menus, inventory, and progression UI

**Model/effort:** Sonnet, medium. UI/state-machine work with well-understood
patterns.

Port the whole player-facing operating system, not just battles.

- Start menu, Bag pockets, PC storage, party menu, summary, Pokédex, Town
  Map, Trainer Card, options, save, and Hall of Fame.
- Move learning/forgetting, TM/HM use, item teaching, evolution scenes, and
  trading evolution architecture.
- Shops, marts, Pokémon Centers, move tutors, name rater, move deleter,
  daycare, and in-game trades.
- Badges, key items, quest flags, National Dex, Fame Checker, and help/menu
  context.
- Accessibility and modern UI hooks must remain optional presentation layers;
  stock FireRed interaction must be fully playable first.

**Exit criterion:** a player can finish the game without developer tools or
unimplemented-menu fallbacks.

## Phase 7 — Story, scripted content, and cutscenes

**Model/effort:** Sonnet, medium, for per-scene scripts; Opus, high, for the
initial script-command-set architecture pass. Bulk of the phase is
content-shaped; the interpreter's command surface deserves more care once,
then reuse.

The script interpreter becomes the focus here.

- Cover all script commands used by FireRed before hand-patching individual
  scenes.
- Implement trainer sight/approach, map callbacks, object movement scripts,
  camera pans, fades, sound/music cues, and multichoice menus.
- Run story checkpoints in order: Oak parcel, each Gym, Rocket arcs, Silph,
  Pokémon Tower, Safari/Surf, Cinnabar, Giovanni, Victory Road, Elite Four,
  and champion sequence.
- Add a checkpoint save corpus. Each checkpoint has expected map, party,
  flags, inventory, music, and available exits.

**Exit criterion:** a clean new game reaches credits with no manual state
edits and no story skip required.

## Phase 8 — Audio, polish, and presentation parity

**Model/effort:** Sonnet, low–medium. Mostly integration and tuning against
reference behavior.

- FireRed music sequence playback, instrument banks, SFX, cries, loops,
  transitions, and volume settings.
- Battle/field/UI animations, screen effects, weather, blending, and palette
  fades.
- Trainer art, Pokémon sprites, overworld sprites, tiles, menus, and region
  maps imported from the player ROM.
- Modern widescreen/HD features only after the stock 240×160 view is correct.
- Performance budget for low-end desktop/mobile hardware and cache warmup.

**Exit criterion:** reference playthrough comparison shows no major missing
audio/visual system, and optional enhancements can be disabled to retain a
faithful presentation.

## Phase 9 — Postgame, Sevii Islands, and secondary modes

**Model/effort:** Sonnet, medium. Same shape as Phase 5 — scaled-out content
work on an established architecture.

Keep this after the credits path so the first release is not blocked by the
long tail.

- One, Two, Three, Four, Five, Six, and Seven Islands.
- National Dex unlock flow, Celio quest chain, Ruby/Sapphire delivery,
  altered encounters, and postgame trainer/world changes.
- Trainer Tower, Union Room prerequisites, records, Mystery Gift stubs, and
  other secondary content, prioritized by offline single-player value.
- Link/trading/battling only after deterministic local save and battle
  behavior is proven; wireless distribution is a separate product decision.

**Exit criterion:** all offline FireRed single-player content is completable
from a normal save.

## Phase 10 — Mod API, compatibility, and release engineering

**Model/effort:** Opus, high. API surface and compatibility guarantees are
hard to change post-release; worth getting right before locking.

- Registry-based, versioned APIs for data patches, scripts, maps, sprites,
  UI, audio, and battle hooks.
- Content ownership/conflict rules, deterministic load ordering, and a
  headless mod SDK.
- Save compatibility matrix: base game, disabled mods, enabled cosmetic mods,
  and gameplay-mod migration/rejection behavior.
- CI for importer fixtures, unit tests, replay tests, screenshot tests,
  package validation, and clean-install smoke tests.
- Launcher/import UX, crash reporting/log export, recovery backups, release
  signing/checksums, and documentation.

**Exit criterion:** a new player can import, play, mod, update, diagnose a
problem, and preserve saves without manual filesystem work.

## Dependencies and critical path

```
ROM importer + schemas
        ↓
GBA renderer + task/scene runtime
        ↓
vertical slice (movement + script + basic battle + save)
        ↓
full battle engine ─────────────┐
        ↓                       │
complete overworld + scripts ───┼──→ credits-path parity
        ↓                       │
menus/progression ──────────────┘
        ↓
postgame → link/secondary modes → public mod API/release polish
```

The importer, renderer, battle rules, script interpreter, and save format are
the critical path. UI polish and optional HD features should never block them.

## Workstreams that can run in parallel after Phase 1

| Workstream | Can begin after | Deliverable |
| --- | --- | --- |
| Asset decoder | ROM verification | graphics/audio/cache fixtures |
| Renderer | tile/palette extraction | title/map screenshot parity |
| Battle rules | species/move extraction | deterministic simulator |
| Script VM | command extraction | headless event tests |
| Map runtime | map/layout extraction | walkable Pallet vertical slice |
| Save system | data schemas | versioned save/load tests |
| Product UX | renderer/input base | launcher/options/accessibility |

## Highest-risk areas and mitigations

| Risk | Mitigation |
| --- | --- |
| Treating a GBA decompilation as desktop-ready code | Use it as a behavior/data specification; write a native runtime deliberately. |
| Importer errors that look like gameplay bugs | Preserve source metadata and test every extracted record/map against fixtures. |
| Battle rules becoming a monolith | Keep pure deterministic rules separate from animation/UI. |
| Story progress softlocks | Maintain automated checkpoint saves and map/warp reachability tests. |
| Save format churn | Version saves from day one; make migrations explicit and reversible. |
| Scope creep into Emerald, online, or HD remakes | Ship FireRed's credits path first; gate later work behind separate milestones. |
| Mod conflicts | Define registry ownership and conflict behavior before public mod support. |

## Practical milestone order

1. **Importer proof:** verified FireRed ROM → inspectable generated data.
2. **Visual proof:** title/Oak/Pallet render at correct GBA composition.
3. **Playable proof:** new game → Route 1 → wild battle → save/reload.
4. **Battle proof:** gym-ready Gen 3 single battles and captures.
5. **Kanto proof:** complete walkable story route and field moves.
6. **Credits proof:** full FireRed main story from a clean save.
7. **Complete proof:** Sevii/postgame and all offline single-player systems.
8. **Release proof:** mod API, updates, package verification, and clean-install
   playthrough.

## Definition of “ready to ship 1.0”

- A verified FireRed ROM imports without distributing game content.
- A clean save can reach credits and complete offline postgame content.
- No known crash, save-corruption, or progression-softlock bugs remain.
- Battle, map, script, and save regression suites are green.
- Stock presentation is faithful at 240×160; enhancements are optional.
- The installer, importer, save recovery, logs, and documentation work on a
  clean machine.

## Follow-on: Emerald

Emerald should be planned only after this project proves the GBA runtime. Its
renderer/importer foundations can be shared, but it is not a map pack:
Hoenn, double battles, contests, secret bases, PokéNav, weather, Battle
Frontier, and Emerald-specific scripts form a second game-scale content and
mechanics project.
