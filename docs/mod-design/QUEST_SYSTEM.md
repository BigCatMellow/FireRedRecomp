# FireRedRecomp Mod Design Snapshot — Quest System

> Imported from `BigCatMellow/Pilot_Projects` for durable FireRedRecomp-side design reference.
>
> Source branch: `pokemon-firered-balance-bootstrap`
>
> Source blob: `0a27b3933d5afa1ffa828a6bec43d4b3a3f560e9`
>
> This is design documentation only. It does not modify FireRedRecomp runtime behavior.

---

# Quest / Mission System Reevaluation

- Record role: `DESIGN / RESEARCH`
- Status: `ACTIVE CANDIDATE — DISCOVERY / NO IMPLEMENTATION YET`
- Authority: `ADVISORY / NONE`
- Parent: Pokémon FireRed balance / FireRedRecomp ruleset work
- Scope: quest architecture, quest UX, rewards, discovery, world reactivity
- Implementation target: eventual FireRedRecomp gameplay mod/ruleset layer, not vanilla recomp behavior
- Date opened: 2026-09-29

## Core question

FireRed already contains many events that are effectively quest-shaped, but it does not present them as a coherent modern quest system.

The goal is not to turn Kanto into an MMO task board.

> **Make optional adventures easy to discover, easy to remember, worth doing, and integrated into the world.**

A good quest system should make Kanto feel more alive without turning exploration into a checklist.

---

# 1. Pokémon Unbound — what it gets right

Pokémon Unbound is the primary reference because its Mission system proves a GBA-style Pokémon game can support a coherent quest layer without ceasing to feel like Pokémon.

## 1.1 Mission Log from the beginning

The player gets a Mission Log early. It tracks main-story and optional missions instead of expecting the player to remember one-off NPC dialogue.

The important principle:

> **Memory should not be the difficulty of a quest.**

## 1.2 Automatic bookkeeping

Unbound's log tracks progress on things such as Zygarde Cells, Trainer Tips signs, Raid Dens, and other region-wide collections.

If the game asks the player to find many things, the game should remember what has already been found.

The player should solve the search problem, not maintain a spreadsheet.

## 1.3 Late-game discovery assistance

Later in Unbound, undiscovered missions can appear as question-mark entries with location information. This is a strong completionist compromise:

- early game preserves discovery;
- late/postgame reduces wiki dependence.

## 1.4 Rewards frequently unlock something interesting

Unbound frequently uses Pokémon, TMs, special items, system upgrades, rare resources, or new mission access instead of defaulting to money.

Preferred reward question:

> **What new possibility did this unlock?**

## 1.5 Good missions use Pokémon's existing verbs

Useful quest verbs already exist:

- catch;
- evolve;
- battle;
- fish;
- breed;
- explore;
- observe;
- use field abilities;
- interact with trainers and Pokémon.

Do not invent a special minigame for every side quest unless the quest truly needs it.

## 1.6 Local chains make places feel like communities

Unbound's Antisis mission chain is a useful structural example: several small local jobs contribute toward a larger faction conflict and culminating confrontation.

Kanto should have small local arcs, not only isolated NPC errands.

## 1.7 Memorable little stories matter

Some Unbound quests begin with a simple problem and then reveal a more sympathetic or unexpected explanation involving Pokémon.

> **A side quest should reveal something about the world, a person, or a Pokémon — not merely consume time.**

---

# 2. Pokémon Unbound — what not to copy blindly

Unbound's mission infrastructure is stronger than every individual mission.

Some missions are essentially long counters or chores:

- walk a huge number of steps;
- save many times;
- fish 10 / 50 / 100 times;
- evolve very large numbers of Pokémon;
- collect large region-wide sets.

These are often better treated as achievements, research milestones, or background completion goals rather than the model for normal side quests.

> **Copy Unbound's Mission Log and support systems. Do not assume every Unbound mission is ideal quest design.**

---

