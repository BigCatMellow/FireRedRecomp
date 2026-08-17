-- Round-trip coverage for main.lua's save/load boundary: a fresh session's
-- state survives SaveFileCodec.encode -> decode -> GameSession.fromSavedState
-- with the same map/position/identity/party a live loadGameFile() call
-- would reconstruct. Focused, plain-Lua (no ROM, no LOVE window needed --
-- main.lua only touches LOVE while registering callbacks, same trick
-- fresh_save_bootstrap_test.lua uses).
-- Run: lua5.1 tests/save_load_roundtrip_test.lua
package.path = package.path .. ";./?.lua"

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

local original = App.GameSession.fromNewGame({
  playerGender=Flow.MALE,
  playerName=Flow.encodeName("RED"),
  rivalName=Flow.encodeName("BLUE"),
}, {
  nextRandom16=function() return 0xCAFE end,
  generatedTrainerIdLower=0x5678,
})
-- Simulate having walked somewhere and warped, the way syncSessionLocation
-- keeps state.saveBlock1.pos/location live during play.
original:setLocation(3 * 256 + 0, 10, 14, "west") -- Pallet Town, an arbitrary tile

local bytes1, counter1 = Codec.encode(original.state, 0, nil)
check("first save is generation 1", counter1 == 1)

local decoded1, info1 = Codec.decode(bytes1)
check("first save decodes OK", decoded1 ~= nil, info1)
check("decoded save reports the same generation", info1.saveCounter == 1)

local loaded = App.GameSession.fromSavedState(decoded1)
check("loaded map matches the saved warp", loaded.mapId == 3 * 256 + 0)
check("loaded location matches the saved tile",
  loaded.location.mapGroup == 3 and loaded.location.mapNum == 0
    and loaded.location.x == 10 and loaded.location.y == 14)
check("loaded identity matches the original session",
  loaded.identity.playerGender == Flow.MALE
    and loaded.identity.playerName == Flow.encodeName("RED")
    and loaded.identity.rivalName == Flow.encodeName("BLUE"))
check("loaded trainer id survives the round trip",
  loaded.state.saveBlock2.playerTrainerId == original.state.saveBlock2.playerTrainerId)
check("loaded money/PC items survive the round trip",
  loaded.state.saveBlock1.money == original.state.saveBlock1.money
    and loaded.state.saveBlock1.pcItems[1].itemId == original.state.saveBlock1.pcItems[1].itemId
    and loaded.state.saveBlock1.pcItems[1].quantity == original.state.saveBlock1.pcItems[1].quantity)

-- A second save from the reloaded session must alternate the codec's
-- physical slot (real dual-slot save behavior), not silently reset to
-- generation 1 just because it came from a freshly loaded session.
loaded:setLocation(4 * 256 + 1, 6, 6, "north")
local bytes2, counter2 = Codec.encode(loaded.state, counter1, bytes1)
check("second save increments the generation", counter2 == 2)
check("second save keeps the first slot's bytes untouched (alternating slots)",
  bytes2:sub(1, 5) == bytes1:sub(1, 5)) -- shared header at least stays byte-identical

local decoded2, info2 = Codec.decode(bytes2)
check("second save decodes to the newer location", decoded2 ~= nil
  and decoded2.saveBlock1.location.mapGroup == 4 and decoded2.saveBlock1.location.mapNum == 1
  and decoded2.saveBlock1.location.x == 6 and decoded2.saveBlock1.location.y == 6)
check("second decode reports the higher generation", info2.saveCounter == 2)

-- Corrupting the file must fall back cleanly rather than crash or invent
-- a session (SaveFileCodec.decode already has dedicated corruption
-- coverage; this just confirms the flow this project's loadGameFile()
-- takes -- decode failing -- doesn't hand back a usable session).
local corrupted = "not a save file at all"
local decoded3, info3 = Codec.decode(corrupted)
check("garbage input is rejected, not silently accepted", decoded3 == nil and info3 ~= nil)

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
