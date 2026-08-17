-- Pure StartMenu.lua state-machine coverage (no ROM needed).
-- Run: lua5.1 tests/start_menu_test.lua
package.path = package.path .. ";./?.lua"

local StartMenu = require("src.core.StartMenu")
local InputState = require("src.core.InputState")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

-- Helper: drive an InputState through "released" then "pressed" so
-- isNewlyPressed fires, mirroring how PokemonMartMenu's own tests likely
-- tick InputState (fresh-press semantics, no repeat needed for StartMenu).
local function tap(menu, buttonMask)
  local input = InputState.new()
  input:update(0)
  input:update(buttonMask)
  menu:processInput(input)
end

-- 1. Default/no-flags item set: no Pokedex, no Pokemon, matching a fresh
-- save with neither FLAG_SYS_POKEDEX_GET nor FLAG_SYS_POKEMON_GET set yet.
local fresh = StartMenu.new({})
check("fresh save has no Pokedex/Pokemon items", #fresh.items == 5)
check("fresh save item order is Bag/Player/Save/Option/Exit",
  fresh.items[1] == StartMenu.BAG and fresh.items[2] == StartMenu.PLAYER
    and fresh.items[3] == StartMenu.SAVE and fresh.items[4] == StartMenu.OPTION
    and fresh.items[5] == StartMenu.EXIT)

-- 2. Full item set with both flags: real SetUpStartMenu_NormalField order
-- is POKEDEX, POKEMON, BAG, PLAYER, SAVE, OPTION, EXIT.
local full = StartMenu.new({ hasPokedex = true, hasPokemon = true })
check("full item set has 7 items", #full.items == 7)
check("full item order matches real SetUpStartMenu_NormalField",
  full.items[1] == StartMenu.POKEDEX and full.items[2] == StartMenu.POKEMON
    and full.items[3] == StartMenu.BAG and full.items[4] == StartMenu.PLAYER
    and full.items[5] == StartMenu.SAVE and full.items[6] == StartMenu.OPTION
    and full.items[7] == StartMenu.EXIT)

-- 3. Pokemon-only (no Pokedex yet): a real early-game state where the
-- player has a starter but hasn't received the Pokedex.
local pokemonOnly = StartMenu.new({ hasPokemon = true })
check("Pokemon-only set omits Pokedex", pokemonOnly.items[1] == StartMenu.POKEMON)
check("Pokemon-only set has 6 items", #pokemonOnly.items == 6)

-- 4. Cursor nav wraps (real Menu_MoveCursor semantics via MenuCursor).
tap(full, InputState.buildMask({ DPAD_UP = true }))
check("Up from item 0 wraps to the last item", full.cursor.cursorPos == 6, full.cursor.cursorPos)
tap(full, InputState.buildMask({ DPAD_DOWN = true }))
check("Down from the last item wraps to item 0", full.cursor.cursorPos == 0, full.cursor.cursorPos)
tap(full, InputState.buildMask({ DPAD_DOWN = true }))
check("Down moves cursor forward one", full.cursor.cursorPos == 1, full.cursor.cursorPos)

-- 5. Cursor movement is newly-pressed only, no auto-repeat (real
-- StartCB_HandleInput reads JOY_NEW, not newAndRepeatedKeys). Holding Down
-- across repeated update() ticks without a fresh release must NOT move the
-- cursor further; InputState's own repeat machinery only sets
-- newAndRepeatedKeys, and isNewlyPressed(DPAD_DOWN) is false on held ticks,
-- so processInput should see no movement.
local heldInput = InputState.new()
heldInput:update(0)
heldInput:update(InputState.buildMask({ DPAD_DOWN = true }))
full:processInput(heldInput) -- newly pressed: moves from 1 -> 2
local afterFirst = full.cursor.cursorPos
for _ = 1, 60 do
  heldInput:update(InputState.buildMask({ DPAD_DOWN = true })) -- still held, not newly pressed
  full:processInput(heldInput)
end
check("held Down (no fresh press) does not auto-repeat the cursor",
  full.cursor.cursorPos == afterFirst, { afterFirst, full.cursor.cursorPos })

-- 6. A confirms the selected item.
local confirmMenu = StartMenu.new({ hasPokedex = true, hasPokemon = true })
tap(confirmMenu, InputState.buildMask({ DPAD_DOWN = true })) -- POKEDEX -> POKEMON
check("cursor is on POKEMON", confirmMenu:currentItemId() == StartMenu.POKEMON)
tap(confirmMenu, InputState.buildMask({ A_BUTTON = true }))
check("A confirms the current item", confirmMenu.state == StartMenu.SELECTED
  and confirmMenu.selectedItemId == StartMenu.POKEMON)
check("isDone is true once selected", confirmMenu:isDone())

-- 7. B closes with no selection.
local cancelMenu = StartMenu.new({})
tap(cancelMenu, InputState.buildMask({ B_BUTTON = true }))
check("B closes the menu", cancelMenu.state == StartMenu.CLOSED)
check("B leaves no selected item", cancelMenu.selectedItemId == nil)
check("isDone is true once closed", cancelMenu:isDone())

-- 8. START also closes the menu (real JOY_NEW(B_BUTTON | START_BUTTON)).
local startCloseMenu = StartMenu.new({})
tap(startCloseMenu, InputState.buildMask({ START_BUTTON = true }))
check("START closes the menu same as B", startCloseMenu.state == StartMenu.CLOSED)

-- 9. Once done, further input is ignored (state machine is inert).
local doneMenu = StartMenu.new({})
tap(doneMenu, InputState.buildMask({ B_BUTTON = true }))
tap(doneMenu, InputState.buildMask({ DPAD_DOWN = true }))
check("processInput after CLOSED does nothing further", doneMenu.cursor.cursorPos == 0)

-- 10. Real StartMenuPokedexSanityCheck: A on POKEDEX is ignored when
-- nationalDexCount == 0, even though the item is present (hasPokedex flag
-- set but zero real Pokedex entries seen -- the corner case the real
-- sanity check exists for).
local blockedDex = StartMenu.new({ hasPokedex = true, nationalDexCount = 0 })
check("cursor starts on POKEDEX", blockedDex:currentItemId() == StartMenu.POKEDEX)
tap(blockedDex, InputState.buildMask({ A_BUTTON = true }))
check("A on POKEDEX with zero dex count is ignored (real sanity check)",
  blockedDex.state == StartMenu.OPEN and blockedDex.selectedItemId == nil)

-- 11. Without the nationalDexCount corner case (unset -- the common path),
-- A on POKEDEX confirms normally.
local unblockedDex = StartMenu.new({ hasPokedex = true })
tap(unblockedDex, InputState.buildMask({ A_BUTTON = true }))
check("A on POKEDEX confirms when nationalDexCount is not the zero corner case",
  unblockedDex.state == StartMenu.SELECTED and unblockedDex.selectedItemId == StartMenu.POKEDEX)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
