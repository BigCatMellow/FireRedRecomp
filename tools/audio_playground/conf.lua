-- Standalone LOVE2D mini-project for manually verifying real GBA cry
-- playback (import/WaveData.lua + src/core/AudioPlayer.lua). Fully separate
-- from the real project's main.lua/conf.lua -- never touches either, so it's
-- safe to run alongside whoever is editing the real main.lua / TitleScreen.
function love.conf(t)
  t.window.title = "FireRed ReComp -- audio playground"
  t.window.width = 480
  t.window.height = 240
  t.console = true
end
