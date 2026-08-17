-- Money-loss formula, party heal, badge counting, and respawn-location
-- fallback coverage. Pure Lua, no ROM needed.
-- Run: lua5.1 tests/whiteout_rules_test.lua
package.path = package.path .. ";./?.lua"

local WhiteoutRules = require("src.core.WhiteoutRules")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Real sWhiteOutMoneyLossMultipliers, verified against src/overworld.c.
check("0-badge multiplier is 2", WhiteoutRules.MONEY_LOSS_MULTIPLIERS[1] == 2)
check("8-badge multiplier is 30", WhiteoutRules.MONEY_LOSS_MULTIPLIERS[9] == 30)
check("real badge flag ids span SYS_FLAGS+0x20..0x27",
  WhiteoutRules.BADGE_FLAG_IDS[1] == 0x820 and WhiteoutRules.BADGE_FLAG_IDS[8] == 0x827)

check("money loss: level 12, 0 badges -> 12*4*2=96", WhiteoutRules.computeMoneyLoss(12, 0, 10000) == 96)
check("money loss: level 12, 3 badges -> 12*4*9=432", WhiteoutRules.computeMoneyLoss(12, 3, 10000) == 432)
check("money loss caps at current money", WhiteoutRules.computeMoneyLoss(100, 8, 500) == 500)
check("money loss never negative even with 0 money", WhiteoutRules.computeMoneyLoss(50, 0, 0) == 0)
check("badge count beyond 8 clamps to the max multiplier",
  WhiteoutRules.computeMoneyLoss(10, 99, 100000) == WhiteoutRules.computeMoneyLoss(10, 8, 100000))

-- countBadges over a fake flag set.
do
  local flags = { [0x820]=true, [0x822]=true }
  local count = WhiteoutRules.countBadges(function(id) return flags[id] == true end)
  check("countBadges tallies only set badge flags", count == 2)
end

-- highestPartyLevel.
check("highest level across a mixed party", WhiteoutRules.highestPartyLevel({
  { level = 5 }, { level = 12 }, nil, { level = 8 },
}) == 12)
check("highest level of an empty party is 0", WhiteoutRules.highestPartyLevel({}) == 0)
check("an explicit count bounds the scan, ignoring stale trailing slots",
  WhiteoutRules.highestPartyLevel({ { level = 5 }, { level = 99 } }, 1) == 5)

-- HealPlayerParty is real EarlyRivalRewards.healParty's territory (built
-- first for the rival battle, but it's the same real function regardless
-- of caller) -- this module deliberately doesn't reimplement it, only
-- reuses it. See early_rival_battle_test.lua for that coverage.
check("WhiteoutRules does not duplicate HealPlayerParty", WhiteoutRules.healParty == nil)

-- respawnLocation fallback.
do
  local zeroed = { mapGroup=0, mapNum=0, warpId=0, x=0, y=0 }
  local fallback = { mapGroup=4, mapNum=1, warpId=-1, x=6, y=6 }
  local resolved = WhiteoutRules.respawnLocation(zeroed, fallback)
  check("never-healed sentinel falls back", resolved == fallback)

  local real = { mapGroup=2, mapNum=5, warpId=-1, x=3, y=7 }
  check("a real heal location is used as-is", WhiteoutRules.respawnLocation(real, fallback) == real)
end

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
