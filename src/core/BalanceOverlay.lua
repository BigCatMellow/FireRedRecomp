-- Project-owned balance overlay.
--
-- ROM importers remain the source of truth for FireRed US v1.0. This module
-- creates derived runtime records for an optional rebalance ruleset; it never
-- mutates imported gBattleMoves or level-up learnsets.
local BalanceOverlay = {}

BalanceOverlay.CATEGORY_PHYSICAL = "physical"
BalanceOverlay.CATEGORY_SPECIAL = "special"

local function shallowCopy(source)
  local out = {}
  for k, v in pairs(source) do out[k] = v end
  return out
end

local function copyLearnset(source)
  local out = {}
  for i, entry in ipairs(source or {}) do
    out[i] = shallowCopy(entry)
  end
  return out
end

function BalanceOverlay.move(baseMove, override)
  assert(type(baseMove) == "table", "base move record is required")
  if not override then return baseMove end
  local out = shallowCopy(baseMove)
  for k, v in pairs(override) do
    assert(k == "power" or k == "accuracy" or k == "pp" or k == "category",
      "unsupported move override field: " .. tostring(k))
    out[k] = v
  end
  if out.category ~= nil then
    assert(out.category == BalanceOverlay.CATEGORY_PHYSICAL
      or out.category == BalanceOverlay.CATEGORY_SPECIAL,
      "category must be physical or special")
  end
  return out
end

function BalanceOverlay.moves(baseMoves, overrides)
  local out = {}
  for id, move in pairs(baseMoves or {}) do
    out[id] = BalanceOverlay.move(move, overrides and overrides[id])
  end
  return out
end

function BalanceOverlay.learnset(baseLearnset, additions)
  if not additions or #additions == 0 then return baseLearnset end
  local out = copyLearnset(baseLearnset)
  for _, addition in ipairs(additions) do
    assert(type(addition.level) == "number" and type(addition.move) == "number",
      "learnset additions require numeric level and move")
    out[#out + 1] = { level = addition.level, move = addition.move }
  end
  table.sort(out, function(a, b)
    if a.level ~= b.level then return a.level < b.level end
    return a.move < b.move
  end)
  return out
end

return BalanceOverlay
