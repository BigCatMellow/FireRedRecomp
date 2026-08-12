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
local TextPrinterState = require("src.core.TextPrinterState")
local Lz77 = require("import.Lz77")
local SpriteAnim = require("import.SpriteAnim")
local SpriteAnimator = require("src.core.SpriteAnimator")
local TitleScreenFlameSpawner = require("src.core.TitleScreenFlameSpawner")
local PaletteFade = require("src.core.PaletteFade")
local PaletteBlend = require("src.core.PaletteBlend")
local MenuCursor = require("src.core.MenuCursor")
local OamShapeSize = require("import.OamShapeSize")
local SlashSprite = require("src.core.SlashSprite")
local SlashMask = require("import.SlashMask")
local AffineAnim = require("import.AffineAnim")
local AffineAnimator = require("src.core.AffineAnimator")
local PlayerMovement = require("src.core.PlayerMovement")

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
-- Title screen is drawn as several separate images (border, then the
-- flame particles, then copyright/box art, then the logo) rather than
-- one flat composite, so the flame OBJ sprites (priority 3, same as the
-- border) can be interleaved at the real draw position between the
-- border and the higher-priority layers (LayerCompositor.lua) instead
-- of always ending up on top of the whole title screen, and so the
-- slash-in effect (which only ever targets the logo -- real
-- BLDCNT_TGT1_BG0) can be composited into just the logo layer.
local titleBorderImage, titleCopyrightBoxArtImage, titleLogoImage
local titleBorderComposited, titleCopyrightBoxArtComposited, titleLogoComposited -- raw { width, height, getPixel } composites, kept around so the fade/slash can re-blend them each step
local titleFade -- PaletteFade.lua: real fade-in-from-white on title screen boot
local titleFadeBuiltY = -1 -- forces a rebuild the first time the title images are needed
local titleSlashSprite -- SlashSprite.lua: real slash-in movement/visibility timing
local titleSlashMask -- SlashMask.lua: isOpaque(x, y) over the slash's real silhouette
local titleLogoBuiltKey -- (fadeY, slashX, slashY, slashInvisible) tuple string, forces a logo rebuild when any of them change
local titleActive = false
local spriteImage
local spriteActive = false
local itemBallImage
local itemBallActive = false
-- Real Pokéball wobble affine animation (AffineAnim.lua/AffineAnimator.lua),
-- applied to the item ball sprite to demonstrate real sprite rotation/
-- scaling data driving actual rendering (love.graphics.draw's native
-- rotate/scale, not a GBA-hardware-accurate affine matrix -- see
-- AffineAnimator.lua's header comment for why that's a fine substitution).
local itemBallAffineAnimator
local fontImage
local fontActive = false
local fontData, fontAddrs, fontPalette
local fontPrinterState -- TextPrinterState.lua: tracks per-character reveal, pauses, wait-for-press
local fontBuiltRevealTokenIndex = -1 -- forces a rebuild the first time fontImage is needed
local fontWindowImage -- the static border frame (TextWindow.lua), built once

local oakSpeechActive = false
local oakSpeechImage
local oakSpeechWindowImage
local oakSpeechPrinterState
local oakSpeechBuiltRevealTokenIndex = -1

-- Phase 3: real grid-based player movement + collision (PlayerMovement.lua)
-- over the already-composited map, camera-cropped to a real GBA-screen-
-- sized (240x160px) viewport centered on the player.
local walkActive = false
local walkMapBlockData, walkMapWidth, walkMapHeight -- raw (unpadded) collision grid, set when the map loads
local playerMovement
local WALK_CAMERA_WIDTH, WALK_CAMERA_HEIGHT = 240, 160 -- real GBA screen resolution

-- isBlocked callback for PlayerMovement:tryMove -- real terrain collision
-- only (MapBlockData's already-decoded collision field, see
-- PlayerMovement.lua's header comment for what's out of scope: object-
-- event collision, elevation, one-way ledges). Off-map tiles (into the
-- border padding) are also treated as blocked, since the border isn't a
-- real walkable area.
local function isWalkTileBlocked(x, y)
  if not walkMapBlockData or x < 0 or x >= walkMapWidth or y < 0 or y >= walkMapHeight then return true end
  local cell = walkMapBlockData[y * walkMapWidth + x]
  return not cell or cell.collision ~= 0
end

local flameActive = false
local flameImage
local flameTiles, flamePalette -- decompressed flame sheet + decoded palette, decoded once
local flameAnimator -- SpriteAnimator.lua, real title screen flame animation
local flameBuiltFrameIndex = -1 -- forces a rebuild the first time flameImage is needed

-- Real title screen flame particle burst (TitleScreenFlameSpawner.lua),
-- composited over the title screen (T view) rather than the standalone
-- single-flame demo (A view) above. flameFrameImageCache maps a
-- particle's current imageValue -> already-built love.Image, since many
-- particles share the same animation frame at once.
local flameSpawner
local flameFrameImageCache = {}

-- Real Yes/No confirmation menu (MenuCursor.lua, ported from
-- CreateYesNoMenu/Menu_MoveCursor/Menu_ProcessInput -- src/menu.c), the
-- most common real menu construct in the game. yesNoResult is nil while
-- undecided, then "confirm" or "cancel" once the player answers.
local yesNoActive = false
local yesNoCursor
local yesNoResult
local yesNoWindowImage, yesNoTextImage, yesNoArrowImage

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

