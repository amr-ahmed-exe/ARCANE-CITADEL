# ARCANE CITADEL — STUDIO CONSTITUTION

Master GDD & Math Blueprint: `@arcane_citadel_master_blueprint.md` (read relevant sections on demand).
Orchestration & Self-Setup Reference: `@claude_code_ai_orchestration_guide.md`.
AI Fast-Lookup Memory: `@docs/REPO_STATE.md`, `@docs/API_CONTRACTS.md`, and `@docs/ADR.md`.
Human Engineering Guidebook: `@docs/DEVELOPER_GUIDEBOOK.md`.
Anti-Deprecation Reference: `@.claude/skills/enforcing-luau-standards/references/deprecated_to_modern_matrix.md`.

## 1. HIERARCHICAL PIPELINE LAW
Never write production code directly in the main orchestrator thread. Route all feature and milestone work through the 5-Stage Pipeline (`/implementing-milestone` or `/building-feature`) and record progress in `docs/specs/pipeline_state.md`:
1. `@chief-architect` (`claude-opus-5-5`, `effort: high`) -> Verifies modern Roblox APIs (`verifying-roblox-apis`) & writes `docs/specs/current_task.md`.
2. `@luau-worker` / `@studio-world-worker` / `@blender-worker` (`claude-sonnet-5-5`) -> Implements spec + `---` Luau-LSP docstrings.
3. `@principal-reviewer` (`claude-opus-5-5`, `effort: high`) -> Audits `git diff` for bugs, exploits, deprecated APIs & missing docstrings.
4. `@qa-playtest-tester` (`claude-sonnet-5-5`) -> Runs automated tests & remote fuzzer in Studio Play Mode MCP.
5. `@repo-librarian` (`claude-sonnet-5-5`) -> Runs `/syncing-documentation` to update AI context tables (`REPO_STATE.md`, `API_CONTRACTS.md`) and human developer guides (`DEVELOPER_GUIDEBOOK.md`, `ADR.md`, `CHANGELOG.md`).

## 2. NON-NEGOTIABLE ENGINEERING & ANTI-DEPRECATION LAWS
- **Strict Typing & Docstrings:** Every `.luau` file in `src/` MUST start with `--!strict` on line 1, a module-level header comment block, and `---` Luau-LSP docstrings (`@param`, `@return`) above every public function and exported type.
- **Zero Deprecated Roblox/Lua APIs:** Enforced by `scan_deprecated_apis.sh`. Never use `wait()`, `spawn()`, `delay()`, `BodyVelocity`, `BodyGyro`, `FindPartOnRay`, `WaitForChild` chains on tagged items, or `game.Lighting` property indexing. Always use `task.*`, `workspace:Raycast()`, `AlignPosition`/`LinearVelocity`, `workspace:GetServerTimeNow()`, and `game:GetService(...)`. When unsure of a modern Roblox API, run `/verifying-roblox-apis`.
- **Humanoid-Free PvE:** Never use Roblox `Humanoid` instances for Wraiths; use server coordinate arrays in `WraithService.luau` and client `CFrame:Lerp` in `WraithVisualController.luau`.
- **Rojo vs. Studio Boundary:** Code (`src/**/*.luau`) is written ONLY on disk and synced via Rojo. Never create or edit `Script` / `ModuleScript` instances inside Studio via MCP.
