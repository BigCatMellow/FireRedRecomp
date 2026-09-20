# Task: recover the save-version compatibility contract

- Task ID: `P0-02-DISCOVERY`
- Status: `READY_FOR_WORKER`
- Type: `RESEARCH / READ-ONLY COMPATIBILITY DISCOVERY`
- Parent capability gate: Phase 0 save-version contract in [`../roadmaps/CAPABILITY_CHECKLIST.md`](../roadmaps/CAPABILITY_CHECKLIST.md), MAPSL `P0-02`.
- Assigned role: `RESEARCHER`.
- Independent reviewer: separate `REVIEWER` helper.
- Prerequisites: current codec/history and existing no-ROM fixtures; independent of the offline Phase 4 ROM runner.
- Risk: `LOW` — evidence/report only; incorrect compatibility claims could endanger later saves.

## Goal

Recover the actual supported-version, migration/refusal, and corruption policy
from current code and history, identify stale charter statements or missing
fixtures, and propose one smallest bounded successor. No save behavior changes
are authorized by this discovery.

## Source of truth

- `src/core/SaveFileCodec.lua`, `SaveBlockLayout.lua`, `PcBoxes.lua`, save/load integration in `main.lua`, and their relevant tests.
- Exact history around `103c5e1d5b7ad11d5408a2112d81437117a991c9` (PC sectors and version 2), its predecessor, and the earlier version-wrapper introduction.
- `PARITY_CONTRACT.md` save-version requirements; Phase 0/3 save entries in the checklist. Their claim that no version exists conflicts with current `VERSION = 2`; distinguish intended policy from actual behavior explicitly.
- Pinned public FireRed source only where retail sector/checksum behavior affects the findings. The project wrapper itself is a project policy, not a retail format.
- Unknowns: exact persisted legacy shapes and evidence for refusal/corruption boundaries; resolve from history/tests without guessing.

## MAY CHANGE

1. `work/tasks/phase0-save-version-contract-discovery.md`
2. `work/reports/phase0-save-version-contract.md`

Temporary synthetic, non-ROM verification artifacts may be created outside git.
Orchestrator owns coordination; Reviewer owns the independent verdict.

## MUST NOT CHANGE

Codec/runtime/save data, version numbers, migration support, production tests,
charter/checklist status, user save files, ROM policy, or any inventory/bridge
path. Never convert, overwrite, or inspect unrelated real user saves. Do not
promise migration where missing data makes it uncertain. No ROM/save dumps,
derived assets, or raw copyrighted records in git.

## Acceptance criteria

1. Pin current and relevant historical revisions and enumerate each persisted project schema: wrapper, modelled sectors, byte-length expectations, current encoder output, and decoder acceptance/refusal.
2. State the current version matrix separately from a proposed explicit future compatibility contract. Preserve the current version-1 refusal unless a later task explicitly authorizes another policy; discovery alone cannot change it.
3. Map magic/version/length/counter/sector signature/checksum/corruption handling and slot fallback to concrete code and existing tests. Record missing or conflicting evidence, including whether save-file writes and in-memory decode are separate safety boundaries.
4. Run focused available no-ROM codec/roundtrip checks; use synthetic read-only experiments only where a precise gap needs investigation. Do not rerun unrelated suites for documentation alone.
5. Identify stale source-of-truth prose and the smallest next task: documentation/explicit contract and targeted fixtures if sufficient, or a separate bounded implementation/design if required. Explicitly list any genuinely new human compatibility decision rather than deciding silently.
6. Independently review the exact report against evidence; no Phase 0 completion follows from this discovery.

## Required evidence

- Existing 149-file no-ROM baseline at accepted Pain Split/unchanged runtime revision.
- `lua5.1 tests/save_file_codec_test.lua` and `lua5.1 tests/save_load_roundtrip_test.lua`, with no ROM environment.
- Exact historical source and relevant test locations; synthetic experiment commands/results where needed.
- Independent report review before accepting the compatibility findings or dispatching the proposed successor.

## Stop / escalate when

Historical schemas cannot be recovered, compatibility would require invented
lost data, a finding needs real user save mutation, or proposed work changes
acceptance/policy. Record the open question and continue independent evidence
collection. User is unavailable; do not block unrelated authorized work.

## Completion and handoff

Researcher writes a concise compatibility/evidence matrix and smallest successor,
commits only allowed text artifacts, and returns exact evidence. Reviewer decides
PASS / NEEDS_FIX / BLOCK. Orchestrator reconciles and dispatches only the accepted
successor. The Phase 4 inventory/private-runner blocker remains separate.
