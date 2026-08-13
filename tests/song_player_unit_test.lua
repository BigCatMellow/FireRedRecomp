-- Plain-Lua unit test (no ROM needed) for src/core/SongPlayer.lua -- the
-- real M4A playback scheduler: tempo/tick clock, per-track command
-- advance, note gate-time release, and the real MidiKeyToFreq /
-- MidiKeyToCgbFreq / TrkVolPitSet / ChnVolSetAsm math. Synthetic event
-- lists (the shape import/SongEvents.lua emits) so the scheduling logic is
-- exercised in isolation; tests/song_player_test.lua covers the real ROM
-- integration path.
--
-- Run: lua5.1 tests/song_player_unit_test.lua
package.path = package.path .. ";./?.lua"
local SongPlayer = require("src.core.SongPlayer")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local function approx(a, b, tol)
  return math.abs(a - b) <= (tol or 1e-6)
end

local function song(...)
  local tracks = {}
  for i, events in ipairs({ ... }) do tracks[i] = { events = events } end
  return { trackCount = #tracks, tracks = tracks }
end

local function note(key, velocity, gateTime)
  return { type = "note", key = key, velocity = velocity, gateTime = gateTime, tie = gateTime == 0 }
end
local function rest(d) return { type = "rest", duration = d } end
local function ctl(name, value, extra)
  local e = { type = "control", name = name, value = value }
  if extra then for k, v in pairs(extra) do e[k] = v end end
  return e
end
local FINE = { type = "end" }

local function firstOfType(events, type_, track)
  for _, e in ipairs(events) do
    if e.type == type_ and (track == nil or e.track == track) then return e end
  end
end

-- 1) umul3232H32: the real ARM high-multiply, reimplemented in 16-bit
--    halves. 2^32 * 2^32 >> 32 style identities.
do
  check("umulH32(2^32-1, 2^32-1) high word", SongPlayer.umulH32(4294967295, 4294967295) == 4294967294,
    SongPlayer.umulH32(4294967295, 4294967295))
  check("umulH32(x, 2^31) == x/2", SongPlayer.umulH32(1000000, 2147483648) == 500000)
  check("umulH32(x, small) == 0", SongPlayer.umulH32(1000, 1000) == 0)
end

-- 2) MidiKeyToFreq: key 60 is the sample's own recorded pitch exactly
--    (gScaleTable[60] = 0x90 -> gFreqTable[0] >> 9 = 2^32/1024, so the
--    high-multiply collapses to freq/1024 == WaveData.sampleRateHz).
do
  local wavFreq = 10764288 -- real gCryTable entry 1's WaveData.freq (10512 Hz)
  check("key 60 reproduces the sample's own rate exactly",
    SongPlayer.midiKeyToFreq(wavFreq, 60) == wavFreq / 1024,
    SongPlayer.midiKeyToFreq(wavFreq, 60))
  check("pitchRatio at key 60 == 1", SongPlayer.pitchRatio(wavFreq, 60) == 1)
  check("one octave up doubles the rate", approx(SongPlayer.pitchRatio(wavFreq, 72), 2.0, 1e-3),
    SongPlayer.pitchRatio(wavFreq, 72))
  check("one octave down halves the rate", approx(SongPlayer.pitchRatio(wavFreq, 48), 0.5, 1e-3),
    SongPlayer.pitchRatio(wavFreq, 48))

  -- Every semitone step in the real table is 2^(1/12) equal temperament
  -- (within the engine's own integer-Hz truncation).
  local semitone = 2 ^ (1 / 12)
  local worst = 0
  for key = 12, 120 do
    local r = SongPlayer.midiKeyToFreq(wavFreq, key + 1) / SongPlayer.midiKeyToFreq(wavFreq, key)
    worst = math.max(worst, math.abs(r - semitone))
  end
  check("every semitone step matches 2^(1/12) within table rounding", worst < 2e-3, worst)

  check("key is clamped at 178 like the real function",
    SongPlayer.midiKeyToFreq(wavFreq, 200) == SongPlayer.midiKeyToFreq(wavFreq, 178, 255))
  -- fineAdjust interpolates between adjacent semitones, monotonically.
  check("fineAdjust interpolates upward", SongPlayer.midiKeyToFreq(wavFreq, 60, 128)
    > SongPlayer.midiKeyToFreq(wavFreq, 60, 0))
  check("fineAdjust 255 stays below the next semitone", SongPlayer.midiKeyToFreq(wavFreq, 60, 255)
    < SongPlayer.midiKeyToFreq(wavFreq, 61, 0))
end

-- 3) MidiKeyToCgbFreq: real register values back through the hardware
--    relation 131072 / (2048 - R) must land on real note frequencies.
do
  check("CGB key 36 is C2 (65.4 Hz)", approx(SongPlayer.cgbFreqHz(36), 65.41, 0.05),
    SongPlayer.cgbFreqHz(36))
  check("CGB key 60 is middle C (261.6 Hz)", approx(SongPlayer.cgbFreqHz(60), 261.63, 0.2),
    SongPlayer.cgbFreqHz(60))
  check("CGB key 69 is A440", approx(SongPlayer.cgbFreqHz(69), 440.0, 0.6),
    SongPlayer.cgbFreqHz(69))
  check("CGB octave doubles", approx(SongPlayer.cgbFreqHz(72) / SongPlayer.cgbFreqHz(60), 2.0, 0.01),
    SongPlayer.cgbFreqHz(72) / SongPlayer.cgbFreqHz(60))
