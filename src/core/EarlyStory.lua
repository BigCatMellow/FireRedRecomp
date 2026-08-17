-- Bounded, pure controller for FireRed's first mandatory story gate:
-- bedroom -> Pallet Town north-exit Oak trigger -> Oak's lab -> starter.
--
-- Facts and state changes are transcribed from:
--   data/maps/PalletTown/map.json + scripts.inc
--   data/maps/PalletTown_ProfessorOaksLab/map.json + scripts.inc
--   include/constants/{flags,vars}.h
--
-- This controller intentionally represents only authoritative gameplay
-- state. main.lua presents the long Oak/rival movement and dialogue sequence
-- as an explicitly abbreviated cutscene, then places the player at the real
-- post-movement lab coordinate. The next mandatory event (the early-rival
-- trainer battle at lab y=8) is returned to the battle integration layer;
-- completeRivalBattle applies the source script's common postbattle state.

local EarlyStory = {}
EarlyStory.__index = EarlyStory

EarlyStory.MAP_PALLET_TOWN = 3 * 256 + 0
EarlyStory.MAP_OAKS_LAB = 4 * 256 + 3

EarlyStory.VAR_STARTER_MON = 0x4031
EarlyStory.VAR_PALLET_OAK_SCENE = 0x4050
EarlyStory.VAR_OAKS_LAB_SCENE = 0x4055

EarlyStory.FLAG_HIDE_BULBASAUR_BALL = 0x028
EarlyStory.FLAG_HIDE_SQUIRTLE_BALL = 0x029
EarlyStory.FLAG_HIDE_CHARMANDER_BALL = 0x02A
EarlyStory.FLAG_HIDE_OAK_IN_HIS_LAB = 0x02B
EarlyStory.FLAG_HIDE_OAK_IN_PALLET_TOWN = 0x02C
EarlyStory.FLAG_HIDE_RIVAL_IN_OAKS_LAB = 0x02D
EarlyStory.FLAG_BEAT_RIVAL_IN_OAKS_LAB = 0x258
EarlyStory.FLAG_VISITED_OAKS_LAB = 0x2CF
EarlyStory.FLAG_PALLET_LADY_NOT_BLOCKING_SIGN = 0x291
EarlyStory.FLAG_SYS_POKEMON_GET = 0x828 -- SYS_FLAGS(0x800) + 0x28
EarlyStory.TRAINER_FLAGS_START = 0x500

-- map.json local ids and scripts.inc assignments, in the actual left-to-
-- right layout: Bulbasaur x=8, Squirtle x=9, Charmander x=10.
local STARTERS = {
  [5]={ localId=5, species=1, starterNum=0, rivalSpecies=4, rivalTrainerId=328, rivalBallLocalId=7, name="BULBASAUR" },
  [6]={ localId=6, species=7, starterNum=1, rivalSpecies=1, rivalTrainerId=327, rivalBallLocalId=5, name="SQUIRTLE" },
  [7]={ localId=7, species=4, starterNum=2, rivalSpecies=7, rivalTrainerId=326, rivalBallLocalId=6, name="CHARMANDER" },
}
EarlyStory.STARTERS = STARTERS

function EarlyStory.new(session)
  assert(session and session.getVar and session.setVar and session.getFlag
    and session.setFlag and session.clearFlag,
    "EarlyStory requires a GameSession-style flag/var boundary")
  return setmetatable({
    session=session, pendingStarter=nil, removedLabObjects={},
  }, EarlyStory)
end

local function matchingCoordEvent(coordEvents, x, y, varId, value)
  if not coordEvents then return false end
  local i = 0
  while coordEvents[i] ~= nil do
    local event = coordEvents[i]
    if event.x == x and event.y == y and event.trigger == varId and event.index == value then
      return true
    end
    i = i + 1
  end
  return false
end