# 3. Other Pokémon / ROM-hack lessons

## 3.1 Pokémon Infinite Fusion

Infinite Fusion uses a Quest Journal with active/completed quests and several categories, including field, hotel, Team Rocket, and legendary quests. It also gives cumulative rewards for completing numbers of quests.

Useful lessons:

- categories help when the list becomes long;
- quest hubs can improve discoverability;
- faction/choice quests can create world reactivity;
- cumulative rewards can encourage optional play.

Risks:

- universal quest hubs can make problems feel like jobs posted on a board rather than things happening to people;
- completion-count rewards can pressure players into clearing weak quests just to fill a meter.

For Kanto, NPC/world-first discovery is preferable to making every town a quest board.

## 3.2 Pokémon Reborn

Community complaints about the absence of a quest tracker reinforce a simple lesson: once the player discovers an unresolved side story, the game should remember it for them.

---

# 4. Broader RPG lessons

## 4.1 The Witcher 3 / CD Projekt

A strong side quest should try to contain at least one memorable element:

- twist;
- character revelation;
- unexpected result;
- choice;
- discovery;
- unusual use of a normal mechanic.

A fetch quest can be short. It should not be empty.

## 4.2 Xenoblade

Generic objectives often auto-complete once fulfilled, while named-NPC quests can become annoying when the player must track the giver down again just to turn in a mechanical task.

Rule:

> **Require a return to the quest giver only when the return conversation or world change matters.**

## 4.3 Majora's Mask

The Bombers' Notebook tracks people, places, schedules, rumors, ongoing events, and completed events.

This is a better emotional model than a sterile checklist.

Our journal should feel like:

> **a trainer's notebook about people, Pokémon, rumors, and unresolved situations in Kanto**

rather than:

> `QUEST 34: COLLECT 7 ITEMS`

## 4.4 New Vegas / honeycomb structure

Some larger local problems can support several optional satellite quests. Completing different subsets can alter or simplify the central resolution.

This structure fits:

- Saffron / Silph;
- Lavender;
- Safari Zone;
- Cinnabar research;
- Sevii local conflicts;
- Team Rocket aftermath.

Use sparingly because state complexity grows quickly.

---

# 5. Proposed FireRed quest philosophy

## Principle 1 — quests belong to the world

A quest begins because someone has a problem, something strange happened, a Pokémon behaves unusually, a place changed, or an institution needs help.

Avoid NPCs who exist solely as quest dispensers.

## Principle 2 — discovery first, tracking second

Before discovery, let the player explore through dialogue, rumors, environmental clues, and visible events.

After discovery, log the quest clearly and remember the bookkeeping.

## Principle 3 — the journal should eliminate memory burden, not puzzle solving

The journal should answer:

- Who asked me?
- Where were they?
- What happened?
- What do I currently know?
- What is the next broad objective?
- What progress have I already made?

It should not automatically give exact coordinates or puzzle solutions.

## Principle 4 — rewards should expand play

Prefer:

- Pokémon or unusual encounters;
- TMs / tutor access;
- held items;
- evolution/training conveniences;
- access to locations;
- shortcuts;
- services;
- cosmetics / collection rewards;
- changed NPC/world states;
- clues to larger mysteries.

Plain money/consumables are fine for very small errands.

## Principle 5 — no essential systems behind arbitrary quest-count grinding

Do not require 30 unrelated quests to unlock a core quality-of-life or battle system.

Completion milestones should mostly reward optional/completionist content.

## Principle 6 — quest length should match the idea

Do not stretch a two-minute idea into a 30-minute fetch chain.

## Principle 7 — use Pokémon mechanics as verbs

Prefer catch, battle, show, evolve, observe, follow, explore, trade, field ability, and route/dungeon interaction over arbitrary counters.

## Principle 8 — ordinary side quests should not be permanently missable

Default expectation: if a quest becomes available, the player can eventually complete it.

---

