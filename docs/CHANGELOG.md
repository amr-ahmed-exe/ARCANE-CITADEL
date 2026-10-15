# ARCANE CITADEL — ENGINEERING, SECURITY & QA CHANGELOG

## [0.0.1] — Repository & Multi-Agent Orchestration Initialized
- Configured 7 Hierarchical Claude 5.5 Sub-Agents (`.claude/agents/`).
- Configured 9 Progressive-Disclosure Agent Skills (`.claude/skills/`), including Live Roblox API Verification (`verifying-roblox-apis`) and Anti-Deprecation scanning (`scan_deprecated_apis.sh`).
- Configured deterministic `PostToolUse` (`verify_luau.sh`) and `PreCompact` hooks.

## [0.0.2] — Orchestration Scaffold Installed on Existing Codebase (2026-10-15)
- Installed full `.claude/` pipeline (7 agents, 9 skills), `docs/` living documentation, `scripts/verify_luau.sh`, `scripts/verify_setup.sh`, and `tests/verify_economy_math.luau` alongside the existing 50-module `src/` implementation (Milestones 1–5).
- Preserved project-tuned `wally.toml` (`brittonfischer/profileservice@2.1.5`), `default.project.json` (`servePort 34872`), and `.gitignore`; added `rokit.toml`, `.luaurc`, `.mcp.json`, `CLAUDE.md`, `assets/asset_manifest.json`.
- Static audit: zero deprecated Roblox/Lua APIs in `src/`; all modules start with `--!strict`.
- Known gap: `src/` modules lack `---` Luau-LSP docstrings, so `verify_docs_coverage.sh` check #1 still fails — scheduled as the first `/building-feature` (document-all-modules) task.
