-- Headless manifest validation and deterministic dependency ordering for
-- ModRegistry API v1. This accepts already-decoded manifest tables; a future
-- filesystem/package loader deliberately owns JSON parsing and code loading.

local ModManifest = {}
ModManifest.API_VERSION = 1

local function copyArray(value, field)
  if value == nil then return {} end
  assert(type(value) == "table", field .. " must be an array")
  local out, seen = {}, {}
  for i, entry in ipairs(value) do
    assert(type(entry) == "string" and entry:match("^[%w_%-]+$"),
      field .. " entries must be valid mod ids")
    assert(not seen[entry], field .. " cannot repeat " .. entry)
    seen[entry] = true
    out[i] = entry
  end
  return out
end

local function semver(value)
  assert(type(value) == "string" and value:match("^%d+%.%d+%.%d+$"),
    "manifest version must be MAJOR.MINOR.PATCH")
  return value
end

function ModManifest.validate(raw)
  assert(type(raw) == "table", "manifest must be a table")
  assert(type(raw.id) == "string" and raw.id:match("^[%w_%-]+$"),
    "manifest id must contain only letters, numbers, _ or -")
  local api = raw.api or ModManifest.API_VERSION
  assert(api == ModManifest.API_VERSION,
    ("manifest %s requires API %s; engine provides API %d")
      :format(raw.id, tostring(api), ModManifest.API_VERSION))
  local saveImpact = raw.saveImpact or "gameplay"
  assert(saveImpact == "cosmetic" or saveImpact == "gameplay",
    "manifest saveImpact must be cosmetic or gameplay")
  return {
    id=raw.id, name=raw.name or raw.id, version=semver(raw.version), api=api,
    priority=tonumber(raw.priority) or 0,
    saveImpact=saveImpact,
    dependencies=copyArray(raw.dependencies, "dependencies"),
    conflicts=copyArray(raw.conflicts, "conflicts"),
  }
end

local function earlier(a, b)
  if a.priority ~= b.priority then return a.priority < b.priority end
  return a.id < b.id
end

-- Validates a selected manifest set and returns the only valid deterministic
-- load order: dependencies precede dependents; otherwise priority then id.
function ModManifest.order(rawManifests)
  assert(type(rawManifests) == "table", "manifest list must be an array")
  local manifests, byId, incoming, dependents = {}, {}, {}, {}
  for i, raw in ipairs(rawManifests) do
    local manifest = ModManifest.validate(raw)
    assert(not byId[manifest.id], "duplicate manifest id: " .. manifest.id)
    manifests[i], byId[manifest.id] = manifest, manifest
    incoming[manifest.id], dependents[manifest.id] = 0, {}
  end
  for _, manifest in ipairs(manifests) do
    for _, dependency in ipairs(manifest.dependencies) do
      assert(byId[dependency], ("%s depends on missing mod %s")
        :format(manifest.id, dependency))
      incoming[manifest.id] = incoming[manifest.id] + 1
      dependents[dependency][#dependents[dependency] + 1] = manifest.id
    end
    for _, conflict in ipairs(manifest.conflicts) do
      assert(not byId[conflict], ("%s conflicts with enabled mod %s")
        :format(manifest.id, conflict))
    end
  end
  local ready, out = {}, {}
  for _, manifest in ipairs(manifests) do
    if incoming[manifest.id] == 0 then ready[#ready + 1] = manifest end
  end
  while #ready > 0 do
    table.sort(ready, earlier)
    local manifest = table.remove(ready, 1)
    out[#out + 1] = manifest
    for _, id in ipairs(dependents[manifest.id]) do
      incoming[id] = incoming[id] - 1
      if incoming[id] == 0 then ready[#ready + 1] = byId[id] end
    end
  end
  assert(#out == #manifests, "mod dependency graph contains a cycle")
  return out
end

return ModManifest
