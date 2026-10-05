# P6-01: normal-field menu coverage and fallback inventory

- Record role: `RESEARCH / EVIDENCE`; ready for independent report review.
- Repository pin: `8f9924bfaf96e2889627a56eff5a1e899cab135e`.
- Public reference pin: `c75f352304d529f6ba92d4f74b9cf8b5c3810788`.
- Contract: [P6-01-FIELD-MENU-INVENTORY](../tasks/phase6-field-menu-coverage-inventory.md).
- Method: read source, production call sites, assertion bodies and existing
  review receipts. No tests, ROM, gameplay, runner operation or environment
  change was performed. Concurrent Restore HP working-tree changes are not
  part of this inventory's evidence.

## Boundary and evidence vocabulary

This inventory follows the normal-field START entry through its seven possible
actions, the existing Party and field-Bag states, Mart BUY/SELL/QUIT entry and
exit, and the PC storage/access boundary. Mart and PC are **not START actions**;
they are separate field-access boundaries. The report does not recursively
inventory all item effects, services, storage operations, battle menus,
new-game UI, generic scripts or later progression screens.

`CODE` means an inspected state/production branch exists, not demonstrated
playability. `UNIT` means an inspected assertion exists, not a new execution
result. `STUB` means the branch explicitly substitutes a message/return or
omits the named action. `UNKNOWN` preserves missing normal-entry, transition or
parity evidence. `RECEIPT` always names a bounded historical acceptance below.
The ordinary entry column is a **code trace**, not a live route claim. A hotkey,
override, storage model or passing component assertion cannot establish that
the no-developer-fallback exit gate is satisfied.

Runtime references are to [main.lua](../../main.lua) at the repository pin.
Reference-source paths/symbols below are all at the public reference pin. The
[capability checklist](../roadmaps/CAPABILITY_CHECKLIST.md) keeps Phase 6 IN
PROGRESS; [roadmap Phase 6](../../docs/roadmap.md) requires finishing without
developer tools or unimplemented-menu fallbacks. Neither status changes here.

## Assertion and receipt key

| Key | Inspected assertions / bounded receipt |
| --- | --- |
| T1 | [start_menu_test](../../tests/start_menu_test.lua): fresh/starter/full item order; new-press-only cursor; A selection; B/START close; closed-state inertness; zero-Dex-count sanity gate. No execution of main's selected-action branches. |
| T2 | [party_screen_test](../../tests/party_screen_test.lua): party rows/decoded display fields, wrap/repeat, selected slot, B/CANCEL, closed-state inertness. No SUMMARY/SWITCH/ITEM action or main return-path assertion. |
| T3 | [bag_screen_test](../../tests/bag_screen_test.lua): three pockets/clamping, context actions, explicit USE placeholder, quantity/confirmation/message TOSS timing, cancellation and empty/closed list. GIVE uses the same code branch, but the inspected placeholder scenario selects USE, not GIVE. |
| T4 | [pokemon_mart_menu_test](../../tests/pokemon_mart_menu_test.lua): BUY/SELL selection, quantity, confirm/cancel, money/capacity refusal, purchase/sale mutation, messages, quit and last-item removal. These assert the current simplified menu, not retail UI equivalence. |
| T5 | [pokemon_mart_test](../../tests/pokemon_mart_test.lua), [bag_test](../../tests/bag_test.lua), [session_bag_bridge_test](../../tests/session_bag_bridge_test.lua): transactions/capacity and save-array conversion; purchase/consumption/empty-slot/fixed-length round trips. Conversion is not disk persistence or proof of the live close callback. |
| T6 | [pc_boxes_test](../../tests/pc_boxes_test.lua): 14×30 capacity, sparse removal, bounds, and `fromStorage` mutating its source storage. [Capture rewards](../../tests/capture_rewards_test.lua) and [save codec](../../tests/save_file_codec_test.lua) provide separate capture/storage assertions, not a PC screen. |
| R1 | [Phase 3 review](../reviews/2026-09-12-phase3-complete-runtime-exit-review.md), `4f4f29ec`, accepts its continuous entry/Route 1 defeat/save/fresh-reload path. The pinned replay implementation calls `love.keypressed("k")` to save and `love.keypressed("l")` to load. Therefore this is not a START→SAVE confirmation or normal Continue-menu receipt, despite historical “normal callback” wording. |
| R2 | [Oak/Parcel final review](../reviews/oak-parcel-dex-presentation-north-final-review.md), `2d8c3221775044a54668683e500055307fe4d20b`, run `34547647645`, accepts its bounded Parcel/Dex/natural-purchase/capture/restart leaf. The earlier [Parcel integration review](../reviews/viridian-parcel-runtime-integration-review.md) explicitly records scene-1 non-shop and scene-2 Mart access. These do not accept all Mart SELL/Bag/Party paths. |
| R3 | [Save-contract review](../reviews/2026-09-21-save-version-contract-review.md), `63592c3`, and [rollover review](../reviews/2026-09-23-save-counter-rollover-review.md), `aec377a`, cover stated codec/round-trip assertions. They do not accept a PC menu, save confirmation UX, interruption atomicity or a full-party live catch→PC→fresh-reload path. |

