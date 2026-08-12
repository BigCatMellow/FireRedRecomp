-- ROM addresses of data tables, keyed by the SHA-1 RomImporter.verify()
-- already reports. These only exist for a *linked* ROM, not the decomp
-- source tree, so each entry here was read out of a real pokefirered.map
-- produced by building pokefirered-master locally (see PARITY_CONTRACT.md /
-- the memory note on the unprivileged build toolchain) and then confirmed
-- by decoding a few known records (Bulbasaur/Ivysaur/Venusaur/Charmander
-- base stats) out of the actual built ROM with SpeciesInfo.parseTable and
-- checking them against known values.
--
-- GBA ROM addresses are memory-mapped starting at 0x08000000; the .gba file
-- offset is address - 0x08000000.

local RomAddresses = {}

RomAddresses["41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc"] = { -- FireRed (US) v1.0
  -- gSpeciesInfo: struct SpeciesInfo[NUM_SPECIES], pokefirered src/data/pokemon/species_info.h
  gSpeciesInfo = 0x08254784 - 0x08000000,
  -- gBattleMoves: struct BattleMove[MOVES_COUNT], pokefirered src/data/battle_moves.h
  -- Verified against real Pound (index 1) / Karate Chop (index 2) data.
  gBattleMoves = 0x08250c04 - 0x08000000,
  -- gTypeEffectiveness: flat (atkType,defType,mult) byte triples, pokefirered src/battle_main.c
  gTypeEffectiveness = 0x0824f050 - 0x08000000,
  -- gItems: struct Item[], pokefirered src/data/items.h
  -- Verified against real Master Ball (index 1) / Ultra Ball (index 2) data.
  gItems = 0x083db028 - 0x08000000,
  -- gAbilityNames: fixed-stride charmap string table, pokefirered src/data/text/abilities.h
  -- Verified against real ABILITY_NONE (index 0) / ABILITY_STENCH (index 1) data.
  gAbilityNames = 0x0824fc40 - 0x08000000,
  -- gSpeciesNames: fixed-stride (POKEMON_NAME_LENGTH+1 = 11 bytes) charmap
  -- string table, pokefirered src/data/text/species_names.h
  -- Verified against real BULBASAUR/IVYSAUR/VENUSAUR/CHARMANDER data.
  gSpeciesNames = 0x08245ee0 - 0x08000000,
  -- gTrainers: struct Trainer[], pokefirered src/data/trainers.h
  -- Verified against real TRAINER_YOUNGSTER_BEN (index 89) data.
  gTrainers = 0x0823eac8 - 0x08000000,
  -- gMapGroups: array of pointers to per-group MapHeader-pointer tables,
  -- pokefirered src/overworld.c / include/global.fieldmap.h
  -- Verified against real MAP_PALLET_TOWN (group 3, num 0): resolves to a
  -- header with mapLayoutId=78, exactly LAYOUT_PALLET_TOWN.
  gMapGroups = 0x083526a8 - 0x08000000,
  -- gWildMonHeaders: flat array (linear-scanned by mapGroup/mapNum,
  -- terminated by mapGroup=0xFF), pokefirered src/data/wild_encounters.h
  -- Verified against real MAP_ROUTE1 (found at scan index 87): encounterRate=21,
  -- land mons exactly PIDGEY/RATTATA at the levels in wild_encounters.json.
  gWildMonHeaders = 0x083c9cb8 - 0x08000000,
  -- sNatureStatTable: static (no linker-map symbol; found via
  -- `arm-none-eabi-nm pokefirered.elf`), pokefirered src/pokemon.c
  -- Verified against real HARDY/LONELY/BRAVE/ADAMANT/MODEST/QUIRKY rows.
  sNatureStatTable = 0x08252b48 - 0x08000000,
  -- gAbilityDescriptionPointers: const u8*[ABILITIES_COUNT], pokefirered src/data/text/abilities.h
  -- Verified against real ABILITY_NONE/ABILITY_STENCH description text.
  gAbilityDescriptionPointers = 0x0824fb08 - 0x08000000,
  -- gNatureNamePointers: const u8*[NUM_NATURES], pokefirered include/pokemon_summary_screen.h
  -- Verified against real HARDY/LONELY/BRAVE/ADAMANT name text.
  gNatureNamePointers = 0x08463e60 - 0x08000000,
  -- gPokedexOrder_Alphabetical: u16[411], pokefirered src/data/pokemon/pokedex_orders.h
  -- Verified against real entries (OLD_UNOWN_B=387 at index 0, ABRA=63 at index 25).
  gPokedexOrder_Alphabetical = 0x08443fc0 - 0x08000000,
  gPokedexOrder_Weight = 0x084442f6 - 0x08000000,
  gPokedexOrder_Height = 0x084445fa - 0x08000000,
  gPokedexOrder_Type = 0x084448fe - 0x08000000,
  -- sSpeciesToNationalPokedexNum: static (no linker-map symbol; found via nm),
  -- u16[NUM_SPECIES], pokefirered src/pokemon.c
  -- Verified against real species 1-5 -> national dex 1-5.
  sSpeciesToNationalPokedexNum = 0x08251fee - 0x08000000,
  -- gMonFrontPicTable/gMonBackPicTable/gTrainerFrontPicTable: struct CompressedSpriteSheet[],
  -- pokefirered include/data.h. Verified: Bulbasaur's front sprite decompresses
  -- to exactly its declared size (2048 bytes).
  gMonFrontPicTable = 0x082350ac - 0x08000000,
  gMonBackPicTable = 0x0823654c - 0x08000000,
  gTrainerFrontPicTable = 0x0823957c - 0x08000000,
  -- gCryTable: struct ToneData[], pokefirered include/gba/m4a_internal.h
  gCryTable = 0x0848c914 - 0x08000000,
  -- gSongTable: struct Song[], pokefirered include/gba/m4a_internal.h
  -- Verified against real mus_dummy/se_use_item/se_pc_login entries.
  gSongTable = 0x084a32cc - 0x08000000,
  -- gMoveNames: fixed-stride (MOVE_NAME_LENGTH+1 = 13 bytes) charmap string
  -- table, pokefirered include/data.h. Verified against real POUND/KARATE CHOP.
  gMoveNames = 0x08247094 - 0x08000000,
  -- gTypeNames: fixed-stride (TYPE_NAME_LENGTH+1 = 7 bytes) charmap string
  -- table, pokefirered src/battle_main.c. Verified against real NORMAL(0)/GRASS(12).
  gTypeNames = 0x0824f1a0 - 0x08000000,
  -- Title screen (Phase 2 -- roadmap exit criterion, started early since
  -- the pieces already existed). pokefirered src/title_screen.c.
  -- gGraphics_TitleScreen_GameTitleLogo{Tiles,Map,Pals}: the logo layer,
  -- 8bpp (not 4bpp like every other graphic here) -- verified by eye
  -- against the real "Pokémon FireRed Version" logo art.
  gGraphics_TitleScreen_GameTitleLogoTiles = 0x08eab8c4 - 0x08000000,
  gGraphics_TitleScreen_GameTitleLogoMap = 0x08ead390 - 0x08000000,
  gGraphics_TitleScreen_GameTitleLogoPals = 0x08eab6c4 - 0x08000000,
  -- Box art Pokémon (Charizard) layer -- verified by eye (breathing fire,
  -- correct pose/colors matching the real title screen).
  gGraphics_TitleScreen_BoxArtMonTiles = 0x08ead608 - 0x08000000,
  gGraphics_TitleScreen_BoxArtMonMap = 0x08eadee4 - 0x08000000,
  gGraphics_TitleScreen_BoxArtMonPals = 0x08ead5e8 - 0x08000000,
  -- Copyright notice + "PRESS START" layer -- verified by eye (both
  -- legible, "©2004 GAME FREAK inc." and "PRESS START" correctly rendered).
  -- gGraphics_TitleScreen_BackgroundPals is shared with the (not yet
  -- implemented) border layer, loaded into a different VRAM bank there.
  gGraphics_TitleScreen_CopyrightPressStartTiles = 0x08eae0b4 - 0x08000000,
  gGraphics_TitleScreen_CopyrightPressStartMap = 0x08eae374 - 0x08000000,
  gGraphics_TitleScreen_BackgroundPals = 0x08eae094 - 0x08000000,
  -- Border background (bg3, furthest back) -- the flat backdrop band the
  -- (not yet implemented) animated flame OBJ sprites render over. Static/
  -- local symbols, not in the linker .map -- found via `nm`. Shares
  -- gGraphics_TitleScreen_BackgroundPals (loaded into a different VRAM
  -- bank in the real game, same color data). sBorderBgTiles is shared
  -- between FireRed/LeafGreen; sBorderBgMap has a per-game variant --
  -- this address is whichever this build's config.mk selected (FireRed).
  sBorderBgTiles = 0x083bf58c - 0x08000000,
  sBorderBgMap = 0x083bf5a8 - 0x08000000,
  -- Player overworld sprite (Red, standing/facing-down), pokefirered
  -- src/data/object_events/*. Uncompressed raw 4bpp (no .lz -- confirmed
  -- from source, not assumed), standard 1D OBJ tile mapping. Verified by
  -- eye: frame 0 is unmistakably the real player character sprite.
  gObjectEventPic_RedNormal = 0x0835bb68 - 0x08000000,
  gObjectEventPal_Player = 0x0835b968 - 0x08000000,
  -- Real OAM shape/size templates (pokefirered src/data/object_events/
  -- base_oam.h) -- verified byte-for-byte against OamShapeSize.lua's
  -- bitfield decode: 16x32 decodes to shape=2 (V_RECTANGLE) size=2,
  -- 16x16 decodes to shape=0 (SQUARE) size=1, both matching their names.
  gObjectEventBaseOam_16x32 = 0x083a3710 - 0x08000000,
  gObjectEventBaseOam_16x16 = 0x083a36f0 - 0x08000000,
  -- A second, genuinely different real object sprite (the ground Item
  -- Ball, 16x16 square -- not the player) to prove ObjectSprite.lua
  -- generalizes rather than being special-cased to RedNormal. Uncompressed
  -- 4bpp (confirmed from the real INCBIN_U16 source, same convention as
  -- the player sprite).
  gObjectEventPic_ItemBall = 0x0838ba28 - 0x08000000,
  gObjectEventPal_NpcWhite = 0x0836d888 - 0x08000000,
  -- Real dialogue-box font (FONT_NORMAL). Static/local symbols found via
  -- nm. Verified against real 'A'/'B' glyphs (correct letterforms with
  -- drop shadow) and the real width table ('A' is 6px wide).
  sFontHalfRowOffsets = 0x081ea044 - 0x08000000,
  sFontNormalLatinGlyphs = 0x081ff300 - 0x08000000,
  sFontNormalLatinGlyphWidths = 0x08207300 - 0x08000000,
  -- Standard window/dialogue border frame graphic + palette table
  -- (pokefirered src/text_window_graphics.c). Real (non-static) symbols,
  -- present in the linker .map. Verified by eye: composites to a clean
  -- 3x3 corner/edge border with no visual noise.
  gStdTextWindow_Gfx = 0x08471a4c - 0x08000000,
  gTextWindowPalettes = 0x08471dec - 0x08000000,
  -- Title screen flame OBJ sprite animation (pokefirered src/title_screen.c,
  -- FireRed only -- LeafGreen has a leaf sprite at a different address
  -- instead). Static/local symbols found via nm. sFlames_Gfx/_Pal are
  -- LZ77-compressed (unlike ObjectSprite.lua's uncompressed overworld
  -- sprites) -- confirmed from the real INCBIN_U32(...".4bpp.lz") source,
  -- not assumed. sSpriteAnim_Flame decodes to exactly the real source's
  -- ANIMCMD_FRAME(0,3), ANIMCMD_FRAME(4,6)...(36,6), ANIMCMD_END sequence
  -- (verified byte-for-byte, see SpriteAnim.lua's header comment).
  sFlames_Gfx = 0x083bf79c - 0x08000000,
  sFlames_Pal = 0x083bf77c - 0x08000000,
  sSpriteAnim_Flame = 0x083bfabc - 0x08000000,
}

-- Total record counts, confirmed via `arm-none-eabi-nm -S` on the real
-- linked ELF (array byte size / record size), used by the data viewer and
-- any other code that needs to know how far a table goes. Static/local
-- ROM layout facts, not per-ROM addresses, so kept separate from the table
-- above.
RomAddresses.COUNTS = {
  NUM_SPECIES = 412,      -- SPECIES_EGG, include/constants/species.h
  MOVES_COUNT = 355,      -- include/constants/moves.h
  NUM_TRAINERS = 743,     -- gTrainers is 0x7418 bytes / 40-byte record
  NUM_NATURES = 25,
}

return RomAddresses