# 6. Quest taxonomy

Keep categories small:

## STORY
Main journey, League, Team Rocket, Pokémon Tower, Sevii main arc.

## LOCAL
Town/character/Pokémon side stories. This should be the heart of the system.

## TRAINER
Battling and team-building challenges.

## RESEARCH
Oak, aides, scientists, habitats, fossils, evolution, breeding, moves.

## MYSTERY
Rumors, hidden places, rare Pokémon, postgame discoveries.

---

# 7. Quest log UX

Example list:

```text
MISSIONS

STORY
  The Road to Fuchsia

LOCAL
  A Restless Cubone
  The Missing Shipment

RESEARCH
  Moon Stone Study

MYSTERY
  Strange Lights on Route 10
```

Statuses:

- New;
- Active;
- Ready to Report;
- Completed;
- Rumor / undiscovered hint when intentionally revealed.

Example detail:

```text
A RESTLESS CUBONE

Lavender Town

Mr. Fuji is worried about a Cubone
that keeps returning to Pokémon Tower.

What you know:
• Cubone entered the tower.
• A Channeler heard crying near 3F.

Next:
Investigate Pokémon Tower.
```

The language should read like notes, not developer objectives.

Progress counters should appear only when counting is genuinely useful.

---

# 8. Discovery / hint model

## Early / normal play

- quest giver or event must be discovered naturally;
- journal shows broad town/route information;
- no exact objective arrow by default.

## Optional hint

The player can request a broader hint if stuck.

## Postgame / completion mode

Reveal undiscovered mission-giver town/location, borrowing Unbound's excellent cleanup approach.

---

# 9. Completion / turn-in rules

## AUTO-COMPLETE

Use when returning adds no meaningful interaction.

## READY TO REPORT

Use when the giver's reaction matters.

## WORLD-COMPLETE

Some quests end by changing the environment or community: bridge repaired, shop reopened, cave cleared, Pokémon disturbance resolved.

The changed world can be part of the reward.

---

# 10. Existing FireRed content audit

First identify content that is already quest-shaped before inventing dozens of new quests.

Candidates to audit:

- Bill / Sea Cottage;
- Mr. Fuji / Pokémon Tower;
- Copycat;
- Pokémon Fan Club;
- Fishing Gurus;
- fossil restoration;
- Move Tutors;
- Day Care;
- Safari Zone Warden / teeth / Surf;
- Silph employees after liberation;
- Power Plant;
- legendary birds;
- Sevii Island errands;
- Lostelle;
- Network Machine;
- Tanoby / Unown mysteries;
- in-game trades;
- aides / Pokédex milestones;
- Game Corner / Rocket Hideout aftermath;
- S.S. Anne NPC micro-stories.

Do not label every interaction as a quest.

Ask:

> **Would recording this help the player remember a meaningful unresolved situation?**

If no, leave it as ordinary world interaction.

---

# 11. New quest design targets

A new quest should primarily accomplish at least one of these:

1. Characterize a town or person.
2. Teach a Pokémon mechanic naturally.
3. Make an underused location worth revisiting.
4. Create a memorable Pokémon encounter.
5. Show consequences of the main story.
6. Give a meaningful optional reward.
7. Connect pieces of Kanto that previously felt unrelated.
8. Seed a mystery that resolves later.

If it accomplishes none of these, it probably should not exist.

---

# 12. Anti-patterns

Reject or heavily constrain:

- fetch quest with no transformation;
- counter grind presented as normal questing;
- return-to-giver tax;
- exact-marker dependence;
- ordinary permanently missable quests;
- essential mechanics behind quest-count milestones;
- quest spam / every NPC having an icon.

Ordinary NPC dialogue is valuable because not every conversation should become a task.

---

# 13. Prototype

Start small:

```text
Pallet
Viridian
Pewter
Route 1
Route 2
Viridian Forest
early Mt. Moon
```

Prototype only:

