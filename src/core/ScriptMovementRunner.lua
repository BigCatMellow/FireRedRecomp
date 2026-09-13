local ObjectEventState = require("src.core.ObjectEventState")
local PlayerMovement = require("src.core.PlayerMovement")

local Runner = {}
Runner.__index = Runner
local direction = { down=PlayerMovement.DOWN, up=PlayerMovement.UP, left=PlayerMovement.LEFT, right=PlayerMovement.RIGHT }

function Runner.new(npc, steps)
  return setmetatable({npc=assert(npc), steps=assert(steps), index=1}, Runner)
end

function Runner:isDone() return self.index > #self.steps and not self.npc.moving end
function Runner:tick()
  if self.npc.moving then if ObjectEventState.advanceStep(self.npc) then self.index=self.index+1 end; return end
  local step = self.steps[self.index]
  if step then ObjectEventState.beginForcedStep(self.npc, assert(direction[step], "unknown movement direction")) end
end
return Runner
