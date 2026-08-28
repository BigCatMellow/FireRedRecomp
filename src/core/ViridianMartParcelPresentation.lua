-- A deliberately narrow, pure presenter for the first Viridian Mart Parcel
-- scene.  It is NOT a generic field-script interpreter.  The sequence and
-- descriptor constants below are transcribed from
-- data/maps/ViridianCity_Mart/scripts.inc/text.inc, verified against the
-- supported FireRed ROM (see work/tasks/viridian-mart-parcel-presentation.md).
--
-- The host owns text rendering/reveal and movement animation.  It supplies
-- completion notifications and applies the returned commands.  Persistence is
-- injected as a two-stage boundary: canBegin must preflight without mutation;
-- commit performs ViridianParcelStory:beginMartParcelScene only after the
-- request message has been acknowledged.  This keeps a full Key Items pocket
-- from beginning a cutscene that cannot produce its receipt.

local Presentation = {}
Presentation.__index = Presentation

Presentation.MAP_VIRIDIAN_MART = 5 * 256 + 3
Presentation.DOOR_X, Presentation.DOOR_Y = 4, 7
Presentation.CLERK_LOCAL_ID = 1

-- ROM pointers, not reconstructed text.  The runtime should resolve these
-- through its existing Charmap/ROM text path.
Presentation.TEXT_YOU_CAME_FROM_PALLET = 0x0819021A
Presentation.TEXT_TAKE_THIS_TO_PROF_OAK = 0x0819023A
Presentation.TEXT_RECEIVED_OAKS_PARCEL = 0x08190289

Presentation.IDLE = "IDLE"
Presentation.WAIT_CLERK_ATTENTION = "WAIT_CLERK_ATTENTION"
Presentation.SHOW_INTRO = "SHOW_INTRO"
Presentation.WAIT_APPROACH = "WAIT_APPROACH"
Presentation.SHOW_REQUEST = "SHOW_REQUEST"
Presentation.SHOW_RECEIPT = "SHOW_RECEIPT"
Presentation.DONE = "DONE"
Presentation.FAILED = "FAILED"

local function command(kind, fields)
  fields = fields or {}
  fields.kind = kind
  return fields
end

local function requireCallbacks(opts)
  assert(type(opts) == "table", "ViridianMartParcelPresentation requires options")
  assert(type(opts.canBegin) == "function", "ViridianMartParcelPresentation requires non-mutating canBegin")
  assert(type(opts.commit) == "function", "ViridianMartParcelPresentation requires commit")
end

function Presentation.new(opts)
  requireCallbacks(opts)
  return setmetatable({
    canBegin = opts.canBegin,
    commit = opts.commit,
    state = Presentation.IDLE,
    failureReason = nil,
  }, Presentation)
end

function Presentation:isActive()
  return self.state ~= Presentation.IDLE and self.state ~= Presentation.DONE
    and self.state ~= Presentation.FAILED
end

function Presentation:isInputLocked()
  return self:isActive()
end

function Presentation:currentTextPointer()
  if self.state == Presentation.SHOW_INTRO then return self.TEXT_YOU_CAME_FROM_PALLET end
  if self.state == Presentation.SHOW_REQUEST then return self.TEXT_TAKE_THIS_TO_PROF_OAK end
  if self.state == Presentation.SHOW_RECEIPT then return self.TEXT_RECEIVED_OAKS_PARCEL end
  return nil
end

-- context is intentionally small and explicit; accepting arbitrary map entry
-- would be generic map-hook scope.  clerkPresent is the host's object-event
-- lookup result for local id 1.
function Presentation:begin(context)
  if self.state ~= Presentation.IDLE then return nil, "already_started" end
  context = context or {}
  if context.mapId ~= self.MAP_VIRIDIAN_MART then return nil, "wrong_map" end
  if context.playerX ~= self.DOOR_X or context.playerY ~= self.DOOR_Y then return nil, "wrong_doorway" end
  if context.clerkPresent ~= true then return nil, "clerk_missing" end

  local ok, reason = self.canBegin(context)
  if not ok then return nil, reason or "precondition_failed" end

  self.state = self.WAIT_CLERK_ATTENTION
  return command("lock", {
    movement = { target="clerk", localId=self.CLERK_LOCAL_ID, action="walk_in_place_faster_down" },
  })
end

-- Called only after the host has completed the named scripted movement.  The
-- source uses waitmovement 0 after each group, so no text becomes available
-- until both movement actors have reported completion.
function Presentation:movementComplete(group)
  if self.state == self.WAIT_CLERK_ATTENTION and group == "clerk_attention" then
    self.state = self.SHOW_INTRO
    return command("show_text", { textPointer=self:currentTextPointer() })
  end
  if self.state == self.WAIT_APPROACH and group == "approach_counter" then
    self.state = self.SHOW_REQUEST
    return command("show_text", { textPointer=self:currentTextPointer() })
  end
  return nil, "unexpected_movement_completion"
end

-- aPressed means a newly-pressed A button.  textFullyRevealed is supplied by
-- TextPrinterState:isFullyRevealed(): A first reveals a still-printing text,
-- then an A on the fully revealed text advances the source scene.
function Presentation:onA(aPressed, textFullyRevealed)
  if not aPressed then return nil end
  if self.state ~= self.SHOW_INTRO and self.state ~= self.SHOW_REQUEST and self.state ~= self.SHOW_RECEIPT then
    return nil, "no_text_to_advance"
  end
  if not textFullyRevealed then return command("reveal_text") end

  if self.state == self.SHOW_INTRO then
    self.state = self.WAIT_APPROACH
    return command("move", {
      group="approach_counter",
      movements={
        { target="clerk", localId=self.CLERK_LOCAL_ID, action="face_right_after_64_frames" },
        { target="player", action="walk_up", steps=4, finalFacing="left", finalX=4, finalY=3 },
      },
    })
  end

  if self.state == self.SHOW_REQUEST then
    local action, reason = self.commit()
    if not action then
      self.state = self.FAILED
      self.failureReason = reason or "commit_failed"
      return command("unlock", { failed=true, reason=self.failureReason })
    end
    self.state = self.SHOW_RECEIPT
    return command("show_text", { textPointer=self:currentTextPointer(), committed=true, action=action })
  end

  self.state = self.DONE
  return command("unlock", { done=true })
end

return Presentation
