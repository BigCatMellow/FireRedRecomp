-- Real save data shape, pokefirered include/global.h's `struct SaveBlock1`
-- (line 759) and `struct SaveBlock2` (line 327). Pure data model: field
-- names, byte offsets, sizes and types transcribed directly from the
-- struct declarations (the header's own `/*0xNNNN*/` offset comments,
-- cross-checked by hand-summing declared field sizes between consecutive
-- offset comments -- every gap found is noted below).
--
-- This is deliberately a PARTIAL model. SaveBlock1 in particular is huge
-- (0x3D68 bytes: full party, 5 bag pockets, object events, quest log,
-- mail, daycare, mystery gift, trainer tower, etc.) -- only the fields a
-- freshly-started new game actually needs are modeled here (player
-- position/warp, party, money, bag, PC items, Pokedex-adjacent seen
-- flags, flags/vars arrays, game stats, rival name). See
-- NewGameDefaults.lua's header for the full list of what's deliberately
-- left unmodeled and why.
--
-- No ROM needed for any of this -- SaveBlock1/SaveBlock2 are compile-time
-- C struct declarations, not ROM data tables.
--
-- Cross-checks performed while transcribing (struct math, not guesses):
--   * SaveBlock2: NUM_FLAG_BYTES gap (flags 0x0EE0 -> vars 0x1000) is
--     0x120 = 288 bytes = FLAGS_COUNT/8 where FLAGS_COUNT =
--     FLAG_0x8FF+1 = 0x900 (constants/flags.h). VARS_COUNT gap (vars
--     0x1000 -> gameStats 0x1200) is 0x200 = 256 u16 vars, matching
--     VARS_COUNT = VARS_END(0x40FF) - VARS_START(0x4000) + 1 = 256
--     (constants/vars.h).
--   * playerParty (0x0038) -> money (0x0290): 0x258 = 600 bytes / 6
--     PARTY_SIZE slots = 100 bytes/slot, matching struct Pokemon's real
--     size (struct BoxPokemon's 80 bytes, confirmed in
--     BoxPokemonCodec.lua, + status u32(4) + level u8 + mail u8 +
--     hp/maxHP/attack/defense/speed/spAttack/spDefense u16x7(14) =
--     80+4+1+1+14 = 100).
--   * pcItems (0x0298) -> bagPocket_Items (0x0310): 0x78 = 120 bytes /
--     4 bytes-per-ItemSlot (u16 itemId + u16 quantity) = 30 slots,
--     matching PC_ITEMS_COUNT=30 (constants/global.h).
--   * seen1 (0x05F8) -> berryBlenderRecords (0x062C): 0x34 = 52 bytes =
--     DEX_FLAGS_NO = ceil(NUM_SPECIES/8) = ceil(412/8) = 52
--     (NUM_SPECIES = SPECIES_EGG = 412, constants/species.h).
--   * SaveBlock2.pokedex (0x018) -> filler_90 (0x090): 0x78 bytes,
--     matching struct Pokedex's declared size (0x10 header fields +
--     owned[52] + seen[52] = 0x10+0x34+0x34 = 0x78).

local SaveBlockLayout = {}

-- struct WarpData (include/global.h ~line 392): s8 mapGroup, s8 mapNum,
-- s8 warpId, s16 x, s16 y -- 3 bytes + 1 pad + 2 + 2 = 8 bytes.
local WARP_DATA = { size = 8, fields = {
  { name = "mapGroup", type = "s8", offset = 0 },
  { name = "mapNum",   type = "s8", offset = 1 },
  { name = "warpId",   type = "s8", offset = 2 },
  { name = "x",        type = "s16", offset = 4 },
  { name = "y",        type = "s16", offset = 6 },
}}

-- struct ItemSlot (include/global.h ~line 400): u16 itemId, u16 quantity.
local ITEM_SLOT = { size = 4, fields = {
  { name = "itemId",   type = "u16", offset = 0 },
  { name = "quantity", type = "u16", offset = 2 },
}}

