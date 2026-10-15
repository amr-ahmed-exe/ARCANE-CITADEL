# assets/ui — Designer Exports

The master blueprint (§4.2) specifies 8 modular `.rbxm` UI packages
(`TopEconomyHUD`, `CitadelWallDrawer`, `BreachDecisionModal`,
`GlobalRaidBrowser`, `GrimoireAndAnvilModal`, `CombatAndInvaderHUD`,
`PlaytimeGiftGridModal`, `PanicMonetizationModals`).

This project implements all 8 screens **in code** instead
(`src/client/UI/*.luau` + `UITheme.luau`), which keeps UI in Git,
works with the Rojo single-script pipeline, and needs no binary
exports. Coverage map:

| Blueprint package (§4.2) | Code implementation |
| :--- | :--- |
| 1. `TopEconomyHUD.rbxm` | `TopEconomyHUD.luau` + `SpellBar.luau` |
| 2. `CitadelWallDrawer.rbxm` | `CitadelWallDrawer.luau` |
| 3. `BreachDecisionModal.rbxm` | `BreachDecisionModal.luau` |
| 4. `GlobalRaidBrowser.rbxm` | `GlobalRaidBrowser.luau` |
| 5. `GrimoireAndAnvilModal.rbxm` | `GrimoireAndAnvilModal.luau` |
| 6. `CombatAndInvaderHUD.rbxm` | `InvaderHUD.luau` + `SpellBar.luau` |
| 7. `PlaytimeGiftGridModal.rbxm` | `PlaytimeGiftGridModal.luau` |
| 8. `PanicMonetizationModals.rbxm` | `FifthDeathModal.luau` + `ShopModal.luau` (+ `BreachDecisionModal` insurance row) |
| Phase 2 extras | `AuctionBoardModal.luau`, `NoticeBanner.luau`, `HelpPanel.luau` |

If the designer later produces `.rbxm` files, drop them in this folder
and wire them through `UIController` (`UIActionButton` tag binder) —
the remotes (`EconomyClient.*`) stay unchanged.
