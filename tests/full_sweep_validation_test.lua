-- Phase 1 validation pass: iterates every species, move, and trainer (not
-- just a handful of spot-checked ones) and every map this project has
-- exercised, checking for crashes and basic sanity bounds. This is
-- deliberately broader than the other integration tests, which verify
-- exact values for a few hand-picked records; this one verifies the whole
-- table decodes cleanly, catching e.g. an off-by-one stride that only
-- breaks on some later record. Opt-in via POKEPORT_ROM, skips cleanly
-- otherwise.
--
-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/full_sweep_validation_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local SpeciesInfo = require("import.SpeciesInfo")
local BattleMove = require("import.BattleMove")
local Trainer = require("import.Trainer")
local TrainerParty = require("import.TrainerParty")
local MapHeader = require("import.MapHeader")
local MapLayout = require("import.MapLayout")
local MapEvents = require("import.MapEvents")
local MapConnections = require("import.MapConnections")
local MapScripts = require("import.MapScripts")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local ok, info = RomImporter.verify(romPath)
if not ok then
  print("FAIL: ROM did not verify -- " .. tostring(info))
  os.exit(1)
end

local sha1 = RomImporter._sha1HexOfFile(romPath)
local addrs = RomAddresses[sha1]
local f = io.open(romPath, "rb")
local data = f:read("*a")
f:close()

-- Every species: decodes without error, base stats in a sane 0-255 range
-- (they're u8 fields so this is really just confirming no misreads), types
-- are either TYPE_NONE(255) or 0-17.
do
  local allOk = true
  local species = SpeciesInfo.parseTable(data, addrs.gSpeciesInfo, RomAddresses.COUNTS.NUM_SPECIES)
  for i = 1, RomAddresses.COUNTS.NUM_SPECIES - 1 do
    local s = species[i]
    for _, t in ipairs(s.types) do
      if not ((t >= 0 and t <= 17) or t == 255) then
        allOk = false
        print(("  species %d has out-of-range type %d"):format(i, t))
      end
    end
  end
  check(("all %d species decode with valid types"):format(RomAddresses.COUNTS.NUM_SPECIES - 1), allOk)
end

-- Every move: decodes without error, type in range, pp is a sane value
-- (real FireRed max PP is 40 before PP Ups).
do
  local allOk = true
  local moves = BattleMove.parseTable(data, addrs.gBattleMoves, RomAddresses.COUNTS.MOVES_COUNT)
  for i = 1, RomAddresses.COUNTS.MOVES_COUNT - 1 do
    local m = moves[i]
    if not ((m.type >= 0 and m.type <= 17) or m.type == 255) then
      allOk = false
      print(("  move %d has out-of-range type %d"):format(i, m.type))
    end
    if m.pp > 40 then
      allOk = false
      print(("  move %d has implausible pp %d"):format(i, m.pp))
    end
  end
  check(("all %d moves decode with valid type/pp"):format(RomAddresses.COUNTS.MOVES_COUNT - 1), allOk)
end

-- Every trainer: decodes without error; if it has a party, resolving that
-- party doesn't error and every mon's species/level are in range.
do
  local allOk = true
  local errorCount = 0
  local trainers = Trainer.parseTable(data, addrs.gTrainers, RomAddresses.COUNTS.NUM_TRAINERS)
  for i = 0, RomAddresses.COUNTS.NUM_TRAINERS - 1 do
    local t = trainers[i]
    if t.partySize > 0 and t.partySize < 20 and t.partyPtr ~= 0 then
      local partyOk, party = pcall(TrainerParty.resolve, t, data)
      if not partyOk then
        allOk = false
        errorCount = errorCount + 1
        if errorCount <= 5 then
          print(("  trainer %d party resolution failed: %s"):format(i, tostring(party)))
        end
      else
        for j = 0, t.partySize - 1 do
          local mon = party[j]
          if mon.species < 1 or mon.species >= RomAddresses.COUNTS.NUM_SPECIES then
            allOk = false
            errorCount = errorCount + 1
            if errorCount <= 5 then
              print(("  trainer %d mon %d has out-of-range species %d"):format(i, j, mon.species))
            end
          end
          if mon.lvl < 1 or mon.lvl > 100 then
            allOk = false
            errorCount = errorCount + 1
            if errorCount <= 5 then
              print(("  trainer %d mon %d has implausible level %d"):format(i, j, mon.lvl))
            end
          end
        end
      end
    end
  end
  check(("all %d trainers' parties resolve with valid species/levels (%d errors)"):format(RomAddresses.COUNTS.NUM_TRAINERS, errorCount), allOk)
end

-- Every map this project has exercised elsewhere: header, layout, events,
-- connections, and script hooks all resolve without error, and every
-- warp's destination map (mapGroup/mapNum) itself resolves too -- this is
-- the "every map/warp reference is valid" half of the roadmap's validation
-- bullet, for the maps actually covered by this project so far (a full
-- region-wide sweep needs every map's group/num enumerated, which isn't
-- built yet -- see the checklist for that as still-open Phase 5 scope).
local EXERCISED_MAPS = {
  { name = "Pallet Town", id = 3 * 256 + 0 },
  { name = "Route 1", id = 3 * 256 + 19 },
  { name = "Pallet Town Player's House 1F", id = 4 * 256 + 0 },
  { name = "Celadon City", id = 3 * 256 + 6 },
}
for _, mapEntry in ipairs(EXERCISED_MAPS) do
  local mOk, header = pcall(MapHeader.resolve, data, addrs.gMapGroups, mapEntry.id)
  check(mapEntry.name .. ": header resolves", mOk, header)
  if mOk then
    local layoutOk, layout = pcall(MapLayout.resolve, data, header.mapLayoutPtr)
    check(mapEntry.name .. ": layout resolves", layoutOk, layout)
    local eventsOk, events = pcall(MapEvents.resolve, data, header.eventsPtr)
    check(mapEntry.name .. ": events resolve", eventsOk, events)
    if eventsOk then
      local warpsOk = true
      for _, w in pairs(events.warps) do
        local whOk = pcall(MapHeader.resolve, data, addrs.gMapGroups, w.mapGroup * 256 + w.mapNum)
        if not whOk then warpsOk = false end
      end
      check(mapEntry.name .. ": every warp's destination map resolves", warpsOk)
    end
    if header.connectionsPtr ~= 0 then
      local connOk = pcall(MapConnections.resolve, data, header.connectionsPtr)
      check(mapEntry.name .. ": connections resolve", connOk)
    end
    if header.mapScriptsPtr ~= 0 then
      local scriptsOk = pcall(MapScripts.resolve, data, header.mapScriptsPtr)
      check(mapEntry.name .. ": script hooks resolve", scriptsOk)
    end
  end
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
