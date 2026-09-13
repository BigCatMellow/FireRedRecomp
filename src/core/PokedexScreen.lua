-- Pure numerical Pokédex list controller. Source: pokefirered's
-- DexScreen_CountMonsInOrderedList / Task_DexScreen_NumericalOrder
-- (src/pokedex_screen.c). This deliberately owns no rendering, ROM reads,
-- save writes, detail page, or start-menu wiring.

local PokedexScreen = {}
PokedexScreen.__index = PokedexScreen

PokedexScreen.KANTO_DEX_COUNT = 151
PokedexScreen.NATIONAL_DEX_COUNT = 411
PokedexScreen.VISIBLE_ROWS = 9 -- sListMenuTemplate_OrderedListMenu.maxShowed
PokedexScreen.OPEN = "open"
PokedexScreen.SELECTED = "selected"
PokedexScreen.CANCELLED = "cancelled"

local function copyEntry(entry)
  return {
    nationalDexNo=entry.nationalDexNo,
    species=entry.species,
    seen=entry.seen,
    owned=entry.owned,
    label=entry.label,
  }
end

local function assertOptions(opts)
  assert(type(opts) == "table", "PokedexScreen requires options")
  assert(type(opts.dexTracker) == "table" and type(opts.dexTracker.isSeen) == "function"
    and type(opts.dexTracker.isOwned) == "function", "PokedexScreen requires a DexTracker-style reader")
  assert(type(opts.speciesForNationalDex) == "function", "PokedexScreen requires speciesForNationalDex")
  assert(type(opts.nameForSpecies) == "function", "PokedexScreen requires nameForSpecies")
end

local function maximumFor(self)
  return self.mode == "national" and self.NATIONAL_DEX_COUNT or self.KANTO_DEX_COUNT
end

-- Retail allocates every possible item but sets ListMenu totalItems only to
-- the final seen National Dex number: unseen holes stay, trailing ones do not.
local function countFor(self)
  local lastSeen = 0
  for nationalDexNo = 1, maximumFor(self) do
    if self.dexTracker:isSeen(nationalDexNo) then lastSeen = nationalDexNo end
  end
  return lastSeen
end

local function updateViewport(self)
  local count = countFor(self)
  if count == 0 then
    self.selectedIndex, self.scrollTop = 0, 0
    return
  end
  self.selectedIndex = math.max(0, math.min(count - 1, self.selectedIndex))
  local selected = self.selectedIndex
  if count <= self.VISIBLE_ROWS then
    self.scrollTop = 0
  elseif selected < 4 then
    self.scrollTop = 0
  elseif selected >= count - 4 then
    self.scrollTop = count - self.VISIBLE_ROWS
  else
    self.scrollTop = selected - 4
  end
end

function PokedexScreen.new(opts)
  assertOptions(opts)
  local self = setmetatable({
    dexTracker=opts.dexTracker,
    speciesForNationalDex=opts.speciesForNationalDex,
    nameForSpecies=opts.nameForSpecies,
    nationalEnabled=opts.nationalEnabled == true,
    mode="kanto",
    state=PokedexScreen.OPEN,
    selectedIndex=0,
    scrollTop=0,
    modePositions={
      kanto={selectedIndex=0, scrollTop=0},
      national={selectedIndex=0, scrollTop=0},
    },
  }, PokedexScreen)
  updateViewport(self)
  return self
end

function PokedexScreen:count()
  updateViewport(self)
  return countFor(self)
end

function PokedexScreen:entryAt(index)
  assert(type(index) == "number" and index >= 0 and index < countFor(self)
    and index == math.floor(index), "Pokedex list index is out of range")
  local nationalDexNo = index + 1 -- numerical order is directly 1..N.
  local seen = self.dexTracker:isSeen(nationalDexNo)
  local species = self.speciesForNationalDex(nationalDexNo)
  assert(type(species) == "number" and species >= 1 and species == math.floor(species),
    "Pokedex species mapping is invalid")
  local owned = self.dexTracker:isOwned(nationalDexNo)
  return {
    nationalDexNo=nationalDexNo,
    species=species,
    seen=seen,
    owned=owned,
    -- Retail keeps unseen slots in the numerical list but hides their names.
    label=seen and self.nameForSpecies(species) or "-----",
  }
end

function PokedexScreen:entries()
  local out = {}
  for index = 0, countFor(self) - 1 do out[#out + 1] = self:entryAt(index) end
  return out
end

function PokedexScreen:selectedEntry()
  if countFor(self) == 0 then return nil end
  return copyEntry(self:entryAt(self.selectedIndex))
end

function PokedexScreen:snapshot()
  updateViewport(self)
  local selected = self:selectedEntry()
  return {
    state=self.state,
    mode=self.mode,
    count=countFor(self),
    selectedIndex=self.selectedIndex,
    scrollTop=self.scrollTop,
    cursorRow=selected and self.selectedIndex - self.scrollTop or nil,
    selected=selected,
  }
end

function PokedexScreen:setMode(mode)
  assert(mode == "kanto" or mode == "national", "Pokedex mode must be kanto or national")
  assert(mode ~= "national" or self.nationalEnabled, "National Pokedex is not enabled")
  assert(self.state == self.OPEN, "Pokedex list is no longer open")
  if self.mode == mode then return false end
  self.modePositions[self.mode] = {selectedIndex=self.selectedIndex, scrollTop=self.scrollTop}
  self.mode = mode
  self.selectedIndex = self.modePositions[mode].selectedIndex
  self.scrollTop = self.modePositions[mode].scrollTop
  updateViewport(self)
  return true
end

function PokedexScreen:move(delta)
  assert(self.state == self.OPEN, "Pokedex list is no longer open")
  assert(type(delta) == "number" and delta == math.floor(delta), "Pokedex movement must be an integer")
  local target = math.max(0, math.min(countFor(self) - 1, self.selectedIndex + delta))
  if target == self.selectedIndex then return false end
  self.selectedIndex = target
  updateViewport(self)
  self.modePositions[self.mode] = {selectedIndex=self.selectedIndex, scrollTop=self.scrollTop}
  return true
end

function PokedexScreen:handle(action)
  assert(type(action) == "string", "Pokedex action must be a string")
  if self.state ~= self.OPEN then return nil end
  if action == "up" then self:move(-1); return nil end
  if action == "down" then self:move(1); return nil end
  if action == "cancel" then
    self.state = self.CANCELLED
    return {kind="cancelled"}
  end
  if action == "confirm" then
    local selected = self:selectedEntry()
    if not selected or not selected.seen then return nil end
    self.state = self.SELECTED
    return {kind="selected", nationalDexNo=selected.nationalDexNo, species=selected.species}
  end
  error("unknown Pokedex action: " .. action)
end

function PokedexScreen:isDone()
  return self.state ~= self.OPEN
end

return PokedexScreen
