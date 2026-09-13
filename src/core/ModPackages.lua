-- Deterministic package discovery for the headless mod SDK. Filesystem and
-- code execution are injected so this remains usable by LÖVE, CLI tools, and
-- tests without giving package code implicit host authority.

local Manifest = require("src.core.ModManifest")
local Packages = {}

local function join(root, name)
  return root == "" and name or root .. "/" .. name
end

-- fs needs `list(path) -> { names }`, `isDirectory(path) -> bool`, and
-- `read(path) -> bytes`. decodeManifest(bytes, path) returns a decoded table;
-- compileEntry(bytes, path, manifest) returns the mod callback function.
-- Packages are `root/<manifest.id>/manifest.json` + `init.lua`. Requiring the
-- directory name to equal its manifest id prevents an accidental rename from
-- making filesystem order part of a mod's identity.
function Packages.discover(fs, root, decodeManifest, compileEntry)
  assert(type(fs) == "table" and type(fs.list) == "function"
      and type(fs.isDirectory) == "function" and type(fs.read) == "function",
    "mod package discovery needs list/isDirectory/read filesystem methods")
  assert(type(root) == "string", "mod package root must be a string")
  assert(type(decodeManifest) == "function", "mod package discovery needs a manifest decoder")
  assert(type(compileEntry) == "function", "mod package discovery needs an entry compiler")

  local names = fs.list(root)
  assert(type(names) == "table", "mod package filesystem list must return an array")
  local directories = {}
  for _, name in ipairs(names) do
    assert(type(name) == "string" and name ~= "" and not name:find("/", 1, true),
      "mod package filesystem returned an invalid entry name")
    local path = join(root, name)
    if fs.isDirectory(path) then directories[#directories + 1] = name end
  end
  table.sort(directories)

  local entries, ids = {}, {}
  for _, directory in ipairs(directories) do
    local packagePath = join(root, directory)
    local manifestPath = join(packagePath, "manifest.json")
    local manifestBytes = fs.read(manifestPath)
    assert(type(manifestBytes) == "string", "could not read mod manifest: " .. manifestPath)
    local manifest = Manifest.validate(decodeManifest(manifestBytes, manifestPath))
    assert(manifest.id == directory,
      ("mod package directory %s does not match manifest id %s"):format(directory, manifest.id))
    assert(not ids[manifest.id], "duplicate mod package id: " .. manifest.id)
    ids[manifest.id] = true

    local entryPath = join(packagePath, "init.lua")
    local entryBytes = fs.read(entryPath)
    assert(type(entryBytes) == "string", "could not read mod entry: " .. entryPath)
    local callback = compileEntry(entryBytes, entryPath, manifest)
    assert(type(callback) == "function", "mod entry must compile to a callback: " .. entryPath)
    entries[#entries + 1] = {manifest=manifest, callback=callback, path=packagePath}
  end
  return entries
end

return Packages
