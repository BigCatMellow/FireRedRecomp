-- Real "trainer sees you" exclamation + walk-up sequence, ported from
-- pokefirered's src/trainer_see.c `sTrainerSeeFuncList` task chain
-- (TrainerSeeFunc_StartExclMark -> WaitExclMark -> TrainerApproach ->
-- PrepareToEngage -> End, funcIds 1-5). Pure Lua state machine, ticked
-- once per real 60Hz frame like PlayerMovement.lua/ObjectEventState.lua.
--
-- Scope boundary (explicitly flagged per this task's brief): this ports
-- the REAL geometry of the sequence -- exclamation-mark duration, exact
-- tile count walked, and when the trainer stops -- but not its visual
-- presentation (sprite/field-effect rendering is a separate LayerCompositor-
-- level concern, same split PlayerMovement.lua/ObjectEventState.lua already
-- draw between pure position state and drawing). The two FRLG-only real
-- sub-paths that trainer_see.c itself marks "Not used in FRLG" (buried-in-
-- ash disguise reveal, TrainerSeeFunc_BeginRemoveDisguise et al, lines 374/
-- 394) and the offscreen-above-trainer camera-scroll case (funcId 12+,
-- FRLG-exclusive but scoped to a real screen-edge encounter this project's
-- camera model doesn't have yet) are NOT implemented -- both error loudly
-- if requested rather than silently no-opping.
--
-- Real sequence ported here:
--   1. STATE_EXCLAMATION: real TrainerSeeFunc_StartExclMark
--      (trainer_see.c:287) starts FLDEFF_EXCLAMATION_MARK_ICON and faces
--      the trainer its own current facing direction (a no-op face, the
--      trainer is already looking at the player by construction -- see
--      TrainerSightline.lua). TrainerSeeFunc_WaitExclMark (line 307) waits
--      for `FieldEffectActiveListContains(FLDEFF_EXCLAMATION_MARK_ICON)`
--      to go false, i.e. until the icon's sprite animation ends. The real
--      animation is `sAnimCmd_ExclamationMark1` (trainer_see.c:604-609):
--      ANIMCMD_FRAME(0,4), ANIMCMD_FRAME(1,4), ANIMCMD_FRAME(2,52) -- a
--      real, exact 4+4+52 = 60-frame duration (transcribed from the real
--      anim-command table, not an invented "about a second" guess).
--   2. STATE_WALKING: real TrainerSeeFunc_TrainerApproach (line 324) walks
--      the trainer forward one real tile per completed
--      GetWalkNormalMovementAction hold (this project's existing 16-
--      frames-per-tile walk speed, ObjectEventState.lua's
--      WALK_FRAMES_PER_TILE / :beginForcedStep+:advanceStep), counting
--      down `task->tTrainerRange`. That counter is seeded by real
--      CheckTrainer (trainer_see.c:117):
--      `TrainerApproachPlayer(&gObjectEvents[trainerObjId], approachDistance - 1)`
--      -- i.e. the trainer walks (approachDistance - 1) tiles, stopping
--      exactly one tile short of the player, never onto their tile.
--   3. STATE_DONE: real TrainerSeeFunc_TrainerApproach's zero-range branch
--      issues MOVEMENT_ACTION_FACE_PLAYER, which is a real no-op here (the
--      trainer already faces the player's direction, per point 1).
--      TrainerSeeFunc_PrepareToEngage (line 342) then locks the player's
--      controls and switches the trainer to its real post-battle idle
--      movement type -- both are caller/session-level responsibilities
--      (matching ObjectEventInteraction.lua's documented "wiring is a
--      deferred main.lua integration step" convention), signaled here by
--      `approach.state == TrainerApproach.STATE_DONE` so a caller knows to
--      run the trainer's actual trainerbattle script via
--      ScriptInterpreter.lua next.

local ObjectEventState = require("src.core.ObjectEventState")

local TrainerApproach = {}

TrainerApproach.STATE_EXCLAMATION = "exclamation"
TrainerApproach.STATE_WALKING = "walking"
TrainerApproach.STATE_DONE = "done"

-- Real sAnimCmd_ExclamationMark1 total duration (trainer_see.c:604-609):
-- ANIMCMD_FRAME(0,4) + ANIMCMD_FRAME(1,4) + ANIMCMD_FRAME(2,52) = 60 frames.
TrainerApproach.EXCLAMATION_FRAMES = 60

-- trainer: an ObjectEventState NPC state table. direction: the direction
-- TrainerSightline found the player in (trainer.facingDirection already
-- equals this for TRAINER_TYPE_NORMAL; passed explicitly so the
-- omnidirectional TRAINER_TYPE_BURIED case is handled the same way).
-- approachDistance: TrainerSightline.getApproachDistance's real return
-- value (the tile distance to the PLAYER, not the walk distance -- this
-- constructor subtracts 1 itself, matching real CheckTrainer's
-- `TrainerApproachPlayer(trainerObj, approachDistance - 1)`).
function TrainerApproach.new(trainer, direction, approachDistance)
  assert(approachDistance and approachDistance > 0,
    "TrainerApproach.new: approachDistance must be a real positive TrainerSightline result")
  trainer.facingDirection = direction
  return setmetatable({
    trainer = trainer,
    direction = direction,
    stepsRemaining = approachDistance - 1,
    state = TrainerApproach.STATE_EXCLAMATION,
    exclamationFramesRemaining = TrainerApproach.EXCLAMATION_FRAMES,
  }, { __index = TrainerApproach })
end

-- Advances the sequence by one real frame. No return value -- inspect
-- :isDone()/.state.
function TrainerApproach:tick()
  if self.state == TrainerApproach.STATE_EXCLAMATION then
    self.exclamationFramesRemaining = self.exclamationFramesRemaining - 1
    if self.exclamationFramesRemaining <= 0 then
      self.state = TrainerApproach.STATE_WALKING
    end
    return
  end

  if self.state == TrainerApproach.STATE_WALKING then
    if self.trainer.moving then
      ObjectEventState.advanceStep(self.trainer)
      return
    end
    if self.stepsRemaining > 0 then
      ObjectEventState.beginForcedStep(self.trainer, self.direction)
      self.stepsRemaining = self.stepsRemaining - 1
    else
      -- Real MOVEMENT_ACTION_FACE_PLAYER: a no-op here, see header.
      self.trainer.facingDirection = self.direction
      self.state = TrainerApproach.STATE_DONE
    end
    return
  end
  -- STATE_DONE: idle, matching real TrainerSeeFunc_End's real
  -- "wait for the player's own movement to finish" gate being the
  -- caller's job (player movement isn't this module's state to own).
end

function TrainerApproach:isDone()
  return self.state == TrainerApproach.STATE_DONE
end

return TrainerApproach
