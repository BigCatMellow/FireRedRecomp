-- Real whiteout consequences: DoWhiteOut (src/overworld.c) -- money loss,
-- full party heal, and respawn at the last real heal location. This
-- project has no gyms/badges/Pokemon Centers yet, so most callers will
-- see badgeCount==0 and a still-zeroed lastHealLocation in practice, but
-- the real formulas are ported in full rather than special-cased down to
-- "always the minimum," so this stays correct once those systems land.
--
-- Real ComputeWhiteOutMoneyLoss (src/overworld.c):
--   nbadges = count of FLAG_BADGE01_GET..FLAG_BADGE08_GET set
--     (SYS_FLAGS(0x800) + 0x20..0x27, include/constants/flags.h)
--   losings = GetPlayerPartyHighestLevel() * 4 * sWhiteOutMoneyLossMultipliers[nbadges]
--   losings = min(losings, current money)
--
-- Real HealPlayerParty (src/script_pokemon_util.c) is already ported as
-- EarlyRivalRewards.healParty (built for the rival-battle heal, but it's
-- the same real function regardless of caller) -- reuse that rather than
-- porting it a second time here.
--
-- Real Overworld_SetWhiteoutRespawnPoint/DoWhiteOut warp to
-- gSaveBlock1Ptr->lastHealLocation unconditionally -- this project models
-- that same field (see GameSession.fromNewGame's saveBlock1.lastHealLocation)
-- but has no Pokemon Center/healing-NPC interaction to ever populate it
-- yet, so a session that has never healed still has it zeroed. Real
-- FireRed never actually reaches this state (the story always routes
-- through a Center or the starting town's heal point first); this
-- module's respawnLocation() takes an explicit fallback for that case
-- rather than guessing what real map group/num 0,0 would mean here.

local WhiteoutRules = {}

WhiteoutRules.MAX_MONEY = 999999 -- MAX_MONEY, src/money.c
WhiteoutRules.MONEY_LOSS_MULTIPLIERS = { 2, 4, 6, 9, 12, 16, 20, 25, 30 } -- index 1 == 0 badges
WhiteoutRules.BADGE_FLAG_IDS = { 0x820, 0x821, 0x822, 0x823, 0x824, 0x825, 0x826, 0x827 }

-- getFlag(flagId) -> boolean, matching GameSession:getFlag's signature.
function WhiteoutRules.countBadges(getFlag)
  local n = 0
  for _, flagId in ipairs(WhiteoutRules.BADGE_FLAG_IDS) do
    if getFlag(flagId) then n = n + 1 end
  end
  return n
end

function WhiteoutRules.computeMoneyLoss(topLevel, badgeCount, currentMoney)
  local multiplier = WhiteoutRules.MONEY_LOSS_MULTIPLIERS[badgeCount + 1]
    or WhiteoutRules.MONEY_LOSS_MULTIPLIERS[#WhiteoutRules.MONEY_LOSS_MULTIPLIERS]
  local losings = topLevel * 4 * multiplier
  return math.max(0, math.min(losings, currentMoney or 0))
end

-- Real GetPlayerPartyHighestLevel: the max real party level, or 0 for an
-- empty party (this project's own fallback -- source never calls this
-- with zero party members since a whiteout requires a battle to have
-- happened, which requires a usable lead). `count` bounds the scan to
-- the real occupied slots (matching EarlyRivalRewards.healParty's own
-- playerPartyCount-bounded loop); defaults to #party for a plain array.
function WhiteoutRules.highestPartyLevel(party, count)
  local highest = 0
  for i = 1, (count or #party) do
    local record = party[i]
    if record and (record.level or 0) > highest then
      highest = record.level
    end
  end
  return highest
end

-- lastHealLocation: the decoded {mapGroup,mapNum,warpId,x,y} field.
-- fallback: used only when lastHealLocation is still the all-zero
-- never-healed sentinel (see header note).
function WhiteoutRules.respawnLocation(lastHealLocation, fallback)
  if lastHealLocation and (lastHealLocation.mapGroup ~= 0 or lastHealLocation.mapNum ~= 0
      or lastHealLocation.x ~= 0 or lastHealLocation.y ~= 0) then
    return lastHealLocation
  end
  return fallback
end

return WhiteoutRules
