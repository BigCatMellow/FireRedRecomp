# FireRed ReComp — Remaining Text Control Codes + Weather/Palette Animation Task (independent, parallel-safe)

## Context you need

This project (`/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp/`)
is a **recomp** of Pokémon FireRed: real decompiled C source
(`/home/mellow/Documents/Projects/Pokemon ReComp/Disassembled_Games/Classic/pokefirered-master/`)
ported by hand into Lua/LÖVE2D, pulling every asset directly out of a
verified real ROM at load time. Nothing is placeholder — every module is
verified against real ROM bytes, documented in its header comment.

Verified ROM:
`/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba`
(SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`).

Checklist: `/home/mellow/Documents/Projects/Pokemon ReComp/docs/handoffs/firered-recomp-checklist.md`
(plain file, not in the git repo — edit directly). This covers two
small, independent Phase 2 polish items:
- "Remaining non-color/pause control codes ... `Charmap.tokenize`
  parses them structurally but `TextRenderer.lua` skips them unacted-on"
- "Weather and per-frame palette animation (distinct from a one-shot
  fade) are still open" (under the layer priority/blend/fade line)

This is genuinely two small tasks bundled into one handoff because both
are quick, well-scoped polish items — feel free to do them in either
order, or split across two sessions if picked up by two agents (just
say clearly in your summary which half you did).

## What NOT to touch

Do not edit `main.lua`. Extend `import/TextRenderer.lua`,
`src/core/PaletteBlend.lua`/`PaletteFade.lua`, or add new files under
`src/core/`/`import/`, plus `tests/`. Note what `main.lua` wiring would
need for whichever half you complete.

## Part 1: remaining control codes in `TextRenderer.lua`

`Charmap.tokenize` already structurally parses every FC-prefixed
control code (colors/highlight/shadow already ACT on render via
`TextRenderer.lua`; PAUSE/PAUSE_UNTIL_PRESS already act via
`TextPrinterState.lua`). What's parsed-but-ignored: sound cues,
`{PLAYER}`-style placeholders (0xFD + subcode), SHIFT_RIGHT/SHIFT_DOWN,
FILL_WINDOW, CLEAR. Read `src/text.c`'s real `RenderFont` switch/case
for each of these codes to confirm exact real behavior (don't guess):

1. **Placeholders** (`{PLAYER}`, `{RIVAL}`, `{STR_VAR_1/2/3}`, etc.):
   real FireRed substitutes these with actual runtime strings (player
   name, a dynamically-set string variable). Since this project doesn't
   have a save/player-name system wired in yet, the correct scoped
   behavior is likely a caller-supplied substitution table (e.g.
   `TextRenderer.render(tokens, {PLAYER = "RED"})`) with a sane
   documented fallback (e.g. render the raw placeholder name in
   brackets) when no substitution is provided — check whether
   `Charmap.decode`'s older bracketed-placeholder behavior already
   established a fallback convention worth reusing for consistency.
2. **SHIFT_RIGHT/SHIFT_DOWN**: real cursor-position adjustment codes —
   port the real pixel-offset math from `src/text.c`.
3. **FILL_WINDOW/CLEAR**: real window-content-clearing codes — port
   the real behavior (what exactly gets cleared/filled, and with what).
4. **Sound cues**: since there's no audio mixer wired into text
   rendering yet (and the audio-sequencer-playback handoff, if it
   hasn't landed, is a prerequisite for *actually* playing a sound),
   the correct scope here is: recognize and correctly skip the real
   parameter-byte width for these codes (already done by `tokenize`)
   and expose a hook/callback the renderer calls when it hits one
   (e.g. `onSoundCue(cueId)`), rather than actually playing audio. Note
   this clearly as the scoped boundary.
5. Add real test coverage for each code actually acted upon (`tests/
   text_renderer_test.lua` already exists — extend it, matching its
   existing pixel/behavior-assertion style, not just "it doesn't
   crash").

## Part 2: weather + per-frame palette animation

1. **Read the real source**: `src/field_weather.c` (weather) and
   whatever real system does non-fade palette cycling (search for
   `UpdatePaletteFade`-adjacent per-frame palette animation — real GBA
   games commonly cycle a few palette indices per frame for water/
   flashing-light effects; find the real FireRed mechanism, e.g. a
   water-reflection or flower-blink cycle, rather than inventing one).
   Don't guess which specific real effect to port — pick ONE concrete
   real effect you can verify against real data, the same way past
   Phase 2 work always anchored to one concrete verified case (e.g. the
   flame particle burst, the slash-in effect).
2. **Port that one effect** as a testable, pure-Lua tick-driven module
   (same pattern as `PaletteFade.lua` — no love2d coupling in the core
   logic), reusing `PaletteBlend.lua`'s per-channel math if applicable
   rather than reimplementing blend math.
3. Verify against real data: confirm the real palette indices/cycle
   timing/target colors you're porting match the real source, not
   assumed values.

### Explicitly out of scope

- Don't try to build a general "any weather type" system — one real,
  concrete, verified effect is the goal (matching this project's
  established pattern of "prove the mechanism on one real case first").
- No `main.lua` wiring for either part.
- No actual audio playback for sound cues (see Part 1, item 4) — hook
  only.
- No player-name/save-data system — placeholders use a caller-supplied
  substitution table with a documented fallback, not a real name.

## Conventions to follow

- Every module's header comment cites the real function/source file and
  states exactly what was verified against real ROM data or source —
  see `TextRenderer.lua`/`PaletteFade.lua` for house style.
- No `bit` library / Lua 5.3 bitwise operators (LuaJIT + plain Lua 5.1
  compatibility).
- Tests: plain-Lua unit tests always run; ROM-integration tests check
  `POKEPORT_ROM` and skip cleanly if unset. Run the full suite before
  finishing:
  ```
  cd "/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp"
  ROMPATH="/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba"
  for f in tests/*.lua; do POKEPORT_ROM="$ROMPATH" lua5.1 "$f" || echo "FAILED: $f"; done
  ```
- **Don't commit anything** — leave changes in the working tree.
- Update the checklist for exactly what you finished (say clearly if
  you only did Part 1, only Part 2, or both).

## Deliverable

Which part(s) you completed, what real source you read for each control
code / the weather-or-palette-animation effect you chose and why, what
was verified against real ROM/source data, what's explicitly left out,
and the file list touched.
