-- Renders the real Oak intro scene (import/OakSpeechScene.lua) to PNG
-- files so the composite can be checked by eye.
--
-- This exists because the usual Phase 2 "live screenshot" pattern goes
-- through main.lua's view modes, and the Oak-intro task was explicitly
-- scoped to leave main.lua alone (other agents were editing it
-- concurrently). Instead of a LÖVE screenshot this drives exactly the
-- same pure decode+composite pipeline the tests use and writes real 8bpc
-- PNGs with the project's own zero-dependency encoder
-- (tools/pixeldiff/png.lua), which is just as much "by eye" verification
-- and is reproducible without a display server.
--
-- Run from the repo root:
--   POKEPORT_ROM=/path/to/verified/pokefirered.gba \
--     lua5.1 tools/oak_scene_render.lua [outputDir]
--
-- Writes:
--   oak_scene_bg_only.png  -- BG1 backdrop alone (the real banding)
--   oak_scene_no_text.png  -- backdrop + Oak, the frame shown during
--                             Task_OakSpeech_Init's post-fade hold
--   oak_scene_full.png     -- + the dialogue box and the real narration,
--                             i.e. Task_OakSpeech_WelcomeToTheWorld
package.path = package.path .. ";./?.lua"

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local OakSpeechScene = require("import.OakSpeechScene")
local PNG = require("tools.pixeldiff.png")

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("set POKEPORT_ROM=/path/to/verified/pokefirered.gba")
  os.exit(1)
end

local ok, info = RomImporter.verify(romPath)
if not ok then
  print("ROM did not verify -- " .. tostring(info))
  os.exit(1)
end

local addrs = RomAddresses[RomImporter._sha1HexOfFile(romPath)]
local f = assert(io.open(romPath, "rb"))
local data = f:read("*a")
f:close()

local outDir = arg and arg[1] or "."

-- The in-memory composites use alpha in {0,1} (the project's pixel
-- protocol); PNG.encode writes the alpha byte straight out, so it has to
-- be rescaled to 0/255 here or every pixel comes out fully transparent.
local function toRgba8(image)
  return {
    width = image.width,
    height = image.height,
    getPixel = function(x, y)
      local p = image.getPixel(x, y)
      return { r = p.r, g = p.g, b = p.b, a = (p.a ~= 0) and 255 or 0 }
    end,
  }
end

local outputs = {
  { "oak_scene_bg_only.png", function() return OakSpeechScene.compositeBackground(data, addrs) end },
  { "oak_scene_no_text.png", function() return OakSpeechScene.composite(data, addrs, { withText = false }) end },
  { "oak_scene_full.png", function() return OakSpeechScene.composite(data, addrs) end },
}

for _, out in ipairs(outputs) do
  local name, build = out[1], out[2]
  local image = build()
  local path = outDir .. "/" .. name
  local wrote, werr = PNG.encodeToFile(toRgba8(image), path)
  if not wrote then
    print("failed to write " .. path .. " -- " .. tostring(werr))
    os.exit(1)
  end
  print(("wrote %s (%dx%d)"):format(path, image.width, image.height))
end
