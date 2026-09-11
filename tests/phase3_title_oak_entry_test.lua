local function read(path)
  local f = assert(io.open(path, "rb"))
  local data = f:read("*a")
  f:close()
  return data
end

local source = read("main.lua")

local function expect(needle, label)
  assert(source:find(needle, 1, true), "missing title/Oak entry contract: " .. label)
end

-- Focused seam guard. The runtime replay is the behavioral proof; this
-- plain-Lua test prevents the narrow title input route from silently
-- regressing or being replaced by a direct post-Oak bootstrap.
expect("elseif titleActive and (inputState:isNewlyPressed(InputState.A_BUTTON)",
  "title accepts normal A input")
expect("or inputState:isNewlyPressed(InputState.START_BUTTON)) then",
  "title accepts normal START input")
expect("world.clearViews()\n      oakSceneActive = true",
  "title enters existing Oak scene")
expect("elseif oakSceneActive and inputState:isNewlyPressed(InputState.A_BUTTON) then",
  "Oak scene continues through normal A input")
expect("beginNewGameFlow()", "Oak continues into existing identity flow")
expect("runtimeReplay == \"title_oak_entry\"", "route-specific runtime replay exists")
expect("RUNTIME_REPLAY title_oak_entry %s", "runtime replay emits machine-readable result")

-- The replay must not call the direct session constructor; session creation
-- stays behind completion of the existing NewGameFlow/bootstrap boundary.
local replayStart = assert(source:find('elseif runtimeReplay == "title_oak_entry"', 1, true))
local replayEnd = assert(source:find('elseif runtimeReplay == "house_to_pallet"', replayStart, true))
local replay = source:sub(replayStart, replayEnd - 1)
assert(not replay:find("GameSession.fromNewGame", 1, true), "replay must not inject a post-Oak session")
assert(replay:find("press(InputState.START_BUTTON)", 1, true), "replay must drive title via START")
assert(replay:find("press(InputState.A_BUTTON)", 1, true), "replay must drive Oak/identity via A")

print("PASS: Phase 3 title -> Oak entry seam contract")
