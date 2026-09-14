# Task: Phase 4 move admission-matrix discovery

- Status: `ACTIVE`
- Type: `PHASE 4 / BATTLE RULES / READ-ONLY DISCOVERY`

## Goal

Produce a source-backed inventory of positive-power FireRed move-effect
families that `BattleEngine:supportsMove` currently admits, distinguishing the
families the engine actually models from those that would incorrectly fall
through its ordinary damage path. Select at most one smallest, independently
testable next implementation leaf; do not implement it in this task.

## Required evidence

1. Enumerate the current admission predicate and every explicit engine effect
   family, with source locations.
2. Join that inventory to verified-ROM move records and FireRed battle-effect
   semantics, identifying reachable positive-power unsupported families.
3. State whether each candidate is safe to defer, must be blocked behind an
   unrepresented prerequisite, or is eligible as the next bounded leaf.
4. Write conclusions only to this task, `STATE.json`, `HANDOFF.md`, and the
   execution map; preserve the Phase 2 external-reference blocker.

## MUST NOT CHANGE

No battle behavior, move admission predicate, UI, AI, trainer layouts, held
items, main wiring, generated data, or bridge configuration. Discovery is not
permission to silently reject or implement a move family.
