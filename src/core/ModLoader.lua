-- Pure headless loader: pairs decoded manifests with caller-supplied Lua
-- callbacks and applies them to a ModRegistry transactionally. Filesystem
-- discovery and sandboxing are intentionally outside this boundary.

local Manifest = require("src.core.ModManifest")
local ModLoader = {}
ModLoader.__index = ModLoader

function ModLoader.new(registry)
  assert(registry and type(registry.apply) == "function" and type(registry.rollback) == "function",
    "ModLoader needs a ModRegistry")
  return setmetatable({ registry=registry, loaded={} }, ModLoader)
end

-- entries are `{ manifest = decodedManifestTable, callback = function(mod) }`.
-- A failed callback rolls back its own staging and every earlier callback in
-- this load attempt, leaving the registry exactly as it was beforehand.
function ModLoader:load(entries)
  assert(type(entries) == "table", "mod entries must be an array")
  local raw, callbacks = {}, {}
  for i, entry in ipairs(entries) do
    assert(type(entry) == "table" and entry.manifest and type(entry.callback) == "function",
      "mod entry needs manifest and callback")
    raw[i] = entry.manifest
    assert(not callbacks[entry.manifest.id], "duplicate callback manifest id: " .. tostring(entry.manifest.id))
    callbacks[entry.manifest.id] = entry.callback
  end
  local ordered = Manifest.order(raw)
  local applied = {}
  for _, manifest in ipairs(ordered) do
    local ok, err = self.registry:apply(manifest, callbacks[manifest.id])
    if not ok then
      for i = #applied, 1, -1 do self.registry:rollback(applied[i].id) end
      return nil, ("mod %s failed: %s"):format(manifest.id, tostring(err))
    end
    applied[#applied + 1] = manifest
  end
  self.loaded = applied
  return applied
end

return ModLoader
