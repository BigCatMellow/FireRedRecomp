# Independent review: north-facing Oak Parcel/Dex presentation

- Record role: `REVIEW`
- Status: `PASS`
- Reviewed revision: `2d8c3221775044a54668683e500055307fe4d20b`
- Active task: `work/tasks/oak-parcel-dex-presentation-north.md`
- Reviewer scope: existing task acceptance and repository invariants only

## Verdict

`PASS`

The bounded runtime-integration package satisfies the active Oak north task criteria. This verdict closes only this reviewed leaf package; it does not mark Phase 3 complete.

## Independent findings

1. **Exact revision / boundary** — comparison from request revision `56f954e56cc632d993ecbc6c25f934d8fbfb4726` to reviewed revision shows one commit and only `main.lua` changed (`+220/-12`). `main.lua` is explicitly within the task MAY CHANGE boundary. No ROM, cache, extracted asset, generic script interpreter, Mart UI, save codec, or battle-rule file entered the implementation commit.
2. **Guard and fallback** — the runtime constructs the existing `OakParcelDexPresentation` only for Oak local id 4 in Oak's Lab, then passes map, exact player position/facing, Mart scene, Lab scene, Parcel presence, and a non-mutating five-Poké-Ball capacity preflight into `begin()`. The presenter itself enforces Lab `(4,3)`, player `(6,4)` facing north, Oak present, Mart scene 1, Lab scene 5, Parcel present. If `begin()` returns no command, interaction falls through to the pre-existing interaction path rather than committing Parcel/Dex state.
3. **Source-derived sequence** — the reviewed presenter contains the source-locked 15 ROM text pointers and north-only sequence. Runtime wiring displays those pointers, spawns the rival from the real Lab object template, performs six-step rival arrival/exit, player facing changes, Oak up/left and right/down movement, bounded walk-in-place interval, then prop 9 / delay 10 / prop 10 / delay 25. Temporary rival/props are removed only from the live NPC list, preserving persistent hide flags.
4. **Input lock** — player and NPC movement tasks now explicitly stop while the Oak presenter reports input locked. Presenter state remains active through text/movement and unlocks only on DONE/FAILED. A-button advancement is handled by the presenter while active.
5. **Durable mutation** — the runtime's `commit` callback delegates to `ViridianParcelStory:completeLabParcelReturn(...)`; the pure presenter invokes it only after terminal rival-exit movement. Focused tests demonstrate no commit during preflight/text/movement, one commit at terminal completion, no duplicate reward after DONE, and failure without terminal reward when the commit fails.
6. **Required evidence** — Local Worker Bridge run `34547647645` on `firered-mint` verified FireRed US v1.0 SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`; patch target validation and application passed; `tests/oak_parcel_dex_presentation_test.lua` passed 24/24; no-ROM `scripts/test_all.sh` passed 121 test files; verified-ROM `scripts/test_all.sh` passed 121 test files including `phase3_exit_path_rom_test: 12 passed`; `scripts/runtime_natural_capture_replay.sh` passed the live Oak presentation and fresh-process restart with `dex=true`, `labScene=6`, `martScene=2`, Parcel quantity 0 and persisted party/capture state.

## Remaining scope

The task explicitly omits audio/fanfare/BGM, Fame Checker, and other Oak orientations; this review does not add them as requirements. Phase 3 remains governed by `work/roadmaps/CAPABILITY_CHECKLIST.md` and its parent exit proof.

## Next allowance

Orchestrator may treat this bounded Oak north presentation leaf as independently passed, re-read the Phase 3 parent gate/checklist, and dispatch only the smallest remaining unproven Phase 3 acceptance item. It must not infer Phase 3 completion from this review alone.
