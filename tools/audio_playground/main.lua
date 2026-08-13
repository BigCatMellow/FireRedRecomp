-- Manual verification tool for real GBA cry playback. Standalone LOVE2D
-- project (own conf.lua/main.lua) -- does NOT touch the real project's
-- main.lua or import/TitleScreen.lua. Run from the firered-recomp repo
-- root with:
--   love tools/audio_playground
-- optionally with POKEPORT_ROM=/path/to/verified/pokefirered.gba set;
-- otherwise falls back to the known verified-ROM path below.
--
-- On load: verifies the ROM (import/RomImporter.lua), decodes a handful of
-- real cries via import/CryTable.lua + import/WaveData.lua, and decodes one
-- real SONG (MUS_LEVEL_UP) via import/SongTable.lua + import/SongEvents.lua.
--   * number keys 1-5: build (import/WaveData -> src/core/AudioPlayer) and
--     play a single cry sample via love.audio.
--   * S: play the whole song -- src/core/SongPlayer.lua schedules its notes
--     on the real M4A tick clock and src/core/SongAudio.lua turns each
--     scheduled note into a pitched love.audio.Source. X stops it.
-- The on-screen readout (tick / elapsed / live Sources / notes started+
-- stopped) is the introspection that makes playback checkable without
-- hearing it; tests/song_audio_test.lua asserts the same numbers headlessly.
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
local SongTable = require("import.SongTable")
local SongEvents = require("import.SongEvents")
local AudioPlayer = require("src.core.AudioPlayer")
local SongPlayer = require("src.core.SongPlayer")
local SongAudio = require("src.core.SongAudio")

local DEFAULT_ROM_PATH =
  "/home/mellow/Documents/Projects/Pokemon ReComp/FireRed/pokefirered-master/pokefirered.gba"

local CRY_IDS = { 1, 2, 3, 10, 50 }

-- MUS_LEVEL_UP (include/constants/songs.h id 257): a short 5-track fanfare
-- that uses both synthesis paths -- three DirectSound (PCM) tracks and two
-- CGB square tracks. See src/core/SongPlayer.lua's header.
local SONG_ID = 257
local SONG_NAME = "MUS_LEVEL_UP"

local state = {
  status = "loading...",
  entries = {}, -- { cryId=, wav=, source=, meta=, label= }
  romData = nil,
  song = nil,      -- decoded SongEvents.decodeSong() result
  songLabel = "song: not loaded",
  player = nil,    -- live SongPlayer while the song is playing
  audio = nil,     -- live SongAudio
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

  state.romData = data

  local okSong, songErr = pcall(function()
    local entry = SongTable.resolve(data, addrs.gSongTable, SONG_ID)
    state.song = SongEvents.decodeSong(data, entry.headerPtr)
    local notes = 0
    for _, track in ipairs(state.song.tracks) do
      for _, e in ipairs(track.events) do
        if e.type == "note" then notes = notes + 1 end
      end
    end
    local preview = SongPlayer.new(state.song):renderTimeline()
    state.songLabel = ("song %s: %d tracks, %d notes, %d ticks, %.2f s")
      :format(SONG_NAME, state.song.trackCount, notes, preview.ticks, preview.seconds)
  end)
  if not okSong then
    state.songLabel = "song: decode ERROR -- " .. tostring(songErr)
  end

  state.status = ("ROM verified: %s. Press 1-%d for a cry, S for the song, X to stop.")
    :format(info.name, #CRY_IDS)
end

local function stopSong()
  if state.audio then state.audio:stopAll() end
  state.player, state.audio = nil, nil
end

local function playSong()
  if not state.song then return end
  stopSong()
  state.player = SongPlayer.new(state.song)
  state.audio = SongAudio.new({ romData = state.romData, tonePtr = state.song.tonePtr })
end

function love.update(dt)
  if not state.player then return end
  -- SongPlayer advances the real M4A tick clock off dt (GBA VBlank rate)
  -- and returns this frame's noteOn/noteOff events; SongAudio turns them
  -- into Sources. This is the whole playback loop.
  state.audio:handle(state.player:update(dt))
  if state.player:isFinished() and state.audio:activeCount() == 0 then
    stopSong()
  end
end

function love.keypressed(key)
  local n = tonumber(key)
  if n and state.entries[n] and state.entries[n].source then
    state.entries[n].source:stop()
    state.entries[n].source:play()
  elseif key == "s" then
    playSong()
  elseif key == "x" then
    stopSong()
  end
end

function love.draw()
  love.graphics.print(state.status, 10, 10)
  for i, entry in ipairs(state.entries) do
    love.graphics.print(("[%d] %s"):format(i, entry.label), 10, 10 + i * 18)
  end

  local y = 10 + (#state.entries + 2) * 18
  love.graphics.print("[S] " .. state.songLabel, 10, y)
  if state.player then
    love.graphics.print(
      ("     playing: tick %d, frame %d, %.2f s, %d live Sources (%d started / %d stopped)")
        :format(state.player.tick, state.player.frame, state.player:seconds(),
          state.audio:activeCount(), state.audio.started, state.audio.stopped),
      10, y + 18)
  end
end
