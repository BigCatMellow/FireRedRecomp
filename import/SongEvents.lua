-- Decodes a real M4A/Sappy "compiled song" event byte stream -- the
-- per-track command bytes a real `struct SongHeader` (pokefirered
-- include/gba/m4a_internal.h) `part[i]` pointer points at, reached from a
-- `struct Song` via import/SongTable.lua's `headerPtr` -- into a flat list
-- of typed Lua tables. Extraction only: this produces a data model of what
-- a song contains (notes/rests/tempo/etc, in stream order); it does NOT
-- play anything back or interpret real-time timing. See
-- src/core/AudioPlayer.lua for real PCM sample playback (individual
-- instrument samples via import/WaveData.lua, not whole songs) -- turning
-- this module's output into scheduled audio is a separate, much bigger
-- follow-up (a real ply-note scheduler), out of scope here.
--
-- Real command byte format traced from pokefirered's actual M4A engine
-- interpreter -- NOT guessed from generic Sappy docs:
--   - src/m4a_1.s, function MPlayMain (the real per-track command
--     dispatch loop, labels _081DD8E0.._081DD938): reads one byte at
--     track->cmdPtr and classifies it:
--       * byte < 0x80: NOT a new command byte -- MIDI-style "running
--         status". track->cmdPtr is NOT advanced past it; the command
--         is track->runningStatus (only ever saved when a byte >= 0xBD
--         was previously dispatched), and this byte is consumed as that
--         command's first argument instead.
--       * 0x80 <= byte <= 0xB0 (49 values): a rest/wait command. Duration
--         in GBA frames = gClockTable[byte - 0x80] (src/m4a_tables.c, a
--         real 49-entry u8 table, values 0x00..0x60 -- also reused below
--         for note gate-times).
--       * 0xB1 <= byte <= 0xCE (30 values): a track-control command,
--         dispatched via (byte - 0xB1) indexing
--         gMPlayJumpTableTemplate (src/m4a_tables.c). The #define block
--         immediately after that table in the real source gives the
--         real names: FINE=0xb1, GOTO=0xb2, PATT=0xb3, PEND=0xb4,
--         REPT=0xb5, MEMACC=0xb9, PRIO=0xba, TEMPO=0xbb, KEYSH=0xbc,
--         VOICE=0xbd, VOL=0xbe, PAN=0xbf, BEND=0xc0, BENDR=0xc1,
--         LFOS=0xc2, LFODL=0xc3, MOD=0xc4, MODT=0xc5, TUNE=0xc8,
--         XCMD=0xcd, EOT=0xce. Slot values in this range with no #define
--         (0xb6-0xb8, 0xc6-0xc7, 0xc9-0xcb) are real dummy/unused
--         template entries that resolve to ply_fine (confirmed by
--         reading gMPlayJumpTableTemplate's literal contents).
--       * 0xCF <= byte <= 0xFF (49 values): a note/TIE command
--         (ply_note, src/m4a_1.s ~1538-1576), noteArg = byte - 0xCF
--         (0..48, matching gClockTable's 49 entries). noteArg 0 (byte
--         0xCF) is TIE per src/m4a_tables.c's `#define TIE 0xcf`:
--         sustain until explicitly released (EOT / a new note), initial
--         gateTime = gClockTable[0] = 0. noteArg > 0 is a normal note
--         with an implicit gate time from gClockTable[noteArg]. Up to 3
--         more optional bytes follow, each consumed only if < 0x80
--         (confirmed in ply_note's asm: it re-tests the next byte
--         against 0x80 before each read, exactly mirroring MPlayMain's
--         own running-status test) -- key (MIDI note number 0-127),
--         velocity (0-127), and extra gate-time (added to the table
--         value). Any of these can be omitted, in which case the
--         track's previous key/velocity/gateTime carry over (real M4A
--         "repeat last note's pitch" shorthand).
--   - ply_tempo (src/m4a_1.s ~920): tempoD = arg * 2 -- the real BPM is
--     the command's argument byte doubled (consistent with
--     MPlayStart's/m4a.c's default tempoD=150 before any TEMPO command
--     runs).
--   - ply_pan / ply_bend / ply_tune (src/m4a_1.s ~981-1054): each does
--     `subs r3, C_V` (C_V = 0x40, constants/m4a_constants.inc) before
--     storing -- i.e. the real stored value is signed, centered on 0x40
--     as neutral (0x40 -> 0, 0x00 -> -64, 0x7F -> +63).
--   - ply_endtie (EOT, 0xCE, src/m4a_1.s ~1818-1857): optional 1-byte
--     key arg (same <0x80 running-status-style convention) -- releases
--     a tied note; omitted arg means "release the track's current key".
--
-- XCMD (0xcd) IS fully decoded: ply_xcmd (src/m4a.c ~1523) reads one more
-- sub-command byte n and dispatches through the real gXcmdTable[]
-- (src/m4a_tables.c ~292-308), a 14-entry table whose real per-entry arg
-- widths are read directly off each ply_x* function body (src/m4a.c
-- ~1544-1653): xxx=0 bytes (n=0,3 -- and actually calls ply_fine, i.e.
-- ends the track -- decoded as an "end" event below), xwave=4,
-- xtype=1, xatta=1, xdeca=1, xsust=1, xrele=1, xiecv=1, xiecl=1,
-- xleng=1, xswee=1, xwait=2, xcmd_0D=4. (This resolves the
-- inconsistent-width problem that made a naive/generic XCMD decode
-- unsafe -- each sub-op's width is now known exactly, not guessed.)
--
-- Deliberately NOT implemented -- real commands in the dispatch table,
-- but rare/pure-control-flow enough that decoding their arg bytes
-- wouldn't help without also simulating jumps (out of scope -- see
-- GOTO below). Decoding stops and reports an "unimplemented" event
-- rather than continuing blind:
--   PATT (0xb3, pattern-call: reads a 4-byte absolute target pointer and
--     jumps to it, pushing a return address), PEND (0xb4,
--     pattern-return: no stream arg but changes control flow to a
--     pushed-earlier address), REPT (0xb5, repeat-N-times: 1 count
--     byte, then conditionally a 4-byte target depending on that count
--     -- variable length), MEMACC (0xb9, ply_memacc: a 3-byte
--     RAM-compare/RAM-write op, structurally different from the other
--     stream commands and meaningless without simulated RAM state),
--     PORT (0xcc, ply_port: writes a raw GBA sound register directly,
--     practically unused in real FireRed music).
-- GOTO (0xB2) itself IS decoded (target pointer extracted), but decoding
-- always stops there rather than following the jump: real songs use it
-- for open-ended loop points, and blindly following it risks an infinite
-- loop or wandering into unrelated ROM data -- same "stop at the
-- terminator, don't simulate control flow" spirit as
-- import/SpriteAnim.lua's ANIMCMD_JUMP handling.
--
-- Verified against real ROM data: MUS_LEVEL_UP (include/constants/songs.h
-- id 257, a short well-known fanfare) -- see tests/song_events_test.lua
-- for exact structural asserts (event count, note/rest presence, no
-- crashes, sane pitch range, clean termination).

