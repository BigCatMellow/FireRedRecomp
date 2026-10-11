# FireRedRecomp Mod Design Snapshot — Trainer Progression

> Imported from `BigCatMellow/Pilot_Projects` for durable FireRedRecomp-side design reference.
>
> Source branch: `pokemon-firered-balance-bootstrap`
>
> Source blob: `527cf23af9ff70f8d96c45ed2a953c139576ee70`
>
> This is design documentation only. It does not modify FireRedRecomp runtime behavior.

---

# Trainer Progression / Anti-Grind System

- Record role: `IDEA / DESIGN BRANCH`
- Primary information class: `TASK CONTEXT + RESEARCH`
- Status: `ACTIVE CANDIDATE — REDESIGNED AFTER DECOMP AUDIT / PROTOTYPE REQUIRED`
- Lifecycle: `ACTIVE`
- Authority: `ADVISORY / NONE`; this file records a progression-system design branch and does not alter the frozen FireRed balance package
- Accountable owner: human project owner
- Canonical owner for subject: this file
- Parent / decision supported: [Pokémon FireRed Balance Project](README.md)
- Related records: [Balance Bible](BALANCE_BIBLE.md), [Roadmap](ROADMAP.md), [Baseline and Sources](BASELINE_AND_SOURCES.md), [Final Specification Freeze Decision](FINAL_SPECIFICATION_FREEZE_DECISION.md)
- Supersedes / superseded by: supersedes the earlier `No Individual Pokémon Levels` hypothesis previously recorded in this file
- Time-sensitive: `NO`
- Decomp reference: `pret/pokefirered@037335f4c725d7c9aecdac87066f2002b4bd7e14`

## Current design thesis

The original hypothesis was to remove individual Pokémon levels and move raw power progression onto the trainer.

That idea is **no longer the leading design**.

The decomp audit shows that FireRed's Pokémon level is read by more systems than the visible level-up loop suggests. Level participates in stat calculation, damage-related mechanics, some move effects, Repel logic, daycare behavior, experience tables, and other compatibility behavior. Removing it would require redefining many unrelated mechanics.

The current direction is therefore:

> **Keep Pokémon levels, but remove the parts of leveling that force repetitive catch-up grinding.**

The primary quality goal is:

> **Changing your team should cost decisions, not time.**

The problem being solved is not "levels are bad." The problem is:

```text
current party around level 35
→ catch useful Ground Pokémon at level 22
→ player has already found a strategic answer
→ game requires 30–60 minutes of repetitive battles before that answer is usable
```

That is backwards. Team experimentation should be rewarded rather than taxed.

## Core system shape

The current candidate separates progression into five related systems:

```text
TRAINER PROGRESS
badges / story / major accomplishments
        ↓
catch-up target
broad evolution tier
training-system access

POKÉMON LEVEL
        ↓
stat scaling
damage-related level behavior
level-sensitive mechanics

TYPE PROFICIENCY
        ↓
move instruction
specialist tutors/resources
training efficiency
small specialist perks

POKÉMON TRAINING
        ↓
explicit stat-development choices
(replacement for passive EV grinding)

FRIENDSHIP / FAMILIARITY
        ↓
bonding, identity, special evolution conditions
without becoming another catch-up grind
```

The system must remain simpler to experience than it sounds internally.

---

# 1. Pokémon levels remain

Pokémon retain individual numerical levels.

Level continues to own:

- ordinary stat scaling;
- the level component of damage calculations;
- level-sensitive move behavior;
- compatibility with mechanics that explicitly compare Pokémon levels;
- the visible sense that an individual Pokémon is growing.

Level should **not** remain the primary gate for:

- whether a newly caught Pokémon can participate in current content;
- evolution timing;
- most move access;
- deliberate repetitive catch-up grinding.

This preserves a large amount of FireRed's identity and engine behavior while attacking the actual pain point.

## Why the original "Trainer Level replaces Pokémon Level" idea was downgraded

The decomp shows direct level dependencies that are not obvious from normal play.

Examples include:

- stat calculation in `src/pokemon.c`;
- level-up experience tables indexed by species growth rate;
- `EFFECT_LEVEL_DAMAGE` used by moves such as Seismic Toss and Night Shade;
- Repel encounter filtering through `IsWildLevelAllowedByRepel`;
- daycare level accumulation and move learning;
- obedience comparisons;
- battle/UI systems that expect a real Pokémon level.

Removing Pokémon level would therefore create a large compatibility burden for little benefit once catch-up grinding can be solved separately.

---

# 2. Trainer Progress replaces grind as the broad progression controller

Trainer progression should probably **not** be another freely grindable XP bar.

The leading candidate is to derive broad trainer capability primarily from:

- badge count;
- story milestones;
- important trainer victories;
- possibly bounded Pokédex/discovery milestones.

The trainer's progression establishes a **catch-up target**.

Example:

```text
Trainer progression implies target range: ~Lv. 34

new Cubone: Lv. 21
existing party: Lv. 33–36
```

Cubone should be able to become useful very quickly.

The trainer progression system should answer:

> "How quickly can an experienced trainer bring a newly caught Pokémon up to the level of the current adventure?"

It should not answer:

> "How much raw bonus damage does the trainer give every Pokémon?"

## Badge-order rule

Kanto's middle-game Gym order is partially flexible.

Therefore broad unlocks should generally key from **badge count / trainer tier**, not from a specific badge identity, unless a specific badge already has a world-progression reason to matter.

---

# 3. Trainer Rank and the Training Floor

The preferred anti-grind mechanism is now a **free Training Floor**, not a stack of large XP multipliers.

Trainer Rank is derived from story/badge progress and defines a minimum level that an experienced trainer can bring any owned Pokémon up to.

Example:

```text
Trainer Rank implies Training Floor: Lv. 32

Cubone caught at Lv. 21
→ Train to Rank
→ Cubone becomes Lv. 32

Pidgeot already Lv. 35
→ unchanged
```

