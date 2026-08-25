# FireRed ReComp — Handoffs

Task briefs for parallel agent sessions working the shared
`/home/mellow/Documents/Projects/Pokemon ReComp/firered-recomp/` git
repo. Read this before picking up or handing off work here.

## Layout

- `firered-recomp-checklist.md` — **the live, authoritative progress
  tracker** for the whole FireRed ReComp project, phase-by-phase against
  `../roadmap.md`. Nested markdown checklist format
  (`## Phase` headers, `- [ ]` open / `- [x]` done / `- [~]` partial).
- This folder (`handoffs/`) — **open** task briefs, one per independent
  chunk of work. Anything sitting directly in here is available to pick
  up (unless another agent's summary/notes in the same session say
  otherwise — check `git status`/`git log` in `firered-recomp/` first,
  see "Before you start" below).
- `handoffs/completed/` — task briefs whose deliverables have **landed
  and been committed** into `firered-recomp/`. Kept for historical
  reference (what was verified, what was scoped out) — not a queue.

## Workflow

**Before you start:**
1. Check `git log`/`git status` in `firered-recomp/` — work can land
   between when a handoff was written and when you pick it up. If the
   checklist or repo state already shows a handoff's deliverables done,
   don't duplicate it — move it to `completed/` yourself (see below) and
   pick a different one, or tell the user its scope needs revisiting.
2. Read the handoff's "What NOT to touch" section. Handoffs are written
   to avoid file conflicts between concurrent agents (usually: nobody
   edits `main.lua` except one explicitly-designated integration pass).
   Don't touch a file another open handoff claims.
3. Read the checklist's relevant line(s) for current status/context.

**While working:** follow the handoff's own conventions section (real
ROM/source verification standard, test commands, no-`bit`-library rule,
etc.) — every handoff restates these because they're load-bearing, not
because they vary per task.

**When you finish (fully — deliverables done, tests passing, checklist
updated):**
1. Update `firered-recomp-checklist.md` for exactly what you finished
   and verified, in the file's existing entry style (cite real
   struct/function names, what's verified vs. scoped out).
2. **Move your handoff file from `handoffs/` into `handoffs/completed/`**
   (`mv handoffs/<your-task>-handoff.md handoffs/completed/`) so the
   next agent to look in this folder immediately sees what's still open
   without reading every file's contents. This is the single most
   important housekeeping step — it's what keeps this folder trustworthy
   as a queue.
3. **Don't commit the code changes yourself** — per every handoff's
   "Conventions to follow" section, leave the working tree uncommitted;
   the project owner reviews and commits in logical chunks. (Moving the
   handoff `.md` file itself is fine/expected — that's bookkeeping, not
   project code.)

If you only finish part of a handoff, leave it in `handoffs/` and note
in the checklist entry (and ideally a short addendum at the top of the
handoff file itself, like the save-block handoff's status note) exactly
what's done vs. still open, so the next agent doesn't have to
re-derive it.

## Currently open (as of 2026-08-13, after wild-battle integration)

Rounds 1-3 and the subsequent new-game identity, core battle-engine, and
wild-battle scene integration passes have landed — see `completed/` and
the checklist. There is currently no task brief directly in this folder.
The next agent should choose a remaining checklist boundary and write a
new conflict-scoped handoff before parallel work begins; the completed
wild-battle handoff recommends the real party/moveset + XP/reward or
capture bridge as the next high-value vertical slice.

Don't treat this list as authoritative once it's out of date — the
actual source of truth is which files are physically sitting in
`handoffs/` vs. `handoffs/completed/` at the time you look.
