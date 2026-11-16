# Frozen Balance Package — Category / Overlay Infrastructure

- Task ID: `BAL-01-INFRA`
- Role: `WORKER`
- Lifecycle: `READY_FOR_REVIEWER`
- Branch: `work/frozen-balance-package`
- Base: `main@e80f9f2cffde02a7987d5c55b45f8a7cd3b834d2`
- Human authority: explicit 2026-09-28 request to review the FireRed notes and continue the work, following the prepared FireRedRecomp target binding
- Frozen specification: `BigCatMellow/Pilot_Projects` PR #14, `integrated_player_package_v1.csv` blob `ed4c75e54435f4b8e8889b47fd8e1c292a8a705f`

## Objective

Create only the target capability needed to represent the frozen rebalance without rewriting imported FireRed US v1.0 ROM truth: an immutable balance overlay plus a per-move category-resolution seam with exact vanilla fallback.

## MAY CHANGE

- `src/core/BalanceOverlay.lua`
- `src/core/BattleFormulas.lua`
- `tests/balance_overlay_test.lua`
- `tests/battle_formulas_test.lua`
- `docs/balance/FROZEN_BALANCE_TRANSLATION.md`
- this task file

## MUST NOT CHANGE

- ROM importers or decoded ROM records
- trainer parties, trainer AI, encounters, economy, TM compatibility/acquisition
- battle move effects outside category selection
- supported-ROM policy
- frozen package values
- held/non-promoted candidates
- capability/phase status
- release/distribution state

## Acceptance

1. Unoverridden moves retain exact Gen-III type-based category behavior.
2. A derived move may explicitly select physical or special damage stats without changing its elemental type.
3. Overlay application cannot mutate imported move or learnset records.
4. Unsupported move-override fields fail closed.
5. Repository no-ROM tests and repository checks pass at the exact implementation revision.
6. An independent Reviewer checks the exact revision before this task is closed.

## Worker result

Implementation is published on draft PR #1. No completion claim is made. Public CI had not produced a run at the initial check, and this environment did not provide a local checkout/toolchain execution path, so acceptance item 5 remains pending. Route the exact PR head to an independent Reviewer after CI/test evidence exists.

## Next eligible work

Do not translate the frozen move-value or learnset rows until this infrastructure slice passes its target tests/review. The next slice must consume the canonical frozen package, including Giga Drain **60 BP / 10 PP**, Aurora Beam **70 BP**, Seaking Waterfall 38, and the exact stage-mirroring requirements.
