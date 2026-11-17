# P5-07 — Viridian Old Man tutorial triggers: field-side source/runtime lock

- Status: `READY_FOR_REVIEWER`. This is research only. It is not a design,
  an implementation or a traversal proof.
- Task: [P5-07 discovery](../tasks/phase5-viridian-old-man-tutorial-trigger-source-discovery.md).
- Runtime: origin/main `df53c7770c1df5884f4c3924e331c5efebe91925`. It contains
  the accepted C0 publication `42cd4fd`.
- Source: clean pret/pokefirered `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
  All source citations use this pin.
- Result: the next blocker is the scene-1 Old Man tutorial coordinate pair,
  C2 (20,8) and C3 (22,8). The runtime does not dispatch them. A scene-1
  player walks north with no tutorial, so the scene stays 1 forever and
  Teachy TV is never offered. The traversal is not blocked, but it takes a
  source-invalid path. Before Cut, crossing C2 or C3 cannot be avoided.
- Outside dependency: the Old Man tutorial battle, entered through
  `StartOldManTutorialBattle`. Its design belongs to the battle lane.

## Next-item selection

- The register and plan name no item after P5-06.
  `RECALIBRATED_DELIVERY_PLAN.md` near-horizon item 4 says to reassess at
  each leaf closure. The P5-06 recovery outcome review
  (`work/reviews/2026-11-15-viridian-roadblock-recovery-outcome-review.md`,
  "Bounded conclusion") accepts bounded C0 only, with no northbound claim.
- **Stale register note:** `work/coordination/TASK_REGISTER.md:94` still shows
  `P5-06-VIRIDIAN-ROADBLOCK-IMPLEMENTATION` as `IN_PROGRESS` / Worker
  Goodall. That is stale after `42cd4fd` and outcome PASS `bd928bc`
  (merged PR66 `794b919`). The HANDOFF "Current relay — 2026-10-28" is stale
  in the same way. This report does not edit either; the Orchestrator
  reconciles them.
- C0's own design excluded C2/C3 (`work/tasks/phase5-viridian-roadblock-design.md:27`).
  P5-05 deferred the tutorial and its gaps as "later work"
  (`work/reports/phase5-viridian-northbound-gate-discovery.md`, section
  "Exactly one next prerequisite").

## Admission (source)

| Entry | x,y | Elevation | Scene var `0x4051` | Script | Source |
| --- | --- | --- | --- | --- | --- |
| C2 | 20,8 | 3 | 1 | `TutorialTriggerLeft` | `data/maps/ViridianCity/map.json:221–229` |
| C3 | 22,8 | 3 | 1 | `TutorialTriggerRight` | `data/maps/ViridianCity/map.json:230–238` |

- Predicate: `src/field_control_avatar.c:1039` (`VarGet(trigger) == (u8)index`)
  and `:1055` (equal elevation, or elevation-0 wildcard). Priority (trainers,
  then on-frame, then coordinate, before warps and wild) and the effective
  `previousElevation` input are already locked in P5-05 ("Selected predicates
  and step priority") and are not repeated here.
- Scene-1 object placement: `data/maps/ViridianCity/scripts.inc:8,17–21` sets
  `LOCALID_TUTORIAL_MAN` (object 4, `map.json:77–91`) to (21,8) with
  `LOOK_AROUND`. C2 and C3 sit on the two tiles beside him.
- Scene 1 is written by `src/core/ViridianParcelStory.lua:75`.

## The tutorial cannot be skipped (collision decode)

`data/layouts/ViridianCity/map.bin` (48×40, `data/layouts/layouts.json:754–763`).
In each u16 block, bits 10–11 are collision and bits 12–15 are elevation. The
behavior is bits 0–8 of the u32 metatile attribute
(`src/fieldmap.c:63–72`); primary metatiles are `< 640` (`include/fieldmap.h:8`).
The decode of rows 0–21 shows the following:

- Only one corridor joins south Viridian (rows 13+) to the north exit (rows 0–5,
  Route 2 `map.json:16–21`): the x20–22 corridor, rows 9–12. Row 9 is open
  only at x20–22. Row 8 is open from x19 to x32, but from row 9 the player can
  step only onto (20,8), (21,8) or (22,8). In scene 1, (21,8) is occupied by
  the tutorial man.
- The west column at x=8 (rows 5–16) has no ledge behaviors (`0x38–0x3B`,
  `include/constants/metatile_behaviors.h:47–50`). It joins row 5 only past
  the Cut tree at (18,5) (object 8, `map.json:136–149`, `EventScript_CutTree`).
  Before Cut it is not a bypass.
- The gym-front region (row 11, x29–41) connects only to the north.
- So every pre-Cut northbound path in scene 1 completes a step on C2 or C3.
  `LOOK_AROUND` turns in place and does not move off (21,8)
  (`map.json:84`; the projection sets type 1).

Reproduce from the source checkout, with no ROM involved:

```
python3 -I -c "import struct;d=open('data/layouts/ViridianCity/map.bin','rb').read();
[print(y,''.join('#' if (struct.unpack_from('<H',d,(y*48+x)*2)[0]>>10)&3 else '.' for x in range(48))) for y in range(22)]"
```

Ledge check: look up `metatile_attributes.bin` for the primary `general`
tileset and the secondary `viridian_city` tileset, and mask `0x1ff`.

## Field-side order up to the battle special (source)

`data/maps/ViridianCity/scripts.inc:202–229`:

1. `lockall` (`:203`/`:214`; `src/scrcmd.c:1195–1207`). This freezes objects
   and waits for the player's movement to finish.
2. Text color. Then the tutorial man walks in place faster toward the player:
   **left** for C2 (`:205`), **right** for C3 (`:216`). Then `waitmovement 0`.
3. The player walks in place faster toward him: **right** for C2 (`:207`),
   **left** for C3 (`:218`). Then `waitmovement 0`. The movements are
   `data/scripts/movement.inc:28–30,36–38`. Neither turn moves anyone off
   their tile.
4. `call DoTutorialBattle` (`:209`/`:220`): `msgbox`, then `closemessage`
   (`:225–226`).
5. `goto_if_questlog EventScript_ReleaseEnd` (`:227`). This is an excluded
   context, as in P5-05.
6. `special QuestLog_CutRecording` (`:228`). This is an excluded context
   with no field effect needed here.
7. `special StartOldManTutorialBattle` (`:229`). This is the **outside
   dependency boundary**. `src/scrcmd.c:99–106` is not a wait.

On return the caller runs `release` (not `releaseall`), then `end`
(`:210–211`/`:221–222`; `src/scrcmd.c:1243–1255`).

## After the battle — dependency on the battle return only

Order at `scripts.inc:230–237`: `waitstate` (`src/scrcmd.c:127–130`), then
`lock`, `faceplayer` and `msgbox`, then the **scene-2 write** (`:234`), then
`giveitem ITEM_TEACHY_TV` (`:235`), then the final msgbox, then `return`.
P5-05 already locks the rest: the field return
(`FieldCB_ContinueScriptHandleMusic`), item-capacity failure without
rolling back scene 2, and the Quest Log bypass. None of it is repeated here.
None of these steps can run until the outside dependency gives control back
to the waiting script. The scene-2 write must not be reached by skipping the
battle.

**Post-battle persistent state is UNKNOWN.** That covers party, bag, flags
and anything else saved. It depends on the battle-lane result. This report
does not assume the party is fully restored or that anything is rolled back
after the battle. A field-side design must not assume either.

## Outside dependency (not traced, not designed)

The battle-lane work covers `StartOldManTutorialBattle`, the Old Man battle
controller, the temporary bag, the forced capture, the shared controller and
return-path writes, the RNG, and the return callback. P5-05's
"Tutorial-specific path" table records the source anchors. The battle lane
owns their design, and this report makes no claim about any of it.

There is an initial battle-lane finding (rina, 2026-11-17, **not yet
reviewed**). The tutorial entry does not itself back up or replace the party.
The forced capture and the bag being restored before the throw are confirmed.
The shared controller and return-path writes, and the RNG, are still
unresolved. This report records the finding only and builds nothing on it.

## Current runtime gap (runtime file:line at `df53c77`)

| Seam | Runtime state |
| --- | --- |
| Completed-step dispatch | `main.lua:1081–1093`: after a completed step, `tryViridianRoadblockAt` runs first. On `not_selected` it falls to EarlyStory, connection, warp, trainer, then wild. |
| C0 classifier | `src/core/ViridianRoadblock.lua:74,77`: `not_selected` unless the step is exactly (22,11) with scene 0. C2/C3 are never selected. |
| EarlyStory | `src/core/EarlyStory.lua:72,91,96`: only Pallet and lab branches, so Viridian returns nil. |
| Object placement | `src/core/ViridianOldManProjection.lua:46–47` projects the man to (21,8), type 1, at scene 1. Placement only, with no trigger. |
| Field ownership precedent | `main.lua:821–931` holds C0's own presenter, lock, owner-conflict check (`:825–831`), teardown/refusal and task. It is C0-specific (state machine `:889–931` hard-codes (22,11)→(22,12)). It is not a shared script lock or a tutorial runner. |
| Player movement | `src/core/PlayerMovement.lua:209–217` has only `startScriptedDown`. It has no scripted walk-in-place facing primitive. Facing is set at `:179`. |
| Script VM | `import/ScriptBytecode.lua:379` decodes `waitstate` (0x27) as `unimplemented`, as executed below. |
| Battle seam | No Old Man tutorial entry point is in the runtime (grep below). |

Net effect: at scene 1 a completed step on (20,8) or (22,8) reaches
`rollWildEncounterAt` (`main.lua:1093`) with no lock, no turns and no
tutorial. That is the source-invalid path.

## Proposed smallest next gate — design only, not dispatch authority

Proposed ID: `P5-07-VIRIDIAN-TUTORIAL-TRIGGER-DESIGN`. It mirrors P5-06's design gate
(`work/tasks/phase5-viridian-roadblock-design.md`). Its outcome: one C2/C3-specific
field-side design. The design covers four things:

- admission at a completed ordinary step, with scene 1, (20,8)/(22,8) and
  elevation 3, following C0's classify contract;
- `lockall`, then the man's in-place turn and wait, then the player's in-place
  turn and wait;
- the message and close;
- a **fail-closed refusal at the battle-special boundary**. The refusal must
  write no scene 2, give no Teachy TV and silently pass no one north, until
  the battle lane provides an accepted Old Man tutorial entry and return
  contract.

The design must also state the following:

- how the gate stays separate from C0's state machine;
- the trainer-priority order at C2/C3;
- re-entry while scene stays 1;
- literal oracles for both mirrored directions.

Its allowlist is two docs paths (the design task and the design report). It
adds no runtime or battle paths.

Stops: any need for battle-lane design, a generic script VM, Quest Log, or
changes to C0/projection behavior. Reaching scene 2 or giving Teachy TV is
out of scope until the dependency is accepted.

## UNKNOWNs

- **`lock`/`faceplayer` target after `waitstate`.** These act on
  `gSelectedObjectEvent` (`src/scrcmd.c:1143–1151,1209–1228`). The
  coordinate path (`src/field_control_avatar.c:618–640`) does not assign it.
  Assignments exist only at `src/field_control_avatar.c:426,452`,
  `src/battle_setup.c:783,834` and `src/field_specials.c:1544`. So which
  object turns on return is unresolved. It may be a stale earlier selection,
  or whatever the battle return path sets.
- **`lockall` paired with `release`.** The script pairs `lockall` with `release`
  instead of `releaseall`. Both call `UnfreezeObjectEvents`
  (`src/scrcmd.c:1239,1253`), and `release` also clears the selected object's
  held movement. Any visible difference is unverified.
- **Frame timing.** The exact frame timing of walk-in-place-faster and of the
  message is not derived here.
- **Whether later progression reads scene ≥2 or Teachy TV.** Not traced
  beyond the NPC branch that P5-05 recorded (`scripts.inc:97–104`).
- **Post-battle state.** The party, the bag and any other saved state after
  return are unknown. They depend on the battle-lane result; see the
  unreviewed initial finding above. No full restoration or rollback is
  assumed.
- **The outside dependency's whole contract.** Its entry, return, RNG and
  abnormal recovery are unknown here by design.

## Receipts (executed 2026-11-17; no ROM, no LÖVE)

- In the source checkout, `git rev-parse HEAD` equals the pin, and
  `git status --short` is empty.
- Numbered reads of `scripts.inc:1–30,196–237`, `map.json:16–30,62–91,136–149,202–238`
  and `scrcmd.c:1143–1156,1195–1256`. Grep for `gSelectedObjectEvent = `.
- The layout collision and behavior decode above (python3 -I). It showed the
  single x20–22 corridor, the Cut tree at (18,5) and no ledges.
- Runtime: `lua5.1 -e '…ScriptBytecode.decode(string.char(0x27),0x08000000)[1].op'`
  printed `unimplemented`.
  `grep -rniE "old.?man.?tutorial|teachy|TutorialTrigger" --include=*.lua`
  found no runtime hit outside tests.
- After staging the two files: `lua5.1 scripts/check_repository.lua` PASS
  (336 tracked Lua, 417 tracked Markdown, 1370 local targets), and
  `git diff --check origin/main` PASS. The diff is exactly 2 files.