-- Called only after a completed field step. Returns a declarative action
-- for main.lua, or nil when no supported story coordinate event fired.
function EarlyStory:onStep(mapId, x, y, coordEvents)
  if mapId == EarlyStory.MAP_PALLET_TOWN
      and self.session:getVar(EarlyStory.VAR_PALLET_OAK_SCENE) == 0
      and matchingCoordEvent(coordEvents, x, y, EarlyStory.VAR_PALLET_OAK_SCENE, 0) then
    -- PalletTown_EventScript_OakTrigger's persistent state immediately
    -- before its warp, followed by the lab transition/on-frame scene's
    -- persistent result. We collapse only presentation timing/movement.
    self.session:setVar(EarlyStory.VAR_PALLET_OAK_SCENE, 1)
    self.session:setVar(EarlyStory.VAR_OAKS_LAB_SCENE, 2)
    self.session:setFlag(EarlyStory.FLAG_HIDE_OAK_IN_PALLET_TOWN)
    self.session:clearFlag(EarlyStory.FLAG_HIDE_OAK_IN_HIS_LAB)
    self.session:setFlag(EarlyStory.FLAG_VISITED_OAKS_LAB)
    return {
      kind="oakEscort", mapId=EarlyStory.MAP_OAKS_LAB,
      -- Explicit `warp ..., 6, 12`, then eight PlayerEnter walk_up steps.
      x=6, y=4, facing="north",
    }
  end

  local labScene = self.session:getVar(EarlyStory.VAR_OAKS_LAB_SCENE)
  if mapId == EarlyStory.MAP_OAKS_LAB and labScene == 2
      and matchingCoordEvent(coordEvents, x, y, EarlyStory.VAR_OAKS_LAB_SCENE, 2) then
    -- EventScript_LeaveStarterSceneTrigger moves the player one tile up.
    return { kind="stayForStarter", x=x, y=y-1, facing="north" }
  end
  if mapId == EarlyStory.MAP_OAKS_LAB and labScene == 3
      and matchingCoordEvent(coordEvents, x, y, EarlyStory.VAR_OAKS_LAB_SCENE, 3) then
    local starterNum = self.session:getVar(EarlyStory.VAR_STARTER_MON)
    local trainerId
    for _, choice in pairs(STARTERS) do
      if choice.starterNum == starterNum then trainerId = choice.rivalTrainerId; break end
    end
    assert(trainerId, "scene 3 has no valid VAR_STARTER_MON rival mapping")
    -- Unlike scene 2's leave guard, the scene-3 script only turns the
    -- player in place. The player remains on the triggering y=8 tile.
    return { kind="rivalBattle", trainerId=trainerId, lane=x-4,
      x=x, y=y, facing="north" }
  end
  return nil
end

function EarlyStory:beginStarterChoice(mapId, localId)
  local choice = STARTERS[localId]
  if mapId ~= EarlyStory.MAP_OAKS_LAB or not choice then return nil end
  if self.session:getVar(EarlyStory.VAR_OAKS_LAB_SCENE) ~= 2 then
    return { kind="starterUnavailable", choice=choice,
      reason="Oak has not opened the starter choice (lab scene 2 is required)." }
  end
  if self.session.state.saveBlock1.playerPartyCount ~= 0 then
    return { kind="starterUnavailable", choice=choice,
      reason="The first-starter script requires the fresh empty-party story state." }
  end
  self.pendingStarter = choice
  return { kind="confirmStarter", choice=choice }
end

function EarlyStory:declineStarter()
  local choice = self.pendingStarter
  self.pendingStarter = nil
  return choice
end