This directly removes the catch-up chore instead of merely making the chore faster.

The Training Floor is **not a cap**. Pokémon above it continue to gain levels normally, so longtime team members can remain somewhat ahead without making new catches unusable.

## Why this is cleaner than accelerated XP

A free floor:

- is independent of species growth-rate curves;
- cannot stack explosively with traded EXP, trainer-battle EXP, Lucky Egg, or Exp. Share;
- removes rather than accelerates solved low-risk battles;
- is easy for the player to understand;
- preserves ordinary FireRed leveling above the current readiness floor.

The underlying implementation can grant exactly enough EXP to reach the floor, preserving the real Pokémon level and all level-sensitive mechanics.

## Where training happens

Preferred presentation:

- Pokémon Centers expose **Train to Rank**;
- newly caught Pokémon below the floor may optionally prompt the player that rank training is available;
- no money or consumable is required for ordinary catch-up.

Charging for basic catch-up would simply convert battle grinding into money grinding.

## Setting the floor

Do not derive the floor from the player's highest Pokémon; that can be gamed by overleveling one party member.

Use the lower edge of the expected party-level band for the current story tier.

The existing balance project's route/boss progression work should supply those bands.

## Existing EXP modifiers

Normal EXP systems still matter **above** the Training Floor:

- Trainer battle bonus;
- traded Pokémon bonus;
- Lucky Egg;
- Exp. Share;
- species growth-rate curves.

They no longer need to solve catch-up.

---

# 4. Optional accelerated catch-up outside Centers

If playtesting shows that returning to a Pokémon Center is itself annoying, Pokémon below the Training Floor may also receive strong catch-up EXP during ordinary play.

This is secondary convenience, not the core system.

Do not create a separate Auto Train currency or idle-grind system unless the simple free floor proves insufficient.

---

# 5. Type Proficiency

Type Proficiency represents what **the trainer knows how to do with a type**.

FireRed has 17 types. The preferred model is now **five broad mastery ranks**, not ten granular XP levels.

Example:

```text
0  UNFAMILIAR
1  FAMILIAR
2  PRACTICED
3  SKILLED
4  EXPERT
5  MASTER
```

The rank should be earned from distinct **Type Insights / milestones**, not a continuously farmable XP bar.

## Proficiency should grant options, not mandatory raw power

Avoid:

```text
Fire Rank 10 = +30% Fire damage
```

That would recreate the original experimentation problem:

> "I should not use this new Water Pokémon because my Fire investment is too valuable."

Prefer rewards such as:

- faster training for Pokémon of that type;
- earlier / broader compatible move instruction;
- specialist tutors;
- type-associated held items/resources;
- small utility perks;
- high-rank specialist interactions.

Large universal damage bonuses should be rejected or treated with extreme caution.

## Early ranks must be fast

Trying a new type must not create a new proficiency grind.

Ranks 0–2 should arrive quickly through ordinary use and discovery.

Ranks 3–5 represent increasing specialization. Rank 5 should be optional mastery, not required for normal story viability.

---

# 6. How Type Proficiency grows

Do **not** use:

> use Ground move → +1 Ground XP forever.

That produces a farming loop immediately.

Type Proficiency should reward **varied meaningful experience**.

Candidate sources:

- first Pokémon of that type caught;
- first new species of that type encountered;
- first new move of that type observed;
- using multiple different moves of that type;
- winning meaningful trainer battles with that type involved;
- evolving a Pokémon of that type;
- training multiple different species of that type;
- facing an important specialist;
- meaningful success or failure against that type.

Repeat identical low-risk actions should rapidly approach zero reward.

The thematic rule is:

> **experience should mean experience, not repetition.**

A checklist / insight model may be better than a visible raw XP bar.

---

# 7. Dual-type Pokémon

Dual-type Pokémon should naturally contribute to both types, but not necessarily equally for every action.

Examples:

- catching Nidoking → some Ground + Poison insight;
- winning primarily through Ground techniques → mostly Ground;
- winning through Poison/status play → mostly Poison;
- evolving a dual-type species → bounded credit to both.

This lets specialization emerge from play rather than from choosing a class at character creation.

---

# 8. Move acquisition becomes trainer knowledge + species capability

The current direction is to reduce the importance of level-up move timing.

A move becomes teachable when:

```text
trainer knows the technique
AND
species is compatible
AND
any required story/item/specialist condition is met
```

Type Proficiency can unlock the trainer's ability to teach groups of moves.

Species compatibility remains mandatory.

High Fire proficiency must **not** turn every Fire Pokémon into the same moveset.

## Example shape

Ground proficiency could unlock access to increasingly advanced compatible techniques:

```text
early ranks   → basic Ground training
middle ranks  → Dig / utility / stronger common techniques
high ranks    → advanced Ground options
mastery       → elite technique access
```

Exact move/rank assignments require separate balance work.

---

# 9. Move memory

The anti-grind / experimentation philosophy strongly supports a modern **move memory** system.

Once a Pokémon has legitimately learned a move, that move should remain available to re-equip outside battle.

A Pokémon still carries four active battle moves.

This removes the old penalty:

> try a move → replace something useful → later pay another cost to recover it.

Move memory also makes proficiency unlocks feel like permanent trainer/Pokémon knowledge.

---

# 10. TMs

Single-use TMs conflict with encouraging roster experimentation.

The progression redesign should **not initially change TM scarcity**.

The frozen balance package deliberately models important one-copy resources such as TM19. Making all TMs reusable here would reopen already-frozen balance assumptions.

Preferred first implementation:

- TMs retain their frozen scarcity/resource rules;
- once a Pokémon legitimately learns a TM move, **that Pokémon remembers it permanently** through move memory;
- swapping the move out no longer destroys the player's investment;
- reusable/renewable TMs remain a separate future decision requiring explicit balance reopening.

Mandatory traversal HMs must be protected from proficiency softlocks.

