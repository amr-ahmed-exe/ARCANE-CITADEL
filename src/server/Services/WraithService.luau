--!strict
-- Arcane Citadel: humanoid-free wraith simulation (Milestone 3).
-- Server owns HP/position arrays only; clients render floating ghosts.
-- Core loop contract: when ward ratio >= threat, automated wards grind
-- contacting wraiths (player free to raid/cast); below threat, wraiths
-- chew the wall and the player must cover the gap manually.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WraithConfig = require(Shared.Configurations.WraithConfig)
local WallConfig = require(Shared.Configurations.WallConfig)
local CitadelService = require(script.Parent.CitadelService)

local WraithService = {}

export type Wraith = {
	id: number,
	wraithType: string,
	hp: number,
	maxHP: number,
	angle: number,
	radius: number,
}

export type WraithState = {
	list: { Wraith },
	nextId: number,
	spawnAcc: number,
}

function WraithService.newState(): WraithState
	return { list = {}, nextId = 1, spawnAcc = 0 }
end

-- Soul + shard payout for a slain wraith (wards or player).
-- soulMult rewards active kill streaks (CombatService passes 1.0-1.4x).
function WraithService.Reward(profile: any, session: CitadelService.CitadelSession, wraithType: string, soulMult: number?): ()
	local spec = WraithConfig.Specs[wraithType]
	if not spec then
		return
	end
	local souls = math.floor(spec.SoulReward * (soulMult or 1))
	if session.IsBloodPactActive then
		session.SessionSoulPot += souls
	else
		session.PermanentVaultSouls += souls
	end
	if math.random() < spec.BloodShardDropChance then
		profile.BloodShards += 1
	end
end

local function outermostIntact(session: CitadelService.CitadelSession): number
	for i = 3, 1, -1 do
		local wall = session.Walls[i]
		if wall and wall.Unlocked and not wall.IsCollapsedForSession then
			return i
		end
	end
	return 0
end

local function pickType(): string
	local w = WraithConfig.Spawn.Weights
	local total = w.Wisp + w.Banshee + w.Revenant + w.Lich
	local roll = math.random() * total
	if roll < w.Wisp then
		return "Wisp"
	elseif roll < w.Wisp + w.Banshee then
		return "Banshee"
	elseif roll < w.Wisp + w.Banshee + w.Revenant then
		return "Revenant"
	end
	return "Lich"
end

function WraithService.Step(
	state: WraithState,
	session: CitadelService.CitadelSession,
	profile: any,
	wardDPS: number,
	wardBoosted: boolean,
	dt: number,
	onBreach: (wallIndex: number) -> ()
): ()
	local wallIndex = outermostIntact(session)
	if wallIndex == 0 then
		table.clear(state.list)
		return
	end

	local wall = session.Walls[wallIndex]
	local wallRadius = WallConfig[wallIndex].RadiusStuds
	local threat = CitadelService.CurrentThreat(session, os.time())
	local ratio = CitadelService.GetEffectiveDefenseRatio(session, wallIndex, os.time())
	local shielded = os.time() < (session.ShieldUntil or 0) -- Milestone 5: Blood Insurance
	local jammed = CitadelService.IsWardJammed(session, os.time()) -- Milestone 4: Ward-Jamming Hex
	local wardsHold = (ratio >= threat or shielded) and not jammed
	local wardRate = wardDPS * (if wardBoosted then 2 else 1)

	-- Spawn pressure.
	state.spawnAcc += WraithConfig.Spawn.PerSecond * dt
	while state.spawnAcc >= 1 and #state.list < WraithConfig.Spawn.MaxActive do
		state.spawnAcc -= 1
		local wraithType = pickType()
		local spec = WraithConfig.Specs[wraithType]
		table.insert(state.list, {
			id = state.nextId,
			wraithType = wraithType,
			hp = spec.MaxHP,
			maxHP = spec.MaxHP,
			angle = math.random() * math.pi * 2,
			radius = 200 + math.random() * 60,
		})
		state.nextId += 1
	end
	if #state.list >= WraithConfig.Spawn.MaxActive then
		state.spawnAcc = 0
	end

	-- Advance / fight.
	for i = #state.list, 1, -1 do
		local wraith = state.list[i]
		local spec = WraithConfig.Specs[wraith.wraithType]
		if not spec then
			table.remove(state.list, i)
			continue
		end
		if wraith.radius > wallRadius + 3 then
			wraith.radius -= spec.MoveSpeed * dt
			continue
		end
		-- Contact: wards grind them, or they chew the wall.
		if wardsHold then
			wraith.hp -= wardRate * dt
			if wraith.hp <= 0 then
				WraithService.Reward(profile, session, wraith.wraithType)
				table.remove(state.list, i)
			end
		else
			wall.CurrentHP -= spec.DamagePerSecond * dt * (if wardBoosted then 0.5 else 1)
			if wall.CurrentHP <= 0 and not wall.IsCollapsedForSession then
				onBreach(wallIndex)
				wallIndex = outermostIntact(session)
				if wallIndex == 0 then
					table.clear(state.list)
					return
				end
				wall = session.Walls[wallIndex]
				wallRadius = WallConfig[wallIndex].RadiusStuds
			end
		end
	end
end

-- Server-side damage helper for player spells (returns souls earned).
-- Flat XZ check: wraiths render high above the ramparts, so aim is horizontal.
function WraithService.DamageAt(
	state: WraithState,
	session: CitadelService.CitadelSession,
	profile: any,
	center: Vector3,
	radius: number,
	damage: number,
	soulMult: number?
): number
	local kills = 0
	for i = #state.list, 1, -1 do
		local wraith = state.list[i]
		local dx = math.cos(wraith.angle) * wraith.radius - center.X
		local dz = math.sin(wraith.angle) * wraith.radius - center.Z
		if dx * dx + dz * dz <= radius * radius then
			wraith.hp -= damage
			if wraith.hp <= 0 then
				WraithService.Reward(profile, session, wraith.wraithType, soulMult)
				table.remove(state.list, i)
				kills += 1
			end
		end
	end
	return kills
end

-- Damage along a segment (Siege Beam). Returns kills. Flat XZ plane.
function WraithService.DamageAlong(
	state: WraithState,
	session: CitadelService.CitadelSession,
	profile: any,
	from: Vector3,
	to: Vector3,
	halfWidth: number,
	damage: number,
	soulMult: number?
): number
	local kills = 0
	local dirX, dirZ = to.X - from.X, to.Z - from.Z
	local lenSq = dirX * dirX + dirZ * dirZ
	if lenSq < 1 then
		return WraithService.DamageAt(state, session, profile, to, halfWidth * 2, damage)
	end
	for i = #state.list, 1, -1 do
		local wraith = state.list[i]
		local px = math.cos(wraith.angle) * wraith.radius - from.X
		local pz = math.sin(wraith.angle) * wraith.radius - from.Z
		local t = math.clamp((px * dirX + pz * dirZ) / lenSq, 0, 1)
		local cx, cz = from.X + dirX * t, from.Z + dirZ * t
		local wx = math.cos(wraith.angle) * wraith.radius
		local wz = math.sin(wraith.angle) * wraith.radius
		local ddx, ddz = wx - cx, wz - cz
		if ddx * ddx + ddz * ddz <= halfWidth * halfWidth then
			wraith.hp -= damage
			if wraith.hp <= 0 then
				WraithService.Reward(profile, session, wraith.wraithType, soulMult)
				table.remove(state.list, i)
				kills += 1
			end
		end
	end
	return kills
end

return WraithService
