-- Run: lua5.1 tests/mod_packages_test.lua
package.path = package.path .. ";./?.lua"
local Packages = require("src.core.ModPackages")
local Json = require("src.core.ModJson")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or "")) end
end
local function fails(fn, needle)
  local ok, err = pcall(fn)
  return not ok and tostring(err):find(needle, 1, true) ~= nil
end

local files = {
  ["mods/a-base/manifest.json"] = '{"id":"a-base","version":"1.0.0","saveImpact":"gameplay"}',
  ["mods/a-base/init.lua"] = "return base",
  ["mods/z-addon/manifest.json"] = '{"id":"z-addon","version":"1.0.0","dependencies":["a-base"],"saveImpact":"cosmetic"}',
  ["mods/z-addon/init.lua"] = "return addon",
}
local directories = { ["mods/a-base"]=true, ["mods/z-addon"]=true }
local fs = {
  list=function() return {"z-addon", "readme.txt", "a-base"} end,
  isDirectory=function(path) return directories[path] or false end,
  read=function(path) return files[path] end,
}
local compiled = {}
local entries = Packages.discover(fs, "mods", function(bytes, path)
  local manifest = Json.decode(bytes)
  check("manifest decoder receives its source path", path == "mods/" .. manifest.id .. "/manifest.json")
  return manifest
end, function(bytes, path, manifest)
  compiled[#compiled + 1] = path
  return function(mod) return mod and manifest.id end
end)
check("discovery is lexical and ignores files", #entries == 2
  and entries[1].manifest.id == "a-base" and entries[2].manifest.id == "z-addon")
check("entry compiler receives deterministic package paths", compiled[1] == "mods/a-base/init.lua"
  and compiled[2] == "mods/z-addon/init.lua")
check("discovered entries preserve manifest callback contract", type(entries[1].callback) == "function")

local mismatched = { list=fs.list, isDirectory=fs.isDirectory, read=function(path)
  if path == "mods/a-base/manifest.json" then return files["mods/z-addon/manifest.json"] end
  return files[path]
end }
check("directory/manifest identity mismatch fails loudly", fails(function()
  Packages.discover(mismatched, "mods", Json.decode, function() return function() end end)
end, "does not match manifest id"))

local missingEntry = { list=fs.list, isDirectory=fs.isDirectory, read=function(path)
  if path == "mods/z-addon/init.lua" then return nil end
  return files[path]
end }
check("missing entry fails loudly", fails(function()
  Packages.discover(missingEntry, "mods", Json.decode, function() return function() end end)
end, "could not read mod entry"))

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
