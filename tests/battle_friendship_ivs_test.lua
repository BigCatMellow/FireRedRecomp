-- H1 source lock: pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788.
-- Player/opponent controllers :1540-1547/:475-482 copy friendship + six IVs
-- at switch-in. pokemon.c:1815 initializes species friendship; battle_main.c
-- :1576-1577/:1588-1589 scales fixed IVs for default/custom trainer parties.
-- Oracles below are known inputs, not values read back from the bridge.
package.path = package.path .. ";./?.lua"
local Bridge = require("src.core.BattlePartyBridge")
local Box = require("src.core.BoxPokemonCodec")
local Save = require("src.core.SaveFileCodec")
local Wild = require("src.core.WildPokemonFactory")
local Starter = require("src.core.StarterPokemonFactory")
local Trainer = require("src.core.TrainerPokemonFactory")

local passed, failed = 0, 0
local function check(name, condition)
  if condition then passed = passed + 1 else
    failed = failed + 1; print("FAIL: " .. name)
  end
end
local fields = {"hp", "attack", "defense", "speed", "spAttack", "spDefense"}
local function checkIvs(name, actual, expected)
  for i, field in ipairs(fields) do check(name .. " " .. field, actual and actual[field] == expected[i]) end
end
local function sequence(values)
  return {draws=0, next16=function(self)
    self.draws = self.draws + 1
    return assert(values[self.draws], "unexpected RNG draw")
  end}
end
local info = {
  baseHP=30, baseAttack=56, baseDefense=35, baseSpeed=72,
  baseSpAttack=25, baseSpDefense=35, types={0,0}, catchRate=255,
  genderRatio=127, friendship=70, growthRate=0, abilities={50,62},
}
local natures = {}
for i=0,24 do natures[i]={attack=0,defense=0,speed=0,spAttack=0,spDefense=0} end
local function args(rng)
  return {species=19, level=5, speciesInfo=info, speciesName=string.rep(string.char(0xBB),10),
    trainer={id=0x12345678,name=string.rep(string.char(0xBB),7),gender=0},
    learnset={{level=1,move=33}}, battleMoves={[33]={pp=35}},
    natures=natures, metLocation=88, rng=rng}
end

-- Nature/personality zero then the two five-bit IV words: 1,2,3 / 4,5,6.
local wildRng = sequence({0,0,0,3137,6308})
local wild = Wild.generate(args(wildRng))
check("wild generation preserves five source draws", wildRng.draws == 5)
local foe = Bridge.battlerFromGenerated(wild)
local temporaryPlayer = Bridge.battlerFromGenerated(wild) -- main's debug-party path
check("wild and temporary player use box friendship", foe.friendship == 70 and temporaryPlayer.friendship == 70)
checkIvs("wild snapshot", foe.ivs, {1,2,3,4,5,6})
checkIvs("temporary player snapshot", temporaryPlayer.ivs, {1,2,3,4,5,6})
check("generated snapshots do not alias either IV owner", foe.ivs ~= wild.ivs
  and foe.ivs ~= wild.boxData.substructs[3].ivs and temporaryPlayer.ivs ~= foe.ivs)
foe.ivs.hp=31; foe.friendship=255
check("battler mutation preserves wild inputs and other snapshot", wild.ivs.hp == 1
  and wild.boxData.substructs[3].ivs.hp == 1 and wild.boxData.substructs[0].friendship == 70
  and temporaryPlayer.ivs.hp == 1 and temporaryPlayer.friendship == 70)
wild.ivs.attack=30; wild.boxData.substructs[0].friendship=99
check("wild mutation preserves existing snapshot", foe.ivs.attack == 2 and temporaryPlayer.friendship == 70)
local incoming = Bridge.battlerFromGenerated(wild)
check("generated switch-in takes fresh input", incoming.ivs.attack == 30 and incoming.friendship == 99)
check("bridge construction consumes no RNG", wildRng.draws == 5)

-- Ownership rule: a boxed wild/temporary mon owns friendship in boxData.
wild.friendship=255
check("boxData owner wins over stale top-level friendship", Bridge.battlerFromGenerated(wild).friendship == 99)
wild.boxData.substructs[0].friendship=0
check("boxData friendship zero is retained", Bridge.battlerFromGenerated(wild).friendship == 0)

local starterRng = sequence({0,0,3137,6308})
local record = Starter.generate(args(starterRng))
check("starter generation preserves four source draws", starterRng.draws == 4)
-- Deliberately stale convenience metadata must not replace encrypted data.
record.boxData.substructs[0].friendship=255
record.ivs.hp=31
local player, decoded = Bridge.battlerFromParty(record, {[19]=info})
check("party friendship comes from encrypted substruct0", player.friendship == 70)
checkIvs("party all six authoritative IVs", player.ivs, {1,2,3,4,5,6})
check("party snapshot does not alias decoded or cached IVs", player.ivs ~= decoded.substructs[3].ivs
  and player.ivs ~= record.boxData.substructs[3].ivs and player.ivs ~= record.ivs)
decoded.substructs[3].ivs.attack=31; decoded.substructs[0].friendship=1
check("returned decoded metadata cannot change party snapshot", player.ivs.attack == 2 and player.friendship == 70)
player.ivs.defense=31; player.friendship=0
local untouched = Box.decode(record.box)
check("party snapshot mutation cannot change encrypted data", untouched.substructs[3].ivs.defense == 3
  and untouched.substructs[0].friendship == 70)

