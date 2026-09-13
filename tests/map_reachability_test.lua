package.path = package.path .. ";./?.lua"
local R = require("src.core.MapReachability")
local pass, fail = 0, 0
local function check(n, ok) if ok then pass=pass+1 else fail=fail+1; print("FAIL: "..n) end end
local pallet, route1, house, route21 = 3*256, 3*256+19, 4*256, 3*256+39
local graph = R.build({
  [pallet]={events={warps={{mapGroup=4,mapNum=0}}},connections={{mapGroup=3,mapNum=19},{mapGroup=3,mapNum=39}}},
  [house]={events={warps={{mapGroup=3,mapNum=0}}}}, [route1]={}, [route21]={},
})
local p = R.path(graph, house, route1)
check("warp and connection compose into a route", p and #p == 3 and p[1] == house and p[3] == route1)
check("unreachable maps return nil", R.path(graph, route1, house) == nil)
check("same map has a zero-edge path", R.path(graph, pallet, pallet)[1] == pallet)
local reachable = R.reachable(graph, house)
check("breadth-first reachability includes every directed successor", reachable[house]
  and reachable[pallet] and reachable[route1] and reachable[route21])
local filtered = R.reachable(graph, house, function(mapId) return mapId ~= route21 end)
check("reachability filter excludes a blocked graph branch", filtered[house] and filtered[pallet]
  and filtered[route1] and not filtered[route21])
local duplicateKinds = R.build({ [pallet]={events={warps={{mapGroup=3,mapNum=19}}},connections={{mapGroup=3,mapNum=19}}} })
check("same destination keeps distinct warp and connection metadata", #duplicateKinds[pallet] == 2)
print(("%d passed, %d failed"):format(pass, fail)); os.exit(fail == 0 and 0 or 1)
