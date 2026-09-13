-- Run: lua5.1 tests/mod_json_test.lua
package.path = package.path .. ";./?.lua"
local Json = require("src.core.ModJson")
local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or "")) end
end
local function fails(text, fragment)
  local ok, err = pcall(function() Json.decode(text) end)
  return not ok and tostring(err):find(fragment, 1, true) ~= nil
end
local manifest = Json.decode('{"id":"example-mod","version":"1.2.3","api":1,"priority":-2,"dependencies":["base"],"saveImpact":"cosmetic"}')
check("manifest JSON decodes typed values", manifest.id == "example-mod" and manifest.priority == -2
  and manifest.dependencies[1] == "base" and manifest.saveImpact == "cosmetic")
local unicode = Json.decode('{"name":"\\uD83D\\uDE80 \\u00E9"}')
check("unicode escapes decode UTF-8 including surrogate pairs", unicode.name == "🚀 é")
local values = Json.decode('[true,false,null,1.25e2]')
check("arrays preserve booleans null and exponent numbers", values[1] and not values[2]
  and values[3] == Json.NULL and values[4] == 125)
check("duplicate object keys fail loudly", fails('{"id":"a","id":"b"}', "duplicate object key"))
check("invalid JSON number fails loudly", fails('{"priority":01}', "expected , or }"))
check("unpaired unicode surrogate fails loudly", fails('"\\uD800"', "unpaired unicode surrogate"))
check("trailing JSON data fails loudly", fails('true false', "trailing data"))
print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
