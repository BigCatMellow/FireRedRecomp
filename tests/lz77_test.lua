-- Run: lua5.1 tests/lz77_test.lua
package.path = package.path .. ";./?.lua"
local Lz77 = require("import.Lz77")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. detail) or ""))
  end
end

-- Hand-encoded LZ77 block for "AAAAAAAAAA" (10 bytes):
--   header: tag 0x10, size 10 (LE 24-bit)
--   flags 0x40 (literal, back-ref, then don't-care bits -- loop stops at size)
--   literal 'A' (0x41)
--   back-ref b1=0x60 (len nibble 6 -> len 9), b2=0x00 (disp 0 -> disp 1)
local compressed = string.char(0x10, 0x0A, 0x00, 0x00, 0x40, 0x41, 0x60, 0x00)

local result, err = Lz77.decompress(compressed)
check("decompresses without error", result ~= nil, err)
check("output is 10 'A's", result == string.rep("A", 10), result and (#result .. " bytes: " .. result))

-- Pure-literal block (no back-references): "AB" via two literal flag bits.
-- flags 0x00 = both literal.
local literalOnly = string.char(0x10, 0x02, 0x00, 0x00, 0x00, 0x41, 0x42)
local result2, err2 = Lz77.decompress(literalOnly)
check("pure literal block decompresses", result2 == "AB", err2)

local badTag = string.char(0x11, 0x02, 0x00, 0x00)
local ok3, err3 = Lz77.decompress(badTag)
check("rejects wrong tag byte", ok3 == nil and type(err3) == "string")

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