Type Proficiency should never prevent the player from learning a required field move once its normal story gate is satisfied.

---

# 11. Evolution: decouple it from Pokémon level

Level requirements create another hidden catch-up grind even if XP is accelerated.

Current preferred direction:

> **Evolution does not require a Pokémon level.**

Evolution instead uses:

```text
Trainer Evolution Tier
+
species evolution condition
+
appropriate item / catalyst where needed
```

## Broad progression gate

Trainer progression / badge count controls broad **Evolution Tiers**.

Original evolution levels can be used as design metadata to derive those tiers rather than inventing every timing from scratch.

Conceptual example only:

```text
very early vanilla evolutions  → early tier
starter first evolutions       → early/mid tier
common middle evolutions       → mid tier
strong final evolutions        → later tier
pseudo-legendary finals        → late tier
```

This prevents absurd cases such as an extremely early Dragonite without requiring Dragonair to grind to level 55.

## Evolution item model

Do not flatten every evolution into the same stone.

Preserve thematic identity:

- existing elemental stones stay;
- friendship evolutions can stay friendship-based;
- trade evolutions can use a Linking-Cord-style item;
- trade-with-item evolutions can use their item directly;
- former level evolutions can use a common Evolution Catalyst / readiness item;
- unusual meaningful conditions can remain when they are not grindy.

The important change is:

> level is no longer the mandatory evolution gate.

## Move locks alone cannot balance early final evolutions

A low-level Dragonite with weak moves is still far stronger than a Dratini because of base stats, typing, and defenses.

Therefore move access is not a sufficient evolution gate.

Evolution itself needs a progression tier.

---

# 12. Friendship / familiarity

Friendship is valuable as an attachment system, but the decomp shows it rises through hidden actions such as:

- walking;
- level-ups;
- learning TMs/HMs;
- certain battle events;
- massages;
- League battles.

Friendship evolutions use a threshold of 220.

A late-caught Pokémon must not become another "run in circles until a hidden number rises" problem.

Preferred principles:

- make friendship state more visible;
- reward meaningful shared activity;
- accelerate late-game bonding;
- keep friendship for identity/evolution where appropriate;
- do not let walking loops become the efficient strategy.

A shallow species/evolution-family familiarity track remains optional, but should only deepen identity and options. It must never be required for basic combat viability.

---

# 13. EVs are a hidden catch-up problem

This was the largest overlooked system.

FireRed silently gives Pokémon stat-specific effort values from defeated species.

Decomp facts:

- `MAX_TOTAL_EVS = 510`;
- `MAX_PER_STAT_EVS = 255`;
- EVs directly enter the stat formula;
- Macho Brace doubles EV gain;
- Pokérus exists as another EV-training accelerator.

Therefore:

```text
old Blastoise Lv. 40
vs
new Rhyhorn rapidly caught up to Lv. 40
```

can still be unfair because Blastoise has accumulated hidden training history.

That violates the anti-catch-up-grind goal.

## Preferred replacement: explicit Training Points

Replace passive opponent-specific EV farming with an explicit allocation system.

Concept:

```text
RHYHORN TRAINING

HP       +10
Attack   +18
Defense  +14
Sp.Atk     0
Sp.Def     0
Speed      0
```

A Pokémon receives an appropriate Training Point allowance based on current development / trainer progression.

A newly caught Pokémon brought into the current range receives the appropriate available allowance rather than starting secretly behind.

This preserves stat customization without requiring external knowledge of EV yields.

Macho Brace / Pokérus would need repurposing or removal if passive EV gain is removed.

---

# 14. IVs and Natures

The decomp confirms:

- IVs are hidden 0–31 values per stat;
- Nature is derived from personality;
- Nature modifies combat stats.

These are not the same kind of grind as levels, but they can still punish the "use the Pokémon you like" principle.

Current recommendation:

- keep IVs/Natures initially for individual variation;
- do not let them become another reason to discard a Pokémon;
- eventually consider visible late-game retraining / correction mechanisms analogous to modern Hyper Training / Mints;
- do not mix that redesign into the first anti-grind prototype.

---

# 15. Hidden badge stat boosts

FireRed contains hidden badge-based combat stat bonuses.

Decomp behavior:

- Badge 1 / Boulder Badge: +10% Attack;
- Badge 3 / Thunder Badge: +10% Speed;
- Badge 5 / Soul Badge: +10% Defense;
- Badge 7 / Volcano Badge: +10% Special Attack and Special Defense.

The battle code applies a `110 / 100` multiplier.

These boosts are poor fits for the new system because badges would already drive Trainer Progress, catch-up access, and evolution tiers.

Current recommendation:

> **Strongly consider removing the hidden badge stat boosts.**

Otherwise badge progression double-dips into both permission/progression and invisible raw combat power.

This requires explicit balance validation before adoption.

---

# 16. Obedience

FireRed's obedience system checks trainer ownership and badge-dependent level thresholds.

This is conceptually adjacent to Trainer Rank but should not be casually merged with it.

Questions to resolve:

- retain traded-Pokémon obedience as a separate mechanic;
- modernize or remove it;
- ensure catch-up leveling cannot accidentally push traded Pokémon into disobedience unexpectedly;
- avoid creating a new frustration penalty for using newly obtained Pokémon.

---

# 17. Daycare

Vanilla Daycare:

- gains EXP from steps;
- levels Pokémon;
- teaches level-up moves;
- can overwrite the oldest move automatically;
- charges based on levels gained.

If catch-up training, move memory, and explicit trainer-assisted training exist, much of Daycare's old leveling function becomes obsolete.

Possible new roles:

- breeding;
- passive friendship;
- passive familiarity;
- Training Point redistribution;
- low-friction training service.

Automatic move deletion should not survive a move-memory redesign.

---

# 18. PP investment

FireRed stores PP Up investment per move slot.

Move memory / free re-equipping raises a design question:

> Does PP investment belong to the move knowledge itself or to the current slot?

