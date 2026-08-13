-- Manual verification tool for real GBA cry playback. Standalone LOVE2D
-- project (own conf.lua/main.lua) -- does NOT touch the real project's
-- main.lua or import/TitleScreen.lua. Run from the firered-recomp repo
-- root with:
--   love tools/audio_playground
-- optionally with POKEPORT_ROM=/path/to/verified/pokefirered.gba set;
-- otherwise falls back to the known verified-ROM path below.
--
-- On load: verifies the ROM (import/RomImporter.lua), decodes a handful of
-- real cries via import/CryTable.lua + import/WaveData.lua. Press number
-- keys 1-5 to build (import/WaveData -> src/core/AudioPlayer) and play each
-- one via love.audio.
--
-- One-line wiring snippet for whoever owns main.lua, if this gets folded
-- into the real game later (do NOT apply this here -- main.lua is off
-- limits for this task):
--   local AudioPlayer = require("src.core.AudioPlayer")
--   local WaveData = require("import.WaveData")
--   local tone = CryTable.resolve(romData, addrs.gCryTable, cryId)
--   local wav = WaveData.resolve(romData, tone.wavPtr - 0x08000000)
--   local source = AudioPlayer.build(wav)
--   source:play()

-- Reach the real project's import/ and src/core/ modules two levels up
-- (tools/audio_playground/ -> repo root).
package.path = package.path .. ";../../?.lua"

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local CryTable = require("import.CryTable")
local WaveData = require("import.WaveData")
local AudioPlayer = require("src.core.AudioPlayer")

local DEFAULT_ROM_PATH =
  "/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba"

local CRY_IDS = { 1, 2, 3, 10, 50 }

local state = {
  status = "loading...",
  entries = {}, -- { cryId=, wav=, source=, meta=, label= }
}

local function loadRomData(path)
  local file, err = io.open(path, "rb")
  if not file then
    return nil, "could not open ROM: " .. tostring(err)
  end
  local data = file:read("*a")
  file:close()
  return data
end

function love.load()
  local romPath = os.getenv("POKEPORT_ROM") or DEFAULT_ROM_PATH

  local ok, info = RomImporter.verify(romPath)
  if not ok then
    state.status = "ROM verify FAILED: " .. tostring(info)
    return
  end

  local data, err = loadRomData(romPath)
  if not data then
    state.status = err
    return
  end

  local sha1 = RomImporter._sha1HexOfFile(romPath)
  local addrs = RomAddresses[sha1]

  for i, cryId in ipairs(CRY_IDS) do
    local okDecode, result = pcall(function()
      local tone = CryTable.resolve(data, addrs.gCryTable, cryId)
      if AudioPlayer.isCgbTone(tone.type) then
        return { cryId = cryId, label = ("cry %d: CGB tone, unsupported, skipped"):format(cryId) }
      end
      local wav = WaveData.resolve(data, tone.wavPtr - 0x08000000)
      local source, meta = AudioPlayer.build(wav)
      return {
        cryId = cryId,
        wav = wav,
        source = source,
        meta = meta,
        label = ("cry %d: %d Hz, %d samples, looping=%s"):format(
          cryId, math.floor(wav.sampleRateHz + 0.5), wav.size, tostring(wav.looping)
        ),
      }
    end)

    if okDecode then
      state.entries[i] = result
    else
      state.entries[i] = { cryId = cryId, label = ("cry %d: ERROR -- %s"):format(cryId, tostring(result)) }
    end
  end

  state.status = ("ROM verified: %s. Press 1-%d to play a cry."):format(info.name, #CRY_IDS)
end

function love.keypressed(key)
  local n = tonumber(key)
  if n and state.entries[n] and state.entries[n].source then
    state.entries[n].source:stop()
    state.entries[n].source:play()
  end
end

function love.draw()
  love.graphics.print(state.status, 10, 10)
  for i, entry in ipairs(state.entries) do
    love.graphics.print(("[%d] %s"):format(i, entry.label), 10, 10 + i * 18)
  end
end
