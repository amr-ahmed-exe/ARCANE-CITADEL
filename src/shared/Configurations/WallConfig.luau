--!strict
-- Arcane Citadel: wall ring balance table (Part 3.4 of the master blueprint).
-- Data-driven: tuners edit numbers here, never inside CitadelService.

export type WallTierSpec = {
	Name: string,
	RadiusStuds: number,
	PerimeterStuds: number,
	BaseDefenseRatio: number,
	BaseMaxHP: number,
	BaseSoulsPerSecond: number,
	UnlockCost: number, -- one-time Vault cost to raise this ring at all
	UpgradeCostBase: number,
	UpgradeCostScale: number,
	UpgradeDefenseStep: number,
	ElixirBaseCost: number,
	ElixirAutoRenewMultiplier: number, -- 1.5x (+50% convenience surcharge)
	ElixirDefenseBonus: number,
	ElixirDurationSeconds: number,
	RepairCostPerHP: number, -- souls per HP for mid-fight repairs (greed sink)
	BreachStealFraction: number, -- Fraction of remaining Session Pot stolen when this wall falls
	BreachWaveResolutionSeconds: number, -- grace window to clear remaining foes before the decision modal
}

local WallConfig: { [number]: WallTierSpec } = {
	[1] = {
		Name = "Inner Sanctum",
		RadiusStuds = 45,
		PerimeterStuds = 282,
		BaseDefenseRatio = 1.00, -- Holds 1.0x monsters out of the box
		BaseMaxHP = 2500,
		BaseSoulsPerSecond = 15,
		UnlockCost = 0, -- always owned
		UpgradeCostBase = 500,
		UpgradeCostScale = 1.35,
		UpgradeDefenseStep = 0.12,
		ElixirBaseCost = 2500,
		ElixirAutoRenewMultiplier = 1.50,
		ElixirDefenseBonus = 0.35,
		ElixirDurationSeconds = 900, -- 15 minutes
		RepairCostPerHP = 3, -- full 20% repair ≈ 1,500 Souls
		BreachStealFraction = 1.00, -- Total Citadel fall: 100% of remaining Session Pot stolen
		BreachWaveResolutionSeconds = 45,
	},
	[2] = {
		Name = "Middle Ward",
		RadiusStuds = 90,
		PerimeterStuds = 565, -- 36% tighter perimeter than Wall 3
		BaseDefenseRatio = 0.80, -- Requires active spells or Elixir until upgraded
		BaseMaxHP = 6000,
		BaseSoulsPerSecond = 60,
		-- ~70 min of Wall 1 income. Previously reused UpgradeCostBase (5,000),
		-- which made a whole new ring cost ~83 seconds of a single wall.
		UnlockCost = 250000,
		UpgradeCostBase = 5000,
		UpgradeCostScale = 1.40,
		UpgradeDefenseStep = 0.10,
		ElixirBaseCost = 10800, -- 20% of 15-min base output (54,000 Souls)
		ElixirAutoRenewMultiplier = 1.50, -- 16,200 Souls (30% of output; 70% pure AFK net profit)
		ElixirDefenseBonus = 0.35, -- Pushes 0.80x -> 1.15x
		ElixirDurationSeconds = 900,
		RepairCostPerHP = 5, -- full 20% repair ≈ 6,000 Souls
		BreachStealFraction = 0.50, -- Steals 50% of remaining Session Pot (leaves ~33.5% of original)
		BreachWaveResolutionSeconds = 45,
	},
	[3] = {
		Name = "Outer Frontier",
		RadiusStuds = 140,
		PerimeterStuds = 880, -- Wide perimeter, massive Soul output
		BaseDefenseRatio = 0.60, -- High decay without Elixir, active play, or upgrades
		BaseMaxHP = 15000,
		BaseSoulsPerSecond = 250,
		-- ~100 min of base income from Wall 1, or a meaningful slice of the
		-- 250/s this ring itself generates.
		UnlockCost = 1500000,
		UpgradeCostBase = 45000,
		UpgradeCostScale = 1.45,
		UpgradeDefenseStep = 0.08,
		ElixirBaseCost = 45000, -- 20% of 15-min base output (225,000 Souls)
		ElixirAutoRenewMultiplier = 1.50, -- 67,500 Souls (30% of output; 70% pure AFK net profit)
		ElixirDefenseBonus = 0.45, -- Pushes 0.60x -> 1.05x
		ElixirDurationSeconds = 900,
		RepairCostPerHP = 8, -- full 20% repair ≈ 24,000 Souls (greed-vs-survival call)
		-- Exact one third, not 0.33: on the blueprint's own 300,000 worked
		-- example 0.33 stole 99,000 and left 201,000, so the modal promised
		-- "bank 67% (200,000)" while paying out 201,000.
		BreachStealFraction = 1 / 3,
		BreachWaveResolutionSeconds = 45,
	},
}

return WallConfig
