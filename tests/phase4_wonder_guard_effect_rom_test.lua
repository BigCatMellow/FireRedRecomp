-- Opt-in source fixture, pret c75f352: abilities.h ability25 name;
-- species_info.h:8096-8129 Shedinja; battle_moves.h named entries below.
-- SHA first; only existing parsers/address interfaces. No private path,
-- ROM bytes, hashes of extracted records or game assets are printed/saved.
package.path = package.path .. ";./?.lua"
local path=os.getenv("POKEPORT_ROM")
if not path or path=="" then
  print("SKIP phase4_wonder_guard_effect_rom_test (set POKEPORT_ROM); non-skipped supported-ROM evidence pending")
  os.exit(0)
end
local Importer=require("import.RomImporter")
assert(Importer.verify(path),"supported-ROM verification failed")
local Addresses=require("import.RomAddresses")
local a=assert(Addresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"])
local f=assert(io.open(path,"rb"),"verified ROM could not be opened")
local rom=f:read("*a");f:close()
local Names=require("import.AbilityNames")
local Charmap=require("import.Charmap")
assert(Charmap.decode(Names.rawNameRecord(rom,a.gAbilityNames,25))=="WONDER GUARD",
  "Wonder Guard ability name mismatch")
local Species=require("import.SpeciesInfo")
local species=Species.parseTable(rom,a.gSpeciesInfo,Addresses.COUNTS.NUM_SPECIES)
local shedinja=species[303] -- include/constants/species.h:312
assert(shedinja.baseHP==1 and shedinja.types[1]==6 and shedinja.types[2]==7
  and shedinja.abilities[1]==25 and shedinja.abilities[2]==0,"Shedinja source record mismatch")
local moves=require("import.BattleMove").parseTable(rom,a.gBattleMoves,Addresses.COUNTS.MOVES_COUNT)
-- id, effect, immutable record power, STATIC type, accuracy. Dynamic power
-- and type must not be written back to these records by engine resolution.
local expected={
  {33,0,35,0,95}, {52,4,40,10,100}, {237,135,1,0,100},
  {311,203,50,0,100}, {205,117,30,5,90}, {301,117,30,15,90},
  {210,119,10,6,95}, {217,122,1,0,90}, {149,88,1,14,80},
  {49,130,1,0,90}, {162,40,1,0,90}, {283,189,1,0,100},
  {90,38,1,4,30}, {167,104,10,1,90}, {153,7,250,0,100},
  {26,45,70,1,95}, {37,27,90,0,100}, {165,48,50,0,100},
}
for _,r in ipairs(expected) do
  local m=moves[r[1]]
  assert(m.effect==r[2] and m.power==r[3] and m.type==r[4] and m.accuracy==r[5],
    "Wonder Guard relevant move source record mismatch")
end
rom=nil
print("phase4_wonder_guard_effect_rom_test: PASS ability name, Shedinja and 18 relevant move records")
