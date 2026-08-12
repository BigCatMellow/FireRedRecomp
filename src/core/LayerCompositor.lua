-- Real GBA layer draw-order rule (standard hardware behavior, not
-- FireRed-specific -- documented in every GBA hardware reference, and
-- implicitly confirmed by pokefirered's own BgTemplate/OamData priority
-- fields, e.g. src/title_screen.c's sBgTemplates assigning bg0..bg3
-- priorities 0..3 and sOamData_FlameOrLeaf's `.priority = 3`): both
-- backgrounds and sprites carry a priority value 0-3, where **lower
-- numbers draw closer to the viewer** (priority 0 = frontmost). Layers
-- are drawn back-to-front in descending priority order; at any priority
-- level shared by both a background and a sprite, the sprite (OBJ) draws
-- on top of the background (BG) of that same priority -- so the real
-- draw order is: for priority 3 down to 0, draw all BG layers at that
-- priority, then all OBJ layers at that priority. Ties within the same
-- kind keep their relative input order (matching OAM index / BG number
-- ordering on real hardware, lower index drawn first/behind).
--
-- This generalizes what TitleScreen.lua's compositeFull previously did
-- by hand (drawing border/copyright/boxart/logo in a fixed, hardcoded
-- sequence that happened to match their real priorities) into a reusable
-- module any future scene compositor can use, and fixes a real
-- correctness gap: the title screen's flame OBJ sprites (priority 3,
-- same as the border BG) were being drawn *after* the fully-composited
-- title image in main.lua, meaning they rendered on top of the
-- copyright/press-start layer (priority 2) instead of correctly behind
-- it -- verified visually (see the commit this shipped in): flames
-- spawn right around the "PRESS START" row and would incorrectly cover
-- it before this fix.

local LayerCompositor = {}

-- layers: a list of { priority = 0-3, kind = "bg" or "obj", ...anything }.
-- Returns a new list sorted into the real back-to-front draw order.
-- Stable with respect to input order for ties (same priority AND kind).
function LayerCompositor.sortLayers(layers)
  local indexed = {}
  for i, layer in ipairs(layers) do
    indexed[i] = { layer = layer, originalIndex = i }
  end
  table.sort(indexed, function(a, b)
    if a.layer.priority ~= b.layer.priority then
      return a.layer.priority > b.layer.priority -- higher priority number (further back) drawn first
    end
    local aIsObj = a.layer.kind == "obj"
    local bIsObj = b.layer.kind == "obj"
    if aIsObj ~= bIsObj then
      return bIsObj -- bg before obj at the same priority
    end
    return a.originalIndex < b.originalIndex -- stable tie-break
  end)
  local sorted = {}
  for i, entry in ipairs(indexed) do sorted[i] = entry.layer end
  return sorted
end

return LayerCompositor
