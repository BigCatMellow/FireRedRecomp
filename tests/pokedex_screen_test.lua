-- Run: lua5.1 tests/pokedex_screen_test.lua
package.path = package.path .. ";./?.lua"
local Screen = require("src.core.PokedexScreen")
local DexTracker = require("src.core.DexTracker")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or "")) end
end
local function fixture(nationalEnabled)
  local dex = DexTracker.new()
  local calls = {names=0}
  local screen = Screen.new({
    dexTracker=dex,
    nationalEnabled=nationalEnabled,
    speciesForNationalDex=function(n) return n end,
    nameForSpecies=function(species) calls.names = calls.names + 1; return "MON" .. species end,
  })
  return screen, dex, calls
end

do
  local screen, dex, calls = fixture(false)
  dex:setSeen(1); dex:setSeen(5); dex:setOwned(5)
  local entries = screen:entries()
  check("Kanto numerical mode stops at its highest seen slot", #entries == 5)
  check("unseen numerical holes stay opaque instead of disappearing", entries[3].nationalDexNo == 3
    and not entries[3].seen and entries[3].label == "-----")
  check("seen names and owned metadata follow separate real flags", entries[1].label == "MON1"
    and entries[5].seen and entries[5].owned and entries[5].label == "MON5")
  check("name adapter is never called for unseen entries", calls.names == 2, calls.names)
  check("National mode is gated until the real flag is enabled", not pcall(function() screen:setMode("national") end))
end

do
  local screen, dex = fixture(true)
  check("empty numerical list has no selected entry", screen:count() == 0
    and screen:snapshot().selected == nil and screen:snapshot().cursorRow == nil)
  dex:setSeen(411)
  check("National mode stops at the highest seen numerical slot", screen:setMode("national")
    and screen:count() == 411 and screen:snapshot().selected.nationalDexNo == 1)
  screen:move(200)
  local middle = screen:snapshot()
  check("nine-row viewport centers a middle selection", middle.selectedIndex == 200
    and middle.scrollTop == 196 and middle.cursorRow == 4)
  screen:move(999)
  local last = screen:snapshot()
  check("viewport clamps at the final entry without cursor wrap", last.selectedIndex == 410
    and last.scrollTop == 402 and last.cursorRow == 8 and not screen:move(1))
  screen:move(-999)
  check("viewport clamps at the first entry without cursor wrap", screen:snapshot().selectedIndex == 0
    and screen:snapshot().scrollTop == 0 and not screen:move(-1))
  check("unseen selection is ignored", screen:handle("confirm") == nil and not screen:isDone())
  dex:setSeen(1)
  local selected = screen:handle("confirm")
  check("seen selection reports National Dex and species", selected and selected.kind == "selected"
    and selected.nationalDexNo == 1 and selected.species == 1 and screen:isDone())
end

do
  local screen, dex = fixture(true)
  dex:setSeen(10); dex:setSeen(200)
  screen:move(9)
  screen:setMode("national")
  screen:move(199)
  screen:setMode("kanto")
  check("each numerical mode preserves its cursor state", screen:snapshot().selectedIndex == 9
    and screen:setMode("national") and screen:snapshot().selectedIndex == 199)
end

do
  local screen = fixture(false)
  local event = screen:handle("cancel")
  check("cancel terminates the list without choosing a species", event and event.kind == "cancelled"
    and screen.state == Screen.CANCELLED and screen:handle("confirm") == nil)
end

print(("pokedex_screen_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
