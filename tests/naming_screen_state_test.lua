-- Pure tests for src/core/NamingScreenState.lua's port of FireRed
-- src/naming_screen.c. Run: lua5.1 tests/naming_screen_state_test.lua
package.path = package.path .. ";./?.lua"

local Charmap = require("import.Charmap")
local InputState = require("src.core.InputState")
local Naming = require("src.core.NamingScreenState")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local function input(newButton, repeatedButton)
  return {
    isNewlyPressed = function(_, b) return b == newButton end,
    isPressedOrRepeated = function(_, b) return b == newButton or b == repeatedButton end,
  }
end

do
  local n = Naming.new()
  check("starts on real uppercase page", n.page == Naming.PAGE_UPPER)
  check("upper/lower pages expose 8 columns", n:columnCount() == 8)
  check("starts on A", n:currentChar() == 0xBB)
  local x, y = n:cursorScreenPosition()
  check("first real cursor center is (38,88)", x == 38 and y == 88)

  n:move(-1, 0)
  check("left from first key wraps into PAGE button", n:keyRole() == Naming.ROLE_PAGE)
  n:move(0, -1)
  check("up in button column wraps PAGE to OK", n:keyRole() == Naming.ROLE_OK)
  n:move(0, 1)
  check("down in button column wraps OK to PAGE", n:keyRole() == Naming.ROLE_PAGE)
  n:move(1, 0)
  check("right from PAGE returns to top key row", n.cursorX == 0 and n.cursorY == 0)
end

do
  local n = Naming.new()
  n.cursorY = 2
  n:move(-1, 0)
  check("row 2 enters the shared BACK button", n:keyRole() == Naming.ROLE_BACKSPACE)
  n:move(1, 0)
  check("leaving BACK restores the remembered key row", n.cursorX == 0 and n.cursorY == 2)
end

do
  local n = Naming.new()
  n.cursorX = 7
  n:swapPage() -- upper -> lower
  check("page order is upper -> lower", n.page == Naming.PAGE_LOWER and n.cursorX == 7)
  n:swapPage() -- lower -> symbols, clamp 7 to 5
  check("symbols page has 6 cols and clamps a key cursor", n.page == Naming.PAGE_SYMBOLS and n:columnCount() == 6 and n.cursorX == 5)
  n:swapPage()
  check("page order wraps symbols -> upper", n.page == Naming.PAGE_UPPER)
end

do
  local n = Naming.new({ fallbackBytes = string.char(0xCC,0xBF,0xBE,0xFF) }) -- RED
  n:processInput(input(InputState.A_BUTTON))
  check("A appends selected charmap byte", Charmap.decode(n:entryBytes()) == "A")
  n:processInput(input(InputState.B_BUTTON))
  check("B backspaces", Charmap.decode(n:entryBytes()) == "")
  check("blank result preserves preselected real default", Charmap.decode(n:resultBytes()) == "RED")

  for _ = 1, 7 do n:processInput(input(InputState.A_BUTTON)) end
  check("name reaches the real seven-byte cap", Charmap.decode(n:entryBytes()) == "AAAAAAA")
  check("full name auto-moves to OK", n:keyRole() == Naming.ROLE_OK)
  n.cursorX, n.cursorY = 0, 0
  n:processInput(input(InputState.A_BUTTON))
  check("typing while full overwrites the final byte, not length 8", #Charmap.decode(n:entryBytes()) == 7)
  n:processInput(input(InputState.START_BUTTON))
  check("START jumps to OK", n:keyRole() == Naming.ROLE_OK)
  check("A on OK finishes", n:processInput(input(InputState.A_BUTTON)) == "finish")
  check("stored buffer is exactly 7 bytes plus EOS", #n:resultBytes() == 8 and n:resultBytes():byte(8) == 0xFF)
end

do
  local n = Naming.new()
  n:processInput(input(InputState.SELECT_BUTTON))
  check("SELECT cycles upper to lower", n.page == Naming.PAGE_LOWER)
  n:processInput(input(InputState.SELECT_BUTTON))
  check("SELECT cycles lower to symbols", n.page == Naming.PAGE_SYMBOLS)
  n.cursorX, n.cursorY = 0, 2
  check("symbols row 2 col 0 is !", n:currentChar() == 0xAB)
  n.cursorX, n.cursorY = 2, 2
  check("symbols include real male glyph", n:currentChar() == 0xB5)
  n.cursorX, n.cursorY = 3, 2
  check("symbols include real female glyph", n:currentChar() == 0xB6)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
