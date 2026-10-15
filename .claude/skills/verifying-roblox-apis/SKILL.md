---
name: verifying-roblox-apis
description: Queries official Roblox Engine documentation (create.roblox.com/docs) and Context7 MCP to verify current 2026 Luau/Roblox API signatures, replacing deprecated methods and caching verified signatures into deprecated_to_modern_matrix.md. Invoke whenever designing a spec with unfamiliar Roblox services or resolving a luau-lsp API error.
argument-hint: "<RobloxServiceOrMethodToVerify>"
allowed-tools: Read, Edit, Bash, WebSearch, WebFetch, mcp__context7__resolve-library-id, mcp__context7__get-library-docs
---

### Current Anti-Deprecation Matrix (Auto-Injected):
!`cat .claude/skills/enforcing-luau-standards/references/deprecated_to_modern_matrix.md`

### Verification & Self-Caching Protocol for: $ARGUMENTS
1. **Check Local Matrix First:** If `$ARGUMENTS` is already documented in `deprecated_to_modern_matrix.md` above, use that exact signature immediately.
2. **Query Live Official Documentation:**
   - First try `mcp__context7__resolve-library-id` / `mcp__context7__get-library-docs` for Roblox Engine / Luau documentation.
   - If Context7 does not have the specific Roblox Engine class, run `WebSearch` restricted strictly to `site:create.roblox.com/docs/reference/engine $ARGUMENTS` and verify whether any method or property is marked **Deprecated** or **Superseded**.
3. **Cache the Result for Future Runs:**
   - Append a concise 1-row entry to `.claude/skills/enforcing-luau-standards/references/deprecated_to_modern_matrix.md` showing the verified modern signature and any deprecated equivalent so no future agent has to search for `$ARGUMENTS` again.
4. **Run the Deterministic Scanner:**
   - Execute `bash .claude/skills/verifying-roblox-apis/scripts/scan_deprecated_apis.sh` to confirm zero banned APIs exist in `src/`.
