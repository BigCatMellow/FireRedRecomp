-- One headless lifecycle for package discovery, sandboxed entrypoints,
-- transactional content application, and save-profile generation.

local Registry = require("src.core.ModRegistry")
local Loader = require("src.core.ModLoader")
local Packages = require("src.core.ModPackages")
local Json = require("src.core.ModJson")
local Entrypoint = require("src.core.ModEntrypoint")
local Manifest = require("src.core.ModManifest")
local Compatibility = require("src.core.ModSaveCompatibility")
local Hooks = require("src.core.ModHooks")

local Runtime = {}
Runtime.__index = Runtime

local function discover(fs, root)
  return Packages.discover(fs, root, Json.decode, function(source, path)
    local callback, err = Entrypoint.compile(source, path)
    assert(callback, err)
    return callback
  end)
end

function Runtime.new(opts)
  opts = opts or {}
  assert(type(opts) == "table", "mod runtime options must be a table")
  local registry = opts.registry or Registry.new()
  assert(type(opts.namespaces or {}) == "table", "mod runtime namespaces must be an array")
  for _, entry in ipairs(opts.namespaces or {}) do
    assert(type(entry) == "table" and type(entry.name) == "string",
      "mod runtime namespace needs name")
    registry:registerNamespace(entry.name, entry.options)
  end
  return setmetatable({
    registry=registry, loader=Loader.new(registry), loaded={},
    hooks=opts.hooks or Hooks.new(), profile=Compatibility.profile({}),
  }, Runtime)
end

-- Headless SDK validation always checks package layout, strict manifests,
-- dependencies/conflicts, and sandboxed entry compilation. Supplying a
-- declared host (`{ namespaces = ... }`, the same shape as Runtime.new)
-- additionally executes callbacks in a fresh transactional registry and
-- resolves every declared namespace. That catches unknown namespaces and
-- invalid content operations without mutating importer data or a live host.
function Runtime.validate(fs, root, host)
  local ok, entriesOrError = pcall(discover, fs, root)
  if not ok then return nil, tostring(entriesOrError) end
  local manifests = {}
  for i, entry in ipairs(entriesOrError) do manifests[i] = entry.manifest end
  local orderedOk, orderedOrError = pcall(Manifest.order, manifests)
  if not orderedOk then return nil, tostring(orderedOrError) end
  if host == nil then return orderedOrError end

  assert(type(host) == "table", "mod validation host must be a table")
  assert(type(host.namespaces or {}) == "table", "mod validation host namespaces must be an array")
  -- Do not accept a caller-owned registry or hooks here: validation must use
  -- a fresh registry so it can never mutate a live host by accident.
  local runtime = Runtime.new({ namespaces=host.namespaces })
  local loaded, loadError = runtime:load(fs, root)
  if not loaded then return nil, loadError end

  -- Registry operations such as `patch` are deliberately lazy until a
  -- consumer resolves its namespace. Force that validation here, then unload
  -- even on failure so this dry run cannot retain operations or hooks.
  local resolvedOk, resolvedError = pcall(function()
    for _, entry in ipairs(host.namespaces or {}) do runtime:resolve(entry.name) end
  end)
  runtime:unload()
  if not resolvedOk then return nil, tostring(resolvedError) end
  return orderedOrError
end

-- Discovers and loads one enabled package set. Every failure is reported as a
-- return value; the registry stays unchanged because discovery is read-only
-- and ModLoader rolls back callbacks as one transaction.
function Runtime:load(fs, root)
  assert(#self.loaded == 0, "mod runtime is already loaded; call unload first")
  local ok, entriesOrError = pcall(discover, fs, root)
  if not ok then return nil, tostring(entriesOrError) end
  -- Add the hook facade only at callback execution time. A callback that
  -- fails after registering hooks is cleaned immediately; a later package
  -- failure is cleaned below along with every earlier owner.
  for _, entry in ipairs(entriesOrError) do
    local callback, manifest = entry.callback, entry.manifest
    entry.callback = function(mod)
      mod.hook = function(_, name, hookCallback)
        return self.hooks:wrap(name, manifest, hookCallback)
      end
      local callbackOk, callbackResult = pcall(callback, mod)
      if not callbackOk then
        self.hooks:removeOwner(manifest.id)
        error(callbackResult, 0)
      end
      return callbackResult
    end
  end
  local loadOk, loaded, err = pcall(self.loader.load, self.loader, entriesOrError)
  if not loadOk or not loaded then
    for _, entry in ipairs(entriesOrError) do self.hooks:removeOwner(entry.manifest.id) end
    return nil, loadOk and err or tostring(loaded)
  end
  self.loaded = loaded
  self.profile = Compatibility.profile(loaded)
  return loaded
end

function Runtime:unload()
  for i = #self.loaded, 1, -1 do
    self.registry:rollback(self.loaded[i].id)
    self.hooks:removeOwner(self.loaded[i].id)
  end
  self.loaded, self.loader.loaded = {}, {}
  self.profile = Compatibility.profile({})
end

function Runtime:resolve(namespace)
  return self.registry:resolve(namespace)
end

return Runtime
