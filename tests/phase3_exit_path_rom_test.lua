-- ROM-backed deterministic replay proof for the bounded Phase 3 exit path.
-- It composes the production new-save, Oak/starter, Route 1 encounter,
-- battle, capture/reward, bag, Dex, and SaveFileCodec seams using only data
-- decoded from the verified FireRed US v1.0 ROM.  It deliberately does not
-- drive LÖVE input/rendering: no headless UI automation boundary exists yet.
-- Run: POKEPORT_ROM=/path/to/pokefirered.gba lua5.1 tests/phase3_exit_path_rom_test.lua
package.path = package.path .. ";./?.lua"

local path = os.getenv("POKEPORT_ROM")
if not path then print("SKIP phase3_exit_path_rom_test (set POKEPORT_ROM)"); os.exit(0) end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local SpeciesInfo = require("import.SpeciesInfo")
local BattleMove = require("import.BattleMove")
local TypeChart = require("import.TypeChart")
local Nature = require("import.Nature")
local LevelUpLearnset = require("import.LevelUpLearnset")
local MapHeader = require("import.MapHeader")
local WildEncounters = require("import.WildEncounters")
local PokedexOrder = require("import.PokedexOrder")
local Flow = require("src.core.NewGameFlow")
local EarlyStory = require("src.core.EarlyStory")
local StarterFactory = require("src.core.StarterPokemonFactory")
local WildFactory = require("src.core.WildPokemonFactory")
local WildSelector = require("src.core.WildEncounterSelector")
local BattlePartyBridge = require("src.core.BattlePartyBridge")
local BattleEngine = require("src.core.BattleEngine")
local CaptureRewards = require("src.core.CaptureRewards")
local SessionBagBridge = require("src.core.SessionBagBridge")
local SaveFileCodec = require("src.core.SaveFileCodec")

