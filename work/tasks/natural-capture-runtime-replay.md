# Task: natural-capture runtime replay

## Contract

- Owner: project maintainer
- Source of truth: `work/tasks/phase3-exit-proof.md`, current runtime replay
  cases, real map connections/events, and the Viridian Mart clerk script
- Output boundary: deterministic runtime-replay support and tests needed to
  prove one current-runtime purchase-and-capture path; no synthetic inventory,
  direct map/session placement, or forced battle outcome

## Route and acceptance evidence

1. Follow the existing normal-input fresh-session replay through Route 1.
2. Traverse the real north connection to Viridian City and its real Mart warp.
3. From Mart entry `(4,7)`, reach player tile `(4,3)`, face left across the
   real `MB_COUNTER` tile `(3,3)`, and trigger clerk local id `1` at `(2,3)`.
4. Purchase Poké Balls through the live `pokemart` script and UI; verify money
   and session-bag persistence without injecting an item.
5. Return through real warps/connections to Route 1, trigger a real grass
   encounter, select BAG through the visible battle controller, and capture
   without forced catch state/outcome.
6. Assert caught party/Dex/bag changes survive the normal save/restart gate.

## Known boundary

The current runtime does not execute generic map on-load/on-frame scripts.
Retail FireRed's first Viridian Mart visit includes Parcel story handling that
is therefore not yet parity-complete. A successful replay here must be called
**current-runtime purchase/capture evidence**, not proof of canonical retail
story progression. The task must stop if that distinction cannot remain clear.

## Verification

- `POKEPORT_ROM=/path/to/pokefirered.gba bash scripts/test_all.sh`
- A dedicated headless LÖVE replay, run twice from clean temporary XDG
  sandboxes, with a canonical marker for Mart purchase and capture persistence.
