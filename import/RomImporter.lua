-- Verifies a candidate ROM's identity before any decode work touches it.
-- Phase 0/1: identity check only. Decoding (graphics, maps, text, scripts,
-- audio) is later importer work — see ../../firered-recomp-roadmap.md Phase 1.

local RomImporter = {}

-- SHA-1 of known-good FireRed (US) dumps. Sourced from the local
-- pokefirered-master decompilation's firered.sha1 / firered_rev1.sha1.
local SUPPORTED = {
  ["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"] = { name = "Pokémon FireRed (US)", revision = "1.0" },
}

-- Recognized but not yet supported, so a clear message beats a generic
-- "unsupported ROM" when someone hands us the rev1 dump or LeafGreen.
local KNOWN_UNSUPPORTED = {
  ["dd5945db9b930750cb39d00c84da8571feebf417"] = "Pokémon FireRed (US) rev1 (v1.1) — not yet supported",
  ["574fa542ffebb14be69902d1d36f1ec0a4afd71e"] = "Pokémon LeafGreen (US) — not yet supported",
}

local function sha1Hex(data)
  -- love.data.hash returns raw bytes; hex-encode for comparison against
  -- the reference .sha1 files' text format.
  local digest = love.data.hash("sha1", data)
  return (digest:gsub(".", function(c) return string.format("%02x", c:byte()) end))
end

-- Standalone lua5.1 (the test harness) has no `love` and no bundled crypto,
-- so shell out to the system `sha1sum` there. Only the real LÖVE runtime
-- path (sha1Hex above) matters for the shipped app; this is test/tooling
-- support only.
local function sha1HexOfFile(path)
  local quoted = "'" .. path:gsub("'", "'\\''") .. "'"
  local proc = io.popen("sha1sum " .. quoted)
  if not proc then return nil, "could not run sha1sum" end
  local line = proc:read("*l")
  proc:close()
  if not line then return nil, "sha1sum produced no output" end
  return line:match("^(%x+)")
end

-- Returns (ok, info) where info is either the matched SUPPORTED entry or an
-- error string safe to show the player.
--
-- Uses plain io, not love.filesystem: the ROM lives wherever the player put
-- it on disk, outside LÖVE's save-dir/game-source sandbox, and
-- love.filesystem can't read arbitrary external paths without an explicit
-- mount. The real importer UI (Phase 1) will still go through a
-- player-facing file picker / drop target; this is the verification core.
function RomImporter.verify(path)
  local file, err = io.open(path, "rb")
  if not file then
    return false, "Could not open ROM file: " .. tostring(err)
  end
  local data = file:read("*a")
  file:close()
  if not data then
    return false, "Could not read ROM file."
  end

  local hash, hashErr
  if love then
    hash = sha1Hex(data)
  else
    hash, hashErr = sha1HexOfFile(path)
    if not hash then
      return false, "Could not hash ROM file: " .. tostring(hashErr)
    end
  end

  local match = SUPPORTED[hash]
  if match then
    return true, match
  end

  local unsupportedReason = KNOWN_UNSUPPORTED[hash]
  if unsupportedReason then
    return false, unsupportedReason
  end

  return false, "ROM not recognized (sha1 " .. hash .. "). This project only supports a verified Pokémon FireRed (US) v1.0 dump."
end

RomImporter._sha1Hex = sha1Hex -- exposed for tests that don't have a real ROM file
RomImporter._sha1HexOfFile = sha1HexOfFile -- exposed for the standalone-lua integration test
RomImporter._SUPPORTED = SUPPORTED

return RomImporter