local SongEvents = {}

local byte = string.byte

SongEvents.romBase = 0x08000000

-- Real gClockTable (src/m4a_tables.c) -- GBA-frame durations for both
-- rest commands (0x80-0xB0) and note gate-times (0xCF-0xFF). 1-based Lua
-- array; index with CLOCK_TABLE[n + 1] for the real 0-based n.
local CLOCK_TABLE = {
  0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,
  0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11, 0x12, 0x13,
  0x14, 0x15, 0x16, 0x17, 0x18, 0x1C, 0x1E, 0x20, 0x24, 0x28,
  0x2A, 0x2C, 0x30, 0x34, 0x36, 0x38, 0x3C, 0x40, 0x42, 0x44,
  0x48, 0x4C, 0x4E, 0x50, 0x54, 0x58, 0x5A, 0x5C, 0x60,
}
SongEvents.CLOCK_TABLE = CLOCK_TABLE

local C_V = 0x40 -- neutral center for PAN/BEND/TUNE (constants/m4a_constants.inc)

-- Real names from src/m4a_tables.c's #define block (cmd byte -> name).
local CONTROL_1BYTE = {
  [0xba] = "prio",
  [0xbb] = "tempo",
  [0xbc] = "keysh",
  [0xbd] = "voice",
  [0xbe] = "vol",
  [0xbf] = "pan",
  [0xc0] = "bend",
  [0xc1] = "bendr",
  [0xc2] = "lfos",
  [0xc3] = "lfodl",
  [0xc4] = "mod",
  [0xc5] = "modt",
  [0xc8] = "tune",
}

local SIGNED_CENTERED = { pan = true, bend = true, tune = true }

local UNIMPLEMENTED = {
  [0xb3] = "patt",
  [0xb4] = "pend",
  [0xb5] = "rept",
  [0xb9] = "memacc",
  [0xcc] = "port",
}