end

-- 4) TrkVolPitSet / ChnVolSetAsm, hand-computed from the real integer
--    formulas for MUS_LEVEL_UP track 1's actual state (vol=90, default
--    volX=0x40, PAN 112 -> signed +48, velocity 100).
do
  local volML, volMR = SongPlayer.trackVolumes(90, 0x40, 48, 0)
  check("volMR for vol=90 pan=+48", volMR == 157, volMR)
  check("volML for vol=90 pan=+48", volML == 21, volML)
  local left, right = SongPlayer.channelVolumes(volML, volMR, 100, 0)
  check("right channel volume", right == 122, right)
  check("left channel volume", left == 16, left)
  check("panned right is louder on the right", right > left)

  -- Centered pan is near-symmetric (the real formula's 128 vs 127 split).
  local cML, cMR = SongPlayer.trackVolumes(127, 0x40, 0, 0)
  local cl, cr = SongPlayer.channelVolumes(cML, cMR, 127, 0)
  check("centered pan is near-symmetric", math.abs(cl - cr) <= 3, ("%d/%d"):format(cl, cr))
  check("volumes stay inside the real 0-255 clamp", cl <= 255 and cr <= 255)
  -- vol defaults to 0 until a VOL command -- real Clear64byte behaviour.
  local zML, zMR = SongPlayer.trackVolumes(0, 0x40, 0, 0)
  check("no VOL command means silence", zML == 0 and zMR == 0)
end

-- 5) trackPitch: the real x = (tune + bend*bendRange)*4 + keyShift<<8 + ...
do
  local t = { tune = 0, bend = 0, bendRange = 2, keyShift = 0, keyShiftX = 0, pitX = 0 }
  local keyM, fine = SongPlayer.trackPitch(t)
  check("neutral track: no key/fine shift", keyM == 0 and fine == 0)
  t.keyShift = 12
  keyM, fine = SongPlayer.trackPitch(t)
  check("KEYSH 12 shifts a whole octave of keys", keyM == 12 and fine == 0)
  t.keyShift = 0
  t.bend = 64 -- max upward BEND with the default bendRange of 2
  keyM, fine = SongPlayer.trackPitch(t)
  check("full BEND with bendRange 2 is +2 semitones", keyM == 2 and fine == 0, ("%d/%d"):format(keyM, fine))
  t.bend = 0
  t.tune = 32 -- half a semitone of TUNE
  keyM, fine = SongPlayer.trackPitch(t)
  check("TUNE +32 is a half-semitone fine adjust", keyM == 0 and fine == 128, ("%d/%d"):format(keyM, fine))
end

-- 6) The clock: with no TEMPO command, tempoI == 150 == exactly one tick
--    per VBlank frame (real MPlayStart defaults).
do
  local p = SongPlayer.new(song({ rest(96), FINE }))
  for _ = 1, 10 do p:updateFrame() end
  check("default tempo: 1 tick per frame", p.tick == 10, p.tick)
  check("default seconds/tick is one VBlank",
    approx(p:secondsPerTick(), 1 / SongPlayer.FRAMES_PER_SECOND, 1e-9), p:secondsPerTick())
