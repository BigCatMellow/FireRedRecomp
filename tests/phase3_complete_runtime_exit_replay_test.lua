local function read(path)
  local f = assert(io.open(path, "rb"))
  local data = f:read("*a")
  f:close()
  return data
end

local source = read("main.lua")
local script = read("scripts/runtime_phase3_complete_exit_replay.sh")

assert(source:find('runtimeReplay == "phase3_complete_exit_save"', 1, true), "missing complete runtime route")
local start = assert(source:find('if replayCompleteExit then', 1, true))
local finish = assert(source:find('else\n      beginNewGameFlow()', start, true))
local entry = source:sub(start, finish - 1)
assert(entry:find('press(InputState.START_BUTTON)', 1, true), "complete route must use title START")
assert(entry:find('press(InputState.A_BUTTON)', 1, true), "complete route must use Oak A")
assert(not entry:find('GameSession.fromNewGame', 1, true), "complete route must not inject a session")
assert(source:find('reachedPallet = walkMapId == MAP_PALLET_TOWN', 1, true), "missing Pallet continuity assertion")
assert(source:find('lead.hp == lead.maxHP', 1, true), "missing defeat recovery assertion")
assert(source:find('or replayCompleteExit) then', 1, true), "complete route must save through normal callback")
assert(script:find('phase3_complete_exit_save', 1, true), "wrapper must run complete normal-boot route")
assert(script:find('run_replay restart_load', 1, true), "wrapper must use a fresh-process reload")
assert(script:find('RUNTIME_REPLAY phase3_complete_exit PASS', 1, true), "wrapper must emit one complete PASS marker")

print("PASS: Phase 3 complete runtime exit replay contract")
