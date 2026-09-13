package.path = package.path .. ";./?.lua"
local T = require("src.core.MapConnectionTraversal")
local pass, fail = 0, 0
local function check(name, condition)
  if condition then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. name) end
end

check("edge direction uses the perpendicular coordinate",
  T.edgeAt(-1, 4, 10, 8) == T.WEST and T.edgeAt(3, -1, 10, 8) == T.NORTH)
check("positive offset excludes the uncovered leading edge",
  not T.coversCoordinate(1, 10, 6, 3) and T.coversCoordinate(3, 10, 6, 3))
check("short destination excludes the uncovered trailing edge",
  T.coversCoordinate(5, 10, 6, 0) and not T.coversCoordinate(7, 10, 6, 0))

local northA = { direction=T.NORTH, offset=0, mapGroup=3, mapNum=1 }
local northB = { direction=T.NORTH, offset=8, mapGroup=3, mapNum=2 }
local targetSizes = { [northA]=8, [northB]=6 }
local getSize = function(connection) return targetSizes[connection] end
check("same-edge partial connections select by coverage",
  T.findIncoming({ [0]=northA, [1]=northB }, T.NORTH, 2, 14, getSize) == northA
  and T.findIncoming({ [0]=northA, [1]=northB }, T.NORTH, 10, 14, getSize) == northB)
check("uncovered edge coordinate has no connection",
  T.findIncoming({ [0]=northA }, T.NORTH, 12, 14, getSize) == nil)

local x, y = T.destinationPosition({ direction=T.NORTH, offset=3 }, 7, -1, 20, 12)
check("north crossing applies offset and arrives on south edge", x == 4 and y == 11)
x, y = T.destinationPosition({ direction=T.WEST, offset=-2 }, -1, 5, 20, 12)
check("west crossing applies signed offset and arrives on east edge", x == 19 and y == 7)

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
