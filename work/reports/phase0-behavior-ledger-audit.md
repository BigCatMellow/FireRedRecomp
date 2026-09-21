# P0-01 behavior-ledger evidence audit

Status: research in progress; not ready for acceptance or ledger edits.
Task: [P0-01-DISCOVERY](../tasks/phase0-behavior-ledger-audit.md).

## Pin and method

All runtime/test/ledger findings below use
`eac7d6985e6bbf1c33c3c4b6e9c338c08f3d0990`, examined in an immutable
`git archive` snapshot. Public main independently resolved to that revision
at intake; research dispatch is `12c5d8e`. Concurrent save-counter and CI
drafts are excluded. Public reference source is pinned to
`c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

Evidence classes are deliberately separate: source definitions establish the
reference basis; runtime call sites establish wiring; test bodies establish
what assertions exist; recorded execution and independent reviews establish
only their stated executed/accepted scope. No new test, full-suite, ROM or
media execution is performed for this prose audit.

## Confirmed material finding: PC-overflow negative is stale

The fifth ledger row says “PC overflow remains incomplete.” This is too broad
at the pinned revision. Commit `103c5e1` wired the caught-outcome branch in
`main.lua:4521` through `CaptureRewards.giveMonToPlayer` and a session-owned
`PcBoxes.fromStorage` view (`main.lua:350–381`, `src/core/PcBoxes.lua:42`).
The containers directly back saved party and PokemonStorage state. Schema 2
serializes all nine PC chunks (`src/core/SaveFileCodec.lua:680–813`).

The reference routing exists in pinned `src/pokemon.c:3686`
(`GiveMonToPlayer`) and `:3708` (`SendMonToPC`); the implemented decision layer
is `src/core/CaptureRewards.lua:33`. Existing
[capture routing fixtures](../../tests/capture_rewards_test.lua) assert party
preference, full-party overflow, PC PP restoration, the next available box,
all-full failure, Dex flags and ball consumption.
[Storage fixtures](../../tests/pc_boxes_test.lua) exercise the backing view;
[codec fixtures](../../tests/save_file_codec_test.lua) roundtrip a boxed
record/current box/names/wallpapers and validate corruption fallback. Their
execution at `63592c3` is covered by the accepted
[save-contract review](../reviews/2026-09-21-save-version-contract-review.md)
(63/0 codec, 13/0 roundtrip, 149-file no-ROM suite). This is not a newly
executed full-party live-capture replay.

Important evidence limits: `tests/phase3_exit_path_rom_test.lua:124` injects a
ball and writes a caught record to party slot 2; it does not test PC overflow
or the live caught-outcome handler. The
[natural-capture task](../tasks/natural-capture-runtime-replay.md) describes
party count 2 and explicitly excludes canonical first-visit Mart/Parcel
progression; its report is not a dedicated PC-overflow acceptance receipt.
An independently accepted end-to-end full-party capture → PC → restart
replay has not been located in this audit and remains UNKNOWN. Correct the
blanket negative to bounded wiring/serialization evidence, not “PC complete.”

## Remaining audit checkpoint

The existing nine rows are: ROM identity; species/moves/types/items/trainers;
map data/rendering; scripts; wild/capture; tutorial trainer battle; Pain Split;
saving/loading; rendering/input/scenes. All must receive a final source,
runtime, test and acceptance mapping before this report is ready.

Further confirmed distinction for the script row: unsupported decoded opcodes
raise at `src/core/ScriptInterpreter.lua:193`, but supported instructions with
absent world callbacks can produce no side effect. `DialogueRunner:buildWorld`
(`src/core/DialogueRunner.lua:101`) wires dialogue, object removal and Mart
pausing, not a general world-command implementation. Its header contains old
“one exception” prose, so actual callbacks, not comments alone, must determine
the proposed ledger wording.

No ledger, runtime, tests, workflows, phase status or coordination changed.
The final recommendation will be at most one bounded ledger-only package;
missing behavior/evidence must remain separate and independently reviewed.
