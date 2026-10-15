--!strict
-- Arcane Citadel: live world + session manager (Milestones 2-4).
-- ONE shared world per server (the owner's Citadel): walls, Session Pot,
-- wraiths, servants. The owner is the first joiner (role "defender");
-- later joiners arrive as "invaders" (5 Soul Tethers, contribution loot).
-- Heartbeat: economy tick + wraith sim + servants + replication + ads.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetworkRouter = require(Shared.Framework.NetworkRouter)
local WallConfig = require(Shared.Configurations.WallConfig)
local WraithConfig = require(Shared.Configurations.WraithConfig)
local AscensionConfig = require(Shared.Configurations.AscensionConfig)
local SabotageConfig = require(Shared.Configurations.SabotageConfig)
local GearConfig = require(Shared.Configurations.GearConfig)
local MonetizationConfig = require(Shared.Configurations.MonetizationConfig)
local ProductConfig = require(Shared.Configurations.ProductConfig)
local SpellConfig = require(Shared.Configurations.SpellConfig)
local MultiplierMath = require(Shared.Utility.MultiplierMath)
local GearScoreMath = require(Shared.Utility.GearScoreMath)
local GraphicsConfig = require(Shared.Configurations.GraphicsConfig)
local CitadelService = require(script.Parent.CitadelService)
local DataService = require(script.Parent.DataService)
local WraithService = require(script.Parent.WraithService)
local CombatService = require(script.Parent.CombatService)
local GearAndAnvilService = require(script.Parent.GearAndAnvilService)
local InvasionService = require(script.Parent.InvasionService)
local AuctionService = require(script.Parent.AuctionService)
local CharacterDresser = require(script.Parent.CharacterDresser)

local GameService = {}

local BLOOD_PACT_LOCK_SECONDS = 30 * 60
local ANTI_LOG_HOLD_SECONDS = 90
-- DEBUG ONLY: Studio costs ÷100 so the full loop (unlock/max/ascend)
-- is testable in minutes. Live game always pays full price.
local STUDIO_DIV = if RunService:IsStudio() then 100 else 1
local GIFT_MINUTES = { 2, 5, 10, 15, 30, 45, 60 }
local GIFT_SHARDS = { [3] = 5, [5] = 15, [7] = 30 } -- 10m / 30m / 60m chests
local GIFT_LUCK_SECONDS = { [3] = 15 * 60, [5] = 30 * 60, [7] = 60 * 60 } -- Luck Elixir with shard chests
local SERVANT_COST = 2000
local SERVANT_MAX = 3
local SERVANT_HP = 300
local SERVANT_DPS = 12
local TRAP_COST = 1500 -- Session Pot / Vault souls (tactical siege sink)
local TRAP_MAX = 5
local TRAP_DAMAGE = 60 -- per trigger to invaders + wraiths (12-stud radius)
local TRAP_HITS = 3 -- triggers before the rune burns out
local TRAP_DURATION = 5 * 60 -- seconds before the rune fades
local TRAP_RADIUS = 12
local FIFTH_DEATH_WINDOW = 10
local AUCTION_SWEEP_SECONDS = 60

-- Shared world (one Citadel per server).
local world: {
	session: CitadelService.CitadelSession?,
	wraiths: WraithService.WraithState,
	servants: { any },
	traps: { any },
	ownerUserId: number?,
	ownerProfile: any?,
	ownerGone: boolean,
	holdUntil: number,
	wasPact: boolean,
	lastBreach: { wallIndex: number, stolen: number }?,
	lastAutoRoll: number,
	lastAuctionSweep: number,
} = {
	session = nil,
	wraiths = WraithService.newState(),
	servants = {},
	traps = {},
	ownerUserId = nil,
	ownerProfile = nil,
	ownerGone = false,
	holdUntil = 0,
	wasPact = false,
	lastBreach = nil,
	lastAutoRoll = 0,
	lastAuctionSweep = 0,
}

-- Per-player records. Shared subtables (session/wraiths/servants) alias
-- the world so CombatService/WraithService need no signature changes.
local records: { [number]: any } = {}

-- Fallen-ring ghost cache: walls are pure visuals (logic reads WallConfig
-- radii), so a breached ring fades to a ruin-ghost until it rebuilds.
local wallGhosted = { false, false, false }

local changedEvent: RemoteEvent? = nil
local wraithSync: RemoteEvent? = nil
local fifthDeathEvent: RemoteEvent? = nil
local noticeEvent: RemoteEvent? = nil

-- Transient banner messages (breaches, bounties, hires, gifts).
local function notify(player: Player, text: string, color: { number }?): ()
	if noticeEvent then
		noticeEvent:FireClient(player, { text = text, color = color or { 255, 190, 60 } })
	end
end

local function notifyAll(text: string, color: { number }?): ()
	for _, player in Players:GetPlayers() do
		notify(player, text, color)
	end
end

local function rankBenchmark(rank: number): number
	return math.max(1, rank) * 150000
end

local function equippedOf(profile: any, presetName: string): { any }
	local items: { any } = {}
	local preset = profile.Loadouts[presetName]
	if not preset then
		return items
	end
	for _, uid in { preset.WeaponUID, preset.ArmorUID, preset.Ring1UID, preset.Ring2UID } do
		if uid and profile.Inventory[uid] then
			table.insert(items, profile.Inventory[uid])
		end
	end
	return items
end

local function gearScoreOf(profile: any, presetName: string): number
	return GearScoreMath.CalculatePlayerGearScore(profile.AscensionRank, equippedOf(profile, presetName))
end

local function defenderRating(): number
	if not world.session then
		return 100
	end
	local wallHP = 0
	for i = 1, 3 do
		local wall = world.session.Walls[i]
		if wall and wall.Unlocked and not wall.IsCollapsedForSession then
			wallHP += wall.MaxHP
		end
	end
	local ownerRec = world.ownerUserId and records[world.ownerUserId]
	local gear = 0
	if ownerRec then
		local profile = DataService.GetByUserId(world.ownerUserId :: number)
		if profile then
			gear = gearScoreOf(profile, profile.ActiveLoadoutType)
		end
	end
	return math.max(100, wallHP + gear)
end

local function intactCount(): number
	if not world.session then
		return 0
	end
	local n = 0
	for i = 1, 3 do
		local wall = world.session.Walls[i]
		if wall and wall.Unlocked and not wall.IsCollapsedForSession then
			n += 1
		end
	end
	return n
end

local function attackerList(): { MultiplierMath.AttackerSnapshot }
	local list: { MultiplierMath.AttackerSnapshot } = {}
	for uid, rec in records do
		if rec.role == "invader" then
			local profile = DataService.GetByUserId(uid)
			-- GearScoreMath already includes rank power (rank * 500),
			-- so use it directly (blueprint AP_i spec).
			local ap = if profile then gearScoreOf(profile, "Raider") else 500
			table.insert(list, { AttackPower = ap, LastHostileTimestamp = rec.lastHostile or 0 })
		end
	end
	return list
end

local function liveMultiplier(): number
	if not world.session then
		return 1.0
	end
	local ownerProfile = world.ownerUserId and DataService.GetByUserId(world.ownerUserId :: number)
	local rank = if ownerProfile then ownerProfile.AscensionRank else 1
	return MultiplierMath.CalculateBloodPactMultiplier(
		world.session.IsBloodPactActive,
		world.session.SessionSoulPot,
		rankBenchmark(rank),
		defenderRating(),
		intactCount(),
		attackerList(),
		os.clock()
	)
end

local function totalContribution(): number
	local total = 0
	for _, rec in records do
		if rec.role == "invader" then
			total += rec.contribution or 0
		end
	end
	return total
end

local function buildSnapshot(player: Player, me: any, profile: any)
	local now = os.time()
	local session = world.session
	assert(session, "world session missing")
	local threat = CitadelService.CurrentThreat(session, now)
	local intensityBonus = math.round(CitadelService.IntensityBonus(session, now) * 100) / 100
	local walls = {}
	for i = 1, 3 do
		local wall = session.Walls[i]
		local missing = wall.MaxHP - wall.CurrentHP
		local repairCost = 0
		if wall.Unlocked and not wall.IsCollapsedForSession and missing > 0 then
			repairCost = math.round(math.min(math.floor(wall.MaxHP * 0.20), missing) * (WallConfig[i].RepairCostPerHP or 5))
		end
		walls[i] = {
			unlocked = wall.Unlocked,
			level = wall.PermanentLevel,
			hp = wall.CurrentHP,
			maxHP = wall.MaxHP,
			ratio = CitadelService.GetEffectiveDefenseRatio(session, i, now),
			threat = threat,
			elixirRemaining = math.max(0, wall.ElixirExpiresAt - now),
			autoRenew = wall.AutoRenewElixir,
			upgradeCost = math.max(1, math.round(WallConfig[i].UpgradeCostBase * (WallConfig[i].UpgradeCostScale ^ wall.PermanentLevel) / STUDIO_DIV)),
			unlockCost = math.max(1, math.round(WallConfig[i].UnlockCost / STUDIO_DIV)),
			-- Price the elixir for the mode the wall is actually in: the
			-- auto-renew convenience surcharge applies when auto-renew is
			-- armed and the Master Alchemist Pass does not waive it.
			elixirCost = math.round(
				WallConfig[i].ElixirBaseCost
					* (if wall.AutoRenewElixir and not session.HasAlchemistPass
						then WallConfig[i].ElixirAutoRenewMultiplier
						else 1)
			),
			repairCost = repairCost,
			collapsed = wall.IsCollapsedForSession,
		}
	end
	local elapsed = now - (me.joinTime or now)
	local gifts = {}
	for gi, minutes in GIFT_MINUTES do
		local claimed = profile.ClaimedPlaytimeGifts[gi] == true
		gifts[gi] = {
			minute = minutes,
			claimed = claimed,
			claimable = (not claimed) and elapsed >= minutes * 60,
			remaining = math.max(0, minutes * 60 - elapsed),
		}
	end
	local share = 0
	if me.role == "invader" then
		share = (me.contribution or 0) / math.max(1, totalContribution())
	end
	local allies = 0
	for _, rec in records do
		if rec.role == "ally" then
			allies += 1
		end
	end
	return {
		vault = if me.role == "defender" then session.PermanentVaultSouls else profile.PermanentVaultSouls,
		pot = session.SessionSoulPot,
		shards = profile.BloodShards,
		crowns = profile.EclipseCrowns or 0,
		multiplier = math.round(liveMultiplier() * AscensionConfig.SoulMultiplier(session.AscensionRank) * 100) / 100,
		isPact = session.IsBloodPactActive,
		lockRemaining = math.max(0, session.BloodPactLockedUntil - now),
		awaitingDecision = session.AwaitingBreachDecision,
		intactWalls = intactCount(),
		elapsed = elapsed,
		walls = walls,
		gifts = gifts,
		role = me.role,
		isOwner = player.UserId == world.ownerUserId,
		lives = me.lives or 0,
		streak = if os.clock() - (me.lastKillAt or 0) > 6 then 0 else (me.killStreak or 0),
		intensityBonus = intensityBonus,
		share = share,
		servants = #world.servants,
		traps = #world.traps,
		hasAlchemist = profile.HasAlchemistPass == true,
		hasDual = profile.HasDualLoadoutPass == true,
		autoRoll = profile.AutoRollEnabled == true,
		luckRemaining = math.max(0, (profile.LuckElixirUntil or 0) - now),
		reforgeCredits = profile.ReforgeCredits or 0,
		rank = world.session.AscensionRank,
		rankName = AscensionConfig.RankName(world.session.AscensionRank),
		maxLevel = AscensionConfig.MaxPermanentLevel,
		wardJamRemaining = math.max(0, (world.session.WardJamUntil or 0) - now),
		allies = allies,
	}
end

local function pushSnapshot(player: Player): ()
	local me = records[player.UserId]
	if not me or not world.session then
		return
	end
	local profile = DataService.GetByUserId(player.UserId)
	if not profile then
		return
	end
	if changedEvent then
		changedEvent:FireClient(player, buildSnapshot(player, me, profile))
	end
end

local function pushAll(): ()
	for _, player in Players:GetPlayers() do
		pushSnapshot(player)
	end
end

-- Shared breach guard: decay tick + wraith tick can hit 0 together.
-- Loot splits by invader contribution (burns when nobody scored).
--
-- This is the ONLY place a breach is announced, and it fires synchronously
-- inside CitadelService.HandleWallBreach. The previous implementation diffed
-- `IsCollapsedForSession` on the next 1s tick, which missed every breach
-- caused between ticks (i.e. all raider combat) — leaving Blood Insurance
-- unredeemable and the "WALL FALLEN" notice silent for the common case.
local function distributeLoot(wallIndex: number, stolen: number): ()
	world.lastBreach = {
		wallIndex = wallIndex,
		stolen = math.max(0, stolen),
	}
	notifyAll(`💥 Wall {wallIndex} ({WallConfig[wallIndex].Name}) has FALLEN!`, { 255, 60, 70 })

	local total = totalContribution()
	if total <= 0 then
		return
	end
	for _, player in Players:GetPlayers() do
		local rec = records[player.UserId]
		if rec and rec.role == "invader" and (rec.contribution or 0) > 0 then
			local cut = math.floor(stolen * (rec.contribution / total))
			local profile = DataService.GetByUserId(player.UserId)
			if profile and cut > 0 then
				profile.PermanentVaultSouls += cut
			end
		end
	end
	-- Anti-combat-log ledger: theft while the owner is gone is recorded
	-- on their profile so the next session can report it. (Vault souls are
	-- untouched — the stolen souls left the Session Pot, which already
	-- excludes them — so this field is informational, never deducted.)
	if world.ownerGone and world.ownerProfile then
		world.ownerProfile.PendingOfflineTheft += stolen
	end
end

local function onWallBreach(wallIndex: number): ()
	if not world.session then
		return
	end
	local wall = world.session.Walls[wallIndex]
	if wall and not wall.IsCollapsedForSession and wall.CurrentHP <= 0 then
		CitadelService.HandleWallBreach(world.session, wallIndex, distributeLoot)
	end
end

-- -- Servants ---------------------------------------------------------------

-- Ghosts a fallen ring (Transparency 0.8) and restores it on rebuild.
-- Original transparency is cached per part so neon veils restore exactly.
local function restoreWallTransparency(): ()
	local citadel = Workspace:FindFirstChild("Citadel")
	if not citadel then
		return
	end
	for i = 1, 3 do
		local model = citadel:FindFirstChild(`Wall_{i}`)
		if model then
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d:GetAttribute("OrigTrans") ~= nil then
					d.Transparency = d:GetAttribute("OrigTrans") :: number
					d:SetAttribute("OrigTrans", nil)
				end
			end
		end
	end
end

local function syncWallVisuals(): ()
	if not world.session then
		return
	end
	local citadel = Workspace:FindFirstChild("Citadel")
	if not citadel then
		return
	end
	for i = 1, 3 do
		local wall = world.session.Walls[i]
		local fallen = wall.IsCollapsedForSession
		if fallen ~= wallGhosted[i] then
			wallGhosted[i] = fallen
			local model = citadel:FindFirstChild(`Wall_{i}`)
			if model then
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") then
						if d:GetAttribute("OrigTrans") == nil then
							d:SetAttribute("OrigTrans", d.Transparency)
						end
						d.Transparency = if fallen then 0.8 else (d:GetAttribute("OrigTrans") or 0) :: number
					end
				end
			end
		end
	end
end

local function servantsFolder(): Folder
	local folder = Workspace:FindFirstChild("Servants")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Servants"
		folder.Parent = Workspace
	end
	return folder :: Folder
end

local function spawnServant(): ()
	if #world.servants >= SERVANT_MAX then
		return
	end
	local part = Instance.new("Part")
	part.Name = "SpectralServant"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(4, 4, 4)
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(150, 120, 255)
	part.Transparency = 0.25
	part.Anchored = true
	part.CanCollide = false
	local angle = math.random() * math.pi * 2
	part.Position = Vector3.new(math.cos(angle) * 90, 4, math.sin(angle) * 90)
	part.Parent = servantsFolder()
	-- Watcher dressing rides the body (parented + welded, so cleanup is automatic).
	local function attach(name: string, size: Vector3, offset: Vector3, color: Color3, transparency: number, shape: Enum.PartType?, flat: boolean?): ()
		local extra = Instance.new("Part")
		extra.Name = name
		if shape then
			extra.Shape = shape
		end
		extra.Size = size
		extra.CFrame = part.CFrame * CFrame.new(offset) * if flat then CFrame.Angles(0, 0, math.pi / 2) else CFrame.new()
		extra.Anchored = true
		extra.CanCollide = false
		extra.CanQuery = false
		extra.Transparency = transparency
		extra.Material = Enum.Material.Neon
		extra.Color = color
		extra.Parent = part
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part
		weld.Part1 = extra
		weld.Parent = part
	end
	attach("ServantCore", Vector3.new(2, 2, 2), Vector3.new(0, 0, 0), Color3.fromRGB(40, 20, 80), 0.1, Enum.PartType.Ball, false)
	attach("ServantHalo", Vector3.new(0.4, 7, 7), Vector3.new(0, 0, 0), Color3.fromRGB(150, 120, 255), 0.7, Enum.PartType.Cylinder, true)
	attach("ServantEye", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 3.4, 0), Color3.fromRGB(240, 250, 255), 0, Enum.PartType.Ball, false)
	table.insert(world.servants, { part = part, hp = SERVANT_HP, maxHP = SERVANT_HP, angle = angle, radius = 90 })
