# ARCANE CITADEL — LIVE REPOSITORY STATE
*(Maintained automatically by `@repo-librarian` at Stage 5 of every pipeline run)*

## 1. Milestone Completion Status
- [x] **Milestone 1:** Toolchain, Core SDK (`NetworkRouter`, `StateMachine`, `ComponentEngine`) & UUID `DataService`
- [x] **Milestone 2:** Grey-Box 3-Wall Citadel, Session Soul Pot vs. Vault, Elixirs (`+50%` Auto-Renew) & `33%/50%/100%` Breach Split
- [x] **Milestone 3:** Humanoid-Free Wraith Engine, RPG Combat (`Q/E/R`), Dual Loadouts & Arcane Anvil Reforging
- [x] **Milestone 4:** Cross-Server Raid Browser (`MemoryStoreSortedMap`), 5-Life Gear Fracture & 90s Anti-Combat Log
- [x] **Milestone 5:** Dual-Checkout Monetization (`1.3x` Eclipse Crowns vs. Raw Robux), Playtime Gifts & Phase 2 Escrow Auction House

> Status verified 2026-10-15: `src/` contains 50 `.luau` modules covering all five milestones. Orchestration scaffold (`.claude/`, `docs/`, `scripts/`, `tests/`) installed from `claude_code_ai_orchestration_guide.md`.

