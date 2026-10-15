--!strict
-- Arcane Citadel: raider sabotage hex consumables (Milestone 4).
-- Invader-only Blood Shard sinks: WardJam silences automated wards,
-- SoulLeech siphons Session Pot souls to the caster. An equipped Raider
-- ring (WallDamageBonus > 0) extends hex duration by +30%.

export type SabotageSpec = {
	Name: string,
	DurationSeconds: number,
	EffectDescription: string,
	BloodShardCost: number,
	CooldownSeconds: number,
	RangeStuds: number,
	StealFraction: number?, -- SoulLeech only: fraction of Session Pot siphoned
	StealMin: number?,
	StealMax: number?,
}

local SabotageConfig = {
	-- +30% hex duration while a Raider ring is equipped.
	RaiderRingDurationBonus = 0.30,
	Specs = {
		["WardJam"] = {
			Name = "Ward-Jamming Hex",
			DurationSeconds = 20,
			EffectDescription = "Silences automated Runic Obelisks for 20s (wards stop grinding wraiths).",
			BloodShardCost = 5,
			CooldownSeconds = 45,
			RangeStuds = 320,
		},
		["SoulLeech"] = {
			Name = "Soul-Leech Hex",
			DurationSeconds = 0, -- instant siphon, no lingering effect
			EffectDescription = "Siphons 5% of the defender's Session Pot (100–25,000 Souls) to your Vault.",
			BloodShardCost = 8,
			CooldownSeconds = 60,
			RangeStuds = 320,
			StealFraction = 0.05,
			StealMin = 100,
			StealMax = 25000,
		},
	} :: { [string]: SabotageSpec },
}

function SabotageConfig.Get(hexId: string): SabotageSpec?
	return SabotageConfig.Specs[hexId]
end

return SabotageConfig