A modernized system should probably attach permanent PP improvement to the learned move rather than to an arbitrary slot, but this needs implementation research.

Do not let move re-equipping erase or duplicate PP investment.

---

# 19. Other hidden level dependencies to audit

Before freezing the system, search every relevant decomp read of:

- `MON_DATA_LEVEL`;
- `MON_DATA_EXP`;
- EV fields;
- IV fields;
- friendship;
- badge flags;
- original-trainer ownership;
- PP bonuses;
- evolution mode/conditions.

Known examples already found:

- Seismic Toss / Night Shade level damage;
- Repel filtering;
- Daycare;
- obedience;
- EXP UI;
- species growth-rate tables;
- Everstone evolution interception.

This is an explicit requirement:

> **Do not freeze the progression redesign until the hidden-dependency audit is complete.**

---

# 20. Systems that should remain distinct

The redesign should not collapse every progression axis into one number.

Preferred ownership:

| System | Owns |
| --- | --- |
| Trainer Progress | broad game progression, catch-up target, evolution tier, training-system access |
| Pokémon Level | stat scaling and explicit level-sensitive mechanics |
| Type Proficiency | trainer knowledge, move instruction, specialist access |
| Training Points | individual stat customization |
| Friendship/Familiarity | attachment and special identity/evolution conditions |
| Story/Badges | world progression and broad Trainer Progress milestones |

This is deliberately different from the original proposal where Trainer Level replaced Pokémon Level.

---

# 21. Anti-grind invariants

Any implementation should preserve these rules:

1. A newly caught Pokémon should become current-content viable quickly.
2. The player should not need to grind wild Pokémon to test a strategic idea.
3. Type Proficiency must not create a replacement grind.
4. Friendship must not create a replacement walking grind.
5. Evolution must not require level grinding.
6. EV/stat training must not require hidden opponent farming.
7. Auto Train must not merely replace battle grinding with currency grinding.
8. Repeated solved encounters should be among the least efficient ways to progress.
9. Trying a new type should be cheap; mastering one can require commitment.
10. Longtime Pokémon may be more understood/attached, but newly caught Pokémon must not be mathematically unusable.

Primary design maxim:

> **Changing your team should cost decisions, not time.**

---

# 22. Failure modes

### `TMF-01` — catch-up multiplier still feels like grinding

Fail if the player must repeatedly fight trivial encounters just to approach Trainer Target.

### `TMF-02` — Trainer Progress becomes the new grind

Fail if grinding weak encounters is an efficient way to increase broad trainer capability.

### `TMF-03` — Type Proficiency farming

Fail if repeatedly using or absorbing the same move is efficient.

### `TMF-04` — specialization punishes experimentation

Fail if existing proficiency bonuses make switching to a new type strategically irrational.

### `TMF-05` — EV replacement recreates EV grinding

Fail if Training Points are primarily earned through repetitive species-specific battles.

### `TMF-06` — evolution tiers cause abrupt badge power spikes

Fail if earning a badge instantly turns most of the roster into final evolutions and trivializes nearby content.

### `TMF-07` — move gating makes new catches technically viable but useless

Fail if the Pokémon has appropriate stats but cannot access a functional moveset.

### `TMF-08` — too many meters

Fail if Trainer Progress + 17 Type Proficiencies + Training Points + Friendship/Familiarity becomes dashboard management.

### `TMF-09` — hidden vanilla multipliers double-dip

Fail if badge boosts, traded EXP, Lucky Egg, growth curves, or other hidden systems amplify the redesign in unintended ways.

### `TMF-10` — late final evolution too early

Fail if an evolution such as Dragonite becomes available before the campaign can support its base-stat power.

### `TMF-11` — move memory homogenizes species

Fail if proficiency + reusable TMs gives every compatible species effectively identical optimal movesets.

### `TMF-12` — old attachment disappears

Fail if there is no meaningful emotional or mechanical identity to long-term Pokémon once catch-up is easy.

---

# 23. Smallest useful prototype

Do not implement the whole system at once.

Prototype the early campaign:

```text
Pallet
→ Route 22 rival
→ Viridian Forest
→ Brock
→ Mt. Moon
→ Cerulean rival
→ Misty
```

Prototype features:

1. Pokémon levels remain.
2. Trainer Rank derived from story/badge progress.
3. Free Train-to-Rank floor.
4. Small five-rank Type Mastery implementation for types relevant to the slice.
5. Natural learnsets preserved; limited mastery-based move instruction added.
6. One evolution-tier transition using the reusable Evolution Catalyst.
7. Move memory for a constrained set of Pokémon.
8. Trainer-rank Training Budget + simple Focus prototype replacing passive EV gain in the slice.
9. Hidden badge stat boosts disabled in the prototype arm.
10. Control arm preserving vanilla behavior.

Measure:

- deliberate grind time;
- time from capture to meaningful use;
- number of species tried;
- party turnover;
- boss difficulty;
- move diversity;
- whether players farm proficiency;
- whether catch-up feels automatic enough;
- whether longtime Pokémon still feel distinct;
- whether evolution timing remains satisfying;
- whether the UI communicates the system without external explanation.

---

# 24. Simplification pass — preferred system v2

The first redesign accumulated too many overlapping systems. The preferred v2 deliberately removes mechanics that do not earn their complexity.

## Keep

- real Pokémon levels;
- normal leveling above the current story readiness floor;
- natural species learnsets;
- Natures and IVs initially;
- friendship where it serves identity/evolution;
- existing TM scarcity until separately reopened.

## Add

- story-derived **Trainer Rank**;
- a free **Training Floor** for instant roster catch-up;
- five-rank milestone-based **Type Mastery**;
- manual evolution eligibility through Trainer Rank + the species' thematic condition;
- move memory;
- rank-based stat-training budget with simple Focus choices;
- visible friendship/bond information.

## Remove or avoid