end

local function stepServants(dt: number): ()
	if not world.session then
		return
	end
	for i = #world.servants, 1, -1 do
		local servant = world.servants[i]
		if not servant.part or not servant.part.Parent then
			table.remove(world.servants, i)
			continue
		end
		-- Hunt the nearest invader inside 80 studs, else patrol Wall 2.
		local target: BasePart? = nil
		local best = 80
		for _, player in Players:GetPlayers() do
			local rec = records[player.UserId]
			if rec and rec.role == "invader" then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if root and humanoid and humanoid.Health > 0 then
					local d = (root.Position - servant.part.Position).Magnitude
					if d < best then
						best = d
						target = root
					end
				end
			end
		end
		if target then
			local pos = servant.part.Position
			local dir = (target.Position - pos)
			local flat = Vector3.new(dir.X, 0, dir.Z)
			if flat.Magnitude > 20 then
				servant.part.Position = pos + flat.Unit * math.min(10 * dt, flat.Magnitude - 15)
				servant.part.Position = Vector3.new(servant.part.Position.X, 4, servant.part.Position.Z)
			else
				local humanoid = target.Parent and (target.Parent :: Model):FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid:TakeDamage((servant.dps or SERVANT_DPS) * dt)
					target.Parent:SetAttribute("LastHitBy", world.ownerUserId or 0)
					target.Parent:SetAttribute("LastHitAt", os.clock())
				end
			end
		else
			servant.angle += 0.15 * dt
			servant.part.Position =
				Vector3.new(math.cos(servant.angle) * 90, 4, math.sin(servant.angle) * 90)
		end
	end
end

-- -- Rune traps (defender tactical sink: Session Pot / Vault souls) --------

local function trapsFolder(): Folder
	local folder = Workspace:FindFirstChild("Traps")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Traps"
		folder.Parent = Workspace
	end
	return folder :: Folder
end

