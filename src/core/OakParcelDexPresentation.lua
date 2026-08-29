-- Narrow, pure presenter for the north-facing ReceiveDexScene in Oak's Lab.
-- It is deliberately not a field-script interpreter.  Constants and the
-- sequence below are transcribed from the verified FireRed source/ROM; see
-- work/tasks/oak-parcel-dex-presentation-north.md for its bounded contract.

local Presentation = {}
Presentation.__index = Presentation

Presentation.MAP_OAKS_LAB = 4 * 256 + 3
Presentation.PLAYER_X, Presentation.PLAYER_Y = 6, 4
Presentation.OAK_LOCAL_ID = 4
Presentation.RIVAL_LOCAL_ID = 8
Presentation.DEX_PROP_LEFT_LOCAL_ID = 9
Presentation.DEX_PROP_RIGHT_LOCAL_ID = 10

Presentation.TEXT_POINTERS = {
  0x0818E405, 0x0818E4AF, 0x0818E4CA, 0x0818DE8D, 0x0818DE99,
  0x0818E508, 0x0818E536, 0x0818E5C5, 0x0818E5EA, 0x0818E612,
  0x0818E6B3, 0x0818E6D0, 0x0818E784, 0x0818DEC8, 0x0818DEF3,
}

Presentation.IDLE = "IDLE"
Presentation.WAIT_RIVAL_ARRIVAL = "WAIT_RIVAL_ARRIVAL"
Presentation.SHOW_TEXT = "SHOW_TEXT"
Presentation.WAIT_PLAYER_FACE_UP = "WAIT_PLAYER_FACE_UP"
Presentation.WAIT_OAK_TO_DEX = "WAIT_OAK_TO_DEX"
Presentation.WAIT_DEX_REVEAL = "WAIT_DEX_REVEAL"
Presentation.WAIT_OAK_RETURN = "WAIT_OAK_RETURN"
Presentation.WAIT_RIVAL_EXIT = "WAIT_RIVAL_EXIT"
Presentation.DONE = "DONE"
Presentation.FAILED = "FAILED"

local function command(kind, fields)
  fields = fields or {}
  fields.kind = kind
  return fields
end

local function requireCallbacks(opts)
  assert(type(opts) == "table", "OakParcelDexPresentation requires options")
  assert(type(opts.canBegin) == "function", "OakParcelDexPresentation requires non-mutating canBegin")
  assert(type(opts.commit) == "function", "OakParcelDexPresentation requires commit")
end

function Presentation.new(opts)
  requireCallbacks(opts)
  return setmetatable({
    canBegin = opts.canBegin,
    commit = opts.commit,
    state = Presentation.IDLE,
    textIndex = nil,
    failureReason = nil,
  }, Presentation)
end

function Presentation:isActive()
  return self.state ~= self.IDLE and self.state ~= self.DONE and self.state ~= self.FAILED
end

function Presentation:isInputLocked()
  return self:isActive()
end

function Presentation:currentTextPointer()
  return self.state == self.SHOW_TEXT and self.TEXT_POINTERS[self.textIndex] or nil
end

local function showText(self, index)
  self.state = self.SHOW_TEXT
  self.textIndex = index
  return command("show_text", { textPointer=self:currentTextPointer(), textIndex=index })
end

-- The extra state fields are intentional strengthened guards.  They prevent
-- malformed saves and other orientations from invoking this north-only slice.
function Presentation:begin(context)
  if self.state ~= self.IDLE then return nil, "already_started" end
  context = context or {}
  if context.mapId ~= self.MAP_OAKS_LAB then return nil, "wrong_map" end
  if context.playerX ~= self.PLAYER_X or context.playerY ~= self.PLAYER_Y then return nil, "wrong_position" end
  if context.playerFacing ~= "up" then return nil, "wrong_facing" end
  if context.oakPresent ~= true then return nil, "oak_missing" end
  if context.martScene ~= 1 then return nil, "mart_scene_not_parcel" end
  if context.labScene ~= 5 then return nil, "lab_scene_not_parcel_return" end
  if context.parcelPresent ~= true then return nil, "parcel_missing" end
  local ok, reason = self.canBegin(context)
  if not ok then return nil, reason or "precondition_failed" end

  self.state = self.SHOW_TEXT
  self.textIndex = 1
  return command("lock", {
    textPointer=self:currentTextPointer(),
    textIndex=self.textIndex,
  })
