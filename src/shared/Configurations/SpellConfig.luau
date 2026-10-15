--!strict
-- Arcane Citadel: player spell hotbar tuning (placeholder for Milestone 3).
-- Q = tactical (4s), E = AoE combat (8s), R = ultimate/siege (25s).

export type SpellSpec = {
	Name: string,
	CooldownSeconds: number,
	Description: string,
}

local SpellConfig: { [string]: SpellSpec } = {
	["Blink"] = { Name = "Shadow-Step Blink", CooldownSeconds = 4, Description = "Short-range teleport (Q tactical)." },
	["Aegis"] = { Name = "Arcane Aegis", CooldownSeconds = 4, Description = "Personal shield absorbing spell damage (Q tactical)." },
	["MendWard"] = { Name = "Healing Ward", CooldownSeconds = 4, Description = "Heal over time zone (Q tactical)." },
	["Meteor"] = { Name = "Meteor Swarm", CooldownSeconds = 8, Description = "AoE impact damage (E combat)." },
	["Witchfire"] = { Name = "Chain Witchfire", CooldownSeconds = 8, Description = "Chaining projectile burn (E combat)." },
	["FrostNova"] = { Name = "Frost Nova", CooldownSeconds = 8, Description = "Radial slow + damage (E combat)." },
	["Bulwark"] = { Name = "Warden Bulwark", CooldownSeconds = 25, Description = "Restore 15% wall HP + supercharge wards 10s (R warden)." },
	["SiegeBeam"] = { Name = "Raider Siege Beam", CooldownSeconds = 25, Description = "Jam enemy wards + melt wall HP (R raider)." },
}

return SpellConfig
