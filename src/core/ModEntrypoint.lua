-- Sandboxed compiler for trusted local mod entrypoints. The resulting
-- callback only receives the registry API supplied by ModLoader; package
-- source gets no implicit filesystem, process, or host-global authority.

local Entrypoint = {}

local function copyLibrary(source)
  local result = {}
  for key, value in pairs(source) do result[key] = value end
  return result
end

local function environment(capabilities)
  local safeMath = copyLibrary(math)
  -- Lua 5.1's random/randomseed share process-global PRNG state. A copied
  -- library table would still expose those host-mutating functions, so mods
  -- receive no ambient RNG until a deterministic capability is deliberately
  -- designed and supplied by a host.
  safeMath.random, safeMath.randomseed = nil, nil
  local env = {
    assert=assert, error=error, ipairs=ipairs, next=next, pairs=pairs,
    select=select, tonumber=tonumber, tostring=tostring, type=type,
    unpack=unpack, math=safeMath, string=copyLibrary(string),
    table=copyLibrary(table),
  }
  for key, value in pairs(capabilities or {}) do
    assert(type(key) == "string" and key:match("^[%a_][%w_]*$"),
      "mod capability name must be an identifier")
    assert(env[key] == nil and key ~= "_G", "mod capability shadows a sandbox builtin: " .. key)
    env[key] = value
  end
  env._G = env
  return env
end

-- Source must evaluate to `function(mod) ... end`. Capabilities are explicit
-- immutable-by-convention values chosen by the host (typically none); they
-- are not a route to ambient globals.
function Entrypoint.compile(source, path, capabilities)
  assert(type(source) == "string", "mod entry source must be a string")
  assert(type(path) == "string" and path ~= "", "mod entry path must be a string")
  assert(capabilities == nil or type(capabilities) == "table", "mod capabilities must be a table")
  local chunk, syntaxError = loadstring(source, "@" .. path)
  if not chunk then return nil, "could not compile mod entry " .. path .. ": " .. syntaxError end
  setfenv(chunk, environment(capabilities))
  local ok, callback = pcall(chunk)
  if not ok then return nil, "could not evaluate mod entry " .. path .. ": " .. tostring(callback) end
  if type(callback) ~= "function" then
    return nil, "mod entry must return a callback: " .. path
  end
  return callback
end

return Entrypoint
