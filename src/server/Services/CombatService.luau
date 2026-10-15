--!strict
-- Arcane Citadel: server-validated player combat (Milestones 3-4).
-- Left-click staff fire + Q/E/R spells, scaled by GearConfig/TraitConfig.
-- Milestone 4: invaders damage walls/servants/defenders (contribution +
-- hostile tracking); defenders damage invaders (killer attribution).
-- All cooldowns + ranges enforced here; client is cosmetic only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GearConfig = require(Shared.Configurations.GearConfig)
local TraitConfig = require(Shared.Configurations.TraitConfig)
local SpellConfig = require(Shared.Configurations.SpellConfig)
local WallConfig = require(Shared.Configurations.WallConfig)
local WraithService = require(script.Parent.WraithService)

local CombatService = {}

local STAFF_RANGE = 320
local STAFF_SPLASH = 12
local PVP_SPLASH = 12
local PVP_FRACTION = 0.5
local WALL_BAND = 20

local function equippedWeapon(profile: any): any
	local loadout = profile.Loadouts[profile.ActiveLoadoutType]
	if not loadout then
		return nil
	end
	return profile.Inventory[loadout.WeaponUID]
end

-- Exported so GameService can derive automated ward pressure.
-- The Vigilant trait (+15% Automated Runic Obelisk DPS) was defined in the
-- config but never read: the ward path only ever looked at the weapon's
-- own WardDPSBonus, so the advertised affix did nothing.
function CombatService.WardBonus(profile: any): number
	local item = equippedWeapon(profile)
	if not item then
		return 0
	end
	local cfg = GearConfig[item.ItemId]
	local bonus = if cfg then cfg.WardDPSBonus else 0
	for _, traitName in { item.PrefixTrait, item.SuffixTrait } do
		if traitName and TraitConfig.Traits[traitName] then
			local mult = TraitConfig.Traits[traitName].WardDPSMultiplier
			if mult then
				bonus *= mult
			end
		end
	end
	return bonus
end

-- Siegebreaker's WallDamageMultiplier (1.35) was defined but never applied,
-- so the item only ever contributed its generic PowerMultiplier.
function CombatService.WallDamageBonus(profile: any): number
	local item = equippedWeapon(profile)
	if not item then
		return 0
	end
	local cfg = GearConfig[item.ItemId]
	local bonus = if cfg then cfg.WallDamageBonus else 0
	for _, traitName in { item.PrefixTrait, item.SuffixTrait } do
		if traitName and TraitConfig.Traits[traitName] then
			local mult = TraitConfig.Traits[traitName].WallDamageMultiplier
			if mult then
				bonus *= mult
			end
		end
	end
	return bonus
end

-- Sturdy's "+10% Max Health" has no consumer anywhere; expose it so the
-- character's max health can be derived from gear.
function CombatService.MaxHealthMultiplier(profile: any): number
	local mult = 1
	for _, item in pairs(profile.Inventory or {}) do
		if not item.IsFractured then
			for _, traitName in { item.PrefixTrait, item.SuffixTrait } do
				if traitName and TraitConfig.Traits[traitName] then
					local m = TraitConfig.Traits[traitName].MaxHealthMultiplier
					if m then
						mult *= m
					end
				end
			end
		end
	end
	return mult
end

local function staffDamage(profile: any): (number, number)
	local item = equippedWeapon(profile)
	if not item then
		return 10, 1.0
	end
	local cfg = GearConfig[item.ItemId]
	if not cfg then
		return 10, 1.0
	end
	local dmg = cfg.BaseSpellDamage * (1 + (item.UpgradeLevel or 0) * 0.08)
	for _, traitName in { item.PrefixTrait, item.SuffixTrait } do
		if traitName and TraitConfig.Traits[traitName] then
			local spec = TraitConfig.Traits[traitName]
			dmg *= spec.PowerMultiplier
			if spec.SpellDamageMultiplier then
				dmg *= spec.SpellDamageMultiplier
			end
		end
	end
	if item.IsFractured then
		dmg *= 0.75
	end
	return dmg, cfg.AttackSpeed
end

local function markHostile(record: any): ()
	record.lastHostile = os.clock()
end

-- Gameplay: chained wraith kills within a 6s window pay bonus souls
-- (+2% per chained kill, capped at +40%). Rewards standing on the
-- ramparts and fighting instead of pure AFK.
local STREAK_WINDOW = 6
local STREAK_STEP = 0.02
local STREAK_CAP = 20

local function streakMult(record: any): number
	local now = os.clock()
	if now - (record.lastKillAt or 0) > STREAK_WINDOW then
		record.killStreak = 0
	end
	return 1 + math.min(record.killStreak or 0, STREAK_CAP) * STREAK_STEP
end

