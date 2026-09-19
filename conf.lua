function love.conf(t)
  t.identity = "firered-recomp"
  t.window.title = "FireRed ReComp (Phase 2 — rendering, no gameplay yet)"
  local capture240 = os.getenv("POKEPORT_CAPTURE_240") == "1"
  t.window.width = capture240 and 240 or 850
  t.window.height = capture240 and 160 or 800
  t.window.resizable = not capture240
  t.version = "11.5"
  t.modules.joystick = false
  t.modules.physics = false
end
