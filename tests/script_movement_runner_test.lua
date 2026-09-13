package.path=package.path..";./?.lua"
local R=require("src.core.ScriptMovementRunner")
local O=require("src.core.ObjectEventState")
local n={x=2,y=2,moving=false}
local r=R.new(n,{"right","up"})
for _=1,40 do r:tick() end
assert(r:isDone() and n.x==3 and n.y==1)
print("script_movement_runner_test: 1 passed, 0 failed")