-- struct Pokedex (include/global.h line 193), size 0x78 -- see header
-- cross-check above.
local POKEDEX = { size = 0x78, fields = {
  { name = "order",            type = "u8",  offset = 0x00 },
  { name = "mode",              type = "u8",  offset = 0x01 },
  { name = "unused",            type = "u8",  offset = 0x02, note = "set to 0xDA by EnableNationalPokedex_RSE, never read (real source comment)" },
  { name = "nationalMagic",     type = "u8",  offset = 0x03, note = "set to 0xB9 when national dex first enabled" },
  { name = "unownPersonality",  type = "u32", offset = 0x04 },
  { name = "spindaPersonality", type = "u32", offset = 0x08 },
  { name = "unknown3",          type = "u32", offset = 0x0C },
  { name = "owned",             type = "u8[52]", offset = 0x10, note = "DEX_FLAGS_NO bytes, bit-per-species" },
  { name = "seen",              type = "u8[52]", offset = 0x44, note = "DEX_FLAGS_NO bytes, bit-per-species" },
}}

-- struct SaveBlock2 (include/global.h line 327), size 0xF24.
SaveBlockLayout.SaveBlock2 = {
  size = 0xF24,
  source = "pokefirered include/global.h:327 struct SaveBlock2",
  fields = {
    { name = "playerName",          type = "u8[8]",  offset = 0x000, note = "PLAYER_NAME_LENGTH(7)+1" },
    { name = "playerGender",        type = "u8",     offset = 0x008, note = "MALE(0)/FEMALE(1)" },
    { name = "specialSaveWarpFlags",type = "u8",     offset = 0x009 },
    { name = "playerTrainerId",     type = "u8[4]",  offset = 0x00A, note = "TRAINER_ID_LENGTH" },
    { name = "playTimeHours",       type = "u16",    offset = 0x00E },
    { name = "playTimeMinutes",     type = "u8",     offset = 0x010 },
    { name = "playTimeSeconds",     type = "u8",     offset = 0x011 },
    { name = "playTimeVBlanks",     type = "u8",     offset = 0x012 },
    { name = "optionsButtonMode",   type = "u8",     offset = 0x013, note = "OPTIONS_BUTTON_MODE_*" },
    -- Header declares these as two separate u16 bitfield groups
    -- starting at 0x014 (comment says the second group's first byte is
    -- 0x15); this module doesn't compute bit-exact packing since it's
    -- not needed for default-value modeling -- see NewGameDefaults.lua
    -- for the real values each bitfield gets on a new game.
    { name = "optionsTextSpeed",      type = "bitfield:3", offset = 0x014, note = "OPTIONS_TEXT_SPEED_*" },
    { name = "optionsWindowFrameType",type = "bitfield:5", offset = 0x014, note = "text box border, 0-19" },
    { name = "optionsSound",          type = "bitfield:1", offset = 0x016, note = "OPTIONS_SOUND_*" },
    { name = "optionsBattleStyle",    type = "bitfield:1", offset = 0x016, note = "OPTIONS_BATTLE_STYLE_*" },
    { name = "optionsBattleSceneOff", type = "bitfield:1", offset = 0x016 },
    { name = "regionMapZoom",         type = "bitfield:1", offset = 0x016 },
    { name = "pokedex",             type = "struct", offset = 0x018, struct = POKEDEX },
    { name = "gcnLinkFlags",        type = "u32",    offset = 0x0A8 },
    { name = "unkFlag1",            type = "bool8",  offset = 0x0AC, note = "set TRUE, never read (real source comment)" },
    { name = "unkFlag2",            type = "bool8",  offset = 0x0AD, note = "set FALSE, never read (real source comment)" },
    { name = "encryptionKey",       type = "u32",    offset = 0xF20 },
  },
}

