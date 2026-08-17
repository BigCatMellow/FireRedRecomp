-- Pure bridge between save-compatible party records / generated wild
-- instances and BattleEngine's transient battler tables.
--
-- A party record is the exact 100-byte struct Pokemon shape used by
-- SaveFileCodec: an encrypted 80-byte `box` plus cached status/level/HP/
-- stats. Moves and PP remain authoritative inside BoxPokemon's attack
-- substruct. The bridge decodes that data when battle starts and writes
-- current HP/PP back after each resolved turn. It never creates a party
-- member or chooses a starter; an empty or all-fainted party has no lead.
--
-- Voluntary in-battle switching (BattleEngine's "switch" action) is also
-- bridged here: findSwitchTargets finds eligible replacement party slots,
-- and battlerFromParty (already fully generic -- it never assumed "the
-- lead") builds the incoming battler exactly the same way it builds the
-- initial one. Real Cmd_switchindataupdate (src/battle_script_commands.c)
-- confirms an ordinary switch-in battler is built completely fresh from
-- party data with neutral stat stages; only EFFECT_BATON_PASS (not
-- implemented anywhere in this project) copies statStages/status2 forward
-- from the outgoing battler as a special case. BattleEngine.makeBattler
-- already defaults every stat stage to the real neutral value, so no extra
-- reset step is needed here.

local BattleEngine = require("src.core.BattleEngine")
local BoxPokemonCodec = require("src.core.BoxPokemonCodec")

local BattlePartyBridge = {}

local function decodeRecord(record)
  if type(record) ~= "table" or type(record.box) ~= "string"
      or #record.box ~= BoxPokemonCodec.BOX_POKEMON_SIZE then
    return nil, "party slot has no complete BoxPokemon record"
  end
  local ok, decoded = pcall(BoxPokemonCodec.decode, record.box)
  if not ok then return nil, "party BoxPokemon could not be decoded" end
  if not decoded.checksumValid then return nil, "party BoxPokemon checksum is invalid" end
  return decoded
end

-- Returns the first living, non-Egg party member, matching the lead that a
-- wild battle can actually send out. This is only the INITIAL lead; a
-- mid-battle voluntary switch (BattleEngine's "switch" action) uses
-- findSwitchTargets below to find an eligible replacement instead. The
-- caller still owns whiteout, and the forced switch-after-faint prompt real
-- FireRed shows is out of scope for this bounded 1v1 bridge (a faint ends
-- the battle here).
function BattlePartyBridge.findUsableLead(saveBlock1)
  if type(saveBlock1) ~= "table" then return nil, nil, "no session save state" end
  local party = saveBlock1.playerParty or {}
  local count = math.max(0, math.min(6, tonumber(saveBlock1.playerPartyCount) or 0))
  if count == 0 then return nil, nil, "player party is empty" end

  local invalidReason
  for slot = 1, count do
    local record = party[slot]
    local decoded, reason = decodeRecord(record)
    if decoded then
      local species = decoded.substructs[0].species
      local isEgg = decoded.isEgg or decoded.isBadEgg or decoded.substructs[3].isEgg
      if species ~= 0 and not isEgg and (record.hp or 0) > 0 then
        return record, slot, nil, decoded
      end
    else
      invalidReason = invalidReason or reason
    end
  end
  return nil, nil, invalidReason or "player party has no conscious non-Egg Pokemon"
end

-- Returns every OTHER living, non-Egg party slot -- the real eligibility
-- test a voluntary in-battle switch uses (Cmd_jumpifcantswitch,
-- src/battle_script_commands.c): `MON_DATA_SPECIES != SPECIES_NONE`,
-- `!MON_DATA_IS_EGG`, `MON_DATA_HP != 0`, and
-- `gBattlerPartyIndexes[gActiveBattler] != i` (i.e. not the slot already on
-- the field). This bridge only needs that same eligibility filter, not the
-- full jumpifcantswitch (that real command also gates on
-- STATUS2_WRAPPED/STATUS2_ESCAPE_PREVENTION/STATUS3_ROOTED trapping and
-- multi-battle flank rules, none of which exist in this bounded 1v1 engine).
-- `excludeSlot` is the 1-based party slot currently on the field (from
-- whichever call found the active battler, e.g. findUsableLead's own
-- returned slot). Returns an ordered list of {slot=, record=}; an empty
-- list (not nil) when no other party member currently qualifies -- the
-- caller decides whether "no valid switch target" is even offered as a UI
-- option.
function BattlePartyBridge.findSwitchTargets(saveBlock1, excludeSlot)
  if type(saveBlock1) ~= "table" then return {}, "no session save state" end
  local party = saveBlock1.playerParty or {}
  local count = math.max(0, math.min(6, tonumber(saveBlock1.playerPartyCount) or 0))
  local targets = {}
  for slot = 1, count do
    if slot ~= excludeSlot then
      local record = party[slot]
      local decoded = decodeRecord(record)
      if decoded then
        local species = decoded.substructs[0].species
        local isEgg = decoded.isEgg or decoded.isBadEgg or decoded.substructs[3].isEgg
        if species ~= 0 and not isEgg and (record.hp or 0) > 0 then
          targets[#targets + 1] = { slot = slot, record = record }
        end
      end
    end
  end
  return targets
end

local function moveSlotsFromBox(decoded)
  local attacks = decoded.substructs[1]
  local out = {}
  for i = 1, 4 do
    local move = attacks.moves[i] or 0
    if move ~= 0 then out[#out + 1] = { move=move, pp=attacks.pp[i] or 0 } end
  end
  return out
end

local function assertCachedStat(record, field)
  local value = record[field]
  assert(type(value) == "number", "party record is missing cached " .. field)
  return value
end

-- Builds a battler from the save record's authoritative cached stats,
-- current HP, and encrypted moves/PP. Returns battler, decoded BoxPokemon.
function BattlePartyBridge.battlerFromParty(record, speciesTable)
  local decoded, reason = decodeRecord(record)
  assert(decoded, reason)
  local species = decoded.substructs[0].species
  local speciesInfo = assert(speciesTable[species],
    ("missing gSpeciesInfo entry %d"):format(species))
  local stats = {
    hp=assertCachedStat(record, "maxHP"),
    attack=assertCachedStat(record, "attack"),
    defense=assertCachedStat(record, "defense"),
    speed=assertCachedStat(record, "speed"),
    spAttack=assertCachedStat(record, "spAttack"),
    spDefense=assertCachedStat(record, "spDefense"),
  }
  local battler = BattleEngine.makeBattler({
    species=species,
    level=assertCachedStat(record, "level"),
    stats=stats,
    hp=assertCachedStat(record, "hp"),
    types=speciesInfo.types,
    moves=moveSlotsFromBox(decoded),
  })
  battler.personality = decoded.personality
  battler.nature = decoded.personality % 25
  battler.abilityNum = decoded.substructs[3].abilityNum
  battler.ability = (speciesInfo.abilities or {})[battler.abilityNum + 1] or 0
  battler.status = record.status or 0
  return battler, decoded
end

-- Generated foes and explicit developer-only temporary party members
-- already carry their calculated stats and legal move list.
function BattlePartyBridge.battlerFromGenerated(instance)
  assert(instance and instance.stats and instance.moves, "generated Pokemon instance is required")
  local battler = BattleEngine.makeBattler({
    species=instance.species,
    catchRate=instance.catchRate,
    level=instance.level,
    stats=instance.stats,
    hp=instance.hp,
    types=instance.types,
    moves=instance.moves,
  })
  battler.personality = instance.personality
  battler.nature = instance.nature
  battler.gender = instance.gender
  battler.abilityNum = instance.abilityNum
  battler.ability = instance.ability
  battler.status = instance.status or 0
  return battler
end

-- Synchronizes the only state the current direct-damage battle mutates:
-- current HP and move PP. Re-encoding updates the real BoxPokemon checksum
-- and encryption; SaveFileCodec can then serialize the same record as-is.
function BattlePartyBridge.persistPartyBattler(record, battler)
  local decoded, reason = decodeRecord(record)
  assert(decoded, reason)
  local attacks = decoded.substructs[1]
  for i, slot in ipairs(battler.moves) do
    assert(attacks.moves[i] == slot.move,
      ("battle move slot %d no longer matches party record"):format(i))
    attacks.pp[i] = math.max(0, math.floor(slot.pp or 0))
  end
  record.hp = math.max(0, math.min(record.maxHP, math.floor(battler.hp or 0)))
  record.status = battler.status or record.status or 0
  record.box = BoxPokemonCodec.encode(decoded)
  record.boxData = decoded
  record.moves = moveSlotsFromBox(decoded)
  return record
end

function BattlePartyBridge.decodeRecord(record)
  return decodeRecord(record)
end

return BattlePartyBridge