local function setDexBit(bytes, nationalDexNo)
  assert(type(bytes) == "string" and #bytes >= 52, "Dex bitfield must be 52 bytes")
  assert(nationalDexNo >= 1 and nationalDexNo <= 411, "National Dex number out of range")
  local zero = nationalDexNo - 1
  local index, bit = math.floor(zero / 8) + 1, zero % 8
  local old = string.byte(bytes, index)
  if math.floor(old / 2^bit) % 2 == 1 then return bytes end
  return bytes:sub(1, index-1) .. string.char(old + 2^bit) .. bytes:sub(index+1)
end

-- Battle intro's HandleSetPokedexFlag(..., FLAG_SET_SEEN) mirrors the
-- opponent species into the same modeled save arrays as ScriptGiveMon.
function EarlyStory:registerSeen(nationalDexNo)
  local sb1, sb2 = self.session.state.saveBlock1, self.session.state.saveBlock2
  sb2.pokedex.seen = setDexBit(sb2.pokedex.seen, nationalDexNo)
  sb1.seen1 = setDexBit(sb1.seen1, nationalDexNo)
  if sb1.seen2 then sb1.seen2 = setDexBit(sb1.seen2, nationalDexNo) end
end

-- Real HandleSetPokedexFlag(FLAG_SET_CAUGHT, ...): sets the owned bit
-- (same real independent-but-usually-paired-with-seen semantics
-- src/core/CaptureRewards.lua's markCaught already documents for its own
-- DexTracker-shaped callers -- this is the same real fact applied to
-- this project's session-state byte-string dex representation instead).
-- Marks seen too, since a capture always follows the mon being seen in
-- this same battle.
function EarlyStory:registerCaught(nationalDexNo)
  self:registerSeen(nationalDexNo)
  local sb2 = self.session.state.saveBlock2
  sb2.pokedex.owned = setDexBit(sb2.pokedex.owned, nationalDexNo)
end

-- Mirrors PalletTown_..._ChoseStarter through RivalTakesStarter:
-- ScriptGiveMon puts the mon in party and sets seen/caught; then the map
-- script sets the two system/story flags, VAR_STARTER_MON, removes the
-- selected and rival-picked ball objects, and advances lab scene to 3.
function EarlyStory:acceptStarter(partyRecord, nationalDexNo)
  local choice = assert(self.pendingStarter, "no pending starter choice")
  assert(type(partyRecord) == "table" and partyRecord.species == choice.species,
    "party record species does not match pending starter")
  local sb1, sb2 = self.session.state.saveBlock1, self.session.state.saveBlock2
  assert(sb1.playerPartyCount == 0 and #(sb1.playerParty or {}) == 0,
    "starter acquisition expects the fresh empty party")

  sb1.playerParty = sb1.playerParty or {}
  sb1.playerParty[1] = partyRecord
  sb1.playerPartyCount = 1
  sb2.pokedex.seen = setDexBit(sb2.pokedex.seen, nationalDexNo)
  sb2.pokedex.owned = setDexBit(sb2.pokedex.owned, nationalDexNo)
  sb1.seen1 = setDexBit(sb1.seen1, nationalDexNo)
  self.session:setFlag(EarlyStory.FLAG_SYS_POKEMON_GET)
  self.session:setFlag(EarlyStory.FLAG_PALLET_LADY_NOT_BLOCKING_SIGN)
  self.session:setVar(EarlyStory.VAR_STARTER_MON, choice.starterNum)
  self.session:setVar(EarlyStory.VAR_OAKS_LAB_SCENE, 3)
  self.removedLabObjects[choice.localId] = true
  self.removedLabObjects[choice.rivalBallLocalId] = true
  self.session:setFlag(choice.localId == 5 and EarlyStory.FLAG_HIDE_BULBASAUR_BALL
    or choice.localId == 6 and EarlyStory.FLAG_HIDE_SQUIRTLE_BALL
    or EarlyStory.FLAG_HIDE_CHARMANDER_BALL)
  self.session:setFlag(choice.rivalBallLocalId == 5 and EarlyStory.FLAG_HIDE_BULBASAUR_BALL
    or choice.rivalBallLocalId == 6 and EarlyStory.FLAG_HIDE_SQUIRTLE_BALL
    or EarlyStory.FLAG_HIDE_CHARMANDER_BALL)
  self.pendingStarter = nil
  return choice
end

-- The lab script resumes here after either win or the special early-rival
-- loss return. It heals outside this controller, removes the rival, sets
-- scene 4, sets the explicit story flag, and the battle callback has already
-- set the selected trainer flag.
function EarlyStory:completeRivalBattle(outcome, trainerId)
  assert(outcome == "playerWon" or outcome == "playerLost",
    "Oak-lab battle can only complete by win or loss")
  assert(self.session:getVar(EarlyStory.VAR_OAKS_LAB_SCENE) == 3,
    "Oak-lab rival completion requires scene 3")
  local expected
  local starterNum = self.session:getVar(EarlyStory.VAR_STARTER_MON)
  for _, choice in pairs(STARTERS) do
    if choice.starterNum == starterNum then expected = choice.rivalTrainerId; break end
  end
  assert(trainerId == expected, "rival trainer does not match VAR_STARTER_MON")
  self.session:setFlag(EarlyStory.TRAINER_FLAGS_START + trainerId)
  self.session:setFlag(EarlyStory.FLAG_BEAT_RIVAL_IN_OAKS_LAB)
  self.session:setFlag(EarlyStory.FLAG_HIDE_RIVAL_IN_OAKS_LAB)
  self.session:setVar(EarlyStory.VAR_OAKS_LAB_SCENE, 4)
  self.removedLabObjects[8] = true
  return { outcome=outcome, trainerId=trainerId, scene=4 }
end

function EarlyStory:isObjectRemoved(mapId, localId)
  return mapId == EarlyStory.MAP_OAKS_LAB and self.removedLabObjects[localId] == true
end

return EarlyStory
