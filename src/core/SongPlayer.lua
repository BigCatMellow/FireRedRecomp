-- Real M4A/Sappy song *playback* -- turns an import/SongEvents.lua decoded
-- event stream (structure only, no timing) into scheduled, multi-track,
-- tick-accurate note-on/note-off events plus the real per-note pitch and
-- volume numbers a mixer needs. Pure Lua: no love.* here at all, so the
-- whole scheduler is unit-testable under plain lua5.1 (same split as
-- src/core/TaskScheduler.lua / src/core/PlayerMovement.lua). Actually
-- turning the emitted events into love.audio.Sources is
-- src/core/AudioPlayer.lua + tools/audio_playground/main.lua.
--
-- Everything below is traced from pokefirered's real engine, not guessed
-- from generic Sappy docs:
--
-- 1. CLOCK / TEMPO (src/m4a_1.s MPlayMain, labels _081DD86C.._081DD9C4).
--    MPlayMain runs once per VBlank. Per frame it does, literally:
--        tempoC += tempoI
--        while tempoC >= 150 do <advance every track one tick>; tempoC -= 150 end
--    (the asm is `r0 = tempoC + tempoI; store; if r0 >= 150 goto trackpass`,
--    and the track pass ends with `tempoC -= 150; store; if >= 150 loop`).
--    tempoI = (tempoD * tempoU) >> 8 (src/m4a.c:1240), tempoU defaults to
--    0x100 and tempoD to 150 (m4a.c:634-637), so with no MPlayTempoControl
--    call tempoI == tempoD, and TEMPO's own `tempoD = arg * 2` (ply_tempo,
--    m4a_1.s ~920) makes tempoD the real BPM. => ticks/frame = bpm/150, i.e.
--    at the default bpm 150 exactly one tick per frame.
--    NOTE for readers of import/SongEvents.lua's header: gClockTable's
--    values are these *engine ticks*, not GBA frames -- the two only
--    coincide at the default tempo. 24 ticks = one quarter note (a 24-tick
--    note at bpm 150 lasts 24/(60*150/150)/59.7 s ~= 0.4 s = 60/150 s, the
--    real quarter-note duration at 150 BPM -- that identity is what
--    ground-truths the whole clock).
--
-- 2. PER-TICK TRACK ADVANCE (MPlayMain _081DD87C.._081DD938). For each
--    track, in this exact order:
--      a. age every sounding channel: `if gateTime ~= 0 then gateTime -= 1;
--         if it just hit 0 then set SOUND_CHANNEL_SF_STOP end` (_081DD892).
--         gateTime == 0 on the way in (a TIE) is skipped by the `beq`, i.e.
--         it never auto-stops -- that is exactly how TIE sustains.
--      b. if track->wait == 0, read and execute command bytes in a loop
--         (_081DD8E0) until one sets wait or ends the track. Notes do NOT
--         set wait, so consecutive notes fire on the same tick; only a
--         rest (0x80-0xB0) sets wait = gClockTable[cmd - 0x80].
--      c. `wait -= 1` (_081DD938) -- the tick that read the rest consumes
--         one of its ticks, so a rest of N spans exactly N ticks.
--    Because note-offs (a) run before commands (b), a note ending on tick T
--    is released before anything started on tick T -- this module emits
--    noteOff events before noteOn events within a tick for that reason.
--
-- 3. FINE / end of track (ply_fine, m4a_1.s): every still-sounding channel
--    of the track gets SF_STOP. So this module emits a noteOff for every
--    note still held when a track terminates.
--    EOT/ply_endtie (m4a_1.s ~1818): optional key arg, else the track's
--    current key; releases the matching held note.
--
-- 4. PITCH -- DirectSound (MidiKeyToFreq, src/m4a.c:23). Real formula,
--    reimplemented exactly here including the 64-bit `umul3232H32` high
--    multiply (done in 16-bit halves so it stays inside a double's exact
--    integer range and needs no bit library):
--        val1 = gFreqTable[gScaleTable[key] & 0xF] >> (gScaleTable[key] >> 4)
--        val2 = same for key + 1
--        freq = umul3232H32(wav->freq, val1 + umul3232H32(val2-val1, fineAdjust << 24))
--    gScaleTable/gFreqTable are the real src/m4a_tables.c tables, copied
--    verbatim below. For key 60 the multiply collapses to wav->freq / 1024
--    (gScaleTable[60] = 0x90 -> gFreqTable[0] >> 9 = 2^32/1024), i.e. the
--    result is a plain integer sample rate in Hz and key 60 is exactly the
--    sample's own recorded pitch -- which is also what makes
--    WaveData.sampleRateHz (freq/1024) the "unshifted" rate. Every semitone
--    is the table's 2^(1/12). See SongPlayer.pitchRatio().
--    `key` here is the note key plus the track's keyM, and `fineAdjust` is
--    the low byte of pitM, both from TrkVolPitSet (src/m4a.c:765):
--        x = (tune + bend*bendRange)*4 + (keyShift<<8) + (keyShiftX<<8) + pitX
--        keyM = x >> 8 ; pitM = x
--
-- 5. PITCH -- CGB square (MidiKeyToCgbFreq, src/m4a.c:810). Same shape with
--    gCgbScaleTable/gCgbFreqTable, base key 36, returning `val + 2048`,
--    which is the GBA sound register's own 11-bit rate field; real hardware
--    frequency is 131072 / (2048 - reg) Hz, so Hz = 131072 / -val. Verified:
--    key 36 -> gCgbFreqTable[0] = -2004 -> 65.4 Hz = C2.
--
-- 6. VOLUME (TrkVolPitSet, src/m4a.c:765, + ChnVolSetAsm, m4a_1.s:1508):
--        x     = (vol * volX) >> 5
--        y     = clamp(2*pan + panX, -128, 127)
--        volMR = ((y + 128) * x) >> 8 ; volML = ((127 - y) * x) >> 8
--        right = min(255, (volMR * ((0x80 + rhythmPan) * velocity)) >> 14)
--        left  = min(255, (volML * ((0x7F - rhythmPan) * velocity)) >> 14)
--    volX defaults to 0x40 and bendRange to 2 (the MPT_FLG_START init block,
--    m4a_1.s _081DD8BA); everything else starts zeroed (Clear64byte).
--
-- Deliberately NOT modelled (documented gaps, same house style as
-- import/WaveData.lua / src/core/AudioPlayer.lua -- these are simplifications,
-- not silent omissions):
--   * ADSR envelopes. ToneData's attack/decay/sustain/release are carried
--     through on the emitted event but no envelope shaping is applied --
--     notes are flat-volume for their whole gate time. (Same call this
--     project already made for cries in AudioPlayer.lua.)
--   * LFO / vibrato (MOD/MODT/LFOS/LFODL). modM stays 0, so MOD commands are
--     parsed and stored but produce no pitch/volume wobble.
--   * Pseudo-echo (XCMD xiecv/xiecl), reverb, and the master
--     MPlayVolumeControl volume (tempoU/volume scaling) -- tempoU is fixed
--     at 0x100.
--   * Channel allocation/priority. The real engine has a fixed pool of
--     DirectSound + 4 CGB hardware channels and steals the lowest-priority
--     one when it runs out; this module lets every track sound
--     simultaneously with no stealing. Real FireRed songs are authored
--     within the hardware limit, so this only diverges on pathological data.
--   * PATT/PEND/REPT/MEMACC/PORT and GOTO loops -- import/SongEvents.lua
--     stops decoding at those (see its header), so a track here just ends
--     with the matching `stopReason`. That means looping BGM plays once
--     through to its GOTO and stops.
--
-- Verified against real ROM data: MUS_LEVEL_UP (songs.h id 257) -- see
-- tests/song_player_test.lua for the ROM-integration asserts and
-- tests/song_player_unit_test.lua for the pure-math/scheduling ones.

