-- Run: lua5.1 tests/oak_parcel_dex_presentation_test.lua
package.path = package.path .. ";./?.lua"
local Presentation = require("src.core.OakParcelDexPresentation")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

local function fixture(preflight, commit)
  local calls = { preflight=0, commit=0 }
  local presenter = Presentation.new({
    canBegin=function(context)
      calls.preflight = calls.preflight + 1
      return preflight == nil and true or preflight[1], preflight and preflight[2]
    end,
    commit=function()
      calls.commit = calls.commit + 1
      return commit == nil and { pokedexGranted=true, pokeBallsGranted=5 } or commit[1], commit and commit[2]
    end,
  })
  return presenter, calls
end

local valid = { mapId=Presentation.MAP_OAKS_LAB, playerX=6, playerY=4,
  playerFacing="up", oakPresent=true, martScene=1, labScene=5, parcelPresent=true }

check("source-locked north descriptor", Presentation.MAP_OAKS_LAB == (4 * 256 + 3)
  and Presentation.OAK_LOCAL_ID == 4 and Presentation.RIVAL_LOCAL_ID == 8
  and Presentation.DEX_PROP_LEFT_LOCAL_ID == 9 and Presentation.DEX_PROP_RIGHT_LOCAL_ID == 10)
local expectedPointers = {
  0x0818E405, 0x0818E4AF, 0x0818E4CA, 0x0818DE8D, 0x0818DE99,
  0x0818E508, 0x0818E536, 0x0818E5C5, 0x0818E5EA, 0x0818E612,
  0x0818E6B3, 0x0818E6D0, 0x0818E784, 0x0818DEC8, 0x0818DEF3,
}
local pointersMatch = #Presentation.TEXT_POINTERS == #expectedPointers
for index, pointer in ipairs(expectedPointers) do
  pointersMatch = pointersMatch and Presentation.TEXT_POINTERS[index] == pointer
end
check("source-locked all-text pointer order", pointersMatch)

do
  local p, calls = fixture()
  local start = assert(p:begin(valid))
  check("valid north interaction locks before the opening text", start.kind == "lock" and p.state == p.SHOW_TEXT
    and p:currentTextPointer() == 0x0818E405 and p:isInputLocked())
  check("opening text begins after one preflight with no commit", calls.preflight == 1 and calls.commit == 0)
  local reveal = assert(p:onA(true, false))
  check("A reveals printing text without advancing", reveal.kind == "reveal_text" and p.textIndex == 1)
  for i = 1, 3 do assert(p:onA(true, true)) end
  check("first four ROM texts precede the rival entrance", p.textIndex == 4 and p:currentTextPointer() == 0x0818DE8D)
  local rivalArrival = assert(p:onA(true, true))
  check("rival entrance follows the fourth source text", rivalArrival.kind == "move" and rivalArrival.group == "rival_arrival"
    and rivalArrival.spawn.localId == 8 and rivalArrival.spawn.x == 5 and rivalArrival.spawn.y == 10
    and rivalArrival.movements[1].steps == 6 and rivalArrival.movements[2].delay16 == 5
    and rivalArrival.movements[2].delay8 == 1)
  assert(p:movementComplete("rival_arrival"))
  check("arrival exposes fifth ROM text", p.textIndex == 5 and p:currentTextPointer() == 0x0818DE99)
  local faceUp = assert(p:onA(true, true))
  check("player faces up before E508", faceUp.kind == "move" and faceUp.group == "player_face_up" and calls.commit == 0)
  assert(p:movementComplete("player_face_up"))
  check("face-up completion exposes E508", p.textIndex == 6 and p:currentTextPointer() == 0x0818E508)
  assert(p:onA(true, true)); local oakToDex = assert(p:onA(true, true))
  check("E508 and E536 precede Oak move", oakToDex.group == "oak_to_dex" and oakToDex.movements[2].finalX == 5)
  assert(p:movementComplete("oak_to_dex"))
  check("Oak arrival exposes E5C5", p.textIndex == 8 and p:currentTextPointer() == 0x0818E5C5)
  local dexReveal = assert(p:onA(true, true))
  check("Dex reveal uses source prop-removal and delay order", dexReveal.group == "dex_reveal"
    and dexReveal.movements[2].localId == 9 and dexReveal.movements[2].action == "remove"
    and dexReveal.movements[3].action == "delay" and dexReveal.movements[3].frames == 10
    and dexReveal.movements[4].localId == 10 and dexReveal.movements[4].action == "remove"
    and dexReveal.movements[5].action == "delay" and dexReveal.movements[5].frames == 25)
  assert(p:movementComplete("dex_reveal"))
  for i = 9, 12 do assert(p:onA(true, true)) end
  local oakReturn = assert(p:onA(true, true))
  check("E784 acknowledgement returns Oak", oakReturn.group == "oak_return")
  assert(p:movementComplete("oak_return"))
  check("return exposes final rival texts", p.textIndex == 14 and p:currentTextPointer() == 0x0818DEC8)
  assert(p:onA(true, true)); local rivalExit = assert(p:onA(true, true))
  check("final text starts the rival exit without early removal", rivalExit.group == "rival_exit"
    and rivalExit.remove == nil and calls.commit == 0)
  local done = assert(p:movementComplete("rival_exit"))
  check("terminal movement removes live rival, commits once, then unlocks", done.kind == "unlock" and done.done and done.committed
    and done.remove.localId == 8 and done.remove.preserveHideFlag
    and p.state == p.DONE and calls.commit == 1 and not p:isInputLocked())
  local ignored = p:onA(true, true)
  check("terminal presenter cannot duplicate reward", ignored == nil and calls.commit == 1)
