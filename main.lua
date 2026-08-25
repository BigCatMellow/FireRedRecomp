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
--
-- Phase 3 turned the W (walk) view into an actual slice of the game
-- rather than a rendering demo: real grid movement/collision/camera over
-- the composited map, real warps between maps, real object-event NPCs
-- (spawned, movement-ticked, drawn, and interactable), real NPC/sign
-- dialogue driven by the real script bytecode through DialogueRunner.lua,
-- and real wild-encounter dice rolls on entering real tall grass. A rolled
-- encounter now starts the bounded Phase 4 1v1 battle scene
-- (FIGHT/RUN, real ROM terrain and monster art). Full view key
-- list: N post-Oak gender/naming flow, V data viewer, T title screen,
-- P player sprite, I item ball, F font sample, O Oak narration text,
-- S full Oak intro scene (Enter continues to N), A flame sprite,
-- Y Yes/No menu, W walk. See docs/roadmap.md.

local Version = require("src.core.Version")
local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local MapHeader = require("import.MapHeader")
local MapLayout = require("import.MapLayout")
local MapBlockData = require("import.MapBlockData")
local MapBorder = require("import.MapBorder")
local MapCompositor = require("import.MapCompositor")
local MapEvents = require("import.MapEvents")
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
local Tileset = require("import.Tileset")
local MetatileAttributes = require("import.MetatileAttributes")
local SlashMask = require("import.SlashMask")
local AffineAnim = require("import.AffineAnim")
local AffineAnimator = require("src.core.AffineAnimator")
local PlayerMovement = require("src.core.PlayerMovement")
local ObjectEventState = require("src.core.ObjectEventState")
local ObjectEventGraphicsInfo = require("import.ObjectEventGraphicsInfo")
local ObjectEventInteraction = require("src.core.ObjectEventInteraction")
local ScriptBytecode = require("import.ScriptBytecode")
local DialogueRunner = require("src.core.DialogueRunner")
local WildEncounters = require("import.WildEncounters")
local WildEncounterSelector = require("src.core.WildEncounterSelector")
local WildEncounterTrigger = require("src.core.WildEncounterTrigger")
local Rng = require("src.core.Rng")
local OakSpeechScene = require("import.OakSpeechScene")
local NamingScreenScene = require("import.NamingScreenScene")
local NewGameFlow = require("src.core.NewGameFlow")
local NewGameDefaults = require("src.core.NewGameDefaults")
local SaveFileCodec = require("src.core.SaveFileCodec")
local Battle = {
  Trainer = require("import.Trainer"),
  TrainerParty = require("import.TrainerParty"),
  SpeciesInfo = require("import.SpeciesInfo"),
  Move = require("import.BattleMove"),
  TypeChart = require("import.TypeChart"),
  Nature = require("import.Nature"),
  Learnset = require("import.LevelUpLearnset"),
  WildFactory = require("src.core.WildPokemonFactory"),
  CaptureRules = require("src.core.CaptureRules"),
  StarterFactory = require("src.core.StarterPokemonFactory"),
  TrainerFactory = require("src.core.TrainerPokemonFactory"),
  RivalAI = require("src.core.EarlyRivalAI"),
  RivalRewards = require("src.core.EarlyRivalRewards"),
  WhiteoutRules = require("src.core.WhiteoutRules"),
  EarlyStory = require("src.core.EarlyStory"),
  PokedexOrder = require("import.PokedexOrder"),
  Item = require("import.Item"),
  SessionBagBridge = require("src.core.SessionBagBridge"),
  PokemonMart = require("src.core.PokemonMart"),
  MartMenu = require("src.core.PokemonMartMenu"),
  StartMenu = require("src.core.StartMenu"),
  PartyScreen = require("src.core.PartyScreen"),
  BagScreen = require("src.core.BagScreen"),
  Bag = require("src.core.Bag"),
  TrainerSightline = require("src.core.TrainerSightline"),
  TrainerApproach = require("src.core.TrainerApproach"),
  TrainerAI = require("src.core.TrainerAI"),
  PartyBridge = require("src.core.BattlePartyBridge"),
  Engine = require("src.core.BattleEngine"),
  Controller = require("src.core.BattleSceneController"),
  Assets = require("import.BattleSceneAssets"),
}

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
local function addLine(text)
  table.insert(statusLines, text)
end
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

