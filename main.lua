-- Phase 1+2 shell: boots a window, verifies a ROM if POKEPORT_ROM points at
-- one, composites a real map into an image and draws it (defaults to
-- Pallet Town; POKEPORT_MAP=group,num for any other), and offers three
-- more views: V for the Phase 1 read-only data viewer (species/moves/
-- trainers/maps), T for the composited title screen (logo + box art +
-- copyright/press-start + border backdrop -- see TitleScreen.lua for what
-- isn't done yet, mainly the animated flame sprites), P for the player's
-- overworld sprite (the first actual OBJ/sprite graphic decoded, as
-- opposed to a background tilemap -- see ObjectSprite.lua). Rendering is
-- integer-scaled and letterboxed to fit the window (ViewportScale.lua).
-- No gameplay, no camera, no moving/animated anything yet: this is "can we
-- turn ROM bytes into recognizable pictures," not a game. See
-- ../firered-recomp-roadmap.md Phase 2 for the real renderer.

local Version = require("src.core.Version")
local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local MapHeader = require("import.MapHeader")
local MapLayout = require("import.MapLayout")
local MapBlockData = require("import.MapBlockData")
local MapBorder = require("import.MapBorder")
local MapCompositor = require("import.MapCompositor")
local DataViewer = require("src.core.DataViewer")
local TitleScreen = require("import.TitleScreen")
local ViewportScale = require("src.core.ViewportScale")
local ObjectSprite = require("import.ObjectSprite")
local Font = require("import.Font")
local TextWindow = require("import.TextWindow")
local TaskScheduler = require("src.core.TaskScheduler")
local Charmap = require("import.Charmap")
local TextRenderer = require("import.TextRenderer")
local GbaGraphics = require("import.GbaGraphics")
local InputState = require("src.core.InputState")

local BORDER_MARGIN_METATILES = 2

local MAP_PALLET_TOWN = 3 * 256 + 0 -- group 3, num 0

-- POKEPORT_MAP=group,num overrides the default map (Pallet Town) -- used to
-- spot-check the compositor generalizes beyond the one map it was built
-- against, e.g. POKEPORT_MAP=3,19 (Route 1) or POKEPORT_MAP=4,0 (Pallet
-- Town's Player's House 1F, an indoor map with a different tileset).
local function selectedMapId()
  local override = os.getenv("POKEPORT_MAP")
  if not override then return MAP_PALLET_TOWN end
  local group, num = override:match("^(%d+),(%d+)$")
  if not group then return MAP_PALLET_TOWN end
  return tonumber(group) * 256 + tonumber(num)
end

local statusLines = {}
local mapImage
local titleImage
local titleActive = false
local spriteImage
local spriteActive = false
local fontImage
local fontActive = false
local fontData, fontAddrs, fontPalette
local fontTokens
local fontTotalCharCount = 0
local fontRevealedCount = 0
local fontBuiltRevealedCount = -1 -- forces a rebuild the first time fontImage is needed
local fontWindowImage -- the static border frame (TextWindow.lua), built once

-- Real task scheduler (src/core/TaskScheduler.lua), ticked at a fixed 1/60s
-- step in love.update -- matches the real game's VBlank-synced RunTasks().
-- Drives per-character text reveal on the font sample view (the "text
-- speed" checklist item); title-screen flame animation frame stepping will
-- reuse the same scheduler once that's built.
local scheduler = TaskScheduler.new()

-- Real input-repeat state (src/core/InputState.lua, ported from
-- pokefirered's ReadKeys). Drives the data viewer's Up/Down navigation:
-- holding the key repeats it after the real 40-tick delay, then every 5
-- ticks, instead of only stepping once per physical keypress -- the
-- Phase 2 "input repeat" checklist item.
local inputState = InputState.new()

-- CHARS_PER_TICK: reveals 1 character every N scheduler ticks (60 ticks =
-- 1 real second), i.e. a fixed text speed. The real game has 3 selectable
-- text speeds (SLOW/MID/FAST, options_menu.c) driving the same kind of
-- per-character delay; this project doesn't have a settings UI yet
-- (checklist: "display settings" still open), so FAST's rough feel (a
-- handful of characters per second) is hardcoded here.
local FONT_REVEAL_TICKS_PER_CHAR = 4
local function fontRevealTask(taskId)
  local data = scheduler:data(taskId)
  data.tickCount = (data.tickCount or 0) + 1
  if data.tickCount >= FONT_REVEAL_TICKS_PER_CHAR then
    data.tickCount = 0
    if fontRevealedCount < fontTotalCharCount then
      fontRevealedCount = fontRevealedCount + 1
    end
  end
end

-- Slices a Charmap.tokenize() list down to "the first N revealed
-- characters, plus every non-char token (color switches, etc.) up to that
-- point" -- so a color switch that happened before the Nth character is
-- still in effect for the partial reveal, matching how the real printer
-- processes control codes immediately but glyphs one at a time.
local function sliceTokensByRevealedChars(tokens, revealedCharCount)
  local sliced = {}
  local charCount = 0
  for _, token in ipairs(tokens) do
    if token.type == "char" then
      if charCount >= revealedCharCount then break end
      charCount = charCount + 1
    end
    sliced[#sliced + 1] = token
  end
  return sliced
end

-- Set once the ROM verifies, so the data viewer (toggled at any time with
-- V) can browse records without re-reading the file.
local romData, romAddrs

-- Data viewer state: which category/record is being browsed, and whether
-- the viewer is showing instead of the map.
local viewerActive = false
local viewerCategoryIndex = 1 -- index into DataViewer.CATEGORIES
local viewerRecordIndex = { species = 1, moves = 1, trainers = 0, maps = 3 * 256 + 0 }

-- Charmap.lua only decodes ROM bytes -> characters, not the reverse; A-Z
-- are contiguous (0xBB-0xD4, confirmed in Charmap.lua) so this small
-- inline table is enough for the sample string below without needing a
-- general encoder.
local function charmapBytesForUppercaseAndSpaces(text)
  local bytes = {}
  for i = 1, #text do
    local c = text:sub(i, i)
    if c == " " then
      bytes[#bytes + 1] = 0x00
    else
      bytes[#bytes + 1] = 0xBB + (string.byte(c) - string.byte("A"))
    end
  end
  return string.char(unpack(bytes))
end

local function addLine(text)
  table.insert(statusLines, text)
end

-- Builds a love.graphics.Image from a MapCompositor/TitleScreen/
-- ObjectSprite composite result. Respects per-pixel alpha if the source
-- provides it (ObjectSprite does, for transparent sprite backgrounds);
-- defaults to fully opaque otherwise (maps/title screens never have holes).
local function buildImage(compositedMap)
  local imageData = love.image.newImageData(compositedMap.width, compositedMap.height)
  for y = 0, compositedMap.height - 1 do
    for x = 0, compositedMap.width - 1 do
      local color = compositedMap.getPixel(x, y)
      imageData:setPixel(x, y, color.r / 255, color.g / 255, color.b / 255, color.a or 1)
    end
  end
  return love.graphics.newImage(imageData)
end

local function loadMapFromRom(romPath)
  local ok, info = RomImporter.verify(romPath)
  if not ok then
    addLine("ROM verification failed: " .. tostring(info))
    return
  end
  addLine(("ROM verified: %s v%s"):format(info.name, info.revision))

  local sha1 = RomImporter._sha1Hex((function()
    local f = io.open(romPath, "rb")
    local data = f:read("*a")
    f:close()
    return data
  end)())
  local addrs = RomAddresses[sha1]
  if not addrs then
    addLine("No known table addresses for this ROM's sha1.")
    return
  end

  local f = io.open(romPath, "rb")
  local data = f:read("*a")
  f:close()
  romData, romAddrs = data, addrs

  local DEBUG = os.getenv("POKEPORT_DEBUG") == "1"
  local function dbg(msg) if DEBUG then print("[dbg] " .. msg) io.stdout:flush() end end

  local mapId = selectedMapId()
  dbg("selectedMapId " .. mapId)
  local header = MapHeader.resolve(data, addrs.gMapGroups, mapId)
  dbg("header resolved")
  local layout = MapLayout.resolve(data, header.mapLayoutPtr)
  dbg("layout resolved " .. layout.width .. "x" .. layout.height)
  local blockData = MapBlockData.resolve(data, layout.mapPtr, layout.width, layout.height)
  dbg("blockData resolved")
  local border = MapBorder.resolve(data, layout.borderPtr, layout.borderWidth, layout.borderHeight)
  dbg("border resolved")
  local primary = MapCompositor.loadTilesetData(data, layout.primaryTilesetPtr)
  dbg("primary tileset loaded, tiles=" .. #primary.tiles)
  local secondary = MapCompositor.loadTilesetData(data, layout.secondaryTilesetPtr)
  dbg("secondary tileset loaded, tiles=" .. #secondary.tiles)
  local composited = MapCompositor.compositeWithBorder(data, primary, secondary, blockData, layout.width, layout.height, border, layout.borderWidth, layout.borderHeight, BORDER_MARGIN_METATILES)
  dbg("composited " .. composited.width .. "x" .. composited.height)

  addLine(("Composited map %d,%d: %dx%d metatiles, %dx%d px"):format(math.floor(mapId / 256), mapId % 256, layout.width, layout.height, composited.width, composited.height))
  mapImage = buildImage(composited)
  dbg("image built")
  mapImage:setFilter("nearest", "nearest")
  dbg("filter set")

  addLine("Press V for the data viewer, T for the title screen, P for a sprite, F for font rendering.")

  local titleOk, titleComposited = pcall(TitleScreen.compositeFull, data, addrs)
  if titleOk then
    titleImage = buildImage(titleComposited)
    titleImage:setFilter("nearest", "nearest")
    dbg("title logo built")
  else
    dbg("title logo failed: " .. tostring(titleComposited))
  end

  local spriteOk, spriteComposited = pcall(ObjectSprite.decodeFrame, data, addrs.gObjectEventPic_RedNormal, addrs.gObjectEventPal_Player, 2, 4, 0)
  if spriteOk then
    spriteImage = buildImage(spriteComposited)
    spriteImage:setFilter("nearest", "nearest")
    dbg("player sprite built")
  else
    dbg("player sprite failed: " .. tostring(spriteComposited))
  end

  fontData, fontAddrs = data, addrs
  -- "POKEMON " in the default color, then a real EXT_CTRL_CODE_COLOR
  -- switch (FC 01 04, TEXT_COLOR_RED) partway through, then "FIRERED" --
  -- demonstrates TextRenderer actually acting on control codes rather
  -- than just displaying them as bracketed text (Charmap.decode's job).
  local message = charmapBytesForUppercaseAndSpaces("POKEMON ") .. string.char(0xFC, 0x01, 0x04) .. charmapBytesForUppercaseAndSpaces("FIRERED") .. string.char(Charmap.TERMINATOR)
  fontTokens = Charmap.tokenize(message)
  fontTotalCharCount = 0
  for _, t in ipairs(fontTokens) do
    if t.type == "char" then fontTotalCharCount = fontTotalCharCount + 1 end
  end
  fontPalette = GbaGraphics.decodePalette(data, addrs.gTextWindowPalettes) -- gTextWindowPalettes[0], the overworld dialogue box's bank
  fontRevealedCount = 0
  fontBuiltRevealedCount = -1
  scheduler:createTask(fontRevealTask, 0)
  dbg("font reveal task created")

  local windowOk, windowComposited = pcall(function()
    local tiles = TextWindow.decodeFrameTiles(data, addrs.gStdTextWindow_Gfx)
    local palette = TextWindow.decodePalette(data, addrs.gTextWindowPalettes, TextWindow.STD_PALETTE_INDEX)
    return TextWindow.compositeFrame(tiles, palette, 14, 2) -- 14x2 tiles fits "POKEMON FIRERED" (~13 tiles wide, 2 tall)
  end)
  if windowOk then
    fontWindowImage = buildImage(windowComposited)
    fontWindowImage:setFilter("nearest", "nearest")
    dbg("text window frame built")
  else
    dbg("text window frame failed: " .. tostring(windowComposited))
  end
end

-- Rebuilds fontImage only when the revealed character count has actually
-- changed since the last draw (rebuilding a love.Image every frame for a
-- static count would be wasted work).
local function ensureFontImageCurrent()
  if not fontData or fontRevealedCount == fontBuiltRevealedCount then return end
  if fontRevealedCount == 0 then
    fontImage = nil
  else
    local sliced = sliceTokensByRevealedChars(fontTokens, fontRevealedCount)
    local ok, composited = pcall(TextRenderer.renderTokens, fontData, fontAddrs, sliced, fontPalette)
    if ok then
      fontImage = buildImage(composited)
      fontImage:setFilter("nearest", "nearest")
    end
  end
  fontBuiltRevealedCount = fontRevealedCount
end

-- ---------------------------------------------------------------- viewer

local function viewerCategory()
  return DataViewer.CATEGORIES[viewerCategoryIndex]
end

local function viewerLines()
  if not romData then return { "No ROM loaded." } end
  local category = viewerCategory()
  local index = viewerRecordIndex[category]
  local lines = { ("[%s] record %s  (Tab: category, Up/Down: -+1, PgUp/PgDn: -+10, V: back to map)"):format(category, tostring(index)) }
  local ok, described = pcall(DataViewer.describe, romData, romAddrs, category, index)
  if ok then
    for _, l in ipairs(described) do lines[#lines + 1] = l end
  else
    lines[#lines + 1] = "Error: " .. tostring(described)
  end
  return lines
end

local function viewerStep(delta)
  local category = viewerCategory()
  if category == "maps" then
    -- Step the map number within the current group; Left/Right (handled
    -- separately) steps the group.
    local group = math.floor(viewerRecordIndex.maps / 256)
    local num = (viewerRecordIndex.maps % 256) + delta
    if num < 0 then num = 0 end
    if num > 255 then num = 255 end
    viewerRecordIndex.maps = group * 256 + num
  else
    viewerRecordIndex[category] = viewerRecordIndex[category] + delta
    if viewerRecordIndex[category] < 0 then viewerRecordIndex[category] = 0 end
  end
end

local function viewerStepGroup(delta)
  if viewerCategory() ~= "maps" then return end
  local group = math.floor(viewerRecordIndex.maps / 256) + delta
  local num = viewerRecordIndex.maps % 256
  if group < 0 then group = 0 end
  if group > 255 then group = 255 end
  viewerRecordIndex.maps = group * 256 + num
end

function love.load()
  love.window.setTitle(Version.title .. " " .. Version.version)
  addLine(Version.title .. " " .. Version.version)

  local romPath = os.getenv("POKEPORT_ROM")
  if not romPath then
    addLine("Set POKEPORT_ROM=/path/to/rom.gba to see real tile graphics decoded from it.")
    return
  end

  local okCall, errMsg = pcall(loadMapFromRom, romPath)
  if not okCall then
    addLine("Error: " .. tostring(errMsg))
  end

  -- POKEPORT_VIEWER=category:index boots straight into the data viewer on
  -- that record, e.g. POKEPORT_VIEWER=species:1 -- used for automated
  -- screenshot verification without needing real keypresses.
  local viewerOverride = os.getenv("POKEPORT_VIEWER")
  if viewerOverride then
    local category, index = viewerOverride:match("^(%a+):(-?%d+)$")
    if category and viewerRecordIndex[category] ~= nil then
      viewerActive = true
      for i, c in ipairs(DataViewer.CATEGORIES) do
        if c == category then viewerCategoryIndex = i end
      end
      viewerRecordIndex[category] = tonumber(index)
    end
  end

  -- POKEPORT_TITLE=1 boots straight into the title screen logo view.
  if os.getenv("POKEPORT_TITLE") == "1" then
    titleActive = true
  end

  -- POKEPORT_SPRITE=1 boots straight into the player-sprite view.
  if os.getenv("POKEPORT_SPRITE") == "1" then
    spriteActive = true
  end

  -- POKEPORT_FONT=1 boots straight into the font-rendering sample view.
  if os.getenv("POKEPORT_FONT") == "1" then
    fontActive = true
  end

  -- love.filesystem is sandboxed to the save directory (see conf.lua's
  -- identity="firered-recomp"), so this always writes there under a fixed
  -- name rather than to an arbitrary POKEPORT_SCREENSHOT path.
  if os.getenv("POKEPORT_SCREENSHOT") == "1" and (mapImage or viewerActive or titleActive or spriteActive or fontActive) then
    -- The font sample normally reveals one character at a time (real text
    -- speed, driven by TaskScheduler in love.update); automated screenshots
    -- want the deterministic finished state instead of whatever partial
    -- reveal happened to be on-screen at capture time.
    fontRevealedCount = fontTotalCharCount
    love.graphics.captureScreenshot(function(imageData)
      imageData:encode("png", "screenshot.png")
      love.event.quit()
    end)
  end
end

-- Ticks the real task scheduler at a fixed 1/60s step regardless of the
-- actual frame rate (matches the real hardware's fixed-59.7Hz VBlank tick
-- driving RunTasks() -- see TaskScheduler.lua), so text reveal speed
-- doesn't depend on how fast this machine renders frames.
local FIXED_TICK = 1 / 60
local tickAccumulator = 0
function love.update(dt)
  tickAccumulator = tickAccumulator + dt
  while tickAccumulator >= FIXED_TICK do
    tickAccumulator = tickAccumulator - FIXED_TICK
    scheduler:runTasks()

    inputState:update(InputState.buildMask({
      DPAD_UP = love.keyboard.isDown("up"),
      DPAD_DOWN = love.keyboard.isDown("down"),
    }))
    if viewerActive then
      if inputState:isPressedOrRepeated(InputState.DPAD_DOWN) then viewerStep(1) end
      if inputState:isPressedOrRepeated(InputState.DPAD_UP) then viewerStep(-1) end
    end
  end
end

function love.draw()
  if fontActive then ensureFontImageCurrent() end
  if spriteActive then
    love.graphics.clear(0.4, 0.7, 0.3) -- solid backdrop so sprite transparency is visible
  else
    love.graphics.clear(0.08, 0.08, 0.1)
  end
  local y = 20
  for _, line in ipairs(statusLines) do
    love.graphics.print(line, 20, y)
    y = y + 20
  end

  if viewerActive then
    y = y + 10
    for _, line in ipairs(viewerLines()) do
      love.graphics.print(line, 20, y)
      y = y + 20
    end
  elseif spriteActive and spriteImage then
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local viewport = ViewportScale.fit(spriteImage:getWidth(), spriteImage:getHeight(), windowWidth - 40, windowHeight - (y + 10))
    love.graphics.draw(spriteImage, 20 + viewport.x, y + 10 + viewport.y, 0, viewport.scale, viewport.scale)
  elseif fontActive and fontWindowImage then
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local viewport = ViewportScale.fit(fontWindowImage:getWidth(), fontWindowImage:getHeight(), windowWidth - 40, windowHeight - (y + 10))
    love.graphics.draw(fontWindowImage, 20 + viewport.x, y + 10 + viewport.y, 0, viewport.scale, viewport.scale)
    if fontImage then
      -- TextWindow.TILE_SIZE (8px) inset places the text inside the
      -- frame's transparent interior, one border tile in from the top-left.
      love.graphics.draw(fontImage, 20 + viewport.x + TextWindow.TILE_SIZE * viewport.scale, y + 10 + viewport.y + TextWindow.TILE_SIZE * viewport.scale, 0, viewport.scale, viewport.scale)
    end
  elseif titleActive and titleImage then
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local viewport = ViewportScale.fit(titleImage:getWidth(), titleImage:getHeight(), windowWidth - 40, windowHeight - (y + 10))
    love.graphics.draw(titleImage, 20 + viewport.x, y + 10 + viewport.y, 0, viewport.scale, viewport.scale)
  elseif mapImage then
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local viewport = ViewportScale.fit(mapImage:getWidth(), mapImage:getHeight(), windowWidth - 40, windowHeight - (y + 10))
    love.graphics.draw(mapImage, 20 + viewport.x, y + 10 + viewport.y, 0, viewport.scale, viewport.scale)
  end
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  elseif key == "v" then
    viewerActive = not viewerActive
    titleActive = false
    spriteActive = false
    fontActive = false
  elseif key == "t" then
    titleActive = not titleActive
    viewerActive = false
    spriteActive = false
    fontActive = false
  elseif key == "p" then
    spriteActive = not spriteActive
    viewerActive = false
    titleActive = false
    fontActive = false
  elseif key == "f" then
    fontActive = not fontActive
    viewerActive = false
    titleActive = false
    spriteActive = false
  elseif viewerActive then
    -- Up/Down are handled in love.update via InputState (real input-repeat
    -- timing), not here -- a plain keypressed step-once would double-step
    -- alongside the repeat-driven update.
    if key == "tab" then
      viewerCategoryIndex = (viewerCategoryIndex % #DataViewer.CATEGORIES) + 1
    elseif key == "pagedown" then
      viewerStep(10)
    elseif key == "pageup" then
      viewerStep(-10)
    elseif key == "right" then
      viewerStepGroup(1)
    elseif key == "left" then
      viewerStepGroup(-1)
    end
  end
end
