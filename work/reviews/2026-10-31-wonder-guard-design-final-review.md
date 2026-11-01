# Wonder Guard source/design final delta review — 2026-10-31

**PASS** for corrected source/design only.

Exact reviewed artifact: `/tmp/firered-wonder-guard-design-20261031.md`,
SHA256 `f9718f67ad8a96d8095c683e00c7b286f2f1d741752d664f8949f2550835d1c9`.
Hash independently verified. This final check is limited to the sole
outstanding correction from
`/tmp/firered-wonder-guard-design-rereview-20261031.md`; previously resolved
findings retain their prior review evidence.

The Psywave oracle now correctly states3 draws on immediate acceptance,
or3+r with r rejected value samples. It preserves the existing rejection
helper and unblocked RNG, and requires the explicit successful-accuracy,
samples11,15,10, tail sequence yielding5 total draws. This matches the
previously verified pinned C rejection loop at
`src/battle_script_commands.c:7557-7565` and native V4a helper:704-707.
The last correction is resolved; no further correction identified.

The design supports compiling one coherent bounded modeled-singles task
on the previously agreed engine/optional opt-in formulas/narrow controller/
focused tests/task surface. Preserve the three distinct scans and reason
precedence, route-specific state/RNG oracles, newly-WG-blocked-only source
tail policy, unblocked RNG limitations, and history/AI/counter exclusions.
Revalidate the actual implementation base in the eventual task.

This is not implementation acceptance or Worker dispatch authority. Parent's
permission for the narrow controller proposal does not itself authorize
code changes. No broad tests/research repeated; no implementation, ROM,
runner, publication, merge, shared coordination edit, full-runtime/replay
parity, Brock AI parity, or phase acceptance is certified or performed.
