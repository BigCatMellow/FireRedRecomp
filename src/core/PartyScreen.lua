-- Pure state machine for FireRed's real top-level Party Screen list --
-- the screen opened by the real STARTMENU_POKEMON item (src/party_menu.c's
-- `CB2_PartyMenuFromStartMenu`, line ~5428: `InitPartyMenu(PARTY_MENU_TYPE_
-- FIELD, PARTY_LAYOUT_SINGLE, PARTY_ACTION_CHOOSE_MON, FALSE, PARTY_MSG_
-- CHOOSE_MON, Task_HandleChooseMonInput, CB2_ReturnToFieldWithOpenMenu)`).
-- Same "pure state machine before its ROM-backed scene" pattern as
-- PokemonMartMenu.lua/StartMenu.lua.
--
-- SCOPE BOUNDARY (confirmed against real source, not assumed): selecting a
-- living party slot in this real context (PARTY_ACTION_CHOOSE_MON) falls
-- into `HandleChooseMonSelection`'s `default:` case (src/party_menu.c line
-- ~1206), which calls `Task_TryCreateSelectionWindow` -- the real SUMMARY/
-- SWITCH/ITEM/CANCEL per-mon submenu. That submenu is real UI/asset/task
-- machinery (a whole second window + its own cursor state, real per-action
-- effects like opening the Summary screen or the Bag) clearly bigger scope
-- than this bounded slice, so per the brief this module stops at "list a
-- filled party + CANCEL, move the cursor, and report which slot (or
-- CANCEL) was confirmed" -- it does NOT implement the SUMMARY/SWITCH/ITEM
-- submenu. A caller wires `:selectedSlot()` to whatever it wants to do next
-- (e.g. eventually open that submenu, or just stop here for now).
--
-- List shape (real `UpdatePartySelectionSingleLayout`, src/party_menu.c
-- line ~1358, used because `gPartyMenu.layout == PARTY_LAYOUT_SINGLE` --
-- confirmed via `UpdateCurrentPartySelection`, line ~1342 -- for exactly
-- this STARTMENU_POKEMON entry point, NOT the 2x2-ish grid other
-- PARTY_LAYOUT_* variants use elsewhere in the game): a plain vertical list
-- of every filled party slot (`gPlayerPartyCount` of them, no gaps -- real
-- FireRed's party array itself has no gaps, matching PartyModel's own
-- add-to-first-empty-slot/shift-on-remove policy already), followed by one
-- CANCEL row (real `SLOT_CANCEL = PARTY_SIZE + 1`, line ~86; the fixed
-- numeric value doesn't matter here, only that it's the one row after the
-- last filled mon). A party with fewer than 6 living mons only shows that
-- many rows, never 6 fixed rows with fake-empty ones -- ported by sizing
-- the cursor to `party:size() + 1` (mons + CANCEL), not a fixed 7.
--
-- Cursor wraparound (real `UpdatePartySelectionSingleLayout`, lines
-- ~1358-1385): Up from slot 0 goes to CANCEL; Up from CANCEL goes to the
-- last mon; Down from the last mon goes to CANCEL; Down from CANCEL goes to
-- slot 0. This is exactly MenuCursor's existing wraparound semantics with
-- CANCEL as the one extra choice past the last mon (`MenuCursor.new(party:
-- size() + 1, 0)`), so this module reuses MenuCursor rather than
-- reimplementing that math. Real `PartyMenuButtonHandler` (line ~1297)
-- reads `gMain.newAndRepeatedKeys` for D-pad movement (auto-repeat, unlike
-- StartMenu's real newly-pressed-only nav) -- exactly what MenuCursor:
-- processInput already does with isPressedOrRepeated, so this module drives
-- the cursor through that one call rather than hand-rolling input reads.
-- Real LEFT/RIGHT column-jump handling (`MENU_DIR_LEFT/_RIGHT`, used for
-- the multi-select "jump to last selected slot" feature of OTHER
-- PARTY_MENU_TYPE_* contexts) is not ported -- this bounded field-view
-- context never uses it (`sPartyMenuInternal->chooseMultiple` is FALSE
-- here, real line ~442).
--
-- A_BUTTON on CANCEL: real `PartyMenuButtonHandler` (line ~1337) maps
-- `A_BUTTON` on `SLOT_CANCEL` to the same `B_BUTTON` result as an actual B
-- press -- i.e. confirming CANCEL and pressing B do the exact same thing.
-- Ported as both landing in the CLOSED state below.
-- B_BUTTON anywhere: real `HandleChooseMonCancel`'s default case (line
-- ~1230, since `gPartyMenu.menuType != PARTY_MENU_TYPE_CHOOSE_MULTIPLE_
-- MONS` here) sets the slot to SLOT_CANCEL and closes the party menu via
-- `Task_ClosePartyMenu` back to `CB2_ReturnToFieldWithOpenMenu` -- the real
-- field callback that redraws the overworld with the Start menu still
-- open, i.e. B here returns to the Start menu, not straight to the
-- overworld. Ported as the CLOSED state with no confirmed slot.
--
-- Per-mon display data: real `DisplayPartyPokemonNickname` shows each
-- mon's `MON_DATA_NICKNAME`, not a separately-looked-up species name. Real
-- `CreateBoxMon` (src/pokemon.c line ~1808: `GetSpeciesName(speciesName,
-- species); SetBoxMonData(boxMon, MON_DATA_NICKNAME, speciesName);`)
-- confirms every mon's nickname field is pre-filled with its species name
-- at creation and only overwritten by an explicit real nickname later --
-- so the already-decoded `nickname` bytes on a party record (via
-- BattlePartyBridge.decodeRecord -> BoxPokemonCodec.decode) are exactly
-- the real display text, with no separate gSpeciesNames/SpeciesInfo lookup
-- needed here (this project has no decoded species-name table wired up
-- anywhere yet -- see import/SpeciesInfo.lua's own header, which only
-- covers gSpeciesInfo's numeric stat struct, not gSpeciesNames text).
-- Level/current-HP/max-HP/status come straight off the party record's own
-- cached fields (record.level/record.hp/record.maxHP/record.status),
-- exactly how BattlePartyBridge.battlerFromParty already reads them
-- (src/core/BattlePartyBridge.lua's assertCachedStat calls) -- no new
-- decode logic duplicated here.
--
-- NOT ported: gender icon and status-condition icon glyphs. This project
-- has no ported STATUS1_* bit-constant table anywhere yet (grepped; only a
-- passing comment references STATUS1_SLEEP), and gender is not decoded by
-- BattlePartyBridge for a save-record battler (BattlePartyBridge.
-- battlerFromParty never sets battler.gender, only battlerFromGenerated
-- does). Building a first STATUS1 bit decoder or a save-record gender
-- reader is its own scoped unit, not menu-navigation logic -- this module
-- exposes the raw `record.status` (0 == no status, matching real
-- STATUS1_NONE) and leaves icon/gender decoding to a future module rather
-- than guessing bit layouts here.

local InputState = require("src.core.InputState")
local MenuCursor = require("src.core.MenuCursor")
local BattlePartyBridge = require("src.core.BattlePartyBridge")
local Charmap = require("import.Charmap")

local PartyScreen = {}
PartyScreen.__index = PartyScreen

PartyScreen.BROWSING = "browsing"
PartyScreen.CONFIRMED = "confirmed"
PartyScreen.CLOSED = "closed"

-- party: a PartyModel instance (src/core/PartyModel.lua), read-only here.
function PartyScreen.new(party)
  assert(party and party.size and party.get, "PartyScreen needs a real PartyModel-shaped party")
  local size = party:size()
  return setmetatable({
    party = party,
    -- size()+1 rows: every filled slot plus one CANCEL row (see header).
    cursor = MenuCursor.new(size + 1, 0),
    state = PartyScreen.BROWSING,
    confirmedSlot = nil, -- 1-based party slot, or nil when CANCEL was confirmed
  }, PartyScreen)
end

function PartyScreen:isDone()
  return self.state ~= PartyScreen.BROWSING
end

-- 0-based row index currently under the cursor (0..party:size()-1 are
-- mons, party:size() is the CANCEL row).
function PartyScreen:cursorRow()
  return self.cursor.cursorPos
end

function PartyScreen:isCancelRow(row)
  return row == self.party:size()
end

-- input: an InputState instance already ticked this frame.
function PartyScreen:processInput(input)
  if self.state ~= PartyScreen.BROWSING then return end

  local result = self.cursor:processInput(input)
  if result == "cancel" then
    -- Real HandleChooseMonCancel's default case: B closes back to the
    -- Start menu with no mon chosen (see header).
    self.state = PartyScreen.CLOSED
  elseif result == "confirm" then
    local row = self.cursor.cursorPos
    if self:isCancelRow(row) then
      -- Real PartyMenuButtonHandler: A on SLOT_CANCEL == a B press.
      self.state = PartyScreen.CLOSED
    else
      self.confirmedSlot = row + 1
      self.state = PartyScreen.CONFIRMED
    end
  end
end

-- Returns display data for 1-based party `slot`: { slot, nickname,
-- species, level, hp, maxHp, status, isEgg }. `nickname` is the real
-- charmap-decoded display text (see header -- already the species name by
-- default). Asserts the record decodes; a party built through this
-- project's own WildPokemonFactory/StarterPokemonFactory/CaptureRewards
-- always produces a valid record.
function PartyScreen:rowData(slot)
  local record = self.party:get(slot)
  assert(record, ("PartyScreen has no record at slot %d"):format(slot))
  local decoded, reason = BattlePartyBridge.decodeRecord(record)
  assert(decoded, reason)
  local isEgg = decoded.isEgg or decoded.isBadEgg or decoded.substructs[3].isEgg
  return {
    slot = slot,
    nickname = Charmap.decode(decoded.nickname, true),
    species = decoded.substructs[0].species,
    level = record.level,
    hp = record.hp,
    maxHp = record.maxHP,
    status = record.status or 0,
    isEgg = isEgg,
  }
end

-- Iterates every row a caller should render, in real display order: filled
-- party slots first (1-based slot numbers), then the CANCEL row last.
-- `for row, isCancel, data in partyScreen:iterateRows() do` -- `data` is
-- nil for the CANCEL row (`isCancel == true`), `row` is the 0-based cursor
-- row matching :cursorRow()'s numbering.
function PartyScreen:iterateRows()
  local size = self.party:size()
  local row = -1
  return function()
    row = row + 1
    if row < size then
      return row, false, self:rowData(row + 1)
    elseif row == size then
      return row, true, nil
    end
  end
end

return PartyScreen
