-- Unit tests (always run) + real-ROM integration test (opt-in via
-- POKEPORT_ROM, skips cleanly otherwise) for import/WaveData.lua.
--
-- Run: lua5.1 tests/wave_data_test.lua
-- Run w/ ROM: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/wave_data_test.lua
package.path = package.path .. ";./?.lua"

local WaveData = require("import.WaveData")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- ---------------------------------------------------------------------
-- Unit tests: hand-encoded WaveData header + samples, no ROM needed.
-- ---------------------------------------------------------------------

local function u32le(n)
  return string.char(
    n % 256,
    math.floor(n / 256) % 256,
    math.floor(n / 65536) % 256,
    math.floor(n / 16777216) % 256
  )
end
local function u16le(n)
  return string.char(n % 256, math.floor(n / 256) % 256)
end

-- Non-looping header: type=0, status=0x0000, freq=10512*1024, loopStart=0,
-- size=4, samples = {0, 64, -1, -128} (as unsigned bytes: 0, 64, 255, 128).
local nonLooping = u16le(0) .. u16le(0x0000) .. u32le(10512 * 1024) .. u32le(0) .. u32le(4)
  .. string.char(0, 64, 255, 128)

local wav1 = WaveData.resolve(nonLooping, 0)
check("type decodes", wav1.type == 0, wav1.type)
check("freq decodes", wav1.freq == 10512 * 1024, wav1.freq)
check("sampleRateHz derives correctly", wav1.sampleRateHz == 10512, wav1.sampleRateHz)
check("size decodes", wav1.size == 4, wav1.size)
check("loopStart decodes", wav1.loopStart == 0, wav1.loopStart)
check("not looping when status high byte has no 0xC0 bits", wav1.looping == false, wav1.looping)
check("raw sample bytes captured", #wav1.samples == 4, #wav1.samples)

local floats1 = WaveData.toFloatSamples(wav1.samples)
check("sample 0 (byte 0) -> 0.0", floats1[1] == 0.0, floats1[1])
check("sample 1 (byte 64) -> 0.5", floats1[2] == 0.5, floats1[2])
check("sample 2 (byte 255, signed -1) -> -1/128", math.abs(floats1[3] - (-1 / 128)) < 1e-9, floats1[3])
check("sample 3 (byte 128, signed -128) -> -1.0", floats1[4] == -1.0, floats1[4])

-- Looping header: status high byte = 0xC0 (both loop bits set).
local looping = u16le(0) .. u16le(0xC000) .. u32le(8000 * 1024) .. u32le(2) .. u32le(4)
  .. string.char(1, 2, 3, 4)
local wav2 = WaveData.resolve(looping, 0)
check("looping when status high byte has 0xC0 bits set", wav2.looping == true, wav2.looping)
check("loopStart decodes on looping sample", wav2.loopStart == 2, wav2.loopStart)

-- Looping header: only bit 0x40 set -- should still count as looping per the
-- real asm's `tst r0, WAVE_DATA_FLAG_LOOP (0xC0)` (any bit in the mask).
local looping2 = u16le(0) .. u16le(0x4000) .. u32le(8000 * 1024) .. u32le(0) .. u32le(1) .. string.char(5)
local wav3 = WaveData.resolve(looping2, 0)
check("looping when only bit 0x40 of status high byte is set", wav3.looping == true, wav3.looping)

-- Offset handling: header not at file start.
local padded = string.rep("\0", 5) .. nonLooping
local wav4 = WaveData.resolve(padded, 5)
check("resolve respects a non-zero base offset", wav4.size == 4 and wav4.freq == 10512 * 1024)

-- ---------------------------------------------------------------------
-- Real-ROM integration test (opt-in).
-- ---------------------------------------------------------------------

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run the ROM integration test")
  print(("%d passed, %d failed"):format(passed, failed))
  os.exit(failed == 0 and 0 or 1)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local CryTable = require("import.CryTable")

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

-- Decode a handful of real cries (by gCryTable index) and sanity-check
-- their WaveData. These are real Pokemon cry ids (table position, not
-- species id -- see pokefirered src/data/pokemon/cry_ids.h), chosen just to
-- get distinct, non-trivial waveform data.
local cryIdsToCheck = { 1, 2, 3, 10, 50 }
local seenWavPtrs = {}

for _, cryId in ipairs(cryIdsToCheck) do
  local tone = CryTable.resolve(data, addrs.gCryTable, cryId)
  local wavOffset = tone.wavPtr - 0x08000000
  check(
    ("cry %d wavPtr looks like a real ROM pointer (0x08xxxxxx)"):format(cryId),
    tone.wavPtr >= 0x08000000 and tone.wavPtr < 0x08000000 + 0x02000000,
    string.format("0x%08x", tone.wavPtr)
  )

  local wav = WaveData.resolve(data, wavOffset)

  check(("cry %d freq is in a sane audible range (1000-100000 Hz raw/1024)"):format(cryId),
    wav.sampleRateHz > 1000 and wav.sampleRateHz < 100000, wav.sampleRateHz)
  check(("cry %d size is a plausible sample count (100-500000)"):format(cryId),
    wav.size > 100 and wav.size < 500000, wav.size)

  -- Cheap "not garbage" check: sample data isn't all one value.
  local allSame = true
  local first = string.byte(wav.samples, 1)
  for i = 2, math.min(#wav.samples, 2000) do
    if string.byte(wav.samples, i) ~= first then
      allSame = false
      break
    end
  end
  check(("cry %d sample data is not degenerate (all one byte value)"):format(cryId), not allSame)

  seenWavPtrs[tone.wavPtr] = (seenWavPtrs[tone.wavPtr] or 0) + 1
end

local distinctCount = 0
for _ in pairs(seenWavPtrs) do
  distinctCount = distinctCount + 1
end
check("checked cries point at multiple distinct WaveData blocks", distinctCount > 1, distinctCount)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
