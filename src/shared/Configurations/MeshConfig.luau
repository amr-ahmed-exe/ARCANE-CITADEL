--!strict
-- Arcane Citadel: mesh override slots (art pass).
-- HOW TO USE (all in Studio, zero code changes):
--   1. View → Toolbox → search "crystal", "dead tree", "castle tower", "magic portal".
--   2. Drag a model into the 3D view, then move it under a folder named
--      exactly "MeshOverrides" (create it under Workspace if missing).
--   3. Rename the dropped model to the slot name and place it at the anchor:
--      CursedWoods   → dead-forest ring, radius 200–260 around (0, 0).
--                       (see GraphicsConfig.WoodsRadiusMin / WoodsRadiusSpan)
--      Watchtowers   → 4 towers at radius 140, diagonal angles (45°, 135°...).
--      RaidPortalSet → centered at (0, 0, 22), arch opening faces -Z (the core).
--      CitadelHeart  → centered at (0, 0). Replaces the code-built crystal.
--   4. Select every part of your model → Anchor them. Press Play: the
--      matching primitive builders are skipped automatically.
-- RULES: never name a slot "Wall_1/2/3" — wall rings stay procedural
-- (gameplay readability + breach ghosting depend on them).

local MeshConfig = {
	OverridesFolder = "MeshOverrides",
	Slots = {
		Woods = "CursedWoods",
		Towers = "Watchtowers",
		Portal = "RaidPortalSet",
		Heart = "CitadelHeart",
	},
	-- Runtime mesh assets (InsertService IDs). 0 = keep code primitives.
	-- ONLY IDs verified on the Creator Store go here, and every model is
	-- script-stripped + part-capped by MeshLoader before placement.
	MeshAssets = {
		-- Verified: "Low Poly Tree" (Creator Store reviews positive).
		DeadTree = 10707210767,
		Tower = 0, -- TODO: verified castle-tower model ID
		Heart = 0, -- TODO: verified crystal-heart model ID
		Portal = 0, -- TODO: verified portal model ID
	},
	-- Reject any loaded model heavier than this (per-model part count).
	MeshPartCap = 200,
}

return MeshConfig
