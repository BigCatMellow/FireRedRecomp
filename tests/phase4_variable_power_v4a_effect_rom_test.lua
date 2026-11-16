-- V4a source assertions at pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788.
-- Runtime bytes stay in memory. SHA verification precedes parsing/access.
package.path = package.path .. ";./?.lua"
local path = os.getenv("POKEPORT_ROM")
if not path or path=="" then
  print("SKIP phase4_variable_power_v4a_effect_rom_test (set POKEPORT_ROM); F4 trainer merge gate unproven")
  os.exit(0)
end
local RomImporter = require("import.RomImporter")
assert(RomImporter.verify(path),"supported-ROM verification failed")
local BattleMove = require("import.BattleMove")
local Trainer = require("import.Trainer")
local TrainerParty = require("import.TrainerParty")
local Addresses = require("import.RomAddresses")
local f = assert(io.open(path,"rb"),"verified ROM could not be opened")
local rom=f:read("*a"); f:close()
local a=assert(Addresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves=BattleMove.parseTable(rom,a.gBattleMoves,Addresses.COUNTS.MOVES_COUNT)
local families = {[121]=216,[123]=218,[135]=237}
local counts = {[121]=0,[123]=0,[135]=0}
for id=0,Addresses.COUNTS.MOVES_COUNT-1 do
  local effect=moves[id].effect
  if families[effect] then
    assert(id==families[effect],"unexpected V4a family member")
    counts[effect]=counts[effect]+1
  end
end
-- battle_moves.h:2811-2822 Return, :2837-2848 Frustration,
-- :3084-3095 Hidden Power. Only HP is non-contact (flags0x32 vs0x33).
for effect,id in pairs(families) do
  assert(counts[effect]==1,"V4a family membership count changed")
  local m=moves[id]
  assert(m.effect==effect and m.power==1 and m.type==0 and m.accuracy==100
    and m.pp==(id==237 and 15 or 20) and m.secondaryEffectChance==0
    and m.target==0 and m.priority==0 and m.flags==(id==237 and 0x32 or 0x33),
    "V4a source record mismatch")
end
-- F4 stronger scope: ALL trainer records with custom moves, including both
-- held-item and no-item layouts, all party sizes, AI tiers and maps. Pinned
-- src/data/trainer_parties.h has zero MOVE_RETURN/MOVE_FRUSTRATION/
-- MOVE_HIDDEN_POWER references. This superset subsumes currently playable
-- custom trainers: main.lua:1501-1531 accepts only partyFlags0/1, sizes1/2,
-- ordinary singles; the Oak rival's flags0 have no custom moves (:1389-1394).
-- No guessed map frontier or trainer roster. A non-skipped pass is required
-- before merge; the no-ROM skip above proves nothing about this gate.
local trainers=Trainer.parseTable(rom,a.gTrainers,Addresses.COUNTS.NUM_TRAINERS)
local customParties, customMons=0,0
local forbidden={[216]=true,[218]=true,[237]=true}
for id=0,Addresses.COUNTS.NUM_TRAINERS-1 do
  local trainer=trainers[id]
  if trainer.partyFlags%2==1 then
    customParties=customParties+1
    local party=TrainerParty.resolve(trainer,rom)
    for slot=0,trainer.partySize-1 do
      customMons=customMons+1
      for moveSlot=0,3 do
        assert(not forbidden[party[slot].moves[moveSlot]],
          "F4 merge blocked: custom trainer carries V4a move; wait for H1")
      end
    end
  end
end
assert(customParties>0 and customMons>0,"F4 custom-trainer scan must be nonempty")
rom=nil
print("phase4_variable_power_v4a_effect_rom_test: PASS three exact source families; F4 all-custom-trainer scan passed")