- 1 main-story journal entry;
- 2–3 local character quests;
- 1 research/background objective;
- 1 trainer challenge;
- 1 small mystery that cannot fully resolve yet.

Measure:

- do players discover quests naturally?
- do they remember what they were doing?
- do they use the journal?
- does the journal help without solving the quest?
- are rewards exciting?
- is backtracking useful or annoying?
- do quest icons create completion pressure?
- do towns become more memorable?
- does normal NPC dialogue still feel distinct?

---

# 14. Current strongest recommendation

Build around three borrowed ideas:

## From Unbound
**Mission Log + automatic bookkeeping + late-game undiscovered-mission assistance.**

## From Majora's Mask
**Track people and unresolved situations, not only objective checklists.**

## From Witcher / New Vegas-style quest design
**Optional content should reveal character/world information, use core mechanics, and sometimes influence larger local situations.**

The target feel:

> **a trainer's notebook of people, Pokémon, rumors, and problems encountered while traveling through Kanto**

not an MMO quest tracker.

---

# 15. Research references

- Unbound Mission Log / missions:
  - https://unboundwiki.com/locations/frozen-heights/
  - https://unboundwiki.com/missions/mission-070/
  - https://unboundwiki.com/missions/mission-013/
  - https://unboundwiki.com/walkthrough/part-40/
  - https://pokemonunbound.fandom.com/wiki/Missions_Masterlist
- Infinite Fusion quests:
  - https://infinitefusion.fandom.com/wiki/Quests
- Quest-design references:
  - https://www.gamedeveloper.com/design/designing-side-quests-study-these-7-games-and-some-chris-avellone-pointers-
  - https://www.gdcvault.com/play/1028897/10-Key-Quest-Design-Lessons
- Majora's Mask Bombers' Notebook:
  - https://www.zeldadungeon.net/wiki/Bombers%27_Notebook

---

# 16. Next work

1. Audit FireRed's existing optional events and classify which are already quest-shaped.
2. Build a Kanto quest-opportunity map by town/route.
3. Separate existing content that only needs logging, existing content worth expanding, and genuinely new quests.
4. Design the journal data model.
5. Draft the first Pallet→Pewter prototype quests.
6. Stress-test quest rewards against the balance/progression redesign.
7. Keep quest implementation as a gameplay-mod concern; FireRedRecomp core should expose only generic hooks if required.

---

# 17. Decomp-guided implementation model

Pinned source reference for this audit:

`pret/pokefirered@037335f4c725d7c9aecdac87066f2002b4bd7e14`

A major finding is that FireRed already contains **two systems adjacent to a modern quest journal**:

1. its existing **Quest Log** event recorder/replay system;
2. the **Fame Checker** people/fact-discovery system.

Neither is itself the mission journal we want, but both show useful existing architecture.

## 17.1 FireRed already has a Quest Log — but it is a recap recorder

The vanilla `quest_log.c` / `quest_log_events.c` system is the feature that plays "Previously on your quest..." scenes after resuming the game.

It stores recent scenes/actions and can replay:

- player/NPC movement;
- map state;
- some story flags/vars;
- object state;
- noteworthy gameplay events.

It is **not** a persistent side-quest list and should not be repurposed directly as one.

The important lesson is the event vocabulary FireRed already considers meaningful.

Vanilla `QL_EVENT_*` hooks include:

- switched party order;
- used item;
- held-item changes;
- used Pokémon Center;
- traded;
- PC deposit/withdraw/move actions;
- defeated Gym Leader;
- defeated wild Pokémon;
- defeated Elite Four member;
- defeated Champion;
- defeated normal trainer;
- departed/arrived at locations;
- used field move;
- bought/sold items;
- obtained story item.

This is extremely useful for the new mission system.

Rather than inventing dozens of bespoke quest counters, the mod can expose a generic gameplay-event stream modeled after these existing FireRed events.

Example:

