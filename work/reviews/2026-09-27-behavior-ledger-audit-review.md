# P0-01 behavior-ledger audit — independent review

Verdict: **PASS** for the bounded research report only.

- Task: [P0-01-DISCOVERY](../tasks/phase0-behavior-ledger-audit.md).
- Reviewed report/task commit: `61f1a770ee96fc08df567a969ea9de06a491b550`.
- Parent: `1d449fe1fb3b22619bb5b6657a21ee5f7db30f36`.
- Audited implementation pin: `eac7d6985e6bbf1c33c3c4b6e9c338c08f3d0990`.
- Public reference pin: `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Artifact: [nine-row evidence audit](../reports/phase0-behavior-ledger-audit.md).

## Method and scope

Independently recovered public main at the reviewed report revision, inspected
the exact two-file diff and task criteria, and read implementation/test/source
anchors in an isolated checkout of the audit pin. Reference-source HEAD was
independently checked. Existing independent review records were read as recorded
acceptance, not treated as freshly reproduced execution. No ROM, user save,
media, test suite, replay, or external write was needed or performed for this
report-only review.

The commit changes only the authorized task and report. `git diff --check` for
the exact commit passes. All 89 local inline-link occurrences in those artifacts
resolve; this is a local-target check, not a claim of external-link validation.
No runtime, tests, ledger, workflow, coordination status, generated data or game
content entered the reviewed change. The task is `READY_FOR_REVIEWER`; the
Orchestrator's exact-review dispatch resolves older coordination wording, which
this review does not edit.

## Independent findings against the existing criteria

All nine rows in the pinned ledger are represented. The report consistently
separates source definitions, actual runtime calls, inspected assertions,
recorded execution and independent acceptance. The following checks substantiate
the material claims; line numbers refer to the audit pin unless stated otherwise.

| Ledger row | Independently checked evidence and retained boundary |
| --- | --- |
| 1 — ROM identity | `RomImporter.verify` and `main.lua:2984` gate decoding on the supported hash/address table. The smoke test covers table/name and missing-file refusal, not real hashing. The title-entry and Pain Split reviews record actual supported-ROM execution; exhaustive wrong-ROM UX remains UNKNOWN. |
| 2 — Data catalogs | Main's catalog construction and `DataViewer.CATEGORIES` match the named consumers. The sweep checks species/moves/trainers and four named maps; it does not prove every mechanic or all-world traversal. The report correctly preserves canonical Phase 1 status while distinguishing it from an unlocated dedicated all-viewer-records acceptance receipt. |
| 3 — Maps | Pinned map structures, map loading, object-event loading and shared camera drawing calls support the runtime map. The ROM map tests cover Route 1/House 1F; map-script table decoding is synthetic. Accepted camera geometry does not establish all-world or retail visual parity. |
| 4 — Scripts | `DialogueRunner.buildWorld` supplies the listed message/lock/face/remove-object/Mart hooks. It does not provide the claimed generic session flag/variable, warp, item/mon, movement or trainer-battle hooks. Interpreter unsupported-command errors differ from absent optional callbacks/no-op setters. Decoding/VM support is therefore not promoted to complete live script support. |
| 5 — Wild/capture | The actual caught handler, capture reward routing, save-backed PC tables and codec tests support bounded PC overflow storage. Component evidence and party-capture receipts are not a dedicated full-party capture-to-PC-to-fresh-reload acceptance. Encounter and early-story exclusions remain explicit. |
| 6 — Tutorial | Reference FIRST_BATTLE setup/commands, the early-rival runtime seam and deterministic AI/RNG/reward assertions support the bounded tutorial row. They do not prove general trainers, all normal-input starter/outcome combinations or full presentation parity. |
| 7 — Pain Split | Pinned source/script/data, engine/controller paths and the independent `a739ddc` review support the existing narrow row. That receipt records 237/0 engine, 39/0 controller, 149-file suites and headless replay evidence. The report preserves exclusions and does not turn headless replay into LÖVE animation parity. |
| 8 — Save | Codec/schema ownership and whole-buffer `love.filesystem.write`/decode-before-session-replacement paths substantiate the separation between format validation and live filesystem safety. The save-contract review is bounded evidence. Historical rollover wording at the audit pin is explicitly separated from later accepted `aec377a`; suffix/partial-field/filesystem limitations remain. |
| 9 — Rendering/input/scenes | Input repeat, scheduler ordering/lifecycle, title/Oak flow and shared viewport owners have concrete assertions and accepted bounded receipts. ROM pixel samples and repeated self-diff captures are not retail-image comparison. Phase 2 visual parity remains open. |

### Stale PC claim and missing acceptance

The blanket PC-overflow-incomplete wording is stale: history identifies
`103c5e1` as the storage-persistence change; the pinned caught handler at
`main.lua:4521` calls `CaptureRewards.giveMonToPlayer`, and
`GameSession.fromNewGame`/`fromSavedState` construct `PcBoxes` over saved storage
by reference. Tests separately exercise party-full routing, box wrap/full
refusal, save backing and serialization/metadata/fallback behavior.

Conversely, `phase3_exit_path_rom_test.lua` injects a ball and populates the
second party slot directly for its capture branch. The natural-capture task
records a two-member party, while the accepted Phase 3 exit receipt follows
wild defeat. No dedicated independently accepted full-party live capture,
PC placement and fresh-process reload receipt was located in the inspected
records. The report's UNKNOWN is appropriately bounded: it neither invents
acceptance nor asserts that the behavior is absent.

### Material omitted coverage and temporal boundaries

The proposed ordinary-trainer/replacement row is supported by concrete runtime
restrictions in `main.lua:1483`, relevant test assertions, and five independent
accepted leaves: `f40c4021`, `8533cf6a`, `8fd9a397`, `3140e267`, and `4a583b6a`.
These cover bounded no-item one/two-member parties, foe/forced/voluntary
replacement and two-sided terminal states. Tests reach real main seams through
configured sessions; the report does not call that universal normal-world
trainer acceptance or broaden party layouts, AI, switching or move mechanics.
Adding the omitted input/scheduler evidence to the existing scene row is also
within the named audit domains, not a new subsystem proposal.

The path-limited comparison from accepted `a739ddc` to the audit pin changes only
`tests/save_file_codec_test.lua` and `tests/save_load_roundtrip_test.lua` within
the reported import/runtime/test/script paths. The report correctly treats the
earlier verified-ROM suite as recorded execution of unchanged tests, not new
independent acceptance of every subsystem. Comparing the pinned ledger with
`9c81b90` confirms the later accepted save-row rollover correction; the proposed
successor explicitly preserves it. No draft inventory result is promoted to
accepted evidence.

## Exact next allowance

The Orchestrator may reconcile this report PASS and dispatch its single proposed
ledger-only correction package, with `docs/behavior-ledger.md` as the sole
implementation path: qualify the nine existing rows and add only the bounded
ordinary-trainer/replacement row, using the report's exact evidence and limits.
That successor needs its own task and independent review. It must preserve later
accepted save wording, canonical phase states, UNKNOWN proof gaps, supported-ROM
policy and visual/runtime exclusions.

This PASS authorizes no runtime/test/workflow change, new missing-proof program,
inventory acceptance, ROM execution or phase closure. Phase 0 remains open.
Per the assigned review boundary, only this review artifact is authored here;
coordination reconciliation, commit and publication remain with the parent.
