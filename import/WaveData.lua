-- Decodes a real `struct WaveData` (pokefirered include/gba/m4a_internal.h)
-- -- the m4a/Sappy sound engine's raw PCM sample header. This is what a
-- ToneData.wav pointer (see import/CryTable.lua) points at: a 16-byte
-- header followed immediately by signed 8-bit PCM sample data. This module
-- decodes the header + samples; actually playing it back is
-- src/core/AudioPlayer.lua (needs love.sound, not testable in plain lua5.1).
--
-- Struct layout (16-byte header, C struct from m4a_internal.h):
--   0x00 type        u16 LE  (low half of what some docs call "status";
--                             GBA Sappy tools usually show type+status as
--                             one u32, but the C struct here splits it into
--                             two named u16 fields, so we follow the C
--                             struct exactly)
--   0x02 status      u16 LE  (high byte is a flags byte tested against
--                             WAVE_DATA_FLAG_LOOP -- see below)
--   0x04 freq         u32 LE  (fixed-point 1024ths; real Hz = freq / 1024)
--   0x08 loopStart   u32 LE  (sample index where playback resumes on loop)
--   0x0C size          u32 LE  (sample count, NOT byte count -- 8-bit PCM so
--                              they're equal here, but keep the field named
--                              per the real struct)
--   0x10 data[size]   s8[]    (signed 8-bit PCM, `size` bytes)
--
-- Loop-flag derivation (NOT guessed -- traced from real ARM asm):
-- pokefirered's constants/m4a_constants.inc defines the WaveData struct's
-- assembly field offsets as o_WaveData_type(2 bytes), o_WaveData_d1(1),
-- o_WaveData_flags(1) -- i.e. the C `status` u16 is really two bytes: a low
-- byte ("d1", unused by the loop check) and a high byte ("flags"). src/m4a_1.s
-- line ~197 does `ldrb r2, [r3, o_WaveData_flags]; movs r0, WAVE_DATA_FLAG_LOOP
-- (0xC0); tst r0, r2` -- i.e. looping is enabled iff the HIGH BYTE of the
-- `status` u16 field, ANDed with 0xC0, is nonzero. That's status bits 0x4000
-- or 0x8000 in the full u16. See WaveData.isLooping() below.
--
-- Verified against real ROM data (2026-08-12, ROM sha1
-- 41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc): decoding gCryTable entry 1's
-- wavPtr gives type=32 [sic -- ToneData.type, not WaveData], and the
-- WaveData itself decodes to freq=10764288 (-> 10512 Hz, one of the GBA's
-- standard Sappy sample rates, SOUND_MODE_FREQ_10512 in m4a_internal.h),
-- size=8187 samples, and non-degenerate (not all-same-byte) sample data --
-- consistent with real cry waveform data, not garbage. See
-- tests/wave_data_test.lua for the automated check across several cries.

local WaveData = {}

local byte = string.byte

local function u16le(data, offset0based)
  return byte(data, offset0based + 1) + byte(data, offset0based + 2) * 256
end

local function u32le(data, offset0based)
  return byte(data, offset0based + 1)
    + byte(data, offset0based + 2) * 256
    + byte(data, offset0based + 3) * 65536
    + byte(data, offset0based + 4) * 16777216
end

WaveData.HEADER_SIZE = 0x10
WaveData.WAVE_DATA_FLAG_LOOP = 0xC0 -- mask tested against the status high byte

-- data: full ROM bytes. offset0based: 0-based file offset of the WaveData
-- header (a wavPtr from CryTable/SongTable minus 0x08000000).
function WaveData.resolve(data, offset0based)
  local statusRaw = u16le(data, offset0based + 0x02)
  local statusHighByte = math.floor(statusRaw / 256) % 256

  local wav = {
    type = u16le(data, offset0based + 0x00),
    status = statusRaw,
    freq = u32le(data, offset0based + 0x04),
    loopStart = u32le(data, offset0based + 0x08),
    size = u32le(data, offset0based + 0x0C),
  }
  wav.sampleRateHz = wav.freq / 1024
  -- Pure-arithmetic bit test (no `bit` lib): (statusHighByte & 0xC0) ~= 0,
  -- i.e. either of the top two bits of the high byte is set.
  wav.looping = math.floor(statusHighByte / 64) % 4 ~= 0

  wav.samplesOffset = offset0based + WaveData.HEADER_SIZE
  wav.samples = data:sub(wav.samplesOffset + 1, wav.samplesOffset + wav.size)

  return wav
end

-- Converts the raw signed-8-bit sample string into a plain Lua array of
-- normalized floats in [-1.0, 1.0). Kept separate from resolve() so callers
-- that only need header fields (freq/size/looping) don't pay for this, and
-- so this pure-math step is unit-testable without any ROM data at all (see
-- tests/wave_data_test.lua).
function WaveData.toFloatSamples(samplesString)
  local out = {}
  local n = #samplesString
  for i = 1, n do
    local b = byte(samplesString, i)
    -- Signed 8-bit: 0..127 -> 0..127, 128..255 -> -128..-1.
    local signed = b >= 128 and (b - 256) or b
    out[i] = signed / 128.0
  end
  return out
end

return WaveData
