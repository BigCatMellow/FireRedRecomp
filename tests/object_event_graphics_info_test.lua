-- Integration test: decodes real gObjectEventGraphicsInfo entries via the
-- real gObjectEventGraphicsInfoPointers table, resolves a real paletteTag
-- through sObjectEventSpritePalettes, and decodes an actual standing-frame
-- NPC sprite through the existing ObjectSprite pipeline. Opt-in via
-- POKEPORT_ROM, skips cleanly otherwise.
--
-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/object_event_graphics_info_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local ObjectEventGraphicsInfo = require("import.ObjectEventGraphicsInfo")
local OamShapeSize = require("import.OamShapeSize")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

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

-- OBJ_EVENT_GFX_WOMAN_1 = 23: Pallet Town's real Sign Lady NPC.
local womanInfo = ObjectEventGraphicsInfo.decode(data, addrs.gObjectEventGraphicsInfoPointers, 23)
check("Woman1 real width/height (16x32)", womanInfo.width == 16 and womanInfo.height == 32, womanInfo.width .. "x" .. womanInfo.height)
check("Woman1 real paletteTag (OBJ_EVENT_PAL_TAG_NPC_GREEN = 0x1105)", womanInfo.paletteTag == 0x1105, string.format("0x%04X", womanInfo.paletteTag))
check("Woman1 real tracks (TRACKS_FOOT = 1)", womanInfo.tracks == 1, womanInfo.tracks)
check("Woman1's real oam pointer matches the known gObjectEventBaseOam_16x32 address",
  womanInfo.oamPtr == addrs.gObjectEventBaseOam_16x32 + 0x08000000, string.format("0x%08X", womanInfo.oamPtr))

-- Cross-check via OamShapeSize: the real oam struct at womanInfo.oamPtr
-- should decode to exactly the same 16x32 dimensions the graphics-info
-- struct itself declares.
local oam = OamShapeSize.decodeOamData(data, womanInfo.oamPtr - ObjectEventGraphicsInfo.romBase)
check("Woman1's real OAM shape/size decodes to the same 16x32", oam.width == 16 and oam.height == 32, oam.width .. "x" .. oam.height)

-- Palette tag resolution: OBJ_EVENT_PAL_TAG_NPC_GREEN should resolve to
-- exactly gObjectEventPal_NpcGreen's real address (found via a second,
-- independent NPC below sharing the same palette family).
local palettePtr = ObjectEventGraphicsInfo.resolvePaletteTag(data, addrs.sObjectEventSpritePalettes, womanInfo.paletteTag)
check("Woman1's real paletteTag resolves to a real gObjectEventPal_NpcGreen-shaped pointer",
  palettePtr == 0x0836d868, string.format("0x%08X", palettePtr))

-- Decode the actual standing-down-frame pixels end to end (graphicsId ->
-- real pixels), the same pipeline ObjectSprite.decodeFrame's existing
-- player-sprite test already spot-checks by shape.
local image, hFlip = ObjectEventGraphicsInfo.decodeStandingImage(data, womanInfo, palettePtr, "down")
check("Woman1 standing-down image is the real declared 16x32px", image.width == 16 and image.height == 32)
check("standing-down doesn't need hFlip", hFlip == false)

local imageRight, hFlipRight = ObjectEventGraphicsInfo.decodeStandingImage(data, womanInfo, palettePtr, "right")
check("standing-right shares the left frame (hFlip=true, matching the real sAnim_FaceEast .hFlip=TRUE)", hFlipRight == true)
check("standing-right image is still 16x32 (same source frame, unflipped canvas)", imageRight.width == 16 and imageRight.height == 32)

-- A second, independently-verified real NPC: OBJ_EVENT_GFX_PROF_OAK = 71.
local oakInfo = ObjectEventGraphicsInfo.decode(data, addrs.gObjectEventGraphicsInfoPointers, 71)
check("Prof Oak real width/height (16x32)", oakInfo.width == 16 and oakInfo.height == 32, oakInfo.width .. "x" .. oakInfo.height)
local oakImage = ObjectEventGraphicsInfo.decodeStandingImage(data, oakInfo, ObjectEventGraphicsInfo.resolvePaletteTag(data, addrs.sObjectEventSpritePalettes, oakInfo.paletteTag), "up")
check("Prof Oak standing-up image decodes to 16x32", oakImage.width == 16 and oakImage.height == 32)

-- graphicsId fallback rule: an id beyond NUM_OBJ_EVENT_GFX (152) falls back
-- to OBJ_EVENT_GFX_LITTLE_BOY (16), matching the real
-- GetObjectEventGraphicsInfo clamp -- should decode identically to
-- graphicsId 16 itself, not error.
local fallbackInfo = ObjectEventGraphicsInfo.decode(data, addrs.gObjectEventGraphicsInfoPointers, 200)
local littleBoyInfo = ObjectEventGraphicsInfo.decode(data, addrs.gObjectEventGraphicsInfoPointers, 16)
check("out-of-range graphicsId falls back to real OBJ_EVENT_GFX_LITTLE_BOY", fallbackInfo.structPtr == littleBoyInfo.structPtr)

-- VAR-based dynamic graphicsId: documented as unimplemented, must error loudly.
local okVar, errVar = pcall(ObjectEventGraphicsInfo.decode, data, addrs.gObjectEventGraphicsInfoPointers, 240)
check("VAR-based graphicsId (>= OBJ_EVENT_GFX_VARS) errors loudly", not okVar and tostring(errVar):find("dynamic") ~= nil, errVar)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