end

for _, case in ipairs({
  { "wrong map", { mapId=0 }, "wrong_map" },
  { "wrong position", { mapId=Presentation.MAP_OAKS_LAB, playerX=5, playerY=4 }, "wrong_position" },
  { "wrong facing", { mapId=Presentation.MAP_OAKS_LAB, playerX=6, playerY=4, playerFacing="left" }, "wrong_facing" },
}) do
  local p, calls = fixture()
  local result, reason = p:begin(case[2])
  check(case[1] .. " has no cutscene or mutation", result == nil and reason == case[3]
    and p.state == p.IDLE and calls.preflight == 0 and calls.commit == 0)
end

do
  local p, calls = fixture({ false, "poke_ball_bag_full" })
  local result, reason = p:begin(valid)
  check("preflight failure remains idle", result == nil and reason == "poke_ball_bag_full"
    and p.state == p.IDLE and calls.preflight == 1 and calls.commit == 0)
end

do
  local p, calls = fixture(nil, { nil, "parcel_remove_failed" })
  assert(p:begin(valid)); for _ = 1, 4 do assert(p:onA(true, true)) end
  assert(p:movementComplete("rival_arrival"))
  assert(p:onA(true, true)); assert(p:movementComplete("player_face_up"))
  assert(p:onA(true, true)); assert(p:onA(true, true)); assert(p:movementComplete("oak_to_dex"))
  assert(p:onA(true, true)); assert(p:movementComplete("dex_reveal"))
  for _ = 1, 5 do assert(p:onA(true, true)) end
  assert(p:movementComplete("oak_return")); assert(p:onA(true, true)); assert(p:onA(true, true))
  local failed = assert(p:movementComplete("rival_exit"))
  check("late commit failure unlocks without terminal reward", failed.kind == "unlock" and failed.failed
    and failed.reason == "parcel_remove_failed" and p.state == p.FAILED and calls.commit == 1)
end

do
  local p = fixture()
  local result, reason = p:movementComplete("rival_arrival")
  check("out-of-order completion is rejected", result == nil and reason == "unexpected_movement_completion")
end

print(("oak_parcel_dex_presentation_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
