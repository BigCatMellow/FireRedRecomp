# Task: source-exact trainer ability-history record/query helper

- Task ID: `P4-AI-ABILITY-HISTORY-HELPER`
- Status: `READY_FOR_WORKER — isolated native helper only`
- Base: current main `49d0f4531ed067370a3024deabcbeb7dc564c597`.
- Goal: implement the independently reviewed smallest prerequisite for future Brock AI: native record/query semantics and injected species inputs with deterministic tests, without routing live AI or recording battle events.
- Source: [ability-history design](../reports/phase4-ai-ability-history-design.md), [independent review](../reviews/2026-10-31-ai-ability-history-design-review.md); pret pin `c75f352304d529f6ba92d4f74b9cf8b5c3810788`, BattleHistory/RecordAbilityBattle/Cmd_get_ability.
- Accepted review notes: scoped guard families are complete, not all source mechanics; raw count/filter precision does not imply more coverage; Rock Head record excludes Struggle. Missing Wonder Guard/Rock Head/direct-drain Liquid Ooze and other producers remain live-parity exclusions, not a blocker to this unattached helper.
- Risk: medium, source RNG precedence and side-vs-battler ownership. No behavior entry point changes.

## MAY CHANGE

`src/core/TrainerAbilityHistory.lua` (new); `tests/trainer_ability_history_test.lua` (new); this task (source lock/evidence only).

## MUST NOT CHANGE

No existing engine/AI/bridge/controller/main/formulas, event producers, battle-start draws, save/import/inventory, workflow/runner/requests/probes, canonical coordination, phase state, ROM access/search, push/merge or live routing. This module has no require/call sites in production yet. Do not correct unrelated existing AI code.

## Acceptance

1. Constructor receives a native species lookup and begins with zero side-owned ability history. API explicitly names source sides0=player,1=foe; do not key by party index/active battler. Record only player-side ability, including source zero-write semantics, with no RNG. Foe record is a no-op. Return no mutable internal history table.
2. Query takes side, current species/actual ability and injected shared RNG. Foe-side returns actual ability with no history/species access/draw. Player precedence: nonzero recorded history; then actual Shadow Tag/Magnet Pull/Arena Trap; then current species abilities. Two nonzero choices independently draw `next16()%2` on every query (odd first, even second); one nonzero choice has no draw. Preserve source zero-first odd fallback. Never save a guess or substitute the current actual ability for unknown knowledge.
3. History persists when queried for replacement species and remains authoritative even over a new trapping ability until explicitly overwritten; a fresh object represents fresh battle setup. Add no live reset/switch hook or startup RNG. Do not assume that eventual source battle setup has zero draws; it is outside this helper.
4. Do not invent missing species/ability inputs. Document and reject invalid native arguments when required; precedence paths that do not require species data must not query it. Do not mutate lookup records/battlers or own RNG. Exact API signatures may be chosen by Worker and documented, provided these explicit semantics are preserved.
5. Source-derived tests cover independent guesses and exact draws, both sides, all precedence combinations, zero writes, missing species on required path, one/zero-first/two abilities, changed species/actual ability, no cached guesses, and separate fresh histories. Source citations lock each branch; independent oracle values must not be read from implementation.
6. Baseline and final full no-ROM suite; focused helper, existing TrainerAI/EarlyRivalAI regressions, repository checker, whitespace. Freeze exact local commit for independent review; do not self-approve or mark live AI/phase parity.

Stop for unknown source behavior, required unlisted file or live hook/state/architecture change. No generic framework or event-bus design. This is a standalone source-known building block; later producer wiring and Brock route require separate authority/review and applicable runtime evidence. Parent may run it alongside H1 review/V4b metadata work because paths, dependencies, and evidence gates are independent and this package changes no production entry point.
