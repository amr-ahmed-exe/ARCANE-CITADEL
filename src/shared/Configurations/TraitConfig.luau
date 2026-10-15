--!strict
-- Arcane Citadel: Arcane Anvil prefix/suffix trait table (Part 3.2).
--
-- Weights are out of TOTAL_TRAIT_WEIGHT (1000), so each Weight is literally
-- its advertised percentage. Keep the sum at 1000 — the roll divides by the
-- running total, so an off-sum table silently rescales every probability.

local TOTAL_TRAIT_WEIGHT = 1000

export type TraitSpec = {
	Weight: number,
	PowerMultiplier: number,
	WallDamageMultiplier: number?,
	SpellDamageMultiplier: number?,
	MaxHealthMultiplier: number?,
	WardDPSMultiplier: number?,
	SoulGenerationMultiplier: number?,
	BountyCutBonus: number?,
	Description: string,
}

local TraitConfig = {
	TOTAL_TRAIT_WEIGHT = TOTAL_TRAIT_WEIGHT,
	ReforgeCostBloodShards = 25,
	-- Must track MonetizationConfig.Catalog.Anvil_Reforge_1x.CrownPrice
	-- (floor(19 / 1.3) = 14). 15 under-delivered the 1.3x promise.
	ReforgeCostEclipseCrowns = 14,
	RepairFractureCostBloodShards = 15,
	RepairFractureCostEclipseCrowns = 11, -- floor(15 / 1.3) = 11 (1.364x)
	Traits = {
		-- Common. The blueprint annotates Sturdy at 50% and lists Sharp as
		-- the second Common option without a number; Sharp absorbs the
		-- remainder so the four explicitly-numbered traits below keep their
		-- stated rates exactly.
		["Sturdy"] = {
			Weight = 500, -- 50%
			PowerMultiplier = 1.05,
			MaxHealthMultiplier = 1.10,
			Description = "+10% Max Health & +5% Gear Score",
		},
		["Sharp"] = {
			Weight = 278, -- 27.8% (balances the table to 1000)
			PowerMultiplier = 1.05,
			SpellDamageMultiplier = 1.05,
			Description = "+5% Spell Damage",
		},
		-- Rare (blueprint annotates Vigilant at 12%)
		["Vigilant"] = {
			Weight = 120, -- 12%
			PowerMultiplier = 1.15,
			WardDPSMultiplier = 1.15,
			Description = "+15% Automated Runic Obelisk DPS",
		},
		["Siegebreaker"] = {
			Weight = 80, -- 8%
			PowerMultiplier = 1.25,
			WallDamageMultiplier = 1.35,
			Description = "+35% Damage to Enemy Citadel Walls",
		},
		-- Legendary (2%)
		["Sovereign"] = {
			Weight = 20, -- 2%
			PowerMultiplier = 1.40,
			SpellDamageMultiplier = 1.30,
			SoulGenerationMultiplier = 1.15,
			Description = "+30% Spell Damage & +15% Soul Generation",
		},
		-- Mythic (0.2% = 1 in 500)
		["Cataclysmic"] = {
			Weight = 2, -- 0.2% (1 in 500 Mythic Trait)
			PowerMultiplier = 1.60,
			SpellDamageMultiplier = 1.50,
			Description = "+50% Spell Damage & AoE Purple Lightning Detonation",
		},
	} :: { [string]: TraitSpec },
}

return TraitConfig
