# P5-07 — source-lock the field side of the Viridian Old Man tutorial triggers

- Task ID: `P5-07-VIRIDIAN-OLD-MAN-TUTORIAL-TRIGGER-DISCOVERY`
- Status: `READY_FOR_REVIEWER` — source-only; no gameplay acceptance
- Type: `RESEARCH / SOURCE DISCOVERY`; no design or implementation authority
- Parent capability: Phase 5 Pallet-to-Elite-Four traversal in [capability checklist](../roadmaps/CAPABILITY_CHECKLIST.md)
- Assigned role: `WORKER` acting as bounded researcher
- Independent reviewer: separate `REVIEWER`; exact source/report verification
- Runtime baseline: `df53c7770c1df5884f4c3924e331c5efebe91925` (origin/main at dispatch)
- Prerequisites: [P5-05 northbound lock](../reports/phase5-viridian-northbound-gate-discovery.md) (PR42 `ae3d559`), [live elevation](phase5-player-elevation-input.md) (PR44 `75b49f3`), [P5-06 C0 recovery outcome PASS](../reviews/2026-11-15-viridian-roadblock-recovery-outcome-review.md) for publication `42cd4fd`
- Risk: LOW — documentation only. Main risk: mistaking the field-side half for a complete tutorial, or treating the Old Man battle as already designed

## Goal

Once C0 is accepted, find the next bounded Phase 5 blocker on the scripted
northbound path. Lock its field-side source sequence and current runtime gap,
then propose the smallest next gate. Coordinator decision (2026-11-17): the
work is split. This task covers only the map/script side of C2 (20,8) and
C3 (22,8) at scene 1. The Old Man tutorial battle (controller, temporary bag,
forced capture) is an **outside dependency** owned by the battle lane. It is
not traced, designed or claimed here.

## Source of truth

- Public pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`,
  read-only at `/home/home/FireRedRecomp-reference/pokefirered`.
- Runtime: origin/main `df53c77`: `main.lua`, `src/core/*`, `import/*`.
- Facts already in P5-05 are cited, not re-inventoried (register line 88).

## Bounded questions

1. Admission: the C2/C3 predicates, the scene-1 object placement, and which
   current dispatch receives these steps.
2. Whether a scene-1 player can reach Route 2 without crossing C2/C3
   (collision/ledge/object decode of the source layout).
3. The script order from `lockall` to `special StartOldManTutorialBattle`.
   This covers facing turns, waits, message, Quest Log branch and cut-recording.
4. The order after the battle (`waitstate`, `lock`/`faceplayer`, scene-2
   write, Teachy TV), recorded as a dependency on the battle return.
5. The smallest next gate, together with its UNKNOWNs and stops.

## MAY CHANGE

- This task file (new)
- `work/reports/phase5-viridian-old-man-tutorial-trigger-source-discovery.md` (new)

## MUST NOT CHANGE

No runtime, tests, import, battle, workflow, runner, probe, request,
coordination (`work/coordination/**`) or roadmap files. No ROM read, no LÖVE
run, no extracted game text or private paths. No merge. Do not re-open P5-06
C0 or P5-04 projection.

## Acceptance criteria

1. Name the exact next blocker, citing pinned source file:line and runtime
   file:line for every claim.
2. Show that the blocker cannot be avoided on the pre-Cut path, with a
   reproducible source-only decode.
3. Cover the field-side order up to the battle special, and the order after
   the return only as a dependency.
4. Name the battle path as an outside dependency, with no design for it.
5. List the UNKNOWNs explicitly.
6. Propose exactly one smallest next gate (design only), following the P5-06
   precedent, with its stops. The proposal is not dispatch authority.
7. `lua5.1 scripts/check_repository.lua` and `git diff --check origin/main`
   pass, and the diff touches exactly these two files.

## Stop / escalate

Stop at UNKNOWN for anything that needs private data, a different source
revision, battle-lane design or new authority. Finish the unaffected findings.

## Worker evidence — 2026-11-17

- Report: [field-side source lock](../reports/phase5-viridian-old-man-tutorial-trigger-source-discovery.md).
- Branch `work/p5-old-man-tutorial-trigger-discovery-20261117`, base
  `df53c77`; the source checkout's HEAD equals the pin.
- Selected blocker: unhandled scene-1 C2/C3. Proposed next gate: the
  P5-07 field-side tutorial-trigger design, which fails closed at the battle
  special.
- Checks: the repository checker and `git diff --check origin/main` were run
  after staging. Results are in the report receipts. Docs-only; the full suite
  is N/A.
- The Worker does not self-certify. Independent review is required before any
  reconciliation.