local SongPlayer = {}
SongPlayer.__index = SongPlayer

-- Real GBA VBlank rate (16.78 MHz / 280896 cycles per frame). MPlayMain is
-- driven off VBlank, so this is what converts ticks to wall-clock seconds.
SongPlayer.FRAMES_PER_SECOND = 59.7275

-- Real src/m4a.c:634-637 defaults (MPlayStart).
SongPlayer.DEFAULT_TEMPO_D = 150
SongPlayer.DEFAULT_TEMPO_U = 0x100
SongPlayer.TEMPO_TICK_THRESHOLD = 150

-- Real MPT_FLG_START track init (m4a_1.s _081DD8BA): Clear64byte zeroes the
-- track, then only these get non-zero defaults.
SongPlayer.DEFAULT_VOL_X = 0x40
SongPlayer.DEFAULT_BEND_RANGE = 2

-- Runaway guard: a correctly decoded non-looping song is short; blowing
-- past this means the input data is not what we think it is.
SongPlayer.MAX_TICKS = 100000

-- Real gScaleTable (src/m4a_tables.c:67), 0-based index = MIDI key.
local SCALE_TABLE = {
  [0] =
  0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB,
  0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xDB,
  0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xCB,
  0xB0, 0xB1, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xBB,
  0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xAB,
  0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9B,
  0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x8B,
  0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x7B,
  0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B,
  0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x5B,
  0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B,
  0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B,
  0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B,
  0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B,
  0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B,
}

