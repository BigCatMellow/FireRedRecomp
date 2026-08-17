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
  -- gLevelUpLearnsets: const u16 *const[NUM_SPECIES],
  -- src/data/pokemon/level_up_learnset_pointers.h. Each pointer targets
  -- packed LEVEL_UP_MOVE(level, move) u16s through LEVEL_UP_END (0xFFFF).
  -- Linker-map address confirmed against the built US v1.0 ROM; consumed
  -- by LevelUpLearnset.lua/WildPokemonFactory.lua for real wild movesets.
  gLevelUpLearnsets = 0x0825d7b4 - 0x08000000,
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
  -- Normal Pokemon palettes: struct CompressedSpritePalette[NUM_SPECIES],
  -- same 8-byte pointer/tag/padding stride as the sprite-sheet tables.
  -- Used by BattleSceneAssets for the live wild-battle front/back pics.
  gMonPaletteTable = 0x0823730c - 0x08000000,
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
  -- Title screen slash-in effect sprite (OBJ window mask, not a visible
  -- sprite -- see SlashMask.lua/SlashSprite.lua). LZ77-compressed.
  -- Verified: decodes to an unmistakable diagonal slash/streak shape.
  sSlash_Gfx = 0x083bf64c - 0x08000000,
  -- Real sprite affine (rotation/scaling) animation data (pokefirered
  -- src/pokeball.c) -- the Pokéball wobble animation. Static/local
  -- symbols found via nm. Verified byte-for-byte against the real 8-byte
  -- (agbcc-padded) AffineAnimCmd entries -- see AffineAnim.lua's header
  -- comment.
  sAffineAnim_BallRotate_0 = 0x08260690 - 0x08000000,
  sAffineAnim_BallRotate_Right = 0x082606a0 - 0x08000000,
  sAffineAnim_BallRotate_Left = 0x082606b0 - 0x08000000,
  sAffineAnim_BallRotate_3 = 0x082606c0 - 0x08000000,
  -- Grass battle terrain (src/battle_bg.c's static sBattleTerrainTable
  -- entry). Static symbols found via nm; each address was checked against
  -- the linked ELF and the ROM LZ77 streams (palette -> 96 bytes, tiles ->
  -- 3136 bytes, screenSize=1 tilemap -> 4096 bytes).
  sBattleTerrainPalette_Grass = 0x08248400 - 0x08000000,
  sBattleTerrainTiles_Grass = 0x0824844c - 0x08000000,
  sBattleTerrainTilemap_Grass = 0x082489a8 - 0x08000000,
  -- Oak intro: the real opening narration text (pokefirered
  -- data/text/new_game_intro.inc, gOakSpeech_Text_WelcomeToTheWorld,
  -- referenced from src/oak_speech.c's Task_OakSpeech_WelcomeToTheWorld/
  -- _ThisWorld message chain). A real (non-static) global symbol.
  -- Verified: decodes via Charmap.decode to exactly the real source's
  -- literal text, "Hello, there!\nGlad to meet you!\pWelcome to the
  -- world of POKéMON!\pMy name is OAK.\pPeople affectionately refer to
  -- me\nas the POKéMON PROFESSOR.\p$", byte-for-byte including the
  -- accented é.
  gOakSpeech_Text_WelcomeToTheWorld = 0x081c5c78 - 0x08000000,
  -- SS Anne overworld object (Phase 2 "any sprite, any size/shape" --
  -- multi-OAM-entry subsprite compositing, SubspriteTable.lua/
  -- ObjectSprite.compositeSubsprites). pokefirered
  -- src/data/object_events/object_event_graphics.h. Real
  -- gObjectEventGraphicsInfo_SSAnne is 128x64px, exceeding the 64x64px
  -- single-OAM-entry cap -- its real subspriteTables
  -- (gObjectEventSpriteOamTables_128x64) composite it from 4 real 64x32
  -- quadrants. Static/local symbols, found via nm.
  gObjectEventPic_SSAnne = 0x08395b08 - 0x08000000,
  gObjectEventPal_SSAnne = 0x08395ae8 - 0x08000000,
  gObjectEventSpriteOamTable_128x64_0 = 0x083a3a20 - 0x08000000,
  -- The player's own real 16x32 object DOES fit one OAM entry but still
  -- has a real subspriteTables (gObjectEventSpriteOamTables_16x32) --
  -- reading the real table (src/data/object_events/
  -- object_event_subsprites.h) shows this is for real runtime
  -- OAM-priority layering (splitting one OAM into differently-prioritized
  -- pieces), NOT sprite-size compositing: table index 0 is a real
  -- {0, NULL} passthrough entry (render the single OAM as-is), which is
  -- the default. Kept here as a second, structurally different real
  -- SubspriteTable to decode against (single real entry, not a 4-way
  -- grid). Static/local symbols, found via nm.
  gObjectEventSpriteOamTables_16x16 = 0x083a3748 - 0x08000000,
  gObjectEventSpriteOamTable_16x16_0 = 0x083a3728 - 0x08000000,
  -- Oak intro scene graphics (pokefirered src/oak_speech.c). All four are
  -- `static` in that translation unit, so they're absent from the linker
  -- .map -- found via `nm pokefirered.elf`. Every one of these was then
  -- verified BYTE-FOR-BYTE: the ROM bytes at each address, for exactly the
  -- length implied by the next symbol's address, hash identical (sha1) to
  -- the corresponding built asset in the decomp tree
  -- (graphics/oak_speech/...), i.e. these are not "looks about right",
  -- they are the real data.
  --   sOakSpeech_Background_Pals  0x80 bytes = bg_tiles.gbapal (64 colors,
  --     4 banks, loaded at BG_PLTT_ID(0)). Shared with the Controls Guide
  --     and Pikachu Intro scenes.
  --   sOakSpeech_Background_Tiles 0x44 bytes = oak_speech_bg.4bpp.lz
  --     (LZ77 -> 320 bytes = 10 4bpp tiles).
  --   sOakSpeech_Background_Tilemap 0xAC bytes = oak_speech_bg.bin.lz
  --     (LZ77 -> 1280 bytes = 640 u16 entries = 32x20).
  --   sOakSpeech_Oak_Pal          0x40 bytes = oak/pal.gbapal (32 colors,
  --     loaded at BG_PLTT_ID(6) i.e. flat palette index 96).
  --   sOakSpeech_Oak_Tiles        0x698 bytes = oak/pic.8bpp.lz (LZ77 ->
  --     6144 bytes = 96 *8bpp* tiles = an 8x12-tile / 64x96px picture).
  sOakSpeech_Background_Pals = 0x08460568 - 0x08000000,
  sOakSpeech_Background_Tiles = 0x08460ca4 - 0x08000000,
  sOakSpeech_Background_Tilemap = 0x08460ce8 - 0x08000000,
  sOakSpeech_Oak_Pal = 0x08461cd4 - 0x08000000,
  sOakSpeech_Oak_Tiles = 0x08461d14 - 0x08000000,
  -- Dialogue-box frame graphic (pokefirered src/text_window.c,
  -- LoadMenuMessageWindowGfx: `LoadBgTiles(..., gMenuMessageWindow_Gfx,
  -- 0x280, ...)` = 20 uncompressed 4bpp tiles, paired with
  -- GetTextWindowPalette(0) = gTextWindowPalettes bank 0). This is the
  -- frame WindowFunc_DrawDialogueFrame draws -- a genuinely DIFFERENT
  -- graphic from the already-imported gStdTextWindow_Gfx (9 tiles, bank
  -- 3), which is the *standard menu* frame. Real (non-static) symbol,
  -- present in the linker .map. Verified by eye: composites to the real
  -- rounded dialogue-box frame with no visual noise.
  gMenuMessageWindow_Gfx = 0x0841f1c8 - 0x08000000,
  -- Object-event (NPC) graphics lookup (Phase 3 -- import/
  -- ObjectEventGraphicsInfo.lua). gObjectEventGraphicsInfoPointers: const
  -- struct ObjectEventGraphicsInfo *const[NUM_OBJ_EVENT_GFX=152], pokefirered
  -- src/data/object_events/object_event_graphics_info_pointers.h -- an array
  -- of POINTERS (not a flat struct array), indexed by an ObjectEventTemplate's
  -- graphicsId. Static/local symbol, found via nm. Verified: entry
  -- OBJ_EVENT_GFX_WOMAN_1 (23, Pallet Town's real Sign Lady NPC) resolves to
  -- exactly gObjectEventGraphicsInfo_Woman1's real nm address (0x083a3d60).
  gObjectEventGraphicsInfoPointers = 0x0839fdb0 - 0x08000000,
  -- sObjectEventSpritePalettes: const struct SpritePalette[] (real local
  -- array in src/event_object_movement.c, ~line 481) -- the small shared
  -- pool of real NPC/player overworld palettes, looked up by an
  -- ObjectEventGraphicsInfo's paletteTag (NOT one entry per graphicsId).
  -- Static/local symbol, found via nm. Verified byte-for-byte: entry index 2
  -- decodes to exactly gObjectEventPal_NpcGreen's real address (0x0836d868)
  -- and tag 0x1105 (OBJ_EVENT_PAL_TAG_NPC_GREEN, exactly Woman1's real
  -- .paletteTag); entry index 8 decodes to exactly this table's own
  -- gObjectEventPal_Player address (0x0835b968), an independent
  -- cross-check. Terminated by a real {NULL, 0} sentinel entry.
  sObjectEventSpritePalettes = 0x083a5158 - 0x08000000,

  -- ------------------------------------------------------------------
  -- New-game gender selection + naming screens (Phase 3)
  -- pokefirered src/oak_speech.c + src/naming_screen.c
  -- ------------------------------------------------------------------
  --
  -- Gender select is NOT its own screen with portraits: the real
  -- Task_OakSpeech_ShowGenderOptions just opens a small standard window
  -- over the already-drawn Oak scene and prints gText_Boy / gText_Girl
  -- with Menu_InitCursor -- exactly the Yes/No menu construct MenuCursor
  -- already models. These two strings are the whole "asset".
  -- Real (non-static) symbols. Verified: decode to exactly "BOY"/"GIRL".
  gText_Boy = 0x08415d93 - 0x08000000,
  gText_Girl = 0x08415d97 - 0x08000000,
  -- Oak's real prompts around the gender/naming flow (data/text/
  -- new_game_intro.inc). Real symbols. All five verified by decoding
  -- through Charmap: "Now tell me. Are you a boy?/Or are you a girl?",
  -- "Let's begin with your name./What is it?", "Right…/So your name is
  -- {PLAYER}.", "Your rival's name, what was it now?", "…Er, was it
  -- {RIVAL}?" -- including the real {PLAYER}/{RIVAL} placeholder bytes
  -- (FD 01 / FD 06) TextRenderer already substitutes.
  gOakSpeech_Text_AskPlayerGender = 0x081c59d5 - 0x08000000,
  gOakSpeech_Text_YourNameWhatIsIt = 0x081c5dea - 0x08000000,
  gOakSpeech_Text_SoYourNameIsPlayer = 0x081c5e13 - 0x08000000,
  gOakSpeech_Text_YourRivalsNameWhatWasIt = 0x081c5e91 - 0x08000000,
  gOakSpeech_Text_ConfirmRivalName = 0x081c5eb5 - 0x08000000,
  -- The real preset-name menus (src/oak_speech.c PrintNameChoiceOptions).
  -- Each is a `const u8 *const[]` pointer array, NOT a flat string table,
  -- so entries are 4-byte pointers into the gNameChoice_* strings.
  -- Static/local symbols, found via nm. Entry counts come from the gap to
  -- the next symbol (0x4C = 19 pointers each for the male/female lists;
  -- the rival list is the FireRed-only 4-entry one). Verified: male[0]
  -- decodes to "RED", female[2] to "OMI", rival[0..3] to "GREEN"/"GARY"/
  -- "KAZ"/"TORU", exactly the real FireRed #if branch (LeafGreen's list
  -- is a different set and would decode to GREEN/LEAF/... instead).
  sMaleNameChoices = 0x0846308c - 0x08000000,
  sFemaleNameChoices = 0x084630d8 - 0x08000000,
  sRivalNameChoices = 0x08463124 - 0x08000000,
  -- gOtherText_NewName: the "NEW NAME" first row of that same menu.
  gOtherText_NewName = 0x081c574f - 0x08000000,

  -- Naming screen (src/naming_screen.c). The keyboard is a real 4-row x
  -- 8-column character grid; three of these four tables are indexed by
  -- the real KEYBOARD_* id (0 = LETTERS_LOWER, 1 = LETTERS_UPPER,
  -- 2 = SYMBOLS), which is deliberately NOT the same order as the
  -- KBPAGE_* page-cycle order the running screen uses -- the real source
  -- comments on this ("the constants for the pages are needlessly
  -- complicated because GF didn't keep the indexing order consistent")
  -- and converts with sPageToKeyboardId. Static/local symbols, found via
  -- nm; their sizes agree exactly with the declared array shapes
  -- (sKeyboardChars is 3*4*8 = 96 bytes and runs exactly up to
  -- sPageColumnCounts; sPageColumnCounts is 3 bytes and runs exactly up
  -- to sPageColumnXPos).
  --
  -- Verified byte-for-byte against the real source's literals: the three
  -- pages decode through Charmap to "abcdef .","ghijkl ,","mnopqrs ",
  -- "tuvwxyz " / the same uppercase / "01234","56789","!?♂♀/-","…“”‘’".
  sKeyboardChars = 0x083e22d0 - 0x08000000,
  -- u8[3]: {8, 8, 6} -- the symbols page really is 6 columns wide, not 8.
  sPageColumnCounts = 0x083e2330 - 0x08000000,
  -- u8[3][8] pixel x of each column, used by the real SetCursorPos
  -- (cursorSprite->x = sPageColumnXPos[page][x] + 38). Verified:
  -- {0,12,24,56,68,80,92,123} for both letter pages, {0,22,44,66,88,110}
  -- for symbols.
  sPageColumnXPos = 0x083e2333 - 0x08000000,
  -- const u8 *const[3][4]: the 12 display strings the real
  -- PrintKeyboardKeys prints (one per keyboard row). These are NOT the
  -- same bytes as sKeyboardChars -- they carry the real
  -- EXT_CTRL_CODE_CLEAR (FC 11 <px>) inter-key spacing that lays the row
  -- out on screen, which is why the keyboard renders as real text rather
  -- than needing per-key tile art. Static/local symbol, found via nm.
  -- Verified: [1][0] (KEYBOARD_LETTERS_UPPER row 0) decodes to
  -- "{FC:11:0B}A{FC:11:06}B{FC:11:06}C{FC:11:1A}D..." exactly.
  sNamingScreenKeyboardText = 0x083e264c - 0x08000000,
  -- Naming screen BG art. gNamingScreenMenu_Gfx is the shared LZ77 tile
  -- set for all four BGs (real LoadGfx does LZ77UnCompWram once and
  -- LoadBgTiles it into bg1/bg2/bg3); the tilemaps are LZ77 too
  -- (DecompressToBgTilemapBuffer). Real (non-static) symbols, present in
  -- the linker .map. Verified: the tile set decompresses to a whole
  -- number of 4bpp tiles and each tilemap to exactly 32x20 entries
  -- (1280 bytes), and the composite is the real naming-screen panel art.
  gNamingScreenMenu_Gfx = 0x08e980e4 - 0x08000000,
  gNamingScreenBackground_Tilemap = 0x08e982bc - 0x08000000,
  -- Per-page keyboard panel tilemaps. Named by the KBPAGE_* page they
  -- belong to (real MainState_FadeIn loads Upper for the initial
  -- KBPAGE_LETTERS_UPPER page and Lower for the on-deck page).
  gNamingScreenKeyboardUpper_Tilemap = 0x08e98398 - 0x08000000,
  gNamingScreenKeyboardLower_Tilemap = 0x08e98458 - 0x08000000,
  gNamingScreenKeyboardSymbols_Tilemap = 0x08e98518 - 0x08000000,
  -- Palettes: gNamingScreenMenu_Pal is 0xC0 bytes = 6 real 16-color banks
  -- (loaded at BG_PLTT_ID(0)); gNamingScreenKeyboard_Pal is one bank
  -- (loaded at BG_PLTT_ID(10), which is exactly the paletteNum the real
  -- WIN_KB_PAGE_1/2 window templates use).
  gNamingScreenMenu_Pal = 0x08e98024 - 0x08000000,
  gNamingScreenKeyboard_Pal = 0x08e97fe4 - 0x08000000,
  -- The real 16x16 selection cursor OBJ (sSpriteTemplate_Cursor, .oam =
  -- sOam_16x16, 4 tiles / 0x80 bytes per the real sSpriteSheets entry).
  -- Uncompressed 4bpp, palette PALTAG_CURSOR = gNamingScreenMenu_Pal
  -- bank 5.
  gNamingScreenCursor_Gfx = 0x08e98df8 - 0x08000000,
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
