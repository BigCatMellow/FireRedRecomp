# FireRed ReComp — Basic Script Interpreter Task (independent, parallel-safe)

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
(plain file, not in the git repo — edit directly). This is Phase 3's
"Basic script interpreter (message, choice, flag/var ops, movement,
warp, give item/pokemon, trainer trigger, fade, callback)" line.

## What NOT to touch

Someone else is actively editing `main.lua` and map/movement-related
files (`src/core/PlayerMovement.lua`) concurrently. **Do not edit
`main.lua`.** Build in new files under `src/core/`, `import/`, and
`tests/`.

## Background: what's already built

- `import/MapScripts.lua` / `import/MapEvents.lua` (Phase 1) already
  extract every real script pointer from a map's data (map scripts,
  object-event scripts, warp/coord/bg event scripts) — **raw pointer
  extraction only, no bytecode interpretation**. This task builds the
  actual interpreter that reads and executes the bytecode those
  pointers point at.
- `import/Charmap.lua` already decodes the real text encoding
  (including `Charmap.tokenize` for structured control-code-aware
  decoding) — script MESSAGE commands point at charmap-encoded text you
  can decode with this directly.
- `src/core/TaskScheduler.lua`, `src/core/TextPrinterState.lua`,
  `src/core/MenuCursor.lua` — real, tested primitives for running things
  over time and handling player choice input, useful for how a script
  interpreter might eventually drive real dialogue/choice UI (though
  this task's core deliverable is the bytecode interpreter itself, not
  full UI wiring — see scope below).

## The task: a real script bytecode VM (not full engine integration)

FireRed's map scripts are a real, well-documented bytecode format —
`src/scrcmd.c` has the real per-command implementations, and
`include/constants/event_scripts.h` / the real script command table
(`gScriptCmdTable` or similar — grep for it) gives the real opcode
list. This is NOT a tiny format — it has ~100+ real commands. **Don't
try to implement all of them.** Scope to the commands explicitly named
in the checklist line: message, choice, flag/var ops, movement, warp,
give item/pokemon, trainer trigger, fade, callback — plus whatever
minimal control flow (jump, compare, if) is needed to execute a real,
simple script end to end.

### Suggested scope

1. **Read the real bytecode format.** Find the real opcode table (grep
   `src/scrcmd.c` and `include/`-something for the command dispatch —
   there's a real fixed opcode-to-handler mapping) and the real per-
   command argument encoding (each opcode has a specific number/width of
   argument bytes following it — don't guess, read the real handler
   functions to see what they read from the script pointer). This is
   the hard research part — budget real time for it, cite the real
   function names you traced each opcode from.
2. **`import/ScriptBytecode.lua`**: given a real script pointer (from
   `MapScripts`/`MapEvents`'s existing extraction), decode the
   instruction stream into a flat list of typed Lua tables — same
   pattern as `import/SpriteAnim.lua`/`import/AffineAnim.lua`/
   `import/SongEvents.lua` (all in this repo already, good references
   for "decode a real command byte stream into typed tables" style).
   Cover at minimum: `msgbox`/message-display commands, `giveitem`,
   `givepokemon` (or the real equivalent names — confirm from source),
   flag/var set/compare/ops, `goto`/`call`/`return`/`end`, `if`-style
   conditional jumps, `warp`, `applymovement`/movement-related commands
   (can just capture the movement data raw, doesn't need to execute
   real NPC movement), trainer-battle-trigger commands, and screen
   fade commands. Document clearly which real opcodes you skipped.
3. **`src/core/ScriptInterpreter.lua`**: a real, steppable VM — given a
   decoded instruction list (from step 2) and a "world state" callback
   interface (get/set flag, get/set var, etc. — you decide the
   interface shape, keep it simple and documented), executes
   instructions one at a time, handling real control flow (jumps,
   conditional branches, call/return). Should be tickable (one
   instruction — or one "step" — per call, not all-at-once), so a
   future caller can pause it mid-script for a real dialogue box to
   finish displaying. You do NOT need to wire this to actual game
   state/UI (that's a separate follow-up) — a test harness with a fake
   world-state object exercising the real control flow is sufficient
   for this task.
4. **Find and decode a real, simple script** from an actual map (Pallet
   Town's sign posts or a simple NPC's script are good candidates —
   `import/MapScripts.lua`/`import/MapEvents.lua` already give you real
   script pointers for any map) and verify your decoder + interpreter
   handle it correctly end to end — real message text decodes right,
   real control flow doesn't infinite-loop or crash, script terminates.

### Explicitly out of scope

- Don't wire this into `main.lua` or real gameplay (someone else owns
  that file, and this is genuinely a separate integration step) — just
  get the decoder + interpreter built, tested, and proven against one
  or two real scripts.
- Don't implement all ~100+ real script commands — the explicit list
  above plus minimal control flow is the target. Document what's
  missing clearly (a real script hitting an unimplemented opcode should
  fail loudly/reported, not silently do nothing).
- No real battle-triggering logic (actually starting a battle) — just
  decode/recognize the trainer-battle-trigger command and its
  arguments.

## Conventions to follow

- Every module's header comment cites the real function/file/opcode
  table it's based on and states exactly what was verified — see
  `import/SongEvents.lua` for a very similar "traced a real bytecode
  interpreter from decompiled source, not generic docs" example to
  match in style and rigor.
- Tests: plain-Lua unit tests always run (synthetic instruction streams
  testing control flow, same pattern as `tests/song_events_unit_test.lua`);
  ROM-integration tests check `POKEPORT_ROM` and skip cleanly if unset.
  Run the full suite before finishing:
  ```
  cd "/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp"
  ROMPATH="/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba"
  for f in tests/*.lua; do POKEPORT_ROM="$ROMPATH" lua5.1 "$f" || echo "FAILED: $f"; done
  ```
- No `bit` library / Lua 5.3 bitwise operators anywhere (LuaJIT + plain
  Lua 5.1 compatibility) — pure arithmetic bit extraction, see
  `import/Lz77.lua`'s header comment.
- **Don't commit anything** — leave changes in the working tree.
- Update the checklist for what you actually finished/verified, in the
  existing entry style.

## Deliverable

A summary of the real opcode table/format you traced (cite real function
names), which commands you implemented vs. explicitly skipped, which
real script you verified end to end and what it did, and the file list
touched.
