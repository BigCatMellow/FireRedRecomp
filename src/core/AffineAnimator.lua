-- Ticks a decoded sprite affine (rotation/scaling) animation
-- (AffineAnim.decodeCmds output) forward, exposing the current scale/
-- rotation for a caller to feed into love.graphics.draw's own sx/sy/r
-- parameters.
--
-- Follows the same duration/jump/loop/end control flow as
-- SpriteAnimator.lua (hold the current frame for `duration` ticks, then
-- advance; a jump redirects elsewhere in the list; end freezes forever;
-- a loop repeats the preceding block `count` times) -- ported from the
-- real ContinueAffineAnim/AffineAnimCmd_* control flow (src/sprite.c),
-- which shares that same structure with the regular (non-affine)
-- animation system.
--
-- Deliberately SIMPLIFIED value semantics, disclosed here rather than
-- silently guessed: the real engine has two distinct value-application
-- paths -- ApplyAffineAnimFrameAbsolute (used when a NEW frame command
-- becomes active: sets xScale/yScale/rotation directly) and
-- ApplyAffineAnimFrameRelativeAndUpdateMatrix (re-applied every
-- remaining tick of a frame's duration, ADDING the frame's values to
-- the running state each time -- this is what turns a single small
-- rotation delta like the real sAffineAnim_BallRotate_Right's
-- FRAME(0,0,-3,1) into a repeating wobble across many loop iterations).
-- The exact interplay between these two paths could not be confirmed
-- with full confidence from the available decompiled source (the plain
-- `ApplyAffineAnimFrame` function multiple call sites use isn't fully
-- traced here). Rather than risk a subtly-wrong dual-mode port, this
-- module uses one clear rule instead: xScale/yScale are applied
-- ABSOLUTE per frame when non-zero (matches real identity frames like
-- AFFINEANIMCMD_FRAME(256,256,0,0) clearly meaning "set to 1.0x", not
-- "add 256"); a literal 0 on either axis leaves that axis's current
-- scale untouched rather than collapsing it to zero -- confirmed
-- necessary against real data, not just a defensive guess: the real
-- rotation-only wobble frames (sAffineAnim_BallRotate_Right/_Left/_0)
-- all have xScale=yScale=0, and were clearly never meant to zero out
-- the sprite. Rotation ACCUMULATES across frame activations (matches
-- small signed deltas like -3/+3 clearly meaning "turn a bit more each
-- time", not "set rotation to -3 degrees"). This produces a real,
-- ROM-data-driven animation with the right *shape* of motion; it is not
-- guaranteed frame-tick-exact against the real hardware's wobble timing.

local AffineAnimator = {}

local function resolveControlFlow(self)
  while true do
    local cmd = self.cmds[self.cmdIndex]
    if cmd.type == "jump" then
      self.cmdIndex = cmd.target + 1
    elseif cmd.type == "loop" then
      -- Loops (re-run the single preceding frame `count` times) aren't
      -- meaningfully different from a jump-to-self for this module's
      -- simplified continuous-rotation model, since real usage here is
      -- always "repeat the previous entry" -- treat it as a jump back
      -- one frame, bounded by count so it still eventually falls through
      -- if this is ever a genuine finite loop rather than infinite.
      if not self.loopsRemaining then self.loopsRemaining = cmd.count end
      if self.loopsRemaining > 0 then
        self.loopsRemaining = self.loopsRemaining - 1
        self.cmdIndex = self.cmdIndex - 1
      else
        self.loopsRemaining = nil
        self.cmdIndex = self.cmdIndex + 1
      end
    elseif cmd.type == "end" then
      self.cmdIndex = self.cmdIndex - 1
      self.ended = true
      break
    else
      break -- landed on a frame command
    end
  end
end

local function applyFrame(self, frame)
  -- A literal 0 means "don't touch this axis," not "scale to zero" --
  -- confirmed against real data: sAffineAnim_BallRotate_Right/_Left/_0
  -- (rotation-only wobble frames) all have xScale=yScale=0, and were
  -- clearly never meant to collapse the sprite to nothing; only frames
  -- like BallRotate_3's (256,256,...) carry a real absolute scale.
  if frame.xScale ~= 0 then self.xScale = frame.xScale / 256 end
  if frame.yScale ~= 0 then self.yScale = frame.yScale / 256 end
  -- Real rotation field is a u8 shifted <<8 into a 16-bit angle
  -- (0-65536 = 0-360 degrees) before use -- confirmed from real
  -- src/sprite.c: `frameCmd->rotation << 8`. A raw byte > 127 is a
  -- negative delta wrapped into u8 range (e.g. -3 stored as 253).
  local signedRotation = frame.rotation > 127 and (frame.rotation - 256) or frame.rotation
  self.rotationAngle = (self.rotationAngle + signedRotation / 256) % 1 -- 0..1 = 0..360 degrees
end

-- cmds: AffineAnim.decodeCmds() output.
function AffineAnimator.new(cmds)
  local self = setmetatable({
    cmds = cmds,
    cmdIndex = 1,
    tickCount = 0,
    ended = false,
    xScale = 1, yScale = 1, -- real AffineAnimStateStartAnim init: xScale=yScale=0x0100=1.0
    rotationAngle = 0, -- 0..1 fraction of a full turn
  }, { __index = AffineAnimator })
  resolveControlFlow(self)
  if not self.ended then applyFrame(self, self.cmds[self.cmdIndex]) end
  return self
end

function AffineAnimator:tick()
  if self.ended then return end
  local cmd = self.cmds[self.cmdIndex]
  self.tickCount = self.tickCount + 1
  if self.tickCount >= math.max(cmd.duration, 1) then
    self.tickCount = 0
    self.cmdIndex = self.cmdIndex + 1
    resolveControlFlow(self)
    if not self.ended then applyFrame(self, self.cmds[self.cmdIndex]) end
  end
end

-- Radians, ready for love.graphics.draw's rotation parameter.
function AffineAnimator:rotationRadians()
  return self.rotationAngle * 2 * math.pi
end

return AffineAnimator