local function feedStreak(record: any, kills: number): ()
	if kills <= 0 then
		return
	end
	local now = os.clock()
	if now - (record.lastKillAt or 0) > STREAK_WINDOW then
		record.killStreak = 0
	end
	record.killStreak = (record.killStreak or 0) + kills
	record.lastKillAt = now
end

-- Defenders + Coven allies share a team; invaders are hostile to both.
local function sameTeam(a: string, b: string): boolean
	if a == b then
		return true
	end
	local friendlyA = a == "defender" or a == "ally"
	local friendlyB = b == "defender" or b == "ally"
	return friendlyA and friendlyB
end

local function tagVictim(character: Model, shooter: Player): ()
	character:SetAttribute("LastHitBy", shooter.UserId)
	character:SetAttribute("LastHitAt", os.clock())
end

-- Raiders melt the outermost intact wall ring near the impact point.
local function damageWalls(record: any, target: Vector3, damage: number): number
	if os.time() < ((record.session :: any).ShieldUntil or 0) then
		return 0 -- Milestone 5: Blood Insurance shield blocks siege damage too.
	end
	local dealt = 0
	for i = 3, 1, -1 do
		local wall = record.session.Walls[i]
		if wall and wall.Unlocked and not wall.IsCollapsedForSession then
			local flat = Vector3.new(target.X, 0, target.Z)
			if math.abs(flat.Magnitude - WallConfig[i].RadiusStuds) <= WALL_BAND then
				wall.CurrentHP -= damage
				dealt = damage
				record.contribution = (record.contribution or 0) + damage
				markHostile(record)
				if wall.CurrentHP <= 0 and record.onWallBreach then
					record.onWallBreach(i)
				end
			end
			break -- only the outermost intact ring takes siege damage
		end
	end
	return dealt
end

-- Damage enemy servants guarding the walls (invaders only).
local function damageServants(record: any, center: Vector3, radius: number, damage: number): number
	if record.role ~= "invader" or not record.servants then
		return 0
	end
	local kills = 0
	for i = #record.servants, 1, -1 do
		local servant = record.servants[i]
		if servant.part and servant.part.Parent and (servant.part.Position - center).Magnitude <= radius then
			servant.hp -= damage
			markHostile(record)
			if servant.hp <= 0 then
				servant.part:Destroy()
				table.remove(record.servants, i)
				record.contribution = (record.contribution or 0) + 150
				kills += 1
			end
		end
	end
	return kills
end

-- Cross-player damage. Defenders + invaders are always hostile to each other.
local function damagePlayers(record: any, shooter: Player, center: Vector3, radius: number, damage: number): ()
	for _, victim in Players:GetPlayers() do
		if victim == shooter then
			continue
		end
		local vRecord = record.allRecords and (record.allRecords :: any)[victim.UserId]
		local vRole = if vRecord then vRecord.role else "defender"
		if sameTeam(vRole, record.role) then
			continue -- no friendly fire (defenders + Coven allies share a team)
		end
		local character = victim.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and (root.Position - center).Magnitude <= radius then
			local finalDamage = damage
			if vRecord and os.clock() < (vRecord.shieldUntil or 0) then
				finalDamage = damage * 0.25 -- Arcane Aegis (Q) absorbs 75% while active.
			end
			humanoid:TakeDamage(finalDamage)
			tagVictim(character, shooter)
			if record.role == "invader" then
				record.contribution = (record.contribution or 0) + 25
				markHostile(record)
			end
		end
	end
end

function CombatService.StaffFire(record: any, profile: any, shooter: Player, charPos: Vector3, target: Vector3): boolean
	local now = os.clock()
	if now < (record.staffReadyAt or 0) then
		return false
	end
	if (target - charPos).Magnitude > STAFF_RANGE then
		return false
	end
	local dmg, attackSpeed = staffDamage(profile)
	record.staffReadyAt = now + 1 / math.max(0.5, attackSpeed)
	local mult = streakMult(record)
	feedStreak(record, WraithService.DamageAt(record.wraiths, record.session, profile, target, STAFF_SPLASH, dmg, mult))
	if record.role == "invader" then
		local scaled = dmg * (1 + CombatService.WallDamageBonus(profile))
		damageWalls(record, target, scaled)
		damageServants(record, target, STAFF_SPLASH, dmg)
	end
	damagePlayers(record, shooter, target, PVP_SPLASH, dmg * PVP_FRACTION)
	return true
end

local function loadoutSpells(profile: any): { string }
	local loadout = profile.Loadouts[profile.ActiveLoadoutType]
	if not loadout then
		return {}
	end
	return { loadout.SpellQ, loadout.SpellE, loadout.SpellR }
end

