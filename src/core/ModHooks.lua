-- Deterministic extension hooks for ModRegistry API v1 consumers.
--
-- A hook is a conventional around-call: callback(nextFn, ...) may inspect or
-- replace arguments/results, and can decline to call nextFn. Hooks sort by
-- ascending priority, then lexical owner id, then registration order. The
-- module is pure Lua; a future loader owns sandboxing and mod-disable policy.

local ModHooks = {}
ModHooks.__index = ModHooks
local unpack = table.unpack or unpack

local function pack(...)
  return { n=select("#", ...), ... }
end

local function assertOwner(owner)
  assert(type(owner) == "table" and type(owner.id) == "string"
    and owner.id:match("^[%w_%-]+$"), "hook owner needs a valid mod id")
end

function ModHooks.new()
  return setmetatable({ chains = {}, sequence = 0 }, ModHooks)
end

function ModHooks:wrap(name, owner, callback)
  assert(type(name) == "string" and name ~= "", "hook name is required")
  assertOwner(owner)
  assert(type(callback) == "function", "hook callback must be a function")
  self.sequence = self.sequence + 1
  local entry = { owner=owner.id, priority=tonumber(owner.priority) or 0,
    callback=callback, sequence=self.sequence }
  local chain = self.chains[name] or {}
  self.chains[name] = chain
  chain[#chain + 1] = entry
  table.sort(chain, function(a, b)
    if a.priority ~= b.priority then return a.priority < b.priority end
    if a.owner ~= b.owner then return a.owner < b.owner end
    return a.sequence < b.sequence
  end)
  return function()
    for i, candidate in ipairs(chain) do
      if candidate == entry then table.remove(chain, i); break end
    end
    if #chain == 0 then self.chains[name] = nil end
  end
end

function ModHooks:call(name, vanilla, ...)
  assert(type(vanilla) == "function", "hook vanilla function is required")
  local chain = self.chains[name]
  if not chain or #chain == 0 then return vanilla(...) end
  local function invoke(index, args)
    if index > #chain then return pack(vanilla(unpack(args, 1, args.n))) end
    local entry = chain[index]
    local usedNext = false
    local function nextFn(...)
      assert(not usedNext, ("hook %s called next more than once"):format(entry.owner))
      usedNext = true
      local nextArgs = select("#", ...) == 0 and args or pack(...)
      local result = invoke(index + 1, nextArgs)
      return unpack(result, 1, result.n)
    end
    return pack(entry.callback(nextFn, unpack(args, 1, args.n)))
  end
  local result = invoke(1, pack(...))
  return unpack(result, 1, result.n)
end

function ModHooks:removeOwner(ownerId)
  for name, chain in pairs(self.chains) do
    for i = #chain, 1, -1 do
      if chain[i].owner == ownerId then table.remove(chain, i) end
    end
    if #chain == 0 then self.chains[name] = nil end
  end
end

return ModHooks