- a separate Trainer XP bar;
- ten-rank Type XP bars;
- catch-up as primarily a giant EXP multiplier;
- an Auto Train currency;
- passive opponent-specific EV grinding;
- hidden badge stat boosts;
- mandatory level requirements for evolution;
- any proficiency penalty that makes unfamiliar types nonviable.

## Preserve natural move learning

Natural level-up learnsets should remain because they preserve species identity and reduce redesign scope.

When **Train to Rank** skips levels, every natural move crossed during the jump is added to that Pokémon's move memory rather than forcing overwrite prompts.

Type Mastery then supplies **additional training options**, not the minimum moves required to make a Pokémon functional.

This is simpler and safer than replacing the entire learnset system with proficiency gates.

## Evolution tool

For former level-based evolutions, the strongest current option is a reusable **Evolution Catalyst** key item:

```text
species is eligible at current Trainer Rank
+
player chooses Evolve
+
Evolution Catalyst triggers the evolution
```

The Catalyst is not consumed. Level evolution was never intended to be a scarce resource, so making its replacement consumable would create a new grind/resource tax.

Existing thematic methods remain distinct:

- Fire/Water/Thunder/Leaf/Moon/Sun Stones remain their own items;
- friendship evolutions retain friendship;
- trade evolutions receive an in-game Linking-Cord-style solution;
- trade-with-item evolutions retain their thematic item;
- Everstone still prevents evolution.

## Attachment survives through being ahead, not through catch-up debt

A longtime Pokémon can naturally remain several levels above the Training Floor and carry:

- more friendship/history;
- more Type Mastery contributions;
- a larger remembered move library;
- ribbons/records;
- player attachment.

A new catch becomes **usable**, not automatically identical to a longtime partner.

That is the intended distinction.

---

# 25. Current disposition

`PROMOTION STATE: ACTIVE REDESIGN CANDIDATE → HIDDEN-SYSTEM AUDIT + PROTOTYPE BEFORE ADOPTION`

The earlier "Trainer Level replaces all Pokémon levels" model is no longer preferred.

Current leading direction:

```text
KEEP Pokémon levels
+
FREE story-gated Training Floor
+
REMOVE level-based evolution gates
+
REUSABLE Evolution Catalyst for former level evolutions
+
5-RANK milestone-based Type Mastery for optional knowledge/options
+
PRESERVE natural level-up learnsets
+
MOVE MEMORY while preserving frozen TM scarcity
+
TRAINER-RANK Training Budget + simple Focus instead of passive EV grind
+
VISIBLE / accelerated friendship where retained
+
REMOVE or explicitly re-evaluate hidden badge stat boosts
```

This branch remains separate from the frozen balance package. It must not silently modify the accepted move/category/learnset specification.

## Exact next work

1. Complete the decomp-wide hidden dependency audit.
2. Produce a dependency map of every meaningful level/EXP/EV/friendship/badge read.
3. Define Trainer Rank → Training Floor bands from expected story-level ranges.
4. Define the exact Train-to-Rank behavior, including skipped natural moves and traded-Pokémon obedience.
5. Define the minimal five-rank Type Mastery rewards for the Brock→Misty prototype.
6. Define evolution tiers for only the families present in that prototype.
7. Define the first Trainer-Rank Training Budget + Focus model and compare its stat outputs against vanilla EV outcomes.
8. Prototype before expanding across Kanto.


---

# 26. 2026-09-29 continuation — world fit, mod architecture, move loadouts, and deeper stress test

This section records the subsequent design discussion and **supersedes earlier implementation preferences where they conflict**. Earlier sections remain in this file as decision history.

## A. This is a FireRedRecomp mod, not a FireRedRecomp rewrite

The progression redesign should be implemented as a **ruleset/gameplay mod for FireRedRecomp**.

FireRedRecomp itself should remain capable of vanilla FireRed behavior when the mod is absent.

Conceptual architecture:

```text
FireRedRecomp
│
├── vanilla FireRed behavior
├── ROM-imported data
└── generic mod hooks / extension points
        │
        ▼
TrainerProgression mod
├── trainer standard
├── catch-up training
├── evolution rules
├── move loadout management
├── optional stat-system changes
└── mod save data
```

Important boundary:

> **Do not put Trainer Progression rules into the recomp core merely because a needed hook is missing.**

If FireRedRecomp lacks an extension point, add the smallest generic hook needed by gameplay mods. The progression rules themselves stay in the mod.

Potential generic hooks the mod may eventually need:

- Pokémon caught;
- Pokémon gains EXP / level;
- Pokémon Center interaction;
- evolution eligibility check;
- battle victory;
- EV award modification;
- badge stat modifier override;
- save/load extension data;
- party/PC Pokémon identity tracking;
- move-selection/loadout query.

No FireRedRecomp runtime code should be changed during design work. The recomp is currently a read-only implementation reference.

## B. In-world framing

The system should feel like an extension of Kanto's existing institutions rather than a new RPG framework.

### League certification

Badges and major League milestones certify the player's ability as a trainer.

The League is not magically strengthening Pokémon. It is recognizing:

> **how advanced a level of training the player has demonstrated they can safely and competently provide.**

This certification can drive a **Training Standard**.

Pokémon Centers then provide services appropriate to that certification.

### Pokémon Centers as training infrastructure

Centers already heal, store, and manage Pokémon using advanced technology.

The redesign can make them the natural place for:

- healing;
- training a Pokémon to the current Trainer Standard;
- building a Pokémon's active move loadout;
- possibly checking bond/friendship;
- later, if needed, stat-training management.

The game abstracts away repetitive conditioning the player has already proven capable of doing.

### Professor Oak / Pokédex

Oak and the Pokédex can provide the explanatory frame:

> Pokémon grow through experience, but trainers also become more capable. As the player earns League certification, Centers can provide more advanced training support.

Do not bury the player in a large tutorial. Introduce services only when first unlocked.

---

# 27. Trainer Rank simplification → Training Standard