local ok, info = RomImporter.verify(path)
if not ok then print("FAIL: ROM verification -- " .. tostring(info)); os.exit(1) end
local f = assert(io.open(path, "rb")); local rom = f:read("*a"); f:close()
local addrs = assert(RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
love = {}
local App = require("main")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end
local function dexBit(bytes, national)
  local zero = national - 1
  return math.floor(string.byte(bytes, math.floor(zero / 8) + 1) / 2^(zero % 8)) % 2 == 1
end
local function zeroRng()
  return { next16=function() return 0 end }
end
local function replayRng(values)
  local i = 0
  return { next16=function() i = i + 1; return values[i] or 0 end }
end

local species = SpeciesInfo.parseTable(rom, addrs.gSpeciesInfo, RomAddresses.COUNTS.NUM_SPECIES)
local moves = BattleMove.parseTable(rom, addrs.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
local typeChart = TypeChart.parseTable(rom, addrs.gTypeEffectiveness)
local natures = Nature.parseTable(rom, addrs.sNatureStatTable)
local items = require("import.Item").parseTable(rom, addrs.gItems, RomAddresses.COUNTS.ITEMS_COUNT)
local route1 = MapHeader.resolve(rom, addrs.gMapGroups, 3 * 256 + 19)
-- Wild encounters are indexed through gWildMonHeaders, not MapHeader.
local route1Header = WildEncounters.findHeader(rom, addrs.gWildMonHeaders, 3, 19)
local route1Land = route1Header and WildEncounters.resolveInfo(rom, route1Header.landMonsInfoPtr, 12)
check("ROM exposes Route 1's real land encounter table", route1Land and route1Land.mons)
local rattata
if route1Land then
  -- A behavior transition plus zero-valued trigger RNG passes the real
  -- StandardWildEncounter dice rolls.  The shared global stream then picks
  -- land slot 1 (20) and its minimum level (0): Route 1 Rattata Lv. 3.
  local global = replayRng({0, 20, 0})
  local triggered = WildSelector.shouldTrigger(global, zeroRng(), route1Land.encounterRate, true)
  local rolled = WildSelector.roll(route1Land, global, "land")
  check("Route 1 replay triggers and selects retail Rattata Lv. 3", triggered
    and rolled.slot == 1 and rolled.species == 19 and rolled.level == 3)
  rattata = route1Land.mons[rolled.slot]
end
check("Route 1 replay has a selected retail Rattata slot", rattata ~= nil)

local function freshSession()
  local session = App.GameSession.fromNewGame({
    playerGender=Flow.MALE, playerName=Flow.encodeName("RED"), rivalName=Flow.encodeName("GREEN"),
  }, { nextRandom16=function() return 0x1234 end, generatedTrainerIdLower=0x5678 })
  local story = EarlyStory.new(session)
  -- NewGameInitData/WarpToPlayersRoom leaves this exact bedroom location;
  -- the completed Oak speech then permits the Pallet coordinate-event seam.
  check("fresh replay begins in the bedroom", session.mapId == 4 * 256 + 1)
  session:setLocation(EarlyStory.MAP_PALLET_TOWN, 12, 1, "north")
  local escort = story:onStep(EarlyStory.MAP_PALLET_TOWN, 12, 1, {
    [0]={x=12,y=1,trigger=EarlyStory.VAR_PALLET_OAK_SCENE,index=0},
    [1]={x=13,y=1,trigger=EarlyStory.VAR_PALLET_OAK_SCENE,index=0},
  })
  check("Oak intro transitions the replay into the lab", escort and escort.mapId == EarlyStory.MAP_OAKS_LAB)
  local choice = assert(story:beginStarterChoice(EarlyStory.MAP_OAKS_LAB, 5)).choice
  local starter = StarterFactory.generate({
    species=choice.species, speciesInfo=species[choice.species],
    speciesName=rom:sub(addrs.gSpeciesNames + choice.species * 11 + 1, addrs.gSpeciesNames + choice.species * 11 + 10),
    learnset=LevelUpLearnset.resolve(rom, addrs.gLevelUpLearnsets, choice.species),
    battleMoves=moves, natures=natures, rng=zeroRng(),
    trainer={id=session.state.saveBlock2.playerTrainerId, name=session.state.saveBlock2.playerName:sub(1, 7), gender=session.state.saveBlock2.playerGender},
    metLocation=0,
  })
  story:acceptStarter(starter, PokedexOrder.speciesToNationalDexNum(rom, addrs.sSpeciesToNationalPokedexNum, choice.species))
  session:setLocation(3 * 256 + 19, 10, 10, "north")
  return session, story
end

local function wild(session)
  return WildFactory.generate({
    species=rattata.species, level=rattata.minLevel, speciesInfo=species[rattata.species],
    speciesName=rom:sub(addrs.gSpeciesNames + rattata.species * 11 + 1, addrs.gSpeciesNames + rattata.species * 11 + 10),
    learnset=LevelUpLearnset.resolve(rom, addrs.gLevelUpLearnsets, rattata.species), battleMoves=moves,
    natures=natures, rng=zeroRng(),
    trainer={id=session.state.saveBlock2.playerTrainerId, name=session.state.saveBlock2.playerName:sub(1, 7), gender=session.state.saveBlock2.playerGender}, metLocation=1,
  })
end

-- Capture branch: a Poke Ball is consumed, the real engine resolves the
-- throw against a Route 1 wild mon, and the caught record/Dex survive reload.
if rattata then
  local session, story = freshSession()
  local bag = SessionBagBridge.fromSaveBlock1(session.state.saveBlock1, items)
  assert(bag:addItem(4, 1)) -- ITEM_POKE_BALL, replay inventory fixture
  local foe = wild(session)
  local player = assert(BattlePartyBridge.battlerFromParty(session.state.saveBlock1.playerParty[1], species))
  local battle = BattleEngine.new({player=player, foe=BattlePartyBridge.battlerFromGenerated(foe), moves=moves, typeChart=typeChart, rng=zeroRng()})
  check("Route 1 capture battle resolves", battle:runTurn({action="capture"}, {action="move",moveSlot=1})[3].success and battle.outcome == "caught")
  check("throwing the ball changes the live bag", CaptureRewards.consumeBall(bag, 4) and bag:quantityOf(4) == 0)
  SessionBagBridge.toSaveBlock1(bag, session.state.saveBlock1)
  local caught = WildFactory.capture(foe, {ball=4, trainer={id=session.state.saveBlock2.playerTrainerId, name=session.state.saveBlock2.playerName:sub(1,7), gender=session.state.saveBlock2.playerGender}})
  session.state.saveBlock1.playerParty[2] = caught; session.state.saveBlock1.playerPartyCount = 2
  local national = PokedexOrder.speciesToNationalDexNum(rom, addrs.sSpeciesToNationalPokedexNum, caught.species)
  story:registerCaught(national)
  check("capture persists party and Dex ownership", session.state.saveBlock1.playerParty[2].species == 19 and dexBit(session.state.saveBlock2.pokedex.owned, national))
  local bytes = assert(SaveFileCodec.encode(session.state, 0, nil))
  local loaded = App.GameSession.fromSavedState(assert(SaveFileCodec.decode(bytes)))
  local loadedCaught = assert(BattlePartyBridge.decodeRecord(loaded.state.saveBlock1.playerParty[2]))
  check("save/reload preserves identity, Route 1 location, caught party, Dex, and empty ball pocket",
    loaded.identity.playerName == Flow.encodeName("RED") and loaded.mapId == 3 * 256 + 19
      and loaded.location.x == 10 and loaded.location.y == 10
      and loaded.state.saveBlock1.playerPartyCount == 2
      and loadedCaught.substructs[0].species == 19
      and dexBit(loaded.state.saveBlock2.pokedex.owned, national)
      and loaded.state.saveBlock1.bagPocket_PokeBalls[1].quantity == 0,
    ("map=%s loc=%s,%s party=%s/%s dex=%s balls=%s"):format(tostring(loaded.mapId),
      tostring(loaded.location.x), tostring(loaded.location.y),
      tostring(loaded.state.saveBlock1.playerPartyCount), tostring(loadedCaught.substructs[0].species),
      tostring(dexBit(loaded.state.saveBlock2.pokedex.owned, national)),
      tostring(loaded.state.saveBlock1.bagPocket_PokeBalls[1] and loaded.state.saveBlock1.bagPocket_PokeBalls[1].quantity)))
end

-- Defeat branch: a one-HP Route 1 Rattata is still resolved by the real
-- battle engine; current HP is written back to the save record and a wild
-- victory leaves the fresh-save money unchanged while granting real EXP.
if rattata then
  local session = freshSession()
  local foe = wild(session); foe.hp = 1
  local record = session.state.saveBlock1.playerParty[1]
  local player = assert(BattlePartyBridge.battlerFromParty(record, species))
  local battle = BattleEngine.new({player=player, foe=BattlePartyBridge.battlerFromGenerated(foe), moves=moves, typeChart=typeChart, rng=zeroRng()})
  local beforeHP, beforeMoney = record.hp, session.state.saveBlock1.money
  battle:runTurn({action="move",moveSlot=1}, {action="move",moveSlot=1})
  BattlePartyBridge.persistPartyBattler(record, battle.player)
  local reward = require("src.core.EarlyRivalRewards").applyWildVictory(record, foe, species, natures,
    LevelUpLearnset.resolve(rom, addrs.gLevelUpLearnsets, battle.player.species), 1)
  check("Route 1 defeat persists battle HP and wild reward without money loss",
    battle.outcome == "playerWon" and record.hp > 0 and record.hp <= beforeHP
      and session.state.saveBlock1.money == beforeMoney and reward.exp > 0)
end

print(("phase3_exit_path_rom_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