local function spawnTrapAt(position: Vector3): ()
	local part = Instance.new("Part")
	part.Name = "RuneTrap"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.6, 8, 8)
	part.Position = Vector3.new(position.X, 0.4, position.Z)
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0.35
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 60, 90)
	part.Parent = trapsFolder()
	-- Etched glyph + warning ring + corner fangs (parented: auto-cleanup).
	local glyph = Instance.new("Part")
	glyph.Name = "RuneGlyph"
	glyph.Shape = Enum.PartType.Cylinder
	glyph.Size = Vector3.new(0.25, 5, 5)
	glyph.CFrame = CFrame.new(part.Position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	glyph.Anchored = true
	glyph.CanCollide = false
	glyph.CanQuery = false
	glyph.Transparency = 0.3
	glyph.Material = Enum.Material.Neon
	glyph.Color = Color3.fromRGB(255, 150, 160)
	glyph.Parent = part
	local warnRing = Instance.new("Part")
	warnRing.Name = "RuneWarnRing"
	warnRing.Shape = Enum.PartType.Cylinder
	warnRing.Size = Vector3.new(0.2, 26, 26)
	warnRing.CFrame = CFrame.new(part.Position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	warnRing.Anchored = true
	warnRing.CanCollide = false
	warnRing.CanQuery = false
	warnRing.Transparency = 0.8
	warnRing.Material = Enum.Material.Neon
	warnRing.Color = Color3.fromRGB(255, 60, 90)
	warnRing.Parent = part
	for t = 0, 3 do
		local ta = (t / 4) * math.pi * 2 + math.pi / 4
		local fang = Instance.new("Part")
		fang.Name = `RuneFang_{t + 1}`
		fang.Size = Vector3.new(1, 1.6, 1)
		fang.Position = part.Position + Vector3.new(math.cos(ta) * 5.5, 0.4, math.sin(ta) * 5.5)
		fang.Anchored = true
		fang.CanCollide = false
		fang.Material = Enum.Material.Cobblestone
		fang.Color = Color3.fromRGB(45, 25, 35)
		fang.Parent = part
	end
	table.insert(world.traps, {
		part = part,
		pos = Vector3.new(position.X, 0, position.Z),
		hitsLeft = TRAP_HITS,
		expiresAt = os.time() + TRAP_DURATION,
		coolUntil = 0,
	})
end

local function stepTraps(now: number): ()
	if not world.session then
		return
	end
	local ownerProfile = world.ownerUserId and DataService.GetByUserId(world.ownerUserId)
	for i = #world.traps, 1, -1 do
		local trap = world.traps[i]
		if not trap.part or not trap.part.Parent or now >= trap.expiresAt or trap.hitsLeft <= 0 then
			if trap.part and trap.part.Parent then
				trap.part:Destroy()
			end
			table.remove(world.traps, i)
			continue
		end
		if os.clock() < (trap.coolUntil or 0) then
			continue
		end
		-- Trigger: any live invader inside the rune circle.
		local tripped = false
		for _, player in Players:GetPlayers() do
			local rec = records[player.UserId]
			if rec and rec.role == "invader" then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if root and humanoid and humanoid.Health > 0 then
					local flat = Vector3.new(root.Position.X, 0, root.Position.Z) - trap.pos
					if flat.Magnitude <= TRAP_RADIUS then
						humanoid:TakeDamage(TRAP_DAMAGE)
						character:SetAttribute("LastHitBy", world.ownerUserId or 0)
						character:SetAttribute("LastHitAt", os.clock())
						tripped = true
					end
				end
			end
		end
		if tripped then
			-- The blast also shreds nearby wraiths (souls flow to the pot/vault).
			local session = world.session
			if ownerProfile then
				WraithService.DamageAt(world.wraiths, session, ownerProfile, trap.pos, TRAP_RADIUS, TRAP_DAMAGE * 4)
			end
			trap.hitsLeft -= 1
			trap.coolUntil = os.clock() + 2 -- one blast per 2s max
			trap.part.Color = if trap.hitsLeft > 0 then Color3.fromRGB(255, 60, 90) else Color3.fromRGB(60, 60, 70)
		end
	end
end

-- -- Banish / bounty ----------------------------------------------------------

local function attackerPower(uid: number): number
	local profile = DataService.GetByUserId(uid)
	if not profile then
		return 500
	end
	-- GearScoreMath already includes rank power (blueprint AP_i spec).
	return gearScoreOf(profile, "Raider")
end

-- Milestone 4: +30% hex duration while a Raider ring is equipped.
local function hasRaiderRing(profile: any): boolean
	local preset = profile.Loadouts and profile.Loadouts.Raider
	if not preset then
		return false
	end
	for _, uid in { preset.Ring1UID, preset.Ring2UID } do
		if uid then
			local item = profile.Inventory[uid]
			local cfg = item and GearConfig[item.ItemId]
			if cfg and cfg.Slot == "Ring" and cfg.WallDamageBonus > 0 then
				return true
			end
		end
	end
	return false
end

local function allyCount(): number
	local n = 0
	for _, rec in records do
		if rec.role == "ally" then
			n += 1
		end
	end
	return n
end

local function payBounty(invaderUid: number, deathPos: Vector3): ()
	if not world.ownerUserId then
		return
	end
	local ownerProfile = DataService.GetByUserId(world.ownerUserId)
	if not ownerProfile then
		return
	end
	local shards = math.max(1, math.floor(attackerPower(invaderUid) / 500))
	ownerProfile.BloodShards += shards
	for _, player in Players:GetPlayers() do
		if player.UserId == world.ownerUserId then
			notify(player, `🩸 Invader wiped! Bounty +{shards} Shards + chest!`, { 255, 80, 100 })
		end
	end
	-- Physical Cursed Bounty Chest (+5 shards, one claim): iron-bound
	-- strongbox with a glowing seal, light, and rising soul-sparkles.
	local chest = Instance.new("Part")
	chest.Name = "BountyChest"
	chest.Size = Vector3.new(3, 2, 3)
	chest.Position = deathPos + Vector3.new(0, 2, 0)
	chest.Anchored = true
	chest.Material = Enum.Material.Cobblestone
	chest.Color = Color3.fromRGB(70, 50, 25)
	chest.Parent = Workspace
	local lid = Instance.new("Part")
	lid.Name = "BountyLid"
	lid.Size = Vector3.new(3.2, 1, 3.2)
	lid.Position = chest.Position + Vector3.new(0, 1.4, 0)
	lid.Anchored = true
	lid.Material = Enum.Material.SmoothPlastic
	lid.Color = Color3.fromRGB(150, 110, 45)
	lid.Parent = chest
	local trim = Instance.new("Part")
	trim.Name = "BountyTrim"
	trim.Size = Vector3.new(3.3, 0.35, 3.3)
	trim.Position = chest.Position + Vector3.new(0, 0.7, 0)
	trim.Anchored = true
	trim.CanCollide = false
	trim.CanQuery = false
	trim.Material = Enum.Material.Neon
	trim.Color = Color3.fromRGB(255, 190, 60)
	trim.Parent = chest
	local glow = Instance.new("PointLight")
	glow.Name = "BountyLight"
	glow.Color = Color3.fromRGB(255, 190, 60)
	glow.Range = 20
	glow.Brightness = 2
	glow.Shadows = false
	glow.Parent = lid
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "BountySparkles"
	sparkles.Rate = GraphicsConfig.ScaledRate(8)
	sparkles.Lifetime = NumberRange.new(0.6, 1.2)
	sparkles.Speed = NumberRange.new(2, 5)
	sparkles.Size = NumberSequence.new(0.8)
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 220, 130))
	sparkles.LightEmission = 1
	sparkles.Parent = lid
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Claim Bounty"
	prompt.ObjectText = "+5 Blood Shards"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 12
	prompt.Parent = chest
	prompt.Triggered:Connect(function(player: Player)
		local profile = DataService.GetByUserId(player.UserId)
		if profile then
			profile.BloodShards += 5
		end
		chest:Destroy()
	end)
	task.delay(120, function()
		if chest.Parent then
			chest:Destroy()
		end
	end)
end

local function banish(player: Player): ()
	local me = records[player.UserId]
	local profile = DataService.GetByUserId(player.UserId)
	if me and profile then
		-- Albion-lite fracture: Raider weapon -25% until repaired.
		local raider = profile.Loadouts.Raider
		local weapon = raider and profile.Inventory[raider.WeaponUID]
		if weapon then
			weapon.IsFractured = true
		end
		me.contribution = 0
		me.lives = 0
	end
	local ok = pcall(TeleportService.Teleport, TeleportService, game.PlaceId, player)
	if not ok then
		player:Kick("Banished from the siege — Raider weapon fractured (-25% power). Rejoin fresh.")
	end
end

local function forfeit(player: Player): ()
	local me = records[player.UserId]
	if not me or me.role ~= "invader" then
		return
	end
	me.fifthDeathAt = nil
	banish(player)
end

-- -- Spawning -----------------------------------------------------------------

-- -- Milestone 5: purchase grants ---------------------------------------------
-- Called by MonetizationService receipt handler. Returns true when granted.

function GameService.SyncOwnerPasses(userId: number, hasAlchemist: boolean): ()
	if world.ownerUserId == userId and world.session then
		world.session.HasAlchemistPass = hasAlchemist
	end
end