end

-- 7) TEMPO 87 (MUS_LEVEL_UP's real value) -> tempoD 174 -> 174/150 ticks
--    per frame, accumulated exactly the way MPlayMain does. Frame 1 still
--    runs at the default 150 (the TEMPO command is only read once that
--    frame's first tick executes), so 25 frames = 1 + floor(24*174/150)
--    = 28 ticks, not 29 -- the real engine has exactly this one-tick
--    startup lag.
do
  local p = SongPlayer.new(song({ ctl("tempo", 87, { bpm = 174 }), rest(200), FINE }))
  for _ = 1, 25 do p:updateFrame() end
  check("tempoD is the doubled TEMPO argument", p.tempoD == 174, p.tempoD)
  check("25 frames at bpm 174 gives 28 ticks", p.tick == 28, p.tick)
  -- 24 ticks is a quarter note. At 174 BPM that is 60/174 s in nominal
  -- musical time; the real GBA runs it off the 59.7275 Hz VBlank, so the
  -- true duration is that scaled by 60/59.7275 (~0.46% slower). Both facts
  -- are asserted so a regression in either direction is caught.
  local quarter = 24 * p:secondsPerTick()
  check("a quarter note is 60/bpm scaled by the real VBlank rate",
    approx(quarter, (60 / 174) * (60 / SongPlayer.FRAMES_PER_SECOND), 1e-6), quarter)
  check("a quarter note is within 0.5% of nominal 60/bpm",
    math.abs(quarter - 60 / 174) / (60 / 174) < 0.005, quarter)
end

-- 8) Scheduling: rest(4), note(gate 8), rest(24), FINE. The note starts on
--    the 5th tick (the rest-reading tick consumes one of its 4) and is
--    released exactly gateTime ticks later.
do
  local p = SongPlayer.new(song({ rest(4), note(60, 127, 8), rest(24), FINE }))
  local tl = p:renderTimeline()
  local on = firstOfType(tl.events, "noteOn")
  local off = firstOfType(tl.events, "noteOff")
  check("exactly one noteOn and one noteOff", #tl.events == 2, #tl.events)
  check("noteOn lands on tick 5 (after a 4-tick rest)", on and on.tick == 5, on and on.tick)
  check("noteOff lands gateTime ticks later", off and off.tick == 13, off and off.tick)
  check("noteOff is released by gate time", off and off.reason == "gateTime")
  check("noteOff refers to the same note", on and off and off.noteId == on.noteId)
  check("note carries its key/velocity/gate", on.key == 60 and on.velocity == 127 and on.gateTime == 8)
  check("timeline seconds are filled in", on.seconds and approx(on.seconds, on.frame / SongPlayer.FRAMES_PER_SECOND))
end

-- 9) Running-status carryover: a note with no key/velocity bytes reuses the
--    track's previous ones (real ply_note only writes the fields present).
do
  local p = SongPlayer.new(song({
    note(72, 90, 4), rest(8), note(nil, nil, 4), rest(8), FINE,
  }))
  local tl = p:renderTimeline()
  local ons = {}
  for _, e in ipairs(tl.events) do if e.type == "noteOn" then ons[#ons + 1] = e end end
  check("two notes sounded", #ons == 2, #ons)
  check("second note reuses the first's key", ons[2] and ons[2].key == 72, ons[2] and ons[2].key)
  check("second note reuses the first's velocity", ons[2] and ons[2].velocity == 90)
end

-- 10) TIE (gateTime 0) sustains until EOT; a plain note does not.
do
  local p = SongPlayer.new(song({
    note(60, 100, 0), rest(40), { type = "endtie", key = 60 }, rest(4), FINE,
  }))
  local tl = p:renderTimeline()
  local on = firstOfType(tl.events, "noteOn")
  local off = firstOfType(tl.events, "noteOff")
  check("tie is flagged on the noteOn", on and on.tie == true)
  check("tied note is not released by gate time", off and off.reason == "endtie", off and off.reason)
  check("tied note survives the whole 40-tick rest", off and off.tick == 41, off and off.tick)
end

-- 11) ply_fine releases anything still sounding when the track ends.
do
  local p = SongPlayer.new(song({ note(60, 100, 0), FINE }))
  local tl = p:renderTimeline()
  local off = firstOfType(tl.events, "noteOff")
  check("FINE releases a held tie", off and off.reason == "trackEnd", off and off.reason)
  check("FINE ends on the same tick it is read", off and off.tick == 1, off and off.tick)
  check("track records why it stopped", p.tracks[1].stopReason == "end", p.tracks[1].stopReason)
  check("player reports finished", p:isFinished())
end

-- 12) Multiple tracks advance in lockstep on the shared clock, and a TEMPO
--     command on one track retimes all of them (tempo lives on the
--     MusicPlayerInfo, not the track -- real ply_tempo writes mplayInfo).
do
  local p = SongPlayer.new(song(
    { ctl("tempo", 150, { bpm = 300 }), rest(4), note(60, 100, 4), rest(8), FINE },
    { rest(4), note(67, 100, 4), rest(8), FINE }
  ))
  local tl = p:renderTimeline()
  local a = firstOfType(tl.events, "noteOn", 1)
  local b = firstOfType(tl.events, "noteOn", 2)
  check("both tracks sound", a ~= nil and b ~= nil)
  check("both tracks' notes land on the same tick", a and b and a.tick == b.tick, a and b and (a.tick .. "/" .. b.tick))
  check("track 2 is retimed by track 1's TEMPO (2 ticks/frame)",
    a and a.frame == math.ceil(a.tick / 2), a and (a.frame .. "/" .. a.tick))
