# ARCANE CITADEL — PUBLIC MODULE & NETWORK CONTRACTS
*(Maintained automatically by `@repo-librarian` at Stage 5 of every pipeline run)*

## 1. Exported Luau Types (`src/shared/` & `src/server/`)
*(Populated with exact `export type` blocks as modules are implemented)*

> Inventory 2026-10-15: all 50 `src/` modules are `--!strict`. Canonical type sources:
> `WallConfig`, `WraithConfig`, `TraitConfig`, `SpellConfig`, `SabotageConfig`,
> `ProductConfig`, `MonetizationConfig`, `MeshConfig`, `GraphicsConfig`,
> `GearConfig`, `AuctionConfig`, `AscensionConfig` (all under
> `src/shared/Configurations/`); framework types in `NetworkRouter`,
> `StateMachine`, `ComponentEngine` (`src/shared/Framework/`); math signatures in
> `MultiplierMath` (`CalculateBloodPactMultiplier`) and `GearScoreMath`
> (`src/shared/Utility/`). Next librarian pass must lift exact `export type`
> blocks here verbatim.

## 2. Public Module Function Signatures
*(Populated with `Module.Function(param: Type): ReturnType` signatures)*

> Known entry points to document verbatim on next pass:
> `MonetizationConfig.FindUnderValueItems()`, `EconomyClient.GetInventoryCached()`,
> `CitadelService.distributeLoot(wallIndex, stolen)`, server Services
> (`DataService`, `GameService`, `CitadelService`, `CombatService`,
> `WraithService`, `InvasionService`, `GearAndAnvilService`,
> `MonetizationService`, `AuctionService`, `WorldBuilder`, `MeshLoader`,
> `CharacterDresser`) and client Controllers (`CombatInputController`,
> `WraithVisualController`, `EconomyClient`, `CameraController`,
> `SoundController`).

## 3. Registered `NetworkRouter` Endpoints (Client <-> Server)
| Endpoint Name | Direction | Rate Limit (req/s) | Payload Schema | Server Zero-Trust Validation Rules |
| :--- | :--- | :--- | :--- | :--- |
| *(Populated as endpoints are registered)* | — | — | — | — |

> UI contract actions (see `audit_or_wireframe_ui.luau`) that must map to endpoints:
> `ToggleBloodPact`, `OpenCrownTreasury`, `UpgradeWall`, `PurchaseElixir`,
> `ToggleAutoRenewElixir`, `BreachAcceptDefeat`, `BreachHoldLine`,
> `SpendEclipseCrowns`, `PromptRobuxProduct`, `RefreshRaidBrowser`,
> `InvadeSelectedTarget`, `RollGrimoire`, `ToggleAutoRoll`,
> `ReforgeWeaponTrait`, `RepairWeaponFracture`, `SwapLoadoutPreset`,
> `CastSpell`, `ClaimPlaytimeGift`. Next librarian pass must confirm each
> against `NetworkRouter` registrations in `CitadelService`, `CombatService`,
> `GearAndAnvilService`, `InvasionService`, `MonetizationService`, `AuctionService`.
