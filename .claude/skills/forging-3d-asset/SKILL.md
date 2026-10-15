---
name: forging-3d-asset
description: Models a stylized 3D mesh in Blender (<2,500 tris), visually verifies via viewport screenshot, normalizes -Z Roblox orientation, exports .fbx, and uploads to Roblox Open Cloud.
argument-hint: "<AssetName> <VisualDescription>"
context: fork
agent: blender-worker
---

### Existing 3D Asset Manifest (Auto-Injected):
!`cat assets/asset_manifest.json 2>/dev/null || echo "{}"`

### Execution Steps for: $ARGUMENTS
1. Model the low-poly mesh (`< 2,500` triangles) in Blender via `mcp__blender__execute_blender_code` using the Dark Witchery palette.
2. Call `mcp__blender__get_viewport_screenshot` to visually inspect proportions and verify no floating geometry exists.
3. Run the bundled normalization and `.fbx` export script inside Blender (`assets/3d/<AssetName>.fbx`) using `.claude/skills/forging-3d-asset/scripts/blender_normalize_export.py`.
4. Run `python3 .claude/skills/forging-3d-asset/scripts/opencloud_upload.py <AssetName> assets/3d/<AssetName>.fbx` via Bash to upload to Roblox Open Cloud and write the `rbxassetid://` URI into `assets/asset_manifest.json`.
5. Return the new `AssetName -> rbxassetid://` mapping to the main thread.
