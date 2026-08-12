-- Per-character text reveal state machine, ported from the real text
-- printer's control-flow (src/text.c's RenderFont, the switch over
-- currChar/EXT_CTRL_CODE_* that returns RENDER_REPEAT/RENDER_UPDATE and
-- sets textPrinter->state to RENDER_STATE_PAUSE/RENDER_STATE_WAIT).
-- Operates on Charmap.tokenize() output rather than raw bytes -- one
-- tick() call is meant to be driven once per real 60Hz tick (see
-- TaskScheduler.lua's header for why -- this matches the real VBlank-
-- synced text printer update).
--
-- Real behavior ported:
--   * "char" tokens are revealed one at a time, gated by ticksPerChar
--     (the real printer's textSpeed field -- this project doesn't have
--     the SLOW/MID/FAST settings menu yet, so ticksPerChar is a fixed
--     constructor argument instead of a save-block setting).
--   * "color"/most "control"/"placeholder" tokens are NOT gated -- the
--     real printer processes them immediately and loops
--     (RENDER_REPEAT) rather than waiting a tick, so any number of them
--     can be consumed in the same tick() call before the next char.
--   * EXT_CTRL_CODE_PAUSE (control code 0x08, one param byte = tick
--     count) stalls further reveal for that many ticks
--     (RENDER_STATE_PAUSE / textPrinter->delayCounter).
--   * EXT_CTRL_CODE_PAUSE_UNTIL_PRESS (0x09) stalls until the caller
--     reports the A button was newly pressed (RENDER_STATE_WAIT).

local TextPrinterState = {}

TextPrinterState.EXT_CTRL_CODE_PAUSE = 0x08
TextPrinterState.EXT_CTRL_CODE_PAUSE_UNTIL_PRESS = 0x09

local DEFAULT_TICKS_PER_CHAR = 4

-- tokens: Charmap.tokenize() output. ticksPerChar: how many tick() calls
-- one character reveal takes (stand-in for the real textSpeed setting).
function TextPrinterState.new(tokens, ticksPerChar)
  return setmetatable({
    tokens = tokens,
    tokenIndex = 0, -- how many tokens have been fully processed/revealed
    tickCount = 0,
    pauseTicksRemaining = 0,
    waitingForPress = false,
    ticksPerChar = ticksPerChar or DEFAULT_TICKS_PER_CHAR,
  }, { __index = TextPrinterState })
end

-- Advances the state machine by exactly one tick. aButtonNewlyPressed:
-- whether the A button was newly pressed this tick (only matters while
-- paused on a PAUSE_UNTIL_PRESS code) -- pass false if not applicable.
function TextPrinterState:tick(aButtonNewlyPressed)
  if self.waitingForPress then
    if aButtonNewlyPressed then self.waitingForPress = false end
    return
  end
  if self.pauseTicksRemaining > 0 then
    self.pauseTicksRemaining = self.pauseTicksRemaining - 1
    return
  end

  while self.tokenIndex < #self.tokens do
    local nextToken = self.tokens[self.tokenIndex + 1]
    if nextToken.type == "char" then
      break
    elseif nextToken.type == "control" and nextToken.sub == TextPrinterState.EXT_CTRL_CODE_PAUSE then
      self.pauseTicksRemaining = nextToken.params[1] or 0
      self.tokenIndex = self.tokenIndex + 1
      return -- this tick triggers the pause; counting starts next tick
    elseif nextToken.type == "control" and nextToken.sub == TextPrinterState.EXT_CTRL_CODE_PAUSE_UNTIL_PRESS then
      self.waitingForPress = true
      self.tokenIndex = self.tokenIndex + 1
      return
    else
      self.tokenIndex = self.tokenIndex + 1
    end
  end
  if self.tokenIndex >= #self.tokens then return end

  self.tickCount = self.tickCount + 1
  if self.tickCount >= self.ticksPerChar then
    self.tickCount = 0
    self.tokenIndex = self.tokenIndex + 1 -- consume the char token
  end
end

-- The tokens revealed so far -- pass straight to TextRenderer.renderTokens.
function TextPrinterState:revealedTokens()
  local sliced = {}
  for i = 1, self.tokenIndex do sliced[i] = self.tokens[i] end
  return sliced
end

function TextPrinterState:isFullyRevealed()
  return self.tokenIndex >= #self.tokens
end

-- Jumps straight to the fully-revealed end state -- for deterministic
-- automated screenshots that want the finished message regardless of
-- whatever partial reveal/pause state was in progress.
function TextPrinterState:revealAll()
  self.tokenIndex = #self.tokens
  self.pauseTicksRemaining = 0
  self.waitingForPress = false
end

return TextPrinterState
