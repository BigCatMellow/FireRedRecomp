-- Phase 0 shell: boots a window, optionally verifies a ROM if POKEPORT_ROM
-- points at one, and reports status on screen. No cache is written, no
-- gameplay runs. See ../firered-recomp-roadmap.md for what comes next.

local Version = require("src.core.Version")
local RomImporter = require("import.RomImporter")

local statusLines = {}

local function addLine(text)
  table.insert(statusLines, text)
end

function love.load()
  love.window.setTitle(Version.title .. " " .. Version.version)
  addLine(Version.title .. " " .. Version.version)
  addLine("Phase 0: charter + repo scaffold. No gameplay yet.")

  local romPath = os.getenv("POKEPORT_ROM")
  if not romPath then
    addLine("Set POKEPORT_ROM=/path/to/rom.gba to test ROM verification.")
    return
  end

  local ok, info = RomImporter.verify(romPath)
  if ok then
    addLine(("ROM verified: %s v%s"):format(info.name, info.revision))
  else
    addLine("ROM verification failed: " .. tostring(info))
  end
end

function love.draw()
  love.graphics.clear(0.08, 0.08, 0.1)
  local y = 20
  for _, line in ipairs(statusLines) do
    love.graphics.print(line, 20, y)
    y = y + 20
  end
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  end
end
