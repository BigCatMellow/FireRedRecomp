package.path = package.path .. ";./?.lua"
local MovementScript = require("src.core.MovementScript")
local passed, failed = 0, 0
local function check(name, value) if value then passed=passed+1 else failed=failed+1; print("FAIL: "..name) end end
local script = string.rep("\0", 16) .. string.char(0x10, 0x1F, 0x38, 0xFE)
local steps = MovementScript.decode(script, 0x08000010)
check("normal, fast, and faster walk actions decode to directions", #steps == 3 and steps[1] == "down" and steps[2] == "left" and steps[3] == "right")
local ok = pcall(MovementScript.decode, string.char(0x99, 0xFE), 0x08000000)
check("unsupported movement actions fail loudly", not ok)
print(("movement_script_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