-- Simulate an authoritative party update; source copies again at switch-in.
-- No claim of in-battle EXP support: runtime rewards are post-battle today.
untouched.substructs[0].friendship=120
untouched.substructs[3].ivs.speed=20
record.box=Box.encode(untouched)
local replacement = Bridge.battlerFromParty(record, {[19]=info})
check("replacement reads fresh party friendship and IVs", replacement.friendship == 120 and replacement.ivs.speed == 20)
check("authoritative party update leaves active snapshot alone", player.friendship == 0 and player.ivs.speed == 4)
replacement.friendship=255; replacement.ivs.hp=31
replacement.hp=4; replacement.moves[1].pp=20
Bridge.persistPartyBattler(record, replacement)
local persisted = Box.decode(record.box)
check("persist updates HP PP and leaves friendship authoritative", record.hp == 4
  and persisted.substructs[1].pp[1] == 20 and persisted.substructs[0].friendship == 120)
checkIvs("persist leaves six authoritative IVs", persisted.substructs[3].ivs, {1,2,3,20,5,6})
check("encrypted record checksum survives persistence", persisted.checksumValid)
local bytes = Save.encodeSaveBlock1({playerPartyCount=1,playerParty={record}},0)
local roundtrip = Save.decodeSaveBlock1(bytes,0).playerParty[1]
local saved = Box.decode(roundtrip.box)
check("save roundtrip preserves encrypted record and checksum", roundtrip.box == record.box and saved.checksumValid
  and saved.substructs[0].friendship == 120 and roundtrip.hp == 4)
checkIvs("save roundtrip IVs", saved.substructs[3].ivs, {1,2,3,20,5,6})
check("party snapshot and persistence consume no RNG", starterRng.draws == 4)

for _,flags in ipairs({0,1}) do
  local trainerRng=sequence({0,0}) -- non-shiny OT id zero for fixed personality
  local options=args(trainerRng)
  local baseFriendship=flags == 0 and 35 or 0
  options.speciesInfo={}
  for key,value in pairs(info) do options.speciesInfo[key]=value end
  options.speciesInfo.friendship=baseFriendship
  options.trainer={partyFlags=flags,rawName=string.char(0xBB,0xFF),doubleBattle=false}
  options.partyMon={species=19,lvl=5,iv=100}
  if flags == 1 then options.partyMon.moves={[0]=33,[1]=0,[2]=0,[3]=0} end
  local instance=Trainer.generate(options)
  local active=Bridge.battlerFromGenerated(instance)
  local label="trainer layout " .. flags
  check(label .. " exposes base friendship without boxData", instance.friendship == baseFriendship and instance.boxData == nil)
  check(label .. " snapshot friendship", active.friendship == baseFriendship)
  -- floor(100 * 31 / 255) = 12 for every stat, both supported layouts.
  checkIvs(label .. " fixed IVs", active.ivs, {12,12,12,12,12,12})
  check(label .. " independent IV table", active.ivs ~= instance.ivs)
  active.ivs.hp=0; active.friendship=0
  check(label .. " battler mutation preserves instance", instance.ivs.hp == 12 and instance.friendship == baseFriendship)
  active.friendship=11
  instance.ivs.attack=31; instance.friendship=0
  check(label .. " instance mutation preserves battler", active.ivs.attack == 12 and active.friendship == 11)
  local fresh=Bridge.battlerFromGenerated(instance)
  check(label .. " fresh snapshot retains top-level zero", fresh.friendship == 0 and fresh.ivs.attack == 31)
  check(label .. " preserves two OT-id RNG draws", trainerRng.draws == 2)
end

-- Explicit synthetic compatibility: missing optional data stays absent,
-- including partial boxed metadata; no species/default/empty-IV fallback.
local synthetic={species=19,level=5,types={0,0},stats={hp=10,attack=5,defense=5,speed=5,spAttack=5,spDefense=5},moves={}}
local bare=Bridge.battlerFromGenerated(synthetic)
check("synthetic absent inputs remain absent", bare.friendship == nil and bare.ivs == nil and synthetic.boxData == nil)
synthetic.friendship=0
check("synthetic friendship alone retains absent IVs", Bridge.battlerFromGenerated(synthetic).friendship == 0
  and Bridge.battlerFromGenerated(synthetic).ivs == nil)
synthetic.boxData={}
check("present boxed owner never falls back to top-level", Bridge.battlerFromGenerated(synthetic).friendship == nil)
synthetic.boxData={substructs={[0]={}}}
check("missing boxed friendship remains absent", Bridge.battlerFromGenerated(synthetic).friendship == nil)
synthetic.boxData=nil; synthetic.friendship=nil
synthetic.ivs={hp=0,attack=0,defense=0,speed=0,spAttack=0,spDefense=0}
local ivOnly=Bridge.battlerFromGenerated(synthetic)
check("synthetic IVs alone retain absent friendship", ivOnly.friendship == nil)
checkIvs("synthetic zero IVs remain exact", ivOnly.ivs, {0,0,0,0,0,0})

print(("battle_friendship_ivs_test: %d passed, %d failed"):format(passed,failed))
os.exit(failed == 0 and 0 or 1)