function CombatService.CastSpell(
	record: any,
	profile: any,
	shooter: Player,
	character: Model?,
	spellId: string,
	target: Vector3
): boolean
	if not SpellConfig[spellId] then
		return false
	end
	local owned = false
	for _, s in loadoutSpells(profile) do
		if s == spellId then
			owned = true
			break
		end
	end
	if not owned then
		return false
	end
	local now = os.clock()
	record.spellReady = record.spellReady or {}
	if now < (record.spellReady[spellId] or 0) then
		return false
	end
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root then
		return false
	end

	local dmg, _ = staffDamage(profile)
	local spec = SpellConfig[spellId]
	local isInvader = record.role == "invader"
	-- Coven allies defend alongside the owner, so "not an invader" is the
	-- correct test for wall-repairing effects, not role == "defender".
	local isDefender = not isInvader

	if spellId == "Blink" then
		if (target - root.Position).Magnitude > 45 then
			return false
		end
		root.CFrame = CFrame.new(target + Vector3.new(0, 3, 0))
	elseif spellId == "Aegis" then
		record.shieldUntil = now + 5
		if humanoid then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 25)
		end
	elseif spellId == "MendWard" then
		if humanoid then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 50)
		end
	elseif spellId == "Meteor" then
		if (target - root.Position).Magnitude > STAFF_RANGE then
			return false
		end
		feedStreak(record, WraithService.DamageAt(record.wraiths, record.session, profile, target, 12, dmg * 3, streakMult(record)))
		if isInvader then
			damageWalls(record, target, dmg * 3 * (1 + CombatService.WallDamageBonus(profile)))
			damageServants(record, target, 12, dmg * 3)
		end
		damagePlayers(record, shooter, target, 12, dmg * 3 * PVP_FRACTION)
	elseif spellId == "Witchfire" then
		if (target - root.Position).Magnitude > STAFF_RANGE then
			return false
		end
		feedStreak(record, WraithService.DamageAt(record.wraiths, record.session, profile, target, 8, dmg * 1.5, streakMult(record)))
		if isInvader then
			damageWalls(record, target, dmg * 1.5 * (1 + CombatService.WallDamageBonus(profile)))
			damageServants(record, target, 8, dmg * 1.5)
		end
		damagePlayers(record, shooter, target, 8, dmg * 1.5 * PVP_FRACTION)
		task.delay(1, function()
			pcall(WraithService.DamageAt, record.wraiths, record.session, profile, target, 8, dmg * 0.5)
		end)
		task.delay(2, function()
			pcall(WraithService.DamageAt, record.wraiths, record.session, profile, target, 8, dmg * 0.5)
		end)
	elseif spellId == "FrostNova" then
		feedStreak(record, WraithService.DamageAt(record.wraiths, record.session, profile, root.Position, 15, dmg, streakMult(record)))
		if isInvader then
			damageWalls(record, root.Position, dmg * (1 + CombatService.WallDamageBonus(profile)))
			damageServants(record, root.Position, 15, dmg)
		end
		damagePlayers(record, shooter, root.Position, 15, dmg * PVP_FRACTION)
	elseif spellId == "Bulwark" then
		-- Defender-only. record.session is the DEFENDER's session, so an
		-- invader casting this was healing the very wall they were raiding
		-- (and supercharging its wards) on a 25s cooldown.
		if not isDefender then
			return false
		end
		local healed = false
		for i = 3, 1, -1 do
			local wall = record.session.Walls[i]
			if wall and wall.Unlocked and not wall.IsCollapsedForSession then
				wall.CurrentHP = math.min(wall.MaxHP, wall.CurrentHP + wall.MaxHP * 0.15)
				healed = true
				break
			end
		end
		if not healed then
			return false
		end
		record.wardBoostUntil = now + 10
	elseif spellId == "SiegeBeam" then
		if (target - root.Position).Magnitude > 80 then
			return false
		end
		feedStreak(record, WraithService.DamageAlong(record.wraiths, record.session, profile, root.Position, target, 6, dmg * 5, streakMult(record)))
		if isInvader then
			-- Raider R melts the outermost wall ring and briefly jams the
			-- automated wards (blueprint: "jams an enemy wall's wards").
			damageWalls(record, target, dmg * 3 * (1 + CombatService.WallDamageBonus(profile)))
			damageServants(record, target, 10, dmg * 5)
			record.session.WardJamUntil =
				math.max(record.session.WardJamUntil or 0, os.time() + 5)
		end
		-- Beam also rakes players along its path.
		local dir = target - root.Position
		local steps = math.clamp(math.floor(dir.Magnitude / 10), 1, 8)
		for s = 1, steps do
			damagePlayers(record, shooter, root.Position + dir * (s / steps), 8, dmg * 5 * PVP_FRACTION)
		end
	else
		return false
	end

	record.spellReady[spellId] = now + spec.CooldownSeconds
	return true
end

return CombatService
