# FireRed ReComp — Screenshot-Parity Tooling Task (independent, parallel-safe)

## Context you need

This project (`/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp/`)
is a **recomp** of Pokémon FireRed: real decompiled C source
(`/home/mellow/Documents/Projects/Pokemon ReComp/Disassembled_Games/Classic/pokefirered-master/`)
ported by hand into Lua/LÖVE2D, pulling every asset directly out of a
verified real ROM at load time. Nothing is placeholder — every module is
verified against real ROM bytes, documented in its header comment.

Verified ROM:
`/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba`
(SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`). A different-revision copy
also exists in the same folder — always use this exact one.

Checklist: `/home/mellow/Documents/Projects/Pokemon ReComp/docs/handoffs/firered-recomp-checklist.md`
(plain file, not in the git repo — edit directly). This task closes
Phase 2's "Screenshot-parity comparison tooling (systematic pixel-diff
against reference, not just eyeballing)" line.

## What NOT to touch

Someone else is actively editing `main.lua` and `import/TitleScreen.lua`
concurrently. **Do not edit either file.** Everything here should live in
a new `tools/` subfolder and new test files. You may add new
`RomAddresses.lua` entries (don't touch existing ones) and read/require
any existing `import/*.lua` or `src/core/*.lua` module.

## The task

Right now every visual verification in this project is "take a
screenshot, look at it, describe what's visible" — real but unsystematic.
Build a **pixel-diff comparison tool**: given two PNGs (or a composited
in-memory image and a reference PNG), report exactly how different they
are — not just "looks right."

### Suggested scope

1. **`tools/pixeldiff/main.lua`** (or a plain Lua CLI script, your
   choice — doesn't need to be a LÖVE2D project since PNG decoding can
   be done via `love.image` if you make it a minimal headless LÖVE
   script, or you can write a pure-Lua PNG decoder if you want zero
   LÖVE dependency — decide based on what's simplest, just document the
   choice): given two image sources, compute:
   - Are dimensions identical? If not, report that immediately.
   - Per-pixel RGBA delta, and a summary: % of pixels that differ at
     all, max single-channel delta, mean delta.
   - Optionally emit a diff-visualization image (e.g. differing pixels
     highlighted in red) — nice to have, not required.
2. **A real use case to prove it against**: this project doesn't have
   reference screenshots from a real emulator to diff against yet. So
   instead, prove the tool works two ways:
   - **Self-consistency**: composite the same real title screen twice
     (e.g. via `import/TitleScreen.lua`'s `compositeFull`) and confirm
     the tool reports 0 difference between two runs of the same
     deterministic decode.
   - **Real regression detection**: deliberately corrupt a copy (flip a
     few pixels, or diff the title screen against the Pallet Town map
     composite) and confirm the tool reports a large, correct
     difference. This proves the tool actually *detects* mismatches,
     not just that it runs.
3. **Wire it into a reusable test helper**: add a small
   `tests/pixeldiff_test.lua`-style helper other tests could call later
   (e.g. `PixelDiff.compare(imageA, imageB)` returning a summary table),
   even if no other test uses it yet — this is infrastructure for
   future use, so make the API clean and documented.
4. **If you can source real reference images**: if a real GBA emulator
   (mGBA, VBA, etc.) is available in this environment, capture a real
   screenshot of the title screen from actual emulation and diff it
   against this project's composited title screen — that would be the
   real "parity" proof the checklist item is asking for. If no emulator
   is available, don't fabricate one — just build and prove the tool
   works per steps 2-3 above, and clearly note in your summary that true
   against-a-real-emulator parity checking is still unverified.

### Explicitly out of scope

- Don't try to get pixel-perfect parity against real hardware timing
  quirks (LCD color curves, GBA's specific gamma) — this tool measures
  *this project's renderer* against *a reference image*, whatever that
  reference is. Getting a real reference image is step 4 above, best-
  effort only.
- Don't build a full visual regression CI pipeline — just the
  comparison primitive and proof it works.

## Conventions to follow

- Every module's header comment cites what it does and how it was
  verified — see `import/CryTable.lua` or `import/SpriteAnim.lua` for
  house style.
- Tests: plain-Lua unit tests always run; ROM-integration tests check
  `POKEPORT_ROM` and skip cleanly if unset (copy boilerplate from any
  `tests/*_test.lua`). Run the full suite before finishing:
  ```
  cd "/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp"
  ROMPATH="/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba"
  for f in tests/*.lua; do POKEPORT_ROM="$ROMPATH" lua5.1 "$f" || echo "FAILED: $f"; done
  ```
- No `bit` library / Lua 5.3 bitwise operators — this project runs
  under both LuaJIT (LÖVE) and plain Lua 5.1, so bit extraction is pure
  arithmetic (`math.floor`/`%`) everywhere. See `import/Lz77.lua`'s
  header comment.
- If you write any standalone LÖVE2D `main.lua` under `tools/`, sanity-
  check it loads: `lua5.1 -e "assert(loadfile('tools/.../main.lua'))"`.
  This project hit a real Lua 60-upvalue-per-function limit bug the test
  suite didn't catch — cheap insurance, don't skip it.
- **Don't commit anything** — leave changes in the working tree for the
  user to review.
- Update the checklist for what you actually finished and verified,
  matching the existing entry style (`[x]`/`[~]` + one paragraph citing
  what was verified).

## Deliverable

A summary of what was built, what you verified and how (be honest about
whether real-emulator parity was actually achieved or just the tool's
correctness on synthetic cases), and the file list touched.