The terminology should probably collapse further.

Rather than exposing:

```text
Trainer Rank IV
Training Floor 34
Evolution Tier III
```

prefer one meaningful number:

> **TRAINING STANDARD: Lv. 34**

That number means:

> "The player has demonstrated the ability to train owned Pokémon reliably to roughly this level of development."

A hidden/displayed rank name may still exist for flavor, but it should not be another mechanical axis.

## Training to Standard

At a Pokémon Center / PC:

```text
CUBONE Lv. 21
Training Standard: Lv. 32

TRAIN TO STANDARD?
→ Cubone Lv. 32
```

Rules:

- optional, never automatic;
- free for ordinary owned Pokémon;
- grants exactly the EXP needed to reach the Standard;
- does not affect Pokémon already above it;
- Pokémon continue gaining EXP normally above the Standard;
- Standard should sit near the **lower edge of the expected party band**, probably around 2–4 levels below the normal leading party, not equal to the strongest expected Pokémon;
- do not derive it from the player's highest-level Pokémon.

This deliberately makes wild levels below the current Standard less strategically important. That is an accepted tradeoff if the system successfully removes roster-switching grind.

### Why a free floor is preferable to giant catch-up multipliers

It:

- removes rather than accelerates solved grinding;
- avoids species growth-curve discrepancies;
- avoids explosive stacking with Lucky Egg, trainer battle EXP, traded EXP, Exp. Share, etc.;
- is easy to understand;
- keeps Rare Candy, Exp. Share, Lucky Egg, Daycare, and ordinary EXP relevant **above** the Standard.

## Gym order problem

Do not assume simple badge count maps perfectly to difficulty because Kanto's middle-game Gym order is flexible.

Potential solution:

- each major certification/milestone has its own supported Training Standard;
- current Standard is the highest legitimate certification earned.

This should be derived from the actual campaign/boss-level map, not guessed.

---

# 28. Evolution redesign — species-specific Trainer Standard, not broad Evolution Tiers

Broad Evolution Tiers have a major failure mode:

> one badge can suddenly unlock many final evolutions at once, causing an abrupt base-stat power spike.

Therefore broad Evolution Tiers are no longer preferred.

## Preferred rule

Former level-based evolutions become **species-specific Trainer Standard requirements**.

Conceptually:

```text
Charmander → Charmeleon
requires trainer capable of roughly Lv. 16 development

Charmeleon → Charizard
requires roughly Lv. 36 development

Magikarp → Gyarados
requires roughly Lv. 20 development

Dratini → Dragonair
requires roughly Lv. 30 development

Dragonair → Dragonite
requires roughly Lv. 55-class trainer capability
```

Exact values are not frozen.

Crucially:

> **The Pokémon itself does not need to be that level. The trainer needs to have reached the corresponding Training Standard.**

This preserves species-specific evolution pacing while removing the individual grind gate.

## Remove the generic Evolution Catalyst unless testing proves a need

The earlier reusable Evolution Catalyst is likely unnecessary.

Once eligible:

```text
Pokémon
→ EVOLUTION AVAILABLE
→ player chooses EVOLVE
```

Existing thematic evolution methods remain:

- elemental/evolution stones;
- friendship;
- trade-with-item concepts;
- an in-game Linking-Cord-style solution for pure trade evolutions;
- Everstone still blocks evolution;
- unusual thematic conditions can remain if they are not grindy.

The League certification is about the trainer's ability to **guide** an evolution, not whether that species is biologically capable of evolving in the wild.

---

# 29. Move system — PC loadouts replace missed-level prompts and most move-memory bookkeeping

A major simplification emerged:

> **The PC should let the player freely configure a Pokémon's active move loadout from every move that Pokémon is currently qualified to use.**

The four active battle slots remain a loadout choice rather than permanent memory.

## Natural-move eligibility

At a PC, a Pokémon may freely equip any natural level-up move that:

1. belongs to its current evolutionary stage **or an earlier stage in its own evolution line**;
2. has a learn level at or below the Pokémon's current real level.

Do not grant moves from future evolutionary stages.

Example:

```text
Charmeleon Lv. 32

eligible:
Charmander natural moves ≤ 32
+
Charmeleon natural moves ≤ 32

not eligible:
Charizard-only moves
```

This removes:

- missed level-up prompts;
- "evolved too early and lost a move" traps;
- the need to simulate 15 level-up move prompts during Train to Standard;
- most need for a separate persistent "natural move memory" database.

FireRed already contains Move Relearner logic (`GetMoveRelearnerMoves`) that demonstrates this basic concept is native to the game. ROM hacks commonly expand move relearning convenience; the mod should adopt the simple principle rather than preserve vanilla friction.

## Catch-up flow

```text
Catch Cubone Lv. 21
↓
Center / PC
↓
Train to Standard → Lv. 32
↓
Configure Moves
↓
choose any eligible natural moves ≤ Lv. 32
↓
leave Center with a usable build
```

No automatic move-learning dialogue is needed during the level jump.

## Why PC-only matters

Move swapping should not be available everywhere.

PC/Center-only loadout changes preserve:

> **preparation as a strategic boundary.**

The player decides what four moves to bring for the next expedition or boss rather than adapting perfectly after every encounter.

This keeps the move limit meaningful while removing permanent mistakes.

---

# 30. TM / tutor moves under PC loadouts

Natural moves and acquired special moves should be treated differently.

## Natural moves

Always freely reconfigurable at the PC if currently eligible by species/evolution line + level.

## TM moves

Do **not** automatically appear merely because the species is compatible.

A TM/tutor move must first be legitimately acquired/assigned according to the active balance rules.

The frozen balance package currently relies on meaningful scarcity for some one-copy TMs. Therefore the progression mod should not silently make all TMs reusable.

Minimum safe policy:

- TM is acquired/used under current scarcity rules;
- once that Pokémon has legitimate access to the technique, it can swap it in/out at the PC without permanently forgetting it.

