---
name: enforcing-luau-standards
description: Enforces strict Luau typing, modern non-deprecated Roblox APIs, Luau-LSP inline docstrings, CollectionService tag patterns, and Zero-Trust remote validation whenever reading or writing Luau files in src/.
paths:
  - "src/**/*.luau"
user-invocable: false
---

### Mandatory Luau Implementation, Anti-Deprecation & Inline Documentation Patterns for `src/**/*.luau`

1. **Consult the Living Anti-Deprecation Matrix:**
   - Always follow `.claude/skills/enforcing-luau-standards/references/deprecated_to_modern_matrix.md`.
   - If you need an unfamiliar Roblox Engine API, invoke `/verifying-roblox-apis` rather than guessing from pre-2026 training data.
2. **Header & Module Docstring Block:**
   - Line 1 MUST be `--!strict`.
   - Immediately below `--!strict`, include a module docstring header:
     ```luau
     --!strict
     --- @class CitadelService
     --- @server
     --- Authoritative server service managing the 3-Wall Concentric Citadel,
     --- Session Soul Pot vs. Permanent Vault routing, Ephemeral Elixirs, and Breach splits.
     ```
3. **Function & Type Docstrings (VS Code IntelliSense Compatible):**
   - Every public function and `export type` MUST have `---` docstrings specifying `@param`, `@return`, and security invariants:
     ```luau
     --- Attempts to purchase or auto-renew a 15-minute Defense Elixir for a specific wall ring.
     --- Deducts from `SessionSoulPot` during Blood Pact Mode or `PermanentVaultSouls` in Sanctuary Mode.
     --- @param session CitadelSession -- The player's active server citadel state
     --- @param wallIndex number -- Target wall ring (1, 2, or 3)
     --- @param isAutoRenewal boolean -- If true, applies the 1.5x surcharge unless HasAlchemistPass is true
     --- @param now number -- Current server timestamp (workspace:GetServerTimeNow() or os.clock())
     --- @return boolean -- True if purchase succeeded and ElixirExpiresAt was extended
     ```
4. **Zero-Trust Server Validation Pattern:**
   - Every `NetworkRouter.ListenServer(endpoint, function(player, payload) ...)` handler MUST validate payload types before indexing:
     ```luau
     if type(payload) ~= "table" then return end
     local wallIndex = payload.WallIndex
     if type(wallIndex) ~= "number" or wallIndex ~= wallIndex or wallIndex < 1 or wallIndex > 3 then
         return
     end
     ```
5. **Memory-Safe Lifecycle Pattern:**
   - Store per-player connections or state tables keyed by `player.UserId` and clean them up inside `Players.PlayerRemoving`.
