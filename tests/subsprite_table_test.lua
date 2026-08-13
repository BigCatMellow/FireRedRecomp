-- Plain-Lua unit test (always runs, no ROM needed): checks
-- SubspriteTable.lua's bitfield/pointer decoding against small synthetic
-- byte strings built to the real struct layout confirmed in the module's
-- header comment (4 bytes/Subsprite, 8 bytes/SubspriteTable entry).
package.path = package.path .. ";./?.lua"

local SubspriteTable = require("import.SubspriteTable")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- One real Subsprite entry, matching gObjectEventSpriteOamTable_16x16_0's
-- real ROM bytes (f8 f8 04 80): x=-8, y=-8, shape=0, size=1,
-- tileOffset=0, priority=2.
local single = string.char(0xf8, 0xf8, 0x04, 0x80)
local decoded = SubspriteTable.decodeSubsprites(single, 0, 1)
check("single subsprite count", #decoded == 1)
check("single subsprite x", decoded[1].x == -8, decoded[1].x)
check("single subsprite y", decoded[1].y == -8, decoded[1].y)
check("single subsprite shape", decoded[1].shape == 0, decoded[1].shape)
check("single subsprite size", decoded[1].size == 1, decoded[1].size)
check("single subsprite tileOffset", decoded[1].tileOffset == 0, decoded[1].tileOffset)
check("single subsprite priority", decoded[1].priority == 2, decoded[1].priority)

-- Two real SS Anne subsprites, matching gObjectEventSpriteOamTable_128x64_0's
-- real ROM bytes (e0 f0 0d 80, 20 f0 0d 82): x=-32,y=-16,shape=1(H_RECT),
-- size=3(64x32),tileOffset=0,priority=2 then x=32,y=-16,...,tileOffset=32,priority=2.
local pair = string.char(0xe0, 0xf0, 0x0d, 0x80, 0x20, 0xf0, 0x0d, 0x82)
local decodedPair = SubspriteTable.decodeSubsprites(pair, 0, 2)
check("pair count", #decodedPair == 2)
check("pair[1] x/y", decodedPair[1].x == -32 and decodedPair[1].y == -16)
check("pair[1] shape/size", decodedPair[1].shape == 1 and decodedPair[1].size == 3)
check("pair[1] tileOffset", decodedPair[1].tileOffset == 0)
check("pair[2] x/y", decodedPair[2].x == 32 and decodedPair[2].y == -16)
check("pair[2] tileOffset", decodedPair[2].tileOffset == 32, decodedPair[2].tileOffset)

-- A real {0, NULL} passthrough SubspriteTable entry (all 8 bytes zero,
-- matching gObjectEventSpriteOamTables_16x16[0] byte-for-byte).
local passthrough = string.char(0, 0, 0, 0, 0, 0, 0, 0)
local passthroughTable = SubspriteTable.decodeTable(passthrough, 0)
check("passthrough count is 0", passthroughTable.count == 0)
check("passthrough subsprites is empty", #passthroughTable.subsprites == 0)

-- A real non-passthrough SubspriteTable entry: {1, ptr=0x08000008}, with
-- the pointed-to Subsprite living at file offset 8 in this synthetic blob
-- (matching how decodeTable resolves a raw ROM pointer by subtracting
-- 0x08000000).
local withPointer = string.char(1, 0, 0, 0, 0x08, 0, 0, 0x08)
     .. string.char(0xf8, 0xf8, 0x04, 0x40)
local resolvedTable = SubspriteTable.decodeTable(withPointer, 0)
check("pointer-resolved table count", resolvedTable.count == 1)
check("pointer-resolved subsprite decodes correctly", #resolvedTable.subsprites == 1
  and resolvedTable.subsprites[1].x == -8
  and resolvedTable.subsprites[1].priority == 1)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
