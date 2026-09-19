-- Deterministic contract coverage for the Phase 2 external-reference checker.
-- Uses synthetic 240x160 PNGs only; no ROM/reference pixels are checked in.
package.path = package.path .. ";./?.lua"
local PNG = require("tools.pixeldiff.png")
local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. name .. (detail and (" -- " .. detail) or "")) end
end
local root = os.tmpname() .. "_phase2_parity"
assert(os.execute("mkdir -p " .. root .. "/refs " .. root .. "/project" ) == 0)
local function writePng(path, width, height, delta)
  local image = { width = width, height = height, getPixel = function(x, y)
    return { r = (x + (delta or 0)) % 256, g = y % 256, b = 77, a = 255 }
  end }
  assert(PNG.encodeToFile(image, path))
end
for _, id in ipairs({ "oak_static", "pallet_centered", "pallet_edge_clamped" }) do
  writePng(root .. "/refs/" .. id .. ".png", 240, 160)
  writePng(root .. "/project/" .. id .. ".png", 240, 160)
end
local function sha(path)
  local p = assert(io.popen("sha256sum -- '" .. path .. "'"))
  local value = assert(p:read("*l")):match("^([0-9a-f]+)")
  p:close()
  return value
end
local function manifest(path, mutate)
  local f = assert(io.open(path, "wb"))
  f:write("schema=phase2-camera-oak-reference-parity/v1\n")
  f:write("supported_rom_sha1=41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc\n")
  f:write("emulator=synthetic-test\ncapture_dimensions=240x160\nproject_capture_command=synthetic\n")
  for _, id in ipairs({ "oak_static", "pallet_centered", "pallet_edge_clamped" }) do
    local base = "case." .. id .. "."
    f:write(base .. "reference_file=" .. id .. ".png\n")
    f:write(base .. "reference_sha256=" .. sha(root .. "/refs/" .. id .. ".png") .. "\n")
    f:write(base .. "boot_state=synthetic\n" .. base .. "input_sequence=synthetic\n" .. base .. "capture_point=synthetic\n")
    f:write(base .. "pixel_channel_delta=0\n" .. base .. "max_differing_percent=0\n" .. base .. "max_channel_delta=0\n" .. base .. "max_mean_delta=0\n")
  end
  if mutate then f:write(mutate) end
  f:close()
end
local function run(extra, result)
  local code = os.execute("lua5.1 tools/phase2_camera_oak_parity_check.lua --manifest " .. root .. "/manifest --reference-dir " .. root .. "/refs --project-dir " .. root .. "/project --result " .. result .. " " .. (extra or "") .. " >/dev/null 2>&1")
  return code == 0
end
manifest(root .. "/manifest")
check("valid synthetic references compare PASS", run("", root .. "/pass.json"))
local f = assert(io.open(root .. "/pass.json", "rb")); local passResult = f:read("*a"); f:close()
check("PASS result records every named case", passResult:find('"status":"PASS"', 1, true) and passResult:find('"id":"oak_static"', 1, true) and passResult:find('"differing_pixel_count":0', 1, true))

os.remove(root .. "/refs/oak_static.png")
check("missing reference fails closed", not run("", root .. "/missing.json"))
f = assert(io.open(root .. "/missing.json", "rb")); local missing = f:read("*a"); f:close()
check("missing reference reports BLOCKED", missing:find('"status":"BLOCKED"', 1, true) ~= nil)
writePng(root .. "/refs/oak_static.png", 240, 160)

manifest(root .. "/manifest", "case.oak_static.reference_sha256=" .. string.rep("0", 64) .. "\n")
check("duplicate/malformed provenance fails closed", not run("", root .. "/bad-manifest.json"))
manifest(root .. "/manifest")
writePng(root .. "/refs/oak_static.png", 240, 160, 1)
check("checksum-mismatched reference fails closed", not run("", root .. "/bad-checksum.json"))
writePng(root .. "/refs/oak_static.png", 239, 160)
manifest(root .. "/manifest")
check("wrong-size reference fails before comparison", not run("", root .. "/wrong-reference-size.json"))
writePng(root .. "/refs/oak_static.png", 240, 160)
manifest(root .. "/manifest")
writePng(root .. "/project/pallet_edge_clamped.png", 239, 160)
check("wrong-size project capture fails before comparison", not run("", root .. "/wrong-size.json"))

os.execute("rm -rf -- " .. root)
print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
