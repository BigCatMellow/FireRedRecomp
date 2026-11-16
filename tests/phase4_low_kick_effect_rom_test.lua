-- Source lock pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788:
-- battle_moves.h:874-885; no weight-table address or numeric provider implied.
package.path = package.path .. ";./?.lua"
local path=os.getenv("POKEPORT_ROM")
if not path or path=="" then
  print("SKIP phase4_low_kick_effect_rom_test (set POKEPORT_ROM); numeric weight provider/native gate unproven")
  os.exit(0)
end
local Importer=require("import.RomImporter")
assert(Importer.verify(path),"supported-ROM verification failed")
-- Verification above precedes record import/access, even opening the ROM.
local Moves=require("import.BattleMove")
local Addresses=require("import.RomAddresses")
local f=assert(io.open(path,"rb"));local bytes=f:read("*a");f:close()
local a=assert(Addresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local moves=Moves.parseTable(bytes,a.gBattleMoves,Addresses.COUNTS.MOVES_COUNT)
local count=0
for id=0,Addresses.COUNTS.MOVES_COUNT-1 do
  if moves[id].effect==196 then
    assert(id==67,"unexpected Low Kick family member");count=count+1
  end
end
assert(count==1,"Low Kick singleton changed")
local m=moves[67]
assert(m.effect==196 and m.power==1 and m.type==1 and m.accuracy==100 and m.pp==20
  and m.secondaryEffectChance==0 and m.target==0 and m.priority==0 and m.flags==0x33,
  "Low Kick source record mismatch")
bytes=nil;moves=nil
print("phase4_low_kick_effect_rom_test: PASS singleton67/source record only; numeric provider/native delivery unproven")
