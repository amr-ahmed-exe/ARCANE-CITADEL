--!strict
-- Arcane Citadel: RPG gear + trait tables (Part 3.2 of the master blueprint).

export type GearSpec = {
	Name: string,
	Slot: "Weapon" | "Armor" | "Ring",
	Rarity: "Common" | "Rare" | "Epic" | "Legendary" | "Mythic",
	RollWeight: number,
	BaseSpellDamage: number,
	AttackSpeed: number,
	WallDamageBonus: number, -- Raider bonus vs enemy walls
	WardDPSBonus: number, -- Warden bonus for automated turrets
	GearScore: number, -- Feeds into AP_i and DR_def
}

local GearConfig: { [string]: GearSpec } = {
	["Apprentice_Branch"] = {
		Name = "Gnarled Witchwood Staff",
		Slot = "Weapon",
		Rarity = "Common",
		RollWeight = 6000, -- 60%
		BaseSpellDamage = 25,
		AttackSpeed = 1.2,
		WallDamageBonus = 0.0,
		WardDPSBonus = 0.0,
		GearScore = 100,
	},
	["Soulfire_Scepter"] = {
		Name = "Scepter of Wailing Souls",
		Slot = "Weapon",
		Rarity = "Epic",
		RollWeight = 450, -- 4.5%
		BaseSpellDamage = 140,
		AttackSpeed = 1.6,
		WallDamageBonus = 0.20, -- +20% damage to enemy walls when Invading
		WardDPSBonus = 0.15, -- +15% automated turret damage when Defending
		GearScore = 1200,
	},
	["Eclipse_Grimoire_Blade"] = {
		Name = "Void-Forged Eclipse Scythe",
		Slot = "Weapon",
		Rarity = "Mythic",
		RollWeight = 5, -- 1 in 2,000
		BaseSpellDamage = 650,
		AttackSpeed = 2.2,
		WallDamageBonus = 0.65,
		WardDPSBonus = 0.50,
		GearScore = 8500,
	},
	["Dreadmoon_Grimoire_Blade"] = {
		Name = "Dreadmoon Grimoire Blade",
		Slot = "Weapon",
		Rarity = "Legendary",
		RollWeight = 60, -- ~0.4% of the base pool; the chase tier between Epic and Mythic
		BaseSpellDamage = 300,
		AttackSpeed = 1.9,
		WallDamageBonus = 0.40, -- +40% damage to enemy walls when Invading
		WardDPSBonus = 0.30, -- +30% automated turret damage when Defending
		GearScore = 3800,
	},
	-- Armor / Vestments (Slot 2): Max HP + ward synergy via Gear Score.
	["Hexweave_Vestment"] = {
		Name = "Hexweave Vestment",
		Slot = "Armor",
		Rarity = "Common",
		RollWeight = 5500,
		BaseSpellDamage = 0,
		AttackSpeed = 1.0,
		WallDamageBonus = 0.0,
		WardDPSBonus = 0.05,
		GearScore = 120,
	},
	["Wraithlord_Shroud"] = {
		Name = "Wraithlord Shroud",
		Slot = "Armor",
		Rarity = "Epic",
		RollWeight = 400,
		BaseSpellDamage = 0,
		AttackSpeed = 1.0,
		WallDamageBonus = 0.10,
		WardDPSBonus = 0.20,
		GearScore = 1400,
	},
	["Gravewarden_Mantle"] = {
		Name = "Gravewarden Mantle",
		Slot = "Armor",
		Rarity = "Legendary",
		RollWeight = 60, -- ~0.4% of the base pool; top armor before Mythic
		BaseSpellDamage = 0,
		AttackSpeed = 1.0,
		WallDamageBonus = 0.15,
		WardDPSBonus = 0.30,
		GearScore = 3200,
	},
	-- Warden Relic Rings (Slot 3/4, defense focus).
	["Sentinel_Band"] = {
		Name = "Sentinel Band",
		Slot = "Ring",
		Rarity = "Rare",
		RollWeight = 900,
		BaseSpellDamage = 0,
		AttackSpeed = 1.0,
		WallDamageBonus = 0.0,
		WardDPSBonus = 0.25, -- +25% automated ward fire rate
		GearScore = 600,
	},
	["Vaultkeeper_Seal"] = {
		Name = "Vaultkeeper Seal",
		Slot = "Ring",
		Rarity = "Epic",
		RollWeight = 350,
		BaseSpellDamage = 0,
		AttackSpeed = 1.0,
		WallDamageBonus = 0.0,
		WardDPSBonus = 0.15, -- +15% soul generation pace (via faster clears)
		GearScore = 900,
	},
	-- Raider Relic Rings (Slot 3/4, invasion focus).
	["Hexmaster_Loop"] = {
		Name = "Hexmaster Loop",
		Slot = "Ring",
		Rarity = "Rare",
		RollWeight = 900,
		BaseSpellDamage = 0,
		AttackSpeed = 1.0,
		WallDamageBonus = 0.25, -- +25% damage to enemy walls; +30% hex duration
		WardDPSBonus = 0.0,
		GearScore = 600,
	},
	["Reaver_Signet"] = {
		Name = "Reaver Signet",
		Slot = "Ring",
		Rarity = "Epic",
		RollWeight = 350,
		BaseSpellDamage = 0,
		AttackSpeed = 1.0,
		WallDamageBonus = 0.30, -- +30% hex duration; +15% stolen cut (via contribution)
		WardDPSBonus = 0.0,
		GearScore = 900,
	},
}

return GearConfig
