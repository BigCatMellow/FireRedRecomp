-- Port of pokefirered's task scheduler (src/task.c / include/task.h): a
-- fixed pool of 16 task slots, run in a priority-ordered doubly-linked
-- list, each holding a Lua function called once per frame with its own
-- task id. This is what will drive text-speed/per-character reveal,
-- animation frame stepping (title screen flames, sprite walk cycles),
-- and eventually the scene stack -- anything the real game runs via
-- CreateTask()/RunTasks() rather than a hardcoded per-frame call.
--
-- Ported behavior (insertion order, priority tie-breaking, linked-list
-- traversal, isActive slot reuse) matches the real gTasks/InsertTask/
-- RunTasks logic exactly. Two real-C-only concerns are deliberately not
-- ported, since they only exist to work around C not having first-class
-- functions/closures:
--   * SetTaskFuncWithFollowupFunc/SwitchTaskToFollowupFunc pack a second
--     function pointer into two s16 data slots (data[14]/data[15]) because
--     struct Task has no extra function-pointer field. Lua tasks can just
--     hold a followupFunc reference directly (task.followupFunc), so this
--     module exposes the same setFuncWithFollowupFunc/switchToFollowupFunc
--     API but without the bit-packing.
--   * SetWordTaskArg/GetWordTaskArg split a 32-bit value across two s16
--     data slots because struct Task.data is s16[16]. Lua numbers aren't
--     width-limited, so task.data[n] can just hold the real value directly
--     -- no packing helpers needed.
--
-- NUM_TASKS=16, HEAD_SENTINEL=nil, TAIL_SENTINEL=nil (Lua doesn't need the
-- real code's 0xFE/0xFF byte sentinels; a nil prev/next means "end of list",
-- checked the same way FindFirstActiveTask/RunTasks check for the sentinels).

local NUM_TASKS = 16

local TaskScheduler = {}
TaskScheduler.NUM_TASKS = NUM_TASKS

local function newScheduler()
  local self = {
    tasks = {}, -- 1-indexed, 1..NUM_TASKS
  }
  for i = 1, NUM_TASKS do
    self.tasks[i] = { isActive = false, func = nil, prev = nil, next = nil, priority = -1, data = {}, followupFunc = nil }
  end
  return setmetatable(self, { __index = TaskScheduler })
end
TaskScheduler.new = newScheduler

local function findFirstActiveTask(self)
  for i = 1, NUM_TASKS do
    local t = self.tasks[i]
    if t.isActive and t.prev == nil then return i end
  end
  return nil
end

local function insertTask(self, newTaskId)
  local taskId = findFirstActiveTask(self)
  if taskId == nil then
    -- The new task is the only task.
    self.tasks[newTaskId].prev = nil
    self.tasks[newTaskId].next = nil
    return
  end

  while true do
    local newTask, task = self.tasks[newTaskId], self.tasks[taskId]
    if newTask.priority < task.priority then
      newTask.prev = task.prev
      newTask.next = taskId
      if task.prev ~= nil then
        self.tasks[task.prev].next = newTaskId
      end
      task.prev = newTaskId
      return
    end
    if task.next == nil then
      newTask.prev = taskId
      newTask.next = task.next
      task.next = newTaskId
      return
    end
    taskId = task.next
  end
end

-- func: function(taskId) called once per RunTasks() while active.
-- priority: lower runs first (matches the real code's InsertTask, which
-- inserts before the first task whose priority is not lower).
-- Returns the new task's id (1-indexed), or nil if the pool is full
-- (the real code returns 0 = slot 0, which is a real, silently-reused
-- task id; nil is used here instead since 0 isn't a valid Lua array index
-- and there's no equivalent "silently clobber task 0" behavior worth
-- replicating).
function TaskScheduler:createTask(func, priority)
  for i = 1, NUM_TASKS do
    local t = self.tasks[i]
    if not t.isActive then
      t.func = func
      t.priority = priority or 0
      insertTask(self, i)
      for k in pairs(t.data) do t.data[k] = nil end
      t.followupFunc = nil
      t.isActive = true
      return i
    end
  end
  return nil
end

function TaskScheduler:destroyTask(taskId)
  local t = self.tasks[taskId]
  if not t or not t.isActive then return end
  t.isActive = false
  if t.prev == nil then
    if t.next ~= nil then self.tasks[t.next].prev = nil end
  else
    if t.next == nil then
      self.tasks[t.prev].next = nil
    else
      self.tasks[t.prev].next = t.next
      self.tasks[t.next].prev = t.prev
    end
  end
end

function TaskScheduler:runTasks()
  local taskId = findFirstActiveTask(self)
  while taskId ~= nil do
    local t = self.tasks[taskId]
    local nextId = t.next -- captured before func() in case it destroys itself
    t.func(taskId)
    taskId = nextId
  end
end

function TaskScheduler:isTaskActive(taskId)
  local t = self.tasks[taskId]
  return t ~= nil and t.isActive
end

function TaskScheduler:funcIsActiveTask(func)
  for i = 1, NUM_TASKS do
    local t = self.tasks[i]
    if t.isActive and t.func == func then return true end
  end
  return false
end

function TaskScheduler:findTaskIdByFunc(func)
  for i = 1, NUM_TASKS do
    local t = self.tasks[i]
    if t.isActive and t.func == func then return i end
  end
  return nil
end

function TaskScheduler:getTaskCount()
  local count = 0
  for i = 1, NUM_TASKS do
    if self.tasks[i].isActive then count = count + 1 end
  end
  return count
end

function TaskScheduler:setFuncWithFollowupFunc(taskId, func, followupFunc)
  local t = self.tasks[taskId]
  t.followupFunc = followupFunc
  t.func = func
end

function TaskScheduler:switchToFollowupFunc(taskId)
  local t = self.tasks[taskId]
  t.func = t.followupFunc
end

function TaskScheduler:data(taskId)
  return self.tasks[taskId].data
end

return TaskScheduler
