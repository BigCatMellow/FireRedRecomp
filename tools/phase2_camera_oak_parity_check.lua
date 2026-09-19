-- Fail-closed comparator for the Phase 2 camera/Oak reference-parity gate.
--
-- This consumes an externally supplied key=value provenance manifest and
-- untracked reference directory. It deliberately has no default reference
-- path: a caller must map that private corpus explicitly. It validates all
-- provenance, checksums, and 240x160 PNG dimensions before PixelDiff sees a
-- pixel. The JSON result is suitable for retaining outside the repository.
--
-- Run via scripts/phase2_camera_oak_parity.sh. Focused coverage is in
-- tests/phase2_camera_oak_parity_harness_test.lua.

package.path = package.path .. ";./?.lua"
local PNG = require("tools.pixeldiff.png")
local PixelDiff = require("tools.pixeldiff.init")

local CASES = { "oak_static", "pallet_centered", "pallet_edge_clamped" }
local REQUIRED_GLOBAL = {
  "schema", "supported_rom_sha1", "emulator", "capture_dimensions",
  "project_capture_command",
}
local REQUIRED_CASE = {
  "reference_file", "reference_sha256", "boot_state", "input_sequence",
  "capture_point", "pixel_channel_delta", "max_differing_percent",
  "max_channel_delta", "max_mean_delta",
}

local function fail(message) error(message, 0) end
local function readFile(path)
  local f, err = io.open(path, "rb")
  if not f then return nil, err end
  local data = f:read("*a")
  f:close()
  return data
end
local function quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end
local function sha256(path)
  local pipe = io.popen("sha256sum -- " .. quote(path) .. " 2>/dev/null")
  if not pipe then return nil, "sha256sum unavailable" end
  local line = pipe:read("*l")
  pipe:close()
  local digest = line and line:match("^([0-9a-fA-F]+)%s")
  if not digest or #digest ~= 64 then return nil, "sha256sum failed" end
  return digest:lower()
end
local function jsonString(value)
  return '"' .. tostring(value):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r') .. '"'
