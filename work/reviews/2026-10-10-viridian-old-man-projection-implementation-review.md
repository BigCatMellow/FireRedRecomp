# Viridian Old Man projection implementation — independent review

Verdict: **PASS** — bounded pre-spawn Viridian local-ID-4 projection matches
the accepted design and five-path authority.

- Reviewed implementation: `51ca31327de4bcfaa2a79615a62907be6243e6a0`.
- Authority: [P5-04-OLD-MAN-PROJECTION-RECOVERY](../tasks/phase5-viridian-old-man-projection-recovery.md).

I reviewed this isolated-worktree commit from independent context and authored
only this review file. Its five changed paths exactly match the bridge route:
the helper, `main.lua`, focused test, implementation task, and report.

`ViridianOldManProjection.apply` admits only map `3*256+1`, one normal local
ID 4 template with base graphics 240, and a session getter for `0x4051`. It
copies only that selected template and leaves the decoded list, all unrelated
objects, session state, scene variable, flags, RNG, and generic dynamic-graphics
policy unchanged. It fails closed for wrong/missing/ambiguous template state,
missing/failed session access, and non-integer, negative, or non-finite scenes.
Scene 0 yields graphics 34/(21,11)/movement 8; scene 1 yields
32/(21,8)/1; scene >=2 uses graphics 32 while retaining decoded position and
movement type.

The sole integration occurs after decode/hide filtering and before
`ObjectEventState.new` in `loadMapObjectEvents`. It does not create a script
callback, VM/decoder hook, dynamic resolver, renderer, save mutation, tutorial,
traversal, or generic world-state mechanism. Refusal logs and preserves normal
NPC construction; hidden objects remain absent.

Independent checks in this worktree passed: focused no-ROM test `115 passed,
0 failed`; `scripts/test_all.sh` in no-ROM mode `153 test files` PASS; Lua
syntax check and whitespace check PASS. The report correctly limits these to
synthetic/pre-spawn evidence, names no private data, and makes no playable
Viridian, traversal, rendering, or Phase 5 completion claim. Guarded
focused/no-ROM/SHA-ROM evidence and separate outcome review remain required
before reconciliation.
