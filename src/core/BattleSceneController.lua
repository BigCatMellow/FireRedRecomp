-- Pure presentation controller for BattleEngine's first live wild-battle
-- slice. It owns menus and consumes the engine's one-way event stream, but
-- never reads a ROM or calls love.*. This keeps input/presentation timing
-- out of BattleEngine's deterministic rules.
--
-- The 2x2 action and move cursors mirror HandleInputChooseAction and
-- HandleInputChooseMove in pokefirered/src/battle_controller_player.c:
-- Left/Right xor bit 0 and Up/Down xor bit 1 when the destination exists.
-- A chooses, B backs out of the move menu. FIGHT and RUN have live engine
-- actions; POKEMON switching deliberately still shows an unavailable
-- message (no live-scene party-select UI exists yet, even though
-- BattleEngine's "switch" action itself is real -- see BattleEngine.lua).
--
-- BAG is bounded, not fully general: this controller only knows how to
-- throw a plain real ITEM_POKE_BALL (CaptureRules.ITEM_POKE_BALL) --
-- there's no live item-browsing/pocket-selection menu, matching this
-- project's established "the pure rules layer exists before its full UI"
-- pattern (see CaptureRewards.lua/PokemonMart.lua, built the same way).
-- `opts.bag` is an optional real Bag.lua instance; if the caller doesn't
-- supply one, or it has no balls, BAG still shows a bounded "no balls"
-- message rather than crashing or pretending a throw happened. A real
-- ball is always consumed on a throw attempt regardless of catch
-- success, matching real FireRed (Cmd_handleballthrow's caller already
-- removed the item from the bag before the throw even resolves).

local InputState = require("src.core.InputState")
local CaptureRules = require("src.core.CaptureRules")

local BattleSceneController = {}
BattleSceneController.__index = BattleSceneController

BattleSceneController.MESSAGES = "messages"
BattleSceneController.ACTION = "action"
BattleSceneController.MOVE = "move"
BattleSceneController.COMPLETE = "complete"

local function possessive(name)
  return name .. "'s"
end

local function otherSide(side)
  if side == "player" then return "foe" end
  return "player"
end

-- Real gStatNamesTable (src/battle_message.c), for the stat keys
-- BattleEngine.lua's statStages table already uses.
local STAT_DISPLAY_NAMES = {
  attack = "ATTACK", defense = "DEFENSE", speed = "SPEED",
  spAttack = "SP. ATK", spDefense = "SP. DEF",
  accuracy = "ACCURACY", evasion = "EVASIVENESS",
}

function BattleSceneController.new(opts)
  assert(opts and opts.engine, "BattleSceneController needs a BattleEngine")
  local self = setmetatable({
    engine = opts.engine,
    playerName = opts.playerName or "POKEMON",
    foeName = opts.foeName or "POKEMON",
    moveName = opts.moveName or function(move) return "MOVE " .. tostring(move) end,
    foeMoveSlot = opts.foeMoveSlot or 1,
    chooseFoeMove = opts.chooseFoeMove,
    runDisabledMessage = opts.runDisabledMessage,
    bag = opts.bag,
    state = BattleSceneController.MESSAGES,
    actionCursor = 0,
    moveCursor = 0,
    messages = {},
    messageIndex = 1,
    afterMessages = BattleSceneController.ACTION,
    revision = 0,
    displayedHP = {
      player = opts.engine.player.hp,
      foe = opts.engine.foe.hp,
    },
  }, BattleSceneController)
  local intro = opts.introMessages or {
    "Wild " .. self.foeName .. " appeared!",
    "Go! " .. self.playerName .. "!",
  }
  local entries = {}
  for _, entry in ipairs(intro) do
    entries[#entries + 1] = type(entry) == "string" and {text=entry} or entry
  end
  self:_setMessages(entries, BattleSceneController.ACTION)
  return self
end

function BattleSceneController:_touch()
  self.revision = self.revision + 1
end

function BattleSceneController:_applyInvisibleEntries()
  while self.messages[self.messageIndex] and not self.messages[self.messageIndex].text do
    local entry = self.messages[self.messageIndex]
    if entry.hpSide then self.displayedHP[entry.hpSide] = entry.hp end
    self.messageIndex = self.messageIndex + 1
  end
end

function BattleSceneController:_setMessages(entries, afterState)
  self.messages = entries
  self.messageIndex = 1
  self.afterMessages = afterState
  self.state = BattleSceneController.MESSAGES
  self:_applyInvisibleEntries()
  if not self.messages[self.messageIndex] then self.state = afterState end
  self:_touch()
end

function BattleSceneController:message()
  local entry = self.messages[self.messageIndex]
  return entry and entry.text or nil
end

function BattleSceneController:advanceMessage()
  if self.state ~= BattleSceneController.MESSAGES then return end
  self.messageIndex = self.messageIndex + 1
  self:_applyInvisibleEntries()
  if not self.messages[self.messageIndex] then self.state = self.afterMessages end
  self:_touch()
end

-- Adds battle-script/reward messages behind the currently playing event
-- stream, before the controller is allowed to reach COMPLETE.
function BattleSceneController:appendMessages(entries, afterState)
  for _, entry in ipairs(entries or {}) do
    self.messages[#self.messages + 1] = type(entry) == "string" and {text=entry} or entry
  end
  if afterState then self.afterMessages = afterState end
  self:_touch()
end

local function move2x2(cursor, input, count)
  local nextCursor = cursor
  if input:isNewlyPressed(InputState.DPAD_LEFT) and cursor % 2 == 1 then
    nextCursor = cursor - 1
  elseif input:isNewlyPressed(InputState.DPAD_RIGHT) and cursor % 2 == 0 and cursor + 1 < count then
    nextCursor = cursor + 1
  elseif input:isNewlyPressed(InputState.DPAD_UP) and cursor >= 2 then
    nextCursor = cursor - 2
  elseif input:isNewlyPressed(InputState.DPAD_DOWN) and cursor < 2 and cursor + 2 < count then
    nextCursor = cursor + 2
  end
  return nextCursor
end

function BattleSceneController:_eventMessages(events)
  local entries = {}
  local function add(text, extra)
    local e = extra or {}
    e.text = text
    entries[#entries + 1] = e
  end
  local function name(side) return side == "player" and self.playerName or self.foeName end

  for _, event in ipairs(events) do
    if event.type == "useMove" then
      add(name(event.side) .. " used " .. self.moveName(event.move) .. "!")
    elseif event.type == "miss" then
      add(possessive(name(event.side)) .. " attack missed!")
    elseif event.type == "critical" then
      add("A critical hit!")
    elseif event.type == "damage" then
      -- HP-bar state changes between script messages in the real battle.
      -- Keep it as an invisible ordered event rather than inventing a
      -- non-FireRed "lost N HP" message.
      entries[#entries + 1] = { hpSide = event.target, hp = event.hpRemaining }
      if event.superEffective then add("It's super effective!") end
      if event.notVeryEffective then add("It's not very effective...") end
    elseif event.type == "noEffect" then
      add("It doesn't affect " .. name(event.target) .. "...")
    elseif event.type == "faint" then
      add(name(event.side) .. " fainted!", { hpSide = event.side, hp = 0 })
    elseif event.type == "noPP" then
      add("There's no PP left for this move!")
    elseif event.type == "statChange" then
      -- Real gStatNamesTable (src/battle_message.c): Attack/Defense/
      -- Speed/Sp. Atk/Sp. Def/Accuracy/Evasiveness. Real message shape
      -- (sText_AttackersStatRose/sText_DefendersStatFell) is "<name>'s
      -- <STAT> <verb>!"; the verb depends on real stage magnitude:
      -- rose/sharply rose for +1/+2, fell/harshly fell for -1/-2
      -- (sText_StatSharply="sharply "/sText_StatHarshly="harshly "
      -- prefixed onto the base "rose!"/"fell!"). Boundary case uses the
      -- real "won't go higher!"/"won't go lower!" pair
      -- (sText_StatsWontIncrease/sText_StatsWontDecrease) rather than
      -- the rose/fell verb.
      local statName = STAT_DISPLAY_NAMES[event.stat] or event.stat
      if event.prevented then
        local verb = (event.stages and event.stages > 0) and "won't go higher!" or "won't go lower!"
        add(possessive(name(event.side)) .. " " .. statName .. "\n" .. verb)
      else
        local magnitude = math.abs(event.stages or 1)
        local verb
        if event.stages and event.stages > 0 then
          verb = magnitude >= 2 and "sharply rose!" or "rose!"
        else
          verb = magnitude >= 2 and "harshly fell!" or "fell!"
        end
        add(possessive(name(event.side)) .. " " .. statName .. "\n" .. verb)
      end
    elseif event.type == "switch" then
      -- Bounded, single-message result: this event doesn't carry the
      -- outgoing/incoming species names (BattleEngine stays fully
      -- party-agnostic -- see its header), so this can't yet reproduce
      -- real FireRed's two-message "<mon>, come back! Go! <mon>!" pair
      -- without deeper plumbing this controller doesn't have. A compact
      -- placeholder covers it instead, same choice already made for
      -- "capture"'s shake-by-shake real message variants above.
      add(name(event.side) .. " switched Pokemon!")
    elseif event.type == "recoil" then
      -- Real sText_PkmnHitWithRecoil (src/battle_message.c): "<mon> is
      -- hit with recoil!" -- the attacker, since recoil damages the
      -- move's own user.
      add(name(event.side) .. " is hit\nwith recoil!")
    elseif event.type == "drain" then
      -- Real sText_PkmnEnergyDrained: "<mon> had its energy drained!" --
      -- real FireRed names the DEFENDER here (the mon the HP was drained
      -- FROM), even though it's the attacker's own side that heals.
      add(name(otherSide(event.side)) .. " had its\nenergy drained!")
    elseif event.type == "multiHit" then
      -- Real sText_HitXTimes: "Hit N time(s)!" -- only emitted when the
      -- sequence completes without an early stop (matching real
      -- BattleScript_MultiHitPrintStrings, which this event's own
      -- BattleEngine.lua doc already notes is skipped on a no-effect
      -- stop; a mid-sequence faint also skips it there since the
      -- faint/battleEnd events already say enough).
      add(("Hit %d time(s)!"):format(event.hits))
    elseif event.type == "tutorialTip" then
      if event.kind == "damage" then
        add("OAK: Inflicting damage on the foe\nis the key to any battle.")
      else
        add("OAK: Lowering the foe's stats\nwill put you at an advantage.")
      end
    elseif event.type == "run" then
      add(event.success and "Got away safely!" or "Can't escape!")
    elseif event.type == "throwBall" then
      add(self.playerName .. " threw a POKé BALL!")
    elseif event.type == "capture" then
      if event.success then
        add("Gotcha! " .. self.foeName .. " was caught!")
      else
        -- Bounded, single-message result: this engine reports the real
        -- shake count (CaptureRules) but doesn't animate a shake-by-shake
        -- sequence, so a compact single line covers every outcome rather
        -- than fabricating per-shake real-FireRed message variants this
        -- project hasn't verified against source.
        add(name(event.target) .. " broke free!")
      end
    end
  end
  return entries
end

function BattleSceneController:_runTurn(playerAction)
  if playerAction.action == "run" and self.runDisabledMessage then
    self:_setMessages({ { text=self.runDisabledMessage } }, BattleSceneController.ACTION)
    return
  end
  if playerAction.action == "move" then
    local slot = self.engine.player.moves[playerAction.moveSlot]
    local move = slot and self.engine.moves[slot.move]
    -- Keep effects beyond the engine's explicit bounded subset visible,
    -- rather than routing an unknown power-zero move into fabricated rules.
    if move and not self.engine:supportsMove(move) then
      self:_setMessages({ { text = "That move's effect is not available yet." } },
        BattleSceneController.MOVE)
      return
    end
  end
  local foeMoveSlot = self.chooseFoeMove and self.chooseFoeMove(self.engine) or self.foeMoveSlot
  local events = self.engine:runTurn(playerAction, { action = "move", moveSlot = foeMoveSlot })
  local after = self.engine:isOver() and BattleSceneController.COMPLETE or BattleSceneController.ACTION
  self.actionCursor = 0
  self:_setMessages(self:_eventMessages(events), after)
end

function BattleSceneController:processInput(input)
  if self.state == BattleSceneController.MESSAGES then
    if input:isNewlyPressed(InputState.A_BUTTON) or input:isNewlyPressed(InputState.B_BUTTON) then
      self:advanceMessage()
    end
    return
  end
  if self.state == BattleSceneController.COMPLETE then return end

  if self.state == BattleSceneController.ACTION then
    local before = self.actionCursor
    self.actionCursor = move2x2(self.actionCursor, input, 4)
    if self.actionCursor ~= before then self:_touch() end
    if input:isNewlyPressed(InputState.A_BUTTON) then
      if self.actionCursor == 0 then
        self.state = BattleSceneController.MOVE
        self.moveCursor = 0
        self:_touch()
      elseif self.actionCursor == 3 then
        self:_runTurn({ action = "run" })
      elseif self.actionCursor == 1 then
        if self.bag and self.bag:quantityOf(CaptureRules.ITEM_POKE_BALL) > 0 then
          self.bag:removeItem(CaptureRules.ITEM_POKE_BALL, 1)
          self:_runTurn({ action = "capture" })
        else
          self:_setMessages({ { text = "You don't have any POKé BALLS!" } }, BattleSceneController.ACTION)
        end
      else
        self:_setMessages({ { text = "POKEMON switching is not available yet." } }, BattleSceneController.ACTION)
      end
    end
    return
  end

  local moveCount = #self.engine.player.moves
  local before = self.moveCursor
  self.moveCursor = move2x2(self.moveCursor, input, moveCount)
  if self.moveCursor ~= before then self:_touch() end
  if input:isNewlyPressed(InputState.B_BUTTON) then
    self.state = BattleSceneController.ACTION
    self:_touch()
  elseif input:isNewlyPressed(InputState.A_BUTTON) then
    self:_runTurn({ action = "move", moveSlot = self.moveCursor + 1 })
  end
end

function BattleSceneController:isComplete()
  return self.state == BattleSceneController.COMPLETE
end

return BattleSceneController