function GameService.ApplyPurchase(player: Player, profile: any, key: string): boolean
	local me = records[player.UserId]
	if not me or not world.session then
		return false
	end
	local session = world.session

	if key == "BloodInsurance" then
		-- Defender-only panic buy. Without this an invader could refund the
		-- raid's stolen souls to the defender's pot, rebuild their wall and
		-- grant the defender 5 minutes of invulnerability — by spending the
		-- attacker's own money.
		if me.role ~= "defender" then
			return false
		end
		-- 15s-style panic: valid while the breach modal is open.
		local breach = world.lastBreach
		if not session.AwaitingBreachDecision or not breach then
			return false
		end
		local wall = session.Walls[breach.wallIndex]
		-- AwaitingBreachDecision is only ever set inside the Blood Pact branch
		-- of HandleWallBreach, so the pot is the only account that can hold
		-- the stolen souls here.
		session.SessionSoulPot += breach.stolen
		if wall then
			wall.IsCollapsedForSession = false
			wall.CurrentHP = wall.MaxHP
		end
		session.ShieldUntil = os.time() + 5 * 60
		session.AwaitingBreachDecision = false
		world.lastBreach = nil
		notify(player, "🛡 Blood Insurance: wall restored + 5-min shield!", { 80, 220, 140 })
	elseif key == "VengeanceCurse" then
		if me.role ~= "defender" then
			return false
		end
		-- Repair the outermost fallen wall, else heal the front line.
		-- `intactCount()` is a COUNT, not an index, so it could never equal
		-- the loop variable on a gapped wall set and the purchase silently
		-- did nothing after the player paid.
		local repaired = false
		for i = 3, 1, -1 do
			local wall = session.Walls[i]
			if wall and wall.Unlocked and wall.IsCollapsedForSession then
				wall.IsCollapsedForSession = false
				wall.CurrentHP = wall.MaxHP
				repaired = true
				break
			end
		end
		if not repaired then
			for i = 3, 1, -1 do
				local wall = session.Walls[i]
				if wall and wall.Unlocked and not wall.IsCollapsedForSession then
					wall.CurrentHP = math.min(wall.MaxHP, wall.CurrentHP + wall.MaxHP * 0.25)
					break
				end
			end
		end
		-- A vengeful Elite Lich fights for the defender (cross-server
		-- retaliation ships post-launch; this is its in-server form).
		if #world.servants < 6 then
			local folder = Workspace:FindFirstChild("Servants")
			if not folder then
				folder = Instance.new("Folder")
				folder.Name = "Servants"
				folder.Parent = Workspace
			end
			local part = Instance.new("Part")
			part.Name = "VengefulLich"
			part.Shape = Enum.PartType.Ball
			part.Size = Vector3.new(7, 7, 7)
			part.Material = Enum.Material.Neon
			part.Color = Color3.fromRGB(230, 50, 90)
			part.Transparency = 0.25
			part.Anchored = true
			part.CanCollide = false
			part.Position = Vector3.new(0, 6, 0)
			part.Parent = folder
			for c = -1, 1 do
				local spike = Instance.new("Part")
				spike.Name = `LichCrown_{c}`
				spike.Size = Vector3.new(1.2, 3, 1.2)
				spike.Position = part.Position + Vector3.new(c * 2, 4.5, 0)
				spike.Anchored = true
				spike.CanCollide = false
				spike.Material = Enum.Material.Cobblestone
				spike.Color = Color3.fromRGB(30, 18, 40)
				spike.Parent = part
			end
			local dread = Instance.new("PointLight")
			dread.Name = "LichLight"
			dread.Color = Color3.fromRGB(230, 50, 90)
			dread.Range = 30
			dread.Brightness = 2
			dread.Shadows = false
			dread.Parent = part
			table.insert(world.servants, { part = part, hp = 1500, maxHP = 1500, angle = 0, radius = 60, dps = 40 })
		end
		session.AwaitingBreachDecision = false
		notifyAll("😡 VENGEANCE CURSE! An Elite Lich joins the defense!", { 255, 60, 90 })
	elseif key == "MercenaryPact" then
		if me.role ~= "defender" then
			return false
		end
		local count = 0
		while #world.servants < 6 and count < 3 do
			spawnServant()
			count += 1
		end
		if count == 0 then
			return false
		end
		notify(player, `👻 {count} elite mercenaries hired!`, { 170, 130, 255 })
	elseif key == "ExtraTethers" then
		if me.role ~= "invader" or not me.fifthDeathAt then
			return false
		end
		me.lives = (me.lives or 0) + 3
		me.fifthDeathAt = nil
		notify(player, "💀 +3 Soul Tethers! Back into the siege!", { 120, 220, 255 })
	elseif key == "WraithColossus" then
		if me.role ~= "invader" or not session.IsBloodPactActive then
			return false
		end
		-- Valley-wide griefing event: a Colossus + honor guard warp in.
		local colossusAngle = math.random() * math.pi * 2
		table.insert(world.wraiths.list, {
			id = world.wraiths.nextId,
			wraithType = "Lich",
			hp = 20000,
			maxHP = 20000,
			angle = colossusAngle,
			radius = 120,
		})
		world.wraiths.nextId += 1
		for _ = 1, 4 do
			table.insert(world.wraiths.list, {
				id = world.wraiths.nextId,
				wraithType = "Revenant",
				hp = 900,
				maxHP = 900,
				angle = math.random() * math.pi * 2,
				radius = 130,
			})
			world.wraiths.nextId += 1
		end
		-- Doom beacon: a crackling sky-beam marks the Colossus landing zone.
		local beacon = Instance.new("Part")
		beacon.Name = "ColossusBeacon"
		beacon.Size = Vector3.new(4, 90, 4)
		beacon.Position = Vector3.new(math.cos(colossusAngle) * 120, 45, math.sin(colossusAngle) * 120)
		beacon.Anchored = true
		beacon.CanCollide = false
		beacon.CanQuery = false
		beacon.Transparency = 0.45
		beacon.Material = Enum.Material.Neon
		beacon.Color = Color3.fromRGB(255, 60, 60)
		beacon.Parent = Workspace
		local beaconLight = Instance.new("PointLight")
		beaconLight.Name = "ColossusLight"
		beaconLight.Color = Color3.fromRGB(255, 60, 60)
		beaconLight.Range = 60
		beaconLight.Brightness = 3
		beaconLight.Shadows = false
		beaconLight.Parent = beacon
		task.delay(45, function()
			if beacon.Parent then
				beacon:Destroy()
			end
		end)
		notifyAll("🦣 A WRAITH COLOSSUS storms the walls!", { 255, 120, 60 })
	elseif key == "RoyalDecree" then
		-- 39 R$ early exit: bypasses the 30-minute Blood Pact lock and banks
		-- the surviving Session Pot into the Permanent Vault.
		-- Defender-only: an invader buying this would cash the DEFENDER's
		-- Blood Pact out from under them.
		if me.role ~= "defender" then
			return false
		end
		if not session.IsBloodPactActive then
			return false
		end
		CitadelService.ExitBloodPactAndBank(session)
		InvasionService.Unpublish()
		world.lastBreach = nil
		profile.PermanentVaultSouls = session.PermanentVaultSouls
		notify(player, "📜 Royal Decree: Blood Pact ended — pot banked safely!", { 255, 220, 130 })
	elseif key == "AnvilReforge1" then
		profile.ReforgeCredits = (profile.ReforgeCredits or 0) + 1
		notify(player, "⚒ +1 Anvil Reforge credit! Chase that Cataclysmic!", { 255, 190, 60 })
	elseif key == "AnvilReforge10" then
		profile.ReforgeCredits = (profile.ReforgeCredits or 0) + 10
		notify(player, "⚒ +10 Anvil Reforge credits! Chase that Cataclysmic!", { 255, 190, 60 })
	else
		-- Blood Shard packs are pure profile grants. Sizing comes from
		-- ProductConfig (single source of truth) instead of a second,
		-- drifting hardcoded table.
		local entry = ProductConfig.Products[key]
		if not entry or not entry.shards then
			return false
		end
		profile.BloodShards += entry.shards
		notify(player, `💎 +{entry.shards} Blood Shards!`, { 120, 220, 255 })
	end
	pushAll()
	return true
end

-- Maps new MonetizationConfig catalog keys -> legacy ApplyPurchase keys.
local CROWN_TO_LEGACY: { [string]: string } = {
	Blood_Insurance = "BloodInsurance",
	Vengeance_Curse = "VengeanceCurse",
	Emergency_Mercenaries = "MercenaryPact",
	Extra_Soul_Tethers = "ExtraTethers",
	Summon_Wraith_Colossus = "WraithColossus",
	Royal_Decree = "RoyalDecree",
	Anvil_Reforge_1x = "AnvilReforge1",
	Anvil_Reforge_10x = "AnvilReforge10",
}

-- 1-click instant spend: validates Crown balance, deducts atomically on the
-- server, then grants the Pass / Panic Save / Shard bundle in 0ms (no Roblox
-- purchase dialog). Returns (success, message).
function GameService.ApplyCrownPurchase(player: Player, profile: any, catalogKey: string): (boolean, string)
	local entry = MonetizationConfig.Catalog[catalogKey]
	if not entry then
		return false, "Unknown item."
	end
	if (profile.EclipseCrowns or 0) < entry.CrownPrice then
		return false, `Need {entry.CrownPrice} Eclipse Crowns (you save 30% vs Robux). Buy a Crown pack!`
	end
	-- Passes: grant directly (Crowns bypass Roblox Game Pass ownership).
	-- The server is the authority here, so ownership must be enforced even
	-- though the shop hides owned rows: without this a double-click on the
	-- Crown button charged 2x115 Crowns for one permanent flag.
	if catalogKey == "Master_Alchemist_Pass" then
		if profile.HasAlchemistPass then
			return false, "You already own the Master Alchemist Pass."
		end
		profile.EclipseCrowns -= entry.CrownPrice
		profile.HasAlchemistPass = true
		GameService.SyncOwnerPasses(player.UserId, true)
		pushAll()
		return true, ""
	end
	if catalogKey == "Dual_Loadout_Pass" then
		if profile.HasDualLoadoutPass then
			return false, "You already own the Dual Loadout Pass."
		end
		profile.EclipseCrowns -= entry.CrownPrice
		profile.HasDualLoadoutPass = true
		pushAll()
		return true, ""
	end
	-- Blood Shard bundles: pure profile grants at 1.3x value.
	if entry.BloodShardGrant then
		profile.EclipseCrowns -= entry.CrownPrice
		profile.BloodShards += entry.BloodShardGrant
		notify(player, `💎 +{entry.BloodShardGrant} Blood Shards (1.3x Crown value)!`, { 120, 220, 255 })
		pushAll()
		return true, ""
	end
	-- Panic / griefing / reforge credits: reuse legacy grant logic.
	local legacyKey = CROWN_TO_LEGACY[catalogKey]
	if not legacyKey then
		return false, "Unknown item."
	end
	-- Deduct first, refund if the situational grant fails (e.g. Insurance with no breach).
	profile.EclipseCrowns -= entry.CrownPrice
	local granted = GameService.ApplyPurchase(player, profile, legacyKey)
	if not granted then
		profile.EclipseCrowns += entry.CrownPrice
		return false, "Not usable right now (refunded)."
	end
	return true, ""
end