-- FONT_REVEAL_TICKS_PER_CHAR: reveals 1 character every N scheduler ticks
-- (60 ticks = 1 real second), i.e. a fixed text speed. The real game has 3
-- selectable text speeds (SLOW/MID/FAST, options_menu.c) driving the same
-- kind of per-character delay; this project doesn't have a settings UI yet
-- (checklist: "display settings" still open), so FAST's rough feel (a
-- handful of characters per second) is hardcoded here.
local FONT_REVEAL_TICKS_PER_CHAR = 4
local function fontRevealTask(taskId)
  fontPrinterState:tick(inputState:isNewlyPressed(InputState.A_BUTTON))
end

local function oakSpeechRevealTask(taskId)
  oakSpeechPrinterState:tick(inputState:isNewlyPressed(InputState.A_BUTTON))
end

local function flameAnimTask(taskId)
  flameAnimator:tick()
end

local function flameSpawnerTask(taskId)
  flameSpawner:tick()
end

local function titleFadeTask(taskId)
  titleFade:tick()
end

local function titleSlashTask(taskId)
  titleSlashSprite:tick()
end

local function itemBallAffineTask(taskId)
  itemBallAffineAnimator:tick()
end

local function playerMovementTask(taskId)
  playerMovement:tick()
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

-- The view-setup blocks below are split into their own top-level
-- functions (rather than being inlined in loadMapFromRom) because Lua
-- caps a single function at 60 upvalues -- loadMapFromRom used to set up
-- every view (map, title, sprites, font, Yes/No menu, flames) in one
-- function body, and by this point in the project touches enough
-- module-level state variables across all of them combined to exceed
-- that limit. Splitting by view keeps each function's upvalue set small
-- and is also just more readable than one 180-line function.

local function loadTitleScreenAssets(data, addrs, dbg)
  local titleOk, titleErr = pcall(function()
    titleBorderComposited = TitleScreen.compositeBorder(data, addrs)
    titleCopyrightBoxArtComposited = TitleScreen.compositeCopyrightAndBoxArt(data, addrs)
    titleLogoComposited = TitleScreen.compositeLogo(data, addrs.gGraphics_TitleScreen_GameTitleLogoTiles, addrs.gGraphics_TitleScreen_GameTitleLogoMap, addrs.gGraphics_TitleScreen_GameTitleLogoPals)
  end)
  if titleOk then
    titleBorderImage = buildImage(titleBorderComposited)
    titleBorderImage:setFilter("nearest", "nearest")
    titleCopyrightBoxArtImage = buildImage(titleCopyrightBoxArtComposited)
    titleCopyrightBoxArtImage:setFilter("nearest", "nearest")
    dbg("title logo built")

    -- Real BeginNormalPaletteFade(palettes, 1, 16, 0, RGB(30,30,31)) --
    -- fades in from a near-white color (5-bit (30,30,31), converted the
    -- same way GbaGraphics.decodeColor converts any GBA color: to8(30)=
    -- 247, to8(31)=255) down to the normal palette. delay=1 means one
    -- tick of waiting between each step (see PaletteFade.lua).
    titleFade = PaletteFade.new(16, 0, 1, { r = 247, g = 247, b = 255 })
    titleFadeBuiltY = -1
    scheduler:createTask(titleFadeTask, 0)
    dbg("title fade-in task created")
  else
    dbg("title logo failed: " .. tostring(titleErr))
  end

  local slashOk, slashErr = pcall(function()
    titleSlashMask = SlashMask.decode(data, addrs.sSlash_Gfx)
  end)
  if slashOk then
    titleSlashSprite = SlashSprite.new()
    titleLogoBuiltKey = nil
    scheduler:createTask(titleSlashTask, 0)
    dbg("slash-in effect decoded and task created")
  else
    dbg("slash-in effect failed: " .. tostring(slashErr))
  end
end

local function loadSpriteAssets(data, addrs, dbg)
  -- Tile dimensions now come from the real OAM shape/size (OamShapeSize.lua)
  -- instead of a hand-fed 2,4 -- proves ObjectSprite.lua isn't
  -- special-cased to this one sprite.
  local redOam = OamShapeSize.decodeOamData(data, addrs.gObjectEventBaseOam_16x32)
  local spriteOk, spriteComposited = pcall(ObjectSprite.decodeFrame, data, addrs.gObjectEventPic_RedNormal, addrs.gObjectEventPal_Player, redOam.widthTiles, redOam.heightTiles, 0)
  if spriteOk then
    spriteImage = buildImage(spriteComposited)
    spriteImage:setFilter("nearest", "nearest")
    dbg("player sprite built")
  else
    dbg("player sprite failed: " .. tostring(spriteComposited))
  end

  -- A second, genuinely different real object sprite (the ground Item
  -- Ball) -- different OAM shape (SQUARE vs V_RECTANGLE) and a different
  -- palette, decoded through the exact same general pipeline.
  local itemBallOam = OamShapeSize.decodeOamData(data, addrs.gObjectEventBaseOam_16x16)
  local itemBallOk, itemBallComposited = pcall(ObjectSprite.decodeFrame, data, addrs.gObjectEventPic_ItemBall, addrs.gObjectEventPal_NpcWhite, itemBallOam.widthTiles, itemBallOam.heightTiles, 0)
  if itemBallOk then
    itemBallImage = buildImage(itemBallComposited)
    itemBallImage:setFilter("nearest", "nearest")
    dbg("item ball sprite built")
  else
    dbg("item ball sprite failed: " .. tostring(itemBallComposited))
  end

  -- Real Pokéball wobble affine animation (src/pokeball.c), applied to
  -- the item ball sprite as a live demonstration of real sprite
  -- rotation/scaling data -- see AffineAnimator.lua for the documented
  -- simplified value semantics.
  local affineOk, affineErr = pcall(function()
    local cmds = AffineAnim.decodeCmds(data, addrs.sAffineAnim_BallRotate_Right)
    itemBallAffineAnimator = AffineAnimator.new(cmds)
  end)
  if affineOk then
    scheduler:createTask(itemBallAffineTask, 0)
    dbg("item ball affine animation decoded and task created")
  else
    dbg("item ball affine animation failed: " .. tostring(affineErr))
  end
