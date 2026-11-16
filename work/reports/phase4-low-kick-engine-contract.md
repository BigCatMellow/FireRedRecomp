# Low Kick ordinary-species engine contract — design only

READY_FOR_REVIEWER. Proposed bounded implementation contract; no code authority,
prototype, native provider or family acceptance. Worker: Codex Sol actor
`/root/v4a_upstream_worker`; parent rina commissions distinct review.

Audited clean published WG `944df72c9742fbf3b192d3908f1627b6004aabf3`, initial
local task-only `2e30fe6872736fa43644aa23de348cc639eb24b9`. Actual src/tests/main
are unchanged from944df72; the larger organizer runtime was not used.
Recovered accepted source report at48c25e0, SHA-256
`b7604b4e7a5638287ee85640b5c065241d65688a9b3773d5b9a74d0ea390b465`, and its
independent correction PASS. Reference HEAD remains exact pret
`c75f352304d529f6ba92d4f74b9cf8b5c3810788` (all source links below pin it).

## Domain and provider boundary

Admit current defender species only in **1..251 or277..411**, exactly386
ordinary species. Static comparison of species constants, the411-entry mapping
and national enum verifies a bijection to dex1..386. In particular411 is
Chimecho,410 Deoxys; internal species IDs are not national IDs. Ordinary Unown
201 uses its ordinary entry. Sources: [species constants](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/include/constants/species.h#L258),
[mapping](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/pokemon.c#L519),
[national enum](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/include/constants/pokedex.h#L395).

Refuse0 (known source sentinel weight0, deliberately outside ordinary battlers),
252..276 old Unown (dex387..411 exceeds the declared entry array),412 Egg,
413..439 newer display-form IDs, all other out-of-range/fractional/nonnumeric/
NaN/infinite IDs. Out-of-bounds C results remain UNKNOWN; refusal assigns no
weight to them. [Conversion](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/pokemon.c#L5210)
has no bounds guard. Candidate importer NUM_SPECIES=412 includes holes; its
[PokedexOrder](https://github.com/BigCatMellow/FireRedRecomp/blob/944df72c9742fbf3b192d3908f1627b6004aabf3/import/PokedexOrder.lua#L42)
conversion also has no domain guard. Neither makes old forms valid inputs.
Transform remains unsupported; no original-species weight snapshot is proposed.

Numeric ABI ownership is known: [PokedexEntry](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/include/pokedex.h#L102)
is0x24 bytes, weight little-endian u16 at+0x0E hectograms; [getter](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/pokedex.c#L11)
indexes gPokedexEntries by national dex. Entries are declared in
src/data/pokemon/pokedex_entries.h, included by src/pokedex_screen.c:204;
ld_script.ld:538 places that object's rodata but supplies no fixed numeric
symbol address. [GFRomHeader](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/rom_header_gf.c#L10)
contains speciesInfo/moves and save-pokedex offsets, **no numeric PokedexEntry
pointer**. Source layout/symbol ownership does not establish the retail address.

At944df72, SpeciesInfo exposes no weight; RomAddresses has species/national
mapping and browsing rank tables, no gPokedexEntries address; PokedexOrder's
weight order is rank, never numeric weight. Thus the supported-ROM numeric
address/provider is **UNKNOWN/unimplemented**, with no guessed derivation from
rank, stats or source-link placement. A future provider needs its own bounded
address/ABI proof and SHA-first reader/wiring authorization; no such edits here.

## Exact proposed API and immutable lookup

Use optional `BattleEngine.new(opts.lowKickWeights)` **plain table**, indexed by
internal ordinary species ID, storing u16 hectograms. Nil means no provider;
empty/partial table is allowed for bounded tests, missing target means refusal.
Reject a non-table/metatable, unsupported key, noninteger, NaN, infinity,
negative or>65535 weight during construction, **before** existing constructor
writes isFirstTurn into either caller battler. Zero weight is valid for an
injected ordinary key; this asserts representable command input, not real data.

Copy raw key/scalar pairs into a constructor-local table captured only by an
engine-owned lookup closure; retain/expose no caller table or mutable internal
map, invoke no caller function/metamethod. The copied configuration lasts one
battle and is never mutated or persisted; it is not new cross-turn battle state.
Two engines copy independently. No makeBattler/bridge/factory/save change.
Every admission and action reads current defender.species anew; no cached weight
on the battler, no attacker-based lookup. Replacements and caller species changes
between actions select a new entry. Arbitrary hostile callbacks changing state
mid-instruction are outside the synchronous engine contract.

Add pure `BattleEngine.lowKickPower(weight)` with integer0..65535 validation:
<100→20, <250→40, <500→60, <1000→80, <2000→100, otherwise120.
Extend `supportsMove(move,id,attacker,defender)` only for effect196/move67,
before positive-power fallback. Default attacker is player; infer defender only
when attacker is the exact engine.player/foe identity; otherwise explicit target
required. Non-Low-Kick/V4a callers retain existing behavior. Invalid/missing
species/lookup returns false, never power1/zero-weight fallback. Require the
source-locked move67 record shape; no arbitrary effect196 record expansion.

Add narrow pure `supportsLowKickAction(side,action,defenderOverride)` returning
boolean plus bounded reason. It checks only an **effective Low Kick** action;
other effective moves/non-move actions return true without changing their
existing admission rules. Resolve live lock first (existing isLocked/lockedSlot),
then all-PP-zero Struggle substitution exactly as resolveMoveCore currently does;
only then inspect selected slot/record. Missing slot/record keeps existing loud
error semantics. `chosenMoveRecord` at4962 is just a raw slot lookup and is
**insufficient**: it knows neither Struggle nor locks. Do not silently reuse it.
TrainerAI still raises on an all-PP-zero foe before engine entry; direct-engine
Struggle validation does not repair or claim that chooser gap. No new generic
action/transaction framework or AI filtering.

For valid input, use an action-local shallow copy of move67 with derived power
before damage/accuracy consumers; shared move remains power1/Fighting. The pure
power calculation may precede cancellers without state/RNG effects. Add Low
Kick's secondary draw exactly once at its ordinary successful/noEffect tail;
WG's existing guardTail already supplies it, so no double draw. Preserve current
WG/static-record-power semantics, other moves and their known RNG gaps.

## Actual refusal boundaries and proposed small preflight

Observed published code: [controller703](https://github.com/BigCatMellow/FireRedRecomp/blob/944df72c9742fbf3b192d3908f1627b6004aabf3/src/core/BattleSceneController.lua#L703)
checks selected player record at723, then calls chooseFoeMove at735, then
runTurn737. TrainerAI's85..130 chooser consumes tie-break RNG and scores without
supportsMove filtering. [runTurn5004](https://github.com/BigCatMellow/FireRedRecomp/blob/944df72c9742fbf3b192d3908f1627b6004aabf3/src/core/BattleEngine.lua#L5004)
increments turn/emits turnStart at5029 before ordering/resolveMove; late support
error at2245 alone cannot promise transactional refusal. resolveMove1738 resets
currentMove/moveDamageDealt before core. These are current facts, not new proof.

Proposed future placements:

- Controller's selected-player Low Kick arm uses supportsLowKickAction with
  current foe before chooser; other unsupported checks stay unchanged. Preserve
  the existing one-message return to MOVE. No turn/PP/HP/engine-event/RNG or AI
  call; UI message/revision changes are allowed. All-zero PP follows Struggle,
  so a raw Low Kick slot does not incorrectly veto an effective Struggle.
- At runTurn entry after existing read-only over/forced-switch assertions but
  before events allocation/reset, turn increment, runAttempted, lock/canceller/
  Focus Punch work or ordering RNG: preflight both effective Low Kick actions.
  Honor lock overriding a requested switch. For an actual unlocked player
  switch, preview action.battler as the foe's target before engine mutation;
  otherwise current target. Current engine has no foe voluntary-switch action.
  Pending forced replacement remains blocked; next turn reads actual new mon.
- Failed direct runTurn preflight raises one descriptive existing-style error;
  no engine turn/PP/HP/timer/flags/events/RNG mutation. No normal power1 damage,
  synthetic battleEnd or automatic retry. For controller-selected foe this is
  **after chooser**: prior chooser/producer RNG is retained, never rewound.
  Controller has no catch/retry around runTurn; error propagates fail-closed,
  not a new menu loop. Caller must fix its input rather than retry unchanged.
- Direct resolveMove preflight precedes its resets; direct resolveMoveCore
  checks before its own mutation. Failure appends nothing to caller events.
  Resolution rechecks actual current defender; supported modeled moves cannot
  Transform/change species between preflight and execution. New such mechanics
  require another contract. No promise to undo an already-resolved earlier hit
  if an external caller mutates state between those boundaries.

Persistence limits are explicit: main.lua:4790 persists when engine.turn changes,
so ordinary player-menu refusal does not trigger a new turn persistence. Engine
has no save callback. However main.lua:1940..1955 already persists outgoing data,
constructs/records incoming mon and changes active metadata **before** calling
controller on voluntary switch; processInput805 removes a ball before capture
_runTurn. An eventual selected-foe error cannot undo these or prior callback/RNG
side effects. This engine-only slice guarantees engine-entry boundaries, not a
whole UI/save transaction. Fixing those global flows would require separately
scoped main/save authority; no such promise or edit is proposed. Native merge
must first satisfy the provider/input gate below, avoiding those missing-data
failures in admitted live flows.

## Literal future tests and source oracles

Use source-derived literals, never engine readback to construct expectations.

- Power weight→power:0/99→20;100/101/249→40;250/251/499→60;
  500/501/999→80;1000/1001/1999→100;2000/2001/65535→120. Reject nil,
  false,string,NaN,±infinity,-1,65536,0.5; missing map/key, wrong-side-only key,
  invalid species ranges above, metatable/callback provider and malformed move.
- Fixed ordinary stats Level10/Atk20/Def20, no Fighting STAB, neutral target,
  no item/ability/status/screen and100% roll: powers20/40/60/80/100/120 cause
  **4/6/9/11/14/16 HP** damage from floor(6P/50)+2. With P60: Fighting STAB13;
  Normal weakness18; Ghost0; Huge/Pure Power attack40→16; Hustle attack30→12
  (accuracy80); burn→5; rain/sun do not change physical Fighting9; a critical
  doubles9→18. Fixed scripted sequence0,1,0,99 means accuracy1, noncrit,
  100% damage, discarded zero-chance secondary: **four draws**.
- Literal action traces with valid input: ordinary lowered-accuracy/Hustle miss
  one accuracy draw/one PP; Protect and Fly/Dig miss zero draws/one PP; asleep
  remaining>1 and flinch cancellation zero draws/no PP. Ordinary Ghost immunity
  still reaches crit/adjustment/secondary: four draws/no HP. WG neutral blocks
  with four draws; WG-super control damages with four. No added tail on an
  early miss/cancel and no duplicate WG tail. Separate runTurn speed-tie and
  AI draws from these per-action counts.
- Source [crit1170](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/battle_script_commands.c#L1196)
  short-circuits Battle/Shell Armor before crit RNG; source Focus Band may add
  a draw at1596. Neither is implemented in this base's ordinary hit path;
  held items and those ability interactions are excluded from this bounded
  slice, not silently given the four-draw promise. First-battle/tutorial and
  paralysis/confusion additional producers retain inherited limitations and
  require separately qualified traces; no global critical/item repair.
- Both sides/current target species, species change before selection/action,
  forced replacement and incoming voluntary-switch target; caller table/move
  mutation and two-engine isolation; shared move untouched. Table mutation
  after construction cannot affect lookup; missing new species refuses.
- Player controller absent input: same turn/PP/HP/RNG/AI calls, existing refusal
  message. Direct/foe engine errors: snapshot turn/flags/locks/timers/events,
  PP/HP/RNG before entry; all unchanged. Chooser fixture deliberately draws
  once then selects unsupported foe: chooser count1 retained, no engine draw.
  Locks and all-zero Struggle bypass irrelevant Low Kick input checks. No
  terminal auto-retry. Save/record snapshots untouched by engine construction/
  resolution; no claim about earlier main callback writes.

## Future literal scope, fixtures and eligibility

Only after independent design PASS may parent amend **this same task** with
future implementation permission. Proposed exact paths: src/core/BattleEngine.lua;
src/core/BattleSceneController.lua (narrow Low Kick selected-player arm only);
tests/battle_low_kick_test.lua (engine/controller assertions);
tests/phase4_low_kick_effect_rom_test.lua; tests/phase4_move_effect_inventory_test.lua;
work/reports/phase4-move-effect-inventory.md; this task. No formulas/main/bridge/
factory/importer/AI/save/replay/workflow change. Source/design report is evidence,
not runtime payload. Stop for any additional required path/semantic unknown.

Inventory remains class B, no represented flip. Current default h1-populated
probe lacks weights: future default Low Kick admission changes true→false only
for singleton67, making299/55 and uncovered16 (missing friendship/IV scope296/58).
An explicitly weighted valid ordinary defender separately admits it and restores
300/54 (or297/57 without friendship/IV); do not conflate scopes. Metadata changes
must be checked against pinned source partition, not copied from predicate output.

Future SHA-first fixture verifies move67's singleton effect196, Fighting/power1/
accuracy100/PP20/flags0x33 and exact source records through existing parser only
after supported SHA verification; locally SKIP, never guessed weight addresses.
Numeric-weight fixture waits for separately reviewed provider address/ABI proof,
then verifies mapping/domain/record lengths and threshold-representative species
without printing/extracting content. No custom-trainer absence claim is borrowed
from V4a F4. Low Kick exists in default level-up learnsets (Mankey level6,
[learnsets751](https://github.com/pret/pokefirered/blob/c75f352304d529f6ba92d4f74b9cf8b5c3810788/src/data/pokemon/level_up_learnsets.h#L750));
custom-text absence cannot prove default-party absence.

**Native merge requires a reviewed numeric provider/delivery contract and
non-skipped supported-ROM proof covering all admitted default/custom trainer,
party/wild and replacement targets**, or separately reviewed complete live-scope
absence proof preventing any Low Kick execution. Neither exists; no live merge
is ready. AI prediction still sees record power1 under this scope; no AI parity.
Provider integration, undefined-form handling beyond refusal and unmodeled
ability/item/history/Transform interactions remain separate gates.

The defined ordinary-species/itemless/modeled-context injected **engine slice
is source-certain and eligible in principle for a bounded fast-lane local
implementation after design PASS**: no new persistent/cross-turn battle state,
main/save/replay or in-scope source UNKNOWN; pure immutable configuration and
narrow preflight suffice. Complete family/native delivery is not eligible or
accepted by this result. Unknown retail address is outside the injected slice,
not fabricated into it. Required public CI/review/ROM/F4/full-relay/runtime and
operator-gated main merge remain. Parent alone decides next exact scope.

## Verification and handoff

Static source parsing verified386 ordinary mappings and25 excluded old mappings;
no runtime prototype, ROM search/access or new data artifact. Source report hash
and reference pin checked; git diff944df72 initially showed task only. Read-only
rg/sed discovery and exact frozen APIs supplied new facts; cwd discovery errors
and corrected absolute-path safeguard captured append-only in friction.
Product baseline/full suite N/A for design-only; recovered accepted213 no-ROM
source/test identity without rerun. Stage new report, run repository checker/
whitespace and freeze exact commit/report digest for distinct Reviewer. Design
PASS alone authorizes no implementation, publication or broader acceptance.
