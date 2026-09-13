-- Source-level seam check: normal field rendering and the ROM replay both
-- use the same pure camera geometry rather than a parallel crop formula.
local f = assert(io.open("main.lua", "rb")); local source = f:read("*a"); f:close()
assert(source:find('require("src.core.CameraViewport")', 1, true))
assert(source:find("currentWalkCamera()", 1, true))
assert(source:find('world.cameraViewport.worldToScreen(camera, npcX', 1, true))
assert(source:find('world.cameraViewport.worldToScreen(camera, playerCompositedX', 1, true))
assert(source:find('runtimeReplay == "phase2_camera_viewport"', 1, true))
local script = assert(io.open("scripts/runtime_camera_viewport_replay.sh", "rb"))
local replay = script:read("*a"); script:close()
assert(replay:find("POKEPORT_MAP=3,19", 1, true))
assert(replay:find("POKEPORT_WALK=1", 1, true))
assert(replay:find("phase2_camera_viewport PASS", 1, true))
print("PASS: Phase 2 camera viewport integration contract")
