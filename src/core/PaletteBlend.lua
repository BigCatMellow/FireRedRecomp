-- Port of pokefirered's real palette blend math (src/blend_palette.c's
-- BlendPalette -- the function every screen fade in the game bottoms out
-- in): each color channel moves toward a target color by coeff/16, using
-- the exact real formula `c + ((target - c) * coeff) >> 4` (a 4-bit
-- arithmetic right shift, i.e. floor division by 16 -- confirmed from the
-- real C source, not assumed).
--
-- One deliberate difference from the real hardware: the real GBA blends
-- in 5-bit-per-channel palette RAM (0-31), then the hardware's own DAC
-- upconverts to a display color. This project never keeps a separate
-- indexed palette buffer -- every renderer (MapCompositor, TitleScreen,
-- ObjectSprite, ...) already materializes straight-to-8bpp RGB pixel
-- images, consistent with how love2d actually draws things -- so this
-- module applies the identical linear-interpolation formula directly in
-- 8-bit (0-255) space instead of 5-bit. The blend curve shape is
-- unchanged (same `>> 4` structure, same clamping at coeff=16); the only
-- difference is precision (8-bit steps instead of 5-bit steps), which is
-- imperceptible and consistent with this project's existing choice to
-- always work in materialized RGB rather than emulate GBA palette RAM.

local PaletteBlend = {}

-- coeff: 0-16 (0 = fully unfaded/original color, 16 = fully blendColor).
-- Values are clamped to that range even if the caller passes something
-- else, matching how the real hardware coefficient is a 5-bit field but
-- only 0-16 is ever meaningful for BlendPalette's `>> 4` math.
local function blendChannel(c, target, coeff)
  if coeff < 0 then coeff = 0 elseif coeff > 16 then coeff = 16 end
  return c + math.floor((target - c) * coeff / 16)
end

-- color/blendColor: {r,g,b} 0-255 each. Returns a new {r,g,b} table.
function PaletteBlend.blendColor(color, blendColor, coeff)
  return {
    r = blendChannel(color.r, blendColor.r, coeff),
    g = blendChannel(color.g, blendColor.g, coeff),
    b = blendChannel(color.b, blendColor.b, coeff),
  }
end

-- Wraps a composited { width, height, getPixel } image (MapCompositor/
-- TitleScreen/ObjectSprite/Font's shared shape) so every opaque pixel is
-- blended toward blendColor by coeff on read -- alpha passes through
-- unchanged (fading a sprite's transparency isn't part of a real palette
-- fade, which only ever touches color channels).
function PaletteBlend.blendImage(image, blendColor, coeff)
  return {
    width = image.width,
    height = image.height,
    getPixel = function(x, y)
      local p = image.getPixel(x, y)
      if p.a == 0 then return p end
      local blended = PaletteBlend.blendColor(p, blendColor, coeff)
      return { r = blended.r, g = blended.g, b = blended.b, a = p.a }
    end,
  }
end

return PaletteBlend
