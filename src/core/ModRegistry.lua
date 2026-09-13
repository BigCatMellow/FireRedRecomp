-- Versioned, deterministic content registry for the future mod loader.
--
-- This module deliberately has no filesystem, Lua-code-loading, or LÖVE
-- dependency. A loader can validate manifests/dependencies separately, then
-- call apply(mod, callback). Keeping the mutable operation log here makes
-- every content surface use the same ownership and conflict rules before it
-- is wired into game data.
--
-- v1 rules:
--   * a namespace is either `record` (whole entries) or `deep` (tables whose
--     fields compose); base entries may only be changed with `override` or
--     `patch`, never an accidental `register`;
--   * enabled mods fold by ascending `priority`, then lexical id, independent
--     of filesystem enumeration or callback invocation order;
--   * every effective entry retains its last writer in provenance();
--   * a failed callback rolls back all of that mod's staged operations.
--
-- The API is intentionally narrow. It is a stable data boundary for maps,
-- moves, species, scripts, sprites, UI, audio, and battle hooks; namespace
-- consumers decide their own record schema and validation.

local ModRegistry = {}
ModRegistry.__index = ModRegistry
ModRegistry.API_VERSION = 1
local DELETE = {}

-- Sentinel used only in a deep patch to remove one field.
ModRegistry.DELETE = DELETE

local function copy(value, seen)
  if value == DELETE then return DELETE end
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
  return out
end

local function isArray(value)
  if type(value) ~= "table" then return false end
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false end
    count = count + 1
  end
  return count == #value
end

local function deepMerge(base, patch)
  if type(base) ~= "table" or type(patch) ~= "table" then return copy(patch) end
  if isArray(base) or isArray(patch) then return copy(patch) end
  local out = copy(base)
  for key, value in pairs(patch) do
    if value == DELETE then out[key] = nil
    elseif type(value) == "table" and type(out[key]) == "table" then
      out[key] = deepMerge(out[key], value)
    else
      out[key] = copy(value)
    end
  end
  return out
end

local function assertMod(mod)
  assert(type(mod) == "table", "mod metadata is required")
  assert(type(mod.id) == "string" and mod.id:match("^[%w_%-]+$"),
    "mod id must contain only letters, numbers, _ or -")
  local api = mod.api or ModRegistry.API_VERSION
  assert(api == ModRegistry.API_VERSION,
    ("mod %s requires API %s; registry provides API %d")
      :format(mod.id, tostring(api), ModRegistry.API_VERSION))
end

function ModRegistry.new()
  return setmetatable({ namespaces = {}, mods = {} }, ModRegistry)
end

-- `base` is copied on registration and never mutated by a registry fold.
function ModRegistry:registerNamespace(name, opts)
  assert(type(name) == "string" and name ~= "", "namespace name is required")
  assert(not self.namespaces[name], "namespace already registered: " .. name)
  opts = opts or {}
  local semantics = opts.semantics or "record"
  assert(semantics == "record" or semantics == "deep",
    "namespace semantics must be record or deep")
  self.namespaces[name] = {
    name = name, semantics = semantics, base = copy(opts.base or {}), ops = {},
  }
  return self
end

local function stage(namespace, owner, op, id, value)
  assert(type(id) == "string" or type(id) == "number", "content id is required")
  if op ~= "remove" then assert(value ~= nil, "content value is required") end
  namespace.ops[#namespace.ops + 1] = {
    owner = owner.id, priority = tonumber(owner.priority) or 0,
    op = op, id = id, value = copy(value), sequence = #namespace.ops + 1,
  }
end

local function facade(self, owner, namespace)
  local source = assert(self.namespaces[namespace], "unknown namespace: " .. tostring(namespace))
  return {
    register = function(_, id, value) stage(source, owner, "register", id, value) end,
    override = function(_, id, value) stage(source, owner, "override", id, value) end,
    patch = function(_, id, value) stage(source, owner, "patch", id, value) end,
    remove = function(_, id) stage(source, owner, "remove", id) end,
  }
end

-- Runs a mod callback transactionally. The callback receives a tiny stable
-- facade: `mod:content("moves"):patch(100, {power = 70})`.
function ModRegistry:apply(mod, callback)
  assertMod(mod)
  assert(type(callback) == "function", "mod callback must be a function")
  assert(not self.mods[mod.id], "mod already applied: " .. mod.id)
  local before = {}
  for name, namespace in pairs(self.namespaces) do before[name] = #namespace.ops end
  local api = {
    id = mod.id,
    content = function(_, name) return facade(self, mod, name) end,
  }
  local ok, err = pcall(callback, api)
  if not ok then
    for name, namespace in pairs(self.namespaces) do
      for i = #namespace.ops, before[name] + 1, -1 do table.remove(namespace.ops, i) end
    end
    return nil, err
  end
  self.mods[mod.id] = { id=mod.id, priority=tonumber(mod.priority) or 0 }
  return true
end

-- Removes every operation registered by one mod. A headless loader uses this
-- to make a multi-mod load transactional when a later dependency fails.
function ModRegistry:rollback(ownerId)
  for _, namespace in pairs(self.namespaces) do
    for i = #namespace.ops, 1, -1 do
      if namespace.ops[i].owner == ownerId then table.remove(namespace.ops, i) end
    end
  end
  self.mods[ownerId] = nil
end

local function ordered(ops)
  local out = {}
  for i, op in ipairs(ops) do out[i] = op end
  table.sort(out, function(a, b)
    if a.priority ~= b.priority then return a.priority < b.priority end
    if a.owner ~= b.owner then return a.owner < b.owner end
    return a.sequence < b.sequence
  end)
  return out
end

function ModRegistry:resolve(namespaceName)
  local namespace = assert(self.namespaces[namespaceName], "unknown namespace: " .. tostring(namespaceName))
  local values, provenance, baseIds = copy(namespace.base), {}, {}
  for id in pairs(namespace.base) do baseIds[id] = true end
  for _, op in ipairs(ordered(namespace.ops)) do
    local exists = values[op.id] ~= nil
    if op.op == "register" then
      assert(not exists, ("%s:%s already exists; %s must use override")
        :format(namespaceName, tostring(op.id), op.owner))
      values[op.id], provenance[op.id] = copy(op.value), op.owner
    elseif op.op == "override" then
      values[op.id], provenance[op.id] = copy(op.value), op.owner
    elseif op.op == "patch" then
      assert(exists, ("%s:%s cannot be patched because it does not exist")
        :format(namespaceName, tostring(op.id)))
      assert(namespace.semantics == "deep", namespaceName .. " does not support deep patches")
      values[op.id], provenance[op.id] = deepMerge(values[op.id], op.value), op.owner
    else -- remove
      values[op.id], provenance[op.id] = nil, op.owner
    end
  end
  return values, provenance
end

function ModRegistry:provenance(namespace, id)
  local _, provenance = self:resolve(namespace)
  return provenance[id]
end

return ModRegistry
