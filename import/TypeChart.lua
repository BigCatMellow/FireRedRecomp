-- Parses FireRed's gTypeEffectiveness table (pokefirered src/battle_main.c):
-- a flat array of (attackingType, defendingType, multiplier) byte triples,
-- terminated by a TYPE_ENDTABLE/TYPE_ENDTABLE sentinel row. Fixed 336 bytes
-- (112 rows) in the real ROM.
--
-- multiplier is a fixed-point decimal: 0=no effect, 5=x0.5, 10=x1.0, 20=x2.0.
-- TYPE_FORESIGHT (0xFE) appears as a row's type value for the
-- Ghost/Normal-immunity-bypass special case, not a real Pokémon type.

local TypeChart = {}

TypeChart.MUL_NO_EFFECT = 0
TypeChart.MUL_NOT_EFFECTIVE = 5
TypeChart.MUL_NORMAL = 10
TypeChart.MUL_SUPER_EFFECTIVE = 20
TypeChart.FORESIGHT = 0xFE
TypeChart.ENDTABLE = 0xFF

local byte = string.byte

-- data: full ROM bytes. tableOffset: 0-based byte offset of the table's
-- first row. Reads until the ENDTABLE sentinel row (matching how the game
-- itself walks this table) rather than a fixed count, so it's correct even
-- if a future ROM/revision changes the row count.
function TypeChart.parseTable(data, tableOffset)
  local rows = {}
  local i = 0
  while true do
    local base = tableOffset + i * 3
    local atk = byte(data, base + 1)
    local def = byte(data, base + 2)
    local mul = byte(data, base + 3)
    if not (atk and def and mul) then
      error(("type chart read ran past end of data at row %d without an ENDTABLE sentinel"):format(i))
    end
    if atk == TypeChart.ENDTABLE and def == TypeChart.ENDTABLE then
      break
    end
    rows[i] = { attackingType = atk, defendingType = def, multiplier = mul }
    i = i + 1
  end
  return rows
end

return TypeChart
