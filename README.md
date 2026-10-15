# Arcane Citadel (Roblox)

Dark-witchery 3-wall concentric siege tycoon + cross-server invasion action-RPG.
Master blueprint: `D:\ROPLOX course\arcane_citadel_master_blueprint_rpg_economy (2).md`

## Prereqs (already installed on this machine)

- Rojo 7.7.1 (`rojo`), Rokit 1.2.0 (`rokit`), Wally 0.3.2 (`wally`)
- Roblox Studio (open, with a baseplate place)

If commands are not found in a fresh terminal, refresh PATH first:

```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','User') + ';' + [System.Environment]::GetEnvironmentVariable('Path','Machine')
```

## First-time setup

1. **Install dependencies:**
   ```powershell
   cd "C:\Users\Amr Ahmed\Downloads\My First Game"
   wally install
   ```
2. **Install the Rojo plugin in Studio:** Toolbox → Plugins → search `Rojo`
   (by rojo-rbx) → Install. This is what syncs these files into Studio.
3. **Serve the project:**
   ```powershell
   rojo serve
   ```
4. **In Studio:** open the Rojo plugin → Connect to `localhost:34872`.
   `src/shared` → ReplicatedStorage, `src/server` → ServerScriptService,
   `src/client` → StarterPlayerScripts.
5. **Verify Milestone 1:** press Play. Output must show
   `[ArcaneCitadel] Server runtime online.` and
   `[ArcaneCitadel] Client runtime online.` with zero errors.

## Pre-launch checklist

- [ ] Paste product/pass IDs into `ProductConfig.luau`.
- [ ] Lower or delete the Studio DEBUG grant in `GameService` (`DEBUG ONLY`).
- [ ] Game Settings → Security → Enable Studio Access to API Services
      (only needed for Studio testing; live games save automatically).
- [ ] Playtest with 2+ players: raid, fracture, bounty, breach split.
- [ ] Tune `WallConfig` / `WraithConfig` / `MultiplierMath` from sessions.
- [ ] Verify the 1.3x Crown promise still holds after any price edit:
      `MonetizationConfig.FindUnderValueItems()` should return `{}`.

## Monetization setup (Milestone 5, before launch)

1. Publish the place: Studio → **File → Publish to Roblox As…**.
2. Creator Hub → your game → **Monetization**:
   - 2 Game Passes: Master Alchemist, Dual Loadout & Auto-Roll.
   - 11 Developer Products: Blood Insurance, Vengeance Curse, Mercenary
     Pact, +3 Soul Tethers, Wraith Colossus, Royal Decree (early pact exit),
     Anvil Reforge x1 / x10, Shard packs (150 / 500 / 2,500).
3. Paste the numeric IDs into
   `src/shared/Configurations/ProductConfig.luau` (0 = disabled).
4. Until IDs are set, every BUY button explains the shop is coming soon —
   nothing can break or charge.

### The 1.3x rule

Every dual-priced item must satisfy `RawRobuxPrice / CrownPrice >= 1.3`,
i.e. `CrownPrice <= floor(RawRobuxPrice / 1.3)`. Run
`MonetizationConfig.FindUnderValueItems()` after editing any price —
three items drifted below the floor in earlier revisions (Anvil Reforge x1
was only 1.267x, both 149 R$ items were 1.296x).

Prices and Robux/Crown values live in
`src/shared/Configurations/MonetizationConfig.luau`; trait reforge costs
live in `TraitConfig` and must track the matching catalog entry.

## Layout

- `src/shared/Configurations` — data-driven balance tables (tune here, not in code)
- `src/shared/Framework` — reusable Studio SDK (NetworkRouter, StateMachine, ComponentEngine)
- `src/shared/Utility` — GearScoreMath, MultiplierMath
- `src/server` — authoritative Services + `Runtime.server.luau`
- `src/client` — Controllers + `Runtime.client.luau`
- `assets/ui` — designer `.rbxm` exports (Milestone 2+)

## Tuning invariants worth knowing

- **Trait weights must sum to 1000.** `TraitConfig.Traits[*].Weight` is a
  literal percentage of `TOTAL_TRAIT_WEIGHT`; an off-sum table silently
  rescales every drop rate.
- **Wall unlock cost is `WallConfig[i].UnlockCost`**, not
  `UpgradeCostBase`. They are separate sinks with very different scale.
- **`distributeLoot(wallIndex, stolen)` is the only breach funnel.** Every
  breach (decay, wraiths, raider combat) passes through it, and that is where
  `world.lastBreach` (the Blood Insurance receipt) is armed.
- **`ElixirAutoRenewMultiplier` is the auto-renew surcharge** (1.5x). The
  snapshot's `elixirCost` already accounts for it and for the Alchemist Pass.
- **Cooldowns live in `CombatInputController`** so the Q/E/R hotkeys and the
  SpellBar buttons share one timer and cannot bypass each other.
- **Inventory reads go through `EconomyClient.GetInventoryCached()`**, never a
  raw per-frame `InvokeServer`.