-- Real gXcmdTable (src/m4a_tables.c), index = XCMD's sub-command byte.
-- argBytes is the real arg width read off each ply_x* function body (see
-- header comment). "isEnd" marks the two dummy slots (n=0,3) that call
-- ply_xxx -> gMPlayJumpTable[0] -> ply_fine, i.e. they end the track.
local XCMD_TABLE = {
  [0] = { name = "xxx", argBytes = 0, isEnd = true },
  [1] = { name = "xwave", argBytes = 4 },
  [2] = { name = "xtype", argBytes = 1 },
  [3] = { name = "xxx", argBytes = 0, isEnd = true },
  [4] = { name = "xatta", argBytes = 1 },
  [5] = { name = "xdeca", argBytes = 1 },
  [6] = { name = "xsust", argBytes = 1 },
  [7] = { name = "xrele", argBytes = 1 },
  [8] = { name = "xiecv", argBytes = 1 },
  [9] = { name = "xiecl", argBytes = 1 },
  [10] = { name = "xleng", argBytes = 1 },
  [11] = { name = "xswee", argBytes = 1 },
  [12] = { name = "xwait", argBytes = 2 },
  [13] = { name = "xcmd_0D", argBytes = 4 },
}

-- Safety cap: even a correctly-decoded infinite song is finite in event
-- count per non-looping pass, so a runaway past this means we've drifted
-- into unrelated ROM data (bad pointer, or a real GOTO loop we correctly
-- stop at anyway -- see above).
SongEvents.MAX_EVENTS = 8000

local function u32le(data, offset0based)
  return byte(data, offset0based + 1)
    + byte(data, offset0based + 2) * 256
    + byte(data, offset0based + 3) * 65536
    + byte(data, offset0based + 4) * 16777216
end

