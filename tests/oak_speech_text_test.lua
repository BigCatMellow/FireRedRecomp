-- Integration test: decodes the real Oak intro opening narration text
-- and checks it matches the real source's literal string exactly
-- (data/text/new_game_intro.inc, gOakSpeech_Text_WelcomeToTheWorld).
-- Opt-in via POKEPORT_ROM, skips cleanly otherwise.
--
-- Run: POKEPORT_ROM=/path/to/verified/pokefirered.gba lua5.1 tests/oak_speech_text_test.lua
package.path = package.path .. ";./?.lua"

local romPath = os.getenv("POKEPORT_ROM")
if not romPath then
  print("SKIP: set POKEPORT_ROM=/path/to/verified/pokefirered.gba to run this test")
  os.exit(0)
end

local RomImporter = require("import.RomImporter")
local RomAddresses = require("import.RomAddresses")
local Charmap = require("import.Charmap")

local passed, failed = 0, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. name .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
  end
end

local ok, info = RomImporter.verify(romPath)
if not ok then
  print("FAIL: ROM did not verify -- " .. tostring(info))
  os.exit(1)
end

local sha1 = RomImporter._sha1HexOfFile(romPath)
local addrs = RomAddresses[sha1]
local f = io.open(romPath, "rb")
local data = f:read("*a")
f:close()

local raw = data:sub(addrs.gOakSpeech_Text_WelcomeToTheWorld + 1, addrs.gOakSpeech_Text_WelcomeToTheWorld + 300)
local decoded = Charmap.decode(raw)

-- Real source (data/text/new_game_intro.inc), \n/\p both render as
-- newlines via Charmap.decode (matching this project's existing
-- linebreak-code handling elsewhere -- \p's real "start a new page and
-- wait for input" behavior isn't replicated, same disclosed
-- simplification already noted for other control codes in the checklist).
local expected = "Hello, there!\nGlad to meet you!\nWelcome to the world of POKéMON!\nMy name is OAK.\nPeople affectionately refer to me\nas the POKéMON PROFESSOR.\n"
check("decodes to exactly the real source's opening narration text", decoded == expected, decoded)

local tokens = Charmap.tokenize(raw)
local charCount, newlineCount = 0, 0
for _, t in ipairs(tokens) do
  if t.type == "char" then charCount = charCount + 1 end
  if t.type == "newline" then newlineCount = newlineCount + 1 end
end
check("tokenizes to a sane number of real characters", charCount > 100 and charCount < 200, charCount)
check("tokenizes the real \\n/\\p linebreaks (6 in the source)", newlineCount == 6, newlineCount)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
