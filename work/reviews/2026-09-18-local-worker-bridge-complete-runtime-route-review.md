# Independent review: complete Phase 3 Local Worker Bridge route

- Verdict: `NEEDS_FIX`
- Reviewed subject revision: `41ca7eb184cdabe6e247f442ab95b6b0037d98be`
- Route implementation ancestor: `f2c240e7a94f7a2329771b0ef06d531eabab64e6`
- Active task: `work/tasks/local-worker-bridge-complete-runtime-route.md`
- Scope: infrastructure/execution-substrate review only

## Evidence confirmed

1. The subject changes only task and coordination records. The requested route
   implementation is an ancestor at `f2c240e7`, and its workflow/procedure
   surface is unchanged through the subject revision.
2. The workflow triggers only on `push` to `main` for controlled request/probe
   paths. It has no `pull_request` or `pull_request_target` trigger, and its
   self-hosted job remains explicitly labelled.
3. Request discovery requires exactly one controlled request/probe. The
   `phase3-complete-runtime-exit-replay` selector is explicit; independent
   deterministic checks recognized both its `.probe` and `.patch` forms and
   rejected an unknown route.
4. The route has an exact five-file allowlist, explicit focused-test command,
   no-ROM suite, verified-ROM suite, runtime replay command, and explicit
   five-file publish staging. The suite/replay steps precede publish.
5. The exact FireRed US v1.0 SHA-1
   `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc` remains fail-closed before
   probe or ROM-backed patch execution. Both locally available candidate ROMs
   match that hash; `env -u POKEPORT_ROM bash scripts/test_all.sh` independently
   passed all 143 files. No complete-runtime focused test or replay exists yet,
   as expected before the downstream evidence task.
6. No ROM, BIOS, generated cache, extracted asset, gameplay/runtime change,
   permission change, or public-PR execution path appears in the reviewed
   subject or route implementation.

## Required correction

The target validator does not validate **every** patch target before
`git apply`. It derives `targets` solely from `--- a/...` and `+++ b/...`
lines. A valid mode-only `diff --git a/<unauthorized> b/<unauthorized>` has no
such lines, so a mixed patch containing one allowed textual target can pass the
allowlist loop while `git apply` also applies the unvalidated mode-only target.

This violates the active task's explicit invariant that every patch target be
checked against the hard-coded task allowlist before application. The smallest
in-scope fix is to derive and validate both paths of every `diff --git` header
(and reject malformed/unparseable headers) before `git apply`, while retaining
the existing exact allowlists and route/test/publish ordering. Add a
non-gameplay validation that demonstrates rejection of an unauthorized
mode-only target alongside the existing recognized-route/unknown-route checks.

## Verdict

`NEEDS_FIX`

The missing validation is concrete and repairable entirely within the current
bridge-maintenance task. The complete-runtime evidence task must not return to
Worker until the correction receives a fresh independent review.