```text
GAME EVENT
  type = defeated_trainer
  trainerId
  playerSpecies
  opponentSpecies
  mapSection
```

A quest objective can subscribe to it without owning battle code.

## 17.2 FireRed already snapshots story flags and vars for Quest Log playback

`event_data.c` routes reads/writes of persistent flags and vars through Quest Log recording while recap recording is active.

This matters because it confirms that FireRed's story progression is fundamentally represented by:

- persistent flags;
- persistent vars;
- inventory state;
- trainer flags;
- map/object-hide flags.

The modern mission journal should read those same authoritative states wherever possible.

Do **not** duplicate a vanilla story flag with a second mod-only "Bill helped" boolean unless the journal needs information vanilla never stores.

## 17.3 Do not use the old QuestLogScene save buffer for the new journal

Vanilla `SaveBlock1.questLog[]` stores recent replay scenes, action scripts, objects, and temporary snapshots.

Its lifecycle is wrong for permanent missions.

The new mod should instead keep a separate persistent quest-extension state containing only things vanilla cannot derive, such as:

- whether an optional quest has been *discovered* if vanilla has no durable discovery flag;
- player-selected tracking state;
- optional hint level;
- genuinely new quest states;
- custom counters not represented elsewhere.

Existing quest completion/stage state should remain derived from FireRed flags/vars/items when possible.

---

# 18. Fame Checker is a strong UI/data precedent

FireRed's Fame Checker is surprisingly close to the desired "people and unresolved situations" notebook philosophy.

The decomp shows:

- a scrollable list of people;
- unlocked vs locked people;
- question-mark panels for unknown facts;
- six discoverable fact panels per person;
- silhouettes / colored portraits;
- progressive discovery;
- saved persistent fact flags.

`struct FameCheckerSaveData` stores a small pick/display state plus a bitfield of discovered flavor-text facts for each tracked person.

The system tracks 16 notable people including:

- Oak;
- Daisy;
- Gym Leaders;
- Elite Four members;
- Bill;
- Mr. Fuji;
- Giovanni.

The scripts call a `famechecker` command at specific dialogue/story moments to unlock facts.

This gives us a strong precedent for a quest journal that is not merely:

```text
Quest 17
Objective 2 / 5
```

A modern journal can combine:

- mission status;
- people involved;
- discovered facts/rumors;
- question marks for intentionally unknown information;
- locations;
- current actionable note.

We should borrow the **information model**, not necessarily clone the exact Fame Checker screen.

---

# 19. Existing FireRed quests are already flag-driven state machines

Two concrete decomp examples:

## 19.1 Bill / Sea Cottage

Source:
`data/maps/Route25_SeaCottage/scripts.inc`

Relevant durable state includes:

- `FLAG_HELPED_BILL_IN_SEA_COTTAGE`;
- `FLAG_GOT_SS_TICKET`;
- related object-hide/system flags.

There is also a temporary `BILL_IN_TELEPORTER` flag used only inside the immediate sequence.

Bill's actual script already branches through states:

```text
not helped
→ ask player for help
→ Bill enters teleporter
→ player activates computer
→ FLAG_HELPED_BILL_IN_SEA_COTTAGE
→ Bill gives S.S. Ticket
→ FLAG_GOT_SS_TICKET
→ later dialogue changes again
```

### Journal interpretation

A modern quest definition could be mostly declarative:

```text
Quest: A Favor for Bill

DISCOVERED
player actually talks to Bill before helping him
(mod-only discovery bit if no vanilla durable flag captures this)

ACTIVE
FLAG_HELPED_BILL_IN_SEA_COTTAGE == false

HELPED
FLAG_HELPED_BILL_IN_SEA_COTTAGE == true
and FLAG_GOT_SS_TICKET == false

COMPLETE
FLAG_GOT_SS_TICKET == true
```

The journal should **not** depend on `BILL_IN_TELEPORTER` because it is a temporary map-state flag.

