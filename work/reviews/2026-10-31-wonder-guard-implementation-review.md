# Wonder Guard independent implementation review — 2026-10-31

**NEEDS_FIX** for exact frozen
`47d88a62ff7bfeeb7ca40573daf4365eabbee834`.

Three source-known route defects below require bounded corrections. No
correction implemented by this Reviewer. No publication/adoption of this
implementation is inferred from green assertions.

## Identity and scope

Reviewed detached `/tmp/firered-wonder-guard-review-20261031`, exact47d88a6,
against dispatch `c1a3cc4`, active `work/tasks/phase4-wonder-guard.md`, and
accepted design SHA256
`f9718f67ad8a96d8095c683e00c7b286f2f1d741752d664f8949f2550835d1c9`
(independently matched in the repository). Pinned source HEAD remains
`c75f352304d529f6ba92d4f74b9cf8b5c3810788`.

AGENTS/REVIEWER read; narrower parent dispatch prohibits remote/canonical-state
writes. Six changed paths are exactly the allowed engine, opt-in formulas,
narrow controller, focused test, opt-in ROM fixture, and task. No Worker tree
edit, code correction, AI/history producer write, global typeCalc rewrite,
admission expansion, persistent state, extracted content, ROM access/search,
runner/remote action, publication, merge, or phase claim occurred.

## R1 — hit-all paths have no secondary tail draw

At `BattleEngine.lua:3782-3784`, the newly blocked generic branch suppresses
the tail for Absorb and Fury Cutter, but still calls it for Earthquake and
Magnitude. Their actual source script has **no seteffectwithchance**.

Source `data/battle_scripts_1.s:1830-1875` contains the complete hit-all loop
and miss tail, ending in moveend/next-target/end. Magnitude enters the same
loop after its strength draw (`:1679-1688`). A landed neutral WG-blocked
Earthquake consumes accuracy+crit+damage-random = **3** draws. Magnitude
adds its earlier strength draw = **4**. Current code consumes4/5.

Smallest correction: exclude these two represented hit-all effects from
the newly blocked secondary-tail draw, preserving their existing order,
PP/HP behavior and unaffected controls. Correct the focused Magnitude
five-draw oracle/comment at `tests/battle_wonder_guard_test.lua:329-333` to
four and add a literal three-draw Earthquake control, both attacker sides.
Update receipt wording as needed. Do not change genuine ordinary-hit tails.

Absorb's Worker clarification is **correct**: its bespoke script at
`:325-365` contains no seteffectwithchance, so blocked accuracy+crit+random
is3 with no drain. Retain that behavior and its control.

## R2 — hit-all missed-label typecalc must see preexisting MISSED

At `BattleEngine.lua:3027-3029`, a fresh BattleFormulas.typeCalc computes
ordinary super/resist flags for the hit-all missed label. Source executes
this typecalc **after** accuracy/protect/semi has set global MISSED.

`ModulateDmgByType` (`battle_script_commands.c:1254-1271`) only changes
super/resist bits when global NO_EFFECT is absent. MISSED is a NO_EFFECT
bit. Hit-all's earlier movevaluescleanup has cleared old effectiveness
bits, then its failed accuracy branch sets MISSED and jumps to typecalc
(`scripts:1836-1847,1867-1875`; C`:945-978,1092-1104,3469-3478`). Thus no
super-effective bit is established at that later typecalc, and Wonder
Guard sets AVOIDED_DMG even for ordinarily super-effective Ground vs Fire
(`C:1328-1337`). This applies to protected, random-miss, and semi-miss
hit-all paths. True type immunity remains distinct.

Current source-real Earthquake, Ground versus a Fire/WG defender: protected
case reports protected, ordinary failed roll reports miss, and air/semi case
reports miss. Source requires **wonderGuard** in all three, no target HP loss;
draws are0/1/0 respectively (Magnitude adds its strength draw).

