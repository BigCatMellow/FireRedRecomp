-- Ticks a decoded sprite animation (SpriteAnim.decodeCmds output) forward
-- one frame per tick() call, following ANIMCMD_FRAME/JUMP/END the same
-- way the real sprite animation system does (src/sprite.c's
-- AnimCmd-stepping logic: hold the current frame for `duration` ticks,
-- then advance to the next command; a jump command redirects to another
-- index in the same list; an end command freezes on the current frame
-- forever -- confirmed by the title screen's own
-- SpriteCallback_TitleScreenFlame checking `sprite->animEnded` to know
-- when to destroy a flame sprite, i.e. real code treats "reached END" as
-- a terminal, not a wrap).
--
-- Meant to be driven once per real 60Hz tick (same fixed-tick loop
-- TaskScheduler/TextPrinterState use), matching the real animation
-- system running off the same VBlank-synced update as everything else.
-- Pure/testable: operates only on the decoded cmd list, no ROM/love2d
-- coupling.

local SpriteAnimator = {}

local function resolveControlFlow(self)
  while true do
    local cmd = self.cmds[self.cmdIndex]
    if cmd.type == "jump" then
      self.cmdIndex = cmd.target + 1 -- target is 0-based, cmds is 1-based
    elseif cmd.type == "end" then
      self.cmdIndex = self.cmdIndex - 1 -- back up: freeze on the last real frame
      self.ended = true
      break
    else
      break -- landed on a frame command
    end
  end
end

-- cmds: SpriteAnim.decodeCmds() output.
function SpriteAnimator.new(cmds)
  local self = setmetatable({
    cmds = cmds,
    cmdIndex = 1,
    tickCount = 0,
    ended = false,
  }, { __index = SpriteAnimator })
  resolveControlFlow(self) -- in case cmds[1] is itself a jump/end (degenerate but valid)
  return self
end

function SpriteAnimator:tick()
  if self.ended then return end
  local cmd = self.cmds[self.cmdIndex]
  self.tickCount = self.tickCount + 1
  if self.tickCount >= cmd.duration then
    self.tickCount = 0
    self.cmdIndex = self.cmdIndex + 1
    resolveControlFlow(self)
  end
end

-- The currently-displayed frame's real imageValue (a tile offset for
-- sheet-based sprites -- see SpriteAnim.lua) and flip flags.
function SpriteAnimator:currentFrame()
  return self.cmds[self.cmdIndex]
end

return SpriteAnimator