This illustrates an important rule:

> **Use durable story state for journal stages; use temporary script flags only for immediate scene presentation.**

## 19.2 Safari Warden / Gold Teeth

Source:
`data/maps/FuchsiaCity_WardensHouse/scripts.inc`

The Warden script already checks:

- whether the Gold Teeth overworld object has been removed/hidden;
- whether HM04 has already been received;
- inventory possession/removal of `ITEM_GOLD_TEETH`;
- `FLAG_GOT_HM04`.

Flow:

```text
talk to Warden
→ player learns something is wrong

find Gold Teeth in Safari Zone
→ story item acquired / object hidden

return to Warden
→ Gold Teeth removed
→ HM04 awarded
→ FLAG_GOT_HM04
```

### Important opportunity

The mission system does not even need the player to talk to the Warden first.

If the player finds Gold Teeth while exploring, the existing FireRed-style `OBTAINED_STORY_ITEM` event can trigger a journal note such as:

> "You found a set of Gold Teeth in the Safari Zone. Someone in Fuchsia may know who they belong to."

This is better than forcing every quest to begin at an NPC with an exclamation mark.

It demonstrates **event-driven quest discovery**.

---

# 20. Quest definitions should be declarative overlays on FireRed state

For vanilla content, prefer data definitions over rewritten scripts.

Conceptual mod definition:

```lua
{
  id = "bill_sea_cottage",
  category = "local",
  title = "A Favor for Bill",
  person = "Bill",
  location = "Route 25",

  discover = event.script_started("Route25_SeaCottage_EventScript_Bill"),

  stages = {
    {
      when = not flag("FLAG_HELPED_BILL_IN_SEA_COTTAGE"),
      note = "Bill needs help with his teleporter."
    },
    {
      when = flag("FLAG_HELPED_BILL_IN_SEA_COTTAGE")
          and not flag("FLAG_GOT_SS_TICKET"),
      note = "Bill is back to normal. Speak with him."
    },
    {
      when = flag("FLAG_GOT_SS_TICKET"),
      complete = true
    }
  }
}
```

This pseudocode is a design target, not current FireRedRecomp API.

Benefits:

- vanilla scripts remain authoritative;
- balance/story mods can change underlying content without the journal becoming the story engine;
- quest definitions are inspectable;
- existing flags/vars can be tested directly;
- new quests can still introduce their own mod state where needed.

---

# 21. Needed generic event hooks, derived from the decomp

The original Quest Log shows a good starting set of events.

For the eventual FireRedRecomp mod API, the journal would benefit from generic hooks such as:

```text
onScriptStart(map, script)
onScriptEnd(map, script)

onFlagChanged(flag, value)
onVarChanged(var, oldValue, newValue)

onMapEntered(map / mapSection)
onMapDeparted(map / mapSection)

onItemObtained(item, quantity, source)
onItemRemoved(item, quantity)

onPokemonCaught(species, map)
onWildPokemonDefeated(species, map)
onTrainerDefeated(trainerId, map)
onGymLeaderDefeated(trainerId)

onFieldMoveUsed(move, species, map)

onPokemonEvolved(fromSpecies, toSpecies)
onTradeCompleted(...)
```

Not every quest should listen to raw hooks directly. A generic quest service should normalize these into events.

The existing FireRed Quest Log validates that most of these event boundaries already correspond to real gameplay seams.

---

# 22. Existing content can often be journalized without modifying its script

Three implementation classes:

## CLASS A — pure observation

All meaningful state already exists.

The quest journal only reads FireRed state.

Example completion checks:

- story flag set;
- item obtained;
- trainer defeated;
- map reached.

No original event script change needed.

## CLASS B — discovery marker only

The existing script has all meaningful progression state but no durable "player learned about this problem" bit.

The mod records only:

`quest discovered = true`

when the relevant script/dialogue begins.

Everything afterward is derived from vanilla flags.

Bill likely fits here.