end

-- 13) Note-offs are emitted before note-ons within a tick, matching
--     MPlayMain's order (channels are aged before commands are read).
do
  -- rest(4) then a gate-4 note repeated: the second note starts on exactly
  -- the tick the first is released.
  local p = SongPlayer.new(song({ note(60, 100, 4), rest(4), note(62, 100, 4), rest(4), FINE }))
  local tl = p:renderTimeline()
  local sameTick = {}
  for _, e in ipairs(tl.events) do
    sameTick[e.tick] = sameTick[e.tick] or {}
    table.insert(sameTick[e.tick], e.type)
  end
  local collided = sameTick[5]
  check("release and re-attack collide on tick 5", collided and #collided == 2, collided and #collided)
  check("noteOff is emitted before noteOn on that tick",
    collided and collided[1] == "noteOff" and collided[2] == "noteOn",
    collided and table.concat(collided, ","))
end

-- 14) Consecutive notes with no rest between them all fire on one tick
--     (notes never set `wait` in the real engine) -- i.e. chords work.
do
  local p = SongPlayer.new(song({ note(60, 100, 8), note(64, 100, 8), note(67, 100, 8), rest(8), FINE }))
  local tl = p:renderTimeline()
  local ons = 0
  for _, e in ipairs(tl.events) do
    if e.type == "noteOn" then
      ons = ons + 1
      check("chord note is on tick 1", e.tick == 1, e.tick)
    end
  end
  check("all three chord notes sounded", ons == 3, ons)
end

-- 15) Volume/pan reach the emitted event (the numbers a mixer consumes).
do
  local p = SongPlayer.new(song({
    ctl("vol", 90), ctl("pan", 112, { signedValue = 48 }), note(71, 100, 4), rest(4), FINE,
  }))
  local tl = p:renderTimeline()
  local on = firstOfType(tl.events, "noteOn")
  check("noteOn carries the real right-channel volume", on and on.volumeRight == 122, on and on.volumeRight)
  check("noteOn carries the real left-channel volume", on and on.volumeLeft == 16, on and on.volumeLeft)
  check("noteOn carries the signed pan", on and on.pan == 48, on and on.pan)
  check("noteOn carries the selected voice", on and on.voice == 0)
end

-- 16) A GOTO (looping BGM) terminates the track here rather than looping --
--     import/SongEvents.lua stops decoding there, documented gap.
do
  local p = SongPlayer.new(song({ note(60, 100, 4), { type = "goto", target = 0x08000000 } }))
  local tl = p:renderTimeline()
  check("goto stops the track", p:isFinished())
  check("stop reason records the goto", p.tracks[1].stopReason == "goto", p.tracks[1].stopReason)
  check("held note is released at the goto", firstOfType(tl.events, "noteOff") ~= nil)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
