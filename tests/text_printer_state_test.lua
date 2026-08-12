-- Unit test: verifies TextPrinterState's per-character reveal timing and
-- its handling of EXT_CTRL_CODE_PAUSE / PAUSE_UNTIL_PRESS control tokens,
-- against synthetic Charmap.tokenize()-shaped token lists (no ROM needed --
-- this module operates purely on tokens, not raw ROM bytes).
-- Run: lua5.1 tests/text_printer_state_test.lua
package.path = package.path .. ";./?.lua"
local TextPrinterState = require("src.core.TextPrinterState")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local function charToken(id) return { type = "char", glyphId = id } end

-- Plain characters reveal one at a time, gated by ticksPerChar.
do
  local tokens = { charToken(1), charToken(2), charToken(3) }
  local s = TextPrinterState.new(tokens, 3)
  check("nothing revealed before any ticks", s.tokenIndex == 0)
  s:tick(false); s:tick(false)
  check("not yet revealed after 2 of 3 ticks", s.tokenIndex == 0)
  s:tick(false)
  check("first char revealed after ticksPerChar ticks", s.tokenIndex == 1)
  for i = 1, 3 do s:tick(false) end
  check("second char revealed after another ticksPerChar ticks", s.tokenIndex == 2)
  for i = 1, 3 do s:tick(false) end
  check("all chars revealed, isFullyRevealed true", s:isFullyRevealed())
  for i = 1, 10 do s:tick(false) end
  check("ticking past the end doesn't error or overshoot", s.tokenIndex == #tokens)
end

-- Color/control tokens (other than PAUSE/PAUSE_UNTIL_PRESS) are consumed
-- immediately, not gated by ticksPerChar -- several can process in one tick.
do
  local tokens = { { type = "color", fg = 4 }, { type = "color", fg = 1 }, charToken(1) }
  local s = TextPrinterState.new(tokens, 5)
  s:tick(false)
  check("both color tokens consumed in a single tick, before any char gating", s.tokenIndex == 2)
  check("revealedTokens includes both color switches already", #s:revealedTokens() == 2)
end

-- EXT_CTRL_CODE_PAUSE stalls further reveal for exactly its param's tick
-- count, then resumes normally.
do
  local tokens = { charToken(1), { type = "control", sub = TextPrinterState.EXT_CTRL_CODE_PAUSE, params = { 3 } }, charToken(2) }
  local s = TextPrinterState.new(tokens, 1) -- 1 tick per char, isolates the pause timing
  s:tick(false)
  check("first char reveals immediately (1 tick/char)", s.tokenIndex == 1)
  s:tick(false)
  check("pause token consumed, this tick spent triggering it", s.tokenIndex == 2)
  s:tick(false); s:tick(false)
  check("still paused after 2 of 3 pause ticks", s.tokenIndex == 2)
  s:tick(false)
  check("still paused after all 3 pause ticks (pause consumed, next tick reveals)", s.tokenIndex == 2)
  s:tick(false)
  check("second char reveals on the first tick after the pause ends", s.tokenIndex == 3)
end

-- EXT_CTRL_CODE_PAUSE_UNTIL_PRESS stalls indefinitely until the caller
-- reports an A-button press, regardless of how many ticks pass.
do
  local tokens = { charToken(1), { type = "control", sub = TextPrinterState.EXT_CTRL_CODE_PAUSE_UNTIL_PRESS, params = {} }, charToken(2) }
  local s = TextPrinterState.new(tokens, 1)
  s:tick(false)
  check("first char reveals", s.tokenIndex == 1)
  s:tick(false)
  check("wait token consumed, now waiting for press", s.tokenIndex == 2 and s.waitingForPress)
  for i = 1, 50 do s:tick(false) end
  check("stays paused indefinitely without a press, no matter how many ticks", s.tokenIndex == 2)
  s:tick(true) -- A pressed
  check("press clears the wait state (still doesn't reveal the next char this same tick)", not s.waitingForPress)
  s:tick(false)
  check("second char reveals on the next tick after the press", s.tokenIndex == 3)
end

-- revealAll() jumps straight to the finished state regardless of pauses,
-- for deterministic automated screenshots.
do
  local tokens = { charToken(1), { type = "control", sub = TextPrinterState.EXT_CTRL_CODE_PAUSE_UNTIL_PRESS, params = {} }, charToken(2) }
  local s = TextPrinterState.new(tokens, 100)
  s:revealAll()
  check("revealAll fully reveals despite an unresolved PAUSE_UNTIL_PRESS", s:isFullyRevealed())
  check("revealAll clears any pending wait state", not s.waitingForPress)
  check("revealedTokens returns every token once fully revealed", #s:revealedTokens() == #tokens)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
