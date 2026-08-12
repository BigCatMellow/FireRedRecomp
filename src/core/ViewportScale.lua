-- Pure math for fitting a source image (a composited map, the title
-- screen, anything this project renders) into an arbitrary window:
-- integer-scaled and centered (letterboxed) so pixel art stays crisp
-- (no non-integer scaling blur) and never gets cropped or distorted.
-- No love.* calls, so it's testable under plain lua5.1; main.lua just
-- calls this each frame (or on resize) and feeds the result to
-- love.graphics.draw.

local ViewportScale = {}

-- sourceWidth/sourceHeight: the image being displayed, in its own pixels
-- (e.g. 256x160 for the title screen, or a composited map's actual size).
-- windowWidth/windowHeight: the available drawing area.
-- Returns { scale, x, y } -- draw the source at that scale, offset by
-- (x, y), to center it with integer scaling. scale is always >= 1 (an
-- image bigger than the window still gets a minimum 1x scale rather than
-- shrinking/blurring -- callers that need to shrink large content should
-- crop instead, not scale down pixel art).
function ViewportScale.fit(sourceWidth, sourceHeight, windowWidth, windowHeight)
  local scale = math.floor(math.min(windowWidth / sourceWidth, windowHeight / sourceHeight))
  if scale < 1 then scale = 1 end

  local x = math.floor((windowWidth - sourceWidth * scale) / 2)
  local y = math.floor((windowHeight - sourceHeight * scale) / 2)

  return { scale = scale, x = x, y = y }
end

return ViewportScale
