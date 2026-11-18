# P5-07 — Viridian scene-1 tutorial-trigger field-side design

- Task ID: `P5-07-VIRIDIAN-TUTORIAL-TRIGGER-DESIGN`
- Status: `READY_FOR_REVIEWER` — design only, with no runtime authority
- Type: `DESIGN / bounded necessary source checks`
- Parent capability: Phase 5 Pallet-to-Elite-Four traversal in the [capability checklist](../roadmaps/CAPABILITY_CHECKLIST.md)
- Assigned role: `WORKER` acting as a bounded designer
- Independent reviewer: a separate `REVIEWER`, doing an exact review of the design, its sources and its scope
- Prerequisites:
  - [P5-07 field-side discovery](../reports/phase5-viridian-old-man-tutorial-trigger-source-discovery.md), PR #80 head `cc287e5` (delta review PASS `f78570c`; still a draft, awaiting the merge gate);
  - [C0 design](../reports/phase5-viridian-roadblock-design.md), PR45 `6006ab6`;
  - [C0 recovery outcome PASS](../reviews/2026-11-15-viridian-roadblock-recovery-outcome-review.md), for publication `42cd4fd`.
- Runtime baseline: `df53c7770c1df5884f4c3924e331c5efebe91925` (tracked Lua is unchanged at `cc287e5`)
- Risk: LOW for the docs. A future implementation risks input leaks, a refusal that lets the player through, interference with C0, and an assumption about post-battle state.

## Goal

Specify one implementable live slice for the field side of the scene-1 C2
(20,8) and C3 (22,8) triggers:

- eligible completed step;
- lockall;
- the man's in-place turn and wait;
- the player's in-place turn and wait;
- message and close;
- the Quest Log instruction pair;
- then a **fail-closed refusal** at `special StartOldManTutorialBattle`.

The refusal writes no scene 2, gives no Teachy TV and lets no one pass through.
In the same report, give the literal runtime/test allowlist, the oracles and
the guarded-evidence and route requirements, mirroring P5-06.

The Old Man tutorial battle is an **outside dependency** owned by the battle
lane. Its battle-lane trace `ec2d8e9` is under independent review and is not
yet reviewed. It may be cited as "pending review", but no design decision may
rest on it.

## Source of truth

Public pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788` only. The
facts accepted in P5-05, the P5-07 discovery and the C0 design are adopted,
not repeated. Gym C1, C0 behavior, the projection and the tutorial battle stay
excluded.

## MAY CHANGE

- `work/tasks/phase5-viridian-old-man-tutorial-trigger-design.md` (this file, new)
- `work/reports/phase5-viridian-old-man-tutorial-trigger-design.md` (new)

## MUST NOT CHANGE

These are all out of bounds:

- runtime code, tests, save data or schema, imports or assets, and the renderer;
- workflow, bridge, runner, probe or request files;
- coordination and roadmap files;
- any battle file;
- C0 or projection behavior.

No ROM read, no LÖVE run, no extracted dialogue, no private paths and no merge.

## Acceptance criteria

1. Exact admission:
   - an ordinary completed, nonmoving step with a matching map generation;
   - map 769 at (20,8) or (22,8), with the decoded C2/C3 identity;
   - scene 1, read from validated storage;
   - the C0 elevation rule (event elevation, 0 as a wildcard, unknown refused).

   Also specify the refusal handling and the dispatch location relative to C0.
2. Source-locked states, transitions and owners for:
   - lock;
   - both in-place turns, with their direction and duration;
   - text pages and scroll;
   - the NEW A/B rules;
   - close;
   - the Quest Log pair;
   - the refusal.
3. Input ownership, the NPC freeze, renderer ownership, teardown, and C0
   mutual exclusion. The refusal must not let the player through.
4. One cohesive implementation proposal with literal paths, its API/state and
   source-derived assertions.
5. A complete evidence plan and guarded-route proposal.
6. Actual checks are kept separate from proposals. UNKNOWNs are explicit. The
   battle is named an outside dependency, and the post-battle state is UNKNOWN.

## Stop / escalate

Stop if the slice needs any of the following:

- new persistent state;
- a generic VM, renderer or collision architecture;
- battle-lane design;
- changes to C0 or the projection;
- another source revision.

## Worker evidence — 2026-11-18

- Report: [design](../reports/phase5-viridian-old-man-tutorial-trigger-design.md).
- Branch `work/p5-07-tutorial-trigger-design-20261118`, based on the PR #80
  head `cc287e5`. The clean source checkout's HEAD equals the pin.
- Checks: the repository checker and `git diff --check origin/main` both
  pass. Receipts are in the report. No ROM, LÖVE, runner or test execution.
- No self-acceptance. An independent review is required.