local function spawnSpot(prefix: string): CFrame?
	local citadel = Workspace:FindFirstChild("Citadel")
	if not citadel then
		return nil
	end
	local spots = {}
	for _, child in citadel:GetDescendants() do
		if child:IsA("BasePart") and string.sub(child.Name, 1, #prefix) == prefix then
			table.insert(spots, child)
		end
	end
	if #spots == 0 then
		return nil
	end
	local pick = spots[math.random(1, #spots)] :: BasePart
	return pick.CFrame + Vector3.new(0, 4, 0)
end

local function placeCharacter(player: Player, spot: CFrame?): ()
	local character = player.Character
	if not character or not spot then
		return
	end
	character:WaitForChild("HumanoidRootPart", 5)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.CFrame = spot
	end
end

local function hookCharacter(player: Player, character: Model): ()
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	task.spawn(CharacterDresser.Dress, player, character)
	humanoid.Died:Connect(function()
		local me = records[player.UserId]
		if not me then
			return
		end
		local deathPos = Vector3.new(0, 5, 0)
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			deathPos = root.Position
		end
		if me.role == "invader" then
			me.lives = math.max(0, (me.lives or 1) - 1)
			if me.lives > 0 then
				task.delay(3, function()
					if player.Parent and records[player.UserId] == me and me.lives > 0 then
						player:LoadCharacter()
						placeCharacter(player, spawnSpot("InvaderSpawn_"))
					end
				end)
			else
				-- 5th death: bounty now, 10s panic window, then fracture+banish.
				payBounty(player.UserId, deathPos)
				me.fifthDeathAt = os.clock()
				if fifthDeathEvent then
					fifthDeathEvent:FireClient(player)
				end
				task.delay(FIFTH_DEATH_WINDOW, function()
					if records[player.UserId] == me and me.fifthDeathAt then
						forfeit(player)
					end
				end)
			end
		else
			-- Defender falls: invader killer banks contribution, defender reforms.
			local killer = character:GetAttribute("LastHitBy")
			local hitAt = character:GetAttribute("LastHitAt")
			if typeof(killer) == "number" and typeof(hitAt) == "number" and os.clock() - hitAt <= 5 then
				local kRec = records[killer]
				if kRec and kRec.role == "invader" then
					kRec.contribution = (kRec.contribution or 0) + 200
					kRec.lastHostile = os.clock()
				end
			end
			task.delay(3, function()
				if player.Parent and records[player.UserId] == me then
					player:LoadCharacter()
				end
			end)
		end
		pushAll()
	end)
end

local function buildWorldFrom(ownerProfile: any): ()
	world.session = {
		OwnerUserId = world.ownerUserId,
		PermanentVaultSouls = ownerProfile.PermanentVaultSouls,
		SessionSoulPot = 0,
		AscensionRank = ownerProfile.AscensionRank,
		HasAlchemistPass = ownerProfile.HasAlchemistPass,
		IsBloodPactActive = false,
		BloodPactLockedUntil = 0,
		BloodPactStartedAt = 0,
		RepairReadyAt = 0,
		AwaitingBreachDecision = false,
		ShieldUntil = 0,
		WardJamUntil = 0,
		Walls = {},
	}
	for i = 1, 3 do
		local saved = ownerProfile.Walls[i];
		(world.session :: any).Walls[i] = {
			Unlocked = if i == 1 then true else (saved and saved.Unlocked or false),
			PermanentLevel = saved and saved.PermanentDefenseLevel or 0,
			CurrentHP = WallConfig[i].BaseMaxHP,
			MaxHP = WallConfig[i].BaseMaxHP,
			IsCollapsedForSession = false,
			ElixirExpiresAt = 0,
			AutoRenewElixir = saved and saved.AutoRenewElixir or false,
		}
	end
	world.wraiths = WraithService.newState()
	-- Reset the ghost cache AND put the meshes back. Clearing wallGhosted
	-- alone left syncWallVisuals with no state change to react to, so every
	-- ring stayed at 0.8 transparency for the rest of the server's life.
	wallGhosted = { false, false, false }
	restoreWallTransparency()
	world.lastBreach = nil
end

local function resetWorld(): ()
	world.session = nil
	world.wraiths = WraithService.newState()
	wallGhosted = { false, false, false }
	restoreWallTransparency()
	world.lastBreach = nil
	world.lastAutoRoll = 0
	for _, servant in world.servants do
		if servant.part and servant.part.Parent then
			servant.part:Destroy()
		end
	end
	world.servants = {}
	for _, trap in world.traps do
		if trap.part and trap.part.Parent then
			trap.part:Destroy()
		end
	end
	world.traps = {}
	-- Release a parked anti-log-hold profile before dropping the reference.
	-- It stayed locked in DataService (auto-saving, never banked) forever
	-- otherwise, because PlayerRemoving only released it in the
	-- no-invaders branch and the hold-expiry branch could be skipped.
	if world.ownerUserId then
		DataService.ReleaseByUserId(world.ownerUserId)
	end
	world.ownerUserId = nil
	world.ownerProfile = nil
	world.ownerGone = false
	world.holdUntil = 0
	world.wasPact = false
	world.lastAuctionSweep = 0
	InvasionService.Unpublish()
end

local function setupPlayer(player: Player): ()
	local profile = DataService.GetByUserId(player.UserId)
	if not profile then
		-- DataService.PlayerAdded may not have run yet; wait briefly.
		local tries = 0
		while not profile and tries < 20 do
			task.wait(0.25)
			tries += 1
			profile = DataService.GetByUserId(player.UserId)
		end
	end
	if not profile then
		player:Kick("Profile unavailable. Rejoin to continue.")
		return
	end

	-- Arrival order alone cannot decide the role: a raider using the Raid
	-- Browser teleports into the target's server and is very often the first
	-- player through the door. InvasionService reads the role that
	-- TeleportOptions stamped on the join, so the invasion actually lands.
	local hasOwner = world.ownerUserId ~= nil
	local role: string = InvasionService.JoinRole(player)
	if not hasOwner then
		-- No Citadel exists yet: this player owns it and defends it.
		role = "defender"
		world.ownerUserId = player.UserId
		buildWorldFrom(profile)
	elseif role == "defender" then
		-- Joined an occupied world without a raid flag: they came to invade.
		role = "invader"
	end

	records[player.UserId] = {
		session = world.session,
		wraiths = world.wraiths,
		servants = world.servants,
		role = role,
		lives = if role == "invader" then 5 else 0,
		contribution = 0,
		lastHostile = 0,
		killStreak = 0,
		lastKillAt = 0,
		staffReadyAt = 0,
		spellReady = {},
		wardBoostUntil = 0,
		shieldUntil = 0,
		joinTime = os.time(),
		fifthDeathAt = nil,
		onWallBreach = onWallBreach,
		allRecords = records,
	}

	-- DEBUG ONLY (DELETE BEFORE PRODUCTION): Studio test bootstrap.
	if role == "defender" and RunService:IsStudio() and profile.PermanentVaultSouls < 5000 then
		profile.PermanentVaultSouls = 5000;
		(world.session :: any).PermanentVaultSouls = 5000
		warn("[GameService] DEBUG grant: 5,000 Vault Souls (Studio only).")
	end

	-- Anti-combat-log report: theft recorded while the owner was offline.
	if role == "defender" and profile.PendingOfflineTheft > 0 then
		local lost = profile.PendingOfflineTheft
		profile.PendingOfflineTheft = 0
		notify(player, `🌙 While you were gone, raiders stole {lost} Souls from your pot.`, { 255, 120, 80 })
	end

	player.CharacterAdded:Connect(function(character: Model)
		hookCharacter(player, character)
	end)
	if player.Character then
		hookCharacter(player, player.Character)
	end
	if role == "invader" then
		profile.ActiveLoadoutType = "Raider"
		task.spawn(function()
			player:LoadCharacter()
			placeCharacter(player, spawnSpot("InvaderSpawn_"))
		end)
	end

	pushSnapshot(player)
end

local function ownerLeave(player: Player, profile: any): ()
	assert(world.session, "world missing")
	local invadersLeft = false
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local rec = records[other.UserId]
			if rec and rec.role == "invader" then
				invadersLeft = true
				break
			end
		end
	end
	-- Sync shared vault into the owner's profile first.
	profile.PermanentVaultSouls = world.session.PermanentVaultSouls
	if invadersLeft then
		-- 90-second anti-combat-log hold: raiders finish the wall.
		world.ownerGone = true
		world.ownerProfile = profile
		world.holdUntil = os.time() + ANTI_LOG_HOLD_SECONDS
		warn("[GameService] Owner left under attack: 90s hold active.")
	else
		world.session.PermanentVaultSouls += world.session.SessionSoulPot
		world.session.SessionSoulPot = 0
		profile.PermanentVaultSouls = world.session.PermanentVaultSouls
		DataService.ReleaseByUserId(player.UserId)
		if #Players:GetPlayers() == 0 then
			resetWorld()
		end
	end
end

-- -- Remotes --------------------------------------------------------------------

function GameService.Init(): ()
	local remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = Shared

	changedEvent = NetworkRouter.RegisterEvent("EconomyChanged", function() end);
	changedEvent.Parent = remotes;

	wraithSync = NetworkRouter.RegisterEvent("WraithSync", function() end);
	wraithSync.Parent = remotes;

	fifthDeathEvent = NetworkRouter.RegisterEvent("FifthDeath", function() end);
	fifthDeathEvent.Parent = remotes;

	noticeEvent = NetworkRouter.RegisterEvent("Notice", function() end);
	noticeEvent.Parent = remotes;

	local function meOf(player: Player): any?
		return records[player.UserId]
	end

	local function ownerOnly(player: Player): any?
		local me = meOf(player)
		if me and me.role == "defender" and player.UserId == world.ownerUserId and world.session then
			return me
		end
		return nil
	end

	(NetworkRouter.RegisterFunction("EconomySnapshot", function(player: Player)
		local me = meOf(player)
		if not me or not world.session then
			return nil
		end
		local profile = DataService.GetByUserId(player.UserId)
		if not profile then
			return nil
		end
		return buildSnapshot(player, me, profile)
	end) :: RemoteFunction).Parent = remotes;

	-- Buying an elixir. `autoRenew` records the player's intent for the
	-- heartbeat to honour, but the flag is only committed once the purchase
	-- actually succeeds: committing it on failure left the HUD claiming
	-- "auto-renew on" while the server silently stopped renewing.
	(NetworkRouter.RegisterFunction("PurchaseElixir", function(player: Player, wallIndex: number, autoRenew: boolean)
		local me = ownerOnly(player)
		if not me or typeof(wallIndex) ~= "number" or wallIndex < 1 or wallIndex > 3 then
			return false
		end
		local profile = DataService.GetByUserId(player.UserId)
		if not profile then
			return false
		end
		local wall = world.session.Walls[wallIndex]
		local ok = CitadelService.TryPurchaseElixir(world.session, wallIndex, false, os.time())
		if not ok then
			return false
		end
		wall.AutoRenewElixir = autoRenew == true
		-- Persist the toggle; buildWorldFrom reads it back on rejoin.
		local saved = profile.Walls[wallIndex]
		if saved then
			saved.AutoRenewElixir = wall.AutoRenewElixir
		end
		pushAll()
		return true
	end) :: RemoteFunction).Parent = remotes;

	-- Toggle auto-renew WITHOUT buying anything. The old flow forced the
	-- toggle through PurchaseElixir, so flipping the checkbox silently
	-- charged the player an elixir every time.
	(NetworkRouter.RegisterFunction("SetAutoRenew", function(player: Player, wallIndex: number, autoRenew: boolean)
		local me = ownerOnly(player)
		if not me or typeof(wallIndex) ~= "number" or wallIndex < 1 or wallIndex > 3 then
			return false
		end
		local profile = DataService.GetByUserId(player.UserId)
		local wall = world.session.Walls[wallIndex]
		if not profile or not wall or not wall.Unlocked then
			return false
		end
		wall.AutoRenewElixir = autoRenew == true
		local saved = profile.Walls[wallIndex]
		if saved then
			saved.AutoRenewElixir = wall.AutoRenewElixir
		end
		pushAll()
		return true
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("UpgradeWall", function(player: Player, wallIndex: number)
		local me = ownerOnly(player)
		if not me or typeof(wallIndex) ~= "number" or wallIndex < 1 or wallIndex > 3 then
			return false
		end
		if world.session.IsBloodPactActive then
			return false -- Vault sealed during Blood Pact.
		end
		local wall = world.session.Walls[wallIndex]
		if not wall.Unlocked then
			return false
		end
		if wall.PermanentLevel >= AscensionConfig.MaxPermanentLevel then
			return false -- maxed: Ascend instead
		end
		local profile = DataService.GetByUserId(player.UserId)
		if not profile then
			return false
		end
		local cost = math.max(1, math.round(WallConfig[wallIndex].UpgradeCostBase * (WallConfig[wallIndex].UpgradeCostScale ^ wall.PermanentLevel) / STUDIO_DIV))
		if world.session.PermanentVaultSouls < cost then
			return false
		end
		world.session.PermanentVaultSouls -= cost
		wall.PermanentLevel += 1
		-- Persist immediately. Without this the level lived in the session
		-- only, so souls were spent for nothing after a relog and the
		-- Ascension gate (PermanentLevel >= MaxPermanentLevel) could never
		-- be reached again.
		local saved = profile.Walls[wallIndex]
		if saved then
			saved.PermanentDefenseLevel = wall.PermanentLevel
		end
		profile.PermanentVaultSouls = world.session.PermanentVaultSouls
		pushAll()
		return true
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("UnlockWall", function(player: Player, wallIndex: number)
		local me = ownerOnly(player)
		if not me or typeof(wallIndex) ~= "number" or wallIndex < 2 or wallIndex > 3 then
			return false
		end
		if world.session.IsBloodPactActive then
			return false
		end
		local profile = DataService.GetByUserId(player.UserId)
		local wall = world.session.Walls[wallIndex]
		if not profile or wall.Unlocked then
			return false
		end
		local cost = math.max(1, math.round(WallConfig[wallIndex].UnlockCost / STUDIO_DIV))
		if world.session.PermanentVaultSouls < cost then
			return false
		end
		world.session.PermanentVaultSouls -= cost
		wall.Unlocked = true
		wall.CurrentHP = wall.MaxHP
		if profile.Walls[wallIndex] then
			profile.Walls[wallIndex].Unlocked = true
		end
		profile.PermanentVaultSouls = world.session.PermanentVaultSouls
		pushAll()
		return true
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("ToggleBloodPact", function(player: Player, enable: boolean)
		local me = ownerOnly(player)
		if not me or enable ~= true or world.session.IsBloodPactActive then
			return false
		end
		world.session.IsBloodPactActive = true
		world.session.BloodPactLockedUntil = os.time() + BLOOD_PACT_LOCK_SECONDS
		world.session.BloodPactStartedAt = os.time()
		pushAll()
		return true
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("RepairWall", function(player: Player, wallIndex: number)
		local me = ownerOnly(player)
		if not me or typeof(wallIndex) ~= "number" or wallIndex < 1 or wallIndex > 3 then
			return false, 0
		end
		local ok, cost = CitadelService.TryRepairWall(world.session, wallIndex, os.time())
		if ok then
			pushAll()
		end
		return ok, cost
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("BreachDecision", function(player: Player, choice: string)
		local me = ownerOnly(player)
		if not me or not world.session.AwaitingBreachDecision then
			return false
		end
		if choice == "cashout" then
			CitadelService.ExitBloodPactAndBank(world.session)
			InvasionService.Unpublish()
		elseif choice == "hold" then
			world.session.AwaitingBreachDecision = false
		else
			return false
		end
		-- Retire the breach receipt either way. Holding the line keeps the
		-- Blood Pact running, so leaving it armed let a later breach resolve
		-- against the PREVIOUS breach's wall index and stolen amount.
		world.lastBreach = nil
		pushAll()
		return true
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("ClaimGift", function(player: Player, giftIndex: number)
		local me = meOf(player)
		local profile = DataService.GetByUserId(player.UserId)
		if not me or not profile or typeof(giftIndex) ~= "number" then
			return false
		end
		local minutes = GIFT_MINUTES[giftIndex]
		if not minutes or profile.ClaimedPlaytimeGifts[giftIndex] then
			return false
		end
		if os.time() - me.joinTime < minutes * 60 then
			return false
		end
		profile.ClaimedPlaytimeGifts[giftIndex] = true
		profile.BloodShards += GIFT_SHARDS[giftIndex] or 0
		local soulGift = 250 * giftIndex
		if me.role == "defender" and world.session then
			-- Defender truth lives in the session (heartbeat earnings accrue
			-- there); add the gift there and sync back, never overwrite live
			-- earnings with the join-time profile value.
			world.session.PermanentVaultSouls += soulGift
			profile.PermanentVaultSouls = world.session.PermanentVaultSouls
		else
			profile.PermanentVaultSouls += soulGift
		end
		local luck = GIFT_LUCK_SECONDS[giftIndex]
		if luck then
			profile.LuckElixirUntil = math.max(os.time() + luck, profile.LuckElixirUntil or 0)
			notify(player, `🎁 Gift claimed: {GIFT_MINUTES[giftIndex]}m chest + Luck Elixir!`, { 120, 220, 255 })
		else
			notify(player, `🎁 Gift claimed: {GIFT_MINUTES[giftIndex]}m chest!`, { 120, 220, 255 })
		end
		pushSnapshot(player)
		return true
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("FireStaff", function(player: Player, target: Vector3)
		local me = meOf(player)
		if not me or typeof(target) ~= "Vector3" then
			return false
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return false
		end
		local profile = DataService.GetByUserId(player.UserId)
		if not profile then
			return false
		end
		local ok = CombatService.StaffFire(me, profile, player, root.Position, target)
		if ok then
			pushAll()
		end
		return ok
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("CastSpell", function(player: Player, spellId: string, target: Vector3)
		local me = meOf(player)
		if not me or typeof(spellId) ~= "string" or typeof(target) ~= "Vector3" then
			return false
		end
		local character = player.Character
		if not character then
			return false
		end
		local profile = DataService.GetByUserId(player.UserId)
		if not profile then
			return false
		end
		local ok = CombatService.CastSpell(me, profile, player, character, spellId, target)
		if ok then
			pushAll()
		end
		return ok
	end) :: RemoteFunction).Parent = remotes;

	-- Personal purse for invaders (their rolls/upgrades never touch the Vault).
	local function purseFor(_player: Player, me: any, profile: any)
		if me.role == "defender" and world.session then
			return world.session, function()
				profile.PermanentVaultSouls = world.session.PermanentVaultSouls
			end
		end
		local purse = { PermanentVaultSouls = profile.PermanentVaultSouls, IsBloodPactActive = false }
		return purse, function()
			profile.PermanentVaultSouls = purse.PermanentVaultSouls
		end
	end

	(NetworkRouter.RegisterFunction("GrimoireRoll", function(player: Player)
		local me = meOf(player)
		local profile = DataService.GetByUserId(player.UserId)
		if not me or not profile then
			return nil
		end
		local purse, commit = purseFor(player, me, profile)
		local item = GearAndAnvilService.Roll(profile, purse)
		commit()
		pushSnapshot(player)
		return item
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("GrimoireMythicRoll", function(player: Player)
		local me = meOf(player)
		local profile = DataService.GetByUserId(player.UserId)
		if not me or not profile then
			return nil
		end
		local purse, _ = purseFor(player, me, profile)
		local item = GearAndAnvilService.RollMythic(profile, purse)
		pushSnapshot(player)
		return item
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("ReforgeItemCredit", function(player: Player, uid: string)
		local me = meOf(player)
		local profile = DataService.GetByUserId(player.UserId)
		if not me or not profile or typeof(uid) ~= "string" then
			return false
		end
		local ok = GearAndAnvilService.ReforgeCredit(profile, uid)
		if ok then
			pushSnapshot(player)
		end
		return ok
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("ReforgeItem", function(player: Player, uid: string)
		local me = meOf(player)
		local profile = DataService.GetByUserId(player.UserId)
		if not me or not profile or typeof(uid) ~= "string" then
			return false
		end
		local ok = GearAndAnvilService.Reforge(profile, uid)
		if ok then
			pushSnapshot(player)
		end
		return ok
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("ReforgeItemCrowns", function(player: Player, uid: string)
		local me = meOf(player)
		local profile = DataService.GetByUserId(player.UserId)
		if not me or not profile or typeof(uid) ~= "string" then
			return false, "Invalid request."
		end
		local ok, msg = GearAndAnvilService.ReforgeWithCrowns(profile, uid)
		if ok then
			pushSnapshot(player)
		end
		return ok, msg
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("UpgradeItem", function(player: Player, uid: string)
		local me = meOf(player)
		local profile = DataService.GetByUserId(player.UserId)
		if not me or not profile or typeof(uid) ~= "string" then
			return false
		end
		local purse, commit = purseFor(player, me, profile)
		local ok = GearAndAnvilService.Upgrade(profile, purse, uid)
		commit()
		if ok then
			pushSnapshot(player)
		end
		return ok
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("RepairItem", function(player: Player, uid: string)
		local me = meOf(player)
		local profile = DataService.GetByUserId(player.UserId)
		if not me or not profile or typeof(uid) ~= "string" then
			return false
		end
		local ok = GearAndAnvilService.Repair(profile, uid)
		if ok then
			pushSnapshot(player)
		end
		return ok
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("RepairItemCrowns", function(player: Player, uid: string)
		local me = meOf(player)
		local profile = DataService.GetByUserId(player.UserId)
		if not me or not profile or typeof(uid) ~= "string" then
			return false, "Invalid request."
		end
		local ok, msg = GearAndAnvilService.RepairWithCrowns(profile, uid)
		if ok then
			pushSnapshot(player)
		end
		return ok, msg
	end) :: RemoteFunction).Parent = remotes;

	-- 1-click instant Crown spend (blueprint 1.7: 0ms, no Roblox prompt).
	(NetworkRouter.RegisterFunction("SpendCrowns", function(player: Player, catalogKey: string)
		local me = meOf(player)
		local profile = DataService.GetByUserId(player.UserId)
		if not me or not profile or typeof(catalogKey) ~= "string" then
			return false, "Invalid request."
		end
		local ok, msg = GameService.ApplyCrownPurchase(player, profile, catalogKey)
		return ok, msg
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("GetCrownCatalog", function(_player: Player)
		return MonetizationConfig.Catalog
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("SalvageItem", function(player: Player, uid: string)
		local me = meOf(player)
		local profile = DataService.GetByUserId(player.UserId)
		if not me or not profile or typeof(uid) ~= "string" then
			return false
		end
		local ok = GearAndAnvilService.Salvage(profile, uid)
		if ok then
			pushSnapshot(player)
		end
		return ok
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("CycleSlot", function(player: Player, preset: string, slot: string)
		local me = meOf(player)
		local profile = DataService.GetByUserId(player.UserId)
		if not me or not profile or typeof(preset) ~= "string" or typeof(slot) ~= "string" then
			return false
		end
		return GearAndAnvilService.CycleSlot(profile, preset, slot)
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("SwapLoadout", function(player: Player, preset: string)
		local me = meOf(player)
		local profile = DataService.GetByUserId(player.UserId)
		if not me or not profile or typeof(preset) ~= "string" then
			return false
		end
		return GearAndAnvilService.Swap(profile, preset)
	end) :: RemoteFunction).Parent = remotes;

	-- Assign a Q/E/R spell to a loadout preset. Without this there was no way
	-- to change spells at all, so five of the eight SpellConfig entries
	-- (Aegis, MendWard, Witchfire, FrostNova, SiegeBeam) were unreachable
	-- content on a preset the player already owned.
	(NetworkRouter.RegisterFunction("SetSpell", function(player: Player, preset: string, slot: string, spellId: string)
		local me = meOf(player)
		local profile = DataService.GetByUserId(player.UserId)
		if not me or not profile or typeof(preset) ~= "string" or typeof(slot) ~= "string" or typeof(spellId) ~= "string" then
			return false
		end
		local loadout = profile.Loadouts[preset]
		if not loadout then
			return false
		end
		-- Role gate: Bulwark heals your own walls, SiegeBeam melts theirs.
		if spellId == "Bulwark" and me.role ~= "defender" then
			return false
		end
		if spellId == "SiegeBeam" and me.role == "defender" then
			return false
		end
		local field = if slot == "Q" then "SpellQ" elseif slot == "E" then "SpellE" elseif slot == "R" then "SpellR" else nil
		if not field or not SpellConfig[spellId] then
			return false
		end
		loadout[field] = spellId
		pushSnapshot(player)
		return true
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("GetInventory", function(player: Player)
		local me = meOf(player)
		local profile = DataService.GetByUserId(player.UserId)
		if not me or not profile then
			return nil
		end
		return GearAndAnvilService.View(profile)
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("ToggleAutoRoll", function(player: Player, enable: boolean)
		local profile = DataService.GetByUserId(player.UserId)
		if not profile or not profile.HasDualLoadoutPass then
			return false
		end
		profile.AutoRollEnabled = enable == true
		return profile.AutoRollEnabled
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("Ascend", function(player: Player)
		local me = ownerOnly(player)
		if not me then
			return false, "Only the Citadel owner can Ascend."
		end
		local profile = DataService.GetByUserId(player.UserId)
		if not profile then
			return false, ""
		end
		if world.session.IsBloodPactActive then
			return false, "Return to Sanctuary Mode first."
		end
		if profile.AscensionRank >= AscensionConfig.MaxRank then
			return false, "Maximum rank reached."
		end
		for i = 1, 3 do
			local wall = world.session.Walls[i]
			if not wall.Unlocked or wall.PermanentLevel < AscensionConfig.MaxPermanentLevel then
				return false, `Max all 3 walls (Lv {AscensionConfig.MaxPermanentLevel}) first.`
			end
		end
		local newRank = profile.AscensionRank + 1
		local floor = newRank - 1 -- new Rank Floor: never weaker than this
		profile.AscensionRank = newRank
		profile.PermanentVaultSouls = 0
		world.session.AscensionRank = newRank
		world.session.PermanentVaultSouls = 0
		world.session.SessionSoulPot = 0
		for i = 1, 3 do
			local wall = world.session.Walls[i]
			wall.PermanentLevel = floor
			wall.CurrentHP = wall.MaxHP
			wall.IsCollapsedForSession = false
			wall.ElixirExpiresAt = 0
			if profile.Walls[i] then
				profile.Walls[i].PermanentDefenseLevel = floor
			end
		end
		world.lastBreach = nil
		notifyAll(`☄ ASCENSION! The Citadel rises as {AscensionConfig.RankName(newRank)} (+{math.floor(AscensionConfig.SoulStep * 100)}% Souls forever)!`, { 255, 200, 80 })
		pushAll()
		return true, ""
	end) :: RemoteFunction).Parent = remotes;

	-- Milestone 4: raid browser + servants + forfeit.
	(NetworkRouter.RegisterFunction("GetRaidTargets", function(player: Player)
		if not meOf(player) then
			return {}
		end
		return InvasionService.GetTargets()
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("InvadeRealm", function(player: Player, jobId: string)
		if not meOf(player) or typeof(jobId) ~= "string" then
			return false, ""
		end
		return InvasionService.Invade(player, jobId)
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("HireServant", function(player: Player)
		local me = ownerOnly(player)
		if not me then
			return false
		end
		assert(world.session, "world missing")
		if #world.servants >= SERVANT_MAX then
			return false
		end
		if world.session.IsBloodPactActive then
			if world.session.SessionSoulPot < SERVANT_COST then
				return false
			end
			world.session.SessionSoulPot -= SERVANT_COST
		else
			if world.session.PermanentVaultSouls < SERVANT_COST then
				return false
			end
			world.session.PermanentVaultSouls -= SERVANT_COST
		end
		spawnServant()
		notify(player, "👻 Spectral Servant hired! It hunts invaders.", { 170, 130, 255 })
		pushAll()
		return true
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("PlaceTrap", function(player: Player, target: Vector3)
		local me = ownerOnly(player)
		if not me or typeof(target) ~= "Vector3" then
			return false
		end
		assert(world.session, "world missing")
		if #world.traps >= TRAP_MAX then
			return false
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or (target - root.Position).Magnitude > 100 then
			return false
		end
		if Vector2.new(target.X, target.Z).Magnitude > 150 then
			return false -- inside the valley, near the walls
		end
		if world.session.IsBloodPactActive then
			if world.session.SessionSoulPot < TRAP_COST then
				return false
			end
			world.session.SessionSoulPot -= TRAP_COST
		else
			if world.session.PermanentVaultSouls < TRAP_COST then
				return false
			end
			world.session.PermanentVaultSouls -= TRAP_COST
		end
		spawnTrapAt(target)
		notify(player, "🪤 Rune Trap set! Invaders trigger it on approach.", { 255, 120, 140 })
		pushAll()
		return true
	end) :: RemoteFunction).Parent = remotes;

	-- Phase 2: Black Market Auction House (escrow).
	(NetworkRouter.RegisterFunction("AuctionListings", function(player: Player)
		if not meOf(player) then
			return {}
		end
		return AuctionService.GetListings()
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("AuctionList", function(player: Player, itemUID: string, price: number)
		local me = meOf(player)
		local profile = DataService.GetByUserId(player.UserId)
		if not me or not profile or typeof(itemUID) ~= "string" or typeof(price) ~= "number" then
			return false, ""
		end
		local ok, msg = AuctionService.ListItem(profile, player.UserId, itemUID, price)
		if ok then
			pushSnapshot(player)
		end
		return ok, msg
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("AuctionCancel", function(player: Player, listingId: string)
		local me = meOf(player)
		local profile = DataService.GetByUserId(player.UserId)
		if not me or not profile or typeof(listingId) ~= "string" then
			return false, ""
		end
		local ok, msg = AuctionService.CancelListing(profile, player.UserId, listingId)
		if ok then
			pushSnapshot(player)
		end
		return ok, msg
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("AuctionBuy", function(player: Player, listingId: string)
		local me = meOf(player)
		local profile = DataService.GetByUserId(player.UserId)
		if not me or not profile or typeof(listingId) ~= "string" then
			return false, ""
		end
		local ok, msg, sellerId, sellerCut = AuctionService.BuyListing(profile, player.UserId, listingId)
		if ok and sellerId and sellerCut and sellerCut > 0 then
			-- Seller online here: direct credit. Otherwise: offline mailbox.
			local sellerProfile = DataService.GetByUserId(sellerId)
			if sellerProfile then
				sellerProfile.BloodShards += sellerCut
				for _, other in Players:GetPlayers() do
					if other.UserId == sellerId then
						notify(other, `🛒 Your market listing sold! +{sellerCut} Blood Shards (15% tax burned).`, { 255, 190, 60 })
					end
				end
			else
				AuctionService.AddMailboxShards(sellerId, sellerCut)
			end
			pushAll()
		elseif ok then
			pushSnapshot(player)
		end
		return ok, msg
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("ClaimAuctionMailbox", function(player: Player)
		local me = meOf(player)
		local profile = DataService.GetByUserId(player.UserId)
		if not me or not profile then
			return nil
		end
		local shards = AuctionService.ClaimMailboxShards(player.UserId)
		if shards > 0 then
			profile.BloodShards += shards
		end
		local items = AuctionService.ClaimItemReturns(player.UserId)
		local returned = 0
		for _, item in items do
			if item.ItemUID and profile.Inventory[item.ItemUID] == nil then
				profile.Inventory[item.ItemUID] = item
				returned += 1
			end
		end
		pushSnapshot(player)
		return { shards = shards, items = returned }
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("InvaderForfeit", function(player: Player)
		local me = meOf(player)
		if not me or me.role ~= "invader" then
			return false
		end
		forfeit(player)
		return true
	end) :: RemoteFunction).Parent = remotes;

	-- Milestone 4: Sabotage Hex consumables (invader-only Blood Shard sinks).
	(NetworkRouter.RegisterFunction("UseSabotage", function(player: Player, hexId: string, target: Vector3)
		local me = meOf(player)
		local profile = DataService.GetByUserId(player.UserId)
		if not me or not profile or not world.session then
			return false, ""
		end
		if me.role ~= "invader" then
			return false, "Only invaders can cast sabotage hexes."
		end
		if not world.session.IsBloodPactActive then
			return false, "Hexes only work during an active Blood Pact."
		end
		local spec = SabotageConfig.Get(hexId)
		if not spec or typeof(target) ~= "Vector3" then
			return false, ""
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return false, ""
		end
		if (target - root.Position).Magnitude > spec.RangeStuds then
			return false, "Target out of hex range."
		end
		local now = os.clock()
		me.sabotageReady = me.sabotageReady or {}
		if now < (me.sabotageReady[hexId] or 0) then
			return false, "Hex recharging."
		end
		if profile.BloodShards < spec.BloodShardCost then
			return false, `Need {spec.BloodShardCost} Blood Shards.`
		end
		-- Validate the effect BEFORE charging. A failed Soul-Leech used to
		-- still cost 8 Blood Shards and burn the 60s cooldown, because the
		-- debit happened above the branch that could bail out.
		if hexId == "SoulLeech" and world.session.SessionSoulPot <= 0 then
			return false, "The Session Pot is empty."
		end
		profile.BloodShards -= spec.BloodShardCost
		me.sabotageReady[hexId] = now + spec.CooldownSeconds
		me.lastHostile = now -- hexing counts as hostile activity (threat gate)

		if hexId == "WardJam" then
			local duration = spec.DurationSeconds * (1 + (if hasRaiderRing(profile)
				then SabotageConfig.RaiderRingDurationBonus
				else 0))
			world.session.WardJamUntil = math.max(world.session.WardJamUntil or 0, os.time() + math.round(duration))
			me.contribution = (me.contribution or 0) + 50
			notifyAll(`🕯 Ward-Jamming Hex! Obelisks silenced {math.round(duration)}s!`, { 170, 100, 255 })
		elseif hexId == "SoulLeech" then
			local pot = world.session.SessionSoulPot
			local steal = math.clamp(
				math.floor(pot * (spec.StealFraction or 0.05)),
				spec.StealMin or 100,
				spec.StealMax or 25000
			)
			steal = math.min(steal, pot)
			if steal <= 0 then
				-- Defensive: nothing to take, so refund rather than punish.
				profile.BloodShards += spec.BloodShardCost
				return false, "The Session Pot is empty."
			end
			world.session.SessionSoulPot -= steal
			profile.PermanentVaultSouls += steal
			me.contribution = (me.contribution or 0) + math.floor(steal / 50)
			notify(player, `🩸 Soul-Leech siphoned {steal} Souls to your Vault!`, { 255, 80, 100 })
		end
		pushAll()
		return true, ""
	end) :: RemoteFunction).Parent = remotes;

	-- Coven allies: up to 2 invaders may defect to the defender's side.
	(NetworkRouter.RegisterFunction("RequestAlly", function(player: Player)
		local me = meOf(player)
		if not me or not world.session then
			return false, ""
		end
		if me.role ~= "invader" then
			return false, "Only invaders can join the Coven."
		end
		if not world.session.IsBloodPactActive then
			return false, "The Coven only musters during a Blood Pact."
		end
		if allyCount() >= 2 then
			return false, "The Coven is full (2 allies)."
		end
		me.role = "ally"
		me.lives = 0
		me.contribution = 0
		me.fifthDeathAt = nil
		local profile = DataService.GetByUserId(player.UserId)
		if profile then
			profile.ActiveLoadoutType = "Warden"
		end
		notifyAll(`🤝 {player.DisplayName} joined the Coven as an Allied Warden! ({allyCount()}/2)`, { 120, 220, 160 })
		pushAll()
		return true, ""
	end) :: RemoteFunction).Parent = remotes;

	-- -- Lifecycle ------------------------------------------------------------
	for _, player in Players:GetPlayers() do
		task.spawn(setupPlayer, player)
	end
	Players.PlayerAdded:Connect(setupPlayer)

	Players.PlayerRemoving:Connect(function(player: Player)
		local me = records[player.UserId]
		records[player.UserId] = nil
		if not me then
			return
		end
		local profile = DataService.GetByUserId(player.UserId)
		if me.role == "defender" and player.UserId == world.ownerUserId then
			if profile and world.session then
				ownerLeave(player, profile)
			else
				DataService.ReleaseByUserId(player.UserId)
			end
		else
			DataService.ReleaseByUserId(player.UserId)
		end
		if #Players:GetPlayers() == 0 then
			resetWorld()
		end
	end)

	-- 1-second authoritative heartbeat.
	task.spawn(function()
		while true do
			task.wait(1)
			if not world.session then
				continue
			end
			local now = os.time()
			local session = world.session
			local collapsedBefore = {}
			for i = 1, 3 do
				collapsedBefore[i] = session.Walls[i].IsCollapsedForSession
			end
			-- Ascension Rank Floor bonus: permanent soul income per rank.
			local mult = liveMultiplier() * AscensionConfig.SoulMultiplier(session.AscensionRank)
			CitadelService.StepEconomyAndDecay(session, mult, now, distributeLoot)
			-- Wraith simulation (owner profile funds ward-side rewards).
			local ownerProfile = world.ownerUserId and DataService.GetByUserId(world.ownerUserId)
			if ownerProfile then
				local wardDPS = WraithConfig.WardBaseDPS * (1 + CombatService.WardBonus(ownerProfile))
				local ownerRec = world.ownerUserId and records[world.ownerUserId]
				local boosted = ownerRec ~= nil and os.clock() < (ownerRec.wardBoostUntil or 0)
				WraithService.Step(world.wraiths, session, ownerProfile, wardDPS, boosted, 1, onWallBreach)
			end
			stepServants(1)
			stepTraps(now)
			-- Phase 2: expired escrow sweep (60s): items return to sellers.
			if os.clock() - world.lastAuctionSweep >= AUCTION_SWEEP_SECONDS then
				world.lastAuctionSweep = os.clock()
				for _, expired in AuctionService.SweepExpired() do
					local sellerProfile = DataService.GetByUserId(expired.seller)
					if sellerProfile and sellerProfile.Inventory[expired.itemUID] == nil then
						sellerProfile.Inventory[expired.itemUID] = expired.item
						for _, other in Players:GetPlayers() do
							if other.UserId == expired.seller then
								notify(other, "🛒 Market listing expired — item returned to your Grimoire.", { 255, 190, 60 })
							end
						end
					else
						AuctionService.DepositItemReturn(expired.seller, expired.item)
					end
				end
			end
			for i = 1, 3 do
				if session.Walls[i].IsCollapsedForSession and not collapsedBefore[i] then
					-- Blood Pact breaches already announced themselves (and
					-- armed world.lastBreach) inside distributeLoot, which
					-- runs synchronously with the damage. Only Sanctuary
					-- PvE breaches need the deferred notice here.
					if not session.IsBloodPactActive then
						notifyAll(`💥 Wall {i} ({WallConfig[i].Name}) has FALLEN!`, { 255, 60, 70 })
					end
				end
			end
			syncWallVisuals()
			-- Milestone 5: Dual Loadout auto-roll (sanctuary, max 1/min).
			if ownerProfile
				and not session.IsBloodPactActive
				and ownerProfile.HasDualLoadoutPass
				and ownerProfile.AutoRollEnabled
				and os.clock() - world.lastAutoRoll > 60
			then
				world.lastAutoRoll = os.clock()
				GearAndAnvilService.Roll(ownerProfile, session)
			end
			-- Lock expiry + anti-log hold expiry.
			if session.IsBloodPactActive
				and not session.AwaitingBreachDecision
				and now >= session.BloodPactLockedUntil
			then
				CitadelService.ExitBloodPactAndBank(session)
				InvasionService.Unpublish()
			end
			if world.ownerGone and now >= world.holdUntil then
				if world.ownerProfile then
					world.ownerProfile.PermanentVaultSouls += session.SessionSoulPot
					session.SessionSoulPot = 0
					world.ownerProfile.PermanentVaultSouls = session.PermanentVaultSouls
				end
				-- Only release if they are genuinely still gone. If the owner
				-- reconnected during the 90s hold, setupPlayer loaded a live
				-- profile under the same UserId; releasing that kicked them
				-- out of the session they had just rejoined.
				if world.ownerUserId and records[world.ownerUserId] == nil then
					DataService.ReleaseByUserId(world.ownerUserId)
				end
				world.ownerProfile = nil
				world.ownerGone = false
				InvasionService.Unpublish()
				if #Players:GetPlayers() == 0 then
					resetWorld()
				end
			end
			-- Advertise open sieges to the raid browser.
			if session.IsBloodPactActive then
				InvasionService.Advertise({
					pot = session.SessionSoulPot,
					defenderRating = defenderRating(),
					intactWalls = intactCount(),
					isPact = true,
				})
			elseif world.wasPact then
				InvasionService.Unpublish()
			end
			world.wasPact = session.IsBloodPactActive
			for _, player in Players:GetPlayers() do
				pushSnapshot(player)
				if wraithSync then
					wraithSync:FireClient(player, world.wraiths.list)
				end
			end
		end
	end)
end

return GameService
