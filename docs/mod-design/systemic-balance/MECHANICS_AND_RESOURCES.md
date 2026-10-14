# Mechanics and Resource Policy

## Physical/Special direction

The research no longer treats the choice as simply:

- vanilla Gen III type-based categories, or
- full modern split with no compensation.

The current preferred branch is:

> **Modern per-move categories + targeted progression repairs + explicit physical Poison exceptions.**

Status: **preferred for further integration, not frozen.**

## Why not plain modern split

A complete per-move split repairs many obvious mismatches:

- Hitmonchan elemental punches.
- Gengar Shadow Ball.
- Butterfree/Venomoth Silver Wind.
- Kingler Crabhammer.
- Omastar AncientPower.

But it also creates real regressions or new resource dependence.

Examples found in the research:

- Muk loses badly if Sludge Bomb becomes Special.
- Jynx can lose natural Ice identity.
- Electrode/Magneton can become more dependent on Thunderbolt.
- some Flying moves can move onto the wrong attacking stat for a particular species.

Therefore category modernization requires ecosystem work.

## Physical Poison exception

Current preferred exception:

- Sludge remains Physical.
- Sludge Bomb remains Physical.

Reason:

A Sludge-Bomb-only exception fixes Muk at the endpoint but still leaves Grimer's real acquisition window mismatched. Keeping the whole Sludge line Physical protects actual progression.

This is narrower than declaring all Poison attacks Physical.

## Game Corner friction

"Repeatable" does not mean "low friction."

High-cost Game Corner TMs such as Ice Beam, Thunderbolt, Flamethrower, and Shadow Ball must not be treated as free progression repairs simply because coins can theoretically be farmed.

If a category change causes a family to lose natural identity and only a 4,000+ coin TM fixes it, that is still a progression regression unless the design intentionally chooses that resource burden.

## TM30 Shadow Ball

Under modern categories, repeatable TM30 becomes premium off-type Special coverage for many families.

Typed allocation screening found that a single copy can still produce meaningful matchup gains across many compatible families even when it does not raise their neutral ceiling.

Current leading policy:

> **TM30 should be finite/single-copy in the hybrid-modern branch.**

This keeps the move valuable while making allocation a team-building decision rather than an unlimited coverage purchase.

Gengar should receive its Ghost identity naturally; TM30 should not need to serve as Gengar's progression patch.

## TM19 Giga Drain

TM19 is already one-copy and therefore inherently a team-allocation resource.

Sensitivity result:

- 60 BP produces the smallest typed contention footprint.
- 65 BP crosses essentially the same added-beneficiary threshold as 70.
- 70 BP therefore is not required to create the issue; the threshold is crossed before that.

Preferred:

> **60 BP / 10 PP.**

This is a useful example of the mod's larger philosophy: improve a type's identity through sustain/reliability when possible rather than always increasing raw damage.

## Rock Slide lesson

The neutral-damage screen initially made repeatable Rock Slide look safe.

Typed-matchup regression showed otherwise: broad compatibility created many new super-effective non-STAB answers.

Conclusion:

> **Every resource or coverage change must be tested against typed targets, not only a neutral dummy.**

That rule should be reused in future mod design.

## Scarcity is a feature

Single-copy TMs and one-use tutors can create meaningful team decisions.

Scarcity is only unhealthy when a species' basic identity depends on winning a contested one-copy resource.

Use this distinction:

- **Identity move** → should generally be natural or low-friction.
- **Premium coverage / optimization** → may reasonably be finite, expensive, or contested.
