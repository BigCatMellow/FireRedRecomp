-- Bounded, pure state controller for FireRed's first Viridian Mart / Oak's
-- Lab Parcel progression. Source: data/maps/ViridianCity_Mart/scripts.inc
-- and data/maps/PalletTown_ProfessorOaksLab/scripts.inc.
--
-- This owns only the persistent gates and inventory effects. Scripted
-- movement, message timing, fanfares, object removal, and generic map-script
-- scheduling remain outside its contract.

local ViridianParcelStory = {}
ViridianParcelStory.__index = ViridianParcelStory

ViridianParcelStory.MAP_VIRIDIAN_MART = 5 * 256 + 3
ViridianParcelStory.MAP_OAKS_LAB = 4 * 256 + 3

ViridianParcelStory.VAR_LAB_SCENE = 0x4055
ViridianParcelStory.VAR_MART_SCENE = 0x4057
ViridianParcelStory.VAR_OLD_MAN_SCENE = 0x4051
ViridianParcelStory.VAR_ROUTE22_SCENE = 0x4054
ViridianParcelStory.VAR_RIVALS_HOUSE_SCENE = 0x4058
ViridianParcelStory.VAR_TEALA_SCENE = 0x407C

ViridianParcelStory.FLAG_SYS_POKEDEX_GET = 0x829
ViridianParcelStory.ITEM_OAKS_PARCEL = 349
ViridianParcelStory.ITEM_POKE_BALL = 4

local function assertBoundary(session, inventory)
  assert(session and session.getVar and session.setVar and session.getFlag and session.setFlag,
    "ViridianParcelStory requires a GameSession-style flag/var boundary")
  assert(inventory and inventory.quantityOf and inventory.canAddItem
    and inventory.addItem and inventory.removeItem,
    "ViridianParcelStory requires quantityOf/canAddItem/addItem/removeItem inventory callbacks")
end

function ViridianParcelStory.new(session, inventory)
  assertBoundary(session, inventory)
  return setmetatable({ session=session, inventory=inventory }, ViridianParcelStory)
end

-- Models the persistent effects of ViridianCity_Mart_EventScript_ParcelScene.
-- The real ON_FRAME_TABLE chooses it only when mart scene is exactly zero.
function ViridianParcelStory:beginMartParcelScene(mapId)
  if mapId ~= self.MAP_VIRIDIAN_MART then return nil, "wrong_map" end
  if self.session:getVar(self.VAR_MART_SCENE) ~= 0 then return nil, "mart_scene_not_zero" end
  if not self.inventory:canAddItem(self.ITEM_OAKS_PARCEL, 1) then return nil, "parcel_bag_full" end
  if not self.inventory:addItem(self.ITEM_OAKS_PARCEL, 1) then return nil, "parcel_add_failed" end

  -- scripts.inc: set mart scene 1, give Parcel, set Lab scene 5. The item
  -- is granted first here only after capacity is preflighted, preserving an
  -- atomic pure-controller result rather than creating a half-applied state.
  self.session:setVar(self.VAR_MART_SCENE, 1)
  self.session:setVar(self.VAR_LAB_SCENE, 5)
  return { kind="martParcel", parcelGranted=true, martScene=1, labScene=5 }
end

-- Models the authoritative state effects at the end of Oak's Lab Dex scene.
-- The surrounding dialogue/cutscene is deliberately not represented here.
function ViridianParcelStory:completeLabParcelReturn(mapId)
  if mapId ~= self.MAP_OAKS_LAB then return nil, "wrong_map" end
  if self.session:getVar(self.VAR_MART_SCENE) < 1 then return nil, "mart_scene_before_parcel" end
  if self.session:getVar(self.VAR_LAB_SCENE) ~= 5 then return nil, "lab_scene_not_parcel_return" end
  if self.session:getFlag(self.FLAG_SYS_POKEDEX_GET) then return nil, "pokedex_already_received" end
  if self.inventory:quantityOf(self.ITEM_OAKS_PARCEL) < 1 then return nil, "parcel_missing" end
  if not self.inventory:canAddItem(self.ITEM_POKE_BALL, 5) then return nil, "poke_ball_bag_full" end
  if not self.inventory:removeItem(self.ITEM_OAKS_PARCEL, 1) then return nil, "parcel_remove_failed" end
  if not self.inventory:addItem(self.ITEM_POKE_BALL, 5) then
    error("ViridianParcelStory: preflighted Poke Ball grant failed after Parcel removal")
  end

  -- Exact trailing persistent writes in ReceiveDexScene, including the
  -- downstream map scenes confirmed in the retail source.
  self.session:setFlag(self.FLAG_SYS_POKEDEX_GET)
  self.session:setVar(self.VAR_TEALA_SCENE, 1)
  self.session:setVar(self.VAR_LAB_SCENE, 6)
  self.session:setVar(self.VAR_MART_SCENE, 2)
  self.session:setVar(self.VAR_OLD_MAN_SCENE, 1)
  self.session:setVar(self.VAR_RIVALS_HOUSE_SCENE, 1)
  self.session:setVar(self.VAR_ROUTE22_SCENE, 1)
  return { kind="labDex", parcelConsumed=true, pokedexGranted=true, pokeBallsGranted=5,
    labScene=6, martScene=2 }
end

return ViridianParcelStory
