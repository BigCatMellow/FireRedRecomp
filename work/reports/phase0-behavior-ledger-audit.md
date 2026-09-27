# P0-01 behavior-ledger evidence audit

Status: research complete; exact-report independent review required. No ledger
edit or phase acceptance is claimed.
Task: [P0-01-DISCOVERY](../tasks/phase0-behavior-ledger-audit.md).

## Pin and method

The nine-row map uses repository revision
`eac7d6985e6bbf1c33c3c4b6e9c338c08f3d0990`, read from an immutable
`git archive` snapshot. Public main resolved to that revision at intake;
research dispatch was `12c5d8e`. Reference source is the local public
decompilation at `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
Project code line numbers below refer to the audit pin, not mutable main.
Relative links provide repository navigation; revisions qualify the claims.

Evidence classes are separate:

- **Source** identifies reference definitions/data, not proof of a complete port.
- **Runtime** identifies actual code and call sites, not merely imports.
- **Tests** describes inspected assertions, separating synthetic fixtures and
  opt-in ROM checks. Presence is not execution.
- **Receipts / limits** identifies recorded execution and independent acceptance
  only within their stated scopes. UNKNOWN means proof was not located, not
  proof that behavior is absent.

No tests, full suite, ROM, media capture or replay were executed by this audit.
Existing reviews were read; their logs were not re-fetched or tests reproduced.
Source/history/path/diff checks alone were performed. Between accepted Pain
Split `a739ddc` and the audit pin, a path-limited history comparison over
`import`, `src`, `main.lua`, `tests`, and `scripts` changes only the two save
test files from the independently accepted save contract. The earlier
verified-ROM receipt therefore evidences execution of unchanged ROM tests;
it does not independently accept every subsystem represented in that suite.

Later accepted change, separate from this pin: reconciliation `9c81b90`
accepts rollover implementation `aec377a` after the
[independent rollover review](../reviews/2026-09-23-save-counter-rollover-review.md).
That package already corrects the live ledger's save-counter wording.
Row 8 retains the historical pin; a successor must preserve the accepted
newer row, not restore the old rollover limitation. No other post-pin runtime
or draft inventory result is promoted into this audit's evidence.

## Existing nine rows

### Importer — row 1: ROM identity and import boundary

- **Source:** supported US v1.0 SHA-1
  `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc` in
  [RomImporter](../../import/RomImporter.lua), with symbol/layout citations and
  hash-keyed addresses in [RomAddresses](../../import/RomAddresses.lua).
  The reference [checksum file](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/firered.sha1)
  provides target identity; address metadata is a separate import concern.
- **Runtime:** [main](../../main.lua) `loadMapFromRom`:2984 calls
  `RomImporter.verify`, refuses failure before decoding, then resolves the
  hash-keyed address table before loading map/assets. Verification uses the
  LÖVE hash path or the plain-Lua external SHA helper.
- **Tests:** [rom_importer_test](../../tests/rom_importer_test.lua) asserts only
  supported-table presence/name and missing-file refusal. Its LÖVE hash stub
  is not SHA verification. ROM integration tests call real verification.
- **Receipts / limits:** the [title-entry review](../reviews/2026-09-11-phase3-title-oak-entry-review.md)
  records supported-SHA verification and live boot at `8bdbda9`; the
  [Pain Split review](../reviews/2026-09-20-pain-split-implementation-review.md)
  records the private SHA gate and 149-file verified-ROM suite at `a739ddc`,
  run `35493728001`. “Wired at boot” is supported. The smoke test alone
  cannot prove hashing; exhaustive wrong-dump/revision refusal UX acceptance
  is UNKNOWN. No additional ROM support is implied.

### Importer — row 2: species, moves, types, items, trainers

- **Source:** [SpeciesInfo](../../import/SpeciesInfo.lua),
  [BattleMove](../../import/BattleMove.lua), [TypeChart](../../import/TypeChart.lua),
  [Item](../../import/Item.lua), and [Trainer](../../import/Trainer.lua) cite
  reference structures and tables: `include/pokemon.h` (SpeciesInfo:208,
  BattleMove:238), `include/item.h:8`, `include/battle.h:116`,
  `src/data/pokemon/species_info.h`, `src/data/battle_moves.h`,
  `src/data/items.h`, `src/data/trainers.h`, and the type table in
  `src/battle_main.c`.
- **Runtime:** main:1176–1181 builds the battle catalog; wild/rival/trainer
  battle constructors and session-bag consumers use it.
  [DataViewer](../../src/core/DataViewer.lua):18 exposes species, moves,
  trainers and maps, with main's describe call at 3224. Items/types are
  not separate viewer categories.
- **Tests:** [species_integration_test](../../tests/species_integration_test.lua)
  checks selected known records. [full_sweep_validation_test](../../tests/full_sweep_validation_test.lua)
  loops species/moves/trainers for decoding and sanity bounds; its map set
  contains four exercised maps, not all Kanto. Both skip without `POKEPORT_ROM`.
- **Receipts / limits:** the verified suite receipt above supports execution
  of these unchanged tests. The canonical checklist records Phase 1 DONE,
  but a dedicated independent receipt proving every viewer record reachable
  is UNKNOWN in the inspected records; this audit does not revoke or
  re-certify that status. Decoded records do not prove corresponding move/item
  mechanics, all trainer layouts or all-world traversal. Qualify “wired to
  viewer, battles, and menus” with the specific consumers.

### Map/script — row 3: map data and rendering

- **Source:** `include/global.fieldmap.h` defines MapLayout:91, MapEvents:165,
  MapConnections:185 and MapHeader:191. Project
  [MapHeader](../../import/MapHeader.lua), [MapLayout](../../import/MapLayout.lua),
  [MapEvents](../../import/MapEvents.lua), [MapConnections](../../import/MapConnections.lua)
  and [MapCompositor](../../import/MapCompositor.lua) decode those tables;
  compositor layer discussion cites `src/field_camera.c:DrawMetatile`.
- **Runtime:** main `loadMap`:2257 resolves map/layout/events; warp and
  connection paths reload maps; `loadMapObjectEvents`:1781 builds NPC state.
  [CameraViewport](../../src/core/CameraViewport.lua) is called at main:518;
  map/NPC/player drawing shares its transform at main:4944/4957.
- **Tests:** [map_generalization_test](../../tests/map_generalization_test.lua)
  is opt-in ROM coverage of Route 1 and Player's House 1F dimensions and
  nonblank compositing. [map_scripts_test](../../tests/map_scripts_test.lua)
  is synthetic pointer-table decoding, not live hook dispatch.
  [camera_viewport_test](../../tests/camera_viewport_test.lua) and
  [phase2_camera_viewport_integration_test](../../tests/phase2_camera_viewport_integration_test.lua)
  cover geometry and wiring. The ledger's map-test glob obscures these
  different assertion strengths.
- **Receipts / limits:** [camera review](../reviews/2026-09-13-phase2-gba-camera-viewport-review.md)
  accepts `4c5456f3`, focused checks, both 125-file suites and Route 1 runtime
  camera motion, run `34753297372`. The
  [Phase 3 exit review](../reviews/2026-09-12-phase3-complete-runtime-exit-review.md)
  accepts a continuous bounded overworld route. Neither proves every map,
  event, connection, sprite/background occlusion case or retail pixel parity.
  “Playable map/camera path” is defensible only with those boundaries.

### Map/script — row 4: script execution

- **Source:** [ScriptBytecode](../../import/ScriptBytecode.lua) cites
  `data/script_cmd_table.inc`, `src/script.c`, `src/scrcmd.c`, variable trainer
  argument layouts in `src/battle_setup.c`, and `data/scripts/std_msgbox.inc`.
- **Runtime:** [ScriptInterpreter](../../src/core/ScriptInterpreter.lua) steps
  instructions; main:2853 starts [DialogueRunner](../../src/core/DialogueRunner.lua),
  whose `buildWorld`:101 supplies message/reveal/lock/face/object-removal/Mart
  hooks. Separate bounded story controllers are not generic script dispatch.
- **Tests:** [script_interpreter_unit_test](../../tests/script_interpreter_unit_test.lua)
  uses synthetic bytecode and supplied callbacks for flags/vars, control flow
  and side effects. [script_interpreter_test](../../tests/script_interpreter_test.lua)
  opt-in ROM checks include Pallet's sign and Viridian's Mart script;
  [dialogue_runner_test](../../tests/dialogue_runner_test.lua) checks synthetic
  reveal/advance/pause behavior. The map-script test checks table shape.
- **Receipts / limits:** unchanged tests have the recorded suite execution
  above; whole generic-script runtime acceptance is UNKNOWN.
  `step`:193 raises for decoded `unimplemented` opcodes, and unsupported
  standard scripts raise too. However `callHook`:138 skips absent callbacks,
  and absent setters do nothing. `buildWorld` has no session flag/var, generic
  warp, give-mon/item, movement or trainer-battle hooks. “Unsupported opcodes
  explicit” must not imply every decoded operation is live or fails loudly.
  These are inspected wiring limits, not new implementation authority.
  Header comments/counts are not a support matrix.

### Battle/capture — row 5: wild encounters and capture persistence

- **Source:** [WildEncounterSelector](../../src/core/WildEncounterSelector.lua)
  and [WildEncounterTrigger](../../src/core/WildEncounterTrigger.lua) cite
  `src/wild_encounter.c` (ChooseWildMonIndex_Land:71,
  DoGlobalWildEncounterDiceRoll:348, StandardWildEncounter:355), encounter
  tables and two RNG streams. [CaptureRewards](../../src/core/CaptureRewards.lua):33
  follows [GiveMonToPlayer / SendMonToPC](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/pokemon.c#L3686).
- **Runtime:** main's completed-step path at 828 invokes encounter selection;
  `startWildBattle` consumes ROM catalog and save-backed party/bag state.
  Its caught-outcome branch at 4521 calls `giveMonToPlayer` at 4541.
  Session constructors at 350/381 use [PcBoxes.fromStorage](../../src/core/PcBoxes.lua):42;
  party/PC views back saved state. Schema 2 serializes nine PC chunks.
- **Tests:** [wild_encounter_selector_test](../../tests/wild_encounter_selector_test.lua)
  includes weighted/statistical and seeded checks;
  [wild_encounter_trigger_test](../../tests/wild_encounter_trigger_test.lua)
  checks completed-step behavior. [capture_rewards_test](../../tests/capture_rewards_test.lua)
  asserts party preference, PC overflow, PP restoration, next box, all-full
  failure, Dex and ball consumption. [pc_boxes_test](../../tests/pc_boxes_test.lua)
  checks backing storage; save tests cover boxed records/current box/names/
  wallpapers and corruption fallback. In contrast,
  [phase3_exit_path_rom_test](../../tests/phase3_exit_path_rom_test.lua):124
  injects a ball and writes the catch to party slot 2; it does not exercise
  the live caught handler or full-party overflow.
- **Receipts / limits:** `4f4f29ec` independently accepts live wild loss, not
  capture. [Natural-capture task evidence](../tasks/natural-capture-runtime-replay.md)
  describes purchase/capture/restart with party count 2; it is a task report,
  not a located dedicated independent full-party-PC receipt. It explicitly
  excludes canonical first-visit Mart/Parcel progression. The accepted save
  contract supplies no-ROM capture/storage/codec regression execution.
  An independently accepted full-party catch → PC → fresh-process reload
  remains UNKNOWN. Tall-grass/base encounter selection does not establish
  surfing/fishing, repel, rate modifiers or roamers.

The blanket “PC overflow remains incomplete” is stale: routing/backing-state
wiring and serialization exist since `103c5e1` and have component coverage.
Replace it with that bounded positive and missing end-to-end acceptance,
not “PC complete.”

### Battle/capture — row 6: tutorial trainer battle

- **Source:** [Oak's Lab scripts](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/data/maps/PalletTown_ProfessorOaksLab/scripts.inc#L333)
  dispatch `trainerbattle_earlyrival`; `src/battle_setup.c:900` sets FIRST_BATTLE.
  `src/battle_script_commands.c:1007/1200` and `data/battle_ai_scripts.s`
  supply tutorial accuracy/critical and AI rules. Trainer/party records are
  ROM data, not inferred from an encounter name.
- **Runtime:** [EarlyStory](../../src/core/EarlyStory.lua) supplies the bounded
  trigger/action and completion state; main `startRivalBattle`:1360 validates
  the lab record and constructs the battle. [EarlyRivalAI](../../src/core/EarlyRivalAI.lua),
  [EarlyRivalRewards](../../src/core/EarlyRivalRewards.lua), engine FIRST_BATTLE
  handling and the controller own battle/reward seams.
- **Tests:** [early_rival_battle_test](../../tests/early_rival_battle_test.lua)
  asserts first-move RNG/crit rules, selected AI branches, RUN refusal and
  reward/party mutation. [early_story_test](../../tests/early_story_test.lua)
  covers synthetic story state; [early_story_rom_test](../../tests/early_story_rom_test.lua)
  cross-checks records. These do not prove every starter/outcome and all
  presentation timing through normal runtime input.
- **Receipts / limits:** unchanged tests have the suite execution above.
  Phase 3's accepted continuous route establishes a playable early slice,
  not an exhaustive tutorial matrix. A dedicated independently reviewed
  all-starter/all-outcome live matrix is UNKNOWN. Main and EarlyStory
  explicitly abbreviate Oak's sequence and reuse limited battle presentation.
  Retain “bounded live slice,” distinct from general trainers and retail
  cutscene/visual parity.

### Battle/capture — row 7: bounded singles Pain Split

- **Source:** `BattleScript_EffectPainSplit` at `data/battle_scripts_1.s:1235`,
  `Cmd_painsplitdmgcalc` at `src/battle_script_commands.c:7674`, own-max clamp
  in `Cmd_datahpupdate:1744`, and effect-91 move #220 at
  `src/data/battle_moves.h:2863`. Exact source anchors and flags 18 are in
  the [independent review](../reviews/2026-09-20-pain-split-implementation-review.md).
- **Runtime:** [BattleEngine](../../src/core/BattleEngine.lua):859/1075 admits
  the literal effect and applies a frozen average, attacker then defender,
  each clamped to its own maximum. [BattleSceneController](../../src/core/BattleSceneController.lua):202
  consumes ordered HP/message events; main uses this engine/controller.
- **Tests:** [battle_engine_test](../../tests/battle_engine_test.lua) and
  [battle_scene_controller_test](../../tests/battle_scene_controller_test.lua)
  check formula, asymmetry, odd/equal HP, ordering, PP, RNG/admission isolation
  and messages. [phase4_pain_split_effect_rom_test](../../tests/phase4_pain_split_effect_rom_test.lua)
  checks the exact record when a verified ROM is supplied.
- **Receipts / limits:** exact `a739ddc` independent PASS records 237/0 engine,
  39/0 controller, both 149-file suites, ROM record 1/0 and configured headless
  replay (244/0 engine, 39/0 controller, 1/0 record), run `35493728001`.
  This row is already specific. Preserve its exclusions: no generic healing/
  zero-power admission, Protect/Substitute/Mirror Move, sure-hit/
  semi-invulnerability, excluded item/ability/status interactions, doubles/
  links or visible animation/timing parity. Headless replay is not a
  normal-input live LÖVE Pain Split demonstration.

### Save — row 8: saving and loading

- **Source:** [SaveFileCodec](../../src/core/SaveFileCodec.lua) and
  [SaveBlockLayout](../../src/core/SaveBlockLayout.lua) cite `src/save.c`,
  `include/save.h` and save structures. The `FRSV` wrapper and version policy
  are project-owned, not retail; the [save-format contract](../../docs/save-format.md)
  distinguishes both.
- **Runtime:** main `saveGame`:2425 encodes and writes a whole buffer through
  `love.filesystem.write`; load at 2445 decodes before replacing the session.
  Session state supplies party/storage plus modeled SaveBlock1/2 fields.
- **Tests:** [save_file_codec_test](../../tests/save_file_codec_test.lua)
  independently constructs historical schema 1, verifies current header/size,
  version/unknown/unwrapped refusal, truncation, nine PC-sector corruptions
  falling back to older content, and state/storage roundtrips.
  [save_load_roundtrip_test](../../tests/save_load_roundtrip_test.lua) compares
  all 57,344 bytes of the preserved prior slot and loaded state.
- **Receipts / limits:** [save-contract review](../reviews/2026-09-21-save-version-contract-review.md)
  accepts `63592c3`: 63/0 codec, 13/0 roundtrip and 149-file no-ROM suite;
  independent historical-fixture and discarded-prior-slot witnesses support
  fixture strength. Phase 3 separately accepts normal two-process save/reload.
  At the audit pin, version 1 is refused, field models are partial, and
  rollover/suffix limitations remain. The later accepted rollover correction
  changes only the counter limitation noted above. Suffix preservation,
  overwrite/refusal UX, filesystem interruption safety and retail-save import
  remain outside these acceptances. Codec fallback is not filesystem atomicity.

### Renderer/input/scene — row 9: rendering, input and scenes

- **Source:** [TitleScreen](../../import/TitleScreen.lua) and
  [OakSpeechScene](../../import/OakSpeechScene.lua) cite `src/title_screen.c`
  and `src/oak_speech.c`; [ObjectSprite](../../import/ObjectSprite.lua) cites
  object graphics structures/data and 1D tile mapping.
  [InputState](../../src/core/InputState.lua) follows `src/main.c:ReadKeys:296`
  and key bit values; [TaskScheduler](../../src/core/TaskScheduler.lua) follows
  `src/task.c:InsertTask:50` / `RunTasks:117`. These are selected ports, not a
  complete emulated GBA display/OAM/task system.
- **Runtime:** main builds scheduler/input at 704/711, samples input and ticks
  at 4434 onward, dispatches title/Oak at 4603/4622 and movement at 4642.
  NewGameFlow owns identity/session transitions; ViewportScale and camera
  handle distinct window-scaling and field-view concerns.
- **Tests:** [title_screen_test](../../tests/title_screen_test.lua) and
  [object_sprite_test](../../tests/object_sprite_test.lua) are opt-in ROM
  dimension/pixel-sample checks, not retail image comparisons.
  [viewport_scale_test](../../tests/viewport_scale_test.lua) checks integer
  scale/centering. The ledger omits directly relevant
  [input_state_test](../../tests/input_state_test.lua) (edges, 40/5-tick repeat),
  [task_scheduler_test](../../tests/task_scheduler_test.lua) (priority/ties,
  destruction, slot exhaustion), and
  [phase3_title_oak_entry_test](../../tests/phase3_title_oak_entry_test.lua).
- **Receipts / limits:** `8bdbda9` accepts title → Oak → identity → bedroom
  through normal input; `4f4f29ec` extends play/save/reload; `4c5456f3` accepts
  the field camera. The [Oak harness review](../reviews/2026-09-13-phase2-oak-reference-evidence-harness-review.md)
  accepts `0017727c` capture plumbing/repeat self-diffs and both 126-file suites,
  not retail-reference parity. Trusted reference comparison remains missing;
  visual/timing parity is UNKNOWN and Phase 2 stays IN PROGRESS. Keep this
  row partial while indexing its currently omitted input/scene evidence.

## Material coverage absent from the existing rows

Ordinary trainer parties and player replacement are neither the tutorial row
nor the Pain Split row. At the pin, main `startTrainerBattle`:1483 admits
one/two-foe ordinary no-item singles, party flags 0/1 and bounded AI tiers;
it rejects held-item layouts and doubles. [TrainerPokemonFactory](../../src/core/TrainerPokemonFactory.lua)
uses `src/battle_main.c:CreateNPCTrainerParty` and trainer party layouts;
[TrainerBattleOrchestrator](../../src/core/TrainerBattleOrchestrator.lua)
owns ordered foe settlement. BattleEngine, BattlePartyBridge and the scene
controller own message-gated legal save-backed replacements.

These are independently accepted leaves, not a claim of complete general
trainer battles:

| Accepted leaf | Exact review/evidence | Existing assertion owner |
| --- | --- | --- |
| No-item trainer construction | [f40c4021; run 34776145784](../reviews/2026-09-13-phase4-trainer-party-no-item-review.md), both 128-file suites | [Factory](../../tests/trainer_pokemon_factory_test.lua), [ROM layouts](../../tests/phase4_trainer_party_rom_test.lua): flags 0/1, reject 2/3 |
| Ordered foe replacement | [8533cf6a; run 34777072801](../reviews/2026-09-13-phase4-foe-only-multimon-review.md) | [Main-seam ROM fixture](../../tests/phase4_foe_only_multimon_rom_test.lua): Ben89, message gate, once-only reward, final-only flag, loss |
| Trainer player forced replacement | [8fd9a397; run 34783304717](../reviews/2026-09-13-phase4-player-forced-replacement-review.md) | [ROM fixture](../../tests/phase4_player_forced_replacement_rom_test.lua): legal bench, cancel retention, outgoing HP and save roundtrip |
| Trainer voluntary switch | [3140e267; run 34797894161](../reviews/2026-09-13-phase4-player-voluntary-switch-review.md) | [ROM fixture](../../tests/phase4_player_voluntary_switch_rom_test.lua): action order, stale/forged/cancel nonmutation, save roundtrip |
| Two-sided replacement state | [4a583b6a; run 34907113705](../reviews/2026-09-15-phase4-two-sided-replacement-state-review.md) | [State fixture](../../tests/phase4_two_sided_replacement_state_test.lua), [ROM settlement](../../tests/phase4_two_sided_replacement_state_rom_test.lua): queue, terminal and draw settlement |

Real-main seam tests intentionally configure sessions/battles; they are not
normal-input traversal through every trainer. Preserve per-leaf exclusions,
one/two-foe live limits, held items/doubles/AI/UI boundaries and the distinction
between trainer switching and separately proven wild/Oak draw settlement.
Full move/effect support has separate inventory/gates; this audit does not
infer it from decoded records or Pain Split acceptance.

## One proposed successor: ledger-only evidence correction

After independent acceptance of this report, compile one package whose sole
implementation path is `docs/behavior-ledger.md`. No task is self-dispatched.
Use the exact anchors above; preserve later accepted save wording and all
canonical phase states.

| Target row | Bounded correction |
| --- | --- |
| 1 ROM identity | Separate smoke-test coverage from real SHA/boot receipts; retain one supported ROM. |
| 2 Data catalogs | Name viewer/catalog consumers; qualify sanity sweep versus mechanics/full-world coverage. |
| 3 Maps | Replace glob-only evidence with representative assertions and bounded camera receipt. |
| 4 Scripts | Separate decoder/VM support from live callbacks; state absent-hook limits and UNKNOWN general acceptance. |
| 5 Wild/capture | Replace blanket PC-overflow negative with routing/backing/serialization evidence and UNKNOWN full-party live restart receipt; retain encounter/story exclusions. |
| 6 Tutorial | Keep bounded row; link owners and distinguish abbreviated presentation from general trainers. |
| New row adjacent to 6 | Add only “Bounded ordinary trainer parties and replacement,” using the five accepted leaves and their limits. |
| 7 Pain Split | Preserve wording/exclusions; add navigable source/review links if needed without broadening support. |
| 8 Save | Preserve accepted post-pin rollover update; retain schema/refusal, suffix/field and filesystem limits and exact reviews. |
| 9 Rendering/input/scenes | Add input/scheduler/title-entry/camera owners and receipts; distinguish self-diff from absent retail comparison. |

Documentation cannot close missing proof: full-party capture/PC/restart,
general script side effects and map-hook dispatch, exhaustive viewer/world or
tutorial runtime matrices, full battle effects, retail visual parity and live
filesystem failure safety need their own contracts/evidence if selected.
These limitations/UNKNOWNs are not additional implementation proposals.

## Handoff and scope audit

All nine rows are mapped; one material battle-row omission and the input/scene
evidence omission are bounded above. No ledger, runtime, tests, workflow,
coordination or capability status changed; no ROM/user save/media was accessed.
Only this report and its task evidence are authored. Local validation passed:
`git diff --check` and all 89 local link occurrences across these two files
resolve. The commit is restricted to these two paths. No new suite result is
claimed. An independent Reviewer must evaluate the exact report revision before
any ledger edit. Phase 0 remains open.