Unless a row explicitly names R1/R2/R3, a dedicated independent normal-menu
receipt was not located: `UNKNOWN`. Test execution counts are intentionally not
invented or inferred from source comments.

## START profile and action matrix

The entry owner is `main.world.openStartMenu` (2130), called from the ordinary
walk/input branch (4636); it reads session flags `0x828` and `0x829` and
constructs [StartMenu](../../src/core/StartMenu.lua). Source:
`src/start_menu.c:SetUpStartMenu_NormalField`. There is no gameplay mutation
when constructing the item list. These three profile rows have ordinary-entry
code and T1 assertions; live profile-to-menu proof remains UNKNOWN.

| Profile ID | Flag inputs | Ordered actions and transition |
| --- | --- | --- |
| FRESH | Pokémon=false, Dex=false | `open`: BAG, PLAYER, SAVE, OPTION, EXIT (5) |
| STARTER | Pokémon=true, Dex=false | `open`: POKÉMON, BAG, PLAYER, SAVE, OPTION, EXIT (6) |
| DEX | Pokémon=true, Dex=true | `open`: POKÉDEX, POKÉMON, BAG, PLAYER, SAVE, OPTION, EXIT (7) |

The flags are independent in both source and code; these profiles do not imply
one flag logically derives from the other. The production constructor omits
`nationalDexCount`, although T1 covers an explicitly supplied zero count.
That corner-case wiring is UNKNOWN/unprovided, not proved by T1. R2 establishes
bounded Dex acquisition; the old comment above `openStartMenu` claiming Dex
acquisition does not exist is stale.

For rows S1–S7, ordinary entry is START → selection;
`main.world.handleStartMenuSelection` (2163) resets `selected` to `open` after
dispatch except EXIT. The retail source column names symbols in
`src/start_menu.c`. No row inherits a normal-route proof from hotkeys.

| ID/action | Source symbol | Runtime transition / owner | Mutation timing and return | Assertions / receipt | Status and route limit |
| --- | --- | --- | --- | --- | --- |
| S0 navigation/close | `StartCB_HandleInput`, `CloseStartMenu` | `StartMenu:processInput`: `open→selected` on A; `open→closed` on B/START; `world.closeStartMenu` clears child/menu fields | Navigation changes cursor only; close returns to field; closing an extant Bag additionally syncs its bag | T1 | CODE+UNIT; ordinary input entry present; complete field-input isolation/re-entry UNKNOWN |
| S1 POKÉDEX | `StartMenuPokedexCallback`, `StartMenuPokedexSanityCheck` | Selection reaches main's generic unavailable-message branch, then `open` | No Dex-content mutation or Dex screen | T1 gates/selection; R2 acquisition only | STUB; acquiring the flag does not implement the screen |
| S2 POKÉMON | `StartMenuPokemonCallback` | `selected→PartyScreen.browsing`; constructor uses read-only adapter over session `playerParty` | No party mutation on entry; no active party produces a refusal line; Party terminal states return to still-open START | T1+T2 | CODE+UNIT; ordinary entry code; no complete Party submenu receipt |
| S3 BAG | `StartMenuBagCallback` | `selected→BagScreen.browsing` using `SessionBagBridge.fromSaveBlock1` | Builds a separate live Bag; writes its contents to session on close; absent session/catalog produces refusal line | T1+T3+T5 | CODE+UNIT; ordinary entry code, main close/re-entry persistence proof UNKNOWN |
| S4 PLAYER | `StartMenuPlayerCallback` | Generic unavailable-message branch, then `open` | No Trainer Card screen/mutation | T1 item presence; no selected-branch assertion located | STUB; no ordinary Trainer Card proof |
| S5 SAVE | `StartMenuSaveCallback`, `StartCB_Save1/2`, `RunSaveDialogCB` | Main directly calls `saveGame`, then reopens START; no retail confirmation state machine | Encode/write occurs on selection; counter/previous bytes change after successful write; failure logs and returns | T1 presence; R1 callback save/reload, R3 codec only | CODE, incomplete UX; K shortcut is separate; START→SAVE/no-dev confirmation receipt UNKNOWN |
| S6 OPTION | `StartMenuOptionCallback` | Generic unavailable-message branch, then `open` | No options screen/settings mutation | T1 presence; no selected-branch assertion located | STUB; normal settings UI UNKNOWN |
| S7 EXIT | `StartMenuExitCallback` | `selected→world.closeStartMenu→field` | No item/party mutation; clears active fields (Bag sync safeguard as S0) | T1 selects/closes model; no main EXIT-specific receipt located | CODE; ordinary exit callback present, complete live return proof UNKNOWN |

