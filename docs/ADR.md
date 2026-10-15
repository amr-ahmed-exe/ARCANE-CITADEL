# ARCANE CITADEL — ARCHITECTURAL DECISION RECORDS (ADR)

## ADR-001: Humanoid-Free Server Array Simulation for Wraiths
- **Context:** Default Roblox `Humanoid` instances run expensive physics and replication checks that lag the server above 80 NPCs.
- **Decision:** Represent Wraiths on the server as plain Luau coordinate structs in `WraithService.luau` and interpolate 3D meshes on the client in `WraithVisualController.luau` using `CFrame:Lerp`.
- **Consequence:** Supports 300+ active Wraiths at 60 FPS with minimal server CPU overhead.

## ADR-002: Sealed Permanent Vault & Session Soul Pot Separation
- **Context:** If Defenders could bank Souls into their Permanent Vault during an active Blood Pact, they would bank right before Wall 3 collapses, leaving Raiders with 0 loot.
- **Decision:** Seal `PermanentVaultSouls` while `IsBloodPactActive == true` and accumulate all generated Souls in `SessionSoulPot` (`33% -> 50% -> 100%` progressive breach split).
- **Consequence:** Preserves high-stakes PvP tension while keeping previously banked Vault Souls 100% safe from rage-quits.

## ADR-003: Preserve Project Toolchain Files During Orchestration Bootstrap (2026-10-15)
- **Context:** The orchestration guide ships generic `wally.toml`, `default.project.json`, `selene.toml`, and `.gitignore` templates, but this repo already had tuned versions (e.g. `brittonfischer/profileservice@2.1.5`, `servePort 34872`, Rojo plugin flow in `README.md`).
- **Decision:** Kept the existing `wally.toml`, `default.project.json`, and `.gitignore` untouched; only added the missing orchestration layer (`.claude/`, `docs/`, `scripts/`, `tests/`, `rokit.toml`, `.luaurc`, `.mcp.json`, `CLAUDE.md`, `assets/asset_manifest.json`).
- **Consequence:** Zero risk to the working Rojo/Wally sync while gaining the 5-stage pipeline, anti-deprecation gates, and living docs.
