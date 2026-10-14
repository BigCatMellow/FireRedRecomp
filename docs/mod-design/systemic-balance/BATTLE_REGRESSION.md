# Battle Regression

Battles are **validation**, not the primary balance target.

Do not decide that a Pokémon or move is balanced because one Gym Leader takes a certain number of turns.

## Why battle regression exists

The systemic models intentionally simplify:

- AI decision quality;
- switching;
- status timing;
- setup opportunity cost;
- recovery;
- resource allocation across a full team;
- sequence effects;
- real opposing movesets.

Representative fights are therefore needed after the systemic package is coherent.

## Pinned vanilla baseline

The research added a reproducible trainer extractor against the pinned FireRed decomp rather than relying on remembered rosters.

The extracted baseline contained:

- 742 trainer records;
- 639 party arrays;
- 1,650 trainer party members.

Custom moves are preserved when specified. Default-move parties are not guessed.

## Representative validation matrix

The first regression suite should include fights that stress different mechanics.

Suggested sentinels:

- **Brock / early routes** — early damage floor and Rock progression sanity.
- **Misty** — early special pressure/recovery.
- **Erika** — Grass sustain, Poison/Bug identity, status/control.
- **Koga** — physical Poison continuity and attrition.
- **Sabrina** — Psychic pressure; Ghost/Dark/TM30 policy.
- **Blaine** — Fire identity and Water/Rock coverage.
- **Giovanni** — Ground/physical pressure and mixed team responses.
- **Lorelei** — Ice/Water category shifts, Jynx-related assumptions.
- **Bruno** — physical Fighting and Hitmonchan coverage.
- **Agatha** — Ghost/Poison category policy and status play.
- **Lance** — Gyarados, Ice access, fast coverage.
- **Champion** — full-team composition and scarce-resource allocation.

Include ordinary route trainers as well so the mod is not secretly tuned only around bosses.

## What to measure

Useful deterministic telemetry:

- expected damage ranges;
- 2HKO/3HKO threshold changes;
- Speed order;
- STAB vs coverage move chosen as best option;
- new super-effective answers;
- survival threshold changes;
- setup-after-control opportunities;
- recovery/sustain loops;
- resource allocation assumptions;
- whether one species can now collapse several intended team roles.

## What not to use as the pass/fail rule

Avoid:

- "must win in exactly N turns";
- "boss should always use move X";
- tuning levels upward solely because the player package improved;
- assuming perfect player movesets;
- assuming every scarce TM is simultaneously available to every party member.

## Watch cases

The first battle-regression pass should explicitly include:

- Gengar
- Hitmonchan
- Gyarados
- Jynx
- Muk
- Beedrill
- Onix
- Kabutops
- Aerodactyl

and at least one team where TM19 and TM30 have to be allocated to different potential beneficiaries.

## Acceptance philosophy

A package passes battle regression when:

- intended species identities show up in real matchups;
- no single coverage change erases too many team-building decisions;
- weak families become viable for coherent reasons;
- already-strong families do not gain unbounded role compression;
- control/setup/sustain value is visible without becoming deterministic lockout;
- scarce resources remain meaningful choices.

Battle findings may send the package back to systemic analysis. They should not directly dictate arbitrary boss-specific buffs/nerfs.
