-- Persistent reward/heal rules for the mandatory Oak-lab battle.  The
-- battle is a normal trainer battle for EXP/EV/prize purposes, followed by
-- the map script's unconditional HealPlayerParty on either outcome.

local BoxPokemonCodec = require("src.core.BoxPokemonCodec")
local ExperienceTable = require("src.core.ExperienceTable")
local PokemonStats = require("src.core.PokemonStats")

local EarlyRivalRewards = {}

EarlyRivalRewards.PRIZE_MONEY = 80 -- 4 * level 5 * multiplier 1 * RivalEarly factor 4
EarlyRivalRewards.MAX_MONEY = 999999
EarlyRivalRewards.ITEM_LUXURY_BALL = 11

local STAT_KEYS = { "hp", "attack", "defense", "speed", "spAttack", "spDefense" }
local EV_FIELDS = {
  hp="hpEV", attack="attackEV", defense="defenseEV",
  speed="speedEV", spAttack="spAttackEV", spDefense="spDefenseEV",
}

local function decode(record)
  local mon = BoxPokemonCodec.decode(assert(record.box, "party record needs BoxPokemon bytes"))
  assert(mon.checksumValid, "party BoxPokemon checksum is invalid")
  return mon
end

local function addEvs(mon, yield)
  local condition = mon.substructs[2]
  local total = 0
  for _, stat in ipairs(STAT_KEYS) do total = total + (condition[EV_FIELDS[stat]] or 0) end
  for _, stat in ipairs(STAT_KEYS) do
    if total >= 510 then break end
    local field = EV_FIELDS[stat]
    local old = condition[field] or 0
    local amount = math.min(yield[stat] or 0, 510 - total, 255 - old)
    condition[field] = old + amount
    total = total + amount
  end
end

local function evTable(mon)
  local c = mon.substructs[2]
  return {
    hp=c.hpEV, attack=c.attackEV, defense=c.defenseEV, speed=c.speedEV,
    spAttack=c.spAttackEV, spDefense=c.spDefenseEV,
  }
end

local function friendshipLevelDelta(friendship)
  if friendship >= 200 then return 2 end
  if friendship >= 100 then return 3 end
  return 5
end

-- Applies the single participating mon's trainer EXP and defeated-mon EVs.
-- The three source learnsets contain no level-6 move; fail if a future data
-- change violates that bounded fact rather than skipping a learn prompt.
function EarlyRivalRewards.applyVictory(record, foe, speciesTable, natures, learnset, currentMapSection)
  local mon = decode(record)
  local ownInfo = assert(speciesTable[mon.substructs[0].species], "player species info missing")
  local foeInfo = assert(speciesTable[foe.species], "foe species info missing")
  local oldLevel, oldMaxHP = record.level, record.maxHP
  local exp = math.floor(foeInfo.expYield * foe.level / 7)
  exp = math.floor(exp * 150 / 100) -- trainer battle bonus

  addEvs(mon, foeInfo.evYield)
  mon.substructs[0].experience = mon.substructs[0].experience + exp
  local newLevel = ExperienceTable.levelForExp(ownInfo.growthRate, mon.substructs[0].experience)
  newLevel = math.min(100, newLevel)

  for _, entry in ipairs(learnset or {}) do
    if entry.level > oldLevel and entry.level <= newLevel then
      error(("Oak-lab reward unexpectedly requires level-up move %d at level %d")
        :format(entry.move, entry.level))
    end
  end

  local stats = PokemonStats.calculateAll(ownInfo, newLevel,
    mon.substructs[3].ivs, evTable(mon),
    assert(natures[mon.personality % 25], "player nature row missing"))
  record.level = newLevel
  record.maxHP = stats.hp
  record.hp = math.min(stats.hp, math.max(0, record.hp + stats.hp - oldMaxHP))
  record.attack, record.defense, record.speed = stats.attack, stats.defense, stats.speed
  record.spAttack, record.spDefense = stats.spAttack, stats.spDefense

  if newLevel > oldLevel then
    local friendship = mon.substructs[0].friendship
    friendship = friendship + friendshipLevelDelta(friendship)
    if mon.substructs[3].pokeball == EarlyRivalRewards.ITEM_LUXURY_BALL then
      friendship = friendship + 1
    end
    if mon.substructs[3].metLocation == currentMapSection then friendship = friendship + 1 end
    mon.substructs[0].friendship = math.min(255, friendship)
  end

  record.box = BoxPokemonCodec.encode(mon)
  record.boxData = mon
  return { exp=exp, oldLevel=oldLevel, newLevel=newLevel }
end

-- AdjustFriendshipOnBattleFaint chooses FAINT_SMALL for this equal-level
-- single battle, whose delta is -1 in all friendship ranges.
function EarlyRivalRewards.applyLoss(record)
  local mon = decode(record)
  mon.substructs[0].friendship = math.max(0, mon.substructs[0].friendship - 1)
  record.box = BoxPokemonCodec.encode(mon)
  record.boxData = mon
end

local function maxPp(base, ppBonuses, slotIndex)
  local ppUps = math.floor(ppBonuses / 4^(slotIndex - 1)) % 4
  return base + math.floor(base * 20 * ppUps / 100)
end

-- HealPlayerParty -> HealParty: clears status, restores HP, and restores
-- each move's PP including its per-slot PP Up bits.
function EarlyRivalRewards.healParty(saveBlock1, movesTable)
  local count = math.max(0, math.min(6, saveBlock1.playerPartyCount or 0))
  for i = 1, count do
    local record = saveBlock1.playerParty[i]
    if record and record.box then
      local mon = decode(record)
      local attacks, bonuses = mon.substructs[1], mon.substructs[0].ppBonuses or 0
      for slot = 1, 4 do
        local moveId = attacks.moves[slot] or 0
        if moveId ~= 0 then
          attacks.pp[slot] = maxPp(assert(movesTable[moveId], "move data missing").pp,
            bonuses, slot)
        else
          attacks.pp[slot] = 0
        end
      end
      record.hp, record.status = record.maxHP, 0
      record.box = BoxPokemonCodec.encode(mon)
      record.boxData = mon
      record.moves = {}
      for slot = 1, 4 do
        local moveId = attacks.moves[slot] or 0
        if moveId ~= 0 then
          record.moves[#record.moves + 1] = {move=moveId, pp=attacks.pp[slot]}
        end
      end
    end
  end
end

function EarlyRivalRewards.addPrizeMoney(saveBlock1)
  saveBlock1.money = math.min(EarlyRivalRewards.MAX_MONEY,
    (saveBlock1.money or 0) + EarlyRivalRewards.PRIZE_MONEY)
end

return EarlyRivalRewards
