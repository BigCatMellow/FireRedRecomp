# Effect-45 implementation — independent outcome review

Verdict: **PASS** for guarded-published implementation
`cfdbb96def3a161e2d70653f83256742054c58c2` against authority
`96b10ceebc96dfc4d40cabae43faecf27abe0ce3`. Bounded effect 45 (Jump Kick 26,
Hi Jump Kick 136) ordinary-singles crash-on-miss only. No Phase 4 completion,
normal save/reload, retail presentation or whole-turn RNG parity follows.

- Task: [P4-F3-RECOIL-IF-MISS-IMPLEMENTATION](../tasks/phase4-recoil-if-miss-implementation.md).
- Sole request: `5fb8053`, `work/local-runner/requests/phase4-recoil-if-miss-effect-20261013.patch`,
  SHA-256 `acd322a6d2cf86820d4413a12b63723d09c10d3165205f6123e44f554907a81a`.
- Guarded [run 38434551595](https://github.com/BigCatMellow/FireRedRecomp/actions/runs/38434551595),
  job `115425037342`, attempt 1, `success`, runner labels `self-hosted, linux, x64, firered-local`.
- Reviewer: independent Claude Code session; did not construct the patch.

## Scope and publication integrity

- `cfdbb96` touches exactly the ten authorized literal paths; no eleventh file.
- Applying the request patch to `5fb8053` reproduces `cfdbb96`'s tree exactly
  (empty diff outside `work/local-runner`).
- `.github/` unchanged since configuration `1d40f3c`.
- `git diff --check 96b10ce cfdbb96` clean.

## Source conformance (pret/pokefirered `c75f352`)

| Source | Implementation | Result |
| --- | --- | --- |
| `Cmd_accuracycheck` miss → `CheckWonderGuardAndLevitate()` sets `DOESNT_AFFECT_FOE`; `BattleScript_MoveMissedDoDamage` jumps to MoveEnd on it after `resultmessage` | Pure `typeCalc` noEffect query before miss; emits `noEffect`, returns; one PP spent, one RNG draw | Match |
| `resultmessage` (miss) → `STRINGID_PKMNCRASHED` → `damagecalc` → `typecalc` → `adjustnormaldamage` | `miss`, base damage (crit=false, defender Reflect), `typeCalc`, random multiplier | Match |
| `DMG_RECOIL_FROM_MISS`: `/2`, `0→1`, cap `target.maxHP/2` | `recoilIfMissDamage` | Match |
| `healthbarupdate`/`datahpupdate`/`tryfaintmon BS_ATTACKER` | Attacker HP clamped, `crash` event, `checkFaint(attacker)` | Match |
| Literal gate | `effect == 45 and moveId in {26,136}` | Match |

Abilities (Levitate/Wonder Guard), Foresight, Endure/Focus Band in
`adjustnormaldamage`, Substitute and doubles remain excluded per task.

## Assertions independently checked

- Engine oracles recomputed by hand from the Gen 3 formula: Lv20 40/40 →
  16, STAB 24, half 12 (JK); 19 → 28 → 14 (HJK); stage/Reflect/super/85% case
  → 5; odd cap 9 → 4; target current HP and attacker max not used.
- RNG: crash = 2 draws then sentinel; immune = 1 draw; hit path unchanged.
- Fatal crash: one faint, defender untouched, opponent action skipped,
  `battleEnd` vs `forcedSwitchNeeded`, pending-switch refusal, replacement
  then later legal turn. firstBattle bypass and tutorial state preserved.
- Controller consumes actual engine events: use → miss → crash text with old
  displayed HP → invisible HP entry → faint/continuation; immune path has no
  crash/HP entry; PARTY/COMPLETE/ACTION terminal states.
- Party bridge: real engine HP/PP persisted through unchanged
  `persistPartyBattler`; checksum/personality preserved; in-memory codec only.
- ROM fixture: exactly two effect-45 members, source-locked fields.

## Guarded receipts (job log, numeric only)

Focused/replay arm: engine 339/0, controller 87/0, party bridge 29/0,
inventory PASS with SHA-verified admission (`admitted_uncovered_positive=108`),
ROM fixture 3/0, replay receipt PASS. Full suites: 155 files in both no-ROM
and verified-ROM modes. Local reviewer re-run (no ROM): engine 332/0,
controller 87/0, party 29/0, full suite 155 files PASS; the 7-assertion engine
difference is the existing ROM-gated fixture section.

## Non-blocking finding (outside this task)

The public job log prints the runner's private ROM file path twice (the
`POKEPORT_ROM` step `env:` block and the verified-ROM suite's PASS line).
The repository is public, so this conflicts with the "no private paths in
public artifacts/logs" rule shared by these task contracts. Not caused by
`cfdbb96`; it is a bridge/test-harness issue. Recommend a separate bounded
fix (do not echo the path; redact in `scripts/test_all.sh`'s summary) and
deleting the affected run logs. This review deliberately does not copy it.

## Result

PASS. Orchestrator may reconcile bounded effect-45 behavior as represented,
preserving every exclusion above.