end

local function beginRivalArrival(self)
  self.state = self.WAIT_RIVAL_ARRIVAL
  return command("move", {
    spawn = { target="rival", localId=self.RIVAL_LOCAL_ID, x=5, y=10 },
    group = "rival_arrival",
    movements = {
      { target="rival", localId=self.RIVAL_LOCAL_ID, action="walk_up", steps=6, finalX=5, finalY=4 },
      { target="player", action="face_down_delay_then_left", delay16=5, delay8=1, finalFacing="left" },
    },
  })
end

function Presentation:movementComplete(group)
  if self.state == self.WAIT_RIVAL_ARRIVAL and group == "rival_arrival" then
    return showText(self, 5)
  end
  if self.state == self.WAIT_PLAYER_FACE_UP and group == "player_face_up" then
    return showText(self, 6)
  end
  if self.state == self.WAIT_OAK_TO_DEX and group == "oak_to_dex" then
    return showText(self, 8)
  end
  if self.state == self.WAIT_DEX_REVEAL and group == "dex_reveal" then
    return showText(self, 9)
  end
  if self.state == self.WAIT_OAK_RETURN and group == "oak_return" then
    return showText(self, 14)
  end
  if self.state == self.WAIT_RIVAL_EXIT and group == "rival_exit" then
    local action, reason = self.commit()
    if not action then
      self.state = self.FAILED
      self.failureReason = reason or "commit_failed"
      return command("unlock", { failed=true, reason=self.failureReason })
    end
    self.state = self.DONE
    return command("unlock", {
      done=true,
      committed=true,
      action=action,
      remove={ target="rival", localId=self.RIVAL_LOCAL_ID, preserveHideFlag=true },
    })
  end
  return nil, "unexpected_movement_completion"
end

function Presentation:onA(aPressed, textFullyRevealed)
  if not aPressed then return nil end
  if self.state ~= self.SHOW_TEXT then return nil, "no_text_to_advance" end
  if not textFullyRevealed then return command("reveal_text") end

  local index = self.textIndex
  if index == 4 then
    return beginRivalArrival(self)
  end
  if index == 5 then
    self.state = self.WAIT_PLAYER_FACE_UP
    return command("move", { group="player_face_up", movements={
      { target="player", action="face_up" },
    }})
  end
  if index == 7 then
    self.state = self.WAIT_OAK_TO_DEX
    return command("move", { group="oak_to_dex", movements={
      { target="oak", localId=self.OAK_LOCAL_ID, action="walk_up", steps=1, finalX=6, finalY=2 },
      { target="oak", localId=self.OAK_LOCAL_ID, action="walk_left", steps=1, finalX=5, finalY=2 },
    }})
  end
  if index == 8 then
    self.state = self.WAIT_DEX_REVEAL
    return command("move", { group="dex_reveal", movements={
      { target="oak", localId=self.OAK_LOCAL_ID, action="walk_in_place_faster_up" },
      { target="prop", localId=self.DEX_PROP_LEFT_LOCAL_ID, action="remove" },
      { target="scene", action="delay", frames=10 },
      { target="prop", localId=self.DEX_PROP_RIGHT_LOCAL_ID, action="remove" },
      { target="scene", action="delay", frames=25 },
    }})
  end
  if index == 13 then
    self.state = self.WAIT_OAK_RETURN
    return command("move", { group="oak_return", movements={
      { target="oak", localId=self.OAK_LOCAL_ID, action="walk_right", steps=1, finalX=6, finalY=2 },
      { target="oak", localId=self.OAK_LOCAL_ID, action="walk_down", steps=1, finalX=6, finalY=3 },
    }})
  end
  if index == 15 then
    self.state = self.WAIT_RIVAL_EXIT
    return command("move", { group="rival_exit", movements={
      { target="player", action="face_left" },
      { target="rival", localId=self.RIVAL_LOCAL_ID, action="walk_down", steps=6, finalX=5, finalY=10 },
    }})
  end
  return showText(self, index + 1)
end

return Presentation