-- Real gFreqTable (src/m4a_tables.c:86): 2^32 * 2^(n/12), n = 0..11.
local FREQ_TABLE = {
  [0] =
  2147483648, 2275179671, 2410468894, 2553802834,
  2705659852, 2866546760, 3037000500, 3217589947,
  3408917802, 3611622603, 3826380858, 4053909305,
}

-- Real gCgbScaleTable (src/m4a_tables.c:118), 0-based index = key - 36.
local CGB_SCALE_TABLE = {
  [0] =
  0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B,
  0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B,
  0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B,
  0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B,
  0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B,
  0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x5B,
  0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B,
  0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x7B,
  0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x8B,
  0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9B,
  0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xAB,
}

-- Real gCgbFreqTable (src/m4a_tables.c:133), s16.
local CGB_FREQ_TABLE = {
  [0] =
  -2004, -1891, -1785, -1685, -1591, -1501,
  -1417, -1337, -1262, -1192, -1125, -1062,
}

SongPlayer.SCALE_TABLE = SCALE_TABLE
SongPlayer.FREQ_TABLE = FREQ_TABLE
SongPlayer.CGB_SCALE_TABLE = CGB_SCALE_TABLE
SongPlayer.CGB_FREQ_TABLE = CGB_FREQ_TABLE

-- Real GBA CGB square channel timing: the 11-bit rate register R gives
-- 131072 / (2048 - R) Hz.
SongPlayer.CGB_CLOCK_HZ = 131072

local floor = math.floor

-- Real ARM `umul3232H32(a, b)` -- the high 32 bits of the unsigned 64-bit
-- product. Both args are u32. Done in 16-bit halves so every intermediate
-- stays a whole number below 2^53 (exact in a Lua double) and no bit
-- library / Lua 5.3 operator is needed.
local function umulH32(a, b)
  local bh = floor(b / 65536)
  local bl = b % 65536
  local hi = a * bh              -- < 2^48
  local lo = a * bl              -- < 2^48
  local q = floor(hi / 65536)
  local r = hi % 65536
  return q + floor((r * 65536 + lo) / 4294967296)
end
SongPlayer.umulH32 = umulH32

-- One gScaleTable/gFreqTable lookup: the u32 pitch factor for a key.
local function scaleFactor(key)
  local s = SCALE_TABLE[key]
  return floor(FREQ_TABLE[s % 16] / (2 ^ floor(s / 16)))
end

-- Real MidiKeyToFreq (src/m4a.c:23). wavFreq is a decoded WaveData.freq
-- (1024ths fixed point); key is the note key already including the track's
-- keyM; fineAdjust is the low byte of pitM (0-255, defaults to 0).
-- Returns the sounding sample rate in whole Hz (see header point 4): for
-- key 60 that is exactly wavFreq / 1024 == WaveData.sampleRateHz.
function SongPlayer.midiKeyToFreq(wavFreq, key, fineAdjust)
  fineAdjust = fineAdjust or 0
  local fineShifted = fineAdjust * 16777216 -- fineAdjust << 24
  if key > 178 then
    key = 178
    fineShifted = 255 * 16777216
  end
  if key < 0 then key = 0 end
  local val1 = scaleFactor(key)
  local val2 = scaleFactor(key + 1)
  return umulH32(wavFreq, val1 + umulH32(val2 - val1, fineShifted))
