# Friction log

## 2026-11-16 — Low Kick engine contract design

- One batched read-only discovery command used candidate-local importer/core paths while its cwd was the public reference checkout; those paths and an assumed include/rom_header_gf.h do not exist there. No mutation or source uncertainty resulted. Split subsequent searches by checkout and discover actual paths before reads.
- A later batched candidate read again included reference-only linker/header paths; no-match errors were confined to discovery. Repeated cwd mix-up countermeasure: all remaining public-reference reads use absolute /home/home/FireRedRecomp-reference/pokefirered paths; independently re-read constants/header/mapping successfully via that path. No code/prototype executed.
