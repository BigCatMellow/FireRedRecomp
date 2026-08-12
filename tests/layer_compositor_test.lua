-- Unit test: verifies LayerCompositor's real GBA draw-order rule
-- (descending priority, BG before OBJ within a priority level).
-- Run: lua5.1 tests/layer_compositor_test.lua
package.path = package.path .. ";./?.lua"
local LayerCompositor = require("src.core.LayerCompositor")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local function namesOf(layers)
  local names = {}
  for i, l in ipairs(layers) do names[i] = l.name end
  return table.concat(names, ",")
end

-- Real title screen scenario: bg0..bg3 at priorities 0..3, matching
-- sBgTemplates -- higher priority number (bg3, the border) drawn first
-- (furthest back), lower priority number (bg0, the logo) drawn last
-- (frontmost).
do
  local layers = {
    { name = "logo", priority = 0, kind = "bg" },
    { name = "boxart", priority = 1, kind = "bg" },
    { name = "copyright", priority = 2, kind = "bg" },
    { name = "border", priority = 3, kind = "bg" },
  }
  local sorted = LayerCompositor.sortLayers(layers)
  check("BG layers sort back-to-front by descending priority", namesOf(sorted) == "border,copyright,boxart,logo", namesOf(sorted))
end

-- The real bug this module fixes: an OBJ sprite (flame, priority 3) and
-- a BG at the SAME priority (border, priority 3) -- the OBJ must draw
-- on top of that BG, but still behind any BG with a lower priority
-- number (copyright, priority 2).
do
  local layers = {
    { name = "copyright", priority = 2, kind = "bg" },
    { name = "flame", priority = 3, kind = "obj" },
    { name = "border", priority = 3, kind = "bg" },
  }
  local sorted = LayerCompositor.sortLayers(layers)
  check("OBJ draws on top of a same-priority BG, but the flame still sits behind a lower-priority-number BG", namesOf(sorted) == "border,flame,copyright", namesOf(sorted))
end

-- Multiple OBJs at the same priority keep their relative (creation)
-- order -- matching real hardware's OAM-index tie-break.
do
  local layers = {
    { name = "sprite_a", priority = 1, kind = "obj" },
    { name = "sprite_b", priority = 1, kind = "obj" },
    { name = "sprite_c", priority = 1, kind = "obj" },
  }
  local sorted = LayerCompositor.sortLayers(layers)
  check("same-priority OBJs keep their input order", namesOf(sorted) == "sprite_a,sprite_b,sprite_c", namesOf(sorted))
end

-- A full mixed scene: several priorities, BGs and OBJs interleaved in
-- input order, to confirm the sort handles the general case correctly.
do
  local layers = {
    { name = "obj_pri0", priority = 0, kind = "obj" },
    { name = "bg_pri3", priority = 3, kind = "bg" },
    { name = "bg_pri0", priority = 0, kind = "bg" },
    { name = "obj_pri3", priority = 3, kind = "obj" },
    { name = "bg_pri1", priority = 1, kind = "bg" },
  }
  local sorted = LayerCompositor.sortLayers(layers)
  check("mixed scene sorts to the full real draw order", namesOf(sorted) == "bg_pri3,obj_pri3,bg_pri1,bg_pri0,obj_pri0", namesOf(sorted))
end

-- sortLayers doesn't mutate the input list.
do
  local layers = { { name = "a", priority = 1, kind = "bg" }, { name = "b", priority = 0, kind = "bg" } }
  local sorted = LayerCompositor.sortLayers(layers)
  check("input list order is untouched", layers[1].name == "a" and layers[2].name == "b")
  check("a new list is returned", sorted ~= layers)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