Smallest correction: carry the known prior-MISSED context into this bounded
hit-all typecalc result; suppress only its source-disallowed effectiveness
flag updates, retaining true immunity and original record-power eligibility.
Do not change the global typeCalc API/AI semantics or typecalc2's independent
OR flags. Correct the presently wrong `super hit-all protect` expectation
at focused test:249 and add random/semi, both-side, super-type controls.

## R3 — Brick Break omits its post-screen cleanup/typecalc2 result pass

Native `BattleEngine.lua:3683-3692` removes screens, then later returns from
the first ordinary WG calculation at:3777-3786. It never reproduces Brick
Break's source result sequence after that calculation.

Source `scripts:2413-2444`: remove screens, crit/damage/typecalc/random;
if animation-turn is nonzero, clear MISSED and DOESNT_AFFECT; then execute
**typecalc2** before HP/result commands. The source screen command sets that
nonzero animation-turn when a screen timer was present (`C:9441-9461`).

Concrete synthetic modeled-state oracle using actual Brick Break's static
record (id280/effect186/power75/Fighting): WG defender Ghost+Dark, active
Reflect. Ordinary typecalc first selects WG+immunity; screen cleanup clears
those global bits; ordered typecalc2 finds Fighting/Dark-super before the
later Fighting/Ghost-zero, so its local super-only flags do not reassert
WG. Global immunity remains and source prints **noEffect**, with zero target
HP loss and4 draws. Current code prints wonderGuard. With no screen, the
earlier WG MISSED survives and wonderGuard is correct. Chart order is at
`battle_main.c:352-362,423-424`.

Smallest correction: retain a bounded action-local screen-removal indication,
and reproduce the cited clear/second-scan/reason sequence for WG Brick Break.
Preserve the first calculation, screen removal/event, random order, and
unrelated/unblocked behavior. Add both-side screen/no-screen oracles for
this immune+super combination. No generic result framework/new persistent
state or broader screen/UI work is needed or authorized.

## Independent evidence and limits

- `env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh`:
  **PASS211** files, honest ROM skips; log
  `/tmp/firered-wonder-guard-review-full-20261031.log`. This includes the
  requested V3/V4a/H1/V4b and engine/controller regressions. Worker's prior
  baseline209 receipt remains recorded; no redundant baseline campaign run.
- Independent focused invocation:569 passed/0 failed; controller144/0.
- Repository checker:340 tracked Lua,418 tracked Markdown,1349 local targets.
  Diff whitespace check passes; isolated exact-head tree remains clean.
- V4a dynamic-copy/no-defrost checks, separate normal/miss/ordered scans,
  controller defender identity, original-record power controls, locks/Fury,
  Present/Psywave/fixed/OHKO, multihit/Triple Kick, Explosion/crash/Rampage,
  B-fallback exclusions and no-history/global-rewrite scope were inspected.
  Their passing assertions do not discharge the three source failures above.
- Independent source-derived probe script
  `/tmp/firered-wonder-guard-review-probes-20261031.lua`: **18 passed,
  12 failed**, the same six failures on each attacker side: Earthquake draw,
  Magnitude draw, hit-all super-type protect/random/semi reason, and Brick
  Break screen/ordered-scan reason. Positive controls preserve unchanged
  HP/PP, Brick Break4 draws and its no-screen WG result. Expected values
  are from the source command sequence, not implementation readback.
- ROM fixture inspected: verify precedes parsing/name/species/move access;
  no guessed importer/address changes. Explicit no-ROM invocation cleanly
  SKIPs and reports missing supported-ROM evidence. No real ROM supplied.

**Next allowance:** original Worker corrects only R1/R2/R3 plus their focused
oracles/receipt within the existing six-path task, reruns affected checks and
freezes a new exact revision for independent delta review. The source behavior
is known and the corrections fit the existing coherent leaf; no new refusal
approximation or broad implementation expansion is required. Retain all
external supported-ROM/F4, V3/base/full-relay, shared-main/public-CI/guarded
route/publication gates. No whole ability, Brock AI, runtime/replay or phase
acceptance follows from this local review.