Unresolved stronger alternative:

### Transferable TM license

A one-copy TM could represent one team-wide license:

```text
TM19 assigned to Gengar
→ Gengar may equip Giga Drain

later:
move TM19 assignment to Vileplume
→ Vileplume may equip it
→ Gengar loses access
```

This would preserve one-copy scarcity while avoiding permanent roster lock-in.

Do not adopt this until the frozen balance assumptions are explicitly reopened.

## Tutors

Special tutor moves should behave like acquired techniques, not natural moves. Once legitimately granted to a Pokémon, PC loadout swapping may preserve access.

---

# 31. Four moves vs six moves

The four-move limit is inherited rather than sacred and should be tested.

FireRed hardcodes `MAX_MON_MOVES 4` throughout:

- BoxPokemon move/PP storage;
- battle controllers;
- AI;
- battle UI;
- trading;
- daycare;
- move deletion;
- PP Up handling;
- Imprison;
- field-move scans;
- evolution/move-learning paths.

For a FireRedRecomp mod, six is more feasible than on original GBA hardware, but it would be a substantial battle-format change, not a trivial constant adjustment.

## Four-move argument

Four moves create a meaningful constraint:

> a Pokémon cannot use every technique it is capable of using at once.

With PC loadout swapping, the punitive permanence is removed while preparation choices remain.

This likely helps maintain reasons to switch Pokémon.

## Six-move argument

Six could:

- increase tactical options per Pokémon;
- make a Pokémon feel more like it genuinely "knows" several techniques;
- reduce artificiality of the historical four-move cap.

But likely risks:

- broad-movepool Pokémon gain disproportionately;
- coverage becomes too easy;
- healing/setup/status can fit alongside full STAB/coverage;
- generalists such as Starmie/Nidoking/Gengar/Dragonite may become even more dominant;
- less need to switch Pokémon;
- boss and AI movepools need redesign;
- battle UI/AI complexity grows.

## Explicit experiment

Prototype both:

| Arm | Active battle moves | PC swapping |
| --- | ---: | --- |
| A | 4 | yes |
| B | 6 | yes |

Measure:

- Pokémon switching frequency;
- number of actually used moves;
- coverage breadth;
- boss difficulty;
- dominance of broad-movepool species;
- cognitive/UI burden;
- whether six creates meaningful choices or simply removes tradeoffs.

Current prior:

> **4 active moves + free PC loadout configuration is probably the cleaner baseline, but six deserves a real prototype rather than being dismissed because tradition says four.**

A six-prepared/four-active intermediate system was considered but currently appears to add management without enough benefit.

---

# 32. PP Ups under swappable loadouts

Vanilla FireRed stores PP Up investment per move slot, which conflicts with freely changing active moves.

Under this mod, PP investment should conceptually belong to:

> **that move on that individual Pokémon**

rather than to physical move slot 1/2/3/4.

If Bonemerang has two PP Ups and is temporarily removed from Cubone's active loadout, restoring Bonemerang should restore its PP investment.

Implementation details remain unresolved because this may require mod-side metadata.

Do not allow loadout swapping to erase, duplicate, or transfer PP investment accidentally.

---

# 33. HM / field-move problem

PC move swapping exposes a classic HM problem:

> remove Surf at a PC after reaching a location that requires Surf to leave.

Possible approaches:

1. prevent removal when it would strand the player — accurate but messy;
2. warn the player and preserve emergency escape logic;
3. ultimately separate field abilities from battle moves.

The long-term clean solution is probably:

> **field capability should not consume battle loadout slots.**

That is a broader redesign and should remain separate until needed.

For a first prototype, preserve HM compatibility and explicitly audit any location that can strand the player.

---

# 34. Deeper flaws found in the current system

## 34.1 Training Standard weakens wild-level meaning

Below the Standard, wild level becomes mostly temporary.

A Lv. 20 and Lv. 28 capture may both become Lv. 32 at the next Center.

Possible acceptable residual value of higher wild levels:

- immediate usability before reaching a Center;
- access to higher natural moves immediately;
- may already exceed the Standard;
- lower time/distance to next Center matters during an expedition.

This is a real cost of the anti-grind philosophy, not something to hide.

## 34.2 EXP rewards below Standard lose importance

This affects:

- Lucky Egg;
- Exp. Share;
- trainer battle EXP;
- Daycare;
- Rare Candy.

Current view:

- these remain meaningful above the Standard;
- Rare Candy becomes primarily an above-standard progression tool;
- Exp. Share/Lucky Egg become tools for maintaining/overleveling rather than mandatory catch-up;
- Daycare's leveling function may become largely obsolete and may eventually become primarily breeding/bonding infrastructure.

## 34.3 Traded Pokémon / obedience conflict

If an outsider Pokémon is trained above the current obedience threshold, the convenience feature can make it worse.

Rule candidate:

```text
outsider training target =
min(Training Standard, current obedience limit)
```

Surface this clearly to the player.

Do not blindly level traded Pokémon past safe obedience.

## 34.4 Friendship during catch-up

Do not simulate every skipped level as an individual friendship increase.

A 20-level Center jump should not grant 20 level-up friendship events.

Preferred interpretation:

> Center catch-up is one structured training event, with at most one bounded friendship/bond adjustment.

## 34.5 Longtime Pokémon identity

A free floor reduces mathematical catch-up debt, which is intentional.

Longtime Pokémon can still differ through:

- being naturally a few levels above Standard;
- friendship;
- history/records/ribbons;
- accumulated special move access;
- player attachment.

Do not intentionally make new Pokémon weak merely to manufacture attachment.

## 34.6 Overlevel grinding still exists

This is acceptable.

The goal is **not** to prohibit grinding.

The goal is:

> **grinding should not be required to make a newly chosen Pokémon usable.**

Players may still deliberately overlevel if they enjoy doing so.

---

# 35. EV system — do less first

