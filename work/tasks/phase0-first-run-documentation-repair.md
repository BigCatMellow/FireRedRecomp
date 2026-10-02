# Task: document the supported first-run verification profile

- Task ID: `P0-04-DOCS`
- Status: `READY_FOR_WORKER`
- Type: `DOCUMENTATION / REPRODUCIBILITY REPAIR`
- Prerequisite: [P0-04 discovery PASS](../reviews/2026-10-02-first-run-reproducibility-discovery-review.md), exact `8c92f67`.

## Goal

Add the smallest accurate first-run documentation needed to make the supported
already-provisioned Linux verification profile explicit. This is not an
installer, dependency bootstrap, universal platform support promise, desktop
proof, or a replacement for a clean-target P0-04 retry.

## MAY CHANGE

1. `README.md`.
2. `docs/FIRST_RUN.md`.
3. This task's completion/handoff section.

## MUST NOT CHANGE

Runtime, tests, workflows, package/dependency manifests, scripts, toolchains,
user settings, desktop session, ROM policy, canonical status, or any other
documentation. Do not claim automatic installation, support an unobserved OS,
accept/copy a ROM, reveal private paths, or claim the desktop starts correctly.

## Acceptance

1. State the conditional observed profile: Linux with already provisioned Git,
Bash, Lua 5.1, LÖVE 11.5 and `sha1sum`; explain that missing tools are a
prerequisite failure, not an auto-install action.
2. Provide no-ROM repository check/test commands and documented missing/invalid
ROM refusal expectations without using real ROM data.
3. Explain the legally obtained supported-ROM boundary, SHA verification and
private-path handling without embedding a path or content.
4. State that desktop first-run/refusal remains a separate clean-target
observation, and existing screenshot/replay hooks do not prove it without ROM.
5. Pass the repository documentation checker and link checks. Independent
review must accept the exact revision before a fresh P0-04 verification.

## Stop

Stop if accuracy requires platform/package-manager selection, host mutation,
valid ROM access, or a claim not established by discovery. Record it; do not
widen scope.
