--!strict
-- Arcane Citadel: dual-checkout monetization config (Master Blueprint Part 3.2).
-- Every premium service has TWO prices:
--   RawRobuxPrice (1.0x baseline, slow 2-step Roblox prompt)
--   CrownPrice = floor(RawRobuxPrice / 1.3) (1.3x value + 1-click instant)
-- Crown packs force bulk commitment (min 99 R$), creating sunk-cost retention.

export type DualPricedItem = {
	Name: string,
	DevProductId: number, -- Roblox Developer Product ID for direct Raw Robux purchase (0 = not configured yet)
	RawRobuxPrice: number, -- 1.0x Baseline Robux Price (display only)
	CrownPrice: number, -- 1.3x Better Value Price (math.floor(RawRobuxPrice / 1.3))
	BloodShardGrant: number?, -- Optional: if this item is a Blood Shard bundle
}

export type CrownBundle = {
	DevProductId: number, -- Roblox Developer Product ID for the Robux -> Crowns pack
	RobuxCost: number,
	CrownsGranted: number,
}

local MonetizationConfig = {
	-- 1. Bulk Eclipse Crown Packs (minimum 99 R$ forces sunk-cost commitment)
	CrownBundles = {
		["Crown_Pouch_100"] = { DevProductId = 100001, RobuxCost = 99, CrownsGranted = 100 },
		["Crown_Coffer_265"] = { DevProductId = 100002, RobuxCost = 249, CrownsGranted = 265 },
		["Crown_Treasury_550"] = { DevProductId = 100003, RobuxCost = 499, CrownsGranted = 550 },
		["Crown_Sovereign_1500"] = { DevProductId = 100004, RobuxCost = 1299, CrownsGranted = 1500 },
	} :: { [string]: CrownBundle },

	-- 2. Services, Panic Products, Passes & Blood Shard Packs (Raw Robux vs. 1.3x Crowns)
	Catalog = {
		["Blood_Insurance"] = {
			Name = "Blood Insurance (Restore 33% & Shield)",
			DevProductId = 200001,
			RawRobuxPrice = 39,
			CrownPrice = 30, -- 1.3x Value!
		},
		["Vengeance_Curse"] = {
			Name = "Vengeance Curse (Repair & Counter-Lich)",
			DevProductId = 200002,
			RawRobuxPrice = 59,
			CrownPrice = 45, -- 1.3x Value!
		},
		["Emergency_Mercenaries"] = {
			Name = "Emergency Mercenary Pact (3 Servants)",
			DevProductId = 200003,
			RawRobuxPrice = 29,
			CrownPrice = 22, -- 1.3x Value!
		},
		["Extra_Soul_Tethers"] = {
			Name = "+3 Soul Tethers (Prevent Weapon Fracture)",
			DevProductId = 200004,
			RawRobuxPrice = 29,
			CrownPrice = 22, -- 1.3x Value!
		},
		["Summon_Wraith_Colossus"] = {
			Name = "Summon Wraith Colossus",
			DevProductId = 200005,
			RawRobuxPrice = 79,
			CrownPrice = 60, -- 1.3x Value!
		},
		["Royal_Decree"] = {
			Name = "Royal Decree (End Blood Pact Early)",
			DevProductId = 200010,
			RawRobuxPrice = 39,
			CrownPrice = 30, -- 1.3x Value!
		},
		["Master_Alchemist_Pass"] = {
			Name = "Master Alchemist Pass (0% Auto-Renew Fee)",
			DevProductId = 200006,
			RawRobuxPrice = 149,
			-- floor(149 / 1.3) = 114 -> 149/114 = 1.307x. 115 was only 1.296x,
			-- which breaks the "ALWAYS at least 1.3x" promise.
			CrownPrice = 114,
		},
		["Dual_Loadout_Pass"] = {
			Name = "Dual Loadout & Auto-Roll Pass",
			DevProductId = 200007,
			RawRobuxPrice = 249,
			CrownPrice = 190, -- 249/190 = 1.310x
		},
		["Anvil_Reforge_1x"] = {
			Name = "Instant Trait Reforge (1x)",
			DevProductId = 200008,
			RawRobuxPrice = 19,
			-- floor(19 / 1.3) = 14 -> 19/14 = 1.357x. 15 was only 1.267x.
			CrownPrice = 14,
		},
		["Anvil_Reforge_10x"] = {
			Name = "Instant Trait Reforge Bundle (10x)",
			DevProductId = 200009,
			RawRobuxPrice = 149,
			CrownPrice = 114, -- floor(149 / 1.3) = 114 -> 1.307x
		},
		-- Blood Shard Packs (Arcane Anvil & Phase 2 Black Market Auction House)
		["BloodShards_150"] = {
			Name = "150 Blood Shards",
			DevProductId = 300001,
			RawRobuxPrice = 65,
			CrownPrice = 50, -- 1.3x Value!
			BloodShardGrant = 150,
		},
		["BloodShards_500"] = {
			Name = "500 Blood Shards",
			DevProductId = 300002,
			RawRobuxPrice = 195,
			CrownPrice = 150, -- 1.3x Value!
			BloodShardGrant = 500,
		},
		["BloodShards_2500"] = {
			Name = "2,500 Blood Shards",
			DevProductId = 300003,
			RawRobuxPrice = 845,
			CrownPrice = 650, -- 1.3x Value!
			BloodShardGrant = 2500,
		},
	} :: { [string]: DualPricedItem },

	-- Game Pass effects. Lives here (not as a magic number in CitadelService)
	-- so the value the pass actually buys is tunable and reviewable.
	PassBonuses = {
		-- Master Alchemist: +0.10 defense ratio while an elixir is active.
		AlchemistElixirDefense = 0.10,
	},

	-- The headline promise is that spending Eclipse Crowns is ALWAYS at least
	-- 1.3x better value than paying raw Robux. Three prices drifted below it
	-- at some point, so the rule is now machine-checkable. Call this from a
	-- dev command (or Studio console) after editing any price above.
	ValueFloor = 1.3,
}

-- Returns a list of "catalogKey: robux/crowns = rate" for any item that
-- under-delivers the 1.3x promise. Empty table == the catalog is honest.
function MonetizationConfig.FindUnderValueItems(): { string }
	local bad = {}
	for key, entry in MonetizationConfig.Catalog do
		if entry.CrownPrice > 0 then
			local rate = entry.RawRobuxPrice / entry.CrownPrice
			if rate < MonetizationConfig.ValueFloor - 1e-9 then
				table.insert(bad, `{key}: {entry.RawRobuxPrice}/{entry.CrownPrice} = {string.format("%.3f", rate)}x`)
			end
		end
	end
	table.sort(bad)
	return bad
end

return MonetizationConfig
