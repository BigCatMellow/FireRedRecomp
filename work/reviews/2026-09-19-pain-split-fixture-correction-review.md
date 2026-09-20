# Pain Split fixture-correction scope review

- Disposition: `PASS` — fixture-correction scope only; not implementation acceptance.
- Reviewer: independent REVIEWER; no implementation or coordination-owner edits.
- Reviewed base: `d793981f950407ee6f469dc50c02e32529cf3cb5`.
- Live recovery: independent `git ls-remote origin refs/heads/main` on 2026-09-19 returned that exact base.
- Failed request: `87d5e72ebd030eb6d547805cb75eebf6f326f848`, guarded run `35410055700`.
- Reviewed artifact: `work/local-runner/requests/phase4-pain-split-effect-20260918-v1.patch`.
- Original artifact SHA-256: `5246b15aee65cfd174930496a9e72a765942f8c9fe838797e6a6c6f7e47ab51a`.
- Prior scope gate: `b1cb14970726f5289b2439a906dcbeff26ad2e28`.

## Finding and independent evidence

The smallest consistent correction is exactly two numeric fixture edits: change
Pain Split's synthetic `flags=51` to `flags=18` in the engine-test hunk, and
change the dedicated ROM-record assertion from `m.flags == 51` to
`m.flags == 18`. Preserve every other byte of the implementation request.
The corrected request, with only these two substitutions and no reformatting,
has SHA-256 `c6170f42df62f45867bbf0c1330584a2c067136ff5811042fbc7d7009856cd69`.
This digest was computed from a transformed read-only stream; no replacement
request or implementation was written during review.

Primary source independently establishes the correction. At upstream
`pret/pokefirered` revision `c75f352304d529f6ba92d4f74b9cf8b5c3810788`,
the [Pain Split record](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/data/battle_moves.h#L2643)
contains only Protect-affected and Mirror-Move-affected flags. The
[flag constants](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/include/constants/pokemon.h#L225)
assign these bits 1 and 4: `2 | 16 = 18`. Decimal 51 would additionally set
contact and King's Rock bits. The upstream master revision was independently
read using `git ls-remote`, then the record and constants were read at the
immutable revision. This agrees with the existing discovery contract; it does
not authorize implementing any flag-dependent state.

The original patch has six changed implementation/test/replay paths, all a
subset of the existing nine-path allowlist. Both the original patch and the
two-substitution stream pass `git apply --check` against the reviewed base.
The engine, scene controller, their tests, and bridge workflow are unchanged
between the failed request revision and this base. The reviewed scope remains
effect 91 alone, with the existing admission, zero-RNG, ordered two-sided HP,
clamp, presentation, and exclusion contract. No behavior hunk needs alteration
to repair the numeric fixture defect. The current workflow still selects the
literal Pain Split route, checks the nine-path allowlist, runs the prescribed
focused/full/verified-ROM/replay sequence, and stages those paths individually.

## Evidence limits and prerequisites

The task/handoff at failure record `068de087f67849a4468e940b35e7c83f1b90c63c`
report private verified-ROM flags 18 and no published implementation. That is
inherited guarded-run evidence, not a ROM observation reproduced by this
reviewer. No local ROM was opened and no corrected ROM/replay result exists
from this review. The independently fetched source supports a corrected
request; it cannot substitute for the required private-ROM execution.

The baseline command `env -u POKEPORT_ROM bash scripts/test_all.sh` exited 127
because `lua5.1` was unavailable in this review environment. No local test
pass is claimed. The Worker needs Lua 5.1 for local checks and the existing
guarded bridge with the supported FireRed US v1.0 SHA-1
`41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc` for acceptance evidence.

## Exact next allowance

Orchestrator may reconcile `P4-PAIN-01` and create the bounded successor
`P4-PAIN-02`, explicitly authorizing one replacement Worker request through
the unchanged `phase4-pain-split-effect` route. Worker may prepare a new
request artifact retaining the failed patch's implementation exactly except
for the two fixture substitutions above. Preserve the original failed
artifact, its failure history, the literal nine-path route, and all acceptance
checks. Any additional behavior or route change requires separate scope
review. Coordination reconciliation remains Orchestrator's responsibility.

The replacement must pass focused checks, full no-ROM checks, the full
SHA-verified-ROM suite including the corrected record assertion, and its
replay before guarded publication; the exact published revision then needs
independent implementation review. This PASS does not accept the implementation,
close the effect, widen admission/healing or excluded state, clear Phase 2's
external-reference blocker, or advance Phase 4 completion.
