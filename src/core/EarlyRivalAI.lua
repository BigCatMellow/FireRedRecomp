-- Exact bounded execution of the three AI scripts enabled for the Oak-lab
-- rivals: CheckBadMove, CheckViability, and TryToFaint.  This is not a
-- general trainer-AI approximation.  It accepts only the four moves that
-- can occur in this battle (Tackle, Scratch, Growl, Tail Whip) and fails
-- visibly for any other effect so later battles cannot silently inherit a
-- made-up policy.

local BattleFormulas = require("src.core.BattleFormulas")

local EarlyRivalAI = {}

EarlyRivalAI.AI_FLAGS = 0x7
EarlyRivalAI.EFFECT_HIT = 0
EarlyRivalAI.EFFECT_ATTACK_DOWN = 18
EarlyRivalAI.EFFECT_DEFENSE_DOWN = 19
EarlyRivalAI.EFFECT_QUICK_ATTACK = 103

local PHYSICAL_TYPES = { [0]=true, [1]=true, [4]=true, [5]=true, [6]=true, [8]=true }

local function hpPercent(mon)
  return math.floor(100 * mon.hp / mon.maxHP)
end

local function predictedDamage(engine, move, simulatedPercent)
  local damage = BattleFormulas.calculateBaseDamage(engine.foe, engine.player, move, false)
  damage = BattleFormulas.typeCalc(damage, move.type,
    engine.foe.types, engine.player.types, engine.typeChart)
  damage = math.floor(damage * simulatedPercent / 100)
  return math.max(1, damage)
end

local function randomLessThan(rng, threshold)
  return rng:next16() % 256 < threshold
end

local function viabilityScore(engine, move)
  local user, target, rng = engine.foe, engine.player, engine.rng
  local score = 0
  if move.effect == EarlyRivalAI.EFFECT_ATTACK_DOWN then
    if target.statStages.attack ~= 6 then
      score = score - 1
      if hpPercent(user) <= 90 then score = score - 1 end
    end
    if target.statStages.attack <= 3 and not randomLessThan(rng, 50) then
      score = score - 2
    end
    if hpPercent(target) <= 70 then score = score - 2 end
    if not PHYSICAL_TYPES[target.types[1]] and not PHYSICAL_TYPES[target.types[2]]
        and not randomLessThan(rng, 50) then
      score = score - 2
    end
  elseif move.effect == EarlyRivalAI.EFFECT_DEFENSE_DOWN then
    if hpPercent(user) >= 70 and target.statStages.defense > 3 then
      return score
    end
    if not randomLessThan(rng, 50) then score = score - 2 end
    if hpPercent(target) <= 70 then score = score - 2 end
  end
  return score
end

-- Returns the 1-based move slot selected by BattleAI_ChooseMoveOrAction.
function EarlyRivalAI.choose(engine, aiFlags)
  assert(aiFlags == EarlyRivalAI.AI_FLAGS,
    "Oak-lab AI requires CheckBadMove|CheckViability|TryToFaint")
  local scores, simulated = {100,100,100,100}, {}
  for i = 1, 4 do simulated[i] = 100 - (engine.rng:next16() % 16) end

  local strongestDamage = 0
  for i = 1, 4 do
    local slot = engine.foe.moves[i]
    if not slot or slot.pp <= 0 then
      scores[i] = 0
    else
      local move = assert(engine.moves[slot.move], "trainer move missing from battle table")
      if move.effect ~= EarlyRivalAI.EFFECT_HIT
          and move.effect ~= EarlyRivalAI.EFFECT_ATTACK_DOWN
          and move.effect ~= EarlyRivalAI.EFFECT_DEFENSE_DOWN then
        error(("unsupported Oak-lab AI move effect %d for move %d")
          :format(move.effect, slot.move))
      end
      if move.power > 1 then
        strongestDamage = math.max(strongestDamage,
          predictedDamage(engine, move, simulated[i]))
      end
    end
  end

  for i = 1, 4 do
    local slot = engine.foe.moves[i]
    if slot and slot.pp > 0 then
      local move = engine.moves[slot.move]
      -- AI_CheckBadMove. Starter abilities do not block these two changes;
      -- the exhausted-stage rule is the only reachable bad-move branch.
      if move.effect == EarlyRivalAI.EFFECT_ATTACK_DOWN
          and engine.player.statStages.attack == 0 then
        scores[i] = scores[i] - 10
      elseif move.effect == EarlyRivalAI.EFFECT_DEFENSE_DOWN
          and engine.player.statStages.defense == 0 then
        scores[i] = scores[i] - 10
      end

      scores[i] = scores[i] + viabilityScore(engine, move)

      -- AI_TryToFaint. Neither Tackle nor Scratch is Quick Attack, and
      -- each lab starter has only one damaging move, so the full generic
      -- "not most powerful" scan reduces to these source-equivalent tests.
      if move.power > 1 then
        local damage = predictedDamage(engine, move, simulated[i])
        if damage >= engine.player.hp then
          scores[i] = scores[i] + 4
        elseif damage < strongestDamage then
          scores[i] = scores[i] - 1
        end
      end
    end
  end

  local best = scores[1]
  local choices = {1}
  for i = 2, 4 do
    if scores[i] > best then
      best, choices = scores[i], {i}
    elseif scores[i] == best then
      choices[#choices + 1] = i
    end
  end
  return choices[(engine.rng:next16() % #choices) + 1], scores
end

return EarlyRivalAI
