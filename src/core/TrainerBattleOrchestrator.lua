-- Foe-only ordered trainer-party state over BattleEngine's existing forced
-- switch primitive.  This deliberately knows nothing about player-party UI,
-- items, doubles, or move choice: its only authority is supplying the next
-- already-built ordinary trainer battler after the faint script has played.
local TrainerBattleOrchestrator = {}
TrainerBattleOrchestrator.__index = TrainerBattleOrchestrator

function TrainerBattleOrchestrator.new(opts)
  assert(opts and opts.foes and #opts.foes >= 2,
    "TrainerBattleOrchestrator needs an ordered foe roster of at least two")
  assert(opts.toBattler, "TrainerBattleOrchestrator needs toBattler")
  return setmetatable({
    foes=opts.foes, toBattler=opts.toBattler, index=1, rewarded={},
  }, TrainerBattleOrchestrator)
end

function TrainerBattleOrchestrator:currentFoe()
  return self.foes[self.index]
end

function TrainerBattleOrchestrator:hasReplacement(side)
  return side == "foe" and self.index < #self.foes
end

-- Called only by the presentation controller after its ordered faint and
-- "must send out" messages are exhausted.  That timing is the important
-- boundary: BattleEngine remains blocked during those messages.
function TrainerBattleOrchestrator:resolveFoeReplacement(engine, reward)
  assert(engine.awaitingForcedSwitch == "foe", "no foe replacement is pending")
  local defeated = self:currentFoe()
  assert(not self.rewarded[self.index], "a defeated foe may be rewarded only once")
  if reward then reward(defeated, self.index, false) end
  self.rewarded[self.index] = true
  self.index = self.index + 1
  local incoming = self:currentFoe()
  engine:resolveForcedSwitch("foe", self.toBattler(incoming))
  return incoming
end

-- The final foe has no replacement, so BattleEngine reports playerWon.
-- Settle it exactly once; caller retains flag/prize authority until this
-- method has returned, preventing early trainer-defeat flags.
function TrainerBattleOrchestrator:resolveFinalFoeReward(reward)
  assert(self.index == #self.foes, "final reward before final foe")
  assert(not self.rewarded[self.index], "final foe already rewarded")
  local foe = self:currentFoe()
  if reward then reward(foe, self.index, true) end
  self.rewarded[self.index] = true
  return foe
end

return TrainerBattleOrchestrator
