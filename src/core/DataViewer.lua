-- Read-only browser over the imported data model -- the Phase 1 exit
-- criterion (roadmap: "a read-only data viewer capable of displaying every
-- map, species, move, and trainer record"). Pure text description logic,
-- no love.* calls, so it's testable under plain lua5.1; main.lua just
-- prints whatever lines this returns and wires up keyboard navigation.

local SpeciesInfo = require("import.SpeciesInfo")
local BattleMove = require("import.BattleMove")
local Trainer = require("import.Trainer")
local TrainerParty = require("import.TrainerParty")
local MapHeader = require("import.MapHeader")
local MapLayout = require("import.MapLayout")
local Charmap = require("import.Charmap")
local RomAddresses = require("import.RomAddresses")

local DataViewer = {}

DataViewer.CATEGORIES = { "species", "moves", "trainers", "maps" }

local function nameOrUnknown(data, tableOffset, stride, index, label)
  local ok, name = pcall(Charmap.decodeAt, data, tableOffset, stride, index)
  return ok and name or ("(" .. label .. " name unavailable)")
end

function DataViewer.describeSpecies(data, addrs, index)
  if index < 1 or index >= RomAddresses.COUNTS.NUM_SPECIES then
    return { ("Species index %d out of range (1-%d)"):format(index, RomAddresses.COUNTS.NUM_SPECIES - 1) }
  end
  local name = nameOrUnknown(data, addrs.gSpeciesNames, 11, index, "species")
  local s = SpeciesInfo.parseTable(data, addrs.gSpeciesInfo, index + 1)[index]
  local type1 = nameOrUnknown(data, addrs.gTypeNames, 7, s.types[1], "type")
  local type2 = s.types[1] ~= s.types[2] and nameOrUnknown(data, addrs.gTypeNames, 7, s.types[2], "type") or nil

  local lines = {
    ("SPECIES #%d: %s"):format(index, name),
    ("  Type: %s%s"):format(type1, type2 and ("/" .. type2) or ""),
    ("  HP %d  Atk %d  Def %d  Speed %d  SpAtk %d  SpDef %d"):format(
      s.baseHP, s.baseAttack, s.baseDefense, s.baseSpeed, s.baseSpAttack, s.baseSpDefense),
    ("  Catch rate %d  Exp yield %d  Gender ratio %d"):format(s.catchRate, s.expYield, s.genderRatio),
    ("  Abilities: %d, %d"):format(s.abilities[1], s.abilities[2]),
  }
  return lines
end

function DataViewer.describeMove(data, addrs, index)
  if index < 1 or index >= RomAddresses.COUNTS.MOVES_COUNT then
    return { ("Move index %d out of range (1-%d)"):format(index, RomAddresses.COUNTS.MOVES_COUNT - 1) }
  end
  local name = nameOrUnknown(data, addrs.gMoveNames, 13, index, "move")
  local m = BattleMove.parseTable(data, addrs.gBattleMoves, index + 1)[index]
  local typeName = nameOrUnknown(data, addrs.gTypeNames, 7, m.type, "type")

  return {
    ("MOVE #%d: %s"):format(index, name),
    ("  Type: %s  Power: %d  Accuracy: %d  PP: %d"):format(typeName, m.power, m.accuracy, m.pp),
    ("  Effect: %d  Priority: %d  Target: %d  Flags: 0x%02X"):format(m.effect, m.priority, m.target, m.flags),
  }
end

function DataViewer.describeTrainer(data, addrs, index)
  if index < 0 or index >= RomAddresses.COUNTS.NUM_TRAINERS then
    return { ("Trainer index %d out of range (0-%d)"):format(index, RomAddresses.COUNTS.NUM_TRAINERS - 1) }
  end
  local t = Trainer.parseTable(data, addrs.gTrainers, index + 1)[index]
  local name = Charmap.decode(t.rawName)
  local lines = {
    ("TRAINER #%d: %s"):format(index, name == "" and "(no name)" or name),
    ("  Class: %d  Double battle: %s  AI flags: 0x%X"):format(t.trainerClass, tostring(t.doubleBattle), t.aiFlags),
    ("  Party size: %d"):format(t.partySize),
  }
  if t.partySize > 0 and t.partySize < 20 then
    local ok, party = pcall(TrainerParty.resolve, t, data)
    if ok then
      for i = 0, t.partySize - 1 do
        local mon = party[i]
        local monName = nameOrUnknown(data, addrs.gSpeciesNames, 11, mon.species, "species")
        lines[#lines + 1] = ("    - %s Lv.%d"):format(monName, mon.lvl)
      end
    end
  end
  return lines
end

-- mapId: packed group*256+num (matching MAP_* constants elsewhere in this
-- project).
function DataViewer.describeMap(data, addrs, mapId)
  local group, num = math.floor(mapId / 256), mapId % 256
  local ok, header = pcall(MapHeader.resolve, data, addrs.gMapGroups, mapId)
  if not ok then
    return { ("MAP group %d num %d: could not resolve (%s)"):format(group, num, tostring(header)) }
  end
  local layoutOk, layout = pcall(MapLayout.resolve, data, header.mapLayoutPtr)
  local lines = {
    ("MAP group %d num %d"):format(group, num),
    ("  mapLayoutId: %d  music: %d  regionMapSectionId: %d"):format(header.mapLayoutId, header.music, header.regionMapSectionId),
    ("  mapType: %d  battleType: %d  biking: %s  running: %s"):format(
      header.mapType, header.battleType, tostring(header.bikingAllowed), tostring(header.allowRunning)),
  }
  if layoutOk then
    lines[#lines + 1] = ("  Layout: %dx%d metatiles, border %dx%d"):format(layout.width, layout.height, layout.borderWidth, layout.borderHeight)
  end
  return lines
end

-- category: one of DataViewer.CATEGORIES. index: record index (species/move/
-- trainer index, or a packed mapId for "maps"). Returns a list of lines.
function DataViewer.describe(data, addrs, category, index)
  if category == "species" then return DataViewer.describeSpecies(data, addrs, index)
  elseif category == "moves" then return DataViewer.describeMove(data, addrs, index)
  elseif category == "trainers" then return DataViewer.describeTrainer(data, addrs, index)
  elseif category == "maps" then return DataViewer.describeMap(data, addrs, index)
  else return { "Unknown category: " .. tostring(category) }
  end
end

return DataViewer