## CLASS C — genuinely new quest logic

A new quest requires state FireRed never had.

Use mod-owned quest state plus ordinary FireRed-style script/event mechanics.

Do not force new quest state into arbitrary unused vanilla flag numbers merely to imitate the ROM.

---

# 23. Quest-state priority order

When deciding where a quest fact comes from, use this order:

1. **Existing durable FireRed flag/var/trainer flag**
2. **Inventory / Pokémon / world state**
3. **Existing normalized game event**
4. **Mod-only discovery/hint/counter state**
5. **New quest-specific state**, only when necessary

This minimizes duplicate truth.

---

# 24. What to inspect next in the decomp

As the Kanto quest audit proceeds, each candidate should include:

- map/script source;
- participating NPC local IDs;
- durable flags;
- vars;
- trainer flags;
- items;
- object-hide flags;
- map scene variables;
- rewards;
- changes to dialogue/world state;
- whether discovery is already durable;
- whether completion can be inferred;
- any temporary flags that must **not** be used for permanent journal state.

Next high-value candidates:

1. Safari Warden + Surf/Gold Teeth;
2. Copycat / Poké Doll;
3. Mr. Fuji / Pokémon Tower;
4. Fighting Dojo;
5. fossil restoration;
6. Power Plant / Zapdos;
7. Silph / Saffron aftermath;
8. Sevii Lostelle;
9. Network Machine;
10. in-game trades / Pokédex aide milestones.

The purpose is not merely to catalog them.

For every candidate ask:

> **What does FireRed already persist, and what is the smallest additional quest-layer state needed to make it understandable to the player?**


---

# 25. Quest navigation / on-screen guidance

The FireRed decomp shows that quest-direction assistance is technically very feasible, but there are several levels of ambition.

## Existing engine pieces

Pinned decomp:
`pret/pokefirered@037335f4c725d7c9aecdac87066f2002b4bd7e14`

Useful existing systems include:

- `FLDEFF_EXCLAMATION_MARK_ICON` used by trainer sight, proving the overworld can attach temporary indicator sprites to map objects;
- an existing overworld arrow graphic, `gFieldEffectObjectPic_Arrow`;
- the Itemfinder's own arrow/star sprite implementation;
- `ObjectEvent` world coordinates and sprite/camera tracking;
- `MapConnection` data for connected outdoor maps;
- `WarpEvent` destination data for doors, caves, stairs, etc.;
- Region Map/map-section support;
- map-grid collision queries such as `MapGridGetCollisionAt`.

These pieces mean the mod would not need to invent basic world-coordinate or indicator rendering machinery from scratch.

## Guidance tier A — objective marker on a visible target

If the target NPC/object is currently loaded on the same map:

```text
        ↓
     [ NPC ]
```

Show a small quest marker/arrow over the relevant NPC, door, object, or interaction point.

Complexity: **LOW**

This is close to existing trainer exclamation-mark field effects.

Use selectively. Do not put markers over every quest-capable NPC before discovery.

Preferred use:

- active tracked quest;
- player is already on the correct map;
- target is currently visible / loaded.

## Guidance tier B — edge-of-screen compass arrow

If the objective is on the current map but offscreen, render an arrow near the edge of the viewport pointing toward the target coordinate.

```text
┌──────────────────────┐
│                  →   │
│                      │
│       PLAYER         │
└──────────────────────┘
```

The engine already knows:

- player coordinates;
- object/world coordinates;
- camera position;
- sprite screen positions.

Complexity: **LOW–MODERATE**

This is probably the best default overworld assistance.

It guides without drawing a literal route across the ground.

## Guidance tier C — breadcrumb to the correct exit/warp

If the objective is on another map:

```text
CURRENT MAP
   ↓
best exit / door / cave entrance
   ↓
next map
   ↓
...
   ↓
QUEST TARGET
```

Use FireRed's:

- map connections;
- warp events;
- destination map IDs;

