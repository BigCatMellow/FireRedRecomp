-- Generalized trainer-battle move-selection AI, sitting ALONGSIDE
-- EarlyRivalAI.lua (not replacing it -- EarlyRivalAI's header already
-- scopes it to "the Oak-lab rivals" specifically, and its exact-script
-- bounded-move-set assertions would fail loudly, correctly, for any other
-- trainer's moveset -- see that module's `error("unsupported Oak-lab AI
-- move effect...")`). This module is the dispatcher a general trainer
-- battle's `chooseFoeMove` should use; EarlyRivalAI remains the Oak-lab
-- tutorial's own direct wiring in main.lua (untouched here).
--
-- Real dispatch traced from src/battle_ai_script_commands.c:
--
--   BattleAI_SetupAIData (~line 330-355): for an ordinary trainer battle
--   (not BATTLE_TYPE_SAFARI/ROAMER/TRAINER_TOWER/EREADER_TRAINER/
--   LEGENDARY_FRLG and not TRAINER_SECRET_BASE -- i.e. a normal overworld
--   trainer, which is this module's whole scope):
--     AI_THINKING_STRUCT->aiFlags = gTrainers[gTrainerBattleOpponent_A].aiFlags;
--   -- exactly import/Trainer.lua's decoded `aiFlags` field, no
--   transformation.
--
--   BattleAI_ChooseMoveOrAction (~line 363):
--     while (AI_THINKING_STRUCT->aiFlags != 0) {
--         if (AI_THINKING_STRUCT->aiFlags & 1) BattleAI_DoAIProcessing();
--         AI_THINKING_STRUCT->aiFlags >>= 1;
--         AI_THINKING_STRUCT->aiLogicId++;
--     }
--     ... return consideredMoveArray[Random() % numOfBestMoves];
--   -- loops over aiFlags' set bits low-to-high, running
--   gBattleAI_ScriptsTable[bit index] for each set bit, then picks the
--   move(s) with the highest resulting score (initialized to 100 for
--   every move, ~line 299-300), breaking ties uniformly at random.
--
-- Two real tiers are ported here, both verified against real source
-- rather than guessed:
--
--   * aiFlags == 0: the `while` loop above never executes a single
--     script (loop guard fails immediately), so every move's score stays
--     its initialized 100 EXCEPT moves already zeroed by
--     CheckMoveLimitations for 0 remaining PP (~line 303-308,
--     `AI_THINKING_STRUCT->score[i] = 0`). All surviving scores tied at
--     100 means `Random() % numOfBestMoves` picks uniformly among them --
--     i.e. a real trainer with no AI flags set genuinely does pick
--     uniformly at random among its PP-remaining moves. This is confirmed
--     real behavior, not a fabricated fallback heuristic.
--   * aiFlags == EarlyRivalAI.AI_FLAGS (0x7 ==
--     AI_SCRIPT_CHECK_BAD_MOVE|AI_SCRIPT_CHECK_VIABILITY|
--     AI_SCRIPT_TRY_TO_FAINT, include/constants/battle_ai.h lines 37-39):
--     delegates to EarlyRivalAI.choose, the existing bit-exact port of
--     those three real AI scripts (bounded to the move/effect set that
--     module's own header documents -- Tackle/Scratch/Growl/Tail Whip).
--
-- Any other real aiFlags value (AI_SCRIPT_SETUP_FIRST_TURN, RISKY,
-- PREFER_STRONGEST_MOVE, PREFER_BATON_PASS, DOUBLE_BATTLE, HP_AWARE,
-- ROAMING, SAFARI, FIRST_BATTLE, or CHECK_BAD_MOVE/VIABILITY/TRY_TO_FAINT
-- combined with any of those) is real gBattleAI_ScriptsTable behavior this
-- module does not implement -- porting all real AI scripts bit-exactly for
-- every trainer in the game is substantially bigger than this task's
-- scope. Errors loudly instead of approximating, matching this project's
-- "fail loudly on unimplemented" house convention (e.g.
-- ObjectEventState.lua:tick()'s unknown-movementType error).

local EarlyRivalAI = require("src.core.EarlyRivalAI")

local TrainerAI = {}

-- Real AI_SCRIPT_* bit values (include/constants/battle_ai.h).
TrainerAI.AI_SCRIPT_CHECK_BAD_MOVE = 0x1
TrainerAI.AI_SCRIPT_CHECK_VIABILITY = 0x2
TrainerAI.AI_SCRIPT_TRY_TO_FAINT = 0x4

-- Real "no AI scripts ran" tie-break: uniformly random among moves with
-- PP remaining (see header). Errors loudly if all four moves are out of
-- PP -- real Struggle substitution (MAX_MON_MOVES exhausted) is not
-- ported here, same documented gap BattleEngine.lua's header already
-- notes for Struggle generally.
local function chooseRandomValidMove(engine)
  local candidates = {}
  for i = 1, 4 do
    local slot = engine.foe.moves[i]
    if slot and slot.pp > 0 then
      candidates[#candidates + 1] = i
    end
  end
  assert(#candidates > 0,
    "TrainerAI: foe has no move with PP remaining (real Struggle substitution not ported)")
  return candidates[(engine.rng:next16() % #candidates) + 1]
end

-- Returns the 1-based move slot chosen for this turn, matching
-- BattleSceneController's chooseFoeMove(engine) shape (see
-- BattleSceneController.lua:305 / main.lua's EarlyRivalAI wiring at
-- main.lua:1237 for the existing calling convention this follows).
function TrainerAI.choose(engine, aiFlags)
  aiFlags = aiFlags or 0
  if aiFlags == 0 then
    return chooseRandomValidMove(engine)
  elseif aiFlags == EarlyRivalAI.AI_FLAGS then
    return (EarlyRivalAI.choose(engine, aiFlags))
  end
  error(("TrainerAI: aiFlags 0x%X not ported -- only 0 (real no-flags random pick) and " ..
    "EarlyRivalAI.AI_FLAGS (0x%X, CHECK_BAD_MOVE|CHECK_VIABILITY|TRY_TO_FAINT) are implemented; " ..
    "see this module's header for the real gBattleAI_ScriptsTable scope boundary"):format(
    aiFlags, EarlyRivalAI.AI_FLAGS))
end

return TrainerAI
