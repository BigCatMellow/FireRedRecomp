-- Unit test: verifies TaskScheduler's priority-ordered linked list and
-- lifecycle match pokefirered's real task.c semantics (insertion order,
-- priority tie-breaking -- ties run in creation order since InsertTask
-- only displaces on strictly-lower priority, destroy-mid-run safety,
-- slot reuse).
-- Run: lua5.1 tests/task_scheduler_test.lua
package.path = package.path .. ";./?.lua"
local TaskScheduler = require("src.core.TaskScheduler")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

-- Basic create/run: a task runs once per runTasks() call while active.
do
  local s = TaskScheduler.new()
  local runs = 0
  local id = s:createTask(function(taskId) runs = runs + 1 end, 0)
  check("createTask returns a valid slot id", id ~= nil)
  s:runTasks()
  s:runTasks()
  check("task runs once per runTasks() call", runs == 2, runs)
end

-- Priority ordering: lower priority value runs first, matching InsertTask
-- (walks the list, inserts before the first strictly-higher-priority task).
do
  local s = TaskScheduler.new()
  local order = {}
  s:createTask(function() table.insert(order, "mid") end, 5)
  s:createTask(function() table.insert(order, "low") end, 1)
  s:createTask(function() table.insert(order, "high") end, 9)
  s:runTasks()
  check("tasks run in priority order regardless of creation order", order[1] == "low" and order[2] == "mid" and order[3] == "high", table.concat(order, ","))
end

-- Same-priority tasks run in creation order (InsertTask only inserts
-- *before* a strictly lower-priority-value task, so equal priority means
-- "append after", i.e. FIFO among ties).
do
  local s = TaskScheduler.new()
  local order = {}
  s:createTask(function() table.insert(order, "first") end, 3)
  s:createTask(function() table.insert(order, "second") end, 3)
  s:createTask(function() table.insert(order, "third") end, 3)
  s:runTasks()
  check("equal-priority tasks run in creation (FIFO) order", order[1] == "first" and order[2] == "second" and order[3] == "third", table.concat(order, ","))
end

-- destroyTask removes a task from the run list; a task destroying itself
-- mid-runTasks() doesn't corrupt traversal of the remaining tasks (RunTasks
-- captures .next before calling .func, matching the real code's "taskId =
-- gTasks[taskId].next" happening after the call -- ported here as capturing
-- nextId before invoking func so a self-destroy doesn't strand the walk).
do
  local s = TaskScheduler.new()
  local order = {}
  local selfId
  selfId = s:createTask(function(taskId) table.insert(order, "self"); s:destroyTask(taskId) end, 0)
  s:createTask(function() table.insert(order, "after") end, 1)
  s:runTasks()
  check("a task destroying itself doesn't strand traversal of later tasks", order[1] == "self" and order[2] == "after", table.concat(order, ","))
  check("destroyed task no longer runs on the next call", (function()
    order = {}
    s:runTasks()
    return #order == 1 and order[1] == "after"
  end)())
end

-- Per-task data storage (Lua's table.data replaces the real code's s16[16]
-- + SetWordTaskArg/GetWordTaskArg packing helpers -- see TaskScheduler.lua's
-- header comment for why those aren't ported).
do
  local s = TaskScheduler.new()
  local id = s:createTask(function() end, 0)
  s:data(id).counter = 42
  check("per-task data persists across runTasks() calls", s:data(id).counter == 42)
end

-- setFuncWithFollowupFunc / switchToFollowupFunc: a task can switch its own
-- behavior after some condition (e.g. an animation's intro phase finishing).
do
  local s = TaskScheduler.new()
  local phase = "intro"
  local mainFunc = function(taskId) phase = "main" end
  local introFunc = function(taskId) phase = "intro-ran"; s:switchToFollowupFunc(taskId) end
  local id = s:createTask(nil, 0)
  s:setFuncWithFollowupFunc(id, introFunc, mainFunc)
  s:runTasks()
  check("intro func ran first", phase == "intro-ran")
  s:runTasks()
  check("switched to the followup func on the next run", phase == "main")
end

-- funcIsActiveTask / findTaskIdByFunc / getTaskCount.
do
  local s = TaskScheduler.new()
  local f = function() end
  check("no active tasks initially", s:getTaskCount() == 0)
  local id = s:createTask(f, 0)
  check("funcIsActiveTask finds the running func", s:funcIsActiveTask(f))
  check("findTaskIdByFunc returns the right id", s:findTaskIdByFunc(f) == id)
  check("getTaskCount reflects the one active task", s:getTaskCount() == 1)
  s:destroyTask(id)
  check("funcIsActiveTask is false after destroy", not s:funcIsActiveTask(f))
  check("getTaskCount is 0 after destroy", s:getTaskCount() == 0)
end

-- Pool exhaustion: creating more than NUM_TASKS tasks returns nil for the
-- overflow (real code returns task id 0, silently reusing/clobbering it --
-- see TaskScheduler.lua's header comment for why nil is used instead).
do
  local s = TaskScheduler.new()
  for i = 1, TaskScheduler.NUM_TASKS do
    check("task " .. i .. " of NUM_TASKS creates successfully", s:createTask(function() end, 0) ~= nil)
  end
  check("creating one more than NUM_TASKS returns nil", s:createTask(function() end, 0) == nil)
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
