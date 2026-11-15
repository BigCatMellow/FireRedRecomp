-- Synthetic bytes only (no ROM content). Source oracle: accepted P5-06 C0
-- design at pokefirered c75f352 (scripts.inc:188-201, text.c:550-650,
-- new_menu_helpers.c:27-32, scrcmd.c:1313-1318). `loadfile(...)("fixtures")`
-- returns the byte/context fixtures for the integration test.
package.path=package.path..";./?.lua"
local R=require("src.core.ViridianRoadblock")
local Input=require("src.core.InputState")
local F={}
function F.bytes(changes, text)
  local b={}; for i=1,512 do b[i]=0xff end
  local function put(p, values) for i,v in ipairs(values) do b[p+i]=v end end
  local function ptr(p) return {p%256,math.floor(p/256),0,8} end
  put(16,{3,200,0,0,8,0})
  put(64,{0x69,0xc7,0,0x0f,0}); put(69,ptr(128))
  put(73,{9,4,0x68,0x4f,0xff,0}); put(79,ptr(32))
  put(83,{0x51,0,0,0x6b,2}); put(32,{0x10,0xfe})
  put(128,text or {0xbb,0xbc,0xfe,0xbd,0xbe,0xfb,0xbf,0xc0,0xc1,0xff})
  for p,v in pairs(changes or {}) do b[p+1]=v end
  local out={}; for i,v in ipairs(b) do out[i]=string.char(v) end
  return table.concat(out)
end
function F.context()
  return {mapId=769,x=22,y=11,normalStep=true,moving=false,generation=1,stepGeneration=1,
    scene=0,elevation=3,events={[0]={x=22,y=11,trigger=0x4051,index=0,elevation=3,scriptPtr=0x08000040}}}
end
if ...=="fixtures" then return F end
local passed,failed=0,0
local function check(name,ok)
  if ok then passed=passed+1 else failed=failed+1; print("FAIL: "..name) end
