# P4-02-ROUTE independent configuration review

- Disposition: `PASS` — exact bounded inventory route configuration only.
- Reviewed base: `82af910`.
- Configuration revision: `24f39c424347425be9836e16d529c7706641aa93`.
- Reviewed range: `82af910..24f39c424347425be9836e16d529c7706641aa93`.
- Local review relay: `03535722f848bb44470f98b41d0fe5bcef34be80`, `READY_FOR_REVIEWER` for `P4-02-ROUTE`.
- Authority: existing route task and independently accepted readiness contract; no new acceptance or scope added by this review.

## Findings against existing acceptance

The exact range changes only the authorized workflow, route documentation, and
route-task evidence record. The workflow adds five case branches totaling 18
lines. An independent comparison verified these are insertions only and that
all prior workflow text remains unchanged. Existing route behavior, global
permissions/triggers/concurrency, trusted-main dispatch, one-request validation,
ROM SHA verification, shared full suites, and publication behavior are preserved.

The selector recognizes the new `phase4-move-effect-inventory` request/probe
prefix with existing filename conventions. The target-validation branch accepts
exactly these three literal paths, and publication stages the same three
individually when present:

1. `tests/phase4_move_effect_inventory_test.lua`
2. `work/tasks/phase4-move-effect-inventory.md`
3. `work/reports/phase4-move-effect-inventory.md`

No source, workflow, coordination, review, or additional path is admitted by
the new branch. Existing unknown-selector and unauthorized-target rejection
remain before patch application. The Pain Split route is unchanged.

Focused execution is exactly the selected Lua interpreter invoking
`tests/phase4_move_effect_inventory_test.lua`. The reviewed readiness correction
is preserved: focused execution may skip without inherited ROM state; the full
verified-ROM suite explicitly receives `steps.rom.outputs.path` through
`POKEPORT_ROM` and must execute the inventory test without skipping for the
later inventory gate. No shared environment or suite command was changed.

The new runtime branch explicitly reports that no replay applies because this
inventory changes no runtime behavior. Every other runtime case is unchanged.
The documentation accurately records the allowlist, focused-ROM limitation,
mandatory full-ROM evidence, and no-replay reason. The task still requires
independent configuration PASS before a separate substrate-only probe and
does not claim probe, inventory, gameplay, or phase completion.

## Independent checks and evidence limits

Checks operated on workflow contents fetched from the exact configuration
revision, not an unpinned working-file copy:

- YAML parsed successfully; `bash -n` accepted all 12 run blocks.
- Executing the actual selector accepted the intended inventory request and
  probe filenames; unknown request/probe prefixes and an unsupported extension
  were rejected.
- Executing the actual validation case accepted all three literal targets;
  rejected seven unauthorized source/workflow/coordination/suffix/traversal/
  nested-path/wildcard examples; and rejected an unknown route.
- Direct focused/staging inspection matched the exact command and three paths.
  Executing only the new replay case produced its explicit no-replay message.
- Independent text comparison proved precisely five insertions and no changes
  to prior workflow text; `git diff --check` passed for the exact range.

Worker recorded before/after 149-file no-ROM PASS. That suite was not repeated
in this configuration review because runtime and test code are unchanged;
the targeted configuration checks above were independently reproduced.
No ROM was opened, no workflow job or probe was dispatched, and no patch or
publication branch was executed by the Reviewer. No prohibited game content
appears in the three-file diff.

Live GitHub was recovered independently during review; the initial query
returned Pain Split implementation `a739ddc88cb44a33d5e6025e619cf1df3fe6a1a8`.
The final independent query returned `03535722f848bb44470f98b41d0fe5bcef34be80`:
Orchestrator had published the authorization, configuration, and pending-review
relay while leaving the probe gated. The exact configuration range is unchanged;
this review accepts the pinned configuration revision, not unrelated changes.

## Exact next allowance

Orchestrator may reconcile this PASS and authorize the task's separate one-file probe
`work/local-runner/probes/phase4-move-effect-inventory-route-20260920.probe`.
Its guarded run must verify the trusted checkout, inventory selector, Lua
toolchain, and private supported-ROM SHA while skipping patch/tests/publication.
Only a successful probe unlocks the bounded inventory request. That later
request still needs its non-skipped full-ROM aggregate evidence and independent
review. This PASS closes neither P4-02's inventory nor any capability phase;
Phase 2's external-reference blocker remains unchanged.

Reviewer wrote only this report; coordination, task edits, configuration,
publication, and probe execution remain with their assigned owners.
