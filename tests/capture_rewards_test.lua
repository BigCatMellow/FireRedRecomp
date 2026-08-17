-- Party/PC/Dex/Bag routing coverage for a resolved capture. Pure Lua,
-- no ROM needed -- CaptureRules.lua (catch-success math) and
-- WildPokemonFactory.capture()/toPcRecord() (record construction) are
-- covered elsewhere; this file only exercises the container-routing
-- decision layer.
-- Run: lua5.1 tests/capture_rewards_test.lua
package.path = package.path .. ";./?.lua"

local Bag = require("src.core.Bag")
local CaptureRewards = require("src.core.CaptureRewards")
local DexTracker = require("src.core.DexTracker")
local PartyModel = require("src.core.PartyModel")
local PcBoxes = require("src.core.PcBoxes")
local Rng = require("src.core.Rng")
local WildPokemonFactory = require("src.core.WildPokemonFactory")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Same minimal RATTATA fixture wild_pokemon_factory_test.lua uses.
local natures = {}
for i = 0, 24 do natures[i] = { attack=0, defense=0, speed=0, spAttack=0, spDefense=0 } end
local rattata = {
  baseHP=30, baseAttack=56, baseDefense=35, baseSpeed=72,
  baseSpAttack=25, baseSpDefense=35, types={0,0}, catchRate=255,
  genderRatio=127, friendship=70, growthRate=0, abilities={50,62},
}
local learnset = { {level=1, move=33}, {level=1, move=39} }
local battleMoves = { [33]={pp=35}, [39]={pp=30} }
local rattataName = string.char(0xCC,0xBB,0xCE,0xCE,0xBB,0xCE,0xBB,0xFF,0,0)
local redName = string.char(0xCC,0xBF,0xBE,0xFF,0xFF,0xFF,0xFF)
local trainer = { id=0x44332211, name=redName, gender=0 }

local function generateCaught(seed)
  local instance = WildPokemonFactory.generate({
    species=19, level=3, speciesInfo=rattata, learnset=learnset,
    battleMoves=battleMoves, natures=natures, rng=Rng.new(seed),
    speciesName=rattataName, trainer=trainer, metLocation=88,
  })
  return WildPokemonFactory.capture(instance, { ball=4, trainer=trainer })
end

-- Party has room: the caught mon goes straight into the party, no PC
-- container touched (real GiveMonToPlayer prefers the party first).
do
  local party, pc = PartyModel.new(), PcBoxes.new()
  local caught = generateCaught(1)
  local dest, slot = CaptureRewards.giveMonToPlayer(party, pc, 1, caught, battleMoves)
  check("room in party routes there", dest == "party" and slot == 1)
  check("party record is the exact caught table", party:get(1) == caught)
  check("no PC box touched", not pc:get(1, 1))
end

-- Party full: overflows to PC, starting at the given box, with PP
-- restored (real SendMonToPC calls MonRestorePP before boxing).
do
  local party, pc = PartyModel.new(), PcBoxes.new()
  for i = 1, 6 do party:add({ placeholder = i }) end
  local caught = generateCaught(2)
  caught.moves[1].pp = 0 -- simulate PP spent in battle before the catch
  local dest, box, slot = CaptureRewards.giveMonToPlayer(party, pc, 5, caught, battleMoves)
  check("full party overflows to PC", dest == "pc" and box == 5 and slot == 1)
  local BoxPokemonCodec = require("src.core.BoxPokemonCodec")
  local boxed = BoxPokemonCodec.decode(pc:get(5, 1).box)
  check("PC path restores PP", boxed.substructs[1].pp[1] == 35)
end

-- Full party + a full starting box: wraps to the next box with room,
-- matching real SendMonToPC's wraparound search.
do
  local party, pc = PartyModel.new(), PcBoxes.new()
  for i = 1, 6 do party:add({ placeholder = i }) end
  for i = 1, PcBoxes.IN_BOX_COUNT do pc:add(3, { placeholder = i }) end
  local caught = generateCaught(3)
  local dest, box, slot = CaptureRewards.giveMonToPlayer(party, pc, 3, caught, battleMoves)
  check("wraps past a full box to the next one", dest == "pc" and box == 4 and slot == 1)
end

-- Every box full: real MON_CANT_GIVE -- must fail loudly, not invent space.
do
  local party, pc = PartyModel.new(), PcBoxes.new()
  for i = 1, 6 do party:add({ placeholder = i }) end
  for b = 1, PcBoxes.TOTAL_BOXES_COUNT do
    for i = 1, PcBoxes.IN_BOX_COUNT do pc:add(b, { placeholder = i }) end
  end
  local caught = generateCaught(4)
  local dest, reason = CaptureRewards.giveMonToPlayer(party, pc, 1, caught, battleMoves)
  check("no room anywhere reports pc_full, not a fabricated slot", dest == nil and reason == "pc_full")
end

-- Dex marking sets both real independent flags.
do
  local dex = DexTracker.new()
  check("unseen/unowned before capture", not dex:isSeen(19) and not dex:isOwned(19))
  CaptureRewards.markCaught(dex, 19)
  check("capture marks both seen and owned", dex:isSeen(19) and dex:isOwned(19))
  check("unrelated species untouched", not dex:isSeen(20) and not dex:isOwned(20))
end

-- Ball consumption is a thin, real RemoveBagItem(ballItemId, 1) call.
do
  local itemLookup = { [4] = { pocket = Bag.POCKET_POKE_BALLS } } -- ITEM_POKE_BALL
  local bag = Bag.new(itemLookup)
  bag:addItem(4, 3)
  check("consumeBall removes exactly one", CaptureRewards.consumeBall(bag, 4) == true
    and bag:quantityOf(4) == 2)
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
