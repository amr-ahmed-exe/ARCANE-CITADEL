---
name: fuzzing-remotes
description: Runs an automated Zero-Trust exploit fuzzer against all RemoteEvents and RemoteFunctions in Roblox Studio Play Mode, testing NaN, math.huge, negative numbers, nil, and spoofed UUIDs.
context: fork
agent: qa-playtest-tester
allowed-tools: Read, mcp__roblox-studio__run_script_in_play_mode, mcp__roblox-studio__get_console_output
---

1. Read `.claude/skills/fuzzing-remotes/scripts/fuzz_network_router.luau`.
2. Execute it inside Roblox Studio Play Mode via `mcp__roblox-studio__run_script_in_play_mode`.
3. Inspect `mcp__roblox-studio__get_console_output` and verify zero unhandled server stack traces occurred and no player currency became `NaN` or negative.
