# Viridian C0 roadblock design — independent review

- Verdict: **PASS** for the bounded design and future evidence proposal.
- Exact PR #45 revision: `a7e12e0023a92b1790e3391ac64657f42e54e486`.
- Dispatch base: `d59f28f844ec9a45abec0f307bae92525c932501`;
  unchanged runtime baseline: `75b49f3a3cbeb877137372a40a0b92973172fad1`.
- [Task](../tasks/phase5-viridian-roadblock-design.md) and
  [report](../reports/phase5-viridian-roadblock-design.md).
- Public source independently verified clean at
  `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

## Material findings

No correction is required within the existing P5-06 criteria. Independent
source and production-owner reconstruction agrees with the report:

- The selected C0 script is exactly lockall, male text style, default message,
  explicit close, one PLAYER walk-down movement, waitmovement0, releaseall and
  end; its movement list is normal-down then step-end
  (`data/maps/ViridianCity/scripts.inc:188–201`). It performs no scene, flag,
  item, party, RNG or reward write. The report does not copy ROM text.
- The message has one paragraph-clear between two pages and then terminates
  (`data/maps/ViridianCity/text.inc:39–42`; `include/characters.h:177–182`).
  Paragraph clear accepts NEW A/B and resets the window/cursor
  (`src/text.c:550–585,796–803,858–870`). Final wait checks NEW A before NEW B;
  the directional shortcut cannot apply because return resumes at
  closemessage, not release (`src/scrcmd.c:1313–1318,1351–1363`). The proposal
  therefore correctly rejects held input as a fresh page/final press and
  isolates a press from both reveal and acknowledgment.
- Reveal acceleration is latched, not reveal-all: NEW A/B during a pending
  delay consumes that update and enables subsequent HELD A/B delay clearing
  (`src/text.c:629–656`). The valid slow/mid/fast delays are 8/4/1
  (`src/new_menu_helpers.c:27–32,423–435,658–663`). The proposed presenter owns
  that source latch across its two-page message while preserving separate page
  and final NEW presses. No Mart A-only/revealAll behavior is reused.
- Script movement is installed directly as a held action and waits for an
  existing action to finish; normal-down advances coordinates without calling
  ordinary collision or ledge admission (`src/script_movement.c:20–28,
  202–225`; `src/event_object_movement.c:5049–5061,5309–5348,5649–5662`).
  Step-end freezes/reports completion, waitmovement joins the last moved object,
  and releaseall clears finished movement/unfreezes objects
  (`src/scrcmd.c:983–1019,1231–1240`). The narrow scripted-down API and explicit
  collision/ledge mutation witness match that boundary.
- Script execution retains field-control ownership until end. Native waits
  resume bytecode on a later script pass, and only script termination unlocks
  field controls (`src/script.c:82–110,326–340`). CB1 field input precedes CB2
  script/tasks/sprites (`src/overworld.c:1394–1487`), so source release cannot
  retroactively leak input in its frame. The proposed start-of-tick ownership
  snapshot is the necessary adaptation to this runtime's opposite order
  (`main.lua:4497–4512`), with next-tick held-direction recovery kept separate.
- Source event priority is trainer, on-frame, then completed-step coordinate
  before warp and later walking/encounter work
  (`src/field_control_avatar.c:193–248,618–640`). Pinned Viridian has only an
  ON_TRANSITION map hook (`data/maps/ViridianCity/scripts.inc:1–3`). The
  C0-specific trainer-first tri-state boundary restores only this selected
  case and leaves unrelated Pallet/lab and other-map order unchanged.
- Current production ownership matches the integration proposal: completed
  movement dispatch currently orders EarlyStory/connection/warp/trainer/wild
  in `main.lua:822–845`; PlayerMovement owns effective elevation and invalidates
  non-normal motion (`src/core/PlayerMovement.lua:64–134,170–235`); map loads
  change generation (`main.lua:2290–2323`); input is sampled after scheduler
  tasks (`main.lua:4497–4512`); and existing dialogue rendering selects among
  bounded printers (`main.lua:3113–3160`). This supports one narrow presenter/
  adapter without generic VM, renderer, save or other-map expansion.
- Admission distinguishes actual event elevation 3, event elevation-0 wildcard,
  known player E0 and unknown E. It requires the decoded map/position/C0
  identity, integer scene storage/value and valid effective elevation; selected
  malformed or unsupported state refuses rather than silently falling through.
  Nonselected entries/maps retain existing behavior. Scripted movement remains
  unqualified elevation provenance, and re-entry depends on a later qualified
  ordinary step rather than a persistent scene write.

The report proposes exactly one cohesive nine-path implementation: one new C0
module, `PlayerMovement.lua`, `main.lua`, four tests, one dedicated replay
wrapper and one implementation task. Production integration tests must traverse
the real completed-step dispatcher, input update, presentation, forced movement
and release barrier. The route allowlist equals those nine paths. The separate
workflow/bridge configuration boundary is identified without being implemented
or treated as ready.

## Actual independent evidence

- Exact range `d59f28f..a7e12e0` changes only the two Worker-authorized paths:
  the new design report and task status/evidence. No runtime, tests, save,
  assets, renderer, workflow, bridge, runner or coordination file changed.
- `git diff --check d59f28f..a7e12e0`: PASS.
- Clean review working/staged `git diff --check`: PASS.
- Repository checker with
  `PATH=/home/home/.local/share/firered-toolchain/bin:$PATH`: PASS,
  321 tracked Lua / 371 tracked Markdown / 1246 local targets before this
  review was added.
- Live GitHub query independently confirmed PR #45 open at exact `a7e12e0`,
  exactly two changed files and no prior reviews. Runs
  [39094949700](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/39094949700)
  (pull_request) and
  [39094947560](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/39094947560)
  (push) both completed successfully at that exact SHA; each passed repository
  checks and the no-ROM suite.
- Current coordination was independently read as `READY_FOR_REVIEWER`. The
  later `c1916f9`/PR #46 checkpoint is coordination-only and does not alter the
  reviewed PR #45 head.

The parent 193-file no-ROM result is attributed carried evidence. Per the docs
contract, no local full suite was rerun. No ROM, LÖVE runner, replay, private
bridge, probe or request was executed; all such evidence in the report is
explicitly future and guarded. No extracted dialogue, screenshot, cache or
other prohibited content entered this review.

## Smallest correction, next allowance and retained limits

Smallest correction: **none**.

The Orchestrator may reconcile this design PASS, obtain final review-head public
CI, and merge/adopt only the exact nine-path C0 proposal. The next bounded
allowance is to compile the separately identified fail-closed bridge
configuration/probe prerequisite; implementation/request authority still waits
for that package's own independent review and successful probe. This review
itself authorizes neither runtime edits nor a runner request. Any later
implementation must retain the module-wide two-page speedup latch,
NEW A/B page/final isolation, trainer-before-C0 ordering, direct scripted walk,
release-tick input barrier, refusal boundaries and nonpersistent scene state
specified here.

No C1/C2/C3, catching tutorial, Teachy TV, generic VM/scheduler, shared renderer,
save/schema, collision architecture, other map, normal-traversal proof, visual/
male-font/audio parity, route readiness, gameplay acceptance or Phase 5/7
completion is accepted. Existing projection/elevation work stays terminal;
guarded SHA-ROM fixture and deterministic runtime witness remain future gates.