## Party and field-Bag matrix

Party source symbols below belong to `src/party_menu.c`. Runtime is
[PartyScreen](../../src/core/PartyScreen.lua), entered by S2, with main's
terminal handling at 4569. All three implemented states are enumerated.

| ID/state | Source symbol | Ordinary runtime transition | Mutation timing / cancel / return | Assertions / receipt | Status |
| --- | --- | --- | --- | --- | --- |
| P1 `browsing` | `CB2_PartyMenuFromStartMenu`, `UpdatePartySelectionSingleLayout` | Held-repeat list navigation over filled slots plus CANCEL; A on mon→`confirmed` | Display/selection only; session party is not copied or edited | T2 | CODE+UNIT; live list coverage UNKNOWN |
| P2 `confirmed` | `HandleChooseMonSelection`, `Task_TryCreateSelectionWindow` | Main logs selected slot and clears Party instead of opening retail action window | No SUMMARY/SWITCH/ITEM mutation; returns to START like cancellation | T2 confirms slot, not submenu; no receipt | STUB frontier; selection is not a completed party action |
| P3 `closed` | `HandleChooseMonCancel`, `Task_ClosePartyMenu` | B or A-on-CANCEL→`closed`; main clears Party, exposes still-open START | No party mutation; later model input inert | T2 | CODE+UNIT; main return receipt UNKNOWN |

Bag source symbols below belong to `src/item_menu.c` except the named quantity
helper in `src/menu_helpers.c`. Runtime is [BagScreen](../../src/core/BagScreen.lua),
entered by S3; main handles terminal sync at 4583. All six states are listed.
The three field pockets are ITEMS, KEY ITEMS, POKÉ BALLS; TM Case/Berry Pouch
are separate retail screens, not extra LEFT/RIGHT pockets.

| ID/state | Source symbol | Ordinary runtime transition | Mutation timing / cancel / return | Assertions / receipt | Status |
| --- | --- | --- | --- | --- | --- |
| B1 `browsing` | `Task_BagMenu_HandleInput`, `ProcessPocketSwitchInput` | Pocket LEFT/RIGHT clamps and rebuilds cursor at row 0; item A→`context_menu`; B/CLOSE→`closed` | No quantity change; retail per-pocket cursor memory is not implemented | T3 list/pockets/empty list | CODE+UNIT, explicitly simplified; normal live pocket persistence UNKNOWN |
| B2 `context_menu` | `sContextMenuItems_Field`, `Task_ItemContextMenuByLocation` | ITEMS: USE/GIVE/TOSS/CANCEL; KEY: USE/CANCEL; BALLS: GIVE/TOSS/CANCEL; B/CANCEL→browsing | USE/GIVE→unavailable `message`, no item effect; REGISTER omitted; TOSS→quantity if >1, otherwise confirm | T3 actions, USE placeholder, cancel, single-copy shortcut | CODE+STUB; no field-use/held-item/REGISTER proof |
| B3 `toss_quantity` | `Task_SelectQuantityToToss`; `AdjustQuantityAccordingToDPadInput` | Quantity changes; A→confirm; B→browsing | Selection only, no bag removal | T3 quantity/cancel | CODE+UNIT; no independent ordinary TOSS receipt |
| B4 `toss_confirm` | `Task_ConfirmTossItems`, `Task_TossItem_Yes/No` | A records pending quantity→message; B→browsing | No removal yet; implementation has A-accept/B-cancel, not a separately navigable Yes/No cursor | T3 verifies pre-removal state/cancel | CODE+UNIT, bounded confirmation; full retail confirmation UI UNKNOWN |
| B5 `message` | `Task_WaitAB_RedrawAndReturnToBag` | A or B acknowledges→browsing | Pending TOSS removes from live Bag only now and rebuilds list; USE/GIVE message has no removal; session not synchronized until close | T3 explicit mutation-after-ack and last-copy removal; T5 conversion | CODE+UNIT; normal close/save/reload sequence UNKNOWN |
| B6 `closed` | `Bag_BeginCloseWin0Animation`, `ItemMenu_StartFadeToExitCallback` | Main syncs live Bag via `toSaveBlock1`, clears Bag, returns to START | Session arrays replaced on close; disk write is separate; model input inert | T3 closed state, T5 round trip; no main-close receipt | CODE+UNIT; no claim that animation/callback ordering matches retail |