-- struct SaveBlock1 (include/global.h line 759), size 0x3D68.
SaveBlockLayout.SaveBlock1 = {
  size = 0x3D68,
  source = "pokefirered include/global.h:759 struct SaveBlock1",
  fields = {
    { name = "pos",                type = "Coords16", offset = 0x0000, note = "s16 x, s16 y" },
    { name = "location",           type = "struct", offset = 0x0004, struct = WARP_DATA, note = "current map warp; set from WarpToPlayersRoom() on new game via ApplyCurrentWarp" },
    { name = "continueGameWarp",   type = "struct", offset = 0x000C, struct = WARP_DATA },
    { name = "dynamicWarp",        type = "struct", offset = 0x0014, struct = WARP_DATA },
    { name = "lastHealLocation",   type = "struct", offset = 0x001C, struct = WARP_DATA },
    { name = "escapeWarp",         type = "struct", offset = 0x0024, struct = WARP_DATA },
    { name = "savedMusic",         type = "u16",    offset = 0x002C },
    { name = "weather",            type = "u8",     offset = 0x002E },
    { name = "weatherCycleStage",  type = "u8",     offset = 0x002F },
    { name = "flashLevel",         type = "u8",     offset = 0x0030 },
    { name = "mapLayoutId",        type = "u16",    offset = 0x0032 },
    { name = "playerPartyCount",   type = "u8",     offset = 0x0034 },
    { name = "playerParty",        type = "struct Pokemon[6]", offset = 0x0038, note = "PARTY_SIZE slots, 100 bytes each (see cross-check above); each slot's BoxPokemon-shaped payload matches BoxPokemonCodec.lua" },
    { name = "money",              type = "u32",    offset = 0x0290, note = "stored XORed with SaveBlock2.encryptionKey (see money.c SetMoney/GetMoney)" },
    { name = "coins",              type = "u16",    offset = 0x0294 },
    { name = "registeredItem",     type = "u16",    offset = 0x0296 },
    { name = "pcItems",            type = "ItemSlot[30]", offset = 0x0298, struct = ITEM_SLOT, note = "PC_ITEMS_COUNT" },
    { name = "bagPocket_Items",    type = "ItemSlot[42]", offset = 0x0310, struct = ITEM_SLOT, note = "BAG_ITEMS_COUNT" },
    { name = "bagPocket_KeyItems", type = "ItemSlot[30]", offset = 0x03B8, struct = ITEM_SLOT, note = "BAG_KEYITEMS_COUNT" },
    { name = "bagPocket_PokeBalls",type = "ItemSlot[13]", offset = 0x0430, struct = ITEM_SLOT, note = "BAG_POKEBALLS_COUNT" },
    { name = "bagPocket_TMHM",     type = "ItemSlot[58]", offset = 0x0464, struct = ITEM_SLOT, note = "BAG_TMHM_COUNT" },
    { name = "bagPocket_Berries",  type = "ItemSlot[43]", offset = 0x054C, struct = ITEM_SLOT, note = "BAG_BERRIES_COUNT" },
    { name = "seen1",              type = "u8[52]", offset = 0x05F8, note = "DEX_FLAGS_NO, Pokedex 'seen' mirror" },
    { name = "flags",              type = "u8[288]", offset = 0x0EE0, note = "NUM_FLAG_BYTES, bit-per-FLAG_*" },
    { name = "vars",               type = "u16[256]", offset = 0x1000, note = "VARS_COUNT, one u16 per VAR_0x4000..VAR_0x40FF" },
    { name = "gameStats",          type = "u32[64]", offset = 0x1200, note = "NUM_GAME_STATS" },
    { name = "rivalName",          type = "u8[8]",  offset = 0x3A4C, note = "PLAYER_NAME_LENGTH+1; explicitly preserved across NewGameInitData() (saved/restored around ClearSav1())" },
  },
}

return SaveBlockLayout
