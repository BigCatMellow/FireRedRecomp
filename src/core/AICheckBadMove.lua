-- Native port of the real AI_CheckBadMove AI script (data/battle_ai_scripts.s
-- :52-602), the script that runs for aiFlags bit AI_SCRIPT_CHECK_BAD_MOVE
-- (0x1, include/constants/battle_ai.h:37). Consumed by TrainerAI.lua, which
-- adds the resulting per-move score to the real base-100 (see
-- BattleAI_ChooseMoveOrAction, src/battle_ai_script_commands.c:299-300, and
-- TrainerAI.lua's own header for the already-verified aggregate loop this
-- plugs into).
--
-- SCOPE (why this exists as its own module and not more branches in
-- TrainerAI.lua): AI_CheckBadMove is not one check, it's a real interpreted
-- AI-script VM script (src/battle_ai_script_commands.c is that VM's own
-- opcode table -- a different bytecode/interpreter from this project's
-- overworld ScriptInterpreter.lua/ScriptBytecode.lua) with an ~80-entry
-- `if_effect` dispatch chain, most of whose targets alias a much smaller set
-- of shared AI_CBM_* sub-routines. This module ports that VM's real
-- semantics natively (in the same spirit EarlyRivalAI.lua already does for
-- its own bounded move set), one Lua function per real distinct sub-routine,
-- keyed off a Lua table mirroring the real if_effect dispatch chain rather
-- than one branch per effect id.
--
-- REAL SCRIPT STRUCTURE, in real execution order (data/battle_ai_scripts.s
-- :52-104):
--   1. get_how_powerful_move_is; if_equal MOVE_POWER_DISCOURAGED, jump past
--      the whole type-immunity/ability-cancel section straight to the
--      Soundproof check. Real Cmd_get_how_powerful_move_is
--      (src/battle_ai_script_commands.c:966) returns MOVE_POWER_DISCOURAGED
--      (0) whenever move.power <= 1 (status moves) OR move.effect is one of
--      the 12 ids in the real sDiscouragedPowerfulMoveEffects[] table (same
--      file, line 245) -- ported verbatim as DISCOURAGED_POWERFUL_EFFECTS
--      below. Only real damaging moves outside that list reach the
--      immunity/ability-cancel section at all.
--   2. AI_CBM_CheckIfNegatesType (only reached per #1): if_type_effectiveness
--      AI_EFFECTIVENESS_x0 -> Score_Minus10 (script ends here, full stop --
--      every real Score_MinusN sub-label is `score -N; end`, so ANY matching
--      branch below skips the rest of the whole script, not just its own
--      section); else get_ability AI_TARGET and check Volt Absorb/Water
--      Absorb/Flash Fire (each: matching move type -> Score_Minus12, else
--      continue), Wonder Guard (NOT super-effective-or-better ->
--      Score_Minus10, else continue), Levitate (Ground-type move ->
--      Score_Minus10, else continue). No ability match, or an ability match
--      whose extra type condition fails, falls through to step 3
--      unconditionally (real `goto AI_CheckBadMove_CheckSoundproof` at the
--      end of the if_equal chain, data/battle_ai_scripts.s:66).
--   3. AI_CheckBadMove_CheckSoundproof (ALWAYS reached, regardless of #1):
--      get_ability AI_TARGET; if ABILITY_SOUNDPROOF and the move is one of
--      the 9 real sound moves (Growl/Roar/Sing/Supersonic/Screech/Snore/
--      Uproar/Metal Sound/Grass Whistle, data/battle_ai_scripts.s:94-102) ->
--      Score_Minus10.
--   4. AI_CheckBadMove_CheckEffect (ALWAYS reached): the real ~80-entry
--      if_effect dispatch (data/battle_ai_scripts.s:105-213) -> one of the
--      ~35 real AI_CBM_* sub-routines, ported below as EFFECT_HANDLERS. A
--      move whose effect id is NOT one of the ~80 listed falls straight to
--      the chain's trailing plain `end` (line 214) -- CONFIRMED real zero
--      penalty, not an approximation (see AICheckBadMove.score's final
--      fallback and the module-level test for this).
--
-- get_ability AI_TARGET SIMPLIFICATION (applies to every ability check
-- below): real Cmd_get_ability (src/battle_ai_script_commands.c:1138-1196),
-- when asking about the opponent (AI_TARGET, always the player from this
-- foe-choosing module's point of view -- TrainerAI.choose only ever picks
-- the FOE's move), does NOT know the player's true ability with certainty.
-- It only returns a species' second ability for sure once BATTLE_HISTORY
-- has recorded it being used (not modeled here) or for the three abilities
-- that "prevent fleeing" (Shadow Tag/Magnet Pull/Arena Trap, not relevant to
-- any check ported here); otherwise, for a species with two possible
-- abilities, it GUESSES uniformly via a live `Random() % 2` (RNG-consuming).
-- Porting that guess bit-exactly would require tracking a BATTLE_HISTORY
-- struct this project has nowhere else and consuming an extra unseeded-here
-- Random() per ability check -- out of scope for this pass. This module
-- instead reads the target battler's real, already-known `.ability` field
-- (populated by BattlePartyBridge.lua:147-148/169-170 from the decoded save
-- data) directly, i.e. the AI is never wrong about the opponent's ability.
-- This is a deliberate, real-behavior-adjacent simplification (not a silent
-- gap): it can only make this AI's play MORE accurate than real FireRed's
-- (which sometimes guesses wrong), never less, and for the large majority of
-- early-game species with only one possible ability the real guess and this
-- port agree with certainty anyway (Cmd_get_ability's single-ability branch,
-- line 1180, has no randomness at all).
--
-- CONFIRMED NO-OP CLASS: this engine (see BattleEngine.lua's header, "No
-- status conditions, abilities, held items, weather... or double battles")
-- has no code path that ever sets status1/status2/status3, weather, or any
-- sideStatus beyond reflect/lightScreen, and no held-item or stockpile-
-- counter state at all. Several real AI_CBM_* branches test exactly those
-- fields (if_status/if_status2/if_status3/get_weather/if_side_affecting for
-- Mist/Spikes/Safeguard/FutureAttack/get_used_held_item/
-- get_stockpile_count). Because this engine structurally can never produce
-- the "true" case for any of those conditions, the real branch's "false"
-- side is not a guess here -- it is a provable fact about this engine's
-- state space, exactly analogous to the real dispatch chain's own
-- confirmed no-penalty fallback for a listed-but-absent effect. Each such
-- branch below is ported as `alwaysNoPenalty` (or, where the real check is
-- the NEGATION of an always-false condition -- e.g. "if user is NOT
-- asleep" -- as an always-applied fixed penalty) with its own citation, not
-- silently folded into the generic unhandled-effect fallback.
--
-- REAL GAPS deliberately left unported (fail loudly -- see
-- AICheckBadMove.score's UNPORTED_EFFECTS check): EFFECT_EXPLOSION (7),
-- EFFECT_ROAR (28), EFFECT_BATON_PASS (127), EFFECT_MEMENTO (168, whose real
-- label falls straight through into AI_CBM_BatonPass's own check with no
-- `end` between them, data/battle_ai_scripts.s:486-493) all real-branch on
-- `count_alive_pokemon` (src/battle_ai_script_commands.c:1080), a live
-- party-alive count this engine has no access to (BattleEngine only exposes
-- an optional per-side `hasReplacement(side)->boolean` callback, not a
-- count, and TrainerAI has no reference to it at all). EFFECT_ATTRACT (120)
-- real-branches on `get_gender` (src/battle_ai_script_commands.c:1764),
-- which no battler table in this project populates. EFFECT_FAKE_OUT (158)
-- real-branches on `is_first_turn_for` (src/battle_ai_script_commands.c
-- :1778), a per-battler "turns since this mon was sent out" counter this
-- engine's voluntary/forced-switch support does not track (turn count alone
-- is not equivalent once switching exists). These effects are real,
-- reachable, and IN the dispatch list -- encountering one is a genuine
-- unported gap, not a confirmed no-op, so AICheckBadMove.score errors
-- loudly for them rather than silently returning 0.

local BattleFormulas = require("src.core.BattleFormulas")
local BattleEngine = require("src.core.BattleEngine")

local AICheckBadMove = {}

-- Real AI_EFFECTIVENESS_* bucket values (include/constants/battle_ai.h
-- :18-23).
local X0, X0_25, X0_5, X1, X2, X4 = 0, 10, 20, 40, 80, 160

-- Real ability ids (include/constants/abilities.h).
local ABILITY_STURDY = 5
local ABILITY_DAMP = 6
local ABILITY_LIMBER = 7
local ABILITY_VOLT_ABSORB = 10
local ABILITY_WATER_ABSORB = 11
local ABILITY_INSOMNIA = 15
local ABILITY_IMMUNITY = 17
local ABILITY_FLASH_FIRE = 18
local ABILITY_OWN_TEMPO = 20
local ABILITY_WONDER_GUARD = 25
local ABILITY_LEVITATE = 26
local ABILITY_CLEAR_BODY = 29
local ABILITY_WATER_VEIL = 41
local ABILITY_SOUNDPROOF = 43
local ABILITY_KEEN_EYE = 51
local ABILITY_HYPER_CUTTER = 52
local ABILITY_STICKY_HOLD = 60
local ABILITY_VITAL_SPIRIT = 72
local ABILITY_WHITE_SMOKE = 73

-- Real type ids (include/constants/pokemon.h).
local TYPE_POISON = 3
local TYPE_GROUND = 4
local TYPE_STEEL = 8
local TYPE_FIRE = 10
local TYPE_WATER = 11
local TYPE_GRASS = 12
local TYPE_ELECTRIC = 13

-- Real move ids for the Soundproof sound-move list
-- (data/battle_ai_scripts.s:94-102, include/constants/moves.h).
local SOUNDPROOF_MOVES = {
  [45] = true,  -- MOVE_GROWL
  [46] = true,  -- MOVE_ROAR
  [47] = true,  -- MOVE_SING
  [48] = true,  -- MOVE_SUPERSONIC
  [103] = true, -- MOVE_SCREECH
  [173] = true, -- MOVE_SNORE
  [253] = true, -- MOVE_UPROAR
  [319] = true, -- MOVE_METAL_SOUND
  [320] = true, -- MOVE_GRASS_WHISTLE
}

-- Real sDiscouragedPowerfulMoveEffects[] (src/battle_ai_script_commands.c
-- :245-260), consulted only by Cmd_get_how_powerful_move_is.
local DISCOURAGED_POWERFUL_EFFECTS = {
  [7] = true,   -- EFFECT_EXPLOSION
  [8] = true,   -- EFFECT_DREAM_EATER
  [39] = true,  -- EFFECT_RAZOR_WIND
  [75] = true,  -- EFFECT_SKY_ATTACK
  [80] = true,  -- EFFECT_RECHARGE
  [145] = true, -- EFFECT_SKULL_BASH
  [151] = true, -- EFFECT_SOLAR_BEAM
  [161] = true, -- EFFECT_SPIT_UP
  [170] = true, -- EFFECT_FOCUS_PUNCH
  [182] = true, -- EFFECT_SUPERPOWER
  [190] = true, -- EFFECT_ERUPTION
  [204] = true, -- EFFECT_OVERHEAT
}

-- Real gTypeEffectiveness-driven classification (Cmd_if_type_effectiveness,
-- src/battle_ai_script_commands.c:1240-1274). The real function seeds
-- gBattleMoveDamage at AI_EFFECTIVENESS_x1 (40) and runs it through the same
-- TypeCalc STAB + per-row walk this project's BattleFormulas.typeCalc
-- already ports, then remaps the STAB-adjusted intermediate values (120,
-- 240, 30, 15) back onto the plain buckets (80, 160, 20, 10). Because that
-- remap exists SOLELY to fold the STAB case back onto the same bucket the
-- non-STAB case already lands on exactly (verified arithmetically: 40 *
-- 15/10 * mult/10, for every real per-row mult in {0,5,10,20}, reduces to
-- the same bucket as 40 * mult/10 alone after the 120/240/30/15 remap), the
-- real classification is provably STAB-independent -- so this port skips
-- STAB entirely (attackerTypes = {-1,-1}, which cannot match moveType) and
-- reads the resulting typeCalc damage value directly as the bucket, with
-- flags.noEffect forced to AI_EFFECTIVENESS_x0 exactly like the real
-- function's `gMoveResultFlags & MOVE_RESULT_DOESNT_AFFECT_FOE` override.
local function classifyEffectiveness(moveType, defenderTypes, typeChart)
  local damage, flags = BattleFormulas.typeCalc(X1, moveType, { -1, -1 }, defenderTypes, typeChart)
  if flags.noEffect then return X0 end
  return damage
end

local function hpPercent(battler)
  return math.floor(100 * battler.hp / battler.maxHP)
end

------------------------------------------------------------------------
-- AI_CBM_* sub-routine ports. Each handler takes (user, target, move,
-- typeChart) -- user is always AI_USER (the foe choosing its move), target
-- is always AI_TARGET (the player) -- and returns the real score delta
-- (<=0) this move's turn should apply, or 0 for "no penalty".
------------------------------------------------------------------------

-- AI_CBM_HighRiskForDamage (data/battle_ai_scripts.s:372-380). Real shared
-- sink for every "big risk to the user if it whiffs/is resisted" damaging
-- effect (Bide, Razor Wind, Super Fang, Recharge-locked moves, Psywave,
-- Counter, Flail, Return/Frustration/Present, Sonic Boom, Mirror Coat, Skull
-- Bash, Focus Punch, Superpower, Endeavor, Low Kick).
local function highRiskForDamage(user, target, move, typeChart)
  local eff = classifyEffectiveness(move.type, target.types, typeChart)
  if eff == X0 then return -10 end
  if target.ability == ABILITY_WONDER_GUARD and eff ~= X2 then return -10 end
  return 0
end

-- AI_CBM_Magnitude (data/battle_ai_scripts.s:368-372): Levitate check, then
-- falls straight through (no real `end`) into AI_CBM_HighRiskForDamage.
local function magnitude(user, target, move, typeChart)
  if target.ability == ABILITY_LEVITATE then return -10 end
  return highRiskForDamage(user, target, move, typeChart)
end

-- AI_CBM_AttackUp/DefenseUp/.../EvasionUp family (data/battle_ai_scripts.s
-- :250-276): real MAX_STAT_STAGE=12 already-maxed check, shared verbatim
-- across every stat-up effect id and its "_2" (2-stage) sibling.
local function statUp(statKey)
  return function(user, target, move, typeChart)
    if user.statStages[statKey] == 12 then return -10 end
    return 0
  end
end

-- AI_CBM_AttackDown/.../EvasionDown + CheckIfAbilityBlocksStatChange
-- (data/battle_ai_scripts.s:278-315): real already-at-0 check, an optional
-- stat-specific immunity ability (Hyper Cutter for Attack, Keen Eye for
-- Accuracy), then the shared Clear Body/White Smoke tail every stat-down
-- effect falls through into.
local function statDown(statKey, specificAbility)
  return function(user, target, move, typeChart)
    if target.statStages[statKey] == 0 then return -10 end
    if specificAbility and target.ability == specificAbility then return -10 end
    if target.ability == ABILITY_CLEAR_BODY or target.ability == ABILITY_WHITE_SMOKE then
      return -10
    end
    return 0
  end
end

-- AI_CBM_Sleep (data/battle_ai_scripts.s:216-222). Real `if_status AI_TARGET
-- STATUS1_ANY` (target already has ANY status) is a confirmed no-op here --
-- see module header's "CONFIRMED NO-OP CLASS".
local function sleep(user, target, move, typeChart)
  if target.ability == ABILITY_INSOMNIA or target.ability == ABILITY_VITAL_SPIRIT then
    return -10
  end
  return 0
end

-- AI_CBM_DreamEater (data/battle_ai_scripts.s:242-245): real first branch
-- `if_not_status AI_TARGET STATUS1_SLEEP, Score_Minus8` ends the script
-- immediately on a match. Target status1 can never contain STATUS1_SLEEP in
-- this engine (see module header), so "target is NOT asleep" is always
-- true -- this is ALWAYS -8, and the real second line (type-x0 check) is
-- real dead code in that case, so it is never reached here either.
local function dreamEater(user, target, move, typeChart)
  return -8
end

-- AI_CBM_Nightmare (data/battle_ai_scripts.s:237-240): real first branch
-- (status2 nightmare already set) is a confirmed no-op; real second branch
-- `if_not_status AI_TARGET STATUS1_SLEEP, Score_Minus8` is -- same as
-- DreamEater above -- always true in this engine, so this is ALWAYS -8.
local function nightmare(user, target, move, typeChart)
  return -8
end

-- AI_CBM_Poison/Toxic (data/battle_ai_scripts.s:344-355). Real
-- `if_status AI_TARGET STATUS1_ANY` tail is a confirmed no-op.
local function poison(user, target, move, typeChart)
  if target.types[1] == TYPE_STEEL or target.types[1] == TYPE_POISON
      or target.types[2] == TYPE_STEEL or target.types[2] == TYPE_POISON then
    return -10
  end
  if target.ability == ABILITY_IMMUNITY then return -10 end
  return 0
end

-- AI_CBM_Paralyze (data/battle_ai_scripts.s:401-407). Real `if_status
-- AI_TARGET STATUS1_ANY` tail is a confirmed no-op.
local function paralyze(user, target, move, typeChart)
  local eff = classifyEffectiveness(move.type, target.types, typeChart)
  if eff == X0 then return -10 end
  if target.ability == ABILITY_LIMBER then return -10 end
  return 0
end

-- AI_CBM_Confuse (data/battle_ai_scripts.s:390-395). Real
-- `if_status2 AI_TARGET STATUS2_CONFUSION` (already confused) is a
-- confirmed no-op.
local function confuse(user, target, move, typeChart)
  if target.ability == ABILITY_OWN_TEMPO then return -10 end
  return 0
end

-- AI_CBM_OneHitKO (data/battle_ai_scripts.s:361-366). Real `if_level_cond 1`
-- is `if_target_higher_level` (asm/macros/battle_ai_script.inc:537-539):
-- real OHKO moves fail outright against a higher-level target.
local function oneHitKO(user, target, move, typeChart)
  local eff = classifyEffectiveness(move.type, target.types, typeChart)
  if eff == X0 then return -10 end
  if target.ability == ABILITY_STURDY then return -10 end
  if target.level > user.level then return -10 end
  return 0
end

-- AI_CBM_Reflect/LightScreen (data/battle_ai_scripts.s:357-359,397-399):
-- unlike most side-status checks, THIS engine really does model
-- reflect/lightScreen (BattleEngine.new's sideStatus table) -- ported
-- against the real data, not folded into the "confirmed no-op" class.
local function reflect(user, target, move, typeChart, sideStatus)
  if sideStatus[BattleEngine.SIDE_FOE].reflect then return -8 end
  return 0
end

local function lightScreen(user, target, move, typeChart, sideStatus)
  if sideStatus[BattleEngine.SIDE_FOE].lightScreen then return -8 end
  return 0
end

-- AI_CBM_Substitute (data/battle_ai_scripts.s:409-412). Real first branch
-- (status2 substitute already up) is a confirmed no-op; the HP guard is
-- real data this engine has.
local function substitute(user, target, move, typeChart)
  if hpPercent(user) < 26 then return -10 end
  return 0
end

-- AI_CBM_LeechSeed (data/battle_ai_scripts.s:414-420). Real
-- `if_status3 AI_TARGET STATUS3_LEECHSEED` (already seeded) is a confirmed
-- no-op.
local function leechSeed(user, target, move, typeChart)
  if target.types[1] == TYPE_GRASS or target.types[2] == TYPE_GRASS then return -10 end
  return 0
end

-- AI_CBM_DamageDuringSleep (Snore/Sleep Talk, data/battle_ai_scripts.s
-- :430-432): real `if_not_status AI_USER STATUS1_SLEEP, Score_Minus8`. The
-- user's own status1 can never contain STATUS1_SLEEP in this engine, so
-- "user is NOT asleep" is always true -- this is ALWAYS -8 (using
-- Snore/Sleep Talk while never actually asleep really is a bad move, and
-- this engine can never make the user asleep, so that real branch always
-- fires here).
local function damageDuringSleep(user, target, move, typeChart)
  return -8
end

-- AI_CBM_Curse/CosmicPower/BulkUp/CalmMind/DragonDance/Tickle
-- (data/battle_ai_scripts.s:438-441,486-489,575-602): a shared "two
-- already-maxed/zeroed stat stages" shape, real stage checks evaluated in
-- order (the first match ends the script; -10 always shadows -8).
local function twoStatPenalty(battler, statA, targetValueA, penaltyA, statB, targetValueB, penaltyB)
  if battler.statStages[statA] == targetValueA then return penaltyA end
  if battler.statStages[statB] == targetValueB then return penaltyB end
  return 0
end

local function curse(user, target, move, typeChart)
  return twoStatPenalty(user, "attack", 12, -10, "defense", 12, -8)
end
local function cosmicPower(user, target, move, typeChart)
  return twoStatPenalty(user, "defense", 12, -10, "spDefense", 12, -8)
end
local function bulkUp(user, target, move, typeChart)
  return twoStatPenalty(user, "attack", 12, -10, "defense", 12, -8)
end
local function calmMind(user, target, move, typeChart)
  return twoStatPenalty(user, "spAttack", 12, -10, "spDefense", 12, -8)
end
local function dragonDance(user, target, move, typeChart)
  return twoStatPenalty(user, "attack", 12, -10, "speed", 12, -8)
end
local function tickle(user, target, move, typeChart)
  return twoStatPenalty(target, "attack", 0, -10, "defense", 0, -8)
end

-- AI_CBM_Haze/PsychUp (data/battle_ai_scripts.s:317-335): real script
-- checks all 7 of the user's own stat stages are NOT lowered (<6 ends the
-- script with no penalty) and all 7 of the target's are NOT raised (>6
-- likewise), only THEN scoring -10 (erasing stat changes is bad only when
-- nobody but the opponent could be benefiting).
local STAT_KEYS = { "attack", "defense", "speed", "spAttack", "spDefense", "accuracy", "evasion" }
local function haze(user, target, move, typeChart)
  for _, key in ipairs(STAT_KEYS) do
    if user.statStages[key] < 6 then return 0 end
  end
  for _, key in ipairs(STAT_KEYS) do
    if target.statStages[key] > 6 then return 0 end
  end
  return -10
end

-- AI_CBM_WillOWisp (data/battle_ai_scripts.s:535-543). Real `if_status
-- AI_TARGET STATUS1_ANY` tail is a confirmed no-op.
local function willOWisp(user, target, move, typeChart)
  if target.ability == ABILITY_WATER_VEIL then return -10 end
  local eff = classifyEffectiveness(move.type, target.types, typeChart)
  if eff == X0 or eff == X0_5 or eff == X0_25 then return -10 end
  return 0
end

-- AI_CBM_TrickAndKnockOff (data/battle_ai_scripts.s:549-552).
local function trickAndKnockOff(user, target, move, typeChart)
  if target.ability == ABILITY_STICKY_HOLD then return -10 end
  return 0
end

-- AI_CBM_BellyDrum (data/battle_ai_scripts.s:247-250): real HP guard, then
-- falls straight through (no `end`) into AI_CBM_AttackUp.
local function bellyDrum(user, target, move, typeChart)
  if hpPercent(user) < 51 then return -10 end
  return statUp("attack")(user, target, move, typeChart)
end

-- AI_CBM_Stockpile/SpitUpAndSwallow (data/battle_ai_scripts.s:515-524): real
-- `get_stockpile_count AI_USER` (src/battle_ai_script_commands.c:1792) has
-- no backing state in this engine at all (no move here can ever increment
-- it), so the count is always, provably, 0 -- not a guess, a structural
-- fact. Stockpile's own check is `if_equal 3` (never true at count 0, so
-- Stockpile itself is a confirmed no-op); Spit Up/Swallow's is `if_equal 0`
-- (ALWAYS true at count 0), giving the two real siblings opposite always-
-- outcomes from the same underlying fact.
local function stockpile(user, target, move, typeChart)
  return 0
end
local function spitUpAndSwallow(user, target, move, typeChart)
  local eff = classifyEffectiveness(move.type, target.types, typeChart)
  if eff == X0 then return -10 end
  return -10
end

-- AI_CBM_HelpingHand (data/battle_ai_scripts.s:545-547): real
-- `if_not_double_battle, Score_Minus10`. This engine only ever runs single
-- battles (BattleEngine.lua's header: "...or double battles" is an
-- explicitly unmodeled mechanic), so "not a double battle" is always,
-- structurally, true here -- this is ALWAYS -10.
local function helpingHand(user, target, move, typeChart)
  return -10
end

-- AI_CBM_Recycle (data/battle_ai_scripts.s:558-561): real
-- `get_used_held_item AI_USER; if_equal ITEM_NONE, Score_Minus10`. Held
-- items are not modeled by this engine at all (BattleEngine.lua's header),
-- so "no item was used" is always, structurally, true -- this is ALWAYS
-- -10.
local function recycle(user, target, move, typeChart)
  return -10
end

-- AI_CBM_Refresh (data/battle_ai_scripts.s:567-569): real `if_not_status
-- AI_USER (POISON|BURN|PARALYSIS|TOXIC), Score_Minus10`. The user's status1
-- can never contain any of those in this engine, so "user has none of
-- them" is always true -- this is ALWAYS -10.
local function refresh(user, target, move, typeChart)
  return -10
end

-- AI_CBM_Teleport (data/battle_ai_scripts.s:185): real dispatch entry jumps
-- straight to Score_Minus10 unconditionally, no sub-label at all.
local function alwaysMinus10(user, target, move, typeChart)
  return -10
end

-- CONFIRMED NO-OP CLASS (see module header): each of these real branches
-- tests state this engine structurally never sets, so the real condition is
-- always false and the real script always falls through to its trailing
-- `end` (no penalty). Cited individually by the dispatch table below.
local function alwaysNoPenalty(user, target, move, typeChart)
  return 0
end

------------------------------------------------------------------------
-- Real if_effect dispatch chain (data/battle_ai_scripts.s:105-213), ported
-- as effect id -> handler. Ids sharing a real target label share the same
-- Lua function reference here, exactly mirroring the real aliasing.
------------------------------------------------------------------------
local EFFECT_HANDLERS = {
  [1] = sleep,                                    -- EFFECT_SLEEP -> AI_CBM_Sleep
  [8] = dreamEater,                                -- EFFECT_DREAM_EATER -> AI_CBM_DreamEater
  [10] = statUp("attack"),                         -- EFFECT_ATTACK_UP
  [11] = statUp("defense"),                        -- EFFECT_DEFENSE_UP
  [12] = statUp("speed"),                          -- EFFECT_SPEED_UP
  [13] = statUp("spAttack"),                       -- EFFECT_SPECIAL_ATTACK_UP
  [14] = statUp("spDefense"),                      -- EFFECT_SPECIAL_DEFENSE_UP
  [15] = statUp("accuracy"),                       -- EFFECT_ACCURACY_UP
  [16] = statUp("evasion"),                        -- EFFECT_EVASION_UP
  [18] = statDown("attack", ABILITY_HYPER_CUTTER),  -- EFFECT_ATTACK_DOWN
  [19] = statDown("defense"),                      -- EFFECT_DEFENSE_DOWN
  [20] = statDown("speed"),                        -- EFFECT_SPEED_DOWN
  [21] = statDown("spAttack"),                     -- EFFECT_SPECIAL_ATTACK_DOWN
  [22] = statDown("spDefense"),                    -- EFFECT_SPECIAL_DEFENSE_DOWN
  [23] = statDown("accuracy", ABILITY_KEEN_EYE),    -- EFFECT_ACCURACY_DOWN
  [24] = statDown("evasion"),                      -- EFFECT_EVASION_DOWN
  [25] = haze,                                     -- EFFECT_HAZE -> AI_CBM_Haze
  [26] = highRiskForDamage,                        -- EFFECT_BIDE -> AI_CBM_HighRiskForDamage
  [33] = poison,                                   -- EFFECT_TOXIC -> AI_CBM_Poison
  [35] = lightScreen,                              -- EFFECT_LIGHT_SCREEN
  [38] = oneHitKO,                                 -- EFFECT_OHKO
  [39] = highRiskForDamage,                        -- EFFECT_RAZOR_WIND
  [40] = highRiskForDamage,                        -- EFFECT_SUPER_FANG
  [46] = alwaysNoPenalty,                          -- EFFECT_MIST: SIDE_STATUS_MIST unmodeled
  [47] = alwaysNoPenalty,                          -- EFFECT_FOCUS_ENERGY: status2 unmodeled
  [49] = confuse,                                  -- EFFECT_CONFUSE -> AI_CBM_Confuse
  [50] = statUp("attack"),                         -- EFFECT_ATTACK_UP_2
  [51] = statUp("defense"),                        -- EFFECT_DEFENSE_UP_2
  [52] = statUp("speed"),                          -- EFFECT_SPEED_UP_2
  [53] = statUp("spAttack"),                       -- EFFECT_SPECIAL_ATTACK_UP_2
  [54] = statUp("spDefense"),                      -- EFFECT_SPECIAL_DEFENSE_UP_2
  [55] = statUp("accuracy"),                       -- EFFECT_ACCURACY_UP_2
  [56] = statUp("evasion"),                        -- EFFECT_EVASION_UP_2
  [58] = statDown("attack", ABILITY_HYPER_CUTTER),  -- EFFECT_ATTACK_DOWN_2
  [59] = statDown("defense"),                      -- EFFECT_DEFENSE_DOWN_2
  [60] = statDown("speed"),                        -- EFFECT_SPEED_DOWN_2
  [61] = statDown("spAttack"),                     -- EFFECT_SPECIAL_ATTACK_DOWN_2
  [62] = statDown("spDefense"),                    -- EFFECT_SPECIAL_DEFENSE_DOWN_2
  [63] = statDown("accuracy", ABILITY_KEEN_EYE),    -- EFFECT_ACCURACY_DOWN_2
  [64] = statDown("evasion"),                      -- EFFECT_EVASION_DOWN_2
  [65] = reflect,                                  -- EFFECT_REFLECT
  [66] = poison,                                   -- EFFECT_POISON -> AI_CBM_Poison
  [67] = paralyze,                                 -- EFFECT_PARALYZE
  [79] = substitute,                               -- EFFECT_SUBSTITUTE
  [80] = highRiskForDamage,                        -- EFFECT_RECHARGE
  [84] = leechSeed,                                -- EFFECT_LEECH_SEED
  [86] = alwaysNoPenalty,                          -- EFFECT_DISABLE: if_any_move_disabled unmodeled
  [87] = highRiskForDamage,                        -- EFFECT_LEVEL_DAMAGE
  [88] = highRiskForDamage,                        -- EFFECT_PSYWAVE
  [89] = highRiskForDamage,                        -- EFFECT_COUNTER
  [90] = alwaysNoPenalty,                          -- EFFECT_ENCORE: if_any_move_encored unmodeled
  [92] = damageDuringSleep,                        -- EFFECT_SNORE
  [97] = damageDuringSleep,                        -- EFFECT_SLEEP_TALK
  [99] = highRiskForDamage,                        -- EFFECT_FLAIL
  [106] = alwaysNoPenalty,                         -- EFFECT_MEAN_LOOK: status2 escape-prevention unmodeled
  [107] = nightmare,                               -- EFFECT_NIGHTMARE
  [108] = statUp("evasion"),                       -- EFFECT_MINIMIZE -> AI_CBM_EvasionUp
  [109] = curse,                                   -- EFFECT_CURSE
  [112] = alwaysNoPenalty,                         -- EFFECT_SPIKES: SIDE_STATUS_SPIKES unmodeled
  [113] = alwaysNoPenalty,                         -- EFFECT_FORESIGHT: status2 unmodeled
  [114] = alwaysNoPenalty,                         -- EFFECT_PERISH_SONG: status3 unmodeled
  [115] = alwaysNoPenalty,                         -- EFFECT_SANDSTORM: weather unmodeled
  [118] = confuse,                                 -- EFFECT_SWAGGER -> AI_CBM_Confuse
  [121] = highRiskForDamage,                       -- EFFECT_RETURN
  [122] = highRiskForDamage,                       -- EFFECT_PRESENT
  [123] = highRiskForDamage,                       -- EFFECT_FRUSTRATION
  [124] = alwaysNoPenalty,                         -- EFFECT_SAFEGUARD: side status unmodeled
  [126] = magnitude,                               -- EFFECT_MAGNITUDE
  [130] = highRiskForDamage,                       -- EFFECT_SONICBOOM
  [136] = alwaysNoPenalty,                         -- EFFECT_RAIN_DANCE: weather unmodeled
  [137] = alwaysNoPenalty,                         -- EFFECT_SUNNY_DAY: weather unmodeled
  [142] = bellyDrum,                               -- EFFECT_BELLY_DRUM
  [143] = haze,                                    -- EFFECT_PSYCH_UP -> AI_CBM_Haze
  [144] = highRiskForDamage,                       -- EFFECT_MIRROR_COAT
  [145] = highRiskForDamage,                       -- EFFECT_SKULL_BASH
  [148] = alwaysNoPenalty,                         -- EFFECT_FUTURE_SIGHT: side status unmodeled
  [153] = alwaysMinus10,                           -- EFFECT_TELEPORT
  [156] = statUp("defense"),                       -- EFFECT_DEFENSE_CURL -> AI_CBM_DefenseUp
  [160] = stockpile,                               -- EFFECT_STOCKPILE
  [161] = spitUpAndSwallow,                        -- EFFECT_SPIT_UP
  [162] = spitUpAndSwallow,                        -- EFFECT_SWALLOW
  [164] = alwaysNoPenalty,                         -- EFFECT_HAIL: weather unmodeled
  [165] = alwaysNoPenalty,                         -- EFFECT_TORMENT: status2 unmodeled
  [166] = confuse,                                 -- EFFECT_FLATTER -> AI_CBM_Confuse
  [167] = willOWisp,                               -- EFFECT_WILL_O_WISP
  [170] = highRiskForDamage,                       -- EFFECT_FOCUS_PUNCH
  [176] = helpingHand,                             -- EFFECT_HELPING_HAND
  [177] = trickAndKnockOff,                        -- EFFECT_TRICK
  [181] = alwaysNoPenalty,                         -- EFFECT_INGRAIN: status3 rooted unmodeled
  [182] = highRiskForDamage,                       -- EFFECT_SUPERPOWER
  [184] = recycle,                                 -- EFFECT_RECYCLE
  [188] = trickAndKnockOff,                        -- EFFECT_KNOCK_OFF -> AI_CBM_TrickAndKnockOff
  [189] = highRiskForDamage,                       -- EFFECT_ENDEAVOR
  [192] = alwaysNoPenalty,                         -- EFFECT_IMPRISON: status3 unmodeled
  [193] = refresh,                                 -- EFFECT_REFRESH
  [196] = highRiskForDamage,                       -- EFFECT_LOW_KICK
  [201] = alwaysNoPenalty,                         -- EFFECT_MUD_SPORT: status3 unmodeled
  [205] = tickle,                                  -- EFFECT_TICKLE
  [206] = cosmicPower,                             -- EFFECT_COSMIC_POWER
  [208] = bulkUp,                                  -- EFFECT_BULK_UP
  [210] = alwaysNoPenalty,                         -- EFFECT_WATER_SPORT: status3 unmodeled
  [211] = calmMind,                                -- EFFECT_CALM_MIND
  [212] = dragonDance,                             -- EFFECT_DRAGON_DANCE
}

-- Real in-list effects deliberately left unported -- see module header's
-- "REAL GAPS" paragraph. Encountering one of these must fail loudly, not
-- silently return 0 (that would misrepresent a real gap as a confirmed
-- real no-op).
local UNPORTED_EFFECTS = {
  [7] = "EFFECT_EXPLOSION (AI_CBM_Explosion needs count_alive_pokemon, not modeled)",
  [28] = "EFFECT_ROAR (AI_CBM_Roar needs count_alive_pokemon, not modeled)",
  [120] = "EFFECT_ATTRACT (AI_CBM_Attract needs get_gender, not modeled)",
  [127] = "EFFECT_BATON_PASS (AI_CBM_BatonPass needs count_alive_pokemon, not modeled)",
  [158] = "EFFECT_FAKE_OUT (AI_CBM_FakeOut needs is_first_turn_for, not modeled)",
  [168] = "EFFECT_MEMENTO (falls through into AI_CBM_BatonPass's count_alive_pokemon check, not modeled)",
}

-- Real EFFECT_HIT and EFFECT_ABSORB (0, 3) etc. that ARE in this project's
-- move set but genuinely absent from the real if_effect dispatch chain fall
-- through to nil below and correctly return 0 -- see AICheckBadMove.score.

-- Returns the real AI_CheckBadMove score delta (<=0) for `move` (a parsed
-- gBattleMoves-shaped record, import/BattleMove.lua) being considered by
-- `user` (AI_USER, the foe) against `target` (AI_TARGET, the player).
-- `moveId` is the move's real numeric id (needed for the Soundproof
-- sound-move list). `typeChart`/`sideStatus` come straight from the
-- BattleEngine instance (import/TypeChart.lua rows; BattleEngine.new's
-- per-side reflect/lightScreen table).
function AICheckBadMove.score(user, target, move, moveId, typeChart, sideStatus)
  -- Step 1-2: get_how_powerful_move_is gate + AI_CBM_CheckIfNegatesType.
  local powerDiscouraged = move.power <= 1 or DISCOURAGED_POWERFUL_EFFECTS[move.effect]
  if not powerDiscouraged then
    local eff = classifyEffectiveness(move.type, target.types, typeChart)
    if eff == X0 then return -10 end
    local ability = target.ability
    if ability == ABILITY_VOLT_ABSORB then
      if move.type == TYPE_ELECTRIC then return -12 end
    elseif ability == ABILITY_WATER_ABSORB then
      if move.type == TYPE_WATER then return -12 end
    elseif ability == ABILITY_FLASH_FIRE then
      if move.type == TYPE_FIRE then return -12 end
    elseif ability == ABILITY_WONDER_GUARD then
      if eff ~= X2 then return -10 end
    elseif ability == ABILITY_LEVITATE then
      if move.type == TYPE_GROUND then return -10 end
    end
  end

  -- Step 3: AI_CheckBadMove_CheckSoundproof (always runs).
  if target.ability == ABILITY_SOUNDPROOF and SOUNDPROOF_MOVES[moveId] then
    return -10
  end

  -- Step 4: AI_CheckBadMove_CheckEffect dispatch.
  local handler = EFFECT_HANDLERS[move.effect]
  if handler then
    return handler(user, target, move, typeChart, sideStatus)
  end
  if UNPORTED_EFFECTS[move.effect] then
    error(("AICheckBadMove: real AI_CheckBadMove effect %d (%s) is in the real dispatch " ..
      "chain but not ported -- see this module's header \"REAL GAPS\" paragraph")
      :format(move.effect, UNPORTED_EFFECTS[move.effect]))
  end
  -- Confirmed real fallback: effect id absent from the real ~80-entry
  -- if_effect chain falls to its trailing plain `end` -- zero penalty, not
  -- an approximation (data/battle_ai_scripts.s:214).
  return 0
end

return AICheckBadMove
