# Friction log

## 2026-11-16 — Low Kick engine contract design

- One batched read-only discovery command used candidate-local importer/core paths while its cwd was the public reference checkout; those paths and an assumed include/rom_header_gf.h do not exist there. No mutation or source uncertainty resulted. Split subsequent searches by checkout and discover actual paths before reads.
- A later batched candidate read again included reference-only linker/header paths; no-match errors were confined to discovery. Repeated cwd mix-up countermeasure: all remaining public-reference reads use absolute /home/home/FireRedRecomp-reference/pokefirered paths; independently re-read constants/header/mapping successfully via that path. No code/prototype executed.

## 2026-11-16 — independent Low Kick contract NEEDS_FIX corrections

- Independent review of e6633f0 identified ambiguous constructor notation (F1) and conflated selection/core lock semantics (F2). Corrected only those report/API/call-site/test paragraphs: preserve new(opts), explicit optional field and full call; one pure planner with mandatory selection/resolution context, projected next-turn expiry versus live direct-resolution locks/fallback. Added literal timer1/timer2/all-zero/cleared-lock witnesses. No runtime prototype or product suite. Countermeasure: bind each preflight call site to the exact phase-specific predicate and literal divergence case, rather than treating isLocked as core equivalence.