## Mart matrix

Ordinary-entry code: `main.tryStartInteraction→startScript→DialogueRunner`
records `pendingMartItemListPtr`; `dialogueTask` (886) resolves the stock and
calls `world.beginMart` (2009). This is not a generic-script acceptance claim.
The bounded Parcel controller/presenters guard the first Viridian visit and
scene-1 non-shop case; R2 covers the later bounded purchase path. The separate
`M` developer route can call the same constructor from another session location
with fixed stock; it proves no field access. Both routes feed the six states of
[PokemonMartMenu](../../src/core/PokemonMartMenu.lua) below.

| ID/state | Source symbol | Entry / runtime transition | Mutation timing / cancel / return | Assertions / receipt | Status |
| --- | --- | --- | --- | --- | --- |
| M1 `topmenu` | `shop.c:Task_ShopMenu`, `sShopMenuActions_BuySellQuit` | Script route or M; BUY→buy list; SELL→sell list; QUIT/B→done | Constructor copies bag/money from session; no purchase yet | T4; R2 bounded ordinary BUY access | CODE+UNIT+bounded RECEIPT; all shops/SELL entry UNKNOWN |
| M2 `list` | `shop.c:Task_BuyMenu`; `item_menu.c:Task_ItemContext_Sell` | BUY item→quantity or insufficient-money message; SELL→quantity, or confirm when one owned; B→topmenu | No transaction; SELL includes owned priced ITEMS/BALLS only | T4 list/insufficient money/single-copy/price-zero filter | CODE+UNIT; simplified SELL, excludes TM/Berry screens; list-end retail behavior UNKNOWN |
| M3 `quantity` | `shop.c:Task_BuyHowManyDialogueInit`; `item_menu.c:Task_SelectQuantityToSell`; `menu_helpers.c:AdjustQuantityAccordingToDPadInput` | A→confirm; B→list; quantity navigation | No transaction; BUY max derives from money, SELL from owned count, capped 99 | T4 quantity/cancel | CODE+UNIT; ordinary full matrix UNKNOWN |
| M4 `confirm` | `shop.c:BuyMenuTryMakePurchase/BuyMenuSubtractMoney`; `item_menu.c:Task_SellItem_Yes/Task_FinalizeSaleToShop` | A calls `PokemonMart.buy/sell`→message; B→list | Current code changes live bag and local money together on A; failed BUY leaves money unchanged; no session sync yet | T4 explicitly asserts transaction before message acknowledgment; T5 math/capacity | CODE+UNIT, not retail timing parity (see below); R2 purchase only |
| M5 `message` | `shop.c:Task_ReturnToItemListAfterItemPurchase`; `item_menu.c:Task_FinalizeSaleToShop` | A/B→configured after-message list/state | Current menu only advances state; transaction already applied (or refusal preserved it) | T4 purchase/sale acknowledgment and rebuilt sell list | CODE+UNIT; reference callback order differs; timing parity not claimed |
| M6 `done` | `shop.c:Task_ShopMenu` quit path; `scrcmd.c:ScrCmd_pokemart` | QUIT/B from topmenu; main update→`world.closeMart` (2025) | Writes bag and money to session, clears Mart; notifies waiting DialogueRunner so script may resume; M/view-key exit also uses close | T4 quit/inert state, T5 conversion, R2 bounded purchase/restart | CODE+UNIT+bounded RECEIPT; arbitrary script return, developer re-entry and interruption behavior UNKNOWN |

Reference timing must not be inferred from the menu tests' “real” wording.
`shop.c:BuyMenuTryMakePurchase` adds the bag item, then schedules
`BuyMenuSubtractMoney` as a message callback; the local transaction helper
combines these effects. For SELL, `item_menu.c:Task_SellItem_Yes` schedules
`Task_FinalizeSaleToShop` through `DisplayItemMessageInBag`, and that later
function removes items/adds money. The local menu applies both at confirmation
before entering MESSAGE. This is a source/code ordering difference, not a new
observed gameplay defect or authority to fix it. Exact text/animation/callback
timing would need a separately scoped source lock.

