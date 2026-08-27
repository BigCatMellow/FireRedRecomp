-- Run: lua5.1 tests/viridian_parcel_story_test.lua
package.path = package.path .. ";./?.lua"
local Story = require("src.core.ViridianParcelStory")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then passed = passed + 1 else
    failed = failed + 1
    print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
  end
end

local function fixture(capacity)
  local vars, flags, items = {}, {}, {}
  local session = {
    getVar=function(_, id) return vars[id] or 0 end,
    setVar=function(_, id, value) vars[id] = value end,
    getFlag=function(_, id) return flags[id] == true end,
    setFlag=function(_, id) flags[id] = true end,
  }
  local inventory = {
    quantityOf=function(_, id) return items[id] or 0 end,
    canAddItem=function(_, _, quantity)
      local total = 0; for _, count in pairs(items) do total = total + count end
      return total + quantity <= (capacity or 99)
    end,
    addItem=function(self, id, quantity)
      if not self:canAddItem(id, quantity) then return false end
      items[id] = (items[id] or 0) + quantity; return true
    end,
    removeItem=function(_, id, quantity)
      if (items[id] or 0) < quantity then return false end
      items[id] = items[id] - quantity; return true
    end,
  }
  return Story.new(session, inventory), session, inventory
end

do
  local story, session, inventory = fixture()
  local action, reason = story:beginMartParcelScene(Story.MAP_VIRIDIAN_MART)
  check("Mart scene zero grants Oak's Parcel", action and action.parcelGranted and reason == nil)
  check("Parcel scene writes Mart 0 -> 1 and Lab -> 5",
    session:getVar(Story.VAR_MART_SCENE) == 1 and session:getVar(Story.VAR_LAB_SCENE) == 5)
  check("Parcel inventory change uses adapter", inventory:quantityOf(Story.ITEM_OAKS_PARCEL) == 1)
  local again, againReason = story:beginMartParcelScene(Story.MAP_VIRIDIAN_MART)
  check("Mart Parcel scene is idempotently gated after scene 1", again == nil and againReason == "mart_scene_not_zero")
  check("idempotent gate grants no second Parcel", inventory:quantityOf(Story.ITEM_OAKS_PARCEL) == 1)
end

do
  local story, session, inventory = fixture()
  local action, reason = story:beginMartParcelScene(Story.MAP_OAKS_LAB)
  check("Mart scene rejects wrong map", action == nil and reason == "wrong_map")
  check("wrong-map gate changes no story state", session:getVar(Story.VAR_MART_SCENE) == 0 and inventory:quantityOf(349) == 0)
end

do
  local story, session, inventory = fixture()
  local action, reason = story:completeLabParcelReturn(Story.MAP_OAKS_LAB)
  check("Lab return requires completed Mart Parcel scene", action == nil and reason == "mart_scene_before_parcel")
  check("missing gate grants no balls", inventory:quantityOf(Story.ITEM_POKE_BALL) == 0)
end

do
  local story, session, inventory = fixture()
  assert(story:beginMartParcelScene(Story.MAP_VIRIDIAN_MART))
  local action, reason = story:completeLabParcelReturn(Story.MAP_OAKS_LAB)
  check("Lab Parcel return grants Dex progression", action and action.pokedexGranted and reason == nil)
  check("Lab return consumes Parcel and grants exactly five balls",
    inventory:quantityOf(Story.ITEM_OAKS_PARCEL) == 0 and inventory:quantityOf(Story.ITEM_POKE_BALL) == 5)
  check("Lab return writes exact primary scenes and Dex flag",
    session:getFlag(Story.FLAG_SYS_POKEDEX_GET) and session:getVar(Story.VAR_LAB_SCENE) == 6
      and session:getVar(Story.VAR_MART_SCENE) == 2)
  check("Lab return writes confirmed downstream scenes",
    session:getVar(Story.VAR_TEALA_SCENE) == 1 and session:getVar(Story.VAR_OLD_MAN_SCENE) == 1
      and session:getVar(Story.VAR_RIVALS_HOUSE_SCENE) == 1 and session:getVar(Story.VAR_ROUTE22_SCENE) == 1)
  local again, againReason = story:completeLabParcelReturn(Story.MAP_OAKS_LAB)
  check("Dex scene is idempotently gated after completion", again == nil and againReason == "lab_scene_not_parcel_return")
  check("idempotent Dex gate grants no extra balls", inventory:quantityOf(Story.ITEM_POKE_BALL) == 5)
end

do
  local story, session, inventory = fixture(0)
  local action, reason = story:beginMartParcelScene(Story.MAP_VIRIDIAN_MART)
  check("full bag prevents Parcel with no scene writes", action == nil and reason == "parcel_bag_full"
    and session:getVar(Story.VAR_MART_SCENE) == 0 and inventory:quantityOf(Story.ITEM_OAKS_PARCEL) == 0)
end

print(("viridian_parcel_story_test: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