## 2. Implemented `src/` Modules
| File Path | Context | Owner Agent | Dependencies | Purpose & Key Exports |
| :--- | :--- | :--- | :--- | :--- |
| src/server/Runtime.server.luau | Server | @luau-worker | Services/* | Server entry point; boots all Services in dependency order |
| src/client/Runtime.client.luau | Client | @luau-worker | Controllers/*, UI/* | Client entry point; boots all Controllers and UI modules |
| src/shared/Framework/NetworkRouter.luau | Shared | @luau-worker | — | Rate-limited RemoteEvent/RemoteFunction registry; Zero-Trust payload validation entry |
| src/shared/Framework/StateMachine.luau | Shared | @luau-worker | — | Generic finite-state machine used by gameplay flows |
| src/shared/Framework/ComponentEngine.luau | Shared | @luau-worker | — | ECS-style component registry for gameplay entities |
| src/shared/Utility/MultiplierMath.luau | Shared | @luau-worker | — | Blood Pact multiplier math; `CalculateBloodPactMultiplier` |
| src/shared/Utility/GearScoreMath.luau | Shared | @luau-worker | GearConfig | Gear score aggregation and power-curve math |
| src/shared/Configurations/WallConfig.luau | Shared | @luau-worker | — | 3-wall decay (`1.0x/0.8x/0.6x`), breach splits, `ElixirAutoRenewMultiplier` |
| src/shared/Configurations/WraithConfig.luau | Shared | @luau-worker | — | Humanoid-free wraith wave tuning tables |
| src/shared/Configurations/TraitConfig.luau | Shared | @luau-worker | — | Grimoire trait weights (sum = 1000) and reforge costs |
| src/shared/Configurations/SpellConfig.luau | Shared | @luau-worker | — | Q/E/R spell definitions, cooldowns, scaling |
| src/shared/Configurations/SabotageConfig.luau | Shared | @luau-worker | — | Sabotage action costs and effects during invasions |
| src/shared/Configurations/ProductConfig.luau | Shared | @luau-worker | — | Robux product/pass numeric IDs (0 = disabled) |
| src/shared/Configurations/MonetizationConfig.luau | Shared | @luau-worker | — | Dual-price catalog; `FindUnderValueItems`, 1.3x Crown law |
| src/shared/Configurations/MeshConfig.luau | Shared | @luau-worker | — | 3D mesh asset IDs and LOD tuning |
| src/shared/Configurations/GraphicsConfig.luau | Shared | @luau-worker | — | Client graphics quality tiers and effect budgets |
| src/shared/Configurations/GearConfig.luau | Shared | @luau-worker | — | Weapon/gear base stats and upgrade curves |
| src/shared/Configurations/AuctionConfig.luau | Shared | @luau-worker | — | Escrow Auction House fees, durations, limits |
| src/shared/Configurations/AscensionConfig.luau | Shared | @luau-worker | — | Ascension reset thresholds and permanent bonuses |
| src/server/Services/DataService.luau | Server | @luau-worker | ProfileService, NetworkRouter | UUID ProfileService saves; session vs. permanent currency routing |
| src/server/Services/GameService.luau | Server | @luau-worker | DataService, NetworkRouter | Match/session lifecycle; DEBUG grant (remove before launch) |
| src/server/Services/CitadelService.luau | Server | @luau-worker | WallConfig, DataService | 3-wall state, elixirs, breach split via `distributeLoot` |
| src/server/Services/CombatService.luau | Server | @luau-worker | SpellConfig, GearScoreMath | Authoritative spell hits, damage, anti-exploit checks |
| src/server/Services/WraithService.luau | Server | @luau-worker | WraithConfig | Humanoid-free server coordinate-array wraith simulation |
| src/server/Services/InvasionService.luau | Server | @luau-worker | MemoryStoreSortedMap | Cross-server raid browser publish/query; 90s anti-combat-log |
| src/server/Services/GearAndAnvilService.luau | Server | @luau-worker | GearConfig, TraitConfig | Loadouts, grimoire rolls, anvil reforging, 5-life fracture |
| src/server/Services/MonetizationService.luau | Server | @luau-worker | MonetizationConfig, ProductConfig | Dual-checkout (Robux vs. Crowns); `ProcessReceipt` handler |
| src/server/Services/AuctionService.luau | Server | @luau-worker | AuctionConfig | Phase 2 escrow listings, bids, settlement |
| src/server/Services/WorldBuilder.luau | Server | @luau-worker | WallConfig | Runtime citadel geometry validation and repair |
| src/server/Services/MeshLoader.luau | Server | @luau-worker | MeshConfig, asset_manifest | Resolves `rbxassetid://` URIs and streams meshes |
| src/server/Services/CharacterDresser.luau | Server | @luau-worker | — | Applies cosmetic loadout visuals to player characters |
| src/client/Controllers/CombatInputController.luau | Client | @luau-worker | SpellConfig, NetworkRouter | Q/E/R hotkeys + SpellBar shared cooldown timers |
| src/client/Controllers/WraithVisualController.luau | Client | @luau-worker | WraithService (via remotes) | Client `CFrame:Lerp` interpolation of wraith meshes |
| src/client/Controllers/EconomyClient.luau | Client | @luau-worker | NetworkRouter | Cached inventory reads via `GetInventoryCached` |
| src/client/Controllers/CameraController.luau | Client | @luau-worker | — | Siege camera rig and shake effects |
| src/client/Controllers/SoundController.luau | Client | @luau-worker | — | Dark-witchery SFX/music bus management |
| src/client/UI/UITheme.luau | Client | @luau-worker | — | Shared Dark Witchery palette, fonts, spacing tokens |
| src/client/UI/TopEconomyHUD.luau | Client | @luau-worker | EconomyClient, UITheme | Soul pot / vault balances; Blood Pact toggle |
| src/client/UI/CitadelWallDrawer.luau | Client | @luau-worker | NetworkRouter, UITheme | Wall upgrades, elixir purchase, auto-renew toggles |
| src/client/UI/BreachDecisionModal.luau | Client | @luau-worker | NetworkRouter, UITheme | Accept-defeat (bank 67%) vs. hold-line vs. Blood Insurance |
| src/client/UI/GlobalRaidBrowser.luau | Client | @luau-worker | InvasionService (via remotes) | Cross-server target list and invade action |
| src/client/UI/GrimoireAndAnvilModal.luau | Client | @luau-worker | GearAndAnvilService (via remotes) | Rolls, auto-roll, reforge, fracture repair, loadout swap |
| src/client/UI/CombatAndInvaderHUD.luau | Client | @luau-worker | CombatInputController | (Consolidated into InvaderHUD + SpellBar; see below) |
| src/client/UI/InvaderHUD.luau | Client | @luau-worker | CombatInputController, UITheme | Invasion-mode combat overlay for raiders |
| src/client/UI/SpellBar.luau | Client | @luau-worker | CombatInputController, UITheme | Q/E/R cast buttons sharing one cooldown timer |
| src/client/UI/AuctionBoardModal.luau | Client | @luau-worker | AuctionService (via remotes) | Escrow listings, bidding, claim UI |
| src/client/UI/ShopModal.luau | Client | @luau-worker | MonetizationService (via remotes) | Crown treasury + Robux dual-checkout storefront |
| src/client/UI/PlaytimeGiftGridModal.luau | Client | @luau-worker | NetworkRouter, UITheme | 10m/30m/60m playtime gift claims |
| src/client/UI/FifthDeathModal.luau | Client | @luau-worker | NetworkRouter, UITheme | Fifth-death panic offers (tethers, vengeance) |
| src/client/UI/NoticeBanner.luau | Client | @luau-worker | TextChatService fallback | System announcements and event toasts |
| src/client/UI/HelpPanel.luau | Client | @luau-worker | UITheme | Onboarding help and control reference |

## 3. Verified Studio 3D & UI Tags
- **3D `Workspace.CitadelGeometry` Status:** Generator ready (`/greyboxing-citadel`); verify in Studio Edit Mode
- **UI `StarterGui` Wireframes / `.rbxm` Status:** Auditor ready (`/validating-ui-contracts`); 8 screens with `UIActionButton` tags
- **3D `assets/asset_manifest.json` Status:** Empty (`{}`); populate via `/forging-3d-asset`
