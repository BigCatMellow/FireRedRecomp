# Lua 5.1 runner-recovery probe result

- Task: `RUNNER-LUA5-RECOVERY`
- Probe revision: `992c0719e90e7319e607b9829d4753570f4507c3`
- GitHub run: `37554725384`
- Result: `BLOCKED — private ROM unavailable to the runner`

## Evidence

The independently authorized metadata-only probe completed its trusted
checkout, request identification, explicit `runner-readiness` route selection,
and `Verify local toolchain` step. The workflow reported Lua 5.1.5.

It then failed in `Locate and verify private FireRed ROM` before hashing or
reading a ROM. `POKEPORT_ROM` was unset and the configured private default
tree did not contain `pokefirered.gba`. A local read-only filename check under
the runner's ordinary Documents/Games locations likewise found no FireRed ROM
candidate. No path, credential, ROM bytes, extracted content, or derived
artifact is recorded here.

## Boundary and consequence

This is substrate evidence only. It proves the Lua repair but provides no ROM
verification, Restore HP implementation, P5 readiness, gameplay, or behavior
evidence. The one probe authorized by `RUNNER-LUA5-RECOVERY` is exhausted; do
not retry it or revive either exhausted P4/P5 run.

The exact unblock is operator-side: make a legally owned FireRed US v1.0 ROM
available to the service either at the workflow's configured private default
location or through its private `POKEPORT_ROM` environment, without committing
the file or revealing its path. A separately bounded recovery decision is
required before another guarded execution.
