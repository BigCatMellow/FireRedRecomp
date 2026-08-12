-- Port of the real title screen slash-in effect's movement/visibility
-- state machine (src/title_screen.c's SpriteCallback_Slash). The slash
-- is a real OBJ sprite in ST_OAM_OBJ_WINDOW mode -- on real hardware it
-- never renders its own pixels; its silhouette instead defines a window
-- region where a "lighten toward white" blend effect
-- (SetGpuRegsForTitleScreenRun: BLDCNT_TGT1_BG0 | BLDCNT_EFFECT_LIGHTEN,
-- BLDY=13) is applied to the logo layer (bg0) as the sprite sweeps
-- across it -- a diagonal flash of light racing over the logo. This
-- module owns only the sprite's real position/visibility timing;
-- PaletteBlend.lua does the actual lighten-toward-white math, and the
-- caller is responsible for testing each logo pixel against the current
-- silhouette (see SlashMask.lua) to decide where to apply it.
--
-- Ported faithfully from the real switch(sprite->sState):
--   state 0: waits sTimer ticks (540 -- 9 real seconds at 60Hz) before
--     becoming visible and moving; starts invisible (inferred: the real
--     code sets `invisible = FALSE` only once the timer expires, which
--     only makes sense if it started TRUE -- this project sets it
--     explicitly rather than relying on an implicit zero-init default).
--   state 1: moves right at a constant 9px/tick from x=-32, with two
--     real one-time vertical jumps (y-=7 exactly at x==67, y+=7 exactly
--     at x==148) -- not a curve, two discrete steps, matching the real
--     integer comparisons. Once x exceeds DISPLAY_WIDTH+32 (272), goes
--     invisible and either freezes (if deactivated) or loops back to
--     state 0 to repeat after another 540-tick wait.
--   state 2: frozen/invisible forever (deactivated).

local SlashSprite = {}

local DISPLAY_WIDTH = 240
local INITIAL_TIMER = 540
local SPEED_X = 9

function SlashSprite.new()
  return setmetatable({
    x = -32,
    y = 27,
    state = 0,
    timer = INITIAL_TIMER,
    invisible = true,
    deactivateRequested = false,
  }, { __index = SlashSprite })
end

-- Real DeactivateSlashSprite: requests the sprite freeze (invisible,
-- state 2) the next time it would otherwise go invisible/reset -- either
-- immediately if it's still waiting (state 0), or after finishing its
-- current sweep (state 1).
function SlashSprite:deactivate()
  self.deactivateRequested = true
end

function SlashSprite:tick()
  if self.state == 0 then
    if self.deactivateRequested then
      self.invisible = true
      self.state = 2
      return
    end
    self.timer = self.timer - 1
    if self.timer == 0 then
      self.invisible = false
      self.state = 1
    end
  elseif self.state == 1 then
    self.x = self.x + SPEED_X
    if self.x == 67 then self.y = self.y - 7 end
    if self.x == 148 then self.y = self.y + 7 end
    if self.x > DISPLAY_WIDTH + 32 then
      self.invisible = true
      if self.deactivateRequested then
        self.state = 2
      else
        self.x = -32
        self.timer = INITIAL_TIMER
        self.state = 0
      end
    end
  end
  -- state 2: frozen, no-op.
end

return SlashSprite
