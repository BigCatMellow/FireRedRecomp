-- Integration test: renders a synthetic tokenized message (built with
-- Charmap.tokenize on real charmap bytes) through TextRenderer against
-- the real ROM's font glyph data and gTextWindowPalettes, and checks that
-- a mid-string EXT_CTRL_CODE_COLOR switch actually changes the rendered
-- pixel color -- not just that it parses. Opt-in via POKEPORT_ROM, skips
-- cleanly otherwise.
--
-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/text_renderer_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local Charmap = require("import.Charmap")
local TextRenderer = require("import.TextRenderer")
local GbaGraphics = require("import.GbaGraphics")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local ok, info = RomImporter.verify(romPath)
if not ok then
  print("FAIL: ROM did not verify -- " .. tostring(info))
  os.exit(1)
end

local sha1 = RomImporter._sha1HexOfFile(romPath)
local addrs = RomAddresses[sha1]
local f = io.open(romPath, "rb")
local data = f:read("*a")
f:close()

local palette = GbaGraphics.decodePalette(data, addrs.gTextWindowPalettes) -- gTextWindowPalettes[0], the overworld dialogue box's bank

-- "A" (0xBB), then FC 01 04 (COLOR -> TEXT_COLOR_RED), then "A" again.
-- Real charmap bytes, not guessed -- 0xBB is confirmed elsewhere
-- (font_test.lua) to be 'A', and 0x01/0x04 are EXT_CTRL_CODE_COLOR and
-- TEXT_COLOR_RED from characters.h.
local message = string.char(0xBB, 0xFC, 0x01, 0x04, 0xBB, 0xFF)
local tokens = Charmap.tokenize(message)
check("tokenizes to char, color, char", #tokens == 3 and tokens[1].type == "char" and tokens[2].type == "color" and tokens[2].fg == 4 and tokens[3].type == "char")

local img = TextRenderer.renderTokens(data, addrs, tokens, palette)
check("composited width covers both glyphs", img.width > 6)
check("composited height is one glyph row", img.height == 16)

-- Row 7 is the 'A' crossbar (confirmed solid at columns 0-4 in
-- font_test.lua's real 'A' pixel-row assertions) -- opaque foreground on
-- both the pre-color and post-color glyph.
local firstGlyphPixel = img.getPixel(0, 7)
check("first 'A' (before the color switch) renders in the default white", firstGlyphPixel.a == 1 and firstGlyphPixel.r == 255 and firstGlyphPixel.g == 255 and firstGlyphPixel.b == 255, ("r=%d g=%d b=%d"):format(firstGlyphPixel.r, firstGlyphPixel.g, firstGlyphPixel.b))

-- Second 'A' starts at x = widthOf('A') + 1 = 6 + 1 = 7 (confirmed 6px
-- wide in font_test.lua).
local secondGlyphPixel = img.getPixel(7, 7)
check("second 'A' (after the color switch) renders in red", secondGlyphPixel.a == 1 and secondGlyphPixel.r == 230 and secondGlyphPixel.g == 8 and secondGlyphPixel.b == 8, ("r=%d g=%d b=%d"):format(secondGlyphPixel.r, secondGlyphPixel.g, secondGlyphPixel.b))

-- Shadow color is unaffected by an fg-only COLOR code -- both glyphs'
-- shadow pixels (row 11, confirmed shadow-only in font_test.lua) still
-- use the default TEXT_COLOR_LIGHT_GRAY.
local firstShadowPixel = img.getPixel(0, 11)
local secondShadowPixel = img.getPixel(7, 11)
check("shadow color is unaffected by an fg-only color switch", firstShadowPixel.r == 214 and firstShadowPixel.g == 214 and firstShadowPixel.b == 206 and secondShadowPixel.r == 214 and secondShadowPixel.g == 214 and secondShadowPixel.b == 206)

-- Real glyph widths, read directly out of the ROM's own width table
-- (sFontNormalLatinGlyphWidths), the same source TextRenderer itself
-- reads -- so these expected-width computations track real data, not
-- assumed pixel counts.
local function glyphWidth(glyphId)
  return string.byte(data, addrs.sFontNormalLatinGlyphWidths + glyphId + 1)
end
local widthA = glyphWidth(0xBB) -- 'A'

-- EXT_CTRL_CODE_SHIFT_RIGHT (FC 0D <x>): real behavior sets the cursor to
-- an absolute x, not a relative offset -- "A" (advances cursor past x=0),
-- then FC 0D 05 should reposition the next glyph starting exactly at x=5,
-- not appended after the first glyph.
-- Target x=20 is chosen well clear of the first glyph's own cell
-- (width 6) so the check can't accidentally hit the first glyph's pixels
-- instead of the repositioned one.
local shiftRightMsg = string.char(0xBB, 0xFC, 0x0D, 20, 0xBB, 0xFF)
local shiftRightImg = TextRenderer.renderTokens(data, addrs, Charmap.tokenize(shiftRightMsg), palette)
check("SHIFT_RIGHT places the second glyph at the absolute x it names",
  shiftRightImg.getPixel(20, 7).a == 1 and shiftRightImg.getPixel(20, 7).r == 255,
  ("a=%s r=%s"):format(tostring(shiftRightImg.getPixel(20, 7).a), tostring(shiftRightImg.getPixel(20, 7).r)))
check("SHIFT_RIGHT's composited width reflects the repositioned glyph", shiftRightImg.width == 20 + widthA + 1, shiftRightImg.width)

-- EXT_CTRL_CODE_SHIFT_DOWN (FC 0E <y>): same absolute-position behavior,
-- vertically -- second "A" should land on row 32, not row 16 (one
-- GLYPH_ROW_HEIGHT below the first, which is what a plain newline would
-- have done).
-- SHIFT_DOWN only repositions y -- x keeps advancing normally, so the
-- second glyph lands at x = widthA+1 (where the first glyph's advance
-- left the cursor), y = 32 (the shifted-to absolute row).
local shiftDownMsg = string.char(0xBB, 0xFC, 0x0E, 0x20, 0xBB, 0xFF)
local shiftDownImg = TextRenderer.renderTokens(data, addrs, Charmap.tokenize(shiftDownMsg), palette)
check("SHIFT_DOWN places the second glyph at the absolute y it names",
  shiftDownImg.getPixel(widthA + 1, 32 + 7).a == 1 and shiftDownImg.getPixel(widthA + 1, 32 + 7).r == 255)
check("SHIFT_DOWN's composited height covers the repositioned glyph", shiftDownImg.height == 32 + 16)

-- EXT_CTRL_CODE_CLEAR (FC 11 <width>): real ClearTextSpan is an empty
-- function body (src/text_printer.c) -- the code only ever advances the
-- cursor, it never actually clears pixels. Two "A"s with a CLEAR of width
-- 10 between them should render as two solid, untouched glyphs 10px
-- apart, not with a gap punched out of anything.
local clearMsg = string.char(0xBB, 0xFC, 0x11, 0x0A, 0xBB, 0xFF)
local clearImg = TextRenderer.renderTokens(data, addrs, Charmap.tokenize(clearMsg), palette)
check("CLEAR only advances the cursor -- second glyph lands widthA+1+10 over",
  clearImg.getPixel(widthA + 1 + 10, 7).a == 1 and clearImg.getPixel(widthA + 1 + 10, 7).r == 255)
check("CLEAR's composited width accounts for the cursor advance, no pixel clearing", clearImg.width == widthA + 1 + 10 + widthA + 1)

-- EXT_CTRL_CODE_FILL_WINDOW (FC 0F): real code wipes the whole window's
-- pixel buffer. "AB" then FILL_WINDOW then "A" should render as if only
-- the final "A" had ever been printed -- the pre-fill "AB" must be fully
-- discarded, not just visually covered.
local fillMsg = string.char(0xBB, 0xBC, 0xFC, 0x0F, 0xBB, 0xFF)
local fillImg = TextRenderer.renderTokens(data, addrs, Charmap.tokenize(fillMsg), palette)
check("FILL_WINDOW discards everything drawn before it", fillImg.width == widthA + 1, fillImg.width)

-- {PLACEHOLDER} substitution: FD 01 is the real {PLAYER} placeholder
-- subcode (VAR_PLACEHOLDER_NAMES in Charmap.lua). With a substitutions
-- table, it should render the substituted text's real glyphs, not the
-- placeholder name.
local placeholderMsg = string.char(0xFD, 0x01, 0xFF)
local substImg = TextRenderer.renderTokens(data, addrs, Charmap.tokenize(placeholderMsg), palette, { PLAYER = "RED" })
local widthR, widthE, widthD = glyphWidth(0xCC), glyphWidth(0xBF), glyphWidth(0xBE)
check("placeholder with a substitution renders the substituted text's real glyphs",
  substImg.width == (widthR + 1) + (widthE + 1) + (widthD + 1), substImg.width)
check("substituted 'R' renders opaque at the start", substImg.getPixel(0, 7).a == 1)

-- No substitution given: falls back to the real parenthesis glyphs (0x5C/
-- 0x5D) around the raw placeholder name, per this module's documented
-- fallback (curly braces aren't real charmap glyphs).
local noSubstImg = TextRenderer.renderTokens(data, addrs, Charmap.tokenize(placeholderMsg), palette)
local widthParenOpen = glyphWidth(0x5C)
check("placeholder with no substitution falls back to a parenthesized name", noSubstImg.width > widthParenOpen)
local openParenHasInk = false
for x = 0, widthParenOpen - 1 do
  for y = 0, 15 do
    if noSubstImg.getPixel(x, y).a == 1 then openParenHasInk = true end
  end
end
check("fallback opens with a real '(' glyph, not a blank/space", openParenHasInk)

-- Sound cues (EXT_CTRL_CODE_PLAY_SE, FC 10 <2-byte id>): no audio mixer
-- wired into text rendering, so this must not play anything -- instead it
-- calls the caller-supplied onSoundCue hook with the cue's real
-- parameter bytes, letting a future audio-wired caller act on it.
local soundMsg = string.char(0xBB, 0xFC, 0x10, 0x34, 0x12, 0xBB, 0xFF)
local soundCueCalls = {}
local soundImg = TextRenderer.renderTokens(data, addrs, Charmap.tokenize(soundMsg), palette, nil, function(kind, params)
  soundCueCalls[#soundCueCalls + 1] = { kind = kind, params = params }
end)
check("PLAY_SE triggers exactly one onSoundCue call", #soundCueCalls == 1, #soundCueCalls)
check("onSoundCue reports the right kind and raw parameter bytes",
  soundCueCalls[1] and soundCueCalls[1].kind == "play_se" and soundCueCalls[1].params[1] == 0x34 and soundCueCalls[1].params[2] == 0x12)
check("PLAY_SE doesn't itself render as a glyph -- width is just the two 'A's", soundImg.width == 2 * (widthA + 1))

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
