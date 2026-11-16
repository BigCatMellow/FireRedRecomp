-- No-ROM, independent source-derived oracles for the unattached helper.
-- pret/pokefirered c75f352304d529f6ba92d4f74b9cf8b5c3810788:
-- battle_ai_script_commands.c:262-286,481-485,1138-1195;
-- include/constants/abilities.h:27,46,75. Synthetic IDs below are literals,
-- not values read back from implementation constants or returned guesses.
package.path = package.path .. ";./?.lua"
local History = require("src.core.TrainerAbilityHistory")
local passed = 0
local function equal(name, actual, expected)
  assert(actual == expected, name .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  passed = passed + 1
end
local function rejects(name, action, message)
  local ok, err = pcall(action)
  assert(not ok and tostring(err):find(message, 1, true), name .. ": " .. tostring(err))
  passed = passed + 1
end
local function fixture(values)
  local species = {
    [100] = { abilities = { 11, 22 } },
    [200] = { abilities = { 44, 55 } },
    [300] = { abilities = { 11, 0 } },
    [400] = { abilities = { 0, 22 } },
    [500] = { abilities = { 0, 0 } },
    [600] = { abilities = { 11, 11 } },
  }
  local lookupCount, lastSpecies = 0, nil
  local history = History.new(function(id)
    lookupCount, lastSpecies = lookupCount + 1, id
    return species[id]
  end)
  local rng = { count = 0 }
  function rng:next16()
    self.count = self.count + 1
    assert(values and values[self.count] ~= nil, "unexpected RNG draw")
    return values[self.count]
  end
  return history, rng, function(expectedCount, expectedSpecies)
    equal("exact lookup count", lookupCount, expectedCount)
    equal("current species lookup", lastSpecies, expectedSpecies)
  end, species
end

-- Reader :1168-1187: guesses independently alternate with source parity;
-- actual ability is neither a fallback nor cached knowledge. Even zero and
-- maximum u16 draws have independently specified expected answers.
do
  local h, rng, lookups, species = fixture({ 3, 4, 0, 65535, 2 })
  equal("fresh odd guess", h:query(0, 100, 99, rng), 11)
  equal("next even guess", h:query(0, 100, 11, rng), 22)
  equal("replacement species, zero draw", h:query(0, 200, 99, rng), 55)
  equal("old species again, maximum odd draw", h:query(0, 100, 22, rng), 11)
  equal("equal nonzero slots still draw", h:query(0, 600, 99, rng), 11)
  equal("one draw per two-candidate query", rng.count, 5)
  lookups(5, 600)
  equal("first species record preserved", species[100].abilities[1], 11)
  equal("second species record preserved", species[100].abilities[2], 22)
end

-- Writer :481-485 and reader :1151-1166: side ownership, zero writes,
-- history before trapping ability before species, including stale history.
do
  local h, rng, lookups = fixture({ 4 })
  equal("record returns no internal table", h:record(0, 33), nil)
  for _, actual in ipairs({ 99, 23, 42, 71 }) do
    equal("history overrides every actual branch", h:query(0, nil, actual, rng), 33)
  end
  equal("history needs no actual input", h:query(0, nil, nil), 33)
  h:record(1, 44)
  equal("foe record cannot overwrite player history", h:query(0, 200, 71, rng), 33)
  h:record(1, 0)
  equal("foe zero cannot clear player history", h:query(0, 200, 23, rng), 33)
  h:record(0, 55)
  equal("explicit overwrite after replacement", h:query(0, 100, 71, rng), 55)
  equal("all history paths no draws", rng.count, 0)
  lookups(0, nil)
  h:record(0, 0)
  for _, actual in ipairs({ 23, 42, 71 }) do
    equal("zero cleared history permits trapping knowledge", h:query(0, nil, actual), actual)
  end
  lookups(0, nil)
  equal("zero cleared history permits fresh guess", h:query(0, 100, 99, rng), 22)
  equal("only cleared-history guess draws", rng.count, 1)
  lookups(1, 100)
end

-- :1189-1193: foe reads no history/species/RNG, with or without a record.
do
  local h, rng, lookups = fixture()
  for _, recorded in ipairs({ 0, 33 }) do
    h:record(0, recorded)
    for _, actual in ipairs({ 0, 99, 23, 42, 71 }) do
      equal("foe actual bypasses player history", h:query(1, nil, actual, rng), actual)
    end
  end
  h:record(1, nil) -- source no-op requires no ability input
  equal("foe never draws", rng.count, 0)
  lookups(0, nil)
end

-- :1168-1187: first-only, zero-first and both-zero paths never draw.
do
  local h, rng, lookups = fixture()
  equal("single first candidate", h:query(0, 300, 99), 11)
  equal("zero first fallback", h:query(0, 400, 99), 22)
  equal("both zero stays zero, no actual substitution", h:query(0, 500, 99), 0)
  equal("single and fallback no draws", rng.count, 0)
  lookups(3, 500)
end

-- Fresh setup :262-286 and side array include/battle.h:295-302: separate
-- objects, no replacement reset, no history leaked through the public object.
do
  local old, rng, oldLookups = fixture({ 3 })
  old:record(0, 33)
  local fresh, freshRng, freshLookups = fixture({ 4 })
  equal("fresh battle has no old knowledge", fresh:query(0, 100, 99, freshRng), 22)
  equal("old battle remains stale across replacement", old:query(0, 200, 71, rng), 33)
  equal("old RNG untouched", rng.count, 0)
  equal("fresh RNG independent", freshRng.count, 1)
  oldLookups(0, nil)
  freshLookups(1, 100)
  for key, value in pairs(old) do
    equal("only methods exposed: " .. key, type(value), "function")
  end
end

-- Native API validation is explicit; invalid required inputs must never
-- manufacture knowledge or consume RNG. Bypasses above use absent inputs.
do
  rejects("lookup required", function() History.new(nil) end, "species lookup required")
  local h, rng, lookups, species = fixture({ 3 })
  for _, side in ipairs({ -1, 2, 0.5, "0" }) do
    rejects("invalid query side", function() h:query(side, 100, 99, rng) end, "invalid source side")
    rejects("invalid record side", function() h:record(side, 11) end, "invalid source side")
  end
  for _, ability in ipairs({ -1, 256, 0.5, "11" }) do
    rejects("invalid recorded ability", function() h:record(0, ability) end, "invalid recorded ability")
    rejects("invalid player actual", function() h:query(0, 100, ability, rng) end, "invalid actual ability")
    rejects("invalid foe actual", function() h:query(1, nil, ability, rng) end, "invalid actual ability")
  end
  rejects("missing actual", function() h:query(0, 100, nil, rng) end, "invalid actual ability")
  for _, id in ipairs({ -1, 65536, 0.5, "100" }) do
    rejects("invalid species", function() h:query(0, id, 99, rng) end, "invalid species")
  end
  rejects("missing species ID", function() h:query(0, nil, 99, rng) end, "invalid species")
  lookups(0, nil)
  rejects("unknown species", function() h:query(0, 999, 99, rng) end, "missing species abilities")
  species[999] = {}
  rejects("missing pair", function() h:query(0, 999, 99, rng) end, "missing species abilities")
  species[999].abilities = { 11 }
  rejects("missing second", function() h:query(0, 999, 99, rng) end, "invalid second species ability")
  species[999].abilities = { -1, 22 }
  rejects("invalid first", function() h:query(0, 999, 99, rng) end, "invalid first species ability")
  equal("invalid inputs no draws", rng.count, 0)
  rejects("two candidates require shared RNG", function() h:query(0, 100, 99) end, "shared RNG required")
  rejects("invalid RNG output", function()
    h:query(0, 100, 99, { next16 = function() return 65536 end })
  end, "invalid RNG result")
end

print(string.format("%d passed, 0 failed", passed))
