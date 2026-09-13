-- Project-owned mod-profile sidecar for a FireRed save buffer. The profile
-- follows the real sector payload instead of occupying any retail save byte,
-- so an unmodded buffer remains byte-for-byte compatible with SaveFileCodec.

local SaveFileCodec = require("src.core.SaveFileCodec")
local Compatibility = require("src.core.ModSaveCompatibility")

local Codec = {}
Codec.MAGIC = "FRMP"
Codec.VERSION = 1

local BASE_BYTES = SaveFileCodec.HEADER_SIZE
  + SaveFileCodec.NUM_SAVE_SLOTS * SaveFileCodec.SLOT_BYTES
Codec.BASE_BYTES = BASE_BYTES
local LEGACY_BASE_BYTES = SaveFileCodec.HEADER_SIZE
  + SaveFileCodec.NUM_SAVE_SLOTS * 5 * SaveFileCodec.SECTOR_SIZE

local function u16(value)
  return string.char(value % 256, math.floor(value / 256) % 256)
end

local function readU16(bytes, offset)
  local lo, hi = bytes:byte(offset + 1, offset + 2)
  if not lo or not hi then return nil end
  return lo + hi * 256
end

local function appendString(out, value)
  assert(#value <= 0xFFFF, "mod profile string is too long")
  out[#out + 1] = u16(#value)
  out[#out + 1] = value
end

-- Encodes a validated compatibility profile as a deterministic binary
-- sidecar. It is not a replacement for the FireRed sectors.
function Codec.encode(profile)
  Compatibility.key(profile) -- validates and gives callers one policy owner
  local entries = {}
  for i, entry in ipairs(profile.entries) do
    entries[i] = {id=entry.id, version=entry.version, impact=entry.impact}
  end
  table.sort(entries, function(a, b) return a.id < b.id end)
  assert(#entries <= 0xFFFF, "too many enabled mods")
  local out = {Codec.MAGIC, string.char(Codec.VERSION), u16(#entries)}
  for _, entry in ipairs(entries) do
    appendString(out, entry.id)
    appendString(out, entry.version)
    out[#out + 1] = entry.impact == "cosmetic" and "\1" or "\2"
  end
  return table.concat(out)
end

function Codec.decode(bytes)
  assert(type(bytes) == "string", "mod profile sidecar must be bytes")
  assert(bytes:sub(1, 4) == Codec.MAGIC, "bad mod profile sidecar magic")
  assert(bytes:byte(5) == Codec.VERSION, "unsupported mod profile sidecar version")
  local count = assert(readU16(bytes, 5), "truncated mod profile sidecar")
  local offset, entries = 7, {}
  for _ = 1, count do
    local idSize = assert(readU16(bytes, offset), "truncated mod profile id length")
    offset = offset + 2
    local id = bytes:sub(offset + 1, offset + idSize)
    assert(#id == idSize, "truncated mod profile id")
    offset = offset + idSize
    local versionSize = assert(readU16(bytes, offset), "truncated mod profile version length")
    offset = offset + 2
    local version = bytes:sub(offset + 1, offset + versionSize)
    assert(#version == versionSize, "truncated mod profile version")
    offset = offset + versionSize
    local impact = bytes:byte(offset + 1)
    assert(impact == 1 or impact == 2, "invalid mod profile impact")
    offset = offset + 1
    entries[#entries + 1] = {id=id, version=version,
      impact=impact == 1 and "cosmetic" or "gameplay"}
  end
  assert(offset == #bytes, "trailing bytes in mod profile sidecar")
  local profile = {version=Compatibility.PROFILE_VERSION, entries=entries}
  Compatibility.key(profile)
  return profile
end

-- A legacy/no-mod save has exactly BASE_BYTES and is returned unchanged.
function Codec.attach(saveBytes, profile)
  assert(type(saveBytes) == "string" and #saveBytes == BASE_BYTES,
    "mod profile sidecar needs one complete SaveFileCodec buffer")
  return saveBytes .. Codec.encode(profile)
end

function Codec.extract(saveBytes)
  assert(type(saveBytes) == "string", "mod profile sidecar must be bytes")
  assert(saveBytes:sub(1, 4) == SaveFileCodec.MAGIC, "bad save magic")
  local version = saveBytes:byte(5)
  local baseBytes = version == 1 and LEGACY_BASE_BYTES
    or version == SaveFileCodec.VERSION and BASE_BYTES
  assert(baseBytes and #saveBytes >= baseBytes,
    "mod profile sidecar needs a complete supported SaveFileCodec buffer")
  local base = saveBytes:sub(1, baseBytes)
  if #saveBytes == baseBytes then return base, nil end
  return base, Codec.decode(saveBytes:sub(baseBytes + 1))
end

return Codec