end

local function loadFontAssets(data, addrs, dbg)
  fontData, fontAddrs = data, addrs
  -- "POKEMON " in the default color, then a real EXT_CTRL_CODE_COLOR
  -- switch (FC 01 04, TEXT_COLOR_RED) for "FIRERED", then a real
  -- EXT_CTRL_CODE_PAUSE (FC 08 <30 ticks>) before switching back to white
  -- (FC 01 01) for " VERSION" -- demonstrates TextRenderer/TextPrinterState
  -- actually acting on control codes rather than just displaying them as
  -- bracketed text (Charmap.decode's job).
  local message = charmapBytesForUppercaseAndSpaces("POKEMON ")
    .. string.char(0xFC, 0x01, 0x04) .. charmapBytesForUppercaseAndSpaces("FIRERED")
    .. string.char(0xFC, 0x08, 30) .. string.char(0xFC, 0x01, 0x01) .. charmapBytesForUppercaseAndSpaces(" VERSION")
    .. string.char(Charmap.TERMINATOR)
  local tokens = Charmap.tokenize(message)
  fontPrinterState = TextPrinterState.new(tokens, FONT_REVEAL_TICKS_PER_CHAR)
  fontPalette = GbaGraphics.decodePalette(data, addrs.gTextWindowPalettes) -- gTextWindowPalettes[0], the overworld dialogue box's bank
  fontBuiltRevealTokenIndex = -1
  scheduler:createTask(fontRevealTask, 0)
  dbg("font reveal task created")

  local windowOk, windowComposited = pcall(function()
    local tiles = TextWindow.decodeFrameTiles(data, addrs.gStdTextWindow_Gfx)
    local palette = TextWindow.decodePalette(data, addrs.gTextWindowPalettes, TextWindow.STD_PALETTE_INDEX)
    return TextWindow.compositeFrame(tiles, palette, 24, 2) -- 24x2 tiles fits "POKEMON FIRERED VERSION" (~22 tiles wide, 2 tall)
  end)
  if windowOk then
    fontWindowImage = buildImage(windowComposited)
    fontWindowImage:setFilter("nearest", "nearest")
    dbg("text window frame built")
  else
    dbg("text window frame failed: " .. tostring(windowComposited))
  end
end

-- Oak intro (partial): the real opening narration text
-- (gOakSpeech_Text_WelcomeToTheWorld, src/oak_speech.c's
-- Task_OakSpeech_WelcomeToTheWorld/_ThisWorld message chain), rendered
-- through the same real font/window/text-printer pipeline as the F view.
-- Deliberately NOT the full scene: no Oak sprite, no Nidoran, no real
-- background layer, no gender/naming flow -- those need asset pipelines
-- (trainer pic decode, a dedicated background layer) and scene-stack
-- machinery this project doesn't have yet. This is the real dialogue
-- text specifically, verified against real ROM bytes end to end.
local function loadOakSpeechAssets(data, addrs, dbg)
  local ok, err = pcall(function()
    local raw = data:sub(addrs.gOakSpeech_Text_WelcomeToTheWorld + 1, addrs.gOakSpeech_Text_WelcomeToTheWorld + 300)
    local tokens = Charmap.tokenize(raw)
    oakSpeechPrinterState = TextPrinterState.new(tokens, FONT_REVEAL_TICKS_PER_CHAR)

    local tiles = TextWindow.decodeFrameTiles(data, addrs.gStdTextWindow_Gfx)
    local palette = TextWindow.decodePalette(data, addrs.gTextWindowPalettes, TextWindow.STD_PALETTE_INDEX)
    oakSpeechWindowImage = buildImage(TextWindow.compositeFrame(tiles, palette, 28, 12)) -- 28x12 tiles fits all 6 real lines stacked
    oakSpeechWindowImage:setFilter("nearest", "nearest")
  end)
  if ok then
    oakSpeechBuiltRevealTokenIndex = -1
    scheduler:createTask(oakSpeechRevealTask, 0)
    dbg("Oak speech text decoded and task created")
  else
    dbg("Oak speech text failed: " .. tostring(err))
  end
end

local function loadYesNoAssets(data, addrs, dbg)
  local yesNoOk, yesNoErr = pcall(function()
    local tiles = TextWindow.decodeFrameTiles(data, addrs.gStdTextWindow_Gfx)
    local palette = TextWindow.decodePalette(data, addrs.gTextWindowPalettes, TextWindow.STD_PALETTE_INDEX)
    -- 6x4 content tiles: "YES"/"NO" plus the selector arrow's column,
    -- two 16px-tall rows (real CreateYesNoMenu's per-row height is
    -- FONT_NORMAL's maxLetterHeight + lineSpacing, which is 16px here).
    yesNoWindowImage = buildImage(TextWindow.compositeFrame(tiles, palette, 6, 4))
    yesNoWindowImage:setFilter("nearest", "nearest")

    -- Real gText_YesNo is "YES\nNO" (src/strings.c) -- 0xFA is one of the
    -- real linebreak bytes Charmap.lua already recognizes.
    local yesNoBytes = charmapBytesForUppercaseAndSpaces("YES") .. string.char(0xFA) .. charmapBytesForUppercaseAndSpaces("NO") .. string.char(Charmap.TERMINATOR)
    local yesNoTokens = Charmap.tokenize(yesNoBytes)
    yesNoTextImage = buildImage(TextRenderer.renderTokens(data, addrs, yesNoTokens, fontPalette))
    yesNoTextImage:setFilter("nearest", "nearest")

    -- The real selector arrow glyph, gText_SelectorArrow2 = "▶" = 0xEF
    -- (charmap.txt), drawn to the left of whichever row is selected.
    local arrowPixelTypes = Font.decodeGlyphPixelTypes(data, addrs.sFontHalfRowOffsets, addrs.sFontNormalLatinGlyphs, 0xEF)
    local arrowWidth = string.byte(data, addrs.sFontNormalLatinGlyphWidths + 0xEF + 1)
    yesNoArrowImage = buildImage(Font.buildGlyphImage(arrowPixelTypes, arrowWidth, fontPalette[1], fontPalette[3]))
    yesNoArrowImage:setFilter("nearest", "nearest")
  end)
  if yesNoOk then
    yesNoCursor = MenuCursor.new(2, 0)
    yesNoResult = nil
    dbg("Yes/No menu built")
  else
    dbg("Yes/No menu failed: " .. tostring(yesNoErr))
  end
end

local function loadFlameAssets(data, addrs, dbg)
  local flameCmds
  local flameOk, flameErr = pcall(function()
    flameTiles = Lz77.decompress(data, addrs.sFlames_Gfx + 1)
    flamePalette = GbaGraphics.decodePalette(data, addrs.sFlames_Pal)
    flameCmds = SpriteAnim.decodeCmds(data, addrs.sSpriteAnim_Flame)
    flameAnimator = SpriteAnimator.new(flameCmds)
  end)
  if flameOk then
    flameBuiltFrameIndex = -1
    scheduler:createTask(flameAnimTask, 0)
    dbg("flame animation decoded and task created")

    flameSpawner = TitleScreenFlameSpawner.new(flameCmds)
    flameFrameImageCache = {}
    scheduler:createTask(flameSpawnerTask, 0)
    dbg("flame particle spawner task created")
  else
    dbg("flame animation failed: " .. tostring(flameErr))
  end
end

-- Real player movement demo: not the canonical real starting position
-- (that needs the new-game script/warp flow, not built yet -- see the
-- checklist's Phase 3 "New-game naming, initial flags/vars") -- instead
-- scans the loaded map's real collision grid for the first walkable
-- tile, so this works on whichever map POKEPORT_MAP selected.
local function loadWalkAssets(dbg)
  if not walkMapBlockData then return end
  for y = 0, walkMapHeight - 1 do
    for x = 0, walkMapWidth - 1 do
      if not isWalkTileBlocked(x, y) then
        playerMovement = PlayerMovement.new(x, y, PlayerMovement.DOWN)
        scheduler:createTask(playerMovementTask, 0)
        dbg(("player movement started at first walkable tile %d,%d"):format(x, y))
        return
      end
    end
  end
  dbg("player movement failed: no walkable tile found on this map")
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
  walkMapBlockData, walkMapWidth, walkMapHeight = blockData, layout.width, layout.height
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

  addLine("Press V for the data viewer, T for the title screen, P for a sprite, I for an item ball, F for font rendering, O for the Oak intro text, A for the animated flame, Y for a Yes/No menu, W to walk (arrow keys).")

  loadTitleScreenAssets(data, addrs, dbg)
  loadSpriteAssets(data, addrs, dbg)
  loadFontAssets(data, addrs, dbg)
  loadOakSpeechAssets(data, addrs, dbg)
  loadYesNoAssets(data, addrs, dbg)
  loadFlameAssets(data, addrs, dbg)
  loadWalkAssets(dbg)
end

-- Rebuilds fontImage only when the revealed character count has actually
-- changed since the last draw (rebuilding a love.Image every frame for a
-- static count would be wasted work).
local function ensureFontImageCurrent()
  if not fontData or not fontPrinterState or fontPrinterState.tokenIndex == fontBuiltRevealTokenIndex then return end
  if fontPrinterState.tokenIndex == 0 then
    fontImage = nil
  else
    local sliced = fontPrinterState:revealedTokens()
    local ok, composited = pcall(TextRenderer.renderTokens, fontData, fontAddrs, sliced, fontPalette)
    if ok then
      fontImage = buildImage(composited)
      fontImage:setFilter("nearest", "nearest")
    end
  end
  fontBuiltRevealTokenIndex = fontPrinterState.tokenIndex
end

local function ensureOakSpeechImageCurrent()
  if not fontData or not oakSpeechPrinterState or oakSpeechPrinterState.tokenIndex == oakSpeechBuiltRevealTokenIndex then return end
  if oakSpeechPrinterState.tokenIndex == 0 then
    oakSpeechImage = nil
  else
    local sliced = oakSpeechPrinterState:revealedTokens()
    local ok, composited = pcall(TextRenderer.renderTokens, fontData, fontAddrs, sliced, fontPalette)
    if ok then
      oakSpeechImage = buildImage(composited)
      oakSpeechImage:setFilter("nearest", "nearest")
    end
  end
  oakSpeechBuiltRevealTokenIndex = oakSpeechPrinterState.tokenIndex
end

local FLAME_TILE_WIDTH, FLAME_TILE_HEIGHT = 2, 2 -- ST_OAM_SIZE_1 SQUARE = 16x16px = 2x2 tiles

-- Rebuilds flameImage only when the animator's current frame has actually
-- changed since the last draw.
local function ensureFlameImageCurrent()
  if not flameTiles or not flameAnimator then return end
  local frame = flameAnimator:currentFrame()
  if frame.imageValue == flameBuiltFrameIndex then return end
  -- imageValue is a tile offset (1D OBJ mapping, see ObjectSprite.lua);
  -- divide by tiles-per-frame to get the frame index decodeFrameTiles wants.
  local frameIndex = frame.imageValue / (FLAME_TILE_WIDTH * FLAME_TILE_HEIGHT)
  local tiles = ObjectSprite.decodeFrameTiles(flameTiles, 0, FLAME_TILE_WIDTH, FLAME_TILE_HEIGHT, frameIndex)
  local composited = ObjectSprite.buildImage(tiles, flamePalette, FLAME_TILE_WIDTH, FLAME_TILE_HEIGHT)
  flameImage = buildImage(composited)
  flameImage:setFilter("nearest", "nearest")
  flameBuiltFrameIndex = frame.imageValue
end

-- Returns a cached love.Image for a given flame frame imageValue, building
-- it on first use. Multiple particles sharing the same current frame reuse
-- the same Image rather than each rebuilding it every draw call.
local function flameFrameImage(imageValue)
  local cached = flameFrameImageCache[imageValue]
  if cached then return cached end
  local frameIndex = imageValue / (FLAME_TILE_WIDTH * FLAME_TILE_HEIGHT)
  local tiles = ObjectSprite.decodeFrameTiles(flameTiles, 0, FLAME_TILE_WIDTH, FLAME_TILE_HEIGHT, frameIndex)
  local composited = ObjectSprite.buildImage(tiles, flamePalette, FLAME_TILE_WIDTH, FLAME_TILE_HEIGHT)
  local img = buildImage(composited)
  img:setFilter("nearest", "nearest")
  flameFrameImageCache[imageValue] = img
  return img
end

-- Rebuilds titleBorderImage/titleCopyrightBoxArtImage (re-blended toward
-- the fade's target color) and titleLogoImage (fade + slash-in lighten)
-- only when the relevant state has actually changed
-- since the last draw.
-- Real BLDCNT_EFFECT_LIGHTEN target color (RGB_WHITE) and blend
-- coefficient (SetGpuRegsForTitleScreenRun's BLDY=13) for the slash-in
-- effect -- see SlashSprite.lua's header comment for the full real
-- register setup this approximates.
local SLASH_LIGHTEN_COLOR = { r = 255, g = 255, b = 255 }
local SLASH_LIGHTEN_COEFF = 13

local function ensureTitleImageCurrent()
  if not titleBorderComposited or not titleCopyrightBoxArtComposited or not titleFade then return end
  if titleFade.y ~= titleFadeBuiltY then
    if titleFade.y == 0 then
      titleBorderImage = buildImage(titleBorderComposited)
      titleCopyrightBoxArtImage = buildImage(titleCopyrightBoxArtComposited)
    else
      titleBorderImage = buildImage(PaletteBlend.blendImage(titleBorderComposited, titleFade.blendColor, titleFade.y))
      titleCopyrightBoxArtImage = buildImage(PaletteBlend.blendImage(titleCopyrightBoxArtComposited, titleFade.blendColor, titleFade.y))
    end
    titleBorderImage:setFilter("nearest", "nearest")
    titleCopyrightBoxArtImage:setFilter("nearest", "nearest")
    titleFadeBuiltY = titleFade.y
  end

  if not titleLogoComposited then return end
  local slashX, slashY, slashInvisible = 0, 0, true
  if titleSlashSprite then
    slashX, slashY, slashInvisible = titleSlashSprite.x, titleSlashSprite.y, titleSlashSprite.invisible
  end
  local key = table.concat({ titleFade.y, slashX, slashY, tostring(slashInvisible) }, ",")
  if key == titleLogoBuiltKey then return end

  local composited = titleLogoComposited
  if titleFade.y ~= 0 then
    composited = PaletteBlend.blendImage(composited, titleFade.blendColor, titleFade.y)
  end
  if titleSlashMask and not slashInvisible then
    -- Real slash-in effect: wherever the slash sprite's silhouette
    -- overlaps the logo, lighten that pixel toward white (see
    -- SLASH_LIGHTEN_COEFF above) -- otherwise pass the (already
    -- fade-blended) pixel through unchanged.
    local base = composited
    composited = {
      width = base.width,
      height = base.height,
      getPixel = function(x, y)
        local p = base.getPixel(x, y)
        if p.a == 0 then return p end
        if titleSlashMask(x - slashX, y - slashY) then
          local lit = PaletteBlend.blendColor(p, SLASH_LIGHTEN_COLOR, SLASH_LIGHTEN_COEFF)
          return { r = lit.r, g = lit.g, b = lit.b, a = p.a }
        end
        return p
      end,
    }
  end
  titleLogoImage = buildImage(composited)
  titleLogoImage:setFilter("nearest", "nearest")
  titleLogoBuiltKey = key
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
  -- POKEPORT_TITLE_FLAME_TICKS=N ticks the flame particle spawner AND the
  -- fade-in forward N times first (same rationale as POKEPORT_FLAME_TICKS
  -- below -- automated screenshots can't wait on real elapsed time).
  -- POKEPORT_TITLE_SLASH_TICKS=N separately ticks the slash-in effect
  -- (it waits a real 540 ticks before its first sweep, far more than a
  -- reasonable POKEPORT_TITLE_FLAME_TICKS value, so it gets its own knob).
  if os.getenv("POKEPORT_TITLE") == "1" then
    titleActive = true
    local ticks = tonumber(os.getenv("POKEPORT_TITLE_FLAME_TICKS") or "0")
    for i = 1, ticks do
      if flameSpawner then flameSpawner:tick() end
      if titleFade then titleFade:tick() end
    end
    local slashTicks = tonumber(os.getenv("POKEPORT_TITLE_SLASH_TICKS") or "0")
    for i = 1, slashTicks do
      if titleSlashSprite then titleSlashSprite:tick() end
    end
  end

  -- POKEPORT_SPRITE=1 boots straight into the player-sprite view.
  if os.getenv("POKEPORT_SPRITE") == "1" then
    spriteActive = true
  end

  -- POKEPORT_ITEMBALL=1 boots straight into the item ball sprite view.
  -- POKEPORT_ITEMBALL_AFFINE_TICKS=N ticks the wobble animation forward
  -- N times first (deterministic screenshots, same rationale as the
  -- other *_TICKS env vars).
  if os.getenv("POKEPORT_ITEMBALL") == "1" then
    itemBallActive = true
    local affineTicks = tonumber(os.getenv("POKEPORT_ITEMBALL_AFFINE_TICKS") or "0")
    for i = 1, affineTicks do
      if itemBallAffineAnimator then itemBallAffineAnimator:tick() end
    end
  end

  -- POKEPORT_FONT=1 boots straight into the font-rendering sample view.
  if os.getenv("POKEPORT_FONT") == "1" then
    fontActive = true
  end

  -- POKEPORT_OAKSPEECH=1 boots straight into the Oak intro text view.
  -- POKEPORT_OAKSPEECH_REVEAL=1 forces the full text revealed
  -- immediately (same rationale as fontPrinterState:revealAll() below).
  if os.getenv("POKEPORT_OAKSPEECH") == "1" then
    oakSpeechActive = true
    if os.getenv("POKEPORT_OAKSPEECH_REVEAL") == "1" and oakSpeechPrinterState then
      oakSpeechPrinterState:revealAll()
    end
  end

  -- POKEPORT_WALK=1 boots straight into the player movement/camera view.
  -- POKEPORT_WALK_MOVES=<dir>,<dir>,... replays a sequence of moves
  -- (down/up/left/right, each held for a full 16-frame step) before the
  -- screenshot is taken -- deterministic movement for automated
  -- screenshots, since real elapsed-time-based key holding can't be
  -- scripted here.
  if os.getenv("POKEPORT_WALK") == "1" then
    walkActive = true
    local moves = os.getenv("POKEPORT_WALK_MOVES")
    if moves and playerMovement then
      for dir in moves:gmatch("[^,]+") do
        playerMovement:tryMove(dir, isWalkTileBlocked)
        for i = 1, 16 do playerMovement:tick() end
      end
    end
  end

  -- POKEPORT_FLAME=1 boots straight into the animated flame sprite view.
  -- POKEPORT_FLAME_TICKS=N ticks the animator forward N times before the
  -- screenshot is taken -- used to capture two different animation frames
  -- deterministically (e.g. tick 0 vs tick 10) rather than relying on
  -- real elapsed time, which automated screenshot capture can't control.
  if os.getenv("POKEPORT_FLAME") == "1" then
    flameActive = true
    local ticks = tonumber(os.getenv("POKEPORT_FLAME_TICKS") or "0")
    if flameAnimator then
      for i = 1, ticks do flameAnimator:tick() end
    end
  end

  -- POKEPORT_YESNO=1 boots straight into the Yes/No menu view.
  -- POKEPORT_YESNO_CURSOR=1 moves the cursor down to NO first, for a
  -- deterministic non-default-selection screenshot.
  if os.getenv("POKEPORT_YESNO") == "1" then
    yesNoActive = true
    if yesNoCursor and os.getenv("POKEPORT_YESNO_CURSOR") == "1" then
      yesNoCursor.cursorPos = 1
    end
  end

  -- love.filesystem is sandboxed to the save directory (see conf.lua's
  -- identity="firered-recomp"), so this always writes there under a fixed
  -- name rather than to an arbitrary POKEPORT_SCREENSHOT path.
  if os.getenv("POKEPORT_SCREENSHOT") == "1" and (mapImage or viewerActive or titleActive or spriteActive or itemBallActive or fontActive or oakSpeechActive or flameActive or yesNoActive or walkActive) then
    -- The font sample normally reveals one character at a time (real text
    -- speed, driven by TaskScheduler in love.update) and can pause or wait
    -- on a keypress mid-message; automated screenshots want the
    -- deterministic finished state instead of whatever partial reveal/
    -- pause was in progress at capture time.
    if fontPrinterState then fontPrinterState:revealAll() end
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
      DPAD_LEFT = love.keyboard.isDown("left"),
      DPAD_RIGHT = love.keyboard.isDown("right"),
      A_BUTTON = love.keyboard.isDown("return"),
      B_BUTTON = love.keyboard.isDown("backspace"),
    }))
    if viewerActive then
      if inputState:isPressedOrRepeated(InputState.DPAD_DOWN) then viewerStep(1) end
      if inputState:isPressedOrRepeated(InputState.DPAD_UP) then viewerStep(-1) end
    end
    if walkActive and playerMovement then
      -- Real continuous walking-while-held uses a plain held-key check
      -- every frame (not the menu-style repeat-with-delay system --
      -- that's specific to menu cursors, see InputState.lua/MenuCursor.lua),
      -- so the next tile starts immediately once the current step finishes.
      if inputState:isHeld(InputState.DPAD_DOWN) then playerMovement:tryMove(PlayerMovement.DOWN, isWalkTileBlocked)
      elseif inputState:isHeld(InputState.DPAD_UP) then playerMovement:tryMove(PlayerMovement.UP, isWalkTileBlocked)
      elseif inputState:isHeld(InputState.DPAD_LEFT) then playerMovement:tryMove(PlayerMovement.LEFT, isWalkTileBlocked)
      elseif inputState:isHeld(InputState.DPAD_RIGHT) then playerMovement:tryMove(PlayerMovement.RIGHT, isWalkTileBlocked)
      end
    end
    if yesNoActive and yesNoCursor and not yesNoResult then
      local outcome = yesNoCursor:processInput(inputState)
      if outcome == "confirm" or outcome == "cancel" then yesNoResult = outcome end
    end
  end
end

function love.draw()
  if fontActive then ensureFontImageCurrent() end
  if oakSpeechActive then ensureOakSpeechImageCurrent() end
  if flameActive then ensureFlameImageCurrent() end
  if titleActive then ensureTitleImageCurrent() end
  if spriteActive or itemBallActive then
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
  elseif itemBallActive and itemBallImage then
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local viewport = ViewportScale.fit(itemBallImage:getWidth(), itemBallImage:getHeight(), math.min(windowWidth - 40, 320), math.min(windowHeight - (y + 10), 320))
    local ballW, ballH = itemBallImage:getWidth(), itemBallImage:getHeight()
    local rotation, animSX, animSY = 0, 1, 1
    if itemBallAffineAnimator then
      rotation = itemBallAffineAnimator:rotationRadians()
      animSX, animSY = itemBallAffineAnimator.xScale, itemBallAffineAnimator.yScale
    end
    -- Rotating/scaling about the sprite's own center (real affine sprites
    -- pivot around their center, not a corner), so the draw origin is the
    -- image's center and the screen position is shifted to match.
    local centerX = 20 + viewport.x + (ballW / 2) * viewport.scale
    local centerY = y + 10 + viewport.y + (ballH / 2) * viewport.scale
    love.graphics.draw(itemBallImage, centerX, centerY, rotation, viewport.scale * animSX, viewport.scale * animSY, ballW / 2, ballH / 2)
  elseif fontActive and fontWindowImage then
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local viewport = ViewportScale.fit(fontWindowImage:getWidth(), fontWindowImage:getHeight(), windowWidth - 40, windowHeight - (y + 10))
    love.graphics.draw(fontWindowImage, 20 + viewport.x, y + 10 + viewport.y, 0, viewport.scale, viewport.scale)
    if fontImage then
      -- TextWindow.TILE_SIZE (8px) inset places the text inside the
      -- frame's transparent interior, one border tile in from the top-left.
      love.graphics.draw(fontImage, 20 + viewport.x + TextWindow.TILE_SIZE * viewport.scale, y + 10 + viewport.y + TextWindow.TILE_SIZE * viewport.scale, 0, viewport.scale, viewport.scale)
    end
  elseif oakSpeechActive and oakSpeechWindowImage then
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local viewport = ViewportScale.fit(oakSpeechWindowImage:getWidth(), oakSpeechWindowImage:getHeight(), windowWidth - 40, windowHeight - (y + 10))
    love.graphics.draw(oakSpeechWindowImage, 20 + viewport.x, y + 10 + viewport.y, 0, viewport.scale, viewport.scale)
    if oakSpeechImage then
      love.graphics.draw(oakSpeechImage, 20 + viewport.x + TextWindow.TILE_SIZE * viewport.scale, y + 10 + viewport.y + TextWindow.TILE_SIZE * viewport.scale, 0, viewport.scale, viewport.scale)
    end
  elseif walkActive and mapImage and playerMovement then
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local viewport = ViewportScale.fit(WALK_CAMERA_WIDTH, WALK_CAMERA_HEIGHT, windowWidth - 40, windowHeight - (y + 10))
    -- Camera: a real 240x160 GBA-screen-sized crop of the already-
    -- composited map, centered on the player's real (sub-tile-
    -- interpolated) pixel position, clamped so it never shows past the
    -- composited image's edges.
    local borderOffsetPx = BORDER_MARGIN_METATILES * 16
    local playerCompositedX = playerMovement:pixelX() + borderOffsetPx
    local playerCompositedY = playerMovement:pixelY() + borderOffsetPx
    local mapPixelWidth, mapPixelHeight = mapImage:getDimensions()
    local quadX = math.max(0, math.min(playerCompositedX + 8 - WALK_CAMERA_WIDTH / 2, mapPixelWidth - WALK_CAMERA_WIDTH))
    local quadY = math.max(0, math.min(playerCompositedY + 8 - WALK_CAMERA_HEIGHT / 2, mapPixelHeight - WALK_CAMERA_HEIGHT))
    local quad = love.graphics.newQuad(quadX, quadY, WALK_CAMERA_WIDTH, WALK_CAMERA_HEIGHT, mapPixelWidth, mapPixelHeight)
    local baseX, baseY = 20 + viewport.x, y + 10 + viewport.y
    love.graphics.draw(mapImage, quad, baseX, baseY, 0, viewport.scale, viewport.scale)
    if spriteImage then
      love.graphics.draw(spriteImage, baseX + (playerCompositedX - quadX) * viewport.scale, baseY + (playerCompositedY - quadY - 16) * viewport.scale, 0, viewport.scale, viewport.scale)
    end
  elseif yesNoActive and yesNoWindowImage then
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local viewport = ViewportScale.fit(yesNoWindowImage:getWidth(), yesNoWindowImage:getHeight(), windowWidth - 40, windowHeight - (y + 10))
    local baseX, baseY = 20 + viewport.x, y + 10 + viewport.y
    love.graphics.draw(yesNoWindowImage, baseX, baseY, 0, viewport.scale, viewport.scale)
    -- Real CreateYesNoMenu draws the selector arrow's column, then the
    -- "YES"/"NO" text starting one arrow-width to its right -- mirrored
    -- here as two separate draws sharing the same left inset.
    local textX = baseX + (TextWindow.TILE_SIZE + yesNoArrowImage:getWidth()) * viewport.scale
    if yesNoTextImage then
      love.graphics.draw(yesNoTextImage, textX, baseY + TextWindow.TILE_SIZE * viewport.scale, 0, viewport.scale, viewport.scale)
    end
    if yesNoCursor and not yesNoResult then
      local arrowY = baseY + (TextWindow.TILE_SIZE + yesNoCursor.cursorPos * 16) * viewport.scale
      love.graphics.draw(yesNoArrowImage, baseX + TextWindow.TILE_SIZE * viewport.scale, arrowY, 0, viewport.scale, viewport.scale)
    end
    if yesNoResult then
      love.graphics.print("Result: " .. (yesNoResult == "confirm" and ("Confirmed " .. (yesNoCursor.cursorPos == 0 and "YES" or "NO")) or "Cancelled") .. "  (press Y to reset)", 20, baseY + yesNoWindowImage:getHeight() * viewport.scale + 20)
    end
  elseif flameActive and flameImage then
    local windowWidth, windowHeight = love.graphics.getDimensions()
    -- The real flame is 16x16px, tiny -- fit generously so the frame
    -- shape is actually visible rather than a few pixels in a corner.
    local viewport = ViewportScale.fit(flameImage:getWidth(), flameImage:getHeight(), math.min(windowWidth - 40, 320), math.min(windowHeight - (y + 10), 320))
    love.graphics.draw(flameImage, 20 + viewport.x, y + 10 + viewport.y, 0, viewport.scale, viewport.scale)
  elseif titleActive and titleBorderImage then
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local viewport = ViewportScale.fit(titleBorderImage:getWidth(), titleBorderImage:getHeight(), windowWidth - 40, windowHeight - (y + 10))
    local baseX, baseY = 20 + viewport.x, y + 10 + viewport.y
    -- Real GBA draw order (LayerCompositor.lua): the border (bg3,
    -- priority 3) draws first, then the flame OBJ sprites (also priority
    -- 3, so they sit on top of the border specifically), then everything
    -- with a lower priority number (copyright/boxart/logo) draws over
    -- both -- so a flame drifting up behind the "PRESS START" text is
    -- correctly hidden by it, instead of always being drawn on top.
    love.graphics.draw(titleBorderImage, baseX, baseY, 0, viewport.scale, viewport.scale)
    if flameSpawner then
      for _, particle in ipairs(flameSpawner.particles) do
        local img = flameFrameImage(particle.animator:currentFrame().imageValue)
        love.graphics.draw(img, baseX + particle.x * viewport.scale, baseY + particle.y * viewport.scale, 0, viewport.scale, viewport.scale)
      end
    end
    if titleCopyrightBoxArtImage then
      love.graphics.draw(titleCopyrightBoxArtImage, baseX, baseY, 0, viewport.scale, viewport.scale)
    end
    if titleLogoImage then
      -- The logo (bg0, priority 0, frontmost) already has the slash-in
      -- lighten effect baked in by ensureTitleImageCurrent, since the
      -- real effect only ever targets this layer.
      love.graphics.draw(titleLogoImage, baseX, baseY, 0, viewport.scale, viewport.scale)
    end
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
    flameActive = false
    yesNoActive = false
    itemBallActive = false
    oakSpeechActive = false
    walkActive = false
  elseif key == "t" then
    titleActive = not titleActive
    viewerActive = false
    spriteActive = false
    fontActive = false
    flameActive = false
    yesNoActive = false
    itemBallActive = false
    oakSpeechActive = false
    walkActive = false
  elseif key == "p" then
    spriteActive = not spriteActive
    viewerActive = false
    titleActive = false
    fontActive = false
    flameActive = false
    yesNoActive = false
    itemBallActive = false
    oakSpeechActive = false
    walkActive = false
  elseif key == "i" then
    itemBallActive = not itemBallActive
    viewerActive = false
    titleActive = false
    spriteActive = false
    fontActive = false
    flameActive = false
    yesNoActive = false
    oakSpeechActive = false
    walkActive = false
  elseif key == "f" then
    fontActive = not fontActive
    viewerActive = false
    titleActive = false
    spriteActive = false
    flameActive = false
    yesNoActive = false
    itemBallActive = false
    oakSpeechActive = false
    walkActive = false
  elseif key == "o" then
    oakSpeechActive = not oakSpeechActive
    viewerActive = false
    titleActive = false
    spriteActive = false
    fontActive = false
    flameActive = false
    yesNoActive = false
    itemBallActive = false
    walkActive = false
  elseif key == "a" then
    flameActive = not flameActive
    viewerActive = false
    titleActive = false
    spriteActive = false
    fontActive = false
    yesNoActive = false
    itemBallActive = false
    oakSpeechActive = false
    walkActive = false
  elseif key == "y" then
    yesNoActive = not yesNoActive
    itemBallActive = false
    if yesNoActive and yesNoCursor then
      yesNoCursor.cursorPos = 0
      yesNoResult = nil
    end
    viewerActive = false
    titleActive = false
    spriteActive = false
    fontActive = false
    flameActive = false
    oakSpeechActive = false
    walkActive = false
  elseif key == "w" then
    walkActive = not walkActive
    viewerActive = false
    titleActive = false
    spriteActive = false
    fontActive = false
    flameActive = false
    yesNoActive = false
    itemBallActive = false
    oakSpeechActive = false
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
