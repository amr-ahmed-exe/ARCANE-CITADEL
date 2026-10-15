---
name: greyboxing-citadel
description: Generates or resets the concentric 3-Wall Citadel geometry, WardSockets, InteractiveStations, and CollectionService tags in Roblox Studio Edit Mode.
context: fork
agent: studio-world-worker
allowed-tools: Read, mcp__roblox-studio__run_code, mcp__roblox-studio__get_project_structure
---

1. Read `.claude/skills/greyboxing-citadel/scripts/generate_citadel_3d.luau`.
2. Execute its exact contents inside Roblox Studio Edit Mode using `mcp__roblox-studio__run_code`.
3. Call `mcp__roblox-studio__get_project_structure` on `Workspace.CitadelGeometry` to verify `Wall_1`, `Wall_2`, `Wall_3`, `WardSocket` pads, and `InteractiveStation` models exist with their required Attributes.
4. Return a concise verification summary to the main thread.
