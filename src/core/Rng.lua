-- Port of pokefirered's real pseudorandom generator (src/random.c):
--   gRngValue = ISO_RANDOMIZE1(gRngValue)  where ISO_RANDOMIZE1(v) =
--     1103515245 * v + 24691, wrapping at 32 bits (the ISO C rand/srand
--     example constants -- real source's own comment, not this project's
--     guess)
--   Random() returns gRngValue >> 16 (the high 16 bits)
-- The title screen's flame spawner uses this exact same LCG formula with
-- its own independent seed/state (TitleScreen_rand/_srand in
-- src/title_screen.c, confirmed calling the same ISO_RANDOMIZE1 macro) --
-- this module is written generically so both the (not-yet-ported) global
-- RNG and the title screen's local one can use one implementation.
--
-- 32-bit wraparound arithmetic without a `bit` library (same constraint
-- as Lz77.lua/InputState.lua): 1103515245 * a 32-bit value can exceed
-- 2^53, breaking float precision, so the multiply is done in two 16-bit
-- halves and only the bits that survive mod 2^32 are kept at each step.

local Rng = {}

local RAND_MULT = 1103515245
local RAND_ADD = 24691
local MOD32 = 4294967296 -- 2^32

-- (a * b) mod 2^32, where a and b are both < 2^32. a is always RAND_MULT
-- here (fits in 31 bits), but this works for any two 32-bit values.
local function mulmod32(a, b)
  local aHi, aLo = math.floor(a / 65536), a % 65536
  local bHi, bLo = math.floor(b / 65536), b % 65536
  -- a*b = (aHi*65536+aLo)*(bHi*65536+bLo)
  --     = aHi*bHi*2^32 + (aHi*bLo + aLo*bHi)*65536 + aLo*bLo
  -- The aHi*bHi*2^32 term is always 0 mod 2^32, so it's dropped. The
  -- middle term only contributes its low 16 bits once shifted left 16
  -- (its high bits shift past bit 31 and vanish mod 2^32).
  local mid = (aHi * bLo + aLo * bHi) % 65536
  local low = aLo * bLo -- < 65536*65536, safely within float precision
  return (mid * 65536 + low) % MOD32
end

-- seed: initial 32-bit RNG state (u16 in the real SeedRng, but the state
-- itself, gRngValue, is u32 -- callers seeding with a real u16 value like
-- the flame spawner's 30840 get identical behavior to the real code).
function Rng.new(seed)
  return setmetatable({ value = seed % MOD32 }, { __index = Rng })
end

-- Advances the generator and returns the next pseudorandom u16 (0-65535),
-- exactly matching a real Random() call (or TitleScreen_rand for the
-- title screen's independent instance).
function Rng:next16()
  self.value = (mulmod32(RAND_MULT, self.value) + RAND_ADD) % MOD32
  return math.floor(self.value / 65536)
end

return Rng
