---
name: validating-ui-contracts
description: Audits StarterGui for the 8 required Arcane Citadel UI screens and their UIActionButton CollectionService tags/Attributes, automatically generating Dark Witchery placeholder wireframes for any screen not yet imported by the UI Designer.
context: fork
agent: studio-world-worker
allowed-tools: Read, mcp__roblox-studio__run_code, mcp__roblox-studio__get_project_structure
---

1. Read `.claude/skills/validating-ui-contracts/scripts/audit_or_wireframe_ui.luau`.
2. Execute it in Roblox Studio Edit Mode via `mcp__roblox-studio__run_code`.
3. Return the audit table showing which screens are using Designer `.rbxm` packages and which were scaffolded as functional wireframes.
