-- Run: lua5.1 tests/new_game_defaults_test.lua
package.path = package.path .. ";./?.lua"
local NewGameDefaults = require("src.core.NewGameDefaults")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- SetDefaultOptions() (src/new_game.c), real constants from
-- include/constants/global.h.
local opt = NewGameDefaults.options
check("default text speed is OPTIONS_TEXT_SPEED_MID (1)", opt.textSpeed == 1)
check("default window frame type is 0", opt.windowFrameType == 0)
check("default sound is OPTIONS_SOUND_MONO (0)", opt.sound == 0)
check("default battle style is OPTIONS_BATTLE_STYLE_SHIFT (0)", opt.battleStyle == 0)
check("default battle scene is on (battleSceneOff == false)", opt.battleSceneOff == false)
check("default region map zoom is off", opt.regionMapZoom == false)
check("default button mode is OPTIONS_BUTTON_MODE_HELP (0)", opt.buttonMode == 0)

-- Misc SaveBlock2 fields.
local sb2 = NewGameDefaults.saveBlock2
check("encryptionKey starts at 0", sb2.encryptionKey == 0)
check("unkFlag1 is TRUE (real source comment: set TRUE, never read)", sb2.unkFlag1 == true)
check("unkFlag2 is FALSE (real source comment: set FALSE, never read)", sb2.unkFlag2 == false)
check("pokedex.unused default is 0xDA", sb2.pokedexUnused == 0xDA)

-- SetMoney(&gSaveBlock1Ptr->money, 3000).
check("starting money is 3000", NewGameDefaults.startingMoney == 3000)

-- WarpToPlayersRoom().
local warp = NewGameDefaults.startingWarp
check("starting map is Pallet Town Player's House 2F", warp.map == "MAP_PALLET_TOWN_PLAYERS_HOUSE_2F")
check("starting warpId is -1 (dummy, uses x/y instead)", warp.warpId == -1)
check("starting x is 6", warp.x == 6)
check("starting y is 6", warp.y == 6)

-- NewGameInitPCItems() / real gNewGamePCItems table.
check("exactly one starting PC item", #NewGameDefaults.startingPCItems == 1)
check("starting PC item is a Potion", NewGameDefaults.startingPCItems[1].item == "ITEM_POTION")
check("starting PC item quantity is 1", NewGameDefaults.startingPCItems[1].quantity == 1)

-- EventScript_ResetAllMapFlags: real setvar.
local foundMassageVar = false
for _, v in ipairs(NewGameDefaults.setVars) do
  if v.var == "VAR_MASSAGE_COOLDOWN_STEP_COUNTER" then
    foundMassageVar = true
    check("VAR_MASSAGE_COOLDOWN_STEP_COUNTER default is 500", v.value == 500)
  end
end
check("VAR_MASSAGE_COOLDOWN_STEP_COUNTER default is present", foundMassageVar)

-- EventScript_ResetAllMapFlags sets exactly 49 real FLAG_HIDE_* flags,
-- plus the FLAG_0x838 leftover from EnableNationalPokedex_RSE == 50
-- total real flags set TRUE on a new game.
check("50 flags set TRUE on a new game (49 FLAG_HIDE_* + FLAG_0x838)",
  #NewGameDefaults.setFlags == 50, #NewGameDefaults.setFlags)

local function hasFlag(name)
  for _, f in ipairs(NewGameDefaults.setFlags) do
    if f == name then return true end
  end
  return false
end
check("FLAG_HIDE_OAK_IN_HIS_LAB is set (first in the real script)", hasFlag("FLAG_HIDE_OAK_IN_HIS_LAB"))
check("FLAG_HIDE_SAFFRON_CITY_POKECENTER_SABRINA_JOURNALS is set (last in the real script)",
  hasFlag("FLAG_HIDE_SAFFRON_CITY_POKECENTER_SABRINA_JOURNALS"))
check("FLAG_HIDE_DEOXYS is set", hasFlag("FLAG_HIDE_DEOXYS"))
check("FLAG_0x838 (EnableNationalPokedex_RSE leftover) is set", hasFlag("FLAG_0x838"))

-- No duplicate flag names (would indicate a transcription slip).
local seen = {}
local duplicates = 0
for _, f in ipairs(NewGameDefaults.setFlags) do
  if seen[f] then duplicates = duplicates + 1 end
  seen[f] = true
end
check("no duplicate flags in setFlags", duplicates == 0, duplicates)

check("starting party count is 0", NewGameDefaults.startingPartyCount == 0)

print(string.format("new_game_defaults_test: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
