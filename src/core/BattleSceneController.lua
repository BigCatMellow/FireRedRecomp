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
    elseif event.type == "substituteDamage" then
      add(name(event.target) .. "'s substitute\ntook the hit!")
    elseif event.type == "substituteBroken" then
      add(name(event.side) .. "'s substitute\nbroke!")
    elseif event.type == "substituteSet" then
      add(name(event.side) .. " put in\na substitute!", { hpSide = event.side, hp = event.hpRemaining })
    elseif event.type == "substituteFailed" then
      add("But it failed!")
    elseif event.type == "transform" then
      add(name(event.side) .. " transformed!")
    elseif event.type == "transformFailed" then
      add("But it failed!")
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
    elseif event.type == "sleep" or event.type == "yawnSleep" then
      add(name(event.target or event.side) .. " fell asleep!")
    elseif event.type == "sleepFailed" then
      add("But it failed!")
    elseif event.type == "asleep" then
      add(name(event.side) .. " is fast asleep.")
    elseif event.type == "wokeUp" then
      add(name(event.side) .. " woke up!")
    elseif event.type == "poison" then
      add(name(event.target) .. " was poisoned!")
    elseif event.type == "toxic" then
      add(name(event.target) .. " was badly poisoned!")
    elseif event.type == "poisonFailed" then
      add("But it failed!")
    elseif event.type == "poisonDamage" or event.type == "toxicDamage" then
      add(name(event.side) .. " is hurt\nby poison!", { hpSide=event.side, hp=event.hpRemaining })
    elseif event.type == "paralyze" then
      add(name(event.target) .. " is paralyzed!\nIt may be unable to move!")
    elseif event.type == "paralyzeFailed" then
      add("But it failed!")
    elseif event.type == "fullyParalyzed" then
      add(name(event.side) .. " is paralyzed!\nIt can't move!")
    elseif event.type == "paralysisCured" then
      add(name(event.side) .. " was cured of\nparalysis!")
    elseif event.type == "snoreFailed" then
      add("But it failed!")
    elseif event.type == "lockOn" then
      add(name(event.side) .. " took aim\nat " .. name(event.target) .. "!")
    elseif event.type == "nightmare" then
      add(name(event.target) .. " fell into\na NIGHTMARE!")
    elseif event.type == "nightmareFailed" then
      add("But it failed!")
    elseif event.type == "nightmareDamage" then
      add(name(event.side) .. " is locked in\na NIGHTMARE!", { hpSide=event.side, hp=event.hpRemaining })
    elseif event.type == "curse" then
      add(name(event.target) .. " was afflicted\nby a curse!")
    elseif event.type == "curseSelfDamage" then
      add(name(event.side) .. " cut its own HP\nand laid a curse!", { hpSide=event.side, hp=event.hpRemaining })
    elseif event.type == "curseDamage" then
      add(name(event.side) .. " is afflicted\nby the curse!", { hpSide=event.side, hp=event.hpRemaining })
    elseif event.type == "curseFailed" then
      add("But it failed!")
    elseif event.type == "trapped" then
      add(name(event.target) .. " can't escape\nnow!")
    elseif event.type == "trapDamage" then
      add(name(event.side) .. " is hurt\nby the trap!", { hpSide=event.side, hp=event.hpRemaining })
    elseif event.type == "trapEnded" or event.type == "trapCleared" then
      add(name(event.side) .. " was freed\nfrom the trap!")
    elseif event.type == "trapFailed" then
      add("But it failed!")
    elseif event.type == "foresight" then
      add(name(event.target) .. " was identified!")
    elseif event.type == "perishSong" then
      add("All active POKEMON will\nfaint in three turns!")
    elseif event.type == "perishSongFailed" then
      add("But it failed!")
    elseif event.type == "perishCount" then
      add(name(event.side) .. "'s perish count\nis " .. event.count .. "!")
    elseif event.type == "perishFaint" then
      add(name(event.side) .. " perished!", { hpSide=event.side, hp=0 })
    elseif event.type == "wish" then
      add(name(event.side) .. " made a wish!")
    elseif event.type == "wishHeal" then
      add(name(event.side) .. "'s wish came true!", { hpSide=event.side, hp=event.hpRemaining })
    elseif event.type == "wishFailed" then
      add(event.fullHP and name(event.side) .. "'s wish came true!" or "But it failed!")
    elseif event.type == "grudge" then
      add(name(event.side) .. " wants revenge!")
    elseif event.type == "grudgeFailed" then
      add("But it failed!")
    elseif event.type == "grudgePP" then
      add(name(event.side) .. " lost all its PP\ndue to the GRUDGE!")
    elseif event.type == "destinyBond" then
      add(name(event.side) .. " is trying to take\nthe foe with it!")
    elseif event.type == "destinyBondKO" then
      add(name(event.side) .. " took " .. name(event.target) .. "\nwith it!")
    elseif event.type == "mimic" then
      add(name(event.side) .. " learned\n" .. self.moveName(event.move) .. "!")
    elseif event.type == "mimicFailed" then
      add("But it failed!")
    elseif event.type == "sketch" then
      add(name(event.side) .. " sketched\n" .. self.moveName(event.move) .. "!")
    elseif event.type == "sketchFailed" or event.type == "sleepTalkFailed" then
      add("But it failed!")
    elseif event.type == "attract" then
      add(name(event.target) .. " fell in love!")
    elseif event.type == "attractFailed" then
      add("But it failed!")
    elseif event.type == "infatuated" then
      add(name(event.side) .. " is in love\nwith " .. name(event.source) .. "!")
    elseif event.type == "loveImmobility" then
      add(name(event.side) .. " is immobilized\nby love!")
    elseif event.type == "camouflage" then
      add(name(event.side) .. " changed its type!")
    elseif event.type == "camouflageFailed" then
      add("But it failed!")
    elseif event.type == "naturePower" then
      add("Nature Power turned into\n" .. self.moveName(event.move) .. "!")
    elseif event.type == "naturePowerFailed" then
      add("But it failed!")
    elseif event.type == "burn" then
      add(name(event.target) .. " was burned!")
    elseif event.type == "burnFailed" then
      add("But it failed!")
    elseif event.type == "burnDamage" then
      add(name(event.side) .. " is hurt\nby its burn!", { hpSide=event.side, hp=event.hpRemaining })
    elseif event.type == "freeze" then
      add(name(event.target) .. " was frozen solid!")
    elseif event.type == "frozen" then
      add(name(event.side) .. " is frozen solid!")
    elseif event.type == "thawed" then
      add(name(event.side) .. " thawed out!")
    elseif event.type == "confuse" then
      add(name(event.target) .. " became confused!")
    elseif event.type == "confuseFailed" then
      add("But it failed!")
    elseif event.type == "confuseStatFailed" then
      add("But it failed!")
    elseif event.type == "confused" then
      add(name(event.side) .. " is confused!")
    elseif event.type == "confusionSelfHit" then
      add("It hurt itself in\nits confusion!", { hpSide=event.side, hp=event.hpRemaining })
    elseif event.type == "snappedOut" then
      add(name(event.side) .. " snapped out\nof confusion!")
    elseif event.type == "flinched" then
      add(name(event.side) .. " flinched and\ncouldn't move!")
    elseif event.type == "ingrain" then
      add(name(event.side) .. " planted its roots!")
    elseif event.type == "ingrainFailed" then
      add("But it failed!")
    elseif event.type == "ingrainHeal" then
      add(name(event.side) .. " absorbed nutrients\nwith its roots!", { hpSide=event.side, hp=event.hpRemaining })
    elseif event.type == "leechSeed" then
      add(name(event.target) .. " was seeded!")
    elseif event.type == "leechSeedFailed" then
      add("But it failed!")
    elseif event.type == "leechSeedDrain" then
      add(name(event.side) .. " is sapped\nby LEECH SEED!", { hpSide=event.side, hp=event.hpRemaining })
      entries[#entries + 1] = { hpSide=event.target, hp=event.targetHpRemaining }
    elseif event.type == "yawn" then
      add(name(event.target) .. " grew drowsy!")
    elseif event.type == "yawnFailed" then
      add("But it failed!")
    elseif event.type == "rest" then
      add(name(event.side) .. " went to sleep and\nrestored its health!", { hpSide=event.side, hp=event.hpRemaining })
    elseif event.type == "restFailed" then
      add("But it failed!")
    elseif event.type == "refresh" then
      add(name(event.side) .. " became healthy!")
    elseif event.type == "refreshFailed" then
      add("But it failed!")
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
      local text = event.kind == "dreamEater"
        and (possessive(name(otherSide(event.side))) .. " dream\nwas eaten!")
        or (name(otherSide(event.side)) .. " had its\nenergy drained!")
      add(text, { hpSide = event.side, hp = event.hpRemaining })
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
    elseif event.type == "teleport" then
      add(name(event.side) .. " fled from the\nbattle!")
    elseif event.type == "teleportFailed" then
      add("But it failed!")
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
    elseif event.type == "haze" then
      -- Real STRINGID_STATCHANGESGONE, emitted unconditionally after
      -- Cmd_normalisebuffs resets both battlers' seven stage values.
      add("All stat changes were\neliminated!")
    elseif event.type == "focusEnergySet" then
      -- Real gBattleText_GetPumped / B_MSG_GETTING_PUMPED.
      add(name(event.side) .. " is getting\npumped!")
    elseif event.type == "focusEnergyFailed" then
      -- Real B_MSG_FOCUS_ENERGY_FAILED -> sText_ButItFailed.
      add("But it failed!")
    elseif event.type == "protectSet" then
      add(name(event.side) .. " protected\nitself!")
    elseif event.type == "protectFailed" then
      add("But it failed!")
    elseif event.type == "endureSet" then
      add(name(event.side) .. " braced\nitself!")
    elseif event.type == "endureFailed" then
      add("But it failed!")
    elseif event.type == "endured" then
      add(name(event.side) .. " endured the hit!")
    elseif event.type == "protected" then
      add(name(event.side) .. " protected\nitself!")
    elseif event.type == "spikesSet" then
      add("SPIKES were scattered all around\nthe opponent's side!")
    elseif event.type == "spikesFailed" then
      add("But it failed!")
    elseif event.type == "spikesDamage" then
      add(name(event.side) .. " is hurt\nby SPIKES!")
    elseif event.type == "spikesCleared" then
      add(name(event.side) .. " blew away\nSPIKES!")
    elseif event.type == "magnitude" then
      add("Magnitude " .. event.magnitude .. "!")
    elseif event.type == "screensShattered" then
      add("The wall shattered!")
    elseif event.type == "heal" then
      add(name(event.side) .. " regained\nhealth!")
    elseif event.type == "healFailed" then
      add("But it failed!")
    elseif event.type == "bellyDrum" then
      add(name(event.side) .. " cut its HP and\nmaxed out ATTACK!")
    elseif event.type == "bellyDrumFailed" then
      add("But it failed!")
    elseif event.type == "psychUp" then
      add(name(event.side) .. " copied the foe's\nstat changes!")
    elseif event.type == "painSplit" then
      add("The battlers shared\ntheir pain!")
    elseif event.type == "painSplitFailed" then
      add("But it failed!")
    elseif event.type == "counterFailed" then
      add("But it failed!")
    elseif event.type == "bideStart" or event.type == "bideStore" then
      add(name(event.side) .. " is storing\nenergy!")
    elseif event.type == "bideRelease" then
      add(name(event.side) .. " unleashed\nenergy!")
    elseif event.type == "bideFailed" or event.type == "presentFailed"
        or event.type == "spiteFailed" or event.type == "conversionFailed"
        or event.type == "mementoFailed" then
      add("But it failed!")
    elseif event.type == "presentHeal" then
      add(name(event.target) .. " regained\nhealth!")
    elseif event.type == "rageBuilding" then
      add(name(event.side) .. "'s RAGE is\nbuilding!")
    elseif event.type == "splash" then
      add("But nothing happened!")
    elseif event.type == "spite" then
      add(name(event.target) .. "'s PP was\nreduced!")
    elseif event.type == "conversion" then
      add(name(event.side) .. " changed its\ntype!")
    elseif event.type == "ohkoFailed" then
      add("But it failed!")
    elseif event.type == "focusPunchLostFocus" then
      add(name(event.side) .. " lost its focus\nand couldn't move!")
    elseif event.type == "fakeOutFailed" then
      add("But it failed!")
    elseif event.type == "recharging" then
      add(name(event.side) .. " must recharge!")
    elseif event.type == "chargeSet" then
      add(name(event.side) .. " is charging\npower!")
    elseif event.type == "semiInvulnerableCharge" then
      local texts = { air="flew up high!", underground="dug underground!", underwater="hid underwater!" }
      add(name(event.side) .. " " .. texts[event.kind])
    elseif event.type == "semiInvulnerableMiss" then
      add("The attack missed!")
    elseif event.type == "futureSightSet" then
      add(name(event.side) .. " foresaw an\nattack!")
    elseif event.type == "futureSightHit" then
      add(name(event.target) .. " took the\nfuture attack!")
    elseif event.type == "futureSightFailed" or event.type == "futureSightMiss" then
      add("But it failed!")
    elseif event.type == "uproarSet" or event.type == "uproarContinues" then
      add(name(event.side) .. " is causing\nan UPROAR!")
    elseif event.type == "uproarWake" then
      add(name(event.target) .. " woke up in\nthe UPROAR!")
    elseif event.type == "uproarEnded" then
      add(name(event.side) .. " calmed down.")
    elseif event.type == "stockpile" then
      add(name(event.side) .. " stockpiled\nenergy!")
    elseif event.type == "stockpileFailed" or event.type == "spitUpFailed" or event.type == "swallowFailed" then
      add("But it failed!")
    elseif event.type == "swallow" then
      add(name(event.side) .. " regained\nhealth!")
    elseif event.type == "tormentSet" then
      add(name(event.target) .. " was subjected\nto TORMENT!")
    elseif event.type == "tormentFailed" then
      add("But it failed!")
    elseif event.type == "tormented" then
      add(name(event.side) .. " can't use the\nsame move twice!")
    elseif event.type == "imprisonSet" then
      add(name(event.side) .. " sealed the foe's\nmove!")
    elseif event.type == "imprisonFailed" then
      add("But it failed!")
    elseif event.type == "imprisoned" then
      add(name(event.side) .. "'s move is\nsealed!")
    elseif event.type == "encoreSet" then
      add(name(event.target) .. " got an\nENCORE!")
    elseif event.type == "encoreFailed" then
      add("But it failed!")
    elseif event.type == "encoreEnded" then
      add(name(event.side) .. "'s ENCORE\nended!")
    elseif event.type == "disableSet" then
      add(name(event.target) .. "'s move was\nDISABLED!")
    elseif event.type == "disableFailed" then
      add("But it failed!")
    elseif event.type == "disabled" then
      add(name(event.side) .. "'s move is\ndisabled!")
    elseif event.type == "disableEnded" then
      add(name(event.side) .. "'s DISABLE\nended!")
    elseif event.type == "tauntSet" then
      add(name(event.target) .. " fell for the\nTAUNT!")
    elseif event.type == "tauntFailed" then
      add("But it failed!")
    elseif event.type == "taunted" then
      add(name(event.side) .. " can't use that\nmove after TAUNT!")
    elseif event.type == "tauntEnded" then
      add(name(event.side) .. "'s TAUNT wore off!")
    elseif event.type == "sportSet" then
      add(event.sport == "mud" and "Electricity's power\nwas weakened!" or "Fire's power\nwas weakened!")
    elseif event.type == "sportFailed" then
      add("But it failed!")
    elseif event.type == "weatherSet" then
      local texts = { rain="It started to rain!", sun="The sunlight got bright!", sandstorm="A sandstorm brewed!", hail="It started to hail!" }
      add(texts[event.weather])
    elseif event.type == "weatherFailed" then
      add("But it failed!")
    elseif event.type == "weatherContinues" then
      local texts = { rain="Rain continues to fall.", sun="The sunlight is strong.", sandstorm="The sandstorm rages.", hail="Hail continues to fall." }
      add(texts[event.weather])
    elseif event.type == "weatherExpired" then
      local texts = { rain="The rain stopped.", sun="The sunlight faded.", sandstorm="The sandstorm subsided.", hail="The hail stopped." }
      add(texts[event.weather])
    elseif event.type == "weatherDamage" then
      add(event.weather == "sandstorm" and (name(event.side) .. " is buffeted\nby the sandstorm!") or (name(event.side) .. " is pelted\nby hail!"))
    elseif event.type == "sideStatusSet" and event.status == "mist" then
      add(name(event.side) .. " is protected\nby MIST!")
    elseif event.type == "sideStatusSet" and event.status == "safeguard" then
      add(name(event.side) .. " is protected\nby SAFEGUARD!")
    elseif event.type == "sideStatusFailed" then
      add("But it failed!")
    elseif event.type == "sideStatusExpired" and event.status == "mist" then
      add(possessive(name(event.side)) .. " MIST\nwore off!")
    elseif event.type == "sideStatusExpired" and event.status == "safeguard" then
      add(possessive(name(event.side)) .. " SAFEGUARD\nprotected it no more!")
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
