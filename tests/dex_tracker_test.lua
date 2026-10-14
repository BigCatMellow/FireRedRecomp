-- Run: lua5.1 tests/dex_tracker_test.lua
package.path = package.path .. ";./?.lua"
local DexTracker = require("src.core.DexTracker")
local StartMenu = require("src.core.StartMenu")
local InputState = require("src.core.InputState")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local dex = DexTracker.new()

check("nothing seen/owned initially", dex:isSeen(1) == false and dex:isOwned(1) == false)

dex:setSeen(1) -- Bulbasaur
check("Bulbasaur seen after setSeen", dex:isSeen(1) == true)
check("Bulbasaur still not owned", dex:isOwned(1) == false)

dex:setOwned(1)
check("Bulbasaur owned after setOwned", dex:isOwned(1) == true)

check("Charmander (4) unaffected", dex:isSeen(4) == false and dex:isOwned(4) == false)

-- Cross-byte-boundary check: dex# 8 is bit 7 of byte 0, dex# 9 is bit 0
-- of byte 1 (zero-based index = (n-1); n=8 -> zeroBased=7 -> byte0 bit7;
-- n=9 -> zeroBased=8 -> byte1 bit0), per the real
-- DexScreen_GetSetPokedexFlag formula.
dex:setSeen(8)
check("dex #8 seen (byte0 bit7)", dex:isSeen(8) == true)
check("dex #9 unaffected by #8", dex:isSeen(9) == false)
dex:setSeen(9)
check("dex #9 seen (byte1 bit0)", dex:isSeen(9) == true)
check("dex #8 still seen after #9 set", dex:isSeen(8) == true)

-- Pinned pret c75f352, include/constants/pokedex.h:6-426: Deoxys is
-- National #386 and NATIONAL_DEX_COUNT is Deoxys, not old Unown #411.
-- Literal source oracles below must not derive their bounds from the tracker.
dex:setSeen(386)
check("last national dex entry (386) seen and not implicitly owned",
  dex:isSeen(386) == true and dex:isOwned(386) == false)
dex:setOwned(386)
check("last national dex entry (386) owned and still seen",
  dex:isOwned(386) == true and dex:isSeen(386) == true)
check("#386 uses bit 1 of zero-based byte 48",
  dex.seen[48] == 2 and dex.owned[48] == 2)

local invalidDex = DexTracker.new()
for _, n in ipairs({ 0, 387, 411, 416, 417 }) do
  for _, method in ipairs({ "isSeen", "isOwned", "setSeen", "setOwned" }) do
    local ok = pcall(invalidDex[method], invalidDex, n)
    check(method .. " rejects out-of-range #" .. n, ok == false)
  end
end
local unchanged, seenBytes, ownedBytes = true, 0, 0
for i = 0, 51 do
  unchanged = unchanged and invalidDex.seen[i] == 0 and invalidDex.owned[i] == 0
end
for _ in pairs(invalidDex.seen) do seenBytes = seenBytes + 1 end
for _ in pairs(invalidDex.owned) do ownedBytes = ownedBytes + 1 end
check("rejected setters leave both 52-byte arrays unchanged",
  unchanged and seenBytes == 52 and ownedBytes == 52)

check("DEX_FLAGS_NO is 52", DexTracker.DEX_FLAGS_NO == 52)
check("NATIONAL_DEX_COUNT is source literal 386", DexTracker.NATIONAL_DEX_COUNT == 386)

-- Serialized SaveBlock2 seen bytes drive the normal field START Pokedex
-- zero-seen-entry admission guard; the owned field must not be substituted.
local zeroSeen = string.rep("\0", 52)
check("serialized zero seen count is zero", DexTracker.countSeenSaveBytes(zeroSeen) == 0)
local firstSeen = string.char(1) .. string.rep("\0", 51)
check("serialized first national entry counted", DexTracker.countSeenSaveBytes(firstSeen) == 1)
local crossByteSeen = string.char(128, 1) .. string.rep("\0", 50)
check("serialized #8 and #9 counted across byte boundary",
  DexTracker.countSeenSaveBytes(crossByteSeen) == 2)
-- #386 is bit 1 of byte 49; #387-416 are padding/old Unown entries,
-- excluded by src/pokedex.c:29-49's NATIONAL_DEX_COUNT loop.
local lastSeen = string.rep("\0", 48) .. string.char(2) .. string.rep("\0", 3)
local only387 = string.rep("\0", 48) .. string.char(4) .. string.rep("\0", 3)
local only411 = string.rep("\0", 51) .. string.char(4)
local only416 = string.rep("\0", 51) .. string.char(128)
local trailingSeen = string.rep("\0", 48) .. string.char(252, 255, 255, 255)
check("serialized #386 counted", DexTracker.countSeenSaveBytes(lastSeen) == 1)
check("serialized #387 excluded", DexTracker.countSeenSaveBytes(only387) == 0)
check("serialized #411 excluded", DexTracker.countSeenSaveBytes(only411) == 0)
check("serialized #416 excluded", DexTracker.countSeenSaveBytes(only416) == 0)
check("all trailing #387-416 bits excluded", DexTracker.countSeenSaveBytes(trailingSeen) == 0)
check("all serialized valid national bits count to literal 386",
  DexTracker.countSeenSaveBytes(string.rep(string.char(255), 52)) == 386)
local absentCount, absentReason = DexTracker.countSeenSaveBytes(nil)
check("missing serialized seen field is unknown, not fabricated zero",
  absentCount == nil and absentReason ~= nil)
local truncatedCount = DexTracker.countSeenSaveBytes(string.rep("\0", 51))
check("truncated serialized seen field is not accepted", truncatedCount == nil)
check("oversized serialized seen field is not accepted",
  DexTracker.countSeenSaveBytes(string.rep("\0", 53)) == nil)
check("non-string serialized seen field is not accepted", DexTracker.countSeenSaveBytes({}) == nil)

-- Exercise the real StartMenu/InputState guard with serialized fixtures,
-- not a copied admission predicate. Source: src/start_menu.c:458-463.
local function menuAfterA(rawSeen)
  local menu = StartMenu.new({
    hasPokedex = true, hasPokemon = true,
    nationalDexCount = DexTracker.countSeenSaveBytes(rawSeen),
  })
  local input = InputState.new()
  input:update(0)
  input:update(InputState.A_BUTTON)
  menu:processInput(input)
  return menu
end
for _, fixture in ipairs({
  { "zero", zeroSeen }, { "#387 only", only387 }, { "#411 only", only411 },
  { "#416 only", only416 }, { "all trailing bits", trailingSeen },
}) do
  local menu = menuAfterA(fixture[2])
  check("StartMenu rejects " .. fixture[1] .. " seen bytes without closing or moving",
    menu.state == StartMenu.OPEN and menu.selectedItemId == nil
      and menu:currentItemId() == StartMenu.POKEDEX and menu.cursor.cursorPos == 0)
end
for _, fixture in ipairs({ { "#1", firstSeen }, { "#386", lastSeen } }) do
  local menu = menuAfterA(fixture[2])
  check("StartMenu admits real seen entry " .. fixture[1],
    menu.state == StartMenu.SELECTED and menu.selectedItemId == StartMenu.POKEDEX)
end
local unknownMenu = menuAfterA(nil)
check("absent count preserves existing unspecified-count StartMenu behavior",
  unknownMenu.state == StartMenu.SELECTED and unknownMenu.selectedItemId == StartMenu.POKEDEX)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