to construct a **map-level navigation graph**.

Then choose the next map transition on the route to the objective.

The on-screen arrow points toward that transition, not directly through walls toward a faraway coordinate.

Complexity: **MODERATE**

This is the strongest candidate for a real quest-navigation system.

Example:

```text
Tracked quest: Help Bill
Player: Cerulean City
Target: Sea Cottage

navigation graph determines:
Cerulean
→ Route 24
→ Route 25
→ Sea Cottage

current arrow:
points toward Route 24 exit
```

When the player changes maps, the next waypoint is recalculated.

## Guidance tier D — Region Map quest marker

The Town/Region Map can show:

- tracked quest location;
- broad destination area;
- possibly undiscovered/hinted quest location in postgame.

Complexity: **LOW–MODERATE**

This pairs naturally with the journal.

Preferred early-game behavior:

> mark the town/route, not an exact tile.

## Guidance tier E — exact tile-by-tile GPS path

This would calculate a path through the current map using collision data and then draw:

```text
PLAYER
  ↓
······→
      ↓
      ↓
   TARGET
```

Technically possible because FireRed exposes tile collision/map-grid information.

However it introduces much more complexity:

- collision-aware pathfinding;
- NPC/dynamic object obstruction;
- ledges;
- one-way tiles;
- Surf;
- Cut;
- Strength;
- Rock Smash;
- locked doors;
- story-gated warps;
- moving objects;
- map changes;
- path rendering;
- continual route recalculation.

Complexity: **HIGH**

It also risks turning Kanto exploration into following a GPS line.

Current recommendation:

> **Do not start with exact ground-path navigation.**

---

# 26. Preferred quest-navigation design

Use a layered system:

```text
QUEST JOURNAL
    ↓
player chooses TRACK
    ↓
REGION MAP
shows broad destination
    ↓
OVERWORLD
arrow points toward next useful transition
    ↓
ON TARGET MAP
edge arrow points toward objective
    ↓
TARGET VISIBLE
small marker over NPC/object
```

This offers modern clarity while preserving exploration.

## Player control

Navigation should be opt-in per quest.

Example journal actions:

```text
TRACK QUEST
STOP TRACKING
SHOW ON MAP
HINT
```

Do not automatically plaster arrows over the screen for every active quest.

## Discovery rule

Guidance cannot reveal information the player has not learned.

A quest stage stores a **known destination precision**:

```text
NONE
REGION
TOWN / ROUTE
MAP
EXACT TARGET
```

Examples:

- "Someone in Fuchsia may own these Gold Teeth." → Fuchsia marker only.
- "Return the teeth to the Safari Warden." → Warden's House / exact NPC guidance allowed.
- "Bill lives somewhere north of Cerulean." → Route 24/25 broad direction, not exact Sea Cottage marker until appropriate.

This preserves mystery and prevents the navigation system from spoiling quests.

## Route graph considerations

The map-level route graph should account for progression requirements.

An edge may require:

- badge/story flag;
- Surf;
- Cut;
- Strength;
- key item;
- unlocked door/warp.

Therefore quest navigation should choose only transitions currently usable by the player.

If no known/currently reachable route exists:

```text
No route currently available.
Check the journal for what you know.
```

Do not point through locked progression.

---

# 27. Recommended prototype for navigation

Prototype only three layers first:

1. Region Map marker for tracked quest.
2. Edge-of-screen arrow toward a known same-map objective or next map transition.
3. Small target marker when the objective NPC/object becomes visible.

Do **not** implement ground-path lines initially.

Test:

- does the arrow reduce getting lost?
- does it spoil exploration?
- do players leave it enabled constantly?
- does map-level routing choose sensible exits?
- does it handle caves/buildings cleanly?
- does it respect locked/HM-gated routes?
- is the UI visually subtle enough to still feel like FireRed?

Current design preference:

> **Breadcrumb navigation, not GPS navigation.**
