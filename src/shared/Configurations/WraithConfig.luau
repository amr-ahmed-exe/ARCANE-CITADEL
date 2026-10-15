--!strict
-- Arcane Citadel: PvE wraith tuning (placeholder values for Milestone 3).
-- Wraiths are humanoid-free: server simulates HP/position arrays,
-- client renders floating ghosts via CFrame:Lerp + sine-wave bob.

export type WraithSpec = {
	Name: string,
	MaxHP: number,
	MoveSpeed: number, -- studs/sec toward the outermost intact wall
	DamagePerSecond: number, -- applied to wall HP on contact
	SoulReward: number, -- Souls paid to Session Pot / Vault on kill
	BloodShardDropChance: number, -- 0..1 roll for a Blood Shard on kill
	BobAmplitude: number, -- sine-wave hover amplitude (studs, client-side)
	BobFrequency: number, -- sine-wave hover frequency (Hz, client-side)
}

local WraithConfig: { [string]: WraithSpec } = {
	["Wisp"] = {
		Name = "Cursed Wisp",
		MaxHP = 60,
		MoveSpeed = 8,
		DamagePerSecond = 4,
		SoulReward = 12,
		BloodShardDropChance = 0.0,
		BobAmplitude = 1.5,
		BobFrequency = 1.2,
	},
	["Banshee"] = {
		Name = "Wailing Banshee",
		MaxHP = 220,
		MoveSpeed = 11,
		DamagePerSecond = 10,
		SoulReward = 35,
		BloodShardDropChance = 0.01,
		BobAmplitude = 2.0,
		BobFrequency = 0.9,
	},
	["Revenant"] = {
		Name = "Armored Revenant",
		MaxHP = 900,
		MoveSpeed = 6,
		DamagePerSecond = 25,
		SoulReward = 120,
		BloodShardDropChance = 0.03,
		BobAmplitude = 1.0,
		BobFrequency = 0.7,
	},
	["Lich"] = {
		Name = "Boss Lich",
		MaxHP = 6000,
		MoveSpeed = 4,
		DamagePerSecond = 80,
		SoulReward = 1500,
		BloodShardDropChance = 1.0, -- Boss always drops Blood Shards
		BobAmplitude = 2.5,
		BobFrequency = 0.5,
	},
}

-- Alive-at-once caps per wall ring (server perf budget for 60 FPS).
-- ThreatBloodPact is the BLOOD PACT BASELINE; the threat then ramps with
-- pact duration (ThreatRampPerMinute, capped at ThreatRampCap) so a long
-- pact pushes the defender toward cashing out. Both live here so tuners
-- never have to touch CitadelService.
local WraithBudgets = {
	MaxActivePerWall = 50,
	ThreatSanctuary = 1.00,
	ThreatBloodPact = 1.35,
	ThreatRampPerMinute = 0.02,
	ThreatRampCap = 0.20, -- effective max threat = 1.35 + 0.20 = 1.55
}

return {
	Specs = WraithConfig,
	Budgets = WraithBudgets,
	Spawn = {
		MaxActive = 150, -- Milestone 3 gate: 150 floating wraiths at 60 FPS
		PerSecond = 5,
		Weights = {
			Wisp = 70,
			Banshee = 20,
			Revenant = 9,
			Lich = 1,
		},
	},
	WardBaseDPS = 25, -- Automated ward kill pressure when ratio >= threat
}
