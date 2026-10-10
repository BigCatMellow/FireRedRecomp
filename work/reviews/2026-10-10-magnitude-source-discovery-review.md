# Magnitude source discovery — independent review

Verdict: **PASS** for `P4-F1-MAGNITUDE-DISCOVERY`, source discovery only.

## Exact revision and scope

Reviewed the two-path uncommitted draft against
`0255088c934231ecccd087d73386f34ab0cfa5ef` in
`/tmp/firered-p4-magnitude`. Independent GitHub recovery returned that same
main revision. The exact reviewed SHA-256 digests are:

- [Report](../reports/phase4-magnitude-source-discovery.md):
  `af4a9cea7a569aa618349e427601cc412a8412e555f80e1c5476c9f8edf4d70f`.
- [Task](../tasks/phase4-magnitude-discovery.md):
  `c5766d3cde8bbaf2ea836d0efa64a9e5318212335f701e5d23d5fd13a47361c5`.

Only the new report and the task's appended 16-line researcher handoff differ
from the base. No runtime, test, admission, workflow, bridge, coordination,
capability status, ROM, extracted asset, or implementation artifact changed.
This pre-publication review was explicitly dispatched by the Orchestrator;
the committed task/register still say `READY_FOR_WORKER`. I changed neither.

## Material evidence

The independent reference checkout is clean at
`c75f352304d529f6ba92d4f74b9cf8b5c3810788`. Direct inspection confirms:

- The move/effect constants are `222`/`126`. The move record at
  `src/data/battle_moves.h:2889` has nominal power 1, Ground type, accuracy
  100, PP 30, and `MOVE_TARGET_FOES_AND_ALLY`.
- `BattleScript_EffectMagnitude` at `data/battle_scripts_1.s:1679` orders
  cancellation, announcement, PP reduction, first-target selection, magnitude
  calculation, the strength message, then the shared hit loop. The report
  does not confuse its explicit draw with all possible helper RNG consumption.
- `Cmd_magnitudedamagecalculation` at
  `src/battle_script_commands.c:8284` has exactly one `Random() % 100`, the
  stated seven threshold branches, transient `gDynamicBasePower`, level buffer,
  and first non-absent non-attacker scan. An independent read-only comparison
  of the source branches and report table checked all 100 residues: every
  residue belongs to exactly one reported interval with the correct level and
  power. The ranges are 0–4/5–14/15–34/35–64/65–84/85–94/95–99, levels 4–10,
  and powers 10/30/50/70/90/110/150.
- The shared loop at `data/battle_scripts_1.s:1835` establishes the Underground
  multiplier/marker before accuracy, critical, base damage, type calculation,
  and normal damage adjustment. Both success and miss paths reach next-target
  handling. The report accurately separates that multi-target source behavior
  from the proposed one-defender projection.

Project inspection independently confirms `Rng:next16()` advances the matching
LCG and returns its high 16 bits, consistent with `src/random.c` and
`include/random.h` at the source pin. `supportsMove` admits Magnitude through
positive power, while the inventory still classifies it as a candidate.
`resolveMove` currently orders the ordinary `useMove`/accuracy/PP path
differently from Magnitude's script; the subsequent critical/base/type/random
damage sequence is present. Flail/Eruption's local move copies establish the
claimed non-mutating precedent, not authority for a generic framework.

The report preserves `UNKNOWN` for the project level-event/presentation
contract and exact seeded full-turn parity. It explicitly excludes Underground,
foes-and-ally traversal/reselection, doubles/absent-battler state, new
abilities/items, cancellation expansion, visual/message-rendering parity, and
generic dynamic-power abstraction. It does not claim implementation,
admission changes, ROM verification, or completed Magnitude parity.

## Checks and exact next allowance

`git diff --check` passed. Separate no-index whitespace checks of the report
and this review produced no diagnostics (exit 1 denotes the added-file diff).
The 100-residue comparison was source/report analysis only, not game execution.
No full suite, replay, or private-ROM run is required by this research task;
none was performed or inferred.

After publishing the exact reviewed artifacts and reconciling coordination,
the Orchestrator may compile exactly one design-only successor:
`P4-F2-MAGNITUDE-DESIGN`. That design must retain the stated singleton and
exclusion boundaries and settle the observable level event and sequencing.
This PASS does not authorize implementation, tests, bridge routing, replay,
ROM work, another effect, or capability-status advancement.
