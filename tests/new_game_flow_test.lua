-- Pure end-to-end tests for the post-Oak identity flow.
-- Run: lua5.1 tests/new_game_flow_test.lua
package.path = package.path .. ";./?.lua"

local Charmap = require("import.Charmap")
local InputState = require("src.core.InputState")
local Flow = require("src.core.NewGameFlow")
local Naming = require("src.core.NamingScreenState")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end
local function input(button)
  return {
    isNewlyPressed = function(_, b) return b == button end,
    isPressedOrRepeated = function(_, b) return b == button end,
  }
end
local A, B = InputState.A_BUTTON, InputState.B_BUTTON

do
  local randomCalls = 0
  local f = Flow.new({ nextRandom16 = function() randomCalls = randomCalls + 1; return 2 end })
  check("flow begins at gender", f.state == Flow.GENDER)
  f.genderCursor.cursorPos = Flow.FEMALE
  f:processInput(input(A))
  check("gender confirmation opens player keyboard", f.state == Flow.PLAYER_NAMING and f.playerGender == Flow.FEMALE)
  check("real player default was selected once", randomCalls == 1)

  -- Enter LEAF using direct real cursor positions: L,E,A,F.
  local positions = { {5,1}, {4,0}, {0,0}, {5,0} }
  for _, p in ipairs(positions) do
    f.naming.cursorX, f.naming.cursorY = p[1], p[2]
    f:processInput(input(A))
  end
  f:processInput(input(InputState.START_BUTTON))
  f:processInput(input(A))
  check("player keyboard writes a charmap name before confirm", f.state == Flow.PLAYER_CONFIRM and Charmap.decode(f.playerName) == "LEAF", Charmap.decode(f.playerName or ""))

  f.confirmCursor.cursorPos = 1
  f:processInput(input(A))
  check("NO returns to player keyboard", f.state == Flow.PLAYER_NAMING)
  check("redo picks another source-faithful fallback", randomCalls == 2)
  f:processInput(input(InputState.START_BUTTON))
  f:processInput(input(A))
  check("empty redo keeps randomly chosen female default OMI", Charmap.decode(f.playerName) == "OMI", Charmap.decode(f.playerName or ""))
  f.confirmCursor.cursorPos = 0
  f:processInput(input(A))
  check("YES proceeds to rival choice menu", f.state == Flow.RIVAL_CHOICE)

  f.rivalChoiceCursor.cursorPos = 2 -- menu row 2 = second preset, GARY
  f:processInput(input(A))
  check("rival preset writes the real GARY bytes", f.state == Flow.RIVAL_CONFIRM and Charmap.decode(f.rivalName) == "GARY")
  f.confirmCursor.cursorPos = 1
  f:processInput(input(A))
  check("rival NO returns to NEW NAME/preset menu", f.state == Flow.RIVAL_CHOICE)

  f.rivalChoiceCursor.cursorPos = 0
  f:processInput(input(A))
  check("NEW NAME opens reused rival keyboard", f.state == Flow.RIVAL_NAMING and f.naming.page == Naming.PAGE_UPPER)
  -- B on an empty buffer is harmless, then blank OK retains GREEN fallback.
  f:processInput(input(B))
  f:processInput(input(InputState.START_BUTTON))
  f:processInput(input(A))
  check("blank rival keyboard retains real GREEN fallback", Charmap.decode(f.rivalName) == "GREEN")
  f.confirmCursor.cursorPos = 0
  f:processInput(input(A))
  local result = f:result()
  check("rival YES reaches clean completed state", f:isComplete() and result ~= nil)
  check("completed result has SaveBlock field values", result.playerGender == Flow.FEMALE and Charmap.decode(result.playerName) == "OMI" and Charmap.decode(result.rivalName) == "GREEN")
  check("both completed name buffers are exactly u8[8]", #result.playerName == 8 and #result.rivalName == 8)
end

do
  local f = Flow.new()
  f:processInput(input(InputState.DPAD_UP))
  check("gender cursor uses real no-wrap input", f.genderCursor.cursorPos == 0)
  f:processInput(input(B))
  check("gender B is ignored like Menu_ProcessInputNoWrapAround caller", f.state == Flow.GENDER)
  f:beginRivalChoice(Flow.encodeName("RED"))
  f:processInput(input(B))
  check("rival-choice B is ignored like real Oak task", f.state == Flow.RIVAL_CHOICE)
  check("FireRed rival presets are exact", table.concat(Flow.RIVAL_DEFAULTS, ",") == "GREEN,GARY,KAZ,TORU")
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