end

-- Playback-rate ratio for a DirectSound sample: how much faster/slower than
-- its recorded pitch this key sounds. This is exactly what a resampler (or
-- love's Source:setPitch) wants. Key 60 == 1.0 by construction (see header).
-- The real engine's Hz result is a truncated integer, so ratios inherit up
-- to ~1 Hz of rounding -- inaudible, and it is what the hardware does.
function SongPlayer.pitchRatio(wavFreq, key, fineAdjust)
  return SongPlayer.midiKeyToFreq(wavFreq, key, fineAdjust) / (wavFreq / 1024)
end

-- Real MidiKeyToCgbFreq (src/m4a.c:810) for the square channels (chanNum
-- 1/2). Returns the raw GBA rate register value the real engine writes.
-- Noise (chanNum 4, gNoiseTable) and the wave channel are not handled here
-- (see the header's gap list).
function SongPlayer.midiKeyToCgbFreq(key, fineAdjust)
  fineAdjust = fineAdjust or 0
  if key <= 35 then
    fineAdjust = 0
    key = 0
  else
    key = key - 36
    if key > 130 then
      key = 130
      fineAdjust = 255
    end
  end
  local function cgbFactor(k)
    local s = CGB_SCALE_TABLE[k]
    -- Arithmetic shift of a negative s16, as GCC compiles `>>` here.
    return floor(CGB_FREQ_TABLE[s % 16] / (2 ^ floor(s / 16)))
  end
  local val1 = cgbFactor(key)
  local val2 = cgbFactor(key + 1)
  return val1 + floor(fineAdjust * (val2 - val1) / 256) + 2048
end

-- Hz for a CGB square note: the register value above run back through the
-- real hardware relation 131072 / (2048 - R).
function SongPlayer.cgbFreqHz(key, fineAdjust)
  local reg = SongPlayer.midiKeyToCgbFreq(key, fineAdjust)
  local divisor = 2048 - reg
  if divisor <= 0 then return nil end
  return SongPlayer.CGB_CLOCK_HZ / divisor
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- Real TrkVolPitSet volume half (src/m4a.c:765). Returns volML, volMR.
function SongPlayer.trackVolumes(vol, volX, pan, panX)
  local x = floor(vol * volX / 32)
  local y = clamp(2 * pan + (panX or 0), -128, 127)
  local volMR = floor((y + 128) * x / 256)
  local volML = floor((127 - y) * x / 256)
  return volML, volMR
end

-- Real ChnVolSetAsm (src/m4a_1.s:1508). Returns left, right (0-255 each).
function SongPlayer.channelVolumes(volML, volMR, velocity, rhythmPan)
  rhythmPan = rhythmPan or 0
  local right = floor(volMR * ((0x80 + rhythmPan) * velocity) / 16384)
  local left = floor(volML * ((0x7F - rhythmPan) * velocity) / 16384)
  return clamp(left, 0, 255), clamp(right, 0, 255)
end

-- Real TrkVolPitSet pitch half (src/m4a.c:765). Returns keyM, pitM's low
-- byte (the fineAdjust the MidiKeyTo*Freq functions take).
function SongPlayer.trackPitch(t)
  local x = (t.tune + t.bend * t.bendRange) * 4
    + t.keyShift * 256
    + t.keyShiftX * 256
    + t.pitX
  local keyM = floor(x / 256)
  local pitM = x % 256
  return keyM, pitM
end

local function newTrackState(events)
  return {
    events = events,
    index = 1,
    wait = 0,
    finished = false,
    stopReason = nil,
    -- Real MusicPlayerTrack fields (Clear64byte zeroes, then these two).
    volX = SongPlayer.DEFAULT_VOL_X,
    bendRange = SongPlayer.DEFAULT_BEND_RANGE,
    vol = 0,
    pan = 0,
    panX = 0,
    bend = 0,
    tune = 0,
    keyShift = 0,
    keyShiftX = 0,
    pitX = 0,
    modT = 0,
    priority = 0,
    voice = 0,
    key = 0,
    velocity = 0,
    gateTime = 0,
    active = {}, -- currently sounding notes (see startNote below)
  }
end

-- song: an import/SongEvents.lua decodeSong() result (or any table with
-- .tracks = { { events = {...} }, ... }).
function SongPlayer.new(song)
  local self = setmetatable({}, SongPlayer)
  self.song = song
  self.tempoD = SongPlayer.DEFAULT_TEMPO_D
  self.tempoU = SongPlayer.DEFAULT_TEMPO_U
  self.tempoI = SongPlayer.DEFAULT_TEMPO_D
  self.tempoC = 0
  self.tick = 0
  self.frame = 0
  self.nextNoteId = 1
  self.tracks = {}
  for i, track in ipairs(song.tracks or {}) do
    self.tracks[i] = newTrackState(track.events)
  end
  return self
end

function SongPlayer:isFinished()
  for _, t in ipairs(self.tracks) do
    if not t.finished then return false end
  end
  return true
end

-- Wall-clock seconds per engine tick at the current tempo. ticks/frame is
-- tempoI/150 and frames/second is the GBA VBlank rate (see header).
function SongPlayer:secondsPerTick()
  return SongPlayer.TEMPO_TICK_THRESHOLD
    / (self.tempoI * SongPlayer.FRAMES_PER_SECOND)
end

function SongPlayer:seconds()
  return self.frame / SongPlayer.FRAMES_PER_SECOND
end

local function emit(out, ev)
  out[#out + 1] = ev
end

local function stopNote(self, trackIndex, t, note, out, reason)
  note.stopped = true
  emit(out, {
    type = "noteOff",
    track = trackIndex,
    tick = self.tick,
    frame = self.frame,
    noteId = note.id,
    key = note.key,
    reason = reason,
  })
end

local function reapStopped(t)
  local kept = {}
  for _, n in ipairs(t.active) do
    if not n.stopped then kept[#kept + 1] = n end
  end
  t.active = kept
end

local function startNote(self, trackIndex, t, out)
  local keyM, fineAdjust = SongPlayer.trackPitch(t)
  local effectiveKey = t.key + keyM
  if effectiveKey < 0 then effectiveKey = 0 end -- real `bpl` clamp in ply_note
  local volML, volMR = SongPlayer.trackVolumes(t.vol, t.volX, t.pan, t.panX)
  local left, right = SongPlayer.channelVolumes(volML, volMR, t.velocity, 0)

  local note = {
    id = self.nextNoteId,
    key = t.key,
    gateTime = t.gateTime,
  }
  self.nextNoteId = self.nextNoteId + 1
  t.active[#t.active + 1] = note

  emit(out, {
    type = "noteOn",
    track = trackIndex,
    tick = self.tick,
    frame = self.frame,
    noteId = note.id,
    voice = t.voice,
    key = t.key,
    effectiveKey = effectiveKey,
    fineAdjust = fineAdjust,
    velocity = t.velocity,
    gateTime = t.gateTime,
    tie = t.gateTime == 0,
    volumeLeft = left,
    volumeRight = right,
    pan = t.pan,
  })
end

-- Applies one decoded control event to the track/player state.
local function applyControl(self, t, e)
  local name = e.name
  if name == "tempo" then
    -- ply_tempo (m4a_1.s ~920): tempoD = arg*2; tempoI = tempoD*tempoU >> 8.
    self.tempoD = e.value * 2
    self.tempoI = floor(self.tempoD * self.tempoU / 256)
  elseif name == "voice" then
    t.voice = e.value
  elseif name == "vol" then
    t.vol = e.value
  elseif name == "pan" then
    t.pan = e.signedValue or (e.value - 0x40)
  elseif name == "bend" then
    t.bend = e.signedValue or (e.value - 0x40)
  elseif name == "bendr" then
    t.bendRange = e.value
  elseif name == "tune" then
    t.tune = e.signedValue or (e.value - 0x40)
  elseif name == "keysh" then
    -- ply_keysh stores the raw byte as a signed keyShift.
    t.keyShift = e.value < 128 and e.value or (e.value - 256)
  elseif name == "prio" then
    t.priority = e.value
  elseif name == "modt" then
    t.modT = e.value
  end
  -- mod/lfos/lfodl and the XCMD sub-ops (xiecv/xiecl/xatta/...) are parsed
  -- by import/SongEvents.lua but intentionally have no effect here -- see
  -- the module header's gap list (no LFO, no ADSR, no pseudo-echo).
end

-- Advances every track by exactly one engine tick, mirroring MPlayMain's
-- per-track order (age channels -> run commands -> decrement wait).
-- Returns a list of emitted noteOn/noteOff events (noteOffs first).
function SongPlayer:step()
  local out = {}
  self.tick = self.tick + 1

  for i, t in ipairs(self.tracks) do
    -- (a) age sounding notes. gateTime == 0 (TIE) never auto-releases.
    for _, note in ipairs(t.active) do
      if not note.stopped and note.gateTime ~= 0 then
        note.gateTime = note.gateTime - 1
        if note.gateTime == 0 then
          stopNote(self, i, t, note, out, "gateTime")
        end
      end
    end
    reapStopped(t)

    if not t.finished then
      -- (b) run commands while wait == 0.
      while t.wait == 0 and not t.finished do
        local e = t.events[t.index]
        if not e then
          t.finished = true
          t.stopReason = "ranOutOfEvents"
          break
        end
        t.index = t.index + 1

        if e.type == "note" then
          if e.key then t.key = e.key end
          if e.velocity then t.velocity = e.velocity end
          t.gateTime = e.gateTime
          startNote(self, i, t, out)
        elseif e.type == "rest" then
          t.wait = e.duration
        elseif e.type == "endtie" then
          local key = e.key or t.key
          for _, note in ipairs(t.active) do
            if not note.stopped and note.key == key then
              stopNote(self, i, t, note, out, "endtie")
            end
          end
          reapStopped(t)
        elseif e.type == "control" then
          applyControl(self, t, e)
        else
          -- end / goto / unimplemented / truncated: ply_fine semantics --
          -- the track stops and all its sounding notes are released.
          t.finished = true
          t.stopReason = e.type
          for _, note in ipairs(t.active) do
            if not note.stopped then
              stopNote(self, i, t, note, out, "trackEnd")
            end
          end
          reapStopped(t)
        end
      end

      -- (c) consume one tick of the pending wait.
      if t.wait > 0 then
        t.wait = t.wait - 1
      end
    end
  end

  return out
end

-- One VBlank frame of the real engine: tempoC += tempoI, then one track
-- pass per whole 150 of accumulated tempoC (MPlayMain, see header).
-- Returns the concatenated events of every tick run this frame.
function SongPlayer:updateFrame()
  local out = {}
  self.frame = self.frame + 1
  self.tempoC = self.tempoC + self.tempoI
  while self.tempoC >= SongPlayer.TEMPO_TICK_THRESHOLD do
    local events = self:step()
    for _, ev in ipairs(events) do out[#out + 1] = ev end
    self.tempoC = self.tempoC - SongPlayer.TEMPO_TICK_THRESHOLD
  end
  return out
end

-- Real-time driver for a variable-dt host (love.update). Accumulates
-- fractional GBA frames and runs whole ones. Returns this call's events.
function SongPlayer:update(dt)
  local out = {}
  self.frameAccumulator = (self.frameAccumulator or 0)
    + dt * SongPlayer.FRAMES_PER_SECOND
  while self.frameAccumulator >= 1 do
    self.frameAccumulator = self.frameAccumulator - 1
    local events = self:updateFrame()
    for _, ev in ipairs(events) do out[#out + 1] = ev end
  end
  return out
end

-- Runs the whole song offline and returns the complete event timeline --
-- the form the tests assert against and the playground pre-renders for a
-- clock-driven playback. Every event carries .tick/.frame; .seconds is
-- filled in here from the real VBlank rate.
-- Returns { events = {...}, ticks = n, frames = n, seconds = n }.
function SongPlayer:renderTimeline(maxTicks)
  maxTicks = maxTicks or SongPlayer.MAX_TICKS
  local events = {}
  while not self:isFinished() and self.tick < maxTicks do
    local frameEvents = self:updateFrame()
    for _, ev in ipairs(frameEvents) do
      ev.seconds = ev.frame / SongPlayer.FRAMES_PER_SECOND
      events[#events + 1] = ev
    end
  end
  return {
    events = events,
    ticks = self.tick,
    frames = self.frame,
    seconds = self:seconds(),
    hitTickCap = self.tick >= maxTicks,
  }
end

return SongPlayer
