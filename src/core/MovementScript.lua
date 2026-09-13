-- Decodes the movement byte stream consumed by applymovement.  This first
-- slice covers the ordinary walking actions used by common story scripts;
-- unknown actions fail loudly instead of guessing animation semantics.
local MovementScript = {}

MovementScript.STEP_END = 0xFE -- MOVEMENT_ACTION_STEP_END
local DIRECTIONS = {
  [0x10]="down", [0x11]="up", [0x12]="left", [0x13]="right", -- normal
  [0x1D]="down", [0x1E]="up", [0x1F]="left", [0x20]="right", -- fast
  [0x35]="down", [0x36]="up", [0x37]="left", [0x38]="right", -- faster
}

function MovementScript.decode(data, ptr)
  local steps, offset = {}, ptr - 0x08000000
  for _ = 1, 256 do
    local action = assert(data:byte(offset + 1), "movement script ran past ROM")
    offset = offset + 1
    if action == MovementScript.STEP_END then return steps end
    local direction = DIRECTIONS[action]
    if not direction then error(("MovementScript: unsupported action 0x%02X"):format(action)) end
    steps[#steps + 1] = direction
  end
  error("MovementScript: missing STEP_END within 256 actions")
end

return MovementScript
