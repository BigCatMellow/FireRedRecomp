-- Pure presentation controller for BattleEngine's first live wild-battle
-- slice. It owns menus and consumes the engine's one-way event stream, but
-- never reads a ROM or calls love.*. This keeps input/presentation timing
-- out of BattleEngine's deterministic rules.
--
-- The 2x2 action and move cursors mirror HandleInputChooseAction and
-- HandleInputChooseMove in pokefirered/src/battle_controller_player.c:
-- Left/Right xor bit 0 and Up/Down xor bit 1 when the destination exists.
-- A chooses, B backs out of the move menu. FIGHT and RUN have live engine
-- actions. POKEMON can opt into a save-backed selector through explicit
-- callbacks; BattleEngine's "switch" action remains the authoritative turn.
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
-- PARTY serves both a normal voluntary selector and a cancel-proof forced
-- replacement. `partyMode` preserves their materially different semantics.
BattleSceneController.PARTY = "party"
BattleSceneController.COMPLETE = "complete"

local function possessive(name)
  return name .. "'s"
end

local function otherSide(side)
  if side == "player" then return "foe" end
  return "player"
end

-- gTypeNames (c75f352 src/battle_main.c:428).
local TYPE_DISPLAY_NAMES = {
  [0] = "NORMAL", "FIGHT", "FLYING", "POISON", "GROUND", "ROCK", "BUG", "GHOST",
  "STEEL", "???", "FIRE", "WATER", "GRASS", "ELECTR", "PSYCHC", "ICE", "DRAGON", "DARK",
}
BattleSceneController.TYPE_DISPLAY_NAMES = TYPE_DISPLAY_NAMES

