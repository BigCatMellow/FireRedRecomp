-- Run: lua5.1 tests/viridian_mart_parcel_presentation_test.lua
package.path = package.path .. ";./?.lua"
local Presentation = require("src.core.ViridianMartParcelPresentation")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

local function fixture(canBeginResult, commitResult)
  local calls = { preflight=0, commit=0 }
  local presenter = Presentation.new({
    canBegin=function(context)
      calls.preflight = calls.preflight + 1
      return canBeginResult == nil and true or canBeginResult[1], canBeginResult and canBeginResult[2]
    end,
    commit=function()
      calls.commit = calls.commit + 1
      return commitResult == nil and { parcelGranted=true, martScene=1, labScene=5 } or commitResult[1], commitResult and commitResult[2]
    end,
  })
  return presenter, calls
end

local valid = { mapId=Presentation.MAP_VIRIDIAN_MART, playerX=4, playerY=7, clerkPresent=true }

check("source-locked Mart map and doorway descriptors", Presentation.MAP_VIRIDIAN_MART == (5 * 256 + 3)
  and Presentation.DOOR_X == 4 and Presentation.DOOR_Y == 7 and Presentation.CLERK_LOCAL_ID == 1)
check("source-locked Parcel text pointers", Presentation.TEXT_YOU_CAME_FROM_PALLET == 0x0819021A
  and Presentation.TEXT_TAKE_THIS_TO_PROF_OAK == 0x0819023A
  and Presentation.TEXT_RECEIVED_OAKS_PARCEL == 0x08190289)

do
  local p, calls = fixture()
  local start = assert(p:begin(valid))
  check("doorway start locks and begins clerk attention", start.kind == "lock" and p.state == p.WAIT_CLERK_ATTENTION and p:isInputLocked())
  check("doorway start uses exact clerk local id", start.movement.localId == 1)
  check("begin preflights exactly once without committing", calls.preflight == 1 and calls.commit == 0)
  local intro = assert(p:movementComplete("clerk_attention"))
  check("clerk movement exposes first ROM-backed message", intro.textPointer == p.TEXT_YOU_CAME_FROM_PALLET)
  local reveal = assert(p:onA(true, false))
  check("A while text prints reveals rather than advances", reveal.kind == "reveal_text" and p.state == p.SHOW_INTRO)
  local approach = assert(p:onA(true, true))
  check("acknowledging intro starts source-derived approach", approach.kind == "move" and approach.movements[2].steps == 4 and approach.movements[2].finalY == 3 and approach.movements[2].finalFacing == "left")
  check("no persistent commit before request acknowledgement", calls.commit == 0)
  local request = assert(p:movementComplete("approach_counter"))
  check("approach completion exposes second ROM-backed message", request.textPointer == p.TEXT_TAKE_THIS_TO_PROF_OAK)
  local receipt = assert(p:onA(true, true))
  check("request acknowledgement commits then exposes receipt", receipt.kind == "show_text" and receipt.committed and receipt.textPointer == p.TEXT_RECEIVED_OAKS_PARCEL and calls.commit == 1)
  local done = assert(p:onA(true, true))
  check("receipt acknowledgement unlocks only at terminal state", done.kind == "unlock" and done.done and p.state == p.DONE and not p:isInputLocked())
  local duplicate = p:onA(true, true)
  check("terminal presenter cannot commit twice", duplicate == nil and calls.commit == 1)
end

for _, case in ipairs({
  { "wrong map", { mapId=0, playerX=4, playerY=7, clerkPresent=true }, "wrong_map" },
  { "wrong doorway", { mapId=Presentation.MAP_VIRIDIAN_MART, playerX=4, playerY=6, clerkPresent=true }, "wrong_doorway" },
  { "missing clerk", { mapId=Presentation.MAP_VIRIDIAN_MART, playerX=4, playerY=7, clerkPresent=false }, "clerk_missing" },
}) do
  local p, calls = fixture()
  local result, reason = p:begin(case[2])
  check(case[1] .. " starts no cutscene", result == nil and reason == case[3] and p.state == p.IDLE and calls.preflight == 0 and calls.commit == 0)
end

do
  local p, calls = fixture({ false, "parcel_bag_full" })
  local result, reason = p:begin(valid)
  check("failed capacity preflight leaves presenter idle", result == nil and reason == "parcel_bag_full" and p.state == p.IDLE and calls.preflight == 1 and calls.commit == 0)
end

do
  local p, calls = fixture(nil, { nil, "parcel_add_failed" })
  assert(p:begin(valid)); assert(p:movementComplete("clerk_attention")); assert(p:onA(true, true)); assert(p:movementComplete("approach_counter"))
  local result = assert(p:onA(true, true))
  check("late commit failure unlocks without receipt", result.kind == "unlock" and result.failed and result.reason == "parcel_add_failed" and p.state == p.FAILED and not p:isInputLocked() and calls.commit == 1)
end

do
  local p = fixture()
  local result, reason = p:movementComplete("approach_counter")
  check("out-of-order movement completion is rejected", result == nil and reason == "unexpected_movement_completion")
end

print(("viridian_mart_parcel_presentation_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
