# Team Synergy and Combined Techniques

**Status:** design candidate, not adopted mechanics.

The desired progression is:

> **Early:** six Pokémon that happen to fight together.  
> **Mid:** Pokémon deliberately cover each other's weaknesses.  
> **Late:** the team feels like a coordinated machine.

## Add team contribution to the role model

Think in this order:

> **Species → role → team contribution → synergy hooks**

A Pokémon should be evaluated partly by what it creates for teammates, not only by its own neutral damage.

Examples:

- Sleep Powder creates a safe switch/setup window.
- Thunder Wave lets slower heavy hitters function.
- Will-O-Wisp increases the effective durability of physical walls.
- Reflect/Light Screen create setup windows.
- Leech Seed creates shared sustain/attrition pressure.
- Roar + Spikes converts forced switching into team damage.

## Prefer emergent synergy

Avoid arbitrary bonuses such as:

> "Sleep Powder makes Charizard deal +20%."

Prefer native-mechanics interactions:

- Burn → lower physical damage.
- Rain → Water up / Fire down.
- Paralysis → lower Speed.
- Screens → team durability.
- Leech Seed → sustain.
- Sleep → setup/switch opportunity.
- Spikes → switching has a cost.
- Roar → forced movement.
- trapping → creates positional commitment.

This keeps team building discoverable rather than turning it into fixed recipe teams.

## Four active moves should probably remain

Do **not** remove the four-move limit by default.

Four active slots force specialization. If every Pokémon can carry STAB, coverage, status, recovery, setup, and utility simultaneously, teammates become less necessary.

Preferred first prototype:

> **Permanent learned-move library + four active battle moves.**

A Pokémon remembers every move it has learned. At appropriate preparation points—likely PC/menu systems—the player can choose which four are currently active.

This removes the frustration of permanent deletion while preserving battle specialization.

### Separate A/B candidate

A possible later test is:

> **4 normal moves + 1 restricted utility/role slot**

The fifth slot would be limited to support/setup/control/recovery/field-utility categories rather than arbitrary damaging coverage.

This is **not preferred yet**; it needs A/B testing against the cleaner remembered-library model.

## Cross-Pokémon combo techniques

The combined-move idea is worth preserving as a later system candidate.

### Scalable model: synergy tags

Do not hard-code hundreds of species-pair recipes. Give moves semantic tags/states that another party member can consume.

Examples:

| Setup state | Potential finisher | Example payoff |
|---|---|---|
| RESTRAINED | aerial/heavy attack | accuracy, trap extension, modest power |
| UNBALANCED | Rollout/charge attack | improved momentum/start stage |
| SOAKED | Electric/Ice | stronger secondary interaction |
| ROOTED | Ground/Grass | trap/drain interaction |
| ASLEEP | setup/dream attack | safe setup / Dream Eater interaction |
| PARALYZED | slow heavy attacker | tempo conversion |
| SEEDED | stall/sustain tools | attrition/sustain loop |
| SCREENED | setup attacker | safer setup |

The first Pokémon creates the state. A different Pokémon consumes or benefits from it.

That requirement is important: if one Pokémon can create and consume the entire combo itself, it is moveset synergy rather than team synergy.

### Singles-friendly state persistence

FireRed is mostly singles, so the setup state can persist briefly across switching.

Example:

```
Butterfree → String Shot / bind-like setup
target gains RESTRAINED for a short window
switch to Pidgeot
Pidgeot → Fly / Wing Attack
combo payoff
```

This turns switching from only "fix the matchup" into "execute the team plan."

### Named Dual Techniques

Use generic tags for scalability, then add a small number of memorable named combinations.

Examples under consideration:

- **Magnitude → Rollout**: terrain is destabilized; Rollout starts with improved momentum or a modest bonus.
- **Bind → Fly**: restrained target enables an aerial finisher with accuracy/trap payoff.
- **Leech Seed + poison**: attrition interaction, preferably utility/sustain rather than huge burst damage.

### Balance rule for combos

A combo should usually be:

> **better than the two moves independently, but not massively better than two optimal normal turns.**

Prefer 10–30% tactical value through utility, reliability, positioning, sustain, or status rather than giant damage multipliers.

## Type ecosystems as team ecosystems

Types can contribute differently to synergy:

- Bug — powders, trapping, speed control, setup, Baton-Pass-like enabling.
- Psychic — screens, Disable-style control, recovery, setup.
- Rock — tanking, hazards, forced movement, defense setup.
- Poison — attrition, debuffs, status pressure.
- Grass — sustain, seed/powder states.
- Electric — tempo/paralysis.
- Flying — speed and state conversion.
- Normal — flexible glue.

This should reinforce type identity without hard-locking every species into one job.
