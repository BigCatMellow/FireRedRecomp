# Independent TrainerAbilityHistory implementation review — 2026-10-31

Verdict: **PASS** for the standalone helper at exact `72bc55d31643f98c81cd3dc6526f4c67867cade1`, implementation base/contract `3352635`, original main base `49d0f4531ed067370a3024deabcbeb7dc564c597`. Reviewed clean isolated worktree `/home/home/FireRedRecomp-ability-history` against `work/tasks/phase4-trainer-ability-history-helper.md`. Worker is separate from this Reviewer.

Scope: `git diff 3352635..72bc55d` changes only the new 81-line module, new 162-line test, and task evidence. Existing runtime/AI/engine/bridge/controller/formulas, production call sites, ROM/import/save and coordination are untouched. `rg` across `src` and `main.lua` finds the helper only in its own definition. The design/review documents already belong to the authority base, not the Worker implementation diff. No prohibited assets/cache appear.

Independently reread the actual source writer/reader and trapping IDs at pret pin `c75f352304d529f6ba92d4f74b9cf8b5c3810788`: `battle_ai_script_commands.c:481-485,1138-1195`; `constants/abilities.h:27,46,75`. Implementation conforms:

- Explicit source side0 writes include zero; side1 writes are no-ops, without touching ability/species/RNG. Side1 query returns actual ability before history/species/RNG access.
- Player query strictly prioritizes nonzero history, then actual 23/42/71, then current species candidates. Bypassed native arguments are not validated or accessed. Required native IDs/pairs/RNG are rejected rather than guessed or substituted.
- Two nonzero candidates call the injected shared RNG once **per query**, including equal candidates; odd selects first, even second. Single first, zero-first fallback and both-zero branches consume no draw. No cached guess or candidate record; no RNG ownership/seeding.
- Closure-private state exposes only methods; recording returns nil. Stale knowledge survives species/actual changes and separate objects start fresh. No replacement hook/startup draw or live state acceptance is introduced.

Tests use literal source-derived synthetic oracles rather than implementation-returned expectations. They meaningfully pin all precedence paths, exact lookup/draw counts, every trapping ID, zero overwrite, foe no-op, native validation, changed species, independent objects and unchanged input records. Additional independent adversarial Lua probes (15 assertions, executed from stdin without repository writes) verified throwing species callbacks are bypassed; invalid player record preserves previous history; malformed foe record is inert; adding public fields cannot change private knowledge; external interleaved RNG draws affect subsequent guesses; mutated provider candidates are reread; and fresh both-zero input does not substitute actual ability. No finding requires a correction.

Independent commands/results at the frozen head:

```text
env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY PATH=toolchain:$PATH bash scripts/test_all.sh
  PASS: 203 files (no-ROM); /tmp/firered-ability-history-independent-suite-20261031.log
env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY PATH=toolchain:$PATH lua5.1 tests/trainer_ability_history_test.lua
  96 passed
env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY PATH=toolchain:$PATH lua5.1 tests/trainer_ai_test.lua
  7 passed
env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY PATH=toolchain:$PATH lua5.1 tests/early_rival_battle_test.lua
  17 passed
env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY PATH=toolchain:$PATH lua5.1 scripts/check_repository.lua
  PASS: 332 tracked Lua, 396 tracked Markdown, 1315 local targets
git diff --check 3352635..72bc55d
  PASS
git status --short; git rev-parse HEAD
  clean; 72bc55d31643f98c81cd3dc6526f4c67867cade1
```

Worker's recorded preimplementation 202-file baseline is distinct from this Reviewer's independently rerun 203-file final suite. No broader suite repetitions or ROM-backed result are claimed.

Next allowance: Orchestrator may reconcile acceptance of this exact **unattached helper** under the task. Source startup RNG, live event-producer wiring, native species-context delivery, Brock routing, missing ability mechanics and all ROM/runtime/phase gates remain outside this PASS. No implementation correction, ROM access, runner action or remote mutation performed; only this `/tmp` review and local test log written.