## PC boundary matrix

No PC UI is inferred from storage allocation, capture overflow or codec tests.
Conversely, a missing screen is not evidence that persistent PC backing is
absent. Storage is not an eighth START item in the source normal-field list.

| ID | Source symbol | Runtime entry / transition | Mutation timing / return | Assertions / receipt | Status / route |
| --- | --- | --- | --- | --- | --- |
| PC1 persisted container | `include/pokemon_storage_system.h:PokemonStorage`; `pokemon_storage_system.c:GetBoxMonDataAt/SetBoxMonDataAt` | Main `GameSession.fromNewGame/fromSavedState` (354/381)→`PcBoxes.fromStorage`; capture owns separate insertion seam | Boxes alias saved storage; add/remove changes backing immediately; codec/disk write separate; no menu close transition | T6; R3 codec/roundtrip; [ledger](../../docs/behavior-ledger.md) preserves full-party live reload UNKNOWN | CODE+UNIT+bounded storage RECEIPT, not a developer-only fake store or a UI route |
| PC2 player access | `pokemon_storage_system_menu.c:ShowPokemonStorageSystemPC`, `Task_PCMainMenu` | No corresponding player-facing PC state machine/normal field opener located among main and current UI modules | No UI selection/cancel/return or user-driven withdraw/deposit mutation can be evidenced here | T6 does not cover UI; no independent normal PC receipt located | UNKNOWN normal access; no UI owner found; do not infer UI from PC1 or implement it here |

## Developer/fallback ledger and unresolved boundaries

| Seam | Exact code anchor | Inventory treatment |
| --- | --- | --- |
| M opens fixed Mart stock from a session location | `main.love.keypressed`, 5144; `world.beginMart` | Developer convenience, not evidence of clerk/script/scene access; normal script path is separately identified above |
| K save / L load | `main.love.keypressed`, 5157/5161; `saveGame/loadGameFile` | K shares the SAVE callback; L reaches the loader. R1/R2 replay use of these public hotkeys cannot close the Phase 6 no-dev menu gate. A normal Continue-menu route was not established by this inventory. |
| View/new-game switches | `main.world.clearViews` and `love.keypressed`, 5075 onward | V/T/P/I/F/O/S/N/A/Y/W toggle views or fresh flow; not normal-menu entry proof. `clearViews` closes/persists Mart but is not a general audit of Bag/Party state cleanup. Cross-view stale state/input isolation remains UNKNOWN. |
| Environment/replay entry | `main.love.load`: `POKEPORT_VIEWER`, `POKEPORT_WALK`, `POKEPORT_NEWGAME`, `POKEPORT_BATTLE`, `POKEPORT_RUNTIME_REPLAY` | Diagnostics/fixture or replay entry must be labeled; no override used here, and a replay requires inspection of what inputs it actually drives |
| Party / Bag / START unavailable branches | P2, B2, S1/S4/S6 | Explicit action frontiers, not implemented mechanics disguised as successful selection |
| Level-up move gap | `main.world` trainer reward path (1464), wild reward path (4511), `allowLevelUpMoveGap` | Existing reward paths can report a skipped learned move because the UI is missing; record as an external P4/P6 dependency, with no battle-menu/mechanic expansion here |

Known evidence limits include the unprovided live zero-Dex-count gate, missing
Party action window, Bag item-use/give/register and separate case/pouch screens,
save confirmation flow, Trainer Card/Options/Dex screens, complete Mart SELL
and script-return timing, and PC player access. This is not an exhaustive
inventory of all Phase 6 services. Centers, tutors, name rater, daycare, trades,
evolution, Town Map, Hall of Fame and accessibility/mod overlays are excluded.

The source table/model states are fully enumerated for this boundary: START
`open/selected/closed`; Party `browsing/confirmed/closed`; Bag six and Mart six
states above (18 model states total). Three START profiles, seven actions plus
navigation, and the two PC axes are explicitly distinct from those state counts.
No count is a coverage percentage or playable-route assertion.

## Worker handoff

The report is source/test-assertion evidence only. Source symbols and current
production bodies were compared at the stated pins; model assertions and
historical receipts were kept separate. The only edits are this report and its
task handoff. No runtime/test execution, ROM/private runner access, route
changes, state preparation, generated asset, save-format change or canonical
status advancement occurred.

Independent report review must PASS before a Phase 6 design/implementation
task. This inventory does not select or authorize a fix, create a successor,
or consume either queued P4 Restore HP or P5 old-man route. A later contract
must choose a bounded missing UI seam and preserve those packages' exclusions.
