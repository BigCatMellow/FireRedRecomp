-- Run: lua5.1 tests/fresh_save_bootstrap_test.lua
-- Focused regression coverage for main.lua's pure fresh-session boundary.
package.path = package.path .. ";./?.lua"

-- main.lua only touches LÖVE while registering callbacks, so a tiny table is
-- enough to import its pure GameSession constructor in plain Lua.
love = {}
local App = require("main")
local Flow = require("src.core.NewGameFlow")
local Codec = require("src.core.SaveFileCodec")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

local session = App.GameSession.fromNewGame({
  playerGender=Flow.FEMALE,
  playerName=Flow.encodeName("LEAF"),
  rivalName=Flow.encodeName("GREEN"),
}, {
  nextRandom16=function() return 0xBEEF end,
  generatedTrainerIdLower=0x1234,
})
local state = session.state

check("canonical fresh map is Pallet Player's House 2F", session.mapId == 4 * 256 + 1)
check("canonical fresh location is 4,1 at 6,6",
  state.saveBlock1.location.mapGroup == 4 and state.saveBlock1.location.mapNum == 1
    and state.saveBlock1.location.warpId == -1 and state.saveBlock1.location.x == 6 and state.saveBlock1.location.y == 6)
check("identity is copied into both SaveBlock name fields",
  state.saveBlock2.playerGender == Flow.FEMALE and state.saveBlock2.playerName == Flow.encodeName("LEAF")
    and state.saveBlock1.rivalName == Flow.encodeName("GREEN"))
check("InitPlayerTrainerId composition is little-endian high Random plus injected timer lower",
  state.saveBlock2.playerTrainerId == string.char(0x34, 0x12, 0xEF, 0xBE))
check("fresh party stays empty and PC starts with one real Potion",
  state.saveBlock1.playerPartyCount == 0 and #state.saveBlock1.playerParty == 0
    and state.saveBlock1.pcItems[1].itemId == 13 and state.saveBlock1.pcItems[1].quantity == 1)
local battleLead, battleSlot, battleReason = session:usableBattleLead()
check("fresh pre-starter session visibly has no battle lead",
  battleLead == nil and battleSlot == nil and battleReason:find("empty", 1, true) ~= nil)
check("real NewGameInitData money/options are represented", state.saveBlock1.money == 3000
  and state.saveBlock2.options.textSpeed == 1 and state.saveBlock2.options.sound == false)
check("initial event vars are packed at VarSet indices",
  state.saveBlock1.vars[0x403C - 0x4000 + 1] == 0x0302
    and state.saveBlock1.vars[0x4025 - 0x4000 + 1] == 500)
local function flagIsSet(flags, id)
  local b = string.byte(flags, math.floor(id / 8) + 1)
  return math.floor(b / (2 ^ (id % 8))) % 2 == 1
end
check("initial EventScript and system flags are codec-packed", flagIsSet(state.saveBlock1.flags, 0x02B)
  and flagIsSet(state.saveBlock1.flags, 0x0AE) and flagIsSet(state.saveBlock1.flags, 0x838))

local bytes = Codec.encode(state)
local decoded, info = Codec.decode(bytes)
check("fresh runtime state is SaveFileCodec-compatible", decoded ~= nil and info.status == "OK")
check("codec round trip keeps bedroom location and trainer id",
  decoded and decoded.saveBlock1.location.mapGroup == 4 and decoded.saveBlock1.location.mapNum == 1
    and decoded.saveBlock1.location.x == 6 and decoded.saveBlock1.location.y == 6
    and decoded.saveBlock2.playerTrainerId == state.saveBlock2.playerTrainerId)

session:setLocation(3 * 256, 7, 8, "south")
check("session location mutates the later-save state after movement/warps",
  session.mapId == 3 * 256 and session.location.facing == "south"
    and state.saveBlock1.pos.x == 7 and state.saveBlock1.pos.y == 8
    and state.saveBlock1.location.mapGroup == 3 and state.saveBlock1.location.mapNum == 0
    and state.saveBlock1.location.x == 7 and state.saveBlock1.location.y == 8)

print(("fresh_save_bootstrap_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
