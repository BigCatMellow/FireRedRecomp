-- Real post-catch persistence routing: GiveMonToPlayer/SendMonToPC
-- (src/pokemon.c) and HandleSetPokedexFlag (src/pokemon.c), plus the
-- real ball-consumption call site (RemoveBagItem, src/item_menu.c).
--
-- WildPokemonFactory.lua already builds the save-compatible party/PC
-- record shapes (capture()/toPcRecord(), including the real PP-restore-
-- only-on-the-PC-path quirk); this module is the missing decision layer
-- on top of it -- which container a freshly caught mon actually lands in
-- -- using this project's existing PartyModel/PcBoxes/DexTracker/Bag
-- containers. Nothing here rolls RNG or decides catch success; that's
-- CaptureRules.lua's job, upstream of this module.
--
-- Real GiveMonToPlayer (src/pokemon.c): scans the party for the first
-- slot with no species, capped at PARTY_SIZE; only overflow goes to PC.
-- Real SendMonToPC (same file): starts at VAR_PC_BOX_TO_SEND_MON's box
-- and wraps through all TOTAL_BOXES_COUNT boxes looking for the first
-- free slot in each, restoring PP (BoxMonRestorePP) before boxing;
-- returns MON_CANT_GIVE only if every box on every wrap is full (this
-- project surfaces that as nil, "pc_full" -- it never invents space).

local WildPokemonFactory = require("src.core.WildPokemonFactory")

local CaptureRewards = {}

-- party: PartyModel instance. pcBoxes: PcBoxes instance. currentBox:
-- 1-indexed box the storage system is "currently viewing" (this
-- project's containers are 1-indexed throughout; real VAR_PC_BOX_TO_
-- SEND_MON is 0-indexed, a caller bridging real save data must convert).
-- caught: WildPokemonFactory.capture()'s returned persistent record.
-- battleMoves: gBattleMoves-shaped table, only consulted on the PC path.
--
-- Returns "party", slot   or   "pc", box, slot   or   nil, "pc_full".
function CaptureRewards.giveMonToPlayer(party, pcBoxes, currentBox, caught, battleMoves)
  assert(party and pcBoxes and caught, "party, pcBoxes, and caught are required")
  if not party:isFull() then
    local slot = assert(party:add(caught))
    return "party", slot
  end

  local record = WildPokemonFactory.toPcRecord(caught, assert(battleMoves,
    "battleMoves is required to restore PP on the PC path"))
  local total = pcBoxes.TOTAL_BOXES_COUNT
  local startBox = ((currentBox - 1) % total) + 1
  for i = 0, total - 1 do
    local box = ((startBox - 1 + i) % total) + 1
    local slot = pcBoxes:add(box, record)
    if slot then
      return "pc", box, slot
    end
  end
  return nil, "pc_full"
end

-- Real HandleSetPokedexFlag: FLAG_SET_SEEN and FLAG_SET_CAUGHT are
-- independent calls in source (a capture doesn't imply "seen" was set
-- through this exact call), but a catch always follows the mon being
-- seen in the same battle, so this convenience sets both -- matching
-- DexTracker.lua's own header note that the two bits are used together
-- in practice even though they're independently settable.
function CaptureRewards.markCaught(dexTracker, nationalDexNo)
  dexTracker:setSeen(nationalDexNo)
  dexTracker:setOwned(nationalDexNo)
end

-- Real ball consumption happens in the bag/item-menu layer
-- (src/item_menu.c's RemoveBagItem call sites), not inside the battle
-- engine -- this project has no bag UI yet, so nothing currently calls
-- this, but it exists ready for that wiring rather than being invented
-- ad hoc later.
function CaptureRewards.consumeBall(bag, ballItemId)
  return bag:removeItem(ballItemId, 1)
end

return CaptureRewards