The earlier Training Point / Training Focus redesign may be solving too much at once.

EVs are definitely a hidden catch-up problem, but a full replacement could over-optimize every Pokémon and create another management system.

Preferred first experiment:

> **disable passive EV gain entirely in the progression ruleset prototype.**

Then player stats come from:

- species/base stats;
- real level;
- IVs;
- Nature.

This removes hidden training debt without immediately introducing another customization layer.

Then test:

> Does the game actually feel worse without stat specialization?

Only if the answer is yes should a simple Training Focus system be added.

This also means Macho Brace and Pokérus may lose their original purpose. Do not invent replacement mechanics merely to preserve them.

---

# 36. Type Mastery — demoted from V1

Type Mastery remains an interesting concept but has not yet earned its complexity.

Failure dilemma:

- if rewards are strong, specialization discourages trying new types;
- if weak, the system is unnecessary;
- if earned by repetition, it becomes grind;
- if earned by unique accomplishments, it risks checklist gameplay.

Therefore:

> **Do not include Type Mastery in the first playable progression prototype.**

Revisit it only if the lean system leaves trainer identity/progression feeling empty.

The same applies to Species Familiarity: it is currently unnecessary.

---

# 37. Hidden badge stat boosts

The mod should strongly consider suppressing FireRed's hidden badge stat boosts.

FireRed secretly grants +10% combat-stat boosts from certain badges.

Under the new model badges/certification already improve the player's practical capability through Training Standard.

Keeping hidden raw stat multipliers risks double-dipping and opaque power spikes.

This should be an explicit prototype arm, not silently assumed.

---

# 38. Mod save / compatibility risks

This is a **ruleset mod**, not a cosmetic toggle.

Once it has:

- trained a Pokémon to Standard;
- altered EV behavior;
- enabled manual evolution;
- recorded special/TM/tutor access;
- possibly stored PP-per-move metadata;

those changes are not necessarily reversible if the mod is disabled.

Therefore saves should know:

```text
ruleset/mod enabled
mod version
mod-extension state version
```

Do not promise clean mid-save disable/enable unless migration rules are deliberately implemented.

## Stable Pokémon identity

Any per-individual metadata must follow a Pokémon through:

```text
party → PC box → party → trade-like movement
```

Never key mod data to party slot.

A FireRed-derived identity such as:

```text
OT ID + personality
```

is an obvious starting fingerprint, but cloning/trading/duplication edge cases need explicit treatment.

## Mod composition

Progression must evaluate the **final active game data**, not assume vanilla ROM tables.

Intended conceptual order:

```text
ROM data
↓
balance/data overlays
↓
progression rules query the resulting data
```

Example:

If the balance mod changes Gengar's learnset, the PC loadout system must use the modified learnset.

This is critical for compatibility with the frozen balance package.

---

# 39. Lean prototype v3 — current strongest candidate

The progression prototype should now be much smaller than earlier versions.

## Keep

- real Pokémon levels;
- real EXP above the current Standard;
- species growth curves;
- IVs;
- Natures;
- friendship;
- natural level-up learnsets as source data;
- existing TM scarcity unless separately reopened.

## Add

### 1. Training Standard

League/story certification establishes the level to which the player can freely prepare owned Pokémon at a Center/PC.

### 2. Train to Standard

Optional free catch-up.

No repetitive battle requirement.

### 3. Species-specific evolution certification

Former level evolutions use Trainer Standard requirements rather than the individual Pokémon's level.

Manual player-triggered evolution once eligible.

### 4. PC move loadout configuration

At a PC, freely choose active natural moves from:

```text
current stage
+
previous evolution stages
+
learn level <= current Pokémon level
```

Special/TM/tutor access remains separately gated by acquisition.

### 5. Single-player trade evolution solution

Linking-Cord-style solution or equivalent.

### 6. EV-off prototype arm

Disable passive EV accumulation and test whether stat customization is actually missed.

### 7. Hidden badge stat-boost-off prototype arm

Test campaign balance without the invisible 10% badge combat modifiers.

## Explicitly do NOT add yet

- Trainer XP;
- Type Mastery;
- Species Familiarity;
- Evolution Tiers;
- Evolution Catalyst;
- Training Points;
- Training Focus;
- Auto Train currency;
- giant catch-up EXP multipliers;
- universal reusable TMs.

---

# 40. Current end-to-end player loop

The latest design produces a much clearer loop:

```text
EXPLORE
↓
catch interesting Pokémon
↓
learn what challenge is ahead
↓
return to Pokémon Center / PC
↓
TRAIN TO STANDARD
↓
configure active move loadout
↓
evolve eligible Pokémon if desired
↓
build party
↓
leave Center
↓
BATTLE / EXPLORE
```

The PC/Center becomes the **team workshop**.

The strategy becomes:

> "Which Pokémon and which active techniques do I want for this expedition?"

rather than:

> "Am I willing to spend 45 minutes grinding this Pokémon before I can find out whether it was a good idea?"

Primary design maxim remains:

> **Changing your team should cost decisions, not time.**

---

# 41. Next concrete design work

1. Build the real campaign **Training Standard table** from the existing boss/route level research and FireRed decomp.
2. Build a first-pass **species-specific evolution certification table**, initially derived from vanilla evolution levels and then hand-tuned for outliers.
3. Audit natural learnsets for **pre-evolution-only / earlier-access moves** under the PC loadout rule.
4. Define exact TM/tutor access semantics under PC loadouts without breaking the frozen balance package.
5. Audit HMs/field moves for possible stranding under free PC move swapping.
6. Define traded-Pokémon obedience behavior during Train to Standard.
7. Define friendship behavior for Center catch-up.
8. Prototype **4 active moves vs 6 active moves** as separate experimental arms.
9. Prototype **EV-off vs vanilla-EV** arms before designing a replacement EV system.
10. Keep Type Mastery out of V1 and only revisit it if playtesting identifies a real missing need.
