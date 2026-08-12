-- Parses a map's script-hook table (the raw byte stream behind a
-- MapHeader's mapScriptsPtr) into structure: which MAP_SCRIPT_* hooks a map
-- has and where their script bytecode starts. Does NOT decode the script
-- bytecode itself -- that needs a script VM/interpreter, out of scope for
-- Phase 1's "raw extraction" (see roadmap). Script pointers are kept raw.
--
-- Format (pokefirered asm/macros/map.inc `map_script`/`map_script_2`
-- macros, confirmed directly from a real map's assembled .s source, not
-- just the macro definition): a stream of (type: u8, scriptOrTablePtr: u32)
-- pairs -- 5 bytes each, NOT padded/aligned (raw assembler .byte/.4byte
-- output) -- terminated by a single type=0 byte. For the two "table" hook
-- types (ON_FRAME_TABLE=2, ON_WARP_INTO_MAP_TABLE=4), scriptOrTablePtr
-- doesn't point at script bytecode -- it points at a second-level table of
-- (var: u16, compare: u16, script: u32) triples, 8 bytes each, terminated
-- by var=0.
--
-- Verified against real MAP_PALLET_TOWN data: decodes to exactly
-- {ON_TRANSITION, PalletTown_OnTransition}, {ON_FRAME_TABLE,
-- PalletTown_OnFrame} then a terminator -- matching
-- data/maps/PalletTown/scripts.inc's PalletTown_MapScripts table order
-- exactly. The ON_FRAME_TABLE sub-entry decodes to var=0x4050 (exactly
-- VAR_MAP_SCENE_PALLET_TOWN_OAK) and compare=2, matching source's
-- `map_script_2 VAR_MAP_SCENE_PALLET_TOWN_OAK, 2, ...` exactly.

local MapScripts = {}

MapScripts.romBase = 0x08000000

MapScripts.ON_LOAD = 1
MapScripts.ON_FRAME_TABLE = 2
MapScripts.ON_TRANSITION = 3
MapScripts.ON_WARP_INTO_MAP_TABLE = 4
MapScripts.ON_RESUME = 5
MapScripts.ON_DIVE_WARP = 6 -- unused in FireRed
MapScripts.ON_RETURN_TO_FIELD = 7

local TABLE_TYPES = { [MapScripts.ON_FRAME_TABLE] = true, [MapScripts.ON_WARP_INTO_MAP_TABLE] = true }

local byte = string.byte

local function u16le(data, offset0based)
  return byte(data, offset0based + 1) + byte(data, offset0based + 2) * 256
end

local function u32le(data, offset0based)
  return byte(data, offset0based + 1)
    + byte(data, offset0based + 2) * 256
    + byte(data, offset0based + 3) * 65536
    + byte(data, offset0based + 4) * 16777216
end

-- Resolves a single (var,compare,script) sub-table, e.g. an
-- ON_FRAME_TABLE/ON_WARP_INTO_MAP_TABLE entry's target.
function MapScripts.resolveVarTable(data, tablePtr)
  local base = tablePtr - MapScripts.romBase
  local out = {}
  local i = 0
  while true do
    local o = base + i * 8
    local var = u16le(data, o + 0x00)
    if var == 0 then break end
    out[i] = {
      var = var,
      compare = u16le(data, o + 0x02),
      scriptPtr = u32le(data, o + 0x04),
    }
    i = i + 1
  end
  return out
end

-- data: full ROM bytes. mapScriptsPtr: raw ROM address (from a MapHeader's
-- mapScriptsPtr field). Returns a 0-indexed list of
-- { type, scriptPtr, varTable } -- varTable is set (via resolveVarTable)
-- only for the two table-type hooks; otherwise scriptPtr points directly
-- at script bytecode (not decoded here).
function MapScripts.resolve(data, mapScriptsPtr)
  local base = mapScriptsPtr - MapScripts.romBase
  local out = {}
  local i = 0
  while true do
    local o = base + i * 5
    local scriptType = byte(data, o + 1)
    if scriptType == 0 then break end
    local scriptPtr = u32le(data, o + 1)
    local entry = { type = scriptType, scriptPtr = scriptPtr }
    if TABLE_TYPES[scriptType] then
      entry.varTable = MapScripts.resolveVarTable(data, scriptPtr)
    end
    out[i] = entry
    i = i + 1
  end
  return out
end

return MapScripts