-- S: the full real Oak intro SCENE (OakSpeechScene.composite -- gradient
-- background + Oak's 8bpp picture + the real dialogue frame and narration),
-- as opposed to O above, which is only the narration text in a standalone
-- text window. Composited once at load (it's a static 240x160 still; the
-- scene module's own header documents the sequencing/animation that is
-- still open) and cached, per this project's don't-redecode-per-frame rule.
local oakSceneActive = false
local oakSceneImage

-- Post-Oak new-game identity flow. This is one table for the same reason
-- the Phase 3 W-view state is bundled below: main.lua's draw/update/load
-- functions are already near Lua 5.1's 60-upvalue ceiling.
-- `flow` is the pure NewGameFlow state machine; all Images are derived
-- caches rebuilt only when flow.revision changes.
local newGame = {
  active = false,
  builtRevision = -1,
}

-- The small runtime save/session boundary for a newly completed Oak flow.
-- This is deliberately pure data construction: it has no LÖVE, ROM, map, or
-- scheduler dependency, so its output can be fed directly to
-- SaveFileCodec.encode() once actual file I/O is wired.  Its values follow
-- NewGameInitData()/WarpToPlayersRoom() in src/new_game.c, while the trainer
-- id follows InitPlayerTrainerId(): `(Random() << 16) |
-- GetGeneratedTrainerIdLower()`, stored little-endian by SetTrainerId().
--
-- The real timer register is not available in a desktop runtime.  Callers
-- inject both Random's next u16 and the timer-derived lower half, making this
-- otherwise hardware-timed operation deterministic/replayable rather than
-- inventing a desktop clock source.
local GameSession = {}

GameSession.MAP_PALLET_TOWN_PLAYERS_HOUSE_2F = 4 * 256 + 1
GameSession.ITEM_POTION = 13 -- ITEM_POTION, include/constants/items.h
GameSession.VARS_START = 0x4000 -- include/constants/vars.h

-- The 49 map-hide flags are ordinary flag indices; FLAG_0x838 is a system
-- flag at index 0x838.  These numeric ids are transcribed from
-- include/constants/flags.h so the codec-compatible bit field reflects the
-- real EventScript_ResetAllMapFlags / EnableNationalPokedex_RSE calls rather
-- than retaining only symbolic metadata.
GameSession._newGameFlagIds = {
  FLAG_0x838 = 0x838,
  FLAG_HIDE_OAK_IN_HIS_LAB = 0x02B,
  FLAG_HIDE_OAK_IN_PALLET_TOWN = 0x02C,
  FLAG_HIDE_BILL_HUMAN_SEA_COTTAGE = 0x033,
  FLAG_HIDE_PEWTER_CITY_RUNNING_SHOES_GUY = 0x092,
  FLAG_HIDE_POKEHOUSE_FUJI = 0x035,
  FLAG_HIDE_LIFT_KEY = 0x036,
  FLAG_HIDE_SILPH_SCOPE = 0x037,
  FLAG_HIDE_CERULEAN_RIVAL = 0x03C,
  FLAG_HIDE_SS_ANNE_RIVAL = 0x03D,
  FLAG_HIDE_VERMILION_CITY_OAKS_AIDE = 0x0A1,
  FLAG_HIDE_SAFFRON_CIVILIANS = 0x03F,
  FLAG_HIDE_ROUTE_22_RIVAL = 0x04F,
  FLAG_HIDE_OAK_IN_CHAMP_ROOM = 0x05A,
  FLAG_HIDE_CREDITS_RIVAL = 0x0A3,
  FLAG_HIDE_CREDITS_OAK = 0x0A4,
  FLAG_HIDE_CINNABAR_BILL = 0x062,
  FLAG_HIDE_CINNABAR_SEAGALLOP = 0x06B,
  FLAG_HIDE_CINNABAR_POKECENTER_BILL = 0x0A2,
  FLAG_HIDE_LORELEI_IN_HER_HOUSE = 0x08C,
  FLAG_HIDE_SAFFRON_FAN_CLUB_BLACK_BELT = 0x06C,
  FLAG_HIDE_SAFFRON_FAN_CLUB_ROCKER = 0x06D,
  FLAG_HIDE_SAFFRON_FAN_CLUB_WOMAN = 0x06E,
  FLAG_HIDE_SAFFRON_FAN_CLUB_BEAUTY = 0x06F,
  FLAG_HIDE_TWO_ISLAND_GAME_CORNER_LOSTELLE = 0x075,
  FLAG_HIDE_TWO_ISLAND_GAME_CORNER_BIKER = 0x074,
  FLAG_HIDE_TWO_ISLAND_WOMAN = 0x07B,
  FLAG_HIDE_TWO_ISLAND_BEAUTY = 0x07C,
  FLAG_HIDE_TWO_ISLAND_POKE_MANIAC = 0x07D,
  FLAG_HIDE_LOSTELLE_IN_HER_HOME = 0x076,
  FLAG_HIDE_THREE_ISLAND_LONE_BIKER = 0x091,
  FLAG_HIDE_FOUR_ISLAND_RIVAL = 0x097,
  FLAG_HIDE_DOTTED_HOLE_SCIENTIST = 0x090,
  FLAG_HIDE_RESORT_GORGEOUS_SELPHY = 0x094,
  FLAG_HIDE_RESORT_GORGEOUS_INSIDE_SELPHY = 0x095,
  FLAG_HIDE_SELPHYS_BUTLER = 0x096,
  FLAG_HIDE_DEOXYS = 0x099,
  FLAG_HIDE_LORELEI_HOUSE_MEOWTH_DOLL = 0x0A5,
  FLAG_HIDE_LORELEI_HOUSE_CHANSEY_DOLL = 0x0A6,
  FLAG_HIDE_LORELEIS_HOUSE_NIDORAN_F_DOLL = 0x0A7,
  FLAG_HIDE_LORELEI_HOUSE_JIGGLYPUFF_DOLL = 0x0A8,
  FLAG_HIDE_LORELEIS_HOUSE_NIDORAN_M_DOLL = 0x0A9,
  FLAG_HIDE_LORELEIS_HOUSE_FEAROW_DOLL = 0x0AA,
  FLAG_HIDE_LORELEIS_HOUSE_PIDGEOT_DOLL = 0x0AB,
  FLAG_HIDE_LORELEIS_HOUSE_LAPRAS_DOLL = 0x0AC,
  FLAG_HIDE_POSTGAME_GOSSIPERS = 0x09D,
  FLAG_HIDE_FAME_CHECKER_ERIKA_JOURNALS = 0x09E,
  FLAG_HIDE_FAME_CHECKER_KOGA_JOURNAL = 0x09F,
  FLAG_HIDE_FAME_CHECKER_LT_SURGE_JOURNAL = 0x0A0,
  FLAG_HIDE_SAFFRON_CITY_POKECENTER_SABRINA_JOURNALS = 0x0AE,
}
GameSession._newGameVarIds = {
  VAR_0x403C = 0x403C,
  VAR_MASSAGE_COOLDOWN_STEP_COUNTER = 0x4025,
}

function GameSession._zeroBytes(count)
  return string.rep("\0", count)
end

function GameSession._setFlagBits(flagNames)
  local bytes = {}
  for i = 1, 288 do bytes[i] = 0 end -- SaveBlock1.flags is u8[288].
  for _, name in ipairs(flagNames) do
    local id = assert(GameSession._newGameFlagIds[name], "missing real new-game flag id: " .. tostring(name))
    local byteIndex, bit = math.floor(id / 8) + 1, id % 8
    bytes[byteIndex] = bytes[byteIndex] + 2 ^ bit
  end
  for i = 1, #bytes do bytes[i] = string.char(bytes[i]) end
  return table.concat(bytes)
end

function GameSession._initialVars()
  local vars = {}
  for i = 1, 256 do vars[i] = 0 end -- SaveBlock1.vars is u16[256].
  for _, entry in ipairs(NewGameDefaults.setVars) do
    local id = assert(GameSession._newGameVarIds[entry.var], "missing real new-game var id: " .. tostring(entry.var))
    vars[id - GameSession.VARS_START + 1] = entry.value
  end
  return vars
end

function GameSession._trainerIdBytes(nextRandom16, generatedTrainerIdLower)
  local high = assert(nextRandom16, "fresh session requires injected nextRandom16")() % 0x10000
  local low = (generatedTrainerIdLower or 0) % 0x10000
  return string.char(low % 256, math.floor(low / 256), high % 256, math.floor(high / 256))
end

function GameSession.fromNewGame(identity, opts)
  assert(identity and identity.playerName and identity.rivalName and identity.playerGender ~= nil,
    "fresh session requires a completed NewGameFlow result")
  opts = opts or {}
  local start = NewGameDefaults.startingWarp
  local location = { mapGroup=4, mapNum=1, warpId=start.warpId, x=start.x, y=start.y }
  local defaults = NewGameDefaults
  local trainerId = GameSession._trainerIdBytes(opts.nextRandom16 or function() return 0 end, opts.generatedTrainerIdLower)
  local state = {
    saveBlock2 = {
      playerName=identity.playerName, playerGender=identity.playerGender,
      specialSaveWarpFlags=defaults.saveBlock2.specialSaveWarpFlags,
      playerTrainerId=trainerId,
      playTimeHours=0, playTimeMinutes=0, playTimeSeconds=0, playTimeVBlanks=0,
      optionsButtonMode=defaults.options.buttonMode,
      options={
        textSpeed=defaults.options.textSpeed, windowFrameType=defaults.options.windowFrameType,
        sound=defaults.options.sound ~= 0, battleStyle=defaults.options.battleStyle ~= 0,
        battleSceneOff=defaults.options.battleSceneOff, regionMapZoom=defaults.options.regionMapZoom,
      },
      pokedex={ order=0, mode=0, unused=defaults.saveBlock2.pokedexUnused, nationalMagic=0,
        unownPersonality=0, spindaPersonality=0, unknown3=0, owned=GameSession._zeroBytes(52), seen=GameSession._zeroBytes(52) },
      gcnLinkFlags=defaults.saveBlock2.gcnLinkFlags, unkFlag1=defaults.saveBlock2.unkFlag1,
      unkFlag2=defaults.saveBlock2.unkFlag2, encryptionKey=defaults.saveBlock2.encryptionKey,
    },
    saveBlock1 = {
      pos={ x=start.x, y=start.y }, location=location,
      continueGameWarp={ mapGroup=0, mapNum=0, warpId=0, x=0, y=0 },
      dynamicWarp={ mapGroup=0, mapNum=0, warpId=0, x=0, y=0 },
      lastHealLocation={ mapGroup=0, mapNum=0, warpId=0, x=0, y=0 },
      escapeWarp={ mapGroup=0, mapNum=0, warpId=0, x=0, y=0 },
      savedMusic=0, weather=0, weatherCycleStage=0, flashLevel=0, mapLayoutId=0,
      playerPartyCount=defaults.startingPartyCount, playerParty={}, money=defaults.startingMoney,
      coins=0, registeredItem=0,
      pcItems={ { itemId=GameSession.ITEM_POTION, quantity=defaults.startingPCItems[1].quantity } },
      bagPocket_Items={}, bagPocket_KeyItems={}, bagPocket_PokeBalls={}, bagPocket_TMHM={}, bagPocket_Berries={},
      seen1=GameSession._zeroBytes(52), flags=GameSession._setFlagBits(defaults.setFlags), vars=GameSession._initialVars(), gameStats={}, rivalName=identity.rivalName,
    },
  }
  return setmetatable({
    identity={ playerGender=identity.playerGender, playerName=identity.playerName, rivalName=identity.rivalName },
    state=state, mapId=GameSession.MAP_PALLET_TOWN_PLAYERS_HOUSE_2F,
    location={ mapGroup=4, mapNum=1, warpId=start.warpId, x=start.x, y=start.y, facing="north" },
  }, { __index=GameSession })
end

-- Reconstructs a live session from a SaveFileCodec.decode()d state -- the
-- load-file counterpart to fromNewGame. `state` is already the exact
-- shape encodeSaveBlock1/encodeSaveBlock2 round-trip, so no field
-- translation is needed here, only deriving the two runtime-only
-- conveniences (identity, mapId/location) fromNewGame also carries
-- alongside the save-compatible `state` table.
--
-- Real FireRed derives the post-load facing direction from which side of
-- the destination warp tile the player entered through (WarpIntoMap);
-- this project's `location` field doesn't store that, so a loaded
-- session always faces south -- a documented simplification, matching
-- how bootstrapFreshSession also picks one fixed starting facing.
function GameSession.fromSavedState(state)
  assert(state and state.saveBlock1 and state.saveBlock2, "decoded save state is required")
  local loc = assert(state.saveBlock1.location, "decoded save has no location field")
  return setmetatable({
    identity={
      playerGender=state.saveBlock2.playerGender,
      playerName=state.saveBlock2.playerName,
      rivalName=state.saveBlock1.rivalName,
    },
    state=state, mapId=loc.mapGroup * 256 + loc.mapNum,
    location={ mapGroup=loc.mapGroup, mapNum=loc.mapNum, warpId=loc.warpId, x=loc.x, y=loc.y, facing="south" },
  }, { __index=GameSession })
end

function GameSession:setLocation(mapId, x, y, facing)
  self.mapId = mapId
  self.location.mapGroup, self.location.mapNum = math.floor(mapId / 256), mapId % 256
  self.location.x, self.location.y, self.location.facing = x, y, facing or self.location.facing
  local sb1 = self.state.saveBlock1
  sb1.pos.x, sb1.pos.y = x, y
  sb1.location.mapGroup, sb1.location.mapNum = self.location.mapGroup, self.location.mapNum
  sb1.location.warpId, sb1.location.x, sb1.location.y = -1, x, y
end

function GameSession:getVar(varId)
  assert(varId >= GameSession.VARS_START and varId <= 0x40FF,
    "event var id out of range: " .. tostring(varId))
  return self.state.saveBlock1.vars[varId - GameSession.VARS_START + 1] or 0
end

function GameSession:setVar(varId, value)
  assert(varId >= GameSession.VARS_START and varId <= 0x40FF,
    "event var id out of range: " .. tostring(varId))
  self.state.saveBlock1.vars[varId - GameSession.VARS_START + 1] = value % 0x10000
end

function GameSession._flagBit(flags, flagId)
  local index, bit = math.floor(flagId / 8) + 1, flagId % 8
  local byte = string.byte(flags, index) or 0
  return index, bit, byte, math.floor(byte / 2^bit) % 2 == 1
end

function GameSession:getFlag(flagId)
  local _, _, _, set = GameSession._flagBit(self.state.saveBlock1.flags, flagId)
  return set
end

function GameSession:setFlag(flagId)
  local flags = self.state.saveBlock1.flags
  local index, bit, byte, set = GameSession._flagBit(flags, flagId)
  if not set then
    self.state.saveBlock1.flags = flags:sub(1, index-1)
      .. string.char(byte + 2^bit) .. flags:sub(index+1)
  end
end

function GameSession:clearFlag(flagId)
  local flags = self.state.saveBlock1.flags
  local index, bit, byte, set = GameSession._flagBit(flags, flagId)
  if set then
    self.state.saveBlock1.flags = flags:sub(1, index-1)
      .. string.char(byte - 2^bit) .. flags:sub(index+1)
  end
end

function GameSession:usableBattleLead()
  return Battle.PartyBridge.findUsableLead(self.state.saveBlock1)
end

-- Phase 3: real grid-based player movement + collision (PlayerMovement.lua)
-- over the already-composited map, camera-cropped to a real GBA-screen-
-- sized (240x160px) viewport centered on the player.
local walkActive = false
local walkMapBlockData, walkMapWidth, walkMapHeight -- raw (unpadded) collision grid, set when the map loads
local walkMapWarps -- 0-indexed array of {x, y, elevation, warpId, mapNum, mapGroup} for the current map (MapEvents.lua, real Phase 1 data)
-- world.walkMapConnections (not a local): the current map's real
-- MapConnections (import/MapConnections.lua), or {} if none -- kept off
-- the main chunk's own locals for the same real Lua 200-local-per-chunk
-- limit noted elsewhere in this file (see world.beginMart's comment).
local walkMapId -- group*256+num of the currently-loaded map
local walkMapPrimaryAttrsPtr, walkMapSecondaryAttrsPtr -- current map's real Tileset.metatileAttributesPtr (MetatileAttributes.lua), for tall-grass/ledge behavior lookups

-- Everything the W view gained in the Phase 3 integration pass (real NPCs,
-- real NPC/sign dialogue, real wild-encounter rolls), deliberately bundled
-- into ONE table rather than a dozen module-level locals: love.draw /
-- love.update / love.keypressed are already close to Lua 5.1's hard
-- 60-upvalue-per-function limit (the same limit that forced
-- loadMapFromRom to be split into per-view loader functions above), and
-- one shared table costs each of them a single upvalue.
--   npcs           -- ObjectEventState.new() list for the current map, rebuilt per loadMap
--   npcImages      -- decoded standing sprites, cached by "graphicsId/facing" (never re-decoded per frame)
--   bgEvents     -- current map's real bg events (Town Signs etc), for A-button sign reading
--   dialogue       -- the active DialogueRunner, or nil when no message box is up
--   dialogueWindowImage / dialogueTextImage / dialogueBuiltTokenIndex -- dialogue box rendering + reveal cache
--   trigger        -- WildEncounterTrigger (persistent across map loads, like the real RNG streams)
--   landInfo       -- current map's real land WildPokemonInfo, or nil
--   battle        -- active BattleSceneController + derived image caches
--   battleCatalog -- ROM species/moves/type chart and static battle art
--   encounterLine -- last rolled encounter/outcome diagnostic
local world = {
  npcs = {},
  npcImages = {},
  bgEvents = {},
  coordEvents = {},
  dialogueBuiltTokenIndex = -1,
  -- saveCounter/saveBytes: the codec's own gSaveCounter-equivalent and
  -- the last full on-disk buffer this runtime produced, so a repeat save
  -- alternates real physical slots instead of rewriting the same one
  -- every time (see SaveFileCodec.encode's previousCounter/previousBytes
  -- params). Both start nil/0 for a runtime that hasn't saved or loaded
  -- yet; loadGameFile() fills them in from the file's own header.
  saveCounter = 0,
  saveBytes = nil,
}

-- Real land-encounter slot count (ENCOUNTER_CHANCE_LAND_MONS_SLOT count,
-- src/data/wild_encounters.h -- WildEncounters.resolveInfo needs told how
-- many WildPokemon entries to read, the struct doesn't carry a count).
local LAND_MONS_COUNT = 12

-- Set once the ROM verifies, so the data viewer (toggled at any time with
-- V) can browse records without re-reading the file. Declared this early
-- (rather than near the data-viewer state below) because
-- getMetatileBehaviorAt, defined just below, needs it.
local romData, romAddrs
local playerMovement
local loadMap, tryWarpAt, startWildBattle, syncSessionLocation, bootstrapFreshSession,
  tryEarlyStoryTriggerAt, acceptStarterChoice -- forward-declared: movement/encounter tasks call these before their definitions
-- world.connectionForEdge/world.tryConnectionAt (not locals): same real
-- 200-local-per-chunk limit as world.walkMapConnections above.
local WALK_CAMERA_WIDTH, WALK_CAMERA_HEIGHT = 240, 160 -- real GBA screen resolution

-- Real metatile BEHAVIOR byte at (x,y) (MetatileAttributes.lua, real
-- metatileAttributes bits 0-8), or nil if off-map/not loaded yet.
local function getMetatileBehaviorAt(x, y)
  if not walkMapBlockData or not walkMapPrimaryAttrsPtr or x < 0 or x >= walkMapWidth or y < 0 or y >= walkMapHeight then return nil end
  local cell = walkMapBlockData[y * walkMapWidth + x]
  if not cell then return nil end
  local attr = MetatileAttributes.resolveCombined(romData, walkMapPrimaryAttrsPtr, walkMapSecondaryAttrsPtr, cell.metatileId)
  return attr.behavior
end

local MB = MetatileAttributes.BEHAVIOR

-- isBlocked callback for PlayerMovement:tryMove -- real terrain collision
-- (MapBlockData's already-decoded collision field, see PlayerMovement.lua's
-- header comment for what's out of scope: object-event collision,
-- elevation mismatches, movement-range fencing). Off-map tiles (into the
-- border padding) are also treated as blocked, since the border isn't a
-- real walkable area.
--
-- Real door metatiles have nonzero raw collision bits (confirmed against
-- Pallet Town's player's-house door) -- the real game still lets the
-- player walk onto them because MapGridIsImpassableAt/
-- CheckForPlayerAvatarCollision-adjacent code special-cases specific real
-- BEHAVIOR bytes, not just the raw collision bits. Scoped here to the two
-- real door behaviors relevant to buildings/caves (MB_WARP_DOOR,
-- MB_CAVE_DOOR) -- other real passable-despite-collision behaviors (arrow
-- warps, stairs, ladders, fall/hole warps) aren't covered.
-- Real GetMapBorderIdAt/GetIncomingConnection (src/fieldmap.c): a step
-- exactly one tile past the current map's edge is allowed, not blocked,
-- when a real MapConnection exists for that edge's direction. Returns the
-- matching connection, or nil. Simplified vs. real source: this project
-- doesn't yet resolve the destination map's own width/height here to
-- reject a connection whose real coverage doesn't reach this particular
-- (x,y) (IsCoordInIncomingConnectingMap's own bounds check) -- fine for
-- every map connection landed so far (Pallet Town's north/south
-- connections are each the one and only connection for that direction
-- and span the whole shared edge), but a future map with more than one
-- partial connection per direction would need that check added.
world.connectionForEdge = function(x, y)
  if not world.walkMapConnections then return nil end
  local MapConnections = require("import.MapConnections")
  local direction
  if x < 0 then direction = MapConnections.CONNECTION_WEST
  elseif x >= walkMapWidth then direction = MapConnections.CONNECTION_EAST
  elseif y < 0 then direction = MapConnections.CONNECTION_NORTH
  elseif y >= walkMapHeight then direction = MapConnections.CONNECTION_SOUTH
  else return nil end
  for _, conn in pairs(world.walkMapConnections) do
    if conn.direction == direction then return conn end
  end
  return nil
end

local function isWalkTileBlocked(x, y)
  if not walkMapBlockData then return true end
  if x < 0 or x >= walkMapWidth or y < 0 or y >= walkMapHeight then
    return world.connectionForEdge(x, y) == nil
  end
  local behavior = getMetatileBehaviorAt(x, y)
  if behavior == MB.MB_WARP_DOOR or behavior == MB.MB_CAVE_DOOR then return false end
  local cell = walkMapBlockData[y * walkMapWidth + x]
  return not cell or cell.collision ~= 0
end

-- Player collision additionally respects live object events. The existing
-- NPC movement callbacks retain terrain-only collision until the general
-- object-vs-object collision system lands, but the player must not walk
-- through Oak, the rival, or the three starter balls to bypass their real
-- A-button interactions.
world.isPlayerWalkTileBlocked = function(x, y)
  if isWalkTileBlocked(x, y) then return true end
  for _, npc in ipairs(world.npcs) do
    if not npc.moving and npc.x == x and npc.y == y then return true end
  end
  return false
end

-- One-way ledges (event_object_movement.c's real GetLedgeJumpDirection):
-- returns the PlayerMovement direction constant a ledge at (x,y) jumps
-- toward, or nil if (x,y) isn't a ledge tile. See PlayerMovement.lua's
-- tryMove header comment for exactly how this is used/what's simplified.
local LEDGE_JUMP_DIRECTION = {
  [MB.MB_JUMP_SOUTH] = PlayerMovement.DOWN,
  [MB.MB_JUMP_NORTH] = PlayerMovement.UP,
  [MB.MB_JUMP_WEST] = PlayerMovement.LEFT,
  [MB.MB_JUMP_EAST] = PlayerMovement.RIGHT,
}
local function getLedgeJumpDirection(x, y)
  return LEDGE_JUMP_DIRECTION[getMetatileBehaviorAt(x, y)]
end

-- (Real tall-grass detection used to live here as isTallGrassTile. The
-- behavior byte is now handed straight to WildEncounterTrigger.lua, which
-- owns both the "is this a real land encounter tile" test and the real
-- previous-behavior tracking DoGlobalWildEncounterDiceRoll needs -- see
-- rollWildEncounterAt below.)

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
-- Test-only override consumed by love.update's otherwise normal keyboard
-- polling. Stored on world to stay within Lua 5.1's main-chunk local cap.
world.replayInputMask = nil

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

-- Real species name out of gSpeciesNames (same fixed-stride charmap table
-- the data viewer reads), for the encounter status line.
local function speciesName(species)
  local ok, name = pcall(Charmap.decodeAt, romData, romAddrs.gSpeciesNames, 11, species)
  return ok and name or ("species #" .. tostring(species))
end

-- Runs the real wild-encounter chain for a just-completed player step, then
-- hands the rolled species/level to the live Phase 4 battle scene.
local function rollWildEncounterAt(x, y)
  if not world.trigger or world.battle then return end
  local encounter = world.trigger:onStep(getMetatileBehaviorAt(x, y), world.landInfo)
  if not encounter then return end
  world.encounterLine = ("Wild %s (Lv %d) appeared!  [real slot %d]"):format(
    speciesName(encounter.species), encounter.level, encounter.slot)
  addLine(world.encounterLine)
  startWildBattle(encounter)
end

-- Real ScrCmd_trainerbattle's own trainerId argument
-- (gTrainerBattleOpponent_A, TrainerBattleLoadArg16 -- a plain literal in
-- the compiled script, never VarGet-resolved, src/battle_setup.c) is only
-- reachable by decoding the trainer's own object-event script and reading
-- its trainerbattle instruction, matching real CheckTrainer's `script[1]`
-- inspection (src/trainer_see.c:117 area) -- this project has no separate
-- "trainer roster" table, the trainerId genuinely only lives inside the
-- compiled script bytecode.
world.resolveTrainerId = function(scriptPtr)
  local ok, instrs = pcall(ScriptBytecode.decode, romData, scriptPtr)
  if not ok then return nil end
  for _, instr in ipairs(instrs) do
    if instr.op == "trainerbattle" then return instr.opponentOrSecond end
  end
  return nil
end

-- Real CheckForTrainersWantingBattle, called after each completed player
-- step (see TrainerSightline.lua's own real citations). Starts the real
-- exclamation+approach sequence rather than the battle directly -- the
-- battle itself only begins once TrainerApproach reports done (see
-- trainerApproachTask below).
world.tryTrainerSightlineAt = function(x, y)
  if not newGame.session then return false end
  local trainer, distance, direction = Battle.TrainerSightline.findTrainerWantingBattle(
    world.npcs, x, y, {
      isBlocked = isWalkTileBlocked,
      alreadyBattled = function(npc)
        local trainerId = world.resolveTrainerId(npc.scriptPtr)
        return trainerId ~= nil and newGame.session:getFlag(Battle.EarlyStory.TRAINER_FLAGS_START + trainerId)
      end,
    })
  if not trainer then return false end
  world.trainerApproach = Battle.TrainerApproach.new(trainer, direction, distance)
  return true
end

local function playerMovementTask(taskId)
  -- A real `lock`/`lockall` (and just having a message box up at all)
  -- freezes the player -- mirrored by not ticking movement at all while a
  -- dialogue script owns the screen. A pending trainer approach sequence
  -- freezes it the same real way (the real game locks field input the
  -- instant CheckForTrainersWantingBattle succeeds).
  if not walkActive or world.battle or world.starterChoice or world.trainerApproach
      or (world.dialogue and world.dialogue:isActive()) then return end
  local wasMoving = playerMovement.moving
  playerMovement:tick()
  if wasMoving and not playerMovement.moving then
    syncSessionLocation()
    -- A warp loads/repositions into a different map. The completed step
    -- belongs to the source map, so don't incorrectly roll the destination
    -- tile's encounter table during that same step.
    if not tryEarlyStoryTriggerAt(playerMovement.tileX, playerMovement.tileY)
        and not world.tryConnectionAt(playerMovement.tileX, playerMovement.tileY)
        and not tryWarpAt(playerMovement.tileX, playerMovement.tileY)
        and not world.tryTrainerSightlineAt(playerMovement.tileX, playerMovement.tileY) then
      rollWildEncounterAt(playerMovement.tileX, playerMovement.tileY)
    end
  end
end

-- Ticks a pending TrainerApproach every real frame (independent of the
-- player's own completed-step cadence -- the exclamation/walk-up
-- sequence must keep animating even while playerMovementTask itself is
-- frozen above). Once done, starts the real trainer battle. A world.*
-- field, not a local -- same real 200-local-per-chunk limit noted
-- elsewhere in this file.
world.trainerApproachTask = function(taskId)
  if not world.trainerApproach then return end
  world.trainerApproach:tick()
  if world.trainerApproach:isDone() then
    local trainer = world.trainerApproach.trainer
    world.trainerApproach = nil
    local trainerId = world.resolveTrainerId(trainer.scriptPtr)
    if not trainerId then
      addLine("Trainer battle could not start: this NPC's script has no real trainerbattle instruction.")
      return
    end
    world.startTrainerBattle(trainerId)
  end
end

-- Real per-frame object-event movement ticking (ObjectEventState:tick --
-- the real MovementType_* state machines). Runs on the same fixed 1/60s
-- scheduler tick as the player, since that's the real VBlank cadence both
-- share. An NPC whose real movement type has no ported per-tick handler
-- errors loudly by design (ObjectEventState's house style); caught here
-- per-NPC so one such NPC disables ITSELF with a visible note instead of
-- taking the whole game down.
local function npcMovementTask(taskId)
  if not walkActive or world.battle or world.starterChoice or world.trainerApproach
      or (world.dialogue and world.dialogue:isActive()) then return end
  for _, npc in ipairs(world.npcs) do
    if not npc.tickDisabled then
      local ok, err = pcall(npc.tick, npc)
      if not ok then
        npc.tickDisabled = true
        addLine(("NPC localId %d: movement ticking disabled -- %s"):format(npc.localId, tostring(err)))
      end
    end
  end
end

local function dialogueTask(taskId)
  local runner = world.dialogue
  if not runner then return end
  runner:tick(inputState:isNewlyPressed(InputState.A_BUTTON))
  -- Real ScrCmd_pokemart: the script paused itself (DialogueRunner's
  -- pendingMartItemListPtr) waiting for the real mart menu to open and
  -- close. Open it once, the same real BUY flow the M dev key already
  -- drives, just with the real script-provided stock list resolved from
  -- ROM instead of the M key's hardcoded Viridian fallback list.
  if runner.pendingMartItemListPtr and not world.martActive then
    world.beginMart(world.resolveMartItemList(runner.pendingMartItemListPtr))
    world.martActive = world.martMenu ~= nil
    if not world.martActive then
      -- beginMart() already logged why (no session/no item table) --
      -- don't leave the script permanently stuck waiting for a menu
      -- that will never appear.
      runner:notifyMartClosed()
    end
  end
  if runner.error then
    addLine("Script stopped: " .. tostring(runner.error))
    world.dialogue = nil
    world.dialogueBuiltTokenIndex = -1
  elseif not runner:isActive() then
    world.dialogue = nil
    world.dialogueBuiltTokenIndex = -1
  end
end

-- Real ViridianCity_Mart_Items (data/maps/ViridianCity_Mart/scripts.inc):
-- the first Poke Mart the player can reach, and this project's only
-- currently-imported mart stock list. Real map/NPC/script interaction to
-- actually walk in and trigger this (the real `pokemart` script command)
-- isn't wired yet -- pressing M below opens it directly, from any
-- session location, as a dev-reachable trigger for the otherwise-fully-
-- real PokemonMartMenu/PokemonMart/Bag/SessionBagBridge pipeline, the
-- same "pure+tested layer before its live map trigger" pattern this
-- project already used for e.g. the naming screen before New Game's own
-- proper story flow existed.
--
-- world.martActive/world.martMenu (not separate top-level locals): this
-- file is already near Lua 5.1's hard 200-local-variable-per-chunk limit
-- (a different, file-wide cap from the per-function 60-upvalue limit
-- documented elsewhere in this file), so new small pieces of state get
-- folded into the existing world table instead of adding new slots.

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

-- Decodes the static ROM tables/art needed by the bounded live battle once
-- at boot. Both monster sprites are dynamic and decoded once per encounter,
-- never per frame: the player back sprite follows the real session lead and
-- the foe front sprite follows the generated wild instance.
local function loadBattleSceneAssets(data, addrs, dbg)
  local ok, result = pcall(function()
    local catalog = {
      species = Battle.SpeciesInfo.parseTable(data, addrs.gSpeciesInfo, RomAddresses.COUNTS.NUM_SPECIES),
      moves = Battle.Move.parseTable(data, addrs.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT),
      typeChart = Battle.TypeChart.parseTable(data, addrs.gTypeEffectiveness),
      natures = Battle.Nature.parseTable(data, addrs.sNatureStatTable),
      trainers = Battle.Trainer.parseTable(data, addrs.gTrainers, RomAddresses.COUNTS.NUM_TRAINERS),
      items = Battle.Item.parseTable(data, addrs.gItems, RomAddresses.COUNTS.ITEMS_COUNT),
    }
    catalog.backgroundImage = buildImage(Battle.Assets.compositeGrassBackground(data, addrs))
    catalog.backgroundImage:setFilter("nearest", "nearest")
    return catalog
  end)
  if ok then
    world.battleCatalog = result
    dbg("battle species/move/nature/trainer tables and grass terrain built")
  else
    addLine("Battle scene assets failed: " .. tostring(result))
  end
end

local ensureRngStreams

-- StartWildBattle-equivalent integration boundary. Field/player/NPC input
-- is frozen simply by world.battle being non-nil (see all three task/input
-- guards); the same global Random()/gRngValue stream used by encounter
-- selection is handed first to GenerateWildMon's nature/personality/IV
-- construction, then to BattleEngine. Wild held-item selection remains
-- deliberately omitted: SetWildMonHeldItem runs later in CreateBattleStart
-- and consumes another Random() even for species with no distinct item.
-- Unown's chamber/letter-constrained personality loop is also not in the
-- ordinary factory, so those encounters fail visibly rather than silently
-- generating the wrong form. Status effects beyond the Oak-lab
-- Growl/Tail Whip subset, held-item mechanics, and general battle AI remain
-- outside the bounded slice.
startWildBattle = function(encounter)
  local catalog = world.battleCatalog
  if not catalog then
    addLine("Battle could not start: ROM battle assets are unavailable.")
    return false
  end
  ensureRngStreams()

  local partyRecord, partySlot, playerBattler, playerDecoded, temporaryPlayer
  if newGame.session then
    local reason
    partyRecord, partySlot, reason, playerDecoded = newGame.session:usableBattleLead()
    if not partyRecord then
      addLine("Wild battle refused: " .. tostring(reason)
        .. ". Obtain a starter before entering a live battle.")
      return false
    end
    local ok, battler = pcall(Battle.PartyBridge.battlerFromParty, partyRecord, catalog.species)
    if not ok then
      addLine("Wild battle refused: session lead is invalid: " .. tostring(battler))
      return false
    end
    playerBattler = battler
  else
    -- Developer screenshots/replays can opt into an isolated temporary
    -- party member. It is generated on its own RNG and is never inserted
    -- into GameSession.playerParty or described as a save/session member.
    local debugSpec = os.getenv("POKEPORT_BATTLE_DEBUG_PARTY")
    local playerSpecies, playerLevel
    if debugSpec then playerSpecies, playerLevel = debugSpec:match("^(%d+),(%d+)$") end
    if not playerSpecies then
      addLine("Wild battle refused: no session party. Set POKEPORT_BATTLE_DEBUG_PARTY=species,level only for a developer battle.")
      return false
    end
    playerSpecies, playerLevel = tonumber(playerSpecies), tonumber(playerLevel)
    local info = catalog.species[playerSpecies]
    if not info then
      addLine("Developer battle refused: temporary-party species is unavailable.")
      return false
    end
    local ok, instance = pcall(function()
      return Battle.WildFactory.generate({
        species=playerSpecies, level=playerLevel, speciesInfo=info,
        learnset=Battle.Learnset.resolve(romData, romAddrs.gLevelUpLearnsets, playerSpecies),
        battleMoves=catalog.moves, natures=catalog.natures,
        rng=Rng.new(tonumber(os.getenv("POKEPORT_BATTLE_DEBUG_PARTY_SEED") or "") or 0x4D3),
        speciesName=romData:sub(romAddrs.gSpeciesNames + playerSpecies * 11 + 1,
          romAddrs.gSpeciesNames + playerSpecies * 11 + 10),
        trainer={ id=0, name=NewGameFlow.encodeName("DEBUG"):sub(1, 7), gender=0 },
        metLocation=world.regionMapSectionId or 0,
      })
    end)
    if not ok then
      addLine("Developer battle refused: temporary party generation failed: " .. tostring(instance))
      return false
    end
    playerBattler = Battle.PartyBridge.battlerFromGenerated(instance)
    playerDecoded = instance.boxData
    temporaryPlayer = true
    addLine(("Developer-only temporary %s Lv %d is active; no session party was created.")
      :format(speciesName(playerSpecies), playerLevel))
  end

  local foeSpecies = catalog.species[encounter.species]
  if not foeSpecies then
    addLine("Battle could not start: decoded foe species record is unavailable.")
    return false
  end
  local trainer
  if newGame.session then
    local sb2 = newGame.session.state.saveBlock2
    trainer = { id=sb2.playerTrainerId, name=sb2.playerName:sub(1, 7), gender=sb2.playerGender }
  else
    trainer = { id=0, name=NewGameFlow.encodeName("DEBUG"):sub(1, 7), gender=0 }
  end
  local okGenerate, foeInstance = pcall(function()
    return Battle.WildFactory.generate({
      species=encounter.species, level=encounter.level, speciesInfo=foeSpecies,
      learnset=Battle.Learnset.resolve(romData, romAddrs.gLevelUpLearnsets, encounter.species),
      battleMoves=catalog.moves, natures=catalog.natures, rng=world.globalRng,
      speciesName=romData:sub(romAddrs.gSpeciesNames + encounter.species * 11 + 1,
        romAddrs.gSpeciesNames + encounter.species * 11 + 10),
      trainer=trainer, metLocation=world.regionMapSectionId or 0,
    })
  end)
  if not okGenerate then
    addLine("Battle could not start: wild Pokemon generation failed: " .. tostring(foeInstance))
    return false
  end
  local foeBattler = Battle.PartyBridge.battlerFromGenerated(foeInstance)

  local function firstDirectMoveSlot(battler)
    for i, slot in ipairs(battler.moves) do
      local move = catalog.moves[slot.move]
      if slot.pp > 0 and move and move.power > 0 then return i end
    end
    return nil
  end
  local playerDirectSlot = firstDirectMoveSlot(playerBattler)
  local foeDirectSlot = firstDirectMoveSlot(foeBattler)
  if not playerDirectSlot or not foeDirectSlot then
    addLine("Battle could not start: this direct-damage slice needs each battler to know a damaging move with PP.")
    return false
  end

  local engine = Battle.Engine.new({
    player=playerBattler, foe=foeBattler,
    moves=catalog.moves, typeChart=catalog.typeChart, rng=world.globalRng,
  })

  local foeName = speciesName(encounter.species)
  local playerName = Charmap.decode(playerDecoded.nickname)
  -- Real bag: BattleSceneController only offers a live BAG throw when it
  -- actually has one. A developer/temporary-party battle (no newGame.
  -- session) has no save-compatible saveBlock1 to bridge, so it still
  -- gets the bounded "no balls" message rather than a fabricated bag.
  local bag = newGame.session
    and Battle.SessionBagBridge.fromSaveBlock1(newGame.session.state.saveBlock1, catalog.items)
    or nil
  local controller = Battle.Controller.new({
    engine=engine, playerName=playerName, foeName=foeName,
    foeMoveSlot=foeDirectSlot, bag=bag,
    moveName=function(move) return Charmap.decodeAt(romData, romAddrs.gMoveNames, 13, move) end,
  })

  local images = {}
  for _, imageSpec in ipairs({ {"foeImage", encounter.species, false}, {"playerImage", playerBattler.species, true} }) do
    local ok, composite = pcall(Battle.Assets.decodeMon, romData, romAddrs, imageSpec[2], imageSpec[3])
    if ok then
      images[imageSpec[1]] = buildImage(composite)
      images[imageSpec[1]]:setFilter("nearest", "nearest")
    else
      addLine("Battle Pokemon sprite failed: " .. tostring(composite))
    end
  end
  world.battle = {
    controller=controller, encounter=encounter, foeInstance=foeInstance,
    foeImage=images.foeImage, playerImage=images.playerImage,
    partyRecord=partyRecord, partySlot=partySlot, persistedTurn=0,
    temporaryPlayer=temporaryPlayer,
    textImages={},
  }
  return true
end

-- trainerbattle_earlyrival integration for lab scene 3. Trainer metadata,
-- its one-mon party, fixed personality/IV construction, default moves, and
-- AI flags all come from the verified ROM tables. The current renderer has
-- no linked building-terrain or trainer-front assets, so it deliberately
-- reuses the already-imported battle backdrop and begins at the send-out;
-- the status line names that presentation gap rather than implying parity.
world.startRivalBattle = function(action)
  local catalog, session = world.battleCatalog, newGame.session
  if not catalog or not session then
    addLine("Oak-lab rival battle could not start: ROM catalog/session is unavailable.")
    return false
  end
  ensureRngStreams()

  local partyRecord, partySlot, reason, playerDecoded = session:usableBattleLead()
  if not partyRecord then
    addLine("Oak-lab rival battle refused: " .. tostring(reason))
    return false
  end
  local ok, built = pcall(function()
    local trainer = assert(catalog.trainers[action.trainerId], "rival trainer record is missing")
    assert(trainer.partySize == 1 and trainer.trainerClass == 81
      and trainer.partyFlags == 0 and trainer.aiFlags == Battle.RivalAI.AI_FLAGS,
      "trainer record is not an Oak-lab rival")
    local partyMon = assert(Battle.TrainerParty.resolve(trainer, romData)[0], "rival party is empty")
    assert(partyMon.lvl == 5 and partyMon.iv == 0, "Oak-lab rival party level/IV changed")
    local foeInfo = assert(catalog.species[partyMon.species], "rival species record is missing")
    local foe = Battle.TrainerFactory.generate({
      trainer=trainer, partyMon=partyMon, speciesInfo=foeInfo,
      speciesName=romData:sub(romAddrs.gSpeciesNames + partyMon.species * 11 + 1,
        romAddrs.gSpeciesNames + partyMon.species * 11 + 10),
      learnset=Battle.Learnset.resolve(romData, romAddrs.gLevelUpLearnsets, partyMon.species),
      battleMoves=catalog.moves, natures=catalog.natures, rng=world.globalRng,
    })
    local player = Battle.PartyBridge.battlerFromParty(partyRecord, catalog.species)
    local engine = Battle.Engine.new({
      player=player, foe=Battle.PartyBridge.battlerFromGenerated(foe),
      moves=catalog.moves, typeChart=catalog.typeChart, rng=world.globalRng,
      firstBattle=true,
    })
    local rivalName = Charmap.decode(session.state.saveBlock1.rivalName)
    local playerName = Charmap.decode(playerDecoded.nickname)
    local foeName = speciesName(foe.species)
    local controller = Battle.Controller.new({
      engine=engine, playerName=playerName, foeName=foeName,
      chooseFoeMove=function(e) return Battle.RivalAI.choose(e, trainer.aiFlags) end,
      runDisabledMessage="OAK: No! There's no running away\nfrom a TRAINER POKEMON battle!",
      introMessages={
        rivalName .. ": Wait, " .. Charmap.decode(session.state.saveBlock2.playerName) .. "!\nLet's check out our POKEMON!",
        "Come on, I'll take you on!",
        "RIVAL " .. rivalName .. " would like to battle!",
        "RIVAL " .. rivalName .. " sent out " .. foeName .. "!",
        "Go! " .. playerName .. "!",
        "OAK: You've never had a POKEMON\nbattle before, have you?",
        "The TRAINER that lowers the foe's\nHP to 0 wins.",
        "Try battling and see for yourself!",
      },
      moveName=function(move) return Charmap.decodeAt(romData, romAddrs.gMoveNames, 13, move) end,
    })
    return {
      trainer=trainer, foe=foe, player=player, controller=controller,
      playerDecoded=playerDecoded, partyRecord=partyRecord, partySlot=partySlot,
      playerName=playerName, rivalName=rivalName, foeName=foeName,
    }
  end)
  if not ok then
    addLine("Oak-lab rival battle failed source validation: " .. tostring(built))
    return false
  end

  local images = {}
  for _, imageSpec in ipairs({ {"foeImage", built.foe.species, false},
      {"playerImage", built.player.species, true} }) do
    local imageOk, composite = pcall(Battle.Assets.decodeMon,
      romData, romAddrs, imageSpec[2], imageSpec[3])
    if imageOk then
      images[imageSpec[1]] = buildImage(composite)
      images[imageSpec[1]]:setFilter("nearest", "nearest")
    else
      addLine("Rival-battle Pokemon sprite failed: " .. tostring(composite))
    end
  end
  world.battle = {
    kind="oakLabRival", controller=built.controller, trainerId=action.trainerId,
    trainer=built.trainer, foeInstance=built.foe,
    foeImage=images.foeImage, playerImage=images.playerImage,
    partyRecord=built.partyRecord, partySlot=built.partySlot, persistedTurn=0,
    playerName=built.playerName, rivalName=built.rivalName, settled=false,
    textImages={},
  }
  newGame.story:registerSeen(Battle.PokedexOrder.speciesToNationalDexNum(
    romData, romAddrs.sSpeciesToNationalPokedexNum, built.foe.species))
  addLine(("Oak-lab rival tutorial started (trainer %d, Lv 5 %s). Building terrain/trainer-front presentation awaits linked ROM addresses; rules and persistence are live.")
    :format(action.trainerId, built.foeName))
  return true
end

-- General live trainer battle (any real trainer reached via
-- TrainerSightline/TrainerApproach, not just the Oak-lab rival). Bounded
-- to a single-mon party for now: TrainerPokemonFactory.generate itself
-- asserts real partyFlags==0 (no held item/no custom moveset) and
-- !doubleBattle (see that module's header) -- a trainer outside that
-- shape, or with more than one party mon, fails loudly here rather than
-- silently mis-building a battle. Multi-mon trainer parties are a real,
-- separate follow-up: BattleEngine's forced-switch-after-faint primitive
-- (opts.hasReplacement/resolveForcedSwitch) already exists and would be
-- the right mechanism, but wiring a live foe-side party-of-N through it
-- (auto-advancing to the trainer's next mon, updating the displayed foe
-- sprite/name) is deliberately deferred rather than rushed into this
-- same pass.
world.startTrainerBattle = function(trainerId)
  local catalog, session = world.battleCatalog, newGame.session
  if not catalog or not session then
    addLine("Trainer battle could not start: ROM catalog/session is unavailable.")
    return false
  end
  ensureRngStreams()

  local partyRecord, partySlot, reason, playerDecoded = session:usableBattleLead()
  if not partyRecord then
    addLine("Trainer battle refused: " .. tostring(reason))
    return false
  end
  local ok, built = pcall(function()
    local trainer = assert(catalog.trainers[trainerId], "trainer record is missing")
    assert(trainer.partySize == 1,
      "multi-mon trainer parties are not wired into the live scene yet (see startTrainerBattle's header)")
    -- Fail before the battle starts, not mid-battle when TrainerAI.choose
    -- is first called -- see TrainerAI.lua's own header for exactly which
    -- real aiFlags tiers are ported (0, AI_SCRIPT_CHECK_BAD_MOVE alone --
    -- real-ROM-confirmed as the common tier ordinary route trainers carry
    -- -- and the rival's own AI_FLAGS combo).
    assert(trainer.aiFlags == 0 or trainer.aiFlags == Battle.TrainerAI.AI_SCRIPT_CHECK_BAD_MOVE
      or trainer.aiFlags == Battle.RivalAI.AI_FLAGS,
      ("trainer aiFlags 0x%X is not one of TrainerAI.lua's ported real tiers"):format(trainer.aiFlags))
    local partyMon = assert(Battle.TrainerParty.resolve(trainer, romData)[0], "trainer party is empty")
    local foeInfo = assert(catalog.species[partyMon.species], "trainer foe species record is missing")
    local foe = Battle.TrainerFactory.generate({
      trainer=trainer, partyMon=partyMon, speciesInfo=foeInfo,
      speciesName=romData:sub(romAddrs.gSpeciesNames + partyMon.species * 11 + 1,
        romAddrs.gSpeciesNames + partyMon.species * 11 + 10),
      learnset=Battle.Learnset.resolve(romData, romAddrs.gLevelUpLearnsets, partyMon.species),
      battleMoves=catalog.moves, natures=catalog.natures, rng=world.globalRng,
    })
    local player = Battle.PartyBridge.battlerFromParty(partyRecord, catalog.species)
    local engine = Battle.Engine.new({
      player=player, foe=Battle.PartyBridge.battlerFromGenerated(foe),
      moves=catalog.moves, typeChart=catalog.typeChart, rng=world.globalRng,
    })
    local trainerName = Charmap.decode(trainer.rawName)
    local playerName = Charmap.decode(playerDecoded.nickname)
    local foeName = speciesName(foe.species)
    -- Real trainer battles have no gTrainerClassNames decode in this
    -- project yet (no import/*.lua module for it) -- the trainer's own
    -- real decoded name is shown alone rather than guessing a class
    -- prefix like "YOUNGSTER BEN".
    local controller = Battle.Controller.new({
      engine=engine, playerName=playerName, foeName=foeName,
      chooseFoeMove=function(e) return Battle.TrainerAI.choose(e, trainer.aiFlags) end,
      runDisabledMessage="No! There's no running\nfrom a TRAINER battle!",
      introMessages={
        trainerName .. " would like to battle!",
        trainerName .. " sent out " .. foeName .. "!",
        "Go! " .. playerName .. "!",
      },
      moveName=function(move) return Charmap.decodeAt(romData, romAddrs.gMoveNames, 13, move) end,
    })
    return {
      trainer=trainer, foe=foe, player=player, controller=controller,
      playerDecoded=playerDecoded, partyRecord=partyRecord, partySlot=partySlot,
      playerName=playerName, trainerName=trainerName, foeName=foeName,
    }
  end)
  if not ok then
    addLine("Trainer battle failed to start: " .. tostring(built))
    return false
  end

  local images = {}
  for _, imageSpec in ipairs({ {"foeImage", built.foe.species, false},
      {"playerImage", built.player.species, true} }) do
    local imageOk, composite = pcall(Battle.Assets.decodeMon,
      romData, romAddrs, imageSpec[2], imageSpec[3])
    if imageOk then
      images[imageSpec[1]] = buildImage(composite)
      images[imageSpec[1]]:setFilter("nearest", "nearest")
    else
      addLine("Trainer-battle Pokemon sprite failed: " .. tostring(composite))
    end
  end
  world.battle = {
    kind="trainer", controller=built.controller, trainerId=trainerId,
    trainer=built.trainer, foeInstance=built.foe,
    foeImage=images.foeImage, playerImage=images.playerImage,
    partyRecord=built.partyRecord, partySlot=built.partySlot, persistedTurn=0,
    playerName=built.playerName, trainerName=built.trainerName,
    textImages={},
  }
  newGame.story:registerSeen(Battle.PokedexOrder.speciesToNationalDexNum(
    romData, romAddrs.sSpeciesToNationalPokedexNum, built.foe.species))
  addLine(("Trainer battle started: %s (trainer %d, Lv %d %s)."):format(
    built.trainerName, trainerId, built.foe.level, built.foeName))
  return true
end

-- Scans the loaded map's real collision grid for the first walkable tile:
-- a developer-map-view and malformed-warp fallback. Fresh sessions use the
-- canonical WarpToPlayersRoom destination below, never this heuristic.
local function findFirstWalkableTile()
  for y = 0, walkMapHeight - 1 do
    for x = 0, walkMapWidth - 1 do
      if not isWalkTileBlocked(x, y) then return x, y end
    end
  end
  return nil
end

-- Both real RNG streams, created ONCE at first use and then kept for the
-- whole session (never re-seeded on a map load -- the real gRngValue and
-- sWildEncounterData.rngState both persist across map transitions; re-
-- seeding per map would make every entry into the same patch of grass roll
-- identically). Fixed default seed so screenshots/replays are
-- deterministic, matching how every other *_TICKS env knob in this file
-- trades real elapsed time for reproducibility; POKEPORT_RNG_SEED=N
-- overrides it.
ensureRngStreams = function()
  if world.globalRng then return end
  local seed = tonumber(os.getenv("POKEPORT_RNG_SEED") or "") or 0x5A0B
  world.globalRng = Rng.new(seed)
  world.trigger = WildEncounterTrigger.new({
    globalRng = world.globalRng,
    triggerRng = WildEncounterSelector.newTriggerRng(seed),
  })
end

-- Per-map object-event (NPC) + bg-event + wild-encounter-table setup,
-- called from loadMap so a real warp into a new map gets its own fresh NPC
-- list instead of dragging the previous map's along. Real NPC movement
-- draws from the shared global Random() stream (same one the encounter
-- rolls use), matching the real game's single gRngValue.
local function loadMapObjectEvents(data, events, mapId)
  ensureRngStreams()

  world.npcs = {}
  world.npcImages = {}
  world.bgEvents = events.bgEvents or {}
  world.coordEvents = events.coordEvents or {}
  world.dialogue = nil
  world.dialogueBuiltTokenIndex = -1

  -- SpawnObjectEventsOnMapEntry skips templates whose FLAG_HIDE_* bit is
  -- set. Before a real session exists the map remains a data/demo view and
  -- keeps the historical behavior of showing all decoded templates.
  local objectEvents = events.objectEvents
  if newGame.session then
    objectEvents = {}
    local sourceIndex, destIndex = 0, 0
    while events.objectEvents[sourceIndex] ~= nil do
      local template = events.objectEvents[sourceIndex]
      local hiddenByFlag = template.flagId and template.flagId ~= 0
        and newGame.session:getFlag(template.flagId)
      local removedByStory = newGame.story
        and newGame.story:isObjectRemoved(mapId, template.localId)
      if not hiddenByFlag and not removedByStory then
        objectEvents[destIndex] = template
        destIndex = destIndex + 1
      end
      sourceIndex = sourceIndex + 1
    end
  end

  local ok, npcs, skippedClones = pcall(ObjectEventState.new, objectEvents, {
    rng = world.globalRng,
    isBlocked = isWalkTileBlocked,
  })
  if not ok then
    addLine("Object events failed to build: " .. tostring(npcs))
    return
  end
  world.npcs = npcs
  -- Real OBJ_KIND_CLONE templates are reported, not silently dropped (see
  -- ObjectEventState.lua's header -- resolving one means parsing a
  -- different map's object events, a separate system).
  addLine(("Loaded %d real object-event NPCs (%d clone objects skipped)"):format(#npcs, #skippedClones))

  -- Real per-map land wild encounter table (gWildMonHeaders is a flat
  -- array linear-scanned by map group/num, not indexed -- see
  -- WildEncounters.lua). Absent for most indoor maps, which is why this
  -- is a plain nil rather than an error.
  world.landInfo = nil
  local header = WildEncounters.findHeader(data, romAddrs.gWildMonHeaders, math.floor(mapId / 256), mapId % 256)
  if header then
    world.landInfo = WildEncounters.resolveInfo(data, header.landMonsInfoPtr, LAND_MONS_COUNT)
  end
  if world.landInfo then
    addLine(("Real land encounter table loaded: encounterRate %d, %d slots"):format(world.landInfo.encounterRate, LAND_MONS_COUNT))
  end
end

-- Real RemoveObjectEventByLocalIdAndMap (src/event_object_movement.c): sets
-- the object's own real hide flag (so it stays gone on a future map
-- reload, same FLAG_HIDE_* mechanism loadMapObjectEvents already checks
-- via template.flagId) AND despawns its live sprite immediately, without
-- waiting for a reload. The general primitive the real `removeobject`
-- script opcode drives (see ScriptInterpreter.lua/DialogueRunner.lua) --
-- EarlyStory.lua's own removedLabObjects/isObjectRemoved predates this and
-- is intentionally left alone (it's a bespoke abbreviated-cutscene
-- controller that doesn't run through the real script VM at all, so it
-- can't call this hook directly), but any future story content driven by
-- a real script can now use the real opcode instead of a one-off table.
world.removeNpcLive = function(localId)
  local kept, removedFlagId = {}, nil
  for _, npc in ipairs(world.npcs) do
    if npc.localId == localId then
      removedFlagId = npc.flagId
    else
      kept[#kept + 1] = npc
    end
  end
  world.npcs = kept
  if removedFlagId and removedFlagId ~= 0 and newGame.session then
    newGame.session:setFlag(removedFlagId)
  end
end

-- Called once at boot: places the player and starts the movement task.
-- Later map loads (via a real warp, see loadMap/tryWarpAt) just
-- reposition the existing playerMovement instead of recreating it.
local function loadWalkAssets(dbg)
  if not walkMapBlockData then return end
  local x, y = findFirstWalkableTile()
  if not x then
    dbg("player movement failed: no walkable tile found on this map")
    return
  end
  playerMovement = PlayerMovement.new(x, y, PlayerMovement.DOWN)
  scheduler:createTask(playerMovementTask, 0)
  scheduler:createTask(npcMovementTask, 0)
  scheduler:createTask(dialogueTask, 0)
  scheduler:createTask(world.trainerApproachTask, 0)
  dbg(("player movement started at first walkable tile %d,%d"):format(x, y))
end

-- The full real Oak intro scene as its own view (S). Static composite,
-- built once here rather than per frame -- same caching rule as every
-- other decoded image in this file.
local function loadOakSceneAssets(data, addrs, dbg)
  local ok, composited = pcall(OakSpeechScene.composite, data, addrs)
  if ok then
    oakSceneImage = buildImage(composited)
    oakSceneImage:setFilter("nearest", "nearest")
    dbg("Oak intro scene composited")
  else
    dbg("Oak intro scene failed: " .. tostring(composited))
  end
end

local function rawCharmapStringAt(data, offset, maxLength)
  local last = offset
  local cap = offset + (maxLength or 256) - 1
  while last <= cap and string.byte(data, last + 1) ~= Charmap.TERMINATOR do last = last + 1 end
  return data:sub(offset + 1, last + 1)
end

local function renderNewGameMenuText(data, addrs, text)
  -- Rebuild with real 0xFA linebreaks (the uppercase helper intentionally
  -- only owns simple glyph conversion for existing demo menus).
  local bytes = {}
  for line in text:gmatch("[^\n]+") do
    if #bytes > 0 then bytes[#bytes + 1] = string.char(0xFA) end
    bytes[#bytes + 1] = charmapBytesForUppercaseAndSpaces(line)
  end
  bytes[#bytes + 1] = string.char(Charmap.TERMINATOR)
  local tokens = { { type="color", fg=2, shadow=3 } }
  for _, token in ipairs(Charmap.tokenize(table.concat(bytes))) do tokens[#tokens + 1] = token end
  return buildImage(TextRenderer.renderTokens(data, addrs, tokens, fontPalette))
end

-- Real menu windows/assets needed around the pure NewGameFlow state.
-- The naming keyboard itself is composited by NamingScreenScene directly
-- from its dedicated ROM tilemaps, palettes, row strings, and cursor OBJ.
local function loadNewGameAssets(data, addrs, dbg)
  local ok, err = pcall(function()
    local tiles = TextWindow.decodeFrameTiles(data, addrs.gStdTextWindow_Gfx)
    local palette = TextWindow.decodePalette(data, addrs.gTextWindowPalettes, TextWindow.STD_PALETTE_INDEX)
    newGame.genderWindowImage = buildImage(TextWindow.compositeFrame(tiles, palette, 9, 4))
    newGame.rivalWindowImage = buildImage(TextWindow.compositeFrame(tiles, palette, 12, 10))
    newGame.confirmWindowImage = buildImage(TextWindow.compositeFrame(tiles, palette, 6, 4))
    newGame.genderTextImage = renderNewGameMenuText(data, addrs, "BOY\nGIRL")
    newGame.rivalTextImage = renderNewGameMenuText(data, addrs, "NEW NAME\nGREEN\nGARY\nKAZ\nTORU")
    newGame.confirmTextImage = renderNewGameMenuText(data, addrs, "YES\nNO")
    local arrowPixels = Font.decodeGlyphPixelTypes(data, addrs.sFontHalfRowOffsets, addrs.sFontNormalLatinGlyphs, 0xEF)
    local arrowWidth = string.byte(data, addrs.sFontNormalLatinGlyphWidths + 0xEF + 1)
    newGame.arrowImage = buildImage(Font.buildGlyphImage(arrowPixels, arrowWidth, fontPalette[2], fontPalette[3]))
    local fill = fontPalette[1]
    newGame.fillColor = { fill.r / 255, fill.g / 255, fill.b / 255 }
    for _, image in ipairs({newGame.genderWindowImage, newGame.rivalWindowImage, newGame.confirmWindowImage,
      newGame.genderTextImage, newGame.rivalTextImage, newGame.confirmTextImage}) do
      image:setFilter("nearest", "nearest")
    end
    local identityRng = Rng.new(0)
    newGame.flow = NewGameFlow.new({ nextRandom16 = function() return identityRng:next16() end })
    newGame.builtRevision = -1
  end)
  if ok then dbg("post-Oak gender/player/rival naming flow loaded")
  else dbg("new-game identity flow failed: " .. tostring(err)) end
end

local function beginNewGameFlow()
  if not newGame.flow then return end
  viewerActive, titleActive, spriteActive, itemBallActive = false, false, false, false
  fontActive, oakSpeechActive, oakSceneActive = false, false, false
  flameActive, yesNoActive, walkActive = false, false, false
  newGame.flow = NewGameFlow.new({ nextRandom16 = function()
    newGame.identityRng = newGame.identityRng or Rng.new(0)
    return newGame.identityRng:next16()
  end })
  newGame.active = true
  newGame.session = nil
  newGame.story = nil
  world.starterChoice = nil
  newGame.builtRevision = -1
end

-- Real ViridianCity_Mart_Items array shape: consecutive real u16 item ids
-- at `ptr`, terminated by ITEM_NONE(0) (data/maps/ViridianCity_Mart/
-- scripts.inc). Used to turn a real `pokemart` script instruction's raw
-- ROM pointer (ScriptBytecode.lua's decoded itemListPtr) into an actual
-- item id list -- the same real table shape tests/script_interpreter_
-- test.lua already verified end-to-end against the ROM.
-- world.resolveMartItemList (not a top-level local): dialogueTask, which
-- calls this, is defined earlier in the file than this assignment runs,
-- so a plain `local function` here would be an invisible forward
-- reference from dialogueTask's point of view (Lua locals aren't visible
-- to code lexically before their declaration) -- a table field read is
-- resolved at call time instead, so this works the same way world.
-- beginMart/closeMart/martLines already had to for the same reason (see
-- the file-wide 200-local-variable note near VIRIDIAN_MART_ITEMS' old
-- declaration above).
world.resolveMartItemList = function(ptr)
  local items = {}
  local base = ptr - ScriptBytecode.romBase
  for i = 0, 63 do -- generous real bound; every real mart stocks well under this
    local off = base + i * 2
    local id = romData:byte(off + 1) + romData:byte(off + 2) * 256
    if id == 0 then break end
    items[#items + 1] = id
  end
  return items
end

-- Opens the real Poke Mart BUY/SELL flow against the active session's
-- real bag/money -- SessionBagBridge.fromSaveBlock1, same as
-- startWildBattle already builds one. `itemIds` is the real BUY stock
-- list (the caller resolves it -- either the M dev key's hardcoded
-- Viridian list, or a live `pokemart` script trigger's real resolved
-- pointer); SELL sources its own list from the live bag instead (see
-- PokemonMartMenu.lua).
world.beginMart = function(itemIds)
  if not newGame.session or not world.battleCatalog or not world.battleCatalog.items then
    addLine("Mart could not open: no active session or ROM item table unavailable.")
    return
  end
  local sb1 = newGame.session.state.saveBlock1
  local bag = Battle.SessionBagBridge.fromSaveBlock1(sb1, world.battleCatalog.items)
  world.martMenu = Battle.MartMenu.new({
    itemIds = itemIds, itemLookup = world.battleCatalog.items,
    bag = bag, money = sb1.money or 0,
  })
end

-- Writes the mart's real final bag/money state back into the session,
-- matching startWildBattle's own bag-persists-on-battle-end convention.
world.closeMart = function()
  if world.martMenu and newGame.session then
    local sb1 = newGame.session.state.saveBlock1
    Battle.SessionBagBridge.toSaveBlock1(world.martMenu.bag, sb1)
    sb1.money = world.martMenu.money
    addLine(("Left the mart. Money: $%d."):format(sb1.money))
  end
  world.martMenu = nil
  world.martActive = false
  -- Real ScrCmd_pokemart's ScriptContext_Stop() resumes once the real
  -- mart menu closes -- if this mart was opened by a live script
  -- (DialogueRunner's pendingMartItemListPtr), tell it to resume past
  -- pokemart into whatever real instructions follow (a real trailing
  -- "Please come again"/release/end, per the Viridian Mart clerk script).
  if world.dialogue and world.dialogue.pendingMartItemListPtr then
    world.dialogue:notifyMartClosed()
  end
end

-- Opens the real overworld START menu (src/start_menu.c's
-- SetUpStartMenu_NormalField -- see StartMenu.lua's own header for the
-- exact real item gating). Real FLAG_SYS_POKEMON_GET/FLAG_SYS_POKEDEX_GET
-- values already live on EarlyStory (Battle.EarlyStory.FLAG_SYS_POKEMON_GET
-- = 0x828); FLAG_SYS_POKEDEX_GET = 0x829 is the same SYS_FLAGS+0x29 real id
-- (include/constants/flags.h) -- this project has no Pokedex-acquisition
-- flow yet, so that flag is always unset today, correctly hiding POKéDEX.
world.openStartMenu = function()
  local hasPokemon = newGame.session and newGame.session:getFlag(Battle.EarlyStory.FLAG_SYS_POKEMON_GET) or false
  local hasPokedex = newGame.session and newGame.session:getFlag(0x829) or false
  world.startMenu = Battle.StartMenu.new({ hasPokemon = hasPokemon, hasPokedex = hasPokedex })
  world.startMenuActive = true
end

world.closeStartMenu = function()
  world.startMenu = nil
  world.startMenuActive = false
  world.partyScreen = nil
  world.partyScreenActive = false
  if world.bagScreen and newGame.session then
    Battle.SessionBagBridge.toSaveBlock1(world.bagScreen.bag, newGame.session.state.saveBlock1)
  end
  world.bagScreen = nil
  world.bagScreenActive = false
end

-- Real StartMenuPokemonCallback (src/start_menu.c) -> CB2_PartyMenuFromStartMenu
-- (src/party_menu.c ~5428): opens the real Party Screen against the live
-- session party. BAG opens the real field-context Bag screen
-- (StartMenuBagCallback -> Task_BagMenu_HandleInput) against the same
-- real session bag the Mart/battle BAG action already share
-- (SessionBagBridge, matching startWildBattle/beginMart's own pattern) --
-- view/select only for now, no item-use context menu yet (see
-- BagScreen.lua's header for that boundary). Every other real item this
-- project doesn't have a live system for yet (PLAYER's Trainer Card,
-- OPTION) shows a bounded, honest "not available yet" line instead of
-- pretending to open something. SAVE reuses the real, already-live
-- saveGame() (bound to the dev K key too) -- StartMenuSaveCallback's real
-- job (src/start_menu.c) is exactly "run the save flow", which this
-- project's saveGame() already does end to end.
world.handleStartMenuSelection = function()
  local itemId = world.startMenu.selectedItemId
  if itemId == Battle.StartMenu.BAG then
    if newGame.session and world.battleCatalog and world.battleCatalog.items then
      local sb1 = newGame.session.state.saveBlock1
      local bag = Battle.SessionBagBridge.fromSaveBlock1(sb1, world.battleCatalog.items)
      world.bagScreen = Battle.BagScreen.new(bag)
      world.bagScreenActive = true
    else
      addLine("Bag could not open: no active session or ROM item table unavailable.")
    end
  elseif itemId == Battle.StartMenu.POKEMON then
    if newGame.session and (newGame.session.state.saveBlock1.playerPartyCount or 0) > 0 then
      local sb1 = newGame.session.state.saveBlock1
      -- PartyScreen.new only needs a read-only {:size(), :get(slot)}
      -- shape (see its own assert) -- a thin adapter over the session's
      -- real save-format playerParty array/count, not a PartyModel (that
      -- module is a separate, mutable add/remove container this screen
      -- has no need to build or copy into).
      local partyView = {
        size = function() return sb1.playerPartyCount or 0 end,
        get = function(_, slot) return sb1.playerParty[slot] end,
      }
      world.partyScreen = Battle.PartyScreen.new(partyView)
      world.partyScreenActive = true
    else
      addLine("No active session party to show.")
    end
  elseif itemId == Battle.StartMenu.SAVE then
    if newGame.session then saveGame() else addLine("Nothing to save yet -- no active session.") end
  elseif itemId == Battle.StartMenu.EXIT then
    -- Real StartMenuExitCallback: closes straight back to the overworld,
    -- unlike every other item which returns to the (still open) Start
    -- menu -- so this is the one branch that must NOT fall through to the
    -- reopen-the-menu step below.
    world.closeStartMenu()
    return
  else
    addLine(("%s is not available yet."):format(tostring(itemId)))
  end
  -- Real CB2_ReturnToFieldWithOpenMenu-adjacent behavior: after handling an
  -- item, control returns to the (still open) Start menu -- reopen it
  -- rather than leaving it stuck in the SELECTED state.
  world.startMenu.state = Battle.StartMenu.OPEN
  world.startMenu.selectedItemId = nil
end

local NEW_GAME_PROMPT_SYMBOL = {
  [NewGameFlow.GENDER] = "gOakSpeech_Text_AskPlayerGender",
  [NewGameFlow.PLAYER_CONFIRM] = "gOakSpeech_Text_SoYourNameIsPlayer",
  [NewGameFlow.RIVAL_CHOICE] = "gOakSpeech_Text_YourRivalsNameWhatWasIt",
  [NewGameFlow.RIVAL_CONFIRM] = "gOakSpeech_Text_ConfirmRivalName",
}

local function ensureNewGameImageCurrent()
  local flow = newGame.flow
  if not newGame.active or not flow or not romData or flow.revision == newGame.builtRevision then return end

  local ok, composited = pcall(function()
    if flow.state == NewGameFlow.PLAYER_NAMING or flow.state == NewGameFlow.RIVAL_NAMING then
      return NamingScreenScene.composite(romData, romAddrs, {
        kind = flow.state == NewGameFlow.RIVAL_NAMING and "rival" or "player",
        state = flow.naming,
        entryBytes = flow.naming:entryBytes(),
      })
    end

    local symbol = NEW_GAME_PROMPT_SYMBOL[flow.state]
    if symbol then
      return OakSpeechScene.composite(romData, romAddrs, {
        withOak = false,
        tokens = Charmap.tokenize(rawCharmapStringAt(romData, romAddrs[symbol])),
        substitutions = {
          PLAYER = flow:displayName(flow.playerName),
          RIVAL = flow:displayName(flow.rivalName),
        },
      })
    end
    return OakSpeechScene.composite(romData, romAddrs, { withOak=false, withText=false })
  end)
  if ok then
    newGame.screenImage = buildImage(composited)
    newGame.screenImage:setFilter("nearest", "nearest")
  else
    newGame.error = tostring(composited)
  end
  newGame.builtRevision = flow.revision
end

-- Loads and composites a real map by id (group*256+num), setting
-- mapImage/walkMapBlockData/walkMapWidth/walkMapHeight/walkMapWarps/
-- walkMapId -- shared by the initial boot load and real warp-triggered
-- map transitions (tryWarpAt below), so a warp doesn't need its own
-- separate copy of this pipeline.
function loadMap(data, addrs, mapId, dbg)
  local header = MapHeader.resolve(data, addrs.gMapGroups, mapId)
  dbg("header resolved")
  world.regionMapSectionId = header.regionMapSectionId
  local layout = MapLayout.resolve(data, header.mapLayoutPtr)
  dbg("layout resolved " .. layout.width .. "x" .. layout.height)
  local blockData = MapBlockData.resolve(data, layout.mapPtr, layout.width, layout.height)
  dbg("blockData resolved")
  walkMapBlockData, walkMapWidth, walkMapHeight = blockData, layout.width, layout.height
  local events = MapEvents.resolve(data, header.eventsPtr)
  walkMapWarps = events.warps
  world.walkMapConnections = (header.connectionsPtr ~= 0) and require("import.MapConnections").resolve(data, header.connectionsPtr) or {}
  walkMapId = mapId
  walkMapPrimaryAttrsPtr = Tileset.resolve(data, layout.primaryTilesetPtr).metatileAttributesPtr
  walkMapSecondaryAttrsPtr = Tileset.resolve(data, layout.secondaryTilesetPtr).metatileAttributesPtr
  local border = MapBorder.resolve(data, layout.borderPtr, layout.borderWidth, layout.borderHeight)
  dbg("border resolved")
  local primary = MapCompositor.loadTilesetData(data, layout.primaryTilesetPtr)
  dbg("primary tileset loaded, tiles=" .. #primary.tiles)
  local secondary = MapCompositor.loadTilesetData(data, layout.secondaryTilesetPtr)
  dbg("secondary tileset loaded, tiles=" .. #secondary.tiles)
  local composited = MapCompositor.compositeWithBorder(data, primary, secondary, blockData, layout.width, layout.height, border, layout.borderWidth, layout.borderHeight, BORDER_MARGIN_METATILES)
  dbg("composited " .. composited.width .. "x" .. composited.height)

  loadMapObjectEvents(data, events, mapId)

  addLine(("Composited map %d,%d: %dx%d metatiles, %dx%d px"):format(math.floor(mapId / 256), mapId % 256, layout.width, layout.height, composited.width, composited.height))
  mapImage = buildImage(composited)
  dbg("image built")
  mapImage:setFilter("nearest", "nearest")
  dbg("filter set")
end

-- Real warp transition: called once when the player's completed step
-- lands on a tile matching one of the current map's real warp events
-- (MapEvents.lua, Phase 1 data -- x/y are already in the same map-local
-- tile coordinate system WalkMapBlockData uses). Loads the destination
-- map and repositions the player at the destination map's own warp
-- entry `warpId` (its real x/y -- e.g. just inside a building's door).
-- A destination warpId outside the destination map's real warp count
-- (the real WARP_ID_NONE convention, or just a decode surprise) falls
-- back to that map's first walkable tile rather than crashing.
function tryWarpAt(x, y)
  if not walkMapWarps then return false end
  for _, warp in pairs(walkMapWarps) do
    if warp.x == x and warp.y == y then
      local destMapId = warp.mapGroup * 256 + warp.mapNum
      loadMap(romData, romAddrs, destMapId, function() end)
      local destWarp = walkMapWarps[warp.warpId]
      local destX, destY
      if destWarp then
        destX, destY = destWarp.x, destWarp.y
      else
        destX, destY = findFirstWalkableTile()
      end
      if destX and playerMovement then
        playerMovement.tileX, playerMovement.tileY = destX, destY
        playerMovement.moving = false
        playerMovement.stepFrame = 0
        syncSessionLocation()
      end
      return true
    end
  end
  return false
end

-- Real edge-of-map connection crossing (src/fieldmap.c's
-- SetPositionFromConnection, adapted from that function's pixel/camera
-- coordinate space into this project's direct tile-local coordinates).
-- Unlike a door/cave warp, real FireRed scrolls the camera seamlessly
-- across two simultaneously-rendered adjacent maps rather than cutting to
-- a freshly loaded one -- this project doesn't have dual-map rendering,
-- so this is a documented simplification: a discrete map-swap the instant
-- the completed step lands past the edge, at the exact real destination
-- tile SetPositionFromConnection itself computes. Per real source, the
-- perpendicular axis carries `connection.offset`; the axis along the
-- crossed edge places the player at the corresponding far edge of the new
-- map (e.g. crossing north lands on the new map's own southmost row).
world.tryConnectionAt = function(x, y)
  local conn = world.connectionForEdge(x, y)
  if not conn then return false end
  local MapConnections = require("import.MapConnections")
  local destMapId = conn.mapGroup * 256 + conn.mapNum
  loadMap(romData, romAddrs, destMapId, function() end)
  local destX, destY
  if conn.direction == MapConnections.CONNECTION_NORTH then
    destX, destY = x - conn.offset, walkMapHeight - 1
  elseif conn.direction == MapConnections.CONNECTION_SOUTH then
    destX, destY = x - conn.offset, 0
  elseif conn.direction == MapConnections.CONNECTION_WEST then
    destX, destY = walkMapWidth - 1, y - conn.offset
  else -- CONNECTION_EAST
    destX, destY = 0, y - conn.offset
  end
  if destX < 0 or destX >= walkMapWidth or destY < 0 or destY >= walkMapHeight then
    destX, destY = findFirstWalkableTile()
  end
  if destX and playerMovement then
    playerMovement.tileX, playerMovement.tileY = destX, destY
    playerMovement.moving = false
    playerMovement.stepFrame = 0
    syncSessionLocation()
  end
  return true
end

-- Persists only the field location that is currently represented by this
-- bounded runtime.  This is intentionally called after every completed
-- player step and after a real warp; actual save-file writing remains a
-- separate UI/IO concern, but a future call to SaveFileCodec.encode can use
-- `newGame.session.state` without reconstructing where the player is.
syncSessionLocation = function()
  if newGame.session and playerMovement and walkMapId then
    newGame.session:setLocation(walkMapId, playerMovement.tileX, playerMovement.tileY,
      playerMovement.facingDirection == PlayerMovement.UP and "north"
        or playerMovement.facingDirection == PlayerMovement.DOWN and "south"
        or playerMovement.facingDirection == PlayerMovement.LEFT and "west" or "east")
  end
end

-- The real naming screen seeds Random and retains a timer-derived trainer-id
-- lower half before the rest of Oak's flow reaches NewGameInitData().  This
-- desktop slice exposes deterministic injection knobs instead of pretending
-- that wall-clock time is the GBA timer: POKEPORT_TRAINER_RNG_SEED and
-- POKEPORT_TRAINER_ID_LOWER.  The pure GameSession builder still performs
-- InitPlayerTrainerId's exact high/low composition.
bootstrapFreshSession = function()
  if newGame.session or not newGame.flow or not newGame.flow:isComplete() then return end
  local rng = Rng.new(tonumber(os.getenv("POKEPORT_TRAINER_RNG_SEED") or "") or 0)
  local lower = tonumber(os.getenv("POKEPORT_TRAINER_ID_LOWER") or "") or 0
  newGame.session = GameSession.fromNewGame(newGame.flow:result(), {
    nextRandom16=function() return rng:next16() end,
    generatedTrainerIdLower=lower,
  })
  newGame.story = Battle.EarlyStory.new(newGame.session)

  -- WarpToPlayersRoom() in src/new_game.c: Map group 4, map 1, (6,6),
  -- WARP_ID_NONE.  The player begins facing north in this presentation's
  -- field state; no starter or story script is fabricated here.
  loadMap(romData, romAddrs, GameSession.MAP_PALLET_TOWN_PLAYERS_HOUSE_2F, function() end)
  if not playerMovement then
    addLine("Fresh save could not start: player movement assets are unavailable.")
    return
  end
  local start = NewGameDefaults.startingWarp
  playerMovement.tileX, playerMovement.tileY = start.x, start.y
  playerMovement.facingDirection = PlayerMovement.UP
  playerMovement.moving, playerMovement.stepFrame = false, 0
  syncSessionLocation()
  newGame.active = false
  walkActive = true
  addLine("Fresh save initialized: Player's House 2F (4,1) at 6,6; party is empty and PC has 1 Potion.")
end

-- Real save-file name is a fixed slot inside the cartridge's own flash,
-- not something the player names; this project's equivalent is one fixed
-- file inside LÖVE's sandboxed save directory (see conf.lua's t.identity).
local SAVE_FILENAME = "firered_recomp.sav"

-- Writes newGame.session.state through SaveFileCodec.encode(), passing
-- world.saveCounter/saveBytes as previousCounter/previousBytes so a
-- repeat save alternates the codec's two physical slots exactly like the
-- real dual-slot save does, instead of always rewriting slot 0.
function saveGame()
  if not newGame.session then
    addLine("Nothing to save: no active session.")
    return
  end
  local bytes, counter = SaveFileCodec.encode(newGame.session.state, world.saveCounter, world.saveBytes)
  local ok, err = love.filesystem.write(SAVE_FILENAME, bytes)
  if not ok then
    addLine("Save failed: " .. tostring(err))
    return
  end
  world.saveCounter, world.saveBytes = counter, bytes
  addLine(("Saved (slot generation %d)."):format(counter))
end

-- Reads SAVE_FILENAME back, validates+selects a slot via
-- SaveFileCodec.decode (real corruption-fallback rules), and replaces the
-- live session with GameSession.fromSavedState()'s reconstruction --
-- loading the decoded map and repositioning the player exactly the way
-- bootstrapFreshSession positions a brand new one.
function loadGameFile()
  if not love.filesystem.getInfo(SAVE_FILENAME) then
    addLine("Load failed: no save file exists yet.")
    return
  end
  local contents = love.filesystem.read(SAVE_FILENAME)
  if not contents then
    addLine("Load failed: could not read the save file.")
    return
  end
  local state, info = SaveFileCodec.decode(contents)
  if not state then
    addLine("Load failed: " .. tostring(info and info.status or "unreadable save data"))
    return
  end

  newGame.session = GameSession.fromSavedState(state)
  newGame.story = Battle.EarlyStory.new(newGame.session)
  world.saveCounter, world.saveBytes = info.saveCounter, contents

  loadMap(romData, romAddrs, newGame.session.mapId, function() end)
  if playerMovement then
    playerMovement.tileX, playerMovement.tileY = newGame.session.location.x, newGame.session.location.y
    playerMovement.facingDirection = PlayerMovement.DOWN
    playerMovement.moving, playerMovement.stepFrame = false, 0
  end
  world.clearViews()
  walkActive = true
  addLine(("Loaded save (slot generation %d): map %d,%d at %d,%d."):format(
    info.saveCounter, newGame.session.location.mapGroup, newGame.session.location.mapNum,
    newGame.session.location.x, newGame.session.location.y))
end

-- Executes the persistent gameplay result of the two supported early-story
-- coordinate events. The many applymovement/delay/music/text commands in
-- Oak's escort are not represented as if they had played: the status line
-- explicitly identifies that presentation as abbreviated. Map choice,
-- trigger coordinates, destination, final coordinate, flags and scene vars
-- are the real source values (EarlyStory.lua).
tryEarlyStoryTriggerAt = function(x, y)
  if not newGame.story then return false end
  local action = newGame.story:onStep(walkMapId, x, y, world.coordEvents)
  if not action then return false end

  if action.kind == "oakEscort" then
    loadMap(romData, romAddrs, action.mapId, function() end)
    playerMovement.tileX, playerMovement.tileY = action.x, action.y
    playerMovement.facingDirection = PlayerMovement.UP
    playerMovement.moving, playerMovement.stepFrame = false, 0
    syncSessionLocation()
    addLine("Oak escorted you to his lab. Movement/dialogue timing is abbreviated; real scene state is now 2. Choose one of the three balls with A.")
  elseif action.kind == "stayForStarter" then
    playerMovement.tileX, playerMovement.tileY = action.x, action.y
    playerMovement.facingDirection = PlayerMovement.UP
    playerMovement.moving, playerMovement.stepFrame = false, 0
    syncSessionLocation()
    addLine("Oak stops you: choose a Pokemon before leaving the lab.")
  elseif action.kind == "rivalBattle" then
    playerMovement.tileX, playerMovement.tileY = action.x, action.y
    playerMovement.facingDirection = PlayerMovement.UP
    playerMovement.moving, playerMovement.stepFrame = false, 0
    syncSessionLocation()
    if not world.startRivalBattle(action) then
      addLine("The mandatory rival encounter remains at lab scene 3 and can be retried; no progression flag was set.")
    end
  end
  return true
end

acceptStarterChoice = function()
  local prompt, catalog = world.starterChoice, world.battleCatalog
  if not prompt or not newGame.story or not catalog then return false end
  ensureRngStreams()
  local choice = prompt.choice
  local sb2 = newGame.session.state.saveBlock2
  local ok, record = pcall(Battle.StarterFactory.generate, {
    species=choice.species, speciesInfo=catalog.species[choice.species],
    speciesName=romData:sub(romAddrs.gSpeciesNames + choice.species * 11 + 1,
      romAddrs.gSpeciesNames + choice.species * 11 + 10),
    learnset=Battle.Learnset.resolve(romData, romAddrs.gLevelUpLearnsets, choice.species),
    battleMoves=catalog.moves, natures=catalog.natures, rng=world.globalRng,
    trainer={ id=sb2.playerTrainerId, name=sb2.playerName:sub(1, 7), gender=sb2.playerGender },
    metLocation=world.regionMapSectionId,
  })
  if not ok then
    addLine("Starter creation failed without changing story state: " .. tostring(record))
    newGame.story:declineStarter()
    world.starterChoice = nil
    return false
  end
  local nationalDexNo = Battle.PokedexOrder.speciesToNationalDexNum(
    romData, romAddrs.sSpeciesToNationalPokedexNum, choice.species)
  local accepted = newGame.story:acceptStarter(record, nationalDexNo)
  local kept = {}
  for _, npc in ipairs(world.npcs) do
    if not newGame.story:isObjectRemoved(walkMapId, npc.localId) then kept[#kept + 1] = npc end
  end
  world.npcs = kept
  world.starterChoice = nil
  addLine(("Received %s Lv 5 from Oak; rival took %s. Party/save/Dex state is persistent.")
    :format(speciesName(accepted.species), speciesName(accepted.rivalSpecies)))
  addLine("Nickname prompt and rival-pick movement are presentation-deferred; the starter keeps its species name. The mandatory rival tutorial starts at the south trigger.")
  return true
end

-- ---------------------------------------------------------- NPCs + scripts

-- Real `faceplayer` turns the object toward the player, i.e. the reverse of
-- whichever way the player is facing (GetOppositeDirection, src/
-- event_object_movement.c).
local OPPOSITE_DIRECTION = {
  [PlayerMovement.DOWN] = PlayerMovement.UP,
  [PlayerMovement.UP] = PlayerMovement.DOWN,
  [PlayerMovement.LEFT] = PlayerMovement.RIGHT,
  [PlayerMovement.RIGHT] = PlayerMovement.LEFT,
}

-- Decoded standing sprite for an NPC's current facing, cached by
-- graphicsId+facing (the real standing frame differs per direction, and
-- "right" is the "left" frame drawn hFlipped -- see
-- ObjectEventGraphicsInfo.FACE_FRAME). Returns (image, hFlip), or nil if
-- this graphicsId can't be decoded (real VAR-based dynamic ids and the one
-- >64px multi-OAM graphic both error loudly in the decoder; cached as a
-- negative result so a failing NPC doesn't retry every single frame).
local function npcSprite(npc)
  local key = npc.graphicsId .. "/" .. npc.facingDirection
  local cached = world.npcImages[key]
  if cached ~= nil then
    if cached == false then return nil end
    return cached.image, cached.hFlip
  end

  local ok, image, hFlip = pcall(function()
    local info = ObjectEventGraphicsInfo.decode(romData, romAddrs.gObjectEventGraphicsInfoPointers, npc.graphicsId)
    local palettePtr = ObjectEventGraphicsInfo.resolvePaletteTag(romData, romAddrs.sObjectEventSpritePalettes, info.paletteTag)
    return ObjectEventGraphicsInfo.decodeStandingImage(romData, info, palettePtr, npc.facingDirection)
  end)
  if not ok then
    world.npcImages[key] = false
    addLine(("NPC graphicsId %d not drawable: %s"):format(npc.graphicsId, tostring(image)))
    return nil
  end

  local built = buildImage(image)
  built:setFilter("nearest", "nearest")
  world.npcImages[key] = { image = built, hFlip = hFlip }
  return built, hFlip
end

-- Real text at a ROM pointer -> Charmap tokens, for DialogueRunner. 300
-- bytes is the same generous read-then-stop-at-terminator window
-- loadOakSpeechAssets already uses (Charmap.tokenize stops at 0xFF).
local function tokenizeTextAt(textPtr)
  local offset = textPtr - ScriptBytecode.romBase
  return Charmap.tokenize(romData:sub(offset + 1, offset + 300))
end

-- Starts a real decoded script (an NPC's scriptPtr or a bg event's sign
-- script) running through DialogueRunner. facingNpc, when given, is the
-- ObjectEventState the real `faceplayer` opcode should turn toward the
-- player.
local function startScript(scriptPtr, facingNpc)
  if scriptPtr == 0 then
    addLine("That object has no real script (scriptPtr 0).")
    return
  end
  local ok, instructions, addrToIndex = pcall(ScriptBytecode.decode, romData, scriptPtr)
  if not ok then
    addLine(("Script 0x%08X failed to decode: %s"):format(scriptPtr, tostring(instructions)))
    return
  end
  world.dialogue = DialogueRunner.new(instructions, addrToIndex, {
    tokenize = tokenizeTextAt,
    ticksPerChar = FONT_REVEAL_TICKS_PER_CHAR,
    onFacePlayer = function()
      if facingNpc then
        facingNpc.facingDirection = OPPOSITE_DIRECTION[playerMovement.facingDirection] or facingNpc.facingDirection
      end
    end,
    onRemoveObject = function(localId) world.removeNpcLive(localId) end,
    onRemoveObjectAt = function(localId, mapGroup, mapNum)
      -- Real ScrCmd_removeobjectat can target ANY map, not just the
      -- current one -- this project has no live NPC state for a map
      -- that isn't currently loaded, so only the current-map case removes
      -- a live sprite; a cross-map target is flagged rather than silently
      -- dropped (that map's own real FLAG_HIDE_* would need setting too,
      -- which requires knowing its template's flagId -- not resolvable
      -- without loading that map's events, out of scope here).
      if mapGroup * 256 + mapNum == walkMapId then
        world.removeNpcLive(localId)
      else
        addLine(("removeobjectat targeted a different map (%d,%d) -- not live-removed (out of scope)."):format(mapGroup, mapNum))
      end
    end,
  })
  world.dialogueBuiltTokenIndex = -1
end

-- Real A-button interaction (field_control_avatar.c's
-- GetInFrontOfPlayer -> TryStartInteraction shape): the tile one step in
-- the player's facing direction. An object event there wins; otherwise a
-- real bg event (Town Signs and friends, kind 0 = script sign) on that
-- same tile is read. Ignored mid-step and while a message box is already
-- up, matching the real ObjectEventIsMovementOverridden/script-context
-- input gating.
local function tryStartInteraction()
  if world.battle then return end
  if not playerMovement or playerMovement.moving then return end
  if world.dialogue and world.dialogue:isActive() then return end

  local npc = ObjectEventInteraction.findInteractionTarget(
    playerMovement.tileX, playerMovement.tileY, playerMovement.facingDirection, world.npcs)
  if npc then
    if newGame.story and walkMapId == Battle.EarlyStory.MAP_OAKS_LAB
        and Battle.EarlyStory.STARTERS[npc.localId] then
      local action = newGame.story:beginStarterChoice(walkMapId, npc.localId)
      if action.kind == "confirmStarter" then
        world.starterChoice = {
          choice=action.choice,
          cursor=MenuCursor.new(2, 0),
        }
        addLine(("Choose %s as your starter? Use Up/Down, A to confirm, B to decline.")
          :format(speciesName(action.choice.species)))
      else
        addLine("Starter unavailable: " .. action.reason)
      end
      return
    end
    startScript(npc.scriptPtr, npc)
    return
  end

  local delta = ObjectEventState.DIRECTION_DELTA[playerMovement.facingDirection]
  if not delta then return end
  local tx, ty = playerMovement.tileX + delta.dx, playerMovement.tileY + delta.dy
  local i = 0
  while world.bgEvents[i] ~= nil do
    local bg = world.bgEvents[i]
    -- kind 0 is the real BG_EVENT_PLAYER_FACING_ANY script sign; the other
    -- real kinds (hidden items, secret base) reuse the union field for
    -- non-script data and are out of scope for this pass.
    if bg.x == tx and bg.y == ty and bg.kind == 0 then
      startScript(bg.union, nil)
      return
    end
    i = i + 1
  end
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
  loadMap(data, addrs, mapId, dbg)

  addLine("Press N for the post-Oak new-game flow (or Enter from S), V data, T title, P sprite, I item, F font, O/S Oak, A flame, Y Yes/No, W walk.")

  loadTitleScreenAssets(data, addrs, dbg)
  loadSpriteAssets(data, addrs, dbg)
  loadFontAssets(data, addrs, dbg)
  loadOakSpeechAssets(data, addrs, dbg)
  loadOakSceneAssets(data, addrs, dbg)
  loadYesNoAssets(data, addrs, dbg)
  loadNewGameAssets(data, addrs, dbg)
  loadFlameAssets(data, addrs, dbg)
  loadBattleSceneAssets(data, addrs, dbg)
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

-- Overworld dialogue box for the W view. The frame is built once (26x4
-- content tiles -> 28x6 with the border = 224x48px, a close stand-in for
-- the real overworld message window's footprint at the bottom of the
-- 240x160 screen); the text image is rebuilt only when the reveal has
-- actually advanced, exactly like ensureFontImageCurrent.
local DIALOGUE_CONTENT_TILES_W, DIALOGUE_CONTENT_TILES_H = 26, 4
local function ensureDialogueImagesCurrent()
  if not fontData or not fontPalette then return end
  if not world.dialogueWindowImage then
    local ok, composited = pcall(function()
      local tiles = TextWindow.decodeFrameTiles(fontData, fontAddrs.gStdTextWindow_Gfx)
      local palette = TextWindow.decodePalette(fontData, fontAddrs.gTextWindowPalettes, TextWindow.STD_PALETTE_INDEX)
      return TextWindow.compositeFrame(tiles, palette, DIALOGUE_CONTENT_TILES_W, DIALOGUE_CONTENT_TILES_H)
    end)
    if not ok then return end
    world.dialogueWindowImage = buildImage(composited)
    world.dialogueWindowImage:setFilter("nearest", "nearest")
    -- Real DrawDialogueFrame follows the frame tiles with a
    -- FillWindowPixelBuffer flood of the interior, and the real overworld
    -- message printer then uses TEXT_COLOR_WHITE as its background with
    -- TEXT_COLOR_DARK_GRAY text and TEXT_COLOR_LIGHT_GRAY shadow (the same
    -- real trio OakSpeechScene.lua's textbox already reproduces).
    -- TextWindow.compositeFrame deliberately leaves the interior
    -- transparent (it's the caller's job), so over a map the box would
    -- otherwise show the field through it -- this paints the real white
    -- background behind it. Palette indices follow TextRenderer's
    -- TEXT_COLOR_* slot convention (palette[1] = TEXT_COLOR_WHITE).
    local fill = fontPalette[1]
    world.dialogueFillColor = { fill.r / 255, fill.g / 255, fill.b / 255 }
  end

  local runner = world.dialogue
  local tokenIndex = (runner and runner.printer) and runner.printer.tokenIndex or -1
  if tokenIndex == world.dialogueBuiltTokenIndex then return end
  world.dialogueBuiltTokenIndex = tokenIndex
  if tokenIndex <= 0 then
    world.dialogueTextImage = nil
    return
  end
  -- Real AddTextPrinterParameterized2(..., TEXT_COLOR_DARK_GRAY,
  -- TEXT_COLOR_WHITE, TEXT_COLOR_LIGHT_GRAY) for an overworld message --
  -- injected as the same kind of color token a real EXT_CTRL_CODE_COLOR
  -- byte would produce, since TextRenderer's own default is the
  -- white-on-transparent pair the F view wants instead.
  local tokens = { { type = "color", fg = 2, shadow = 3 } }
  for _, token in ipairs(runner:revealedTokens()) do tokens[#tokens + 1] = token end
  local ok, composited = pcall(TextRenderer.renderTokens, fontData, fontAddrs, tokens, fontPalette)
  if ok then
    world.dialogueTextImage = buildImage(composited)
    world.dialogueTextImage:setFilter("nearest", "nearest")
  end
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

-- Plain text-line rendering, same pattern as viewerLines() -- real ROM-
-- backed window/menu art (the NamingScreenScene.lua treatment) is a
-- separate, later piece; this proves the real data/logic pipeline works
-- end to end without waiting on that.
world.martLines = function()
  local function martItemName(itemId)
    local entry = world.battleCatalog and world.battleCatalog.items and world.battleCatalog.items[itemId]
    if not entry then return "ITEM " .. tostring(itemId) end
    local ok, name = pcall(Charmap.decode, entry.rawName, true)
    return ok and name or ("ITEM " .. tostring(itemId))
  end
  local m = world.martMenu
  local lines = { ("POKE MART -- Money: $%d  (M: leave)"):format(m.money) }
  local function unitLinePrice(itemId)
    local price = world.battleCatalog.items[itemId].price
    return m.transactionType == "sell" and math.floor(price / 2) or price
  end
  if m.state == Battle.MartMenu.TOPMENU then
    lines[#lines + 1] = "Up/Down: choose, A: select, B: leave"
    local options = { "BUY", "SELL", "QUIT" }
    for i, label in ipairs(options) do
      local cursor = (i - 1 == m.topCursor) and "> " or "  "
      lines[#lines + 1] = cursor .. label
    end
  elseif m.state == Battle.MartMenu.LIST then
    local verb = m.transactionType == "sell" and "sell" or "buy"
    lines[#lines + 1] = ("Up/Down: choose, A: %s, B: back"):format(verb)
    if #m.itemIds == 0 then
      lines[#lines + 1] = "(nothing to sell)"
    end
    for i, itemId in ipairs(m.itemIds) do
      local cursor = (i - 1 == m.listCursor) and "> " or "  "
      lines[#lines + 1] = ("%s%s  $%d"):format(cursor, martItemName(itemId), unitLinePrice(itemId))
    end
  elseif m.state == Battle.MartMenu.QUANTITY then
    lines[#lines + 1] = ("%s  In bag: %d"):format(martItemName(m.selectedItemId), m.bag:quantityOf(m.selectedItemId))
    lines[#lines + 1] = ("x%02d   $%d  (Up/Down +-1, Left/Right +-10)"):format(
      m.quantity, unitLinePrice(m.selectedItemId) * m.quantity)
    lines[#lines + 1] = "A: confirm, B: back"
  elseif m.state == Battle.MartMenu.CONFIRM then
    local verb = m.transactionType == "sell" and "Sell it?" or "Buy it?"
    lines[#lines + 1] = ("%s x%d -- $%d. %s  (A: yes, B: no)"):format(
      martItemName(m.selectedItemId), m.quantity,
      unitLinePrice(m.selectedItemId) * m.quantity, verb)
  elseif m.state == Battle.MartMenu.MESSAGE then
    lines[#lines + 1] = m.message
    lines[#lines + 1] = "(A or B to continue)"
  end
  return lines
end

local START_MENU_LABELS = {
  [Battle.StartMenu.POKEDEX] = "POKEDEX", [Battle.StartMenu.POKEMON] = "POKEMON",
  [Battle.StartMenu.BAG] = "BAG", [Battle.StartMenu.PLAYER] = "PLAYER",
  [Battle.StartMenu.SAVE] = "SAVE", [Battle.StartMenu.OPTION] = "OPTION",
  [Battle.StartMenu.EXIT] = "EXIT",
}

world.startMenuLines = function()
  local m = world.startMenu
  local lines = { "START MENU  (Up/Down, A: select, B/Start: close)" }
  for i, itemId in ipairs(m.items) do
    local cursor = (i - 1 == m.cursor.cursorPos) and "> " or "  "
    lines[#lines + 1] = cursor .. (START_MENU_LABELS[itemId] or tostring(itemId))
  end
  return lines
end

world.partyScreenLines = function()
  local p = world.partyScreen
  local lines = { "PARTY  (Up/Down, A: select, B: back)" }
  for row, isCancel, data in p:iterateRows() do
    local cursor = (row == p:cursorRow()) and "> " or "  "
    if isCancel then
      lines[#lines + 1] = cursor .. "CANCEL"
    else
      lines[#lines + 1] = ("%s%s Lv%d  HP %d/%d"):format(cursor, data.nickname, data.level, data.hp, data.maxHp)
    end
  end
  return lines
end

world.bagScreenLines = function()
  local b = world.bagScreen
  local pocketNames = {
    [Battle.Bag.POCKET_ITEMS] = "ITEMS", [Battle.Bag.POCKET_KEY_ITEMS] = "KEY ITEMS", [Battle.Bag.POCKET_POKE_BALLS] = "POKE BALLS",
  }
  local function itemName(itemId)
    local entry = world.battleCatalog and world.battleCatalog.items and world.battleCatalog.items[itemId]
    if not entry then return "ITEM " .. tostring(itemId) end
    local ok, name = pcall(Charmap.decode, entry.rawName, true)
    return ok and name or ("ITEM " .. tostring(itemId))
  end
  if b.state == Battle.BagScreen.CONTEXT_MENU then
    local lines = { ("%s  (Up/Down, A: select, B: back)"):format(itemName(b.selectedItemId)) }
    for i, action in ipairs(b:contextActions()) do
      local cursor = (i - 1 == b.contextCursor.cursorPos) and "> " or "  "
      lines[#lines + 1] = cursor .. action
    end
    return lines
  elseif b.state == Battle.BagScreen.TOSS_QUANTITY then
    return {
      ("Toss %s  In bag: %d"):format(itemName(b.selectedItemId), b.tossMaxQuantity),
      ("x%02d  (Up/Down +-1, Left/Right +-10)"):format(b.tossQuantity),
      "A: confirm, B: back",
    }
  elseif b.state == Battle.BagScreen.TOSS_CONFIRM then
    return { ("Throw away %s x%d?  (A: yes, B: no)"):format(itemName(b.selectedItemId), b.tossQuantity) }
  elseif b.state == Battle.BagScreen.MESSAGE then
    return { b.message, "(A or B to continue)" }
  end
  local lines = { ("BAG -- %s  (Left/Right: pocket, A: select, B: back)"):format(pocketNames[b:pocket()] or "?") }
  for row, isCancel, itemId, quantity in b:iterateRows() do
    local cursor = (row == b:cursorRow()) and "> " or "  "
    if isCancel then
      lines[#lines + 1] = cursor .. "CLOSE BAG"
    else
      lines[#lines + 1] = ("%s%s x%d"):format(cursor, itemName(itemId), quantity)
    end
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
  -- POKEPORT_WALK_TALK=1 additionally fires one real A-button interaction
  -- after the moves finish (the NPC/sign the player ends up facing), and
  -- POKEPORT_WALK_TALK_TICKS=N then ticks the dialogue runner N times so a
  -- screenshot catches a partially- or fully-revealed real message --
  -- automated capture can't press keys or wait on real elapsed time.
  if os.getenv("POKEPORT_WALK") == "1" then
    walkActive = true
    local moves = os.getenv("POKEPORT_WALK_MOVES")
    if moves and playerMovement then
      for dir in moves:gmatch("[^,]+") do
        playerMovement:tryMove(dir, world.isPlayerWalkTileBlocked, getLedgeJumpDirection)
        for i = 1, 16 do playerMovement:tick() end
        syncSessionLocation()
        if not tryEarlyStoryTriggerAt(playerMovement.tileX, playerMovement.tileY)
            and not tryWarpAt(playerMovement.tileX, playerMovement.tileY) then
          rollWildEncounterAt(playerMovement.tileX, playerMovement.tileY)
        end
        if world.battle then break end
      end
    end
    if os.getenv("POKEPORT_WALK_TALK") == "1" and not world.battle then
      tryStartInteraction()
      local talkTicks = tonumber(os.getenv("POKEPORT_WALK_TALK_TICKS") or "120")
      for _ = 1, talkTicks do
        if world.dialogue then world.dialogue:tick(false) end
      end
    end
  end

  -- POKEPORT_BATTLE=species,level boots the same live scene a grass step
  -- launches, without depending on a particular movement/RNG sequence.
  -- It still requires a real session lead. For isolated developer visuals
  -- with no session at all, POKEPORT_BATTLE_DEBUG_PARTY=species,level opts
  -- into a generated temporary battler that is never stored in GameSession.
  -- POKEPORT_BATTLE_ADVANCE=N acknowledges N intro/result messages first,
  -- useful for deterministic screenshots of the action menu.
  local battleOverride = os.getenv("POKEPORT_BATTLE")
  if battleOverride then
    local species, level = battleOverride:match("^(%d+),(%d+)$")
    if species and level then
      walkActive = true
      startWildBattle({ species=tonumber(species), level=tonumber(level), slot=0 })
      local advances = tonumber(os.getenv("POKEPORT_BATTLE_ADVANCE") or "0") or 0
      for _ = 1, advances do
        if world.battle then world.battle.controller:advanceMessage() end
      end
    end
  end

  -- POKEPORT_OAKSCENE=1 boots straight into the full Oak intro scene view.
  if os.getenv("POKEPORT_OAKSCENE") == "1" then
    oakSceneActive = true
  end

  -- POKEPORT_NEWGAME selects a deterministic point in the new identity
  -- flow for live screenshots: gender (or 1), player, rival, complete.
  -- Normal interactive play enters the same flow with N or Enter from S.
  local newGameOverride = os.getenv("POKEPORT_NEWGAME")
  if newGameOverride and newGame.flow then
    beginNewGameFlow()
    if newGameOverride == "player" then
      newGame.flow:beginPlayerNaming(NewGameFlow.MALE)
    elseif newGameOverride == "rival" then
      newGame.flow:beginPlayerNaming(NewGameFlow.MALE)
      newGame.flow:beginRivalChoice(NewGameFlow.encodeName("RED"))
    elseif newGameOverride == "complete" then
      newGame.flow.playerGender = NewGameFlow.MALE
      newGame.flow.playerName = NewGameFlow.encodeName("RED")
      newGame.flow.rivalName = NewGameFlow.encodeName("GREEN")
      newGame.flow.state = NewGameFlow.COMPLETE
      newGame.flow:_touch()
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

  -- Deliberately tiny runtime smoke replays. Unlike POKEPORT_WALK_MOVES,
  -- these reach movement and battle menus through the same love.update
  -- keyboard-input path used in normal play. They are opt-in, terminate
  -- after emitting one machine-readable result, and are not a scripting API.
  local runtimeReplay = os.getenv("POKEPORT_RUNTIME_REPLAY")
  local replayRoute1 = runtimeReplay == "route1_wild_defeat"
    or runtimeReplay == "route1_wild_defeat_save"
    or runtimeReplay == "route1_wild_win"
  if runtimeReplay == "restart_load" then
    -- This is intentionally a separate process from the save replay.  L is
    -- the normal hotkey callback, and the outer script supplies a fresh,
    -- isolated XDG/LÖVE sandbox containing only the prior process's save.
    love.keypressed("l")
    local session = newGame.session
    local loaded = session and session.mapId == GameSession.MAP_PALLET_TOWN_PLAYERS_HOUSE_2F
      and session.location.x == 6 and session.location.y == 6
      and session.state.saveBlock1.playerPartyCount == 1
    print(("RUNTIME_REPLAY restart_load %s map=%s pos=%s,%s party=%s identity=%s/%s/%s"):format(
      loaded and "PASS" or "FAIL", tostring(session and session.mapId),
      tostring(session and session.location.x), tostring(session and session.location.y),
      tostring(session and session.state.saveBlock1.playerPartyCount),
      tostring(session and Charmap.decode(session.identity.playerName)),
      tostring(session and Charmap.decode(session.identity.rivalName)),
      tostring(session and session.identity.playerGender)))
    if loaded then love.event.quit() else love.event.quit(1) end
  elseif runtimeReplay == "house_to_pallet" or replayRoute1 then
    beginNewGameFlow()

    local function tick(mask, count)
      world.replayInputMask = mask
      for _ = 1, count do love.update(1 / 60) end
    end
    local function move(button)
      -- One press starts a single grid step; release ticks let its task
      -- finish without beginning a second step.
      tick(button, 1)
      tick(0, 16)
    end
    local function press(button)
      tick(button, 1)
      tick(0, 1)
    end
    local function loseBattle()
      local outcome
      -- Advance real battle text/menu input. Selecting the second move
      -- (Growl) every turn intentionally avoids a fabricated quick win;
      -- the retail foe's normal attacks then produce the real loss path.
      for _ = 1, 240 do
        local battle = world.battle
        if not battle then break end
        if battle.controller.state == Battle.Controller.MESSAGES then
          press(InputState.A_BUTTON)
        elseif battle.controller.state == Battle.Controller.ACTION then
          press(InputState.A_BUTTON)
        elseif battle.controller.state == Battle.Controller.MOVE then
          press(InputState.DPAD_RIGHT)
          press(InputState.A_BUTTON)
        else
          tick(0, 1)
        end
        if battle.controller.engine.outcome then outcome = battle.controller.engine.outcome end
      end
      return outcome
    end
    local function winBattle()
      local outcome
      -- The first real move slot is selected through the normal FIGHT
      -- menu. No foe HP, engine outcome, or RNG state is injected here.
      for _ = 1, 240 do
        local battle = world.battle
        if not battle then break end
        if battle.controller.state == Battle.Controller.MESSAGES
            or battle.controller.state == Battle.Controller.ACTION
            or battle.controller.state == Battle.Controller.MOVE then
          press(InputState.A_BUTTON)
        else
          tick(0, 1)
        end
        if battle.controller.engine.outcome then outcome = battle.controller.engine.outcome end
      end
      return outcome
    end

    -- Exercise the real post-Oak keyboard state machine: accept its
    -- default BOY cursor, accept the deterministic generated player-name
    -- fallback, select the visible GREEN rival preset, then confirm both.
    -- This intentionally does not claim to automate Oak's preceding scene.
    press(InputState.A_BUTTON) -- gender -> player naming
    press(InputState.START_BUTTON) -- naming cursor -> OK
    press(InputState.A_BUTTON) -- accept player fallback -> confirm
    press(InputState.A_BUTTON) -- player YES -> rival menu
    press(InputState.DPAD_DOWN) -- NEW NAME -> GREEN preset
    press(InputState.A_BUTTON) -- GREEN -> rival confirm
    press(InputState.A_BUTTON) -- rival YES -> complete
    world.runtimeReplayIdentity = newGame.flow:result()
    tick(0, 1) -- completed identity flow bootstraps the fresh session
    local started = newGame.session and walkMapId == GameSession.MAP_PALLET_TOWN_PLAYERS_HOUSE_2F
      and playerMovement and playerMovement.tileX == 6 and playerMovement.tileY == 6
    if started then
      for _ = 1, 4 do move(InputState.DPAD_RIGHT) end
      for _ = 1, 4 do move(InputState.DPAD_UP) end
      -- The stair lands on Player's House 1F at (10,2); its south-west
      -- door warp at (5,8) is the next real map transition into Pallet.
      for _ = 1, 5 do move(InputState.DPAD_LEFT) end
      for _ = 1, 6 do move(InputState.DPAD_DOWN) end
      if replayRoute1 then
        -- The only north exit tiles are Oak's real (12,1)/(13,1) story
        -- gate, so traverse to it rather than bypassing field progression.
        move(InputState.DPAD_DOWN)
        for _ = 1, 4 do move(InputState.DPAD_RIGHT) end
        for _ = 1, 6 do move(InputState.DPAD_UP) end
        for _ = 1, 2 do move(InputState.DPAD_RIGHT) end
        move(InputState.DPAD_UP) -- Oak trigger: real runtime loads the lab

        -- At the source-derived lab landing (6,4), face Bulbasaur's ball
        -- at (8,4), accept it through the live interaction/menu code, then
        -- take the real y=8 rival gate and deliberately lose the tutorial.
        move(InputState.DPAD_RIGHT)
        press(InputState.A_BUTTON)
        press(InputState.A_BUTTON)
        for _ = 1, 4 do move(InputState.DPAD_DOWN) end
        local rivalOutcome = loseBattle()

        -- The common rival-loss script leaves scene 4 and the player at
        -- (7,8). Walk through the actual lab door, then Pallet's now-open
        -- north connection into Route 1.
        if rivalOutcome == "playerLost" then
          for _ = 1, 4 do move(InputState.DPAD_DOWN) end
          world.runtimeReplayAfterLab = { map=walkMapId, x=playerMovement.tileX, y=playerMovement.tileY }
          -- Lab warp 2 lands at Pallet (16,13). The source path to the
          -- north connection is south once, west four, then north to y=0.
          move(InputState.DPAD_DOWN)
          for _ = 1, 4 do move(InputState.DPAD_LEFT) end
          for _ = 1, 15 do move(InputState.DPAD_UP) end
        end

        -- Route 1's arrival tile is grass. With the existing deterministic
        -- POKEPORT_RNG_SEED=0 hook, these normal field steps start a retail
        -- wild encounter within two grass steps; keep retrying defensively
        -- before taking its real whiteout/loss path.
        local reachedRoute1 = walkMapId == 3 * 256 + 19
        if reachedRoute1 then
          for _ = 1, 24 do
            if world.battle then break end
            move(InputState.DPAD_UP)
            if world.battle then break end
            move(InputState.DPAD_DOWN)
          end
        end
        local wildOutcome = runtimeReplay == "route1_wild_win" and winBattle() or loseBattle()
        world.runtimeReplayResult = {
          reachedRoute1=reachedRoute1, rivalOutcome=rivalOutcome, wildOutcome=wildOutcome,
        }
      end
    end
    world.replayInputMask = nil
    local passed = started and (runtimeReplay == "house_to_pallet" and walkMapId == MAP_PALLET_TOWN)
      and newGame.session and newGame.session.mapId == MAP_PALLET_TOWN
    if replayRoute1 then
      local result = world.runtimeReplayResult or {}
      passed = started and result.reachedRoute1 and result.rivalOutcome == "playerLost"
        and result.wildOutcome == (runtimeReplay == "route1_wild_win" and "playerWon" or "playerLost")
    end
    if passed and runtimeReplay == "route1_wild_defeat_save" then
      -- K reaches saveGame only through the normal public hotkey callback.
      -- The save-restart shell gate owns the isolated filesystem boundary.
      love.keypressed("k")
      world.runtimeReplaySaved = love.filesystem.getInfo(SAVE_FILENAME) ~= nil
      passed = world.runtimeReplaySaved
    end
    local replayDetail = world.runtimeReplayResult
      and (" route1=" .. tostring(world.runtimeReplayResult.reachedRoute1)
        .. " rival=" .. tostring(world.runtimeReplayResult.rivalOutcome)
        .. " wild=" .. tostring(world.runtimeReplayResult.wildOutcome)) or ""
    if world.runtimeReplayAfterLab then
      replayDetail = replayDetail .. (" afterLab=" .. tostring(world.runtimeReplayAfterLab.map)
        .. "@" .. tostring(world.runtimeReplayAfterLab.x) .. "," .. tostring(world.runtimeReplayAfterLab.y))
    end
    if world.runtimeReplayIdentity then
      replayDetail = replayDetail .. (" identity="
        .. Charmap.decode(world.runtimeReplayIdentity.playerName) .. "/"
        .. Charmap.decode(world.runtimeReplayIdentity.rivalName)
        .. "/" .. tostring(world.runtimeReplayIdentity.playerGender))
    end
    if runtimeReplay == "route1_wild_defeat_save" then
      replayDetail = replayDetail .. " saved=" .. tostring(world.runtimeReplaySaved)
    end
    print(("RUNTIME_REPLAY %s %s map=%s pos=%s,%s%s"):format(runtimeReplay,
      passed and "PASS" or "FAIL", tostring(walkMapId),
      tostring(playerMovement and playerMovement.tileX), tostring(playerMovement and playerMovement.tileY), replayDetail))
    if passed then love.event.quit() else love.event.quit(1) end
  end

  -- love.filesystem is sandboxed to the save directory (see conf.lua's
  -- identity="firered-recomp"), so this always writes there under a fixed
  -- name rather than to an arbitrary POKEPORT_SCREENSHOT path.
  if os.getenv("POKEPORT_SCREENSHOT") == "1" and (mapImage or viewerActive or titleActive or spriteActive or itemBallActive or fontActive or oakSpeechActive or oakSceneActive or flameActive or yesNoActive or walkActive or newGame.active or world.battle) then
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
world.settleOakLabRivalBattle = function(battle)
  if battle.kind ~= "oakLabRival" or battle.settled
      or not battle.controller.engine.outcome then return end
  local outcome = battle.controller.engine.outcome
  local ok, result = pcall(function()
    local messages = {}
    if outcome == "playerWon" then
      local reward = Battle.RivalRewards.applyVictory(
        battle.partyRecord, battle.foeInstance, world.battleCatalog.species,
        world.battleCatalog.natures,
        Battle.Learnset.resolve(romData, romAddrs.gLevelUpLearnsets,
          battle.controller.engine.player.species),
        world.regionMapSectionId)
      Battle.RivalRewards.addPrizeMoney(newGame.session.state.saveBlock1)
      messages[#messages + 1] = ("%s gained %d EXP. Points!"):format(battle.playerName, reward.exp)
      if reward.newLevel > reward.oldLevel then
        messages[#messages + 1] = ("%s grew to Lv. %d!"):format(battle.playerName, reward.newLevel)
        local live = battle.controller.engine.player
        live.level, live.hp, live.maxHP = battle.partyRecord.level,
          battle.partyRecord.hp, battle.partyRecord.maxHP
        live.attack, live.defense, live.speed = battle.partyRecord.attack,
          battle.partyRecord.defense, battle.partyRecord.speed
        live.spAttack, live.spDefense = battle.partyRecord.spAttack, battle.partyRecord.spDefense
        messages[#messages + 1] = {hpSide="player", hp=battle.partyRecord.hp}
      end
      messages[#messages + 1] = "WHAT? Unbelievable!\nI picked the wrong POKEMON!"
      messages[#messages + 1] = "OAK: Hm! Excellent! If you win,\nyour POKEMON will grow!"
      messages[#messages + 1] = ("%s got $%d for winning!")
        :format(Charmap.decode(newGame.session.state.saveBlock2.playerName), Battle.RivalRewards.PRIZE_MONEY)
    elseif outcome == "playerLost" then
      Battle.RivalRewards.applyLoss(battle.partyRecord)
      messages[#messages + 1] = battle.rivalName .. ": Yeah! Am I great or what?"
      messages[#messages + 1] = "OAK: Hm... How disappointing..."
      messages[#messages + 1] = "Since you had no warning this time,\nI'll pay for you."
    else
      error("trainer battle ended with an impossible outcome: " .. tostring(outcome))
    end
    messages[#messages + 1] = battle.rivalName
      .. ": I'll make my POKEMON battle\nto toughen it up!"
    messages[#messages + 1] = "Smell you later!"
    return messages
  end)
  battle.settled = true
  if ok then
    battle.controller:appendMessages(result, Battle.Controller.COMPLETE)
  else
    battle.settlementError = tostring(result)
    battle.controller:appendMessages({
      "Rival-battle settlement failed source validation; story progress remains at scene 3.",
    }, Battle.Controller.COMPLETE)
    addLine("Rival-battle settlement failed: " .. tostring(result))
  end
end

world.finishOakLabRivalBattle = function(battle)
  if battle.settlementError then
    world.battle = nil
    return
  end
  local outcome = battle.controller.engine.outcome
  local ok, result = pcall(function()
    -- PalletTown_ProfessorOaksLab_EventScript_EndRivalBattle begins with
    -- HealPlayerParty and reaches this same progression on either outcome.
    Battle.RivalRewards.healParty(newGame.session.state.saveBlock1, world.battleCatalog.moves)
    return newGame.story:completeRivalBattle(outcome, battle.trainerId)
  end)
  if not ok then
    addLine("Rival-battle story continuation failed: " .. tostring(result))
    world.battle = nil
    return
  end
  local kept = {}
  for _, npc in ipairs(world.npcs) do
    if not newGame.story:isObjectRemoved(walkMapId, npc.localId) then kept[#kept + 1] = npc end
  end
  world.npcs = kept
  -- The rival-exit movement ends by turning the player south in place on
  -- the original scene-3 trigger tile.
  playerMovement.facingDirection = PlayerMovement.DOWN
  syncSessionLocation()
  addLine(("Oak-lab rival battle %s: party healed, scene 4/trainer/story flags persisted, rival departed%s.")
    :format(outcome == "playerWon" and "won" or "lost",
      outcome == "playerWon" and ", $80 awarded" or "; Oak covered the loss"))
  world.battle = nil
end

-- General live trainer battle completion (any trainer reached via
-- TrainerSightline, not the Oak-lab rival's own bespoke path). Real
-- battle_setup.c sets the trainer's own FightTrainerFlag
-- (TRAINER_FLAGS_START + trainerId, same real base EarlyStory.lua
-- already uses) only on a real win -- a loss or run leaves the trainer
-- rebattlable. A loss still applies the same real whiteout
-- (WhiteoutRules) an ordinary wild-battle loss does -- trainer-battle
-- losses are not special-cased for that in real FireRed either.
-- A win grants real EXP too, via the same EarlyRivalRewards.applyVictory
-- the Oak-lab rival already uses -- that function already defaults to
-- the real BATTLE_TYPE_TRAINER 150% bonus (Cmd_getexp), so no separate
-- trainer-specific formula is needed here; allowLevelUpMoveGap=true since
-- an arbitrary trainer's foe (unlike the rival's fixed lvl-5 fixture)
-- can legitimately cross a level-up-move threshold this project has no
-- move-learn UI for yet (same real gap applyWildVictory already
-- documents for ordinary wild wins).
world.finishTrainerBattle = function(battle)
  local outcome = battle.controller.engine.outcome
  if outcome == "playerWon" then
    if newGame.session then
      newGame.session:setFlag(Battle.EarlyStory.TRAINER_FLAGS_START + battle.trainerId)
    end
    if battle.partyRecord and battle.foeInstance then
      -- Real Cmd_getexp's BATTLE_TYPE_TRAINER 150% bonus -- EarlyRivalRewards.
      -- applyVictory already defaults to it (opts.expMultiplierPercent==150),
      -- this project's own wild-battle path is the one that opts OUT via
      -- applyWildVictory's 100% override, not the other way around.
      local ok, reward = pcall(Battle.RivalRewards.applyVictory,
        battle.partyRecord, battle.foeInstance, world.battleCatalog.species,
        world.battleCatalog.natures,
        Battle.Learnset.resolve(romData, romAddrs.gLevelUpLearnsets,
          battle.controller.engine.player.species),
        world.regionMapSectionId, { allowLevelUpMoveGap = true })
      if ok then
        local levelMsg = ""
        if reward.newLevel > reward.oldLevel then
          levelMsg = (" Grew to Lv. %d!"):format(reward.newLevel)
        end
        addLine(("Defeated %s! Gained %d EXP.%s"):format(battle.trainerName, reward.exp, levelMsg))
        if reward.skippedLevelUpMoves then
          addLine("(A level-up move was reached but not learned -- no move-learn UI yet.)")
        end
      else
        addLine(("Defeated %s, but reward application failed: %s"):format(battle.trainerName, tostring(reward)))
      end
    else
      addLine(("Defeated %s! (No session party to reward.)"):format(battle.trainerName))
    end
  elseif outcome == "playerLost" then
    local sb1 = newGame.session.state.saveBlock1
    local topLevel = Battle.WhiteoutRules.highestPartyLevel(sb1.playerParty, sb1.playerPartyCount)
    local badgeCount = Battle.WhiteoutRules.countBadges(function(id) return newGame.session:getFlag(id) end)
    local loss = Battle.WhiteoutRules.computeMoneyLoss(topLevel, badgeCount, sb1.money or 0)
    sb1.money = (sb1.money or 0) - loss
    Battle.RivalRewards.healParty(sb1, world.battleCatalog.moves)
    local start = NewGameDefaults.startingWarp
    local respawn = Battle.WhiteoutRules.respawnLocation(sb1.lastHealLocation,
      { mapGroup=4, mapNum=1, warpId=start.warpId, x=start.x, y=start.y })
    loadMap(romData, romAddrs, respawn.mapGroup * 256 + respawn.mapNum, function() end)
    if playerMovement then
      playerMovement.tileX, playerMovement.tileY = respawn.x, respawn.y
      playerMovement.facingDirection = PlayerMovement.DOWN
      playerMovement.moving, playerMovement.stepFrame = false, 0
    end
    syncSessionLocation()
    addLine(("Lost to %s. Whiteout: lost $%d, party healed, respawned at %d,%d (%d,%d)."):format(
      battle.trainerName, loss, respawn.mapGroup, respawn.mapNum, respawn.x, respawn.y))
  else
    -- Real trainer battles block running (runDisabledMessage) -- this
    -- branch should be unreachable, but fails safely rather than leaving
    -- world.battle stuck if some other outcome ever reaches here.
    addLine(("Trainer battle against %s ended (%s)."):format(battle.trainerName, tostring(outcome)))
  end
  world.battle = nil
end

function love.update(dt)
  tickAccumulator = tickAccumulator + dt
  while tickAccumulator >= FIXED_TICK do
    tickAccumulator = tickAccumulator - FIXED_TICK
    scheduler:runTasks()

    inputState:update(world.replayInputMask or InputState.buildMask({
      DPAD_UP = love.keyboard.isDown("up"),
      DPAD_DOWN = love.keyboard.isDown("down"),
      DPAD_LEFT = love.keyboard.isDown("left"),
      DPAD_RIGHT = love.keyboard.isDown("right"),
      A_BUTTON = love.keyboard.isDown("return"),
      B_BUTTON = love.keyboard.isDown("backspace"),
      SELECT_BUTTON = love.keyboard.isDown("rshift"),
      START_BUTTON = love.keyboard.isDown("space"),
    }))
    if viewerActive then
      if inputState:isPressedOrRepeated(InputState.DPAD_DOWN) then viewerStep(1) end
      if inputState:isPressedOrRepeated(InputState.DPAD_UP) then viewerStep(-1) end
    end
    if world.battle then
      world.battle.controller:processInput(inputState)
      if world.battle.partyRecord
          and world.battle.controller.engine.turn ~= world.battle.persistedTurn then
        local battle = world.battle
        local ok, err = pcall(Battle.PartyBridge.persistPartyBattler,
          battle.partyRecord, battle.controller.engine.player)
        battle.persistedTurn = battle.controller.engine.turn
        if not ok then
          addLine("Session party battle state failed to persist: " .. tostring(err))
        end
      end
      if world.battle and world.battle.kind == "oakLabRival" then
        world.settleOakLabRivalBattle(world.battle)
      end
      if world.battle.controller:isComplete() then
        local battle = world.battle
        local outcome = battle.controller.engine.outcome
        -- Whatever BAG did during the battle (a real ball thrown/consumed)
        -- must land back in the session's save-compatible state, win or
        -- lose -- a real ball is spent the moment it's thrown, not only
        -- on a successful catch.
        if battle.controller.bag and newGame.session then
          Battle.SessionBagBridge.toSaveBlock1(battle.controller.bag, newGame.session.state.saveBlock1)
        end
        if battle.kind == "oakLabRival" then
          world.finishOakLabRivalBattle(battle)
        elseif battle.kind == "trainer" then
          world.finishTrainerBattle(battle)
        elseif outcome == "playerLost" then
          local sb1 = newGame.session.state.saveBlock1
          local topLevel = Battle.WhiteoutRules.highestPartyLevel(sb1.playerParty, sb1.playerPartyCount)
          local badgeCount = Battle.WhiteoutRules.countBadges(function(id) return newGame.session:getFlag(id) end)
          local loss = Battle.WhiteoutRules.computeMoneyLoss(topLevel, badgeCount, sb1.money or 0)
          sb1.money = (sb1.money or 0) - loss
          Battle.RivalRewards.healParty(sb1, world.battleCatalog.moves)
          local start = NewGameDefaults.startingWarp
          local respawn = Battle.WhiteoutRules.respawnLocation(sb1.lastHealLocation,
            { mapGroup=4, mapNum=1, warpId=start.warpId, x=start.x, y=start.y })
          loadMap(romData, romAddrs, respawn.mapGroup * 256 + respawn.mapNum, function() end)
          if playerMovement then
            playerMovement.tileX, playerMovement.tileY = respawn.x, respawn.y
            playerMovement.facingDirection = PlayerMovement.DOWN
            playerMovement.moving, playerMovement.stepFrame = false, 0
          end
          syncSessionLocation()
          addLine(("Whiteout: lost $%d, party healed, respawned at %d,%d (%d,%d)."):format(
            loss, respawn.mapGroup, respawn.mapNum, respawn.x, respawn.y))
          world.battle = nil
        elseif outcome == "playerWon" then
          if battle.partyRecord and battle.foeInstance then
            local ok, reward = pcall(Battle.RivalRewards.applyWildVictory,
              battle.partyRecord, battle.foeInstance, world.battleCatalog.species,
              world.battleCatalog.natures,
              Battle.Learnset.resolve(romData, romAddrs.gLevelUpLearnsets,
                battle.controller.engine.player.species),
              world.regionMapSectionId)
            if ok then
              local levelMsg = ""
              if reward.newLevel > reward.oldLevel then
                levelMsg = (" Grew to Lv. %d!"):format(reward.newLevel)
              end
              addLine(("Wild battle won: gained %d EXP.%s"):format(reward.exp, levelMsg))
              if reward.skippedLevelUpMoves then
                addLine("(A level-up move was reached but not learned -- no move-learn UI yet.)")
              end
            else
              addLine("Wild battle won, but reward application failed: " .. tostring(reward))
            end
          else
            addLine("Wild battle won. No session party to reward (developer battle).")
          end
          world.battle = nil
        elseif outcome == "caught" then
          if newGame.session and battle.foeInstance then
            local sb1, sb2 = newGame.session.state.saveBlock1, newGame.session.state.saveBlock2
            local liveFoe = battle.controller.engine.foe
            local ok, caught = pcall(Battle.WildFactory.capture, battle.foeInstance, {
              ball = Battle.CaptureRules.ITEM_POKE_BALL,
              trainer = { id=sb2.playerTrainerId, name=sb2.playerName:sub(1, 7), gender=sb2.playerGender },
              hp = liveFoe.hp, status = liveFoe.status, moveSlots = liveFoe.moves,
            })
            if ok then
              local nationalDexNo = Battle.PokedexOrder.speciesToNationalDexNum(
                romData, romAddrs.sSpeciesToNationalPokedexNum, battle.foeInstance.species)
              -- Real GiveMonToPlayer tries the party first; PC-box overflow
              -- (src/core/CaptureRewards.lua's giveMonToPlayer, real
              -- SendMonToPC) needs a live PcBoxes instance this session
              -- doesn't carry yet -- flagged, not silently dropped: a full
              -- party still marks the Dex (real HandleSetPokedexFlag ran
              -- regardless of where GiveMonToPlayer routed the mon) but
              -- says plainly that the capture itself wasn't stored.
              if (sb1.playerPartyCount or 0) < 6 then
                sb1.playerParty = sb1.playerParty or {}
                sb1.playerParty[sb1.playerPartyCount + 1] = caught
                sb1.playerPartyCount = sb1.playerPartyCount + 1
                addLine(("Gotcha! %s was caught and added to the party!"):format(speciesName(battle.foeInstance.species)))
              else
                addLine(("Gotcha! %s was caught, but the party is full and PC-box storage isn't wired into the live session yet -- this capture was NOT saved.")
                  :format(speciesName(battle.foeInstance.species)))
              end
              if nationalDexNo then
                newGame.story:registerCaught(nationalDexNo)
              end
            else
              addLine("Captured, but persistence failed: " .. tostring(caught))
            end
          else
            addLine("Wild battle: caught, but no session party to persist to (developer battle).")
          end
          world.battle = nil
        else
          addLine("Returned to the field after running from the wild battle.")
          world.battle = nil
        end
      end
    elseif world.martActive and world.martMenu then
      world.martMenu:processInput(inputState)
      if world.martMenu:isDone() then world.closeMart() end
    elseif world.partyScreenActive and world.partyScreen then
      world.partyScreen:processInput(inputState)
      if world.partyScreen:isDone() then
        -- Real B/CANCEL and a real confirmed-slot selection both return to
        -- the (still open) Start menu -- see PartyScreen.lua's header:
        -- selecting a living mon would real-open the SUMMARY/SWITCH/ITEM
        -- submenu, out of scope here, so a confirmed slot just reports
        -- which one and falls back to the Start menu like CANCEL does.
        if world.partyScreen.state == Battle.PartyScreen.CONFIRMED then
          addLine(("Selected party slot %d (no SUMMARY/SWITCH/ITEM menu yet)."):format(world.partyScreen.confirmedSlot))
        end
        world.partyScreen = nil
        world.partyScreenActive = false
      end
    elseif world.bagScreenActive and world.bagScreen then
      world.bagScreen:processInput(inputState)
      if world.bagScreen:isDone() then
        -- BagScreen now owns its own real per-item context menu (USE/GIVE
        -- stubs, a real working TOSS) internally -- isDone() only fires
        -- once the whole Bag screen actually closes back to the Start
        -- menu, so there's nothing left to report here.
        if newGame.session then
          Battle.SessionBagBridge.toSaveBlock1(world.bagScreen.bag, newGame.session.state.saveBlock1)
        end
        world.bagScreen = nil
        world.bagScreenActive = false
      end
    elseif world.startMenuActive and world.startMenu then
      world.startMenu:processInput(inputState)
      if world.startMenu.state == Battle.StartMenu.CLOSED then
        world.closeStartMenu()
      elseif world.startMenu.state == Battle.StartMenu.SELECTED then
        world.handleStartMenuSelection()
      end
    elseif newGame.active and newGame.flow then
      newGame.flow:processInput(inputState)
      if newGame.flow:isComplete() then bootstrapFreshSession() end
    elseif walkActive and world.starterChoice then
      local outcome = world.starterChoice.cursor:processInput(inputState)
      if outcome == "confirm" and world.starterChoice.cursor.cursorPos == 0 then
        acceptStarterChoice()
      elseif outcome == "confirm" or outcome == "cancel" then
        local declined = newGame.story:declineStarter()
        world.starterChoice = nil
        addLine(("Declined %s; all three real choices remain available.")
          :format(declined and speciesName(declined.species) or "starter"))
      end
    elseif oakSceneActive and inputState:isNewlyPressed(InputState.A_BUTTON) then
      -- The S view is the real Oak narration frame; A continues into the
      -- real next task family, starting gender selection.
      beginNewGameFlow()
    elseif walkActive and playerMovement
        and (world.trainerApproach or (world.dialogue and world.dialogue:isActive())) then
      -- A real script's `lock`/`lockall` (and just having a message box
      -- open) blocks field input entirely -- the A press is consumed by
      -- the dialogue's own advance, handled in dialogueTask. A pending
      -- trainer approach sequence blocks field input the same real way
      -- (see trainerApproachTask/tryTrainerSightlineAt).
    elseif walkActive and playerMovement then
      if inputState:isNewlyPressed(InputState.START_BUTTON) then world.openStartMenu() end
      if inputState:isNewlyPressed(InputState.A_BUTTON) then tryStartInteraction() end
      -- Real continuous walking-while-held uses a plain held-key check
      -- every frame (not the menu-style repeat-with-delay system --
      -- that's specific to menu cursors, see InputState.lua/MenuCursor.lua),
      -- so the next tile starts immediately once the current step finishes.
      if inputState:isHeld(InputState.DPAD_DOWN) then playerMovement:tryMove(PlayerMovement.DOWN, world.isPlayerWalkTileBlocked, getLedgeJumpDirection)
      elseif inputState:isHeld(InputState.DPAD_UP) then playerMovement:tryMove(PlayerMovement.UP, world.isPlayerWalkTileBlocked, getLedgeJumpDirection)
      elseif inputState:isHeld(InputState.DPAD_LEFT) then playerMovement:tryMove(PlayerMovement.LEFT, world.isPlayerWalkTileBlocked, getLedgeJumpDirection)
      elseif inputState:isHeld(InputState.DPAD_RIGHT) then playerMovement:tryMove(PlayerMovement.RIGHT, world.isPlayerWalkTileBlocked, getLedgeJumpDirection)
      end
    end
    if yesNoActive and yesNoCursor and not yesNoResult then
      local outcome = yesNoCursor:processInput(inputState)
      if outcome == "confirm" or outcome == "cancel" then yesNoResult = outcome end
    end
  end
end

local function drawNewGameFlow(y)
  ensureNewGameImageCurrent()
  if not newGame.screenImage or not newGame.flow then return end
  local windowWidth, windowHeight = love.graphics.getDimensions()
  local viewport = ViewportScale.fit(240, 160, windowWidth - 40, windowHeight - (y + 10))
  -- Keep the same y-origin convention as other views. The menu helper's
  -- fixed 30 below corresponds to y+10 when status occupies one line;
  -- adjust it here so overlays remain locked to GBA screen coordinates.
  local baseX, baseY = 20 + viewport.x, y + 10 + viewport.y
  love.graphics.draw(newGame.screenImage, baseX, baseY, 0, viewport.scale, viewport.scale)

  local flow = newGame.flow
  local function menu(image, textImage, cursor, sx, sy)
    local fill = newGame.fillColor
    local x, yy = baseX + sx * viewport.scale, baseY + sy * viewport.scale
    if fill then
      love.graphics.setColor(fill[1], fill[2], fill[3])
      love.graphics.rectangle("fill", x + 8 * viewport.scale, yy + 8 * viewport.scale,
        (image:getWidth() - 16) * viewport.scale, (image:getHeight() - 16) * viewport.scale)
      love.graphics.setColor(1, 1, 1)
    end
    love.graphics.draw(image, x, yy, 0, viewport.scale, viewport.scale)
    if textImage then
      love.graphics.draw(textImage, x + (8 + newGame.arrowImage:getWidth()) * viewport.scale,
        yy + 9 * viewport.scale, 0, viewport.scale, viewport.scale)
    end
    if cursor and newGame.arrowImage then
      love.graphics.draw(newGame.arrowImage, x + 8 * viewport.scale,
        yy + (9 + cursor.cursorPos * 16) * viewport.scale, 0, viewport.scale, viewport.scale)
    end
  end

  if flow.state == NewGameFlow.GENDER then
    menu(newGame.genderWindowImage, newGame.genderTextImage, flow.genderCursor, 136, 64)
  elseif flow.state == NewGameFlow.RIVAL_CHOICE then
    menu(newGame.rivalWindowImage, newGame.rivalTextImage, flow.rivalChoiceCursor, 8, 8)
  elseif flow.state == NewGameFlow.PLAYER_CONFIRM or flow.state == NewGameFlow.RIVAL_CONFIRM then
    menu(newGame.confirmWindowImage, newGame.confirmTextImage, flow.confirmCursor, 8, 8)
  elseif flow.state == NewGameFlow.COMPLETE then
    local gender = flow.playerGender == NewGameFlow.FEMALE and "GIRL" or "BOY"
    local summary = ("IDENTITY COMPLETE\n%s  %s\nRIVAL  %s\nSTARTING FRESH SAVE")
      :format(gender, flow:displayName(flow.playerName), flow:displayName(flow.rivalName))
    love.graphics.setColor(0.05, 0.08, 0.12, 0.82)
    love.graphics.rectangle("fill", baseX + 16 * viewport.scale, baseY + 40 * viewport.scale, 208 * viewport.scale, 72 * viewport.scale)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(summary, baseX + 24 * viewport.scale, baseY + 48 * viewport.scale, 0, viewport.scale, viewport.scale)
  end
  if newGame.error then love.graphics.print("New-game render error: " .. newGame.error, baseX, baseY + 165 * viewport.scale) end
end

local function battleTextImage(text, darkText)
  local battle = world.battle
  if not battle or not fontData or not fontPalette then return nil end
  local key = (darkText and "dark:" or "light:") .. text
  if battle.textImages[key] ~= nil then return battle.textImages[key] or nil end
  local ok, composited = pcall(TextRenderer.renderTokens, fontData, fontAddrs,
    Battle.Assets.textTokens(text, darkText), fontPalette)
  if not ok then battle.textImages[key] = false; return nil end
  local image = buildImage(composited)
  image:setFilter("nearest", "nearest")
  battle.textImages[key] = image
  return image
end

-- Minimal live battle presentation over the real ROM grass terrain/front/
-- back sprites. Health-box/window chrome is intentionally drawn with the
-- current native primitives; importing the full battle-interface tilemap
-- and healthbox sprite system belongs to the broader Phase 4 UI pass.
local function drawBattleScene(y)
  local battle, catalog = world.battle, world.battleCatalog
  if not battle or not catalog then return end
  local controller = battle.controller
  local windowWidth, windowHeight = love.graphics.getDimensions()
  local viewport = ViewportScale.fit(240, 160, windowWidth - 40, windowHeight - (y + 10))
  local baseX, baseY, scale = 20 + viewport.x, y + 10 + viewport.y, viewport.scale
  love.graphics.draw(catalog.backgroundImage, baseX, baseY, 0, scale, scale)

  if battle.foeImage and controller.displayedHP.foe > 0 then
    love.graphics.draw(battle.foeImage, baseX + 144 * scale, baseY + 8 * scale, 0, scale, scale)
  end
  if battle.playerImage and controller.displayedHP.player > 0 then
    love.graphics.draw(battle.playerImage, baseX + 40 * scale, baseY + 48 * scale, 0, scale, scale)
  end

  local function drawText(text, x, yy, dark)
    local image = battleTextImage(text, dark)
    if image then love.graphics.draw(image, baseX + x * scale, baseY + yy * scale, 0, scale, scale) end
  end
  local function healthBox(side, x, yy)
    local battler = controller.engine:battler(side)
    local hp = controller.displayedHP[side]
    local name = side == "player" and controller.playerName or controller.foeName
    love.graphics.setColor(0.96, 0.96, 0.9)
    love.graphics.rectangle("fill", baseX + x*scale, baseY + yy*scale, 108*scale, 31*scale)
    love.graphics.setColor(0.12, 0.12, 0.12)
    love.graphics.rectangle("line", baseX + x*scale, baseY + yy*scale, 108*scale, 31*scale)
    love.graphics.setColor(1, 1, 1)
    drawText(name .. " Lv" .. battler.level, x+4, yy+1, true)
    love.graphics.setColor(0.15, 0.15, 0.15)
    love.graphics.rectangle("fill", baseX+(x+24)*scale, baseY+(yy+20)*scale, 78*scale, 5*scale)
    local ratio = battler.maxHP > 0 and hp / battler.maxHP or 0
    local r, g = ratio <= 0.2 and 0.85 or (ratio <= 0.5 and 0.95 or 0.2), ratio <= 0.2 and 0.15 or (ratio <= 0.5 and 0.75 or 0.75)
    love.graphics.setColor(r, g, 0.12)
    love.graphics.rectangle("fill", baseX+(x+25)*scale, baseY+(yy+21)*scale, 76*ratio*scale, 3*scale)
    love.graphics.setColor(1, 1, 1)
    drawText("HP", x+4, yy+13, true)
  end
  healthBox("foe", 8, 8)
  healthBox("player", 124, 72)

  love.graphics.setColor(0.96, 0.96, 0.92)
  love.graphics.rectangle("fill", baseX, baseY + 112*scale, 240*scale, 48*scale)
  love.graphics.setColor(0.1, 0.1, 0.12)
  love.graphics.rectangle("line", baseX, baseY + 112*scale, 240*scale, 48*scale)
  love.graphics.setColor(1, 1, 1)

  local function cursorAt(x, yy)
    love.graphics.setColor(0.15, 0.15, 0.18)
    love.graphics.polygon("fill", baseX+x*scale, baseY+yy*scale,
      baseX+(x+5)*scale, baseY+(yy+4)*scale, baseX+x*scale, baseY+(yy+8)*scale)
    love.graphics.setColor(1, 1, 1)
  end

  if controller.state == Battle.Controller.MESSAGES then
    drawText(controller:message() or "", 8, 119, true)
  elseif controller.state == Battle.Controller.ACTION then
    drawText("What will\n" .. controller.playerName .. " do?", 7, 115, true)
    local labels = { "FIGHT", "BAG", "POKEMON", "RUN" }
    local positions = { {133,115}, {193,115}, {133,135}, {193,135} }
    for i, label in ipairs(labels) do drawText(label, positions[i][1], positions[i][2], true) end
    local p = positions[controller.actionCursor + 1]
    cursorAt(p[1] - 8, p[2] + 3)
  elseif controller.state == Battle.Controller.MOVE then
    for i, moveSlot in ipairs(controller.engine.player.moves) do
      local col, row = (i-1)%2, math.floor((i-1)/2)
      drawText(Charmap.decodeAt(romData, romAddrs.gMoveNames, 13, moveSlot.move), 16+col*82, 115+row*18, true)
    end
    local slot = controller.engine.player.moves[controller.moveCursor + 1]
    if slot then
      local move = catalog.moves[slot.move]
      drawText(("PP %d/%d"):format(slot.pp, move.pp), 177, 115, true)
      drawText(Charmap.decodeAt(romData, romAddrs.gTypeNames, 7, move.type), 177, 135, true)
    end
    local col, row = controller.moveCursor%2, math.floor(controller.moveCursor/2)
    cursorAt(8+col*82, 118+row*18)
  end
end

function love.draw()
  if newGame.active then ensureNewGameImageCurrent() end
  if fontActive then ensureFontImageCurrent() end
  if oakSpeechActive then ensureOakSpeechImageCurrent() end
  if walkActive then ensureDialogueImagesCurrent() end
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

  if world.battle then
    drawBattleScene(y)
  elseif world.martActive and world.martMenu then
    y = y + 10
    for _, line in ipairs(world.martLines()) do
      love.graphics.print(line, 20, y)
      y = y + 20
    end
  elseif world.partyScreenActive and world.partyScreen then
    y = y + 10
    for _, line in ipairs(world.partyScreenLines()) do
      love.graphics.print(line, 20, y)
      y = y + 20
    end
  elseif world.bagScreenActive and world.bagScreen then
    y = y + 10
    for _, line in ipairs(world.bagScreenLines()) do
      love.graphics.print(line, 20, y)
      y = y + 20
    end
  elseif world.startMenuActive and world.startMenu then
    y = y + 10
    for _, line in ipairs(world.startMenuLines()) do
      love.graphics.print(line, 20, y)
      y = y + 20
    end
  elseif newGame.active then
    drawNewGameFlow(y)
  elseif viewerActive then
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
  elseif oakSceneActive and oakSceneImage then
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local viewport = ViewportScale.fit(oakSceneImage:getWidth(), oakSceneImage:getHeight(), windowWidth - 40, windowHeight - (y + 10))
    love.graphics.draw(oakSceneImage, 20 + viewport.x, y + 10 + viewport.y, 0, viewport.scale, viewport.scale)
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

    -- The map is quad-cropped to the real 240x160 GBA screen, but the
    -- NPC/player/dialogue draws below are separate un-quadded draws, so
    -- anything positioned off-camera (an NPC on the far side of the map,
    -- or one mid-step at the screen edge) would otherwise spill outside
    -- the viewport. Scissor to the same rect the map crop occupies.
    love.graphics.setScissor(baseX, baseY, WALK_CAMERA_WIDTH * viewport.scale, WALK_CAMERA_HEIGHT * viewport.scale)

    -- Real object-event NPCs, drawn through the same camera crop as the
    -- player: their real (sub-tile-interpolated) pixel position, shifted by
    -- the composited image's border margin, with the sprite's bottom
    -- aligned to the tile like the player's is. hFlip for a right-facing
    -- NPC is the renderer's job (see ObjectEventGraphicsInfo's header), so
    -- it's a negative x scale about the sprite's own width here.
    for _, npc in ipairs(world.npcs) do
      local npcImage, hFlip = npcSprite(npc)
      if npcImage then
        local npcX = npc:pixelX() + borderOffsetPx
        local npcY = npc:pixelY() + borderOffsetPx
        local screenX = baseX + (npcX - quadX) * viewport.scale
        local screenY = baseY + (npcY - quadY - (npcImage:getHeight() - 16)) * viewport.scale
        if hFlip then
          love.graphics.draw(npcImage, screenX + npcImage:getWidth() * viewport.scale, screenY, 0, -viewport.scale, viewport.scale)
        else
          love.graphics.draw(npcImage, screenX, screenY, 0, viewport.scale, viewport.scale)
        end
      end
    end

    if spriteImage then
      love.graphics.draw(spriteImage, baseX + (playerCompositedX - quadX) * viewport.scale, baseY + (playerCompositedY - quadY - 16) * viewport.scale, 0, viewport.scale, viewport.scale)
    end

    -- Real message box (DialogueRunner), drawn over the field like the
    -- real bg0 dialogue window sitting in front of the map/OBJ layers.
    if world.dialogue and world.dialogue.printer and world.dialogueWindowImage then
      local boxX = baseX + 8 * viewport.scale
      local boxY = baseY + (WALK_CAMERA_HEIGHT - world.dialogueWindowImage:getHeight() - 8) * viewport.scale
      if world.dialogueFillColor then
        local c = world.dialogueFillColor
        love.graphics.setColor(c[1], c[2], c[3])
        love.graphics.rectangle("fill", boxX, boxY,
          world.dialogueWindowImage:getWidth() * viewport.scale, world.dialogueWindowImage:getHeight() * viewport.scale)
        love.graphics.setColor(1, 1, 1)
      end
      love.graphics.draw(world.dialogueWindowImage, boxX, boxY, 0, viewport.scale, viewport.scale)
      if world.dialogueTextImage then
        -- Real messages page with \p (EXT "new paragraph": clear the
        -- window and start over) and \l (scroll up a line). Charmap.lua
        -- currently renders all three real linebreak bytes as a plain
        -- newline (documented in its own header), so a long real message
        -- can run past the box's 4 content rows and past its right edge
        -- until real pagination exists. Clipped to the frame's interior
        -- so it never spills onto the field in the meantime.
        love.graphics.intersectScissor(boxX + TextWindow.TILE_SIZE * viewport.scale, boxY + TextWindow.TILE_SIZE * viewport.scale,
          DIALOGUE_CONTENT_TILES_W * TextWindow.TILE_SIZE * viewport.scale, DIALOGUE_CONTENT_TILES_H * TextWindow.TILE_SIZE * viewport.scale)
        love.graphics.draw(world.dialogueTextImage, boxX + TextWindow.TILE_SIZE * viewport.scale, boxY + TextWindow.TILE_SIZE * viewport.scale, 0, viewport.scale, viewport.scale)
        love.graphics.setScissor(baseX, baseY, WALK_CAMERA_WIDTH * viewport.scale, WALK_CAMERA_HEIGHT * viewport.scale)
      end
    end

    -- Bounded presentation of the real MSGBOX_YESNO starter confirmation.
    -- The imported general dialogue runner cannot yet suspend a full map
    -- script at yesnobox, so this overlay uses the same two-row MenuCursor
    -- input semantics and labels the choice directly. Acquisition still
    -- occurs only through the actual lab ball object interaction.
    if world.starterChoice then
      local prompt = world.starterChoice
      local boxX, boxY = baseX + 16*viewport.scale, baseY + 104*viewport.scale
      love.graphics.setColor(0.96, 0.96, 0.92)
      love.graphics.rectangle("fill", boxX, boxY, 208*viewport.scale, 48*viewport.scale)
      love.graphics.setColor(0.1, 0.1, 0.12)
      love.graphics.rectangle("line", boxX, boxY, 208*viewport.scale, 48*viewport.scale)
      love.graphics.print(("Choose %s?  %s YES   %s NO"):format(
        speciesName(prompt.choice.species), prompt.cursor.cursorPos == 0 and ">" or " ",
        prompt.cursor.cursorPos == 1 and ">" or " "),
        boxX + 8*viewport.scale, boxY + 14*viewport.scale, 0, viewport.scale, viewport.scale)
      love.graphics.setColor(1, 1, 1)
    end
    love.graphics.setScissor()
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

-- Every view is mutually exclusive. Centralised here rather than having
-- each key's branch re-list all the OTHER views' flags (which is how this
-- grew, and which meant adding the S view would have required editing all
-- nine existing branches): a view key clears everything, then toggles its
-- own flag back on if it wasn't already the active view.
world.clearViews = function()
  viewerActive, titleActive, spriteActive, itemBallActive = false, false, false, false
  fontActive, oakSpeechActive, oakSceneActive = false, false, false
  flameActive, yesNoActive, walkActive = false, false, false
  newGame.active = false
  if world.martActive then world.closeMart() end -- persists bag/money before leaving
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  elseif world.battle then
    -- StartWildBattle locks field controls and freezes object events in
    -- the real game. Battle input is polled through InputState in
    -- love.update; view hotkeys must not let the player abandon the scene.
    return
  elseif world.starterChoice then
    -- The real starter yes/no box owns field input until confirmed or
    -- declined. Menu input is polled through InputState in love.update.
    return
  elseif key == "v" then
    local was = viewerActive
    world.clearViews()
    viewerActive = not was
  elseif key == "t" then
    local was = titleActive
    world.clearViews()
    titleActive = not was
  elseif key == "p" then
    local was = spriteActive
    world.clearViews()
    spriteActive = not was
  elseif key == "i" then
    local was = itemBallActive
    world.clearViews()
    itemBallActive = not was
  elseif key == "f" then
    local was = fontActive
    world.clearViews()
    fontActive = not was
  elseif key == "o" then
    local was = oakSpeechActive
    world.clearViews()
    oakSpeechActive = not was
  elseif key == "s" then
    local was = oakSceneActive
    world.clearViews()
    oakSceneActive = not was
  elseif key == "n" then
    local was = newGame.active
    world.clearViews()
    if not was then beginNewGameFlow() end
  elseif key == "a" then
    local was = flameActive
    world.clearViews()
    flameActive = not was
  elseif key == "y" then
    local was = yesNoActive
    world.clearViews()
    yesNoActive = not was
    if yesNoActive and yesNoCursor then
      yesNoCursor.cursorPos = 0
      yesNoResult = nil
    end
  elseif key == "w" then
    local was = walkActive
    world.clearViews()
    walkActive = not was
  elseif key == "m" then
    local was = world.martActive
    world.clearViews()
    if not was then
      -- Real ViridianCity_Mart_Items (data/maps/ViridianCity_Mart/
      -- scripts.inc): POKE_BALL(4)/POTION(13)/ANTIDOTE(14)/PARALYZE_
      -- HEAL(18). Dev-reachable trigger, from any session location --
      -- the real walk-in-and-talk-to-the-clerk path now also works (see
      -- dialogueTask's pendingMartItemListPtr handling below), but only
      -- once the player has actually walked into Viridian City Mart.
      world.beginMart({ 4, 13, 14, 18 })
      world.martActive = world.martMenu ~= nil
    end
  elseif key == "k" and walkActive and newGame.session and not world.dialogue then
    -- Only meaningful mid-playthrough (an active session, not mid-dialogue,
    -- same restriction the real game's own save prompt implies).
    saveGame()
  elseif key == "l" then
    -- Loading is allowed from any non-blocked view (see the world.battle/
    -- starterChoice early returns above) so a save can be resumed straight
    -- from boot, not only from the walk view.
    loadGameFile()
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

-- Keep the live LÖVE entrypoint unchanged, while allowing the pure fresh
-- session constructor to be exercised by the plain-Lua targeted test.
if ... == "main" then
  return { GameSession=GameSession }
end
