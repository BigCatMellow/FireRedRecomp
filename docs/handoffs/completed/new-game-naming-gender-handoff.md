# FireRed ReComp — New-Game Naming + Gender Selection UI Task (main.lua owner — run ALONE, not in parallel with any other main.lua work)

## Context you need

This project (`/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp/`)
is a **recomp** of Pokémon FireRed: real decompiled C source
(`/home/mellow/Documents/Projects/Pokemon ReComp/Disassembled_Games/Classic/pokefirered-master/`)
ported by hand into Lua/LÖVE2D, pulling every asset directly out of a
verified real ROM at load time.

Verified ROM:
`/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba`
(SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`).

Checklist: `/home/mellow/Documents/Projects/Pokemon ReComp/docs/handoffs/firered-recomp-checklist.md`.
This continues Phase 3's `- [~] New-game naming, initial flags/vars` line
— `src/core/SaveBlockLayout.lua`/`NewGameDefaults.lua` already model the
real data shape/defaults, but there's no UI/flow yet. This task builds
that UI/flow: after Oak's intro narration, the real game asks for gender,
then player name, then rival name.

## What NOT to touch

**This is a `main.lua`-owning task — do not run it concurrently with any
other handoff that also claims `main.lua`.** Check `git status` before
starting; if `main.lua` already has uncommitted changes from another
in-flight session, stop and report back rather than merging over them.

## Background: what's already built (reuse, don't reinvent)

- `import/OakSpeechScene.lua` — the scene this flow continues from
  (currently ends after narration, no gender/naming yet — see its own
  header for exactly what's built).
- `src/core/MenuCursor.lua` — real cursor movement (wraparound, A/B,
  held-key repeat) — the gender-select screen is a real 2-option cursor
  choice (Boy/Girl), directly reusable, same pattern as the existing
  Yes/No menu.
- `import/TextWindow.lua`/`TextRenderer.lua`/`TextPrinterState.lua` — the
  full dialogue/window rendering pipeline.
- `src/core/InputState.lua` — real key-repeat timing, already used for
  the data viewer and menu navigation.
- `src/core/NewGameDefaults.lua` — confirms there's no fixed default
  player/rival name (set by the naming screens), so this task is what
  actually produces those values for the first time.
- `src/core/SaveBlockLayout.lua` — the real field shape (`playerName`,
  `playerGender`, `rivalName`) this flow ultimately populates.

## The task

### 1. Gender selection screen

Find and decode the real gender-select screen assets (search
`src/oak_speech.c` or wherever the real transition into gender selection
happens for the real graphics/layout — likely simple: two portrait
images, Boy/Girl labels, a cursor). Verify field names/addresses from
real source, don't guess. Build it as a real screen using `MenuCursor`
for the 2-choice selection, composited with whatever real portrait
graphics exist (if the real portraits turn out to require more graphics
machinery than is worth it for this pass — e.g. large character art —
a text-only Boy/Girl choice using the existing menu/window primitives is
an acceptable documented fallback; say clearly if you took this route).

### 2. Player naming screen (the real keyboard/character-grid UI)

This is the substantial new piece — FireRed's real naming screen is a
character-grid keyboard (letters laid out in a grid, cursor moves with
D-pad, A selects a character, B backspaces, a confirm option finalizes).
1. **Find the real source** for this screen (search for "naming" /
   "NamingScreen" in `src/` — don't assume a filename, confirm it from a
   real grep). Read the real character-grid layout (how many rows/
   columns, which real character set — FireRed has multiple real
   keyboard "pages": lowercase, uppercase, symbols — decide how many
   pages to support; even just the primary uppercase page is a
   legitimate scoped-down first pass if the full multi-page keyboard is
   too much for one session, but say clearly what's covered).
2. **Decode the real keyboard graphics** if there are dedicated tile/
   layout assets, or lay it out programmatically using the existing font
   renderer if the real screen is closer to "just text drawn in a grid"
   — check the real source to see which is true, don't assume.
3. **Build the interactive state**: cursor position in the grid, a
   growing name buffer (respect FireRed's real max player-name length —
   confirm the real constant, likely a small number like 7-8 chars, from
   `include/constants/`), A selects the highlighted character and
   appends it, B backspaces, some real confirm action (a "END"/"OK" grid
   cell, or a separate button — check source) finalizes the name.
4. **Wire it to a real name buffer** matching `SaveBlockLayout.lua`'s
   `playerName` field shape (check its real max length/encoding — is it
   stored as raw charmap bytes, confirm from `SaveBlockLayout.lua`'s own
   documentation).

### 3. Rival naming

Real FireRed asks for the rival's name too (same keyboard UI, reused).
Simplest correct approach: run the same naming-screen module a second
time for the rival name, writing into `SaveBlockLayout.lua`'s
`rivalName` field shape instead. A "here are a few real default rival
name options to pick from, or type your own" flow exists in some
versions — check the real source for whether FireRed offers preset name
choices before free typing, and match whatever's actually there.

### 4. Wire the full flow into `main.lua`

After the existing Oak intro (S view)'s narration, chain into: gender
select → player naming → rival naming → (end state: hold the finished
{gender, playerName, rivalName} somewhere sensible in `main.lua`'s
state — there's no overworld-spawn/bedroom-start flow yet, so "reaching
a clean end state with all three values populated, visibly confirmable"
is the actual exit bar for this task, not "and then gameplay begins").

### Explicitly out of scope

- Actually starting the overworld game session (spawning the player in
  the bedroom, walking into Pallet Town as a fresh save) — that needs
  more integration than this task's scope (loading the actual starting
  map/warp from `NewGameDefaults.lua`, which a future pass can wire once
  this exists).
- Multiple keyboard pages beyond what you scope in step 2.2 (document
  what's covered).
- Actually writing to a save file — that's `SaveFileCodec.lua`'s
  territory (may already exist, check `handoffs/completed/` — this task
  just needs to produce the in-memory values, not persist them).

## Conventions to follow

- Every module's header comment cites the real struct/function/source
  file and states exactly what was verified against real ROM data.
- No `bit` library / Lua 5.3 bitwise operators.
- Tests: plain-Lua unit tests for anything structurally testable (grid
  cursor movement, name-buffer append/backspace/length-cap logic) —
  same pattern as `MenuCursor.lua`'s tests (stub input, no love2d
  needed for the core logic). Live-screenshot the gender/naming screens
  for visual confirmation, matching this project's established standard.
  Run the full suite before finishing:
  ```
  cd "/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp"
  ROMPATH="/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba"
  for f in tests/*.lua; do POKEPORT_ROM="$ROMPATH" lua5.1 "$f" || echo "FAILED: $f"; done
  lua5.1 -e "assert(loadfile('main.lua'))"
  ```
- **Don't commit anything** — leave changes in the working tree.
- Update the checklist's "New-game naming, initial flags/vars" line for
  exactly what you finished.

## Deliverable

What real source you found for the gender-select and naming screens,
how many keyboard pages/what character set is covered, what's a real
decoded asset vs. a documented text-only fallback, what you verified
live (screenshots), what's explicitly deferred, and the file list
touched.