end
local function writeResult(path, status, reason, records)
  local out = { "{\"status\":" .. jsonString(status) .. ",\"reason\":" .. jsonString(reason) .. ",\"cases\":[" }
  for i, record in ipairs(records or {}) do
    if i > 1 then out[#out + 1] = "," end
    out[#out + 1] = "{\"id\":" .. jsonString(record.id)
      .. ",\"capture_width\":" .. tostring(record.capture_width)
      .. ",\"capture_height\":" .. tostring(record.capture_height)
      .. ",\"reference_sha256\":" .. jsonString(record.reference_sha256)
      .. ",\"differing_pixel_count\":" .. tostring(record.differing_pixel_count)
      .. ",\"differing_pixel_percent\":" .. tostring(record.differing_pixel_percent)
      .. ",\"max_channel_delta\":" .. tostring(record.max_channel_delta)
      .. ",\"mean_channel_delta\":" .. tostring(record.mean_channel_delta)
      .. ",\"threshold\":{\"pixel_channel_delta\":" .. tostring(record.pixel_channel_delta)
      .. ",\"max_differing_percent\":" .. tostring(record.max_differing_percent)
      .. ",\"max_channel_delta\":" .. tostring(record.threshold_max_channel_delta)
      .. ",\"max_mean_delta\":" .. tostring(record.max_mean_delta) .. "}"
      .. ",\"status\":" .. jsonString(record.status) .. "}"
  end
  out[#out + 1] = "]}\n"
  local f, err = io.open(path, "wb")
  if not f then fail("cannot write result " .. path .. ": " .. tostring(err)) end
  f:write(table.concat(out))
  f:close()
end

local function parseManifest(path)
  local data, err = readFile(path)
  if not data then fail("reference corpus unavailable: cannot read manifest: " .. tostring(err)) end
  local values = {}
  local lineNo = 0
  for line in (data .. "\n"):gmatch("(.-)\n") do
    lineNo = lineNo + 1
    if line ~= "" and not line:match("^%s*#") then
      local key, value = line:match("^([a-z0-9_%.]+)=(.*)$")
      if not key or value == "" then fail("malformed provenance manifest at line " .. lineNo) end
      if values[key] then fail("duplicate provenance key " .. key) end
      values[key] = value
    end
  end
  for _, key in ipairs(REQUIRED_GLOBAL) do
    if not values[key] then fail("missing provenance field " .. key) end
  end
  if values.schema ~= "phase2-camera-oak-reference-parity/v1" then fail("unsupported provenance schema") end
  if values.supported_rom_sha1 ~= "41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc" then fail("unsupported-ROM provenance SHA-1") end
  if values.capture_dimensions ~= "240x160" then fail("reference capture dimensions must be 240x160") end
  for _, id in ipairs(CASES) do
    for _, field in ipairs(REQUIRED_CASE) do
      if not values["case." .. id .. "." .. field] then
        fail("missing provenance field case." .. id .. "." .. field)
      end
    end
    local filename = values["case." .. id .. ".reference_file"]
    if filename:find("[/\\]") or filename == "." or filename == ".." then fail("reference_file must be a bare filename for " .. id) end
    if not values["case." .. id .. ".reference_sha256"]:match("^[0-9a-fA-F][0-9a-fA-F]+$")
      or #values["case." .. id .. ".reference_sha256"] ~= 64 then fail("invalid reference SHA-256 for " .. id) end
  end
  return values
end

local function numberField(values, key)
  local value = tonumber(values[key])
  if not value or value < 0 then fail("invalid non-negative numeric provenance field " .. key) end
  return value
end
local function decode240(path, kind, id)
  local image, err = PNG.decodeFile(path)
  if not image then fail("invalid " .. kind .. " PNG for " .. id .. ": " .. tostring(err)) end
  if image.width ~= 240 or image.height ~= 160 then fail(kind .. " PNG for " .. id .. " is not 240x160") end
  return image
end

local manifest, projectDir, referenceDir, resultPath, preflight
for i = 1, #arg do
  local value = arg[i]
  if value == "--manifest" then manifest = arg[i + 1]
  elseif value == "--project-dir" then projectDir = arg[i + 1]
  elseif value == "--reference-dir" then referenceDir = arg[i + 1]
  elseif value == "--result" then resultPath = arg[i + 1] end
  if value == "--preflight" then preflight = true end
end
if not manifest or not referenceDir or not resultPath or (not preflight and not projectDir) then
  io.stderr:write("usage: lua5.1 tools/phase2_camera_oak_parity_check.lua --manifest FILE --reference-dir DIR --result FILE [--preflight | --project-dir DIR]\n")
  os.exit(2)
end

local ok, err = pcall(function()
  local values = parseManifest(manifest)
  if preflight then
    for _, id in ipairs(CASES) do
      local referencePath = referenceDir .. "/" .. values["case." .. id .. ".reference_file"]
      local actualSha, shaErr = sha256(referencePath)
      if not actualSha then fail("reference corpus unavailable: " .. id .. " checksum unavailable: " .. tostring(shaErr)) end
      if actualSha ~= values["case." .. id .. ".reference_sha256"]:lower() then fail("reference checksum mismatch for " .. id) end
      decode240(referencePath, "reference", id)
    end
    writeResult(resultPath, "PASS", "reference provenance and PNGs validated; no project comparison requested", {})
    return
  end
  local records = {}
  for _, id in ipairs(CASES) do
    local referencePath = referenceDir .. "/" .. values["case." .. id .. ".reference_file"]
    local projectPath = projectDir .. "/" .. id .. ".png"
    local actualSha, shaErr = sha256(referencePath)
    if not actualSha then fail("reference corpus unavailable: " .. id .. " checksum unavailable: " .. tostring(shaErr)) end
    if actualSha ~= values["case." .. id .. ".reference_sha256"]:lower() then fail("reference checksum mismatch for " .. id) end
    local reference = decode240(referencePath, "reference", id)
    local project = decode240(projectPath, "project capture", id)
    local prefix = "case." .. id .. "."
    local pixelThreshold = numberField(values, prefix .. "pixel_channel_delta")
    local maxDiffering = numberField(values, prefix .. "max_differing_percent")
    local maxChannel = numberField(values, prefix .. "max_channel_delta")
    local maxMean = numberField(values, prefix .. "max_mean_delta")
    local summary = PixelDiff.compare(project, reference, { diffThreshold = pixelThreshold })
    local passed = summary.percentDiffering <= maxDiffering and summary.maxChannelDelta <= maxChannel and summary.meanDelta <= maxMean
    records[#records + 1] = {
      id = id, capture_width = project.width, capture_height = project.height,
      reference_sha256 = actualSha, differing_pixel_count = summary.diffPixelCount,
      differing_pixel_percent = summary.percentDiffering, max_channel_delta = summary.maxChannelDelta,
      mean_channel_delta = summary.meanDelta, pixel_channel_delta = pixelThreshold,
      max_differing_percent = maxDiffering, threshold_max_channel_delta = maxChannel,
      max_mean_delta = maxMean, status = passed and "PASS" or "FAIL",
    }
  end
  local allPass = true
  for _, record in ipairs(records) do if record.status ~= "PASS" then allPass = false end end
  writeResult(resultPath, allPass and "PASS" or "FAIL", allPass and "all cases within declared thresholds" or "one or more cases exceed declared thresholds", records)
  if not allPass then os.exit(1) end
end)
if not ok then
  local reason = tostring(err)
  local status = reason:find("reference corpus unavailable", 1, true) and "BLOCKED" or "FAIL"
  writeResult(resultPath, status, reason, {})
  io.stderr:write("phase2 parity " .. status .. ": " .. reason .. "\n")
  os.exit(1)
end