-- data: full ROM bytes. offset0based: 0-based file offset of one track's
-- command byte stream (a SongHeader.part[i] pointer minus romBase).
-- Returns a flat list of events, always ending with one of:
--   {type="end", ...}                 -- real FINE (0xB1), a dummy/
--                                          unused jump-table slot (rare),
--                                          or XCMD sub-op 0/3 (ply_xxx,
--                                          which itself calls ply_fine)
--   {type="goto", target=<raw ptr>}   -- real GOTO (0xB2); not followed
--   {type="unimplemented", name=..}   -- PATT/PEND/REPT/MEMACC/PORT, or
--                                          an out-of-range XCMD sub-op
--   {type="truncated", reason=..}     -- ran off the buffer or hit
--                                          MAX_EVENTS
-- Other event types that can appear before the terminator:
--   {type="note", tie=bool, key=n|nil, velocity=n|nil, gateTime=n, opcode=n}
--   {type="rest", duration=n, opcode=n}
--   {type="endtie", key=n|nil, opcode=0xCE}
--   {type="control", name=.., value=n, opcode=n[, bpm=n][, signedValue=n]
--     [, subcmd=n]}  -- subcmd present for XCMD-derived control events
--     (name is the real gXcmdTable sub-op name, e.g. "xiecv"/"xwait")
function SongEvents.decodeTrack(data, offset0based)
  local events = {}
  local pos = offset0based
  local dataLen = #data
  local runningStatus = nil

  while true do
    if #events >= SongEvents.MAX_EVENTS then
      events[#events + 1] = { type = "truncated", reason = "hit MAX_EVENTS safety cap" }
      break
    end
    if pos < 0 or pos >= dataLen then
      events[#events + 1] = { type = "truncated", reason = "ran off the end of the buffer" }
      break
    end

    local b = byte(data, pos + 1)
    local cmd
    if b < 0x80 then
      cmd = runningStatus
      if not cmd then
        events[#events + 1] = { type = "truncated", reason = "data byte with no running-status command active" }
        break
      end
      -- cmdPtr NOT advanced here -- this byte is the command's first arg.
    else
      cmd = b
      pos = pos + 1
      if cmd >= 0xBD then
        runningStatus = cmd
      end
    end

    if cmd >= 0xCF then
      -- Note/TIE command (ply_note).
      local noteArg = cmd - 0xCF
      local gateTime = CLOCK_TABLE[noteArg + 1]
      local key, velocity = nil, nil
      if pos < dataLen and byte(data, pos + 1) < 0x80 then
        key = byte(data, pos + 1)
        pos = pos + 1
        if pos < dataLen and byte(data, pos + 1) < 0x80 then
          velocity = byte(data, pos + 1)
          pos = pos + 1
          if pos < dataLen and byte(data, pos + 1) < 0x80 then
            gateTime = gateTime + byte(data, pos + 1)
            pos = pos + 1
          end
        end
      end
      events[#events + 1] = {
        type = "note",
        tie = noteArg == 0,
        key = key,
        velocity = velocity,
        gateTime = gateTime,
        opcode = cmd,
      }
    elseif cmd >= 0x80 and cmd <= 0xB0 then
      events[#events + 1] = { type = "rest", duration = CLOCK_TABLE[cmd - 0x80 + 1], opcode = cmd }
    elseif cmd == 0xB1 then
      events[#events + 1] = { type = "end", opcode = cmd }
      break
    elseif cmd == 0xB2 then
      if pos + 4 > dataLen then
        events[#events + 1] = { type = "truncated", reason = "GOTO target ran off the buffer" }
        break
      end
      local target = u32le(data, pos)
      pos = pos + 4
      events[#events + 1] = { type = "goto", target = target, opcode = cmd }
      break
    elseif cmd == 0xCE then
      local key = nil
      if pos < dataLen and byte(data, pos + 1) < 0x80 then
        key = byte(data, pos + 1)
        pos = pos + 1
      end
      events[#events + 1] = { type = "endtie", key = key, opcode = cmd }
    elseif CONTROL_1BYTE[cmd] then
      if pos >= dataLen then
        events[#events + 1] = { type = "truncated", reason = "control command arg ran off the buffer" }
        break
      end
      local name = CONTROL_1BYTE[cmd]
      local value = byte(data, pos + 1)
      pos = pos + 1
      local ev = { type = "control", name = name, value = value, opcode = cmd }
      if name == "tempo" then
        ev.bpm = value * 2
      end
      if SIGNED_CENTERED[name] then
        ev.signedValue = value - C_V
      end
      events[#events + 1] = ev
    elseif cmd == 0xCD then
      -- XCMD: one more sub-command byte, then a sub-command-specific arg
      -- width (see gXcmdTable derivation in the header comment).
      if pos >= dataLen then
        events[#events + 1] = { type = "truncated", reason = "XCMD sub-command byte ran off the buffer" }
        break
      end
      local sub = byte(data, pos + 1)
      pos = pos + 1
      local info = XCMD_TABLE[sub]
      if not info then
        events[#events + 1] = { type = "unimplemented", name = "xcmd", opcode = cmd, subcmd = sub }
        break
      end
      if info.isEnd then
        events[#events + 1] = { type = "end", opcode = cmd, subcmd = sub, via = "xcmd/" .. info.name }
        break
      end
      if pos + info.argBytes > dataLen then
        events[#events + 1] = { type = "truncated", reason = "XCMD " .. info.name .. " arg ran off the buffer" }
        break
      end
      local value = 0
      for i = 0, info.argBytes - 1 do
        value = value + byte(data, pos + i + 1) * (256 ^ i)
      end
      pos = pos + info.argBytes
      events[#events + 1] = { type = "control", name = info.name, value = value, opcode = cmd, subcmd = sub }
    elseif UNIMPLEMENTED[cmd] then
      events[#events + 1] = { type = "unimplemented", name = UNIMPLEMENTED[cmd], opcode = cmd }
      break
    else
      -- 0xB1-0xCE dummy/unused jump-table slot -- resolves to ply_fine
      -- in the real engine (confirmed against gMPlayJumpTableTemplate's
      -- literal contents), so treat it the same as a real FINE.
      events[#events + 1] = { type = "end", opcode = cmd, dummy = true }
      break
    end
  end

  return events
end

-- data: full ROM bytes. headerAddr: a raw full ROM address (0x08xxxxxx)
-- -- a Song.headerPtr from SongTable.resolve(). Decodes the real
-- `struct SongHeader` (m4a_internal.h: u8 trackCount, u8 blockCount,
-- u8 priority, u8 reverb, struct ToneData *tone, u8 *part[trackCount])
-- and then decodes every track's event stream.
-- Returns { trackCount=n, priority=n, reverb=n, tonePtr=<raw ptr>,
--           tracks = { [1] = { ptr=<raw ptr>, events={...} }, ... } }
function SongEvents.decodeSong(data, headerAddr)
  local headerOffset = headerAddr - SongEvents.romBase
  local trackCount = byte(data, headerOffset + 0 + 1)
  local blockCount = byte(data, headerOffset + 1 + 1)
  local priority = byte(data, headerOffset + 2 + 1)
  local reverb = byte(data, headerOffset + 3 + 1)
  local tonePtr = u32le(data, headerOffset + 0x04)

  local tracks = {}
  for i = 0, trackCount - 1 do
    local partPtr = u32le(data, headerOffset + 0x08 + i * 4)
    tracks[i + 1] = {
      ptr = partPtr,
      events = SongEvents.decodeTrack(data, partPtr - SongEvents.romBase),
    }
  end

  return {
    trackCount = trackCount,
    blockCount = blockCount,
    priority = priority,
    reverb = reverb,
    tonePtr = tonePtr,
    tracks = tracks,
  }
end

return SongEvents