-- Weather texts (c75f352 src/battle_message.c:339-352).
local WEATHER_SET_TEXT = {
  rain = "It started to rain!", sandstorm = "A sandstorm brewed!",
  sun = "The sunlight got bright!", hail = "It started to hail!",
}
local WEATHER_CONTINUES_TEXT = {
  rain = "Rain continues to fall.", sandstorm = "The sandstorm rages.",
  sun = "The sunlight is strong.", hail = "Hail continues to fall.",
}
local WEATHER_ENDED_TEXT = {
  rain = "The rain stopped.", sandstorm = "The sandstorm subsided.",
  sun = "The sunlight faded.", hail = "The hail stopped.",
}
-- Weather W3b: gAbilityNames (src/data/text/abilities.h:166, :209, :234)
-- and the tails of STRINGID_PKMNMADEITRAIN / PKMNSXWHIPPEDUPSANDSTORM /
-- PKMNSXINTENSIFIEDSUN (src/battle_message.c:263, :284, :285).
local WEATHER_ABILITY_NAMES = { [2] = "DRIZZLE", [45] = "SAND STREAM", [70] = "DROUGHT" }
local WEATHER_ABILITY_TEXT = {
  rain = "made it rain!", sandstorm = "whipped up a sandstorm!",
  sun = "intensified the sun's rays!",
}

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
    onMessagesComplete = opts.onMessagesComplete,
    forcedSwitchChoices = opts.forcedSwitchChoices,
    onForcedSwitchChoice = opts.onForcedSwitchChoice,
    voluntarySwitchChoices = opts.voluntarySwitchChoices,
    onVoluntarySwitchChoice = opts.onVoluntarySwitchChoice,
    runDisabledMessage = opts.runDisabledMessage,
    bag = opts.bag,
    state = BattleSceneController.MESSAGES,
    actionCursor = 0,
    moveCursor = 0,
    partyCursor = 0,
    partyChoices = {},
    partyMode = nil,
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
  -- Weather W3b: TryDoEventsBeforeFirstTurn (src/battle_main.c:2856-2927)
  -- runs the leads' switch-in abilities after the intro and send-out
  -- messages and before the first action selection. Every live battle start
  -- builds its controller right after its fresh engine, so this is where
  -- the battle-start events are resolved and presented. An engine that has
  -- already resolved its start or played a turn is left alone.
  local engine = self.engine
  if type(engine.resolveBattleStart) == "function"
      and not engine.battleStartResolved and engine.turn == 0 then
    for _, entry in ipairs(self:_eventMessages(engine:resolveBattleStart())) do
      entries[#entries + 1] = entry
    end
  end
  self:_setMessages(entries, BattleSceneController.ACTION)
  return self
end

-- Weather W3b: the events of a forced replacement that a caller resolved
-- through BattleEngine:resolveForcedSwitch inside one of this controller's
-- callbacks (the replacement's switch-in ability), as message entries. They
-- follow the caller's own send-out text, as switchineffects follows
-- printstring SWITCHINMON (data/battle_scripts_1.s:2879-2884).
function BattleSceneController:_takeForcedSwitchMessages()
  local engine = self.engine
  if type(engine.takeForcedSwitchEvents) ~= "function" then return {} end
  return self:_eventMessages(engine:takeForcedSwitchEvents())
end

local function concatEntries(first, second)
  local out = {}
  for _, entry in ipairs(first or {}) do out[#out + 1] = entry end
  for _, entry in ipairs(second or {}) do out[#out + 1] = entry end
  return out
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

-- A locked player (charging/recharging/rampaging) gets no action menu: the turn runs
-- with the locked move as soon as the controller would enter ACTION.
function BattleSceneController:_enterAction()
  local engine = self.engine
  if engine and engine.isLocked and engine.isOver and not engine:isOver()
      and not engine.awaitingForcedSwitch and engine:isLocked("player") then
    self:_runTurn({ action = "move", moveSlot = self.engine.player.lockedSlot })
    return true
  end
  return false
end

function BattleSceneController:_setMessages(entries, afterState)
  self.messages = {}
  for _, entry in ipairs(entries or {}) do
    self.messages[#self.messages + 1] = type(entry) == "string" and {text=entry} or entry
  end
  self.messageIndex = 1
  self.afterMessages = afterState
  if afterState == BattleSceneController.PARTY and not self.partyMode then self.partyMode = "forced" end
  self.state = BattleSceneController.MESSAGES
  self:_applyInvisibleEntries()
  if not self.messages[self.messageIndex] then
    self.state = afterState
    if afterState ~= BattleSceneController.PARTY then self.partyMode = nil end
    if afterState == BattleSceneController.ACTION and self:_enterAction() then return end
  end
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
  if not self.messages[self.messageIndex] then
    -- A foe-only trainer roster may resolve its already-pending forced
    -- switch here, after (never before) the faint/message sequence.  The
    -- hook returns the incoming-foe messages, if any; it has no player UI
    -- authority and is opt-in so all existing controller users are unchanged.
    local followup = self.onMessagesComplete and self.onMessagesComplete(self)
    followup = concatEntries(followup, self:_takeForcedSwitchMessages())
    if #followup > 0 then
      self:_setMessages(followup, BattleSceneController.ACTION)
      return
    end
    self.state = self.afterMessages
    if self.state == BattleSceneController.PARTY then self:_refreshPartyChoices() else self.partyMode = nil end
    if self.state == BattleSceneController.ACTION and self:_enterAction() then return end
  end
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

local STATUS_ABILITY_NAMES = {
  [7] = "LIMBER", [15] = "INSOMNIA", [17] = "IMMUNITY", [41] = "WATER VEIL", [72] = "VITAL SPIRIT",
}

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
    elseif event.type == "magnitude" then
      -- The engine has already selected the level and completed its model
      -- work. Presentation only announces that literal event; it neither
      -- infers transient power/target nor touches RNG or engine state.
      add(("Magnitude %d!"):format(event.level))
    elseif event.type == "miss" then
      add(possessive(name(event.side)) .. " attack missed!")
    elseif event.type == "crash" then
      add(name(event.side) .. " kept going\nand crashed!")
      -- Source announces crash before attacker HP. Only an invisible entry
      -- advances displayedHP after acknowledgement; model HP is engine-owned.
      entries[#entries + 1] = { hpSide = event.side, hp = event.hpRemaining }
    elseif event.type == "moveFailed" then
      add("But it failed!")
    elseif event.type == "critical" then
      add("A critical hit!")
    elseif event.type == "damage" then
      -- HP-bar state changes between script messages in the real battle.
      -- Keep it as an invisible ordered event rather than inventing a
      -- non-FireRed "lost N HP" message.
      entries[#entries + 1] = { hpSide = event.target, hp = event.hpRemaining }
      if event.superEffective then add("It's super effective!") end
      if event.notVeryEffective then add("It's not very effective...") end
    elseif event.type == "painSplitHP" then
      entries[#entries + 1] = { hpSide = event.side, hp = event.hpRemaining }
    elseif event.type == "painSplit" then
      add("The battlers\nshared their pain!")
    elseif event.type == "restoreHP" then
      entries[#entries + 1] = { hpSide = event.side, hp = event.hpRemaining }
      -- sText_PkmnRegainedHealth (c75f352 battle_message.c:124); the heal
      -- target is the user, so B_DEF_NAME names this side.
      add(name(event.side) .. " regained\nhealth!")
    elseif event.type == "restoreHPFull" then
      -- sText_PkmnHPFull (battle_message.c:125), via BattleScript_AlreadyAtFullHp.
      add(possessive(name(event.side)) .. "\nHP is full!")
    elseif event.type == "noEffect" then
      add("It doesn't affect " .. name(event.target) .. "...")
    elseif event.type == "faint" then
      add(name(event.side) .. " fainted!", { hpSide = event.side, hp = 0 })
    elseif event.type == "forcedSwitchNeeded" then
      -- Bounded placeholder, same choice already made for "switch": no live
      -- party-select scene exists yet (BattleEngine's forced-switch engine
      -- primitive is real -- see BattleEngine.lua's header -- but building
      -- that UI is a separate, explicitly out-of-scope task). A real
      -- FireRed player would see the party-select menu here instead.
      add(name(event.side) .. " must send out\na new POKEMON!")
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
    elseif event.type == "statsWontRise" then
      -- sText_StatsWontIncrease2 (src/battle_message.c).
      add(possessive(name(event.side)) .. " stats won't\ngo any higher!")
    elseif event.type == "conversion" then
      -- sText_PkmnChangedType
      add(name(event.side) .. " transformed\ninto the " .. (TYPE_DISPLAY_NAMES[event.newType] or "???") .. " type!")
    elseif event.type == "mementoHP" then
      -- trymemento drops the user's HP bar before the stat messages.
      entries[#entries + 1] = { hpSide = event.side, hp = 0 }
    elseif event.type == "wallShattered" then
      add("The wall shattered!") -- sText_TheWallShattered
    elseif event.type == "splash" then
      add("But nothing happened!") -- sText_ButNothingHappened
    elseif event.type == "haze" then
      add("All stat changes were\neliminated!") -- sText_StatChangesGone
    elseif event.type == "psychUp" then
      -- sText_PkmnCopiedStatChanges
      add(name(event.side) .. " copied\n" .. possessive(name(event.target)) .. " stat changes!")
    elseif event.type == "bellyDrum" then
      -- Source updates attacker HP before sText_PkmnCutHPMaxedAttack.
      entries[#entries + 1] = { hpSide = event.side, hp = event.hpRemaining }
      add(name(event.side) .. " cut its own HP\nand maximized ATTACK!")
    elseif event.type == "statsWontFall" then
      -- sText_StatsWontDecrease2 (src/battle_message.c).
      add(possessive(name(event.side)) .. " stats won't\ngo any lower!")
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
      -- move's own user. hpSide=event.side (not otherSide): recoil/drain
      -- change the ATTACKER's own HP, unlike "damage" whose hpSide is
      -- the target -- get this backwards and the wrong HP bar animates.
      add(name(event.side) .. " is hit\nwith recoil!", { hpSide = event.side, hp = event.hpRemaining })
    elseif event.type == "drain" then
      -- Real sText_PkmnEnergyDrained: "<mon> had its energy drained!" --
      -- real FireRed names the DEFENDER here (the mon the HP was drained
      -- FROM) in the MESSAGE, even though it's the attacker's own side
      -- whose HP bar actually changes (a real heal) -- hpSide must stay
      -- event.side (the attacker) despite the message naming the other side.
      add(name(otherSide(event.side)) .. " had its\nenergy drained!", { hpSide = event.side, hp = event.hpRemaining })
    elseif event.type == "multiHit" then
      -- Real sText_HitXTimes: "Hit N time(s)!" (battle_message.c:82),
      -- `hits` = hits landed. Never emitted on a no-effect stop (real
      -- BattleScript_MultiHitPrintStrings skips it). The 2-5 family,
      -- Double Kick, Twineedle and Triple Kick emit it after a KO too,
      -- before the caller's faint, as in source. For the resolveMultiHit
      -- families the effectiveness flags ride on this event, not on each
      -- damage event: source prints them once via MultiHitPrintStrings'
      -- resultmessage, just before the count (data/battle_scripts_1.s
      -- :645-649). Triple Kick's damage events still carry their own.
      if event.superEffective then add("It's super effective!") end
      if event.notVeryEffective then add("It's not very effective...") end
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
    elseif event.type == "screenSet" then
      -- Real sText_PkmnRaisedDef/sText_PkmnRaisedSpDef (src/battle_
      -- message.c): "<mon>'s REFLECT\nraised DEFENSE!" / "<mon>'s LIGHT
      -- SCREEN\nraised SP. DEF!" (single-battle B_MSG_SET_REFLECT_SINGLE/
      -- B_MSG_SET_LIGHTSCREEN_SINGLE variant -- the double-battle "a
      -- little" wording is out of scope, single battle only).
      if event.screen == "reflect" then
        add(possessive(name(event.side)) .. " REFLECT\nraised DEFENSE!")
      else
        add(possessive(name(event.side)) .. " LIGHT SCREEN\nraised SP. DEF!")
      end
    elseif event.type == "screenFailed" then
      -- Real B_MSG_SIDE_STATUS_FAILED -> sText_ButItFailed.
      add("But it failed!")
    elseif event.type == "screenExpired" then
      -- Real sText_PkmnsXWoreOff: "<side>'s REFLECT/LIGHT SCREEN\nwore
      -- off!" -- side-prefix wording mirrors this project's existing
      -- sText_TeamStoppedWorking/sText_FoeStoppedWorking pattern ("Your
      -- team's"/"The foe's") since B_ATK_PREFIX1 is the same real
      -- side-dependent prefix.
      local screenName = event.screen == "reflect" and "REFLECT" or "LIGHT SCREEN"
      local prefix = event.side == "player" and "Your team's" or "The foe's"
      add(prefix .. " " .. screenName .. "\nwore off!")
    elseif event.type == "fastAsleep" then
      -- Status canceller/end-of-turn texts: c75f352 src/battle_message.c
      -- line numbers in comments; scripts data/battle_scripts_1.s:3657-3718.
      add(name(event.side) .. " is fast\nasleep.") -- :162
    elseif event.type == "wokeUp" then
      add(name(event.side) .. " woke up!") -- :163
    elseif event.type == "frozenSolid" then
      add(name(event.side) .. " is\nfrozen solid!") -- :100
    elseif event.type == "thawed" then
      add(name(event.side) .. " was\ndefrosted!") -- :102 PKMNWASDEFROSTED2
    elseif event.type == "defrostedByMove" then
      add(name(event.side) .. " was\ndefrosted by " .. self.moveName(event.move) .. "!") -- :103
    elseif event.type == "fullyParalyzed" then
      add(name(event.side) .. " is paralyzed!\nIt can't move!") -- :106
    elseif event.type == "defrostedByFire" then
      add(name(event.side) .. " was\ndefrosted!") -- :101 PKMNWASDEFROSTED
    elseif event.type == "statusApplied" then
      -- sMoveEffectBS_Ptrs scripts (data/battle_scripts_1.s:3848-3881):
      -- text names the effect battler.
      local n = name(event.side)
      if event.kind == "poison" then add(n .. "\nwas poisoned!") -- :88
      elseif event.kind == "toxic" then add(n .. " is badly\npoisoned!") -- :92
      elseif event.kind == "burn" then add(n .. " was burned!") -- :94
      elseif event.kind == "freeze" then add(n .. " was\nfrozen solid!") -- :98
      elseif event.kind == "paralysis" then add(n .. " is paralyzed!\nIt may be unable to move!") -- :104
      elseif event.kind == "sleep" then add(n .. "\nfell asleep!") -- :83
      end
    elseif event.type == "statusPrevented" then
      -- B_MSG_ABILITY_PREVENTS_MOVE_STATUS texts (battle_message.c:270,272,
      -- 280) with gAbilityNames (src/data/text/abilities.h) for the three
      -- abilities that can reach them.
      local ability = STATUS_ABILITY_NAMES[event.ability] or "ABILITY"
      local who = possessive(name(event.side)) .. " " .. ability
      if event.kind == "burn" then add(who .. "\nprevents burns!")
      elseif event.kind == "paralysis" then add(who .. "\nprevents paralysis!")
      else add(who .. "\nprevents poisoning!")
      end
    elseif event.type == "statusAlready" then
      -- Primary status scripts' "already" branches (battle_message.c).
      local n = name(event.side)
      if event.kind == "sleep" then add(n .. " is\nalready asleep!") -- :85
      elseif event.kind == "paralysis" then add(n .. " is\nalready paralyzed!") -- :107
      elseif event.kind == "burn" then add(n .. " already\nhas a burn.") -- :97
      else add(n .. " is already\npoisoned.") -- :91 (poison and toxic)
      end
    elseif event.type == "stayedAwake" then
      -- sText_PkmnStayedAwakeUsing (:174) via jumpifcantmakeasleep.
      add(name(event.side) .. " stayed awake\nusing its " .. (STATUS_ABILITY_NAMES[event.ability] or "ABILITY") .. "!")
    elseif event.type == "statusCured" then
      add(possessive(name(event.side)) .. " status\nreturned to normal!") -- :222
    elseif event.type == "restSlept" then
      -- gRestUsedStringIds (battle_message.c:973-977): B_MSG_REST_STATUSED
      -- when trysetrest saw any of status1 bits 3-7.
      if event.statused then
        add(name(event.side) .. " slept and\nbecame healthy!") -- :134
      else
        add(name(event.side) .. " went\nto sleep!") -- :133
      end
    elseif event.type == "focusEnergy" then
      add(name(event.side) .. " is getting\npumped!") -- gBattleText_GetPumped :153
    elseif event.type == "paralysisHealed" then
      add(name(event.side) .. " was\nhealed of paralysis!") -- :108
    elseif event.type == "confusionApplied" then
      add(name(event.side) .. " became\nconfused!") -- battle_message.c:116
    elseif event.type == "fatigueConfusion" then
      add(name(event.side) .. " became\nconfused due to fatigue!") -- :177
    elseif event.type == "alreadyConfused" then
      add(name(event.side) .. " is\nalready confused!") -- :117
    elseif event.type == "confusionPrevented" then
      add(possessive(name(event.side)) .. " OWN TEMPO\nprevents confusion!") -- :273
    elseif event.type == "chargeTurn" then
      -- gFirstTurnOfTwoStringIds (battle_message.c:135-138).
      local n = name(event.side)
      if event.kind == "razorWind" then add(n .. " whipped\nup a whirlwind!")
      elseif event.kind == "solarBeam" then add(n .. " took\nin sunlight!")
      elseif event.kind == "skullBash" then add(n .. " lowered\nits head!")
      elseif event.kind == "fly" then add(n .. " flew\nup high!") -- :139
      elseif event.kind == "dig" then add(n .. " dug a hole!") -- :140
      elseif event.kind == "dive" then add(n .. " hid\nunderwater!") -- :141
      elseif event.kind == "bounce" then add(n .. " sprang up!") -- :142
      else add(n .. " is glowing!")
      end
    elseif event.type == "mustRecharge" then
      add(name(event.side) .. " must\nrecharge!") -- :185
    elseif event.type == "flinched" then
      add(name(event.side) .. " flinched!") -- battle_message.c:123
    elseif event.type == "confusedTurn" then
      add(name(event.side) .. " is\nconfused!") -- :114
    elseif event.type == "confusionSelfHit" then
      -- Text before the HP update (data/battle_scripts_1.s:3744-3751).
      add("It hurt itself in its\nconfusion!") -- :337
      entries[#entries + 1] = { hpSide = event.side, hp = event.hpRemaining }
    elseif event.type == "confusionEnded" then
      add(name(event.side) .. " snapped\nout of confusion!") -- :115
    elseif event.type == "weatherSet" then
      -- gMoveWeatherChangeStringIds (c75f352 src/battle_message.c:912-920).
      add(WEATHER_SET_TEXT[event.kind])
    elseif event.type == "weatherContinues" then
      -- ENDTURN_* (src/battle_util.c:624-711), gRainContinuesStringIds /
      -- gSandstormHailContinuesStringIds (battle_message.c:928-945).
      add(WEATHER_CONTINUES_TEXT[event.kind])
    elseif event.type == "weatherEnded" then
      add(WEATHER_ENDED_TEXT[event.kind])
    elseif event.type == "weatherDamage" then
      -- gSandstormHailDmgStringIds (:156-157), printed before datahpupdate
      -- (data/battle_scripts_1.s:3167-3173).
      if event.kind == "sandstorm" then
        add(name(event.side) .. " is buffeted\nby the sandstorm!")
      else
        add(name(event.side) .. " is pelted\nby HAIL!")
      end
      entries[#entries + 1] = { hpSide = event.side, hp = event.hpRemaining }
    elseif event.type == "rainDish" then
      -- STRINGID_PKMNSXRESTOREDHPALITTLE2 (c75f352 src/battle_message.c:283)
      -- with B_ATK_ABILITY = RAIN DISH (gBattlerAttacker is the holder,
      -- src/battle_util.c:1819), printed before datahpupdate
      -- (data/battle_scripts_1.s:3938-3944).
      add(possessive(name(event.side)) .. " RAIN DISH\nrestored its HP a little!")
      entries[#entries + 1] = { hpSide = event.side, hp = event.hpRemaining }
    elseif event.type == "weatherAbility" then
      -- BattleScript_DrizzleActivates/SandstreamActivates/DroughtActivates
      -- (data/battle_scripts_1.s:3918-3924, :3946-3952, :4013-4019);
      -- B_SCR_ACTIVE_NAME_WITH_PREFIX/B_SCR_ACTIVE_ABILITY name the holder.
      add(possessive(name(event.side)) .. " " .. (WEATHER_ABILITY_NAMES[event.ability] or "ABILITY")
        .. "\n" .. WEATHER_ABILITY_TEXT[event.kind])
    elseif event.type == "statusDamage" then
      -- Message before the HP update (printstring, then datahpupdate).
      if event.kind == "burn" then
        add(name(event.side) .. " is hurt\nby its burn!") -- :96
      else
        add(name(event.side) .. " is hurt\nby poison!") -- :90 (toxic too)
      end
      entries[#entries + 1] = { hpSide = event.side, hp = event.hpRemaining }
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
    if move and not self.engine:supportsMove(move, slot.move) then
      self:_setMessages({ { text = "That move's effect is not available yet." } },
        BattleSceneController.MOVE)
      return
    end
  end
  -- A locked foe (charging/recharging/rampaging) chooses nothing: no AI script, so no
  -- AI RNG (src/battle_main.c:3125-3130); the engine uses its locked move.
  local foeMoveSlot
  if self.engine.isLocked and self.engine:isLocked("foe") then
    foeMoveSlot = self.engine.foe.lockedSlot
  else
    foeMoveSlot = self.chooseFoeMove and self.chooseFoeMove(self.engine) or self.foeMoveSlot
  end
  local events = self.engine:runTurn(playerAction, { action = "move", moveSlot = foeMoveSlot })
  -- The engine has made the team-wide eligibility decision before it emits
  -- forcedSwitchNeeded.  Do not fall through to ACTION while that pending
  -- decision exists: a player faint with a legal bench must drain its
  -- messages and then enter the forced-only selector.
  local after = self.engine:isOver() and BattleSceneController.COMPLETE
    or (self.engine.awaitingForcedSwitch == "player" and BattleSceneController.PARTY)
    or BattleSceneController.ACTION
  self.actionCursor = 0
  self:_setMessages(self:_eventMessages(events), after)
end

function BattleSceneController:_refreshPartyChoices()
  local provider = self.partyMode == "forced" and self.forcedSwitchChoices
    or self.partyMode == "voluntary" and self.voluntarySwitchChoices
  local choices = provider and provider() or {}
  self.partyChoices = choices or {}
  if #self.partyChoices == 0 then
    self.partyCursor = 0
  else
    self.partyCursor = math.max(0, math.min(self.partyCursor, #self.partyChoices - 1))
  end
end

function BattleSceneController:_openVoluntarySwitch()
  -- Existing wild/developer controller callers have no save-backed bridge;
  -- preserve their bounded unavailable behavior rather than inventing a
  -- selector outside the trainer-only voluntary-switch contract.
  if not self.voluntarySwitchChoices then
    self:_setMessages({ { text = "POKEMON switching is not available yet." } }, BattleSceneController.ACTION)
    return
  end
  self.partyMode = "voluntary"
  self:_refreshPartyChoices()
  -- No legal bench means no engine action: turn, RNG, and active battler are
  -- unchanged. Do not show a selector that cannot make a legal choice.
  if #self.partyChoices == 0 then
    self.partyMode = nil
    self:_setMessages({ { text = "There are no other POKEMON!" } }, BattleSceneController.ACTION)
    return
  end
  self.state = BattleSceneController.PARTY
  self:_touch()
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
        self:_openVoluntarySwitch()
      end
    end
    return
  end

  if self.state == BattleSceneController.PARTY then
    -- Voluntary cancellation is always available, even if a previously
    -- displayed sole candidate became stale before this input. Forced
    -- replacement deliberately remains below the mode guard and cannot
    -- cancel into ACTION.
    if self.partyMode == "voluntary" and input:isNewlyPressed(InputState.B_BUTTON) then
      self.state = BattleSceneController.ACTION
      self.partyMode = nil
      self:_touch()
      return
    end
    -- Re-read the save-backed candidates each input.  This makes a stale,
    -- active, fainted, egg, or otherwise invalid choice unable to clear the
    -- pending engine state between the faint and the actual confirmation.
    self:_refreshPartyChoices()
    if #self.partyChoices == 0 then
      self:_touch()
      return
    end
    local before = self.partyCursor
    if input:isNewlyPressed(InputState.DPAD_UP) then
      self.partyCursor = (self.partyCursor + #self.partyChoices - 1) % #self.partyChoices
    elseif input:isNewlyPressed(InputState.DPAD_DOWN) then
      self.partyCursor = (self.partyCursor + 1) % #self.partyChoices
    end
    if self.partyCursor ~= before then self:_touch() end
    -- B/CANCEL intentionally does nothing for a forced replacement. A
    -- forced replacement may not cancel into ACTION or player loss.
    if input:isNewlyPressed(InputState.A_BUTTON) then
      local callback = self.partyMode == "forced" and self.onForcedSwitchChoice
        or self.partyMode == "voluntary" and self.onVoluntarySwitchChoice
      if callback then
        -- Revalidate the UI selection at the save-backed callback. A legal
        -- voluntary callback may call _runTurn, retaining engine ordering.
        local entries = callback(self.partyChoices[self.partyCursor + 1])
        local switchIn = self:_takeForcedSwitchMessages()
        if entries or #switchIn > 0 then
          self:_setMessages(concatEntries(entries, switchIn), BattleSceneController.ACTION)
        end
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
