-- Pure state machine for FireRed's real overworld START menu (opened with
-- the Start button; pokefirered src/start_menu.c). Presentation-free, same
-- "pure state machine before its ROM-backed scene" pattern as
-- PokemonMartMenu.lua/NamingScreenState.lua.
--
-- Real item set/order (src/start_menu.c's `enum StartMenuOption`, line ~41,
-- and `SetUpStartMenu_NormalField`, line ~213):
--   STARTMENU_POKEDEX -> STARTMENU_POKEMON -> STARTMENU_BAG ->
--   STARTMENU_PLAYER -> STARTMENU_SAVE -> STARTMENU_OPTION -> STARTMENU_EXIT
-- POKéDEX is only appended when `FlagGet(FLAG_SYS_POKEDEX_GET) == TRUE`;
-- POKéMON is only appended when `FlagGet(FLAG_SYS_POKEMON_GET) == TRUE`
-- (both real per-item gates in SetUpStartMenu_NormalField, not just
-- POKéDEX -- a fresh save with no starter yet has neither item). This
-- module models that generically as `opts.hasPokedex`/`opts.hasPokemon`
-- booleans the caller resolves from real save flags (this project's
-- EarlyStory.lua already tracks FLAG_SYS_POKEMON_GET, see
-- EarlyStory.FLAG_SYS_POKEMON_GET) -- StartMenu.lua itself has no session/
-- flag dependency, matching PokemonMartMenu's pure-input-driven shape.
--
-- CORRECTION TO BRIEF: the requested item list "POKéMON/BAG/[player name]/
-- SAVE/OPTIONS/EXIT" omits POKéDEX, and only gated POKéDEX's visibility --
-- real source gates POKéMON's visibility too (FLAG_SYS_POKEMON_GET). This
-- module ports the exact real order/gating from `enum StartMenuOption` +
-- `SetUpStartMenu_NormalField` above.
--
-- SCOPE: this module only ports the real "normal field" item set. Real
-- src/start_menu.c also has SetUpStartMenu_Link/_UnionRoom/_SafariZone
-- variants (different item sets for link play, the Union Room, and the
-- Safari Zone's RETIRE option) -- out of scope, as this project has none of
-- those contexts yet.
--
-- Cursor navigation: real `StartCB_HandleInput` (src/start_menu.c, line
-- ~402) reads `JOY_NEW(DPAD_UP)`/`JOY_NEW(DPAD_DOWN)` -- newly-pressed only,
-- NOT `newAndRepeatedKeys` -- and moves the cursor with the real
-- `Menu_MoveCursor` (src/menu.c, the same wraparound primitive
-- MenuCursor.lua already ports as :moveCursor). That's a deliberate
-- difference from PokemonMartMenu/PartyScreen, which both use held-repeat
-- D-pad navigation for their (longer) lists -- the Start menu's own real
-- code simply doesn't repeat. This module calls MenuCursor:moveCursor
-- directly off isNewlyPressed rather than using MenuCursor:processInput
-- (which would incorrectly add repeat).
--
-- A_BUTTON: real `StartCB_HandleInput` calls `StartMenuPokedexSanityCheck`
-- (line ~459) before honoring A on the currently selected item: if the
-- selected item is POKéDEX and `GetNationalPokedexCount(0) == 0` (i.e. the
-- player has the Pokédex flag but has seen nothing in it -- a corner case,
-- not the norm), A is entirely ignored (no callback fires, cursor stays
-- put). Modeled here as `opts.nationalDexCount` (default treated as
-- non-zero / unblocked when omitted, since most callers won't hit this
-- corner case and the brief's own hasPokedex flag already covers the
-- common "no Pokédex yet" gate).
--
-- B_BUTTON or START_BUTTON: real `JOY_NEW(B_BUTTON | START_BUTTON)` closes
-- the menu back to the overworld with no item chosen (`StartCB_HandleInput`
-- line ~427, `CloseStartMenu()`). Modeled as the CLOSED state with no
-- selected item, same as B.
--
-- Only the top-level browsing state is ported. What happens after a real
-- item fires (opening the Pokédex screen, Bag, Party Screen, Trainer Card,
-- the real save confirmation dialog state machine, the Options screen) is
-- each of those systems' own scope -- this module only exposes which real
-- STARTMENU_* item id was confirmed, via `selectedItemId`, matching how
-- PokemonMartMenu's caller polls `.state`/`:isDone()` each frame rather
-- than this module owning a callback.

local InputState = require("src.core.InputState")
local MenuCursor = require("src.core.MenuCursor")

local StartMenu = {}
StartMenu.__index = StartMenu

-- Real STARTMENU_* ids (src/start_menu.c enum StartMenuOption). Only the
-- normal-field-relevant ones are exposed; STARTMENU_RETIRE/_PLAYER2 (Safari
-- Zone/link-specific) are out of this module's scope (see header).
StartMenu.POKEDEX = "pokedex"
StartMenu.POKEMON = "pokemon"
StartMenu.BAG = "bag"
StartMenu.PLAYER = "player"
StartMenu.SAVE = "save"
StartMenu.OPTION = "option"
StartMenu.EXIT = "exit"

StartMenu.OPEN = "open"
StartMenu.SELECTED = "selected"
StartMenu.CLOSED = "closed"

-- opts.hasPokedex: real FLAG_SYS_POKEDEX_GET. opts.hasPokemon: real
-- FLAG_SYS_POKEMON_GET. opts.nationalDexCount: real GetNationalPokedexCount
-- (0), only meaningful when hasPokedex is true; omit/nil is treated as
-- "not the zero corner case" (see header).
function StartMenu.new(opts)
  opts = opts or {}
  -- Real SetUpStartMenu_NormalField (src/start_menu.c line ~213): append
  -- order is POKéDEX (gated), POKéMON (gated), BAG, PLAYER, SAVE, OPTION,
  -- EXIT (real `AppendToStartMenuItems` calls, unconditional after the
  -- gated pair).
  local items = {}
  if opts.hasPokedex then items[#items + 1] = StartMenu.POKEDEX end
  if opts.hasPokemon then items[#items + 1] = StartMenu.POKEMON end
  items[#items + 1] = StartMenu.BAG
  items[#items + 1] = StartMenu.PLAYER
  items[#items + 1] = StartMenu.SAVE
  items[#items + 1] = StartMenu.OPTION
  items[#items + 1] = StartMenu.EXIT

  return setmetatable({
    items = items,
    cursor = MenuCursor.new(#items, 0),
    state = StartMenu.OPEN,
    selectedItemId = nil,
    nationalDexCount = opts.nationalDexCount,
  }, StartMenu)
end

function StartMenu:currentItemId()
  return self.items[self.cursor.cursorPos + 1]
end

function StartMenu:isDone()
  return self.state ~= StartMenu.OPEN
end

-- Real StartMenuPokedexSanityCheck (src/start_menu.c line ~459): A on
-- POKéDEX is ignored outright when GetNationalPokedexCount(0) == 0.
local function isBlockedByPokedexSanityCheck(self, itemId)
  return itemId == StartMenu.POKEDEX
    and self.nationalDexCount ~= nil and self.nationalDexCount == 0
end

-- input: an InputState instance already ticked this frame.
function StartMenu:processInput(input)
  if self.state ~= StartMenu.OPEN then return end

  -- Real StartCB_HandleInput reads JOY_NEW, not newAndRepeatedKeys (see
  -- header) -- newly-pressed only, no D-pad auto-repeat on this menu.
  if input:isNewlyPressed(InputState.DPAD_UP) then
    self.cursor:moveCursor(-1)
    return
  elseif input:isNewlyPressed(InputState.DPAD_DOWN) then
    self.cursor:moveCursor(1)
    return
  end

  if input:isNewlyPressed(InputState.B_BUTTON) or input:isNewlyPressed(InputState.START_BUTTON) then
    self.state = StartMenu.CLOSED
    return
  end

  if input:isNewlyPressed(InputState.A_BUTTON) then
    local itemId = self:currentItemId()
    if not isBlockedByPokedexSanityCheck(self, itemId) then
      self.selectedItemId = itemId
      self.state = StartMenu.SELECTED
    end
    return
  end
end

return StartMenu
