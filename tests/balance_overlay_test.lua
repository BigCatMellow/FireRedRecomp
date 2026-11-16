-- Run: lua5.1 tests/balance_overlay_test.lua
package.path = package.path .. ";./?.lua"
local Overlay = require("src.core.BalanceOverlay")

local passed, failed = 0, 0
local function check(name, condition)
  if condition then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. name) end
end

local baseMove = { power=40, type=10, accuracy=100, pp=25 }
local changed = Overlay.move(baseMove, { power=50, category=Overlay.CATEGORY_PHYSICAL })
check("move overlay changes derived record", changed.power == 50 and changed.category == "physical")
check("move overlay preserves untouched fields", changed.type == 10 and changed.accuracy == 100)
check("move overlay does not mutate ROM record", baseMove.power == 40 and baseMove.category == nil)
check("no override preserves source identity", Overlay.move(baseMove, nil) == baseMove)

local baseLearnset = { {level=5, move=1}, {level=10, move=2} }
local derived = Overlay.learnset(baseLearnset, { {level=7, move=3} })
check("learnset overlay inserts in level order",
  #derived == 3 and derived[1].move == 1 and derived[2].move == 3 and derived[3].move == 2)
check("learnset overlay does not mutate ROM list", #baseLearnset == 2)

local ok = pcall(function() Overlay.move(baseMove, { effect=99 }) end)
check("overlay rejects fields that would rewrite imported mechanics", not ok)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
