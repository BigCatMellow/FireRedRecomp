# Handoff: north-facing Oak Parcel/Dex presentation

- From: `/root`
- To: next FireRed ReComp implementation owner
- Task: `work/tasks/oak-parcel-dex-presentation-north.md`
- Status: `ACTIVE` — checkpoint only; not runtime integrated

## What is true now

- VERIFIED: the pure, bounded presenter has the 15 recorded ROM text pointers,
  strengthened north-facing guard, source-correct opening order (first four
  messages, then rival entrance, then `DE99`), temporary-object intent, and a
  terminal-only durable commit callback.
- VERIFIED: `lua5.1 tests/oak_parcel_dex_presentation_test.lua` passes with
  24 passed, 0 failed after the source-order correction.
- VERIFIED: independent review rejected the initial rival-before-opening-text
  order and checkpoint review required delayed rival removal plus ordered Dex
  prop removals; those findings are incorporated in the current presenter and
  test.
- ASSUMED / UNKNOWN: no `main.lua` integration, game-window replay, or
  verified-ROM execution of this scene has occurred at this checkpoint.

## Work completed

- Added `src/core/OakParcelDexPresentation.lua`: a deliberately narrow state
  machine, not a generic field-script interpreter.
- Added a focused pure-Lua contract test.
- Recorded a bounded runtime wiring plan from independent inspection.

## Work not completed

- Wire the presenter into `main.lua` and the Oak A-button path.
- Create/render the scene text printer, schedule forced motion, and apply the
  field/input/NPC locks.
- Instantiate/remove the temporary rival and remove Dex props only from the
  live map object list; do not persist hide flags.
- Update the natural-capture replay, run both suites and verified-ROM replay,
  then obtain final independent review.

## Decisions and constraints

- Keep the exact strengthened guard from the task: Lab `(4,3)`, player
  `(6,4)` facing up, Oak id 4, Mart scene 1, Lab scene 5, Parcel present, and
  a non-mutating ball-capacity preflight.
- Invoke `ViridianParcelStory:completeLabParcelReturn` only from the final
  presenter completion. Existing fallback behavior remains for all other Oak
  interactions.
- Do not add generic `addobject`, `applymovement`, map hooks, other Oak
  orientations, audio, Fame Checker, or broad script-interpreter work.

## Current blocker / risk

- Main integration is the active risk: existing `removeNpcLive` persists hide
  flags and must not be used for the temporary rival or props. Existing NPC
  movement must also pause while the cutscene owns those tracks.

## Working state

- Changed/uncommitted paths: none after this checkpoint is committed.
- Last verification performed: `lua5.1 tests/oak_parcel_dex_presentation_test.lua`
  — 24 passed, 0 failed; `git diff --check` — clean.
- Known failing checks: none. Full suites and runtime replay have not yet run
  for this unintegrated presenter.

## Next action

1. Follow the bounded wiring plan in the task context: integrate this presenter
   before the current abbreviated Oak fallback, retain real object templates
   for a temporary rival, and add the matching scheduler/text/input/render
   paths; then run the acceptance evidence.

## Do not redo / do not assume

- Do not reintroduce the rejected rival-before-opening-text sequence: retail
  displays `E405`, `E4AF`, `E4CA`, `DE8D`, then brings in the rival, then
  displays `DE99`.
- Do not infer scene completion from the focused pure test; it does not prove
  runtime integration or persistent save/restart behavior.
- Do not treat the temporary rival/props as permanently hidden.

## Evidence / paths

- `work/tasks/oak-parcel-dex-presentation-north.md`
- `src/core/OakParcelDexPresentation.lua`
- `tests/oak_parcel_dex_presentation_test.lua`
- `work/reviews/viridian-mart-parcel-presentation-review.md` for the prior
  analogous presenter/review pattern.