end
local function describe(data) return R.describe(data,0x08000040,0x08000010) end
local d=assert(describe(F.bytes()))
check("dynamic pointers and two independent pages",d.textPtr==0x08000080 and d.movementPtr==0x08000020
  and #d.pages[1]==5 and d.pages[1][3].type=="newline" and #d.pages[2]==3)
for _,i in ipairs({0,1,2,3,4,9,10,11,12,13,14,19,20,21,22,23}) do
  check("reject changed script operand "..i,describe(F.bytes({[64+i]=0x55}))==nil)
end
for _,p in ipairs({16,21,32,33,72,82}) do
  check("reject table/movement/pointer "..p,describe(F.bytes({[p]=0x55}))==nil)
end
for n=0,87 do check("range checked script truncation "..n,describe(F.bytes():sub(1,n))==nil) end
for _,ptr in ipairs({0,1,0x07ffffff,0x08000200,0x09000000,0x08000040+0.5}) do
  check("invalid script pointer "..ptr,R.describe(F.bytes(),ptr,0x08000010)==nil)
  check("invalid table pointer "..ptr,R.describe(F.bytes(),0x08000040,ptr)==nil)
end
for _,text in ipairs({{0xbb,0xff},{0xfe,0xbb,0xfb,0xbc,0xff},
  {0xbb,0xfe,0xfb,0xbc,0xff},{0xbb,0xfe,0xbc,0xfb,0xff},
  {0xbb,0xfe,0xbc,0xfb,0xbd,0xfb,0xbe,0xff},
  {0xbb,0xfe,0xbc,0xfb,0xbd,0xfe,0xbe,0xff}}) do
  check("reject malformed page shape",describe(F.bytes(nil,text))==nil)
end
for b=0xf7,0xfd do
  if b~=0xfb then check("reject unexpected control "..b,describe(F.bytes({[129]=b}))==nil) end
end
check("truncated text",describe(F.bytes():sub(1,135))==nil)
check("bounded missing terminator",describe(F.bytes():sub(1,128)..string.rep(string.char(0xbb),1024))==nil)
check("selected identity",R.classify(F.context())=="owned")
for _,case in ipairs({{"mapId",768,"not_selected"},{"x",21,"not_selected"},{"y",12,"not_selected"},
  {"scene",1,"not_selected"},{"scene",65535,"not_selected"},{"scene",false,"refused"},
  {"scene",-1,"refused"},{"scene",65536,"refused"},{"scene",0.1,"refused"},
  {"elevation",4,"not_selected"},{"elevation",0,"not_selected"},{"elevation",false,"refused"},
  {"normalStep",false,"refused"},{"moving",true,"refused"},{"stepGeneration",2,"refused"}}) do
  local c=F.context(); c[case[1]]=case[2]
  check("admission "..case[1].."="..tostring(case[2]),R.classify(c)==case[3])
end
for _,field in ipairs({"scene","generation","stepGeneration","elevation","events"}) do
  local c=F.context();c[field]=nil;check("missing "..field,R.classify(c)=="refused")
end
for _,field in ipairs({"x","y","trigger","index","elevation"}) do
  local c=F.context();c.events[0][field]=99;check("C0 identity "..field,R.classify(c)=="refused")
end
do
  local c=F.context();c.events[1]=c.events[0];check("conflicting identity",R.classify(c)=="refused")
  c=F.context();c.events[0].elevation=0;c.elevation=0
  check("known player zero matches event wildcard",R.classify(c)=="owned")
  c.elevation=4;check("wildcard known4",R.classify(c)=="owned")
  c.elevation=nil;check("wildcard never unknown",R.classify(c)=="refused")
end
do
  local c=F.context();c.scene=1;c.normalStep=false;c.elevation=nil
  check("valid nonzero scene stays legacy before step qualification",R.classify(c)=="not_selected")
  c=F.context();check("selected event returned",select(2,R.classify(c))==c.events[0])
end
for _,speed in ipairs({-1,3,8,false,"1"}) do check("unsupported speed",R.new(d,speed)==nil) end
for speed,delay in pairs({[0]=8,[1]=4,[2]=1}) do
  local r=assert(R.new(d,speed));local input=Input.new()
  input:update(0);r:update(input)
  check("first glyph and literal delay "..speed,r.printer.tokenIndex==1 and r.remaining==delay)
  input:update(Input.A_BUTTON);r:update(input)
  check("activation returns without glyph "..speed,r.accelerated and r.printer.tokenIndex==1)
  r:update(input);check("held acceleration one glyph "..speed,r.printer.tokenIndex==2)
end
for speed,delay in pairs({[0]=8,[1]=4,[2]=1}) do
  -- Unaccelerated cadence: one glyph, then `delay` frames that print nothing.
  local r=assert(R.new(d,speed));local input=Input.new();local cadence=true
  for frame=0,(#d.pages[1]-1)*(delay+1) do
    input:update(0);r:update(input)
    cadence=cadence and r.printer.tokenIndex==math.floor(frame/(delay+1))+1
  end
  check("source delay cadence "..speed,cadence and r.state=="WAIT_PAGE")
  -- Held latched acceleration never reveals more than one glyph per update.
  r=assert(R.new(d,speed));input=Input.new();input:update(0);r:update(input)
  local last,oneStep=r.printer.tokenIndex,true
  for _=1,40 do
    input:update(Input.B_BUTTON);r:update(input)
    oneStep=oneStep and r.printer.tokenIndex-last<=1;last=r.printer.tokenIndex
    if r.state~="PRINT_PAGE1" then break end
  end
  check("no reveal-all under held latch "..speed,oneStep and r.state=="WAIT_PAGE")
end
for _,button in ipairs({Input.A_BUTTON,Input.B_BUTTON}) do
  local r=assert(R.new(d,2));local input=Input.new()
  local function tick(mask) input:update(mask);r:update(input) end
  tick(0);tick(button)
  while r.state=="PRINT_PAGE1" do tick(button) end
  check("printing press cannot acknowledge page",r.state=="WAIT_PAGE")
  tick(button);check("held never clears page",r.page==1)
  tick(0);tick(Input.START_BUTTON+Input.SELECT_BUTTON+Input.DPAD_DOWN)
  check("directions/start/select never acknowledge",r.page==1)
  tick(0);tick(button)
  check("new page resets printer, preserves latch",r.page==2 and r.printer.tokenIndex==0 and r.accelerated)
  while r.state=="PRINT_PAGE2" do tick(button) end
  tick(button);check("held never final acknowledgment",r.state=="WAIT_FINAL")
  tick(0);tick(Input.A_BUTTON+Input.B_BUTTON)
  check("A wins simultaneous final buttons",r.state=="CLOSE_PENDING" and r.acknowledgedBy=="A")
  check("ack leaves frame open",r.printer~=nil)
  r:cancel("test");check("separate cancellation",r.state=="CANCELLED" and not r:isActive() and not r.printer)
end
print(("phase5_viridian_roadblock_test: %d passed, %d failed"):format(passed,failed))
os.exit(failed==0 and 0 or 1)
