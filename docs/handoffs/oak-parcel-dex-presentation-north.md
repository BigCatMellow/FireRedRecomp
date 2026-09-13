# Handoff: north-facing Oak Parcel/Dex presentation

- From: `/root`
- To: next FireRed ReComp implementation owner
- Task: `work/tasks/oak-parcel-dex-presentation-north.md`
- Status: `DONE` — live bounded presenter is integrated, verified, and
  independently approved; owner commit remains the publication boundary.

## What is true now

- VERIFIED: the pure, bounded presenter has the 15 recorded ROM text pointers,
  strengthened north-facing guard, source-correct opening order (first four
  messages, then rival entrance, then `DE99`), temporary-object intent, and a
  terminal-only durable commit callback.
- VERIFIED: `lua5.1 tests/oak_parcel_dex_presentation_test.lua` passes with
  26 passed, 0 failed; it covers no-write runtime abort and post-rival
  commit-failure cleanup.
- VERIFIED: `main.lua` integrates the bounded presenter before the abbreviated
  Oak fallback, owns its text/motion/input lock, uses a temporary rival and
  live-only Dex-prop removal, and invokes the durable story controller only
  after terminal choreography.
- VERIFIED: `luac5.1 -p main.lua`, the 138-file ROM-backed suite, and the
  two-process natural-capture save/restart replay pass.

## Work completed

- Added `src/core/OakParcelDexPresentation.lua`: a deliberately narrow state
  machine, not a generic field-script interpreter.
- Added a focused pure-Lua contract test.
- Recorded a bounded runtime wiring plan from independent inspection.

## Work not completed

- No implementation work remains in this bounded slice.

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

- The temporary rival and Dex props must continue to be removed only from the
  live NPC list, never through
  `removeNpcLive`, which persists object hide flags.

## Working state

- Changed/uncommitted paths include the presenter, bounded `main.lua` bridge,
  focused test, task/review records, and broader in-flight project work.
- Last verification: focused presenter test (26/0), `luac5.1 -p main.lua`,
  138-file ROM suite, natural-capture save/restart replay, and `git diff
  --check` — all pass before the failed-commit cleanup follow-up.

## Next action

1. Hand the bounded slice to the owner for commit without expanding into a
   generic script interpreter.

## Do not redo / do not assume

- Do not reintroduce the rejected rival-before-opening-text sequence: retail
  displays `E405`, `E4AF`, `E4CA`, `DE8D`, then brings in the rival, then
  displays `DE99`.
- Do not infer full FireRed story parity from this bounded scene; the replay
  proves only the current implemented Mart → Parcel → Dex → capture path.
- Do not treat the temporary rival/props as permanently hidden.

## Evidence / paths

- `work/tasks/oak-parcel-dex-presentation-north.md`
- `src/core/OakParcelDexPresentation.lua`
- `tests/oak_parcel_dex_presentation_test.lua`
- `work/reviews/viridian-mart-parcel-presentation-review.md` for the prior
  analogous presenter/review pattern.
