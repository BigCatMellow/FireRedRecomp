-- Pure save/mod-profile compatibility evaluator. It deliberately does not
-- change SaveFileCodec's FireRed-sector wrapper yet: callers can use this
-- stable policy when a future save metadata field is introduced.
--
-- A gameplay-changing mod is incompatible when disabled, enabled, or changed
-- version-to-version unless an explicit migration says otherwise. Cosmetic
-- differences are accepted but reported, never silently treated as equal.

local Compatibility = {}
Compatibility.PROFILE_VERSION = 1

local function sort(entries)
  table.sort(entries, function(a, b) return a.id < b.id end)
  return entries
end

local function assertImpact(value)
  assert(value == "cosmetic" or value == "gameplay",
    "save impact must be cosmetic or gameplay")
end

function Compatibility.profile(manifests)
  assert(type(manifests) == "table", "manifests must be an array")
  local entries, seen = {}, {}
  for _, manifest in ipairs(manifests) do
    assert(type(manifest) == "table" and type(manifest.id) == "string"
      and type(manifest.version) == "string", "profile needs validated manifests")
    assert(not seen[manifest.id], "profile has duplicate mod id: " .. manifest.id)
    local impact = manifest.saveImpact or "gameplay"
    assertImpact(impact)
    seen[manifest.id] = true
    entries[#entries + 1] = {id=manifest.id, version=manifest.version, impact=impact}
  end
  return {version=Compatibility.PROFILE_VERSION, entries=sort(entries)}
end

local function indexed(profile)
  assert(type(profile) == "table" and profile.version == Compatibility.PROFILE_VERSION
    and type(profile.entries) == "table", "unsupported mod save profile")
  local out = {}
  for _, entry in ipairs(profile.entries) do
    assert(type(entry.id) == "string" and type(entry.version) == "string", "invalid mod save profile entry")
    assertImpact(entry.impact)
    assert(not out[entry.id], "duplicate mod save profile id: " .. entry.id)
    out[entry.id] = entry
  end
  return out
end

function Compatibility.key(profile)
  indexed(profile) -- validate before producing a stable external key
  local entries = { entries={} }
  for i, entry in ipairs(profile.entries) do entries.entries[i] = {
    id=entry.id, version=entry.version, impact=entry.impact,
  } end
  sort(entries.entries)
  local parts = {}
  for _, entry in ipairs(entries.entries) do
    parts[#parts + 1] = entry.id .. "@" .. entry.version .. ":" .. entry.impact
  end
  return "v" .. Compatibility.PROFILE_VERSION .. "/" .. table.concat(parts, ";")
end

-- migrations is optional `{ [savedKey] = { [activeKey] = migrationName } }`.
function Compatibility.compare(saved, active, migrations)
  local savedById, activeById = indexed(saved), indexed(active)
  local ids, seen, cosmetic = {}, {}, {}
  for id in pairs(savedById) do seen[id] = true; ids[#ids + 1] = id end
  for id in pairs(activeById) do if not seen[id] then ids[#ids + 1] = id end end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local old, new = savedById[id], activeById[id]
    if old and new and old.version == new.version and old.impact == new.impact then
      -- unchanged
    elseif (old and old.impact == "gameplay") or (new and new.impact == "gameplay") then
      local oldKey, newKey = Compatibility.key(saved), Compatibility.key(active)
      local migration = migrations and migrations[oldKey] and migrations[oldKey][newKey]
      if migration then return {status="migrate", migration=migration} end
      return {status="reject", reason=("gameplay mod mismatch: %s"):format(id)}
    else
      cosmetic[#cosmetic + 1] = id
    end
  end
  return #cosmetic == 0 and {status="exact"} or {status="cosmetic", changed=cosmetic}
end

-- Keeps user-visible compatibility reporting deterministic and separate from
-- the policy decision above. Hosts must still explicitly execute a migration;
-- merely receiving a `migrate` result never authorizes loading altered state.
function Compatibility.describe(result)
  assert(type(result) == "table" and type(result.status) == "string",
    "compatibility result is required")
  if result.status == "exact" then return nil end
  if result.status == "cosmetic" then
    assert(type(result.changed) == "table", "cosmetic compatibility result needs changed mod ids")
    return "Cosmetic mod differences: " .. table.concat(result.changed, ", ") .. "."
  end
  if result.status == "migrate" then
    return "Save requires explicit mod migration: " .. tostring(result.migration) .. "."
  end
  if result.status == "reject" then return tostring(result.reason) end
  error("unknown mod compatibility status: " .. result.status)
end

return Compatibility
