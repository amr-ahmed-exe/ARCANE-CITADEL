--!strict
-- Arcane Citadel: idempotent grey-box world builder (Milestones 2 + polish).
-- Spec: Part 4.1 -- concentric rings 45/90/140 studs, turret sockets,
-- stations, spawn markers, fog -- plus dark-citadel dressing: ground disc,
-- rune rings, wall torches, braziers, atmosphere + post effects.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local WallConfig = require(game:GetService("ReplicatedStorage").Shared.Configurations.WallConfig)
local MeshConfig = require(game:GetService("ReplicatedStorage").Shared.Configurations.MeshConfig)
local GraphicsConfig = require(game:GetService("ReplicatedStorage").Shared.Configurations.GraphicsConfig)
local MeshLoader = require(script.Parent.MeshLoader)

local WorldBuilder = {}

local STONE = {
	Color3.fromRGB(45, 35, 70),
	Color3.fromRGB(60, 50, 90),
	Color3.fromRGB(75, 65, 105),
}
local ACCENT = Color3.fromRGB(150, 60, 255)
local GOLD = Color3.fromRGB(255, 190, 60)

local function addTag(instance: Instance, tag: string)
	if not CollectionService:HasTag(instance, tag) then
		CollectionService:AddTag(instance, tag)
	end
end

-- Mesh override slot: if the user dropped a model with this name under
-- Workspace/MeshOverrides, the matching primitive builder is skipped.
local function hasOverride(slotName: string): boolean
	local folder = Workspace:FindFirstChild(MeshConfig.OverridesFolder)
	return folder ~= nil and folder:FindFirstChild(slotName) ~= nil
end

local function buildRing(parent: Instance, wallIndex: number): ()
	local spec = WallConfig[wallIndex]
	local r = spec.RadiusStuds
	local h = if wallIndex == 1 then 28 elseif wallIndex == 2 then 24 else 20
	local thickness = 6
	local circumference = 2 * math.pi * r
	local count = math.clamp(math.floor(circumference / 14), 12, 40)
	local segLen = circumference / count + 0.5 -- slight overlap, no gaps

	-- South gate (+Z, toward spawn/portal): a ~16-stud gap so players can
	-- actually walk out. Without this the rings are sealed traps.
	local GATE_ANGLE = math.pi / 2
	local GATE_HALF_STUDS = 8

	local model = Instance.new("Model")
	model.Name = `Wall_{wallIndex}`
	model.Parent = parent

	local function angDist(a: number, b: number): number
		return math.abs((a - b + math.pi * 3) % (math.pi * 2) - math.pi)
	end

	for n = 0, count - 1 do
		local a = (n / count) * math.pi * 2
		if angDist(a, GATE_ANGLE) * r < GATE_HALF_STUDS then
			continue -- gate opening
		end
		local seg = Instance.new("Part")
		seg.Name = `WallSegment_W{wallIndex}_{n + 1}`
		seg.Size = Vector3.new(thickness, h, segLen)
		seg.CFrame = CFrame.new(math.cos(a) * r, h / 2, math.sin(a) * r) * CFrame.Angles(0, -a, 0)
		seg.Anchored = true
		seg.Material = Enum.Material.Cobblestone
		-- Sparse rune veins: every 8th segment glows instead of every 4th.
		seg.Color = if n % 8 == 2 then Color3.fromRGB(110, 60, 180) else STONE[wallIndex]
		if n % 8 == 2 then
			seg.Material = Enum.Material.Neon
		end
		seg.Parent = model
		seg:SetAttribute("WallIndex", wallIndex)
		addTag(seg, "CitadelWall")

		-- Battered footer: flared base ring so walls read as fortresses, not boxes.
		local footer = Instance.new("Part")
		footer.Name = `Footer_W{wallIndex}_{n + 1}`
		footer.Size = Vector3.new(thickness + 3, 3, segLen + 1)
		footer.CFrame = CFrame.new(math.cos(a) * r, 1.5, math.sin(a) * r) * CFrame.Angles(0, -a, 0)
		footer.Anchored = true
		footer.Material = Enum.Material.Cobblestone
		footer.Color = Color3.fromRGB(30, 24, 48)
		footer.Parent = model

		-- Dark cap trim along the top of every segment (reads as a parapet).
		local trim = Instance.new("Part")
		trim.Name = `Trim_W{wallIndex}_{n + 1}`
		trim.Size = Vector3.new(thickness + 0.6, 1.2, segLen + 0.4)
		trim.CFrame = seg.CFrame * CFrame.new(0, h / 2 + 0.6, 0)
		trim.Anchored = true
		trim.Material = Enum.Material.Slate
		trim.Color = Color3.fromRGB(28, 22, 46)
		trim.Parent = model

		-- Witchfire torch every 8th segment.
		if n % 8 == 0 then
			local torch = Instance.new("Part")
			torch.Name = `Torch_W{wallIndex}_{n + 1}`
			torch.Shape = Enum.PartType.Ball
			torch.Size = Vector3.new(2.5, 2.5, 2.5)
			torch.Position = Vector3.new(math.cos(a) * r, h + 1.5, math.sin(a) * r)
			torch.Anchored = true
			torch.CanCollide = false
			torch.Material = Enum.Material.Neon
			torch.Color = Color3.fromRGB(255, 140, 40)
			torch.Parent = model
		end

		-- Crenellations: every 3rd segment gets a merlon cap, alternating
		-- block / wedge so the parapet isn't a copy-paste row.
		if n % 3 == 0 then
			local merlon = Instance.new("Part")
			merlon.Name = `Merlon_W{wallIndex}_{n + 1}`
			merlon.Shape = if (n // 3) % 2 == 0 then Enum.PartType.Wedge else Enum.PartType.Block
			merlon.Size = Vector3.new(thickness + 0.6, 2.4, 3.5)
			merlon.CFrame = seg.CFrame * CFrame.new(0, h / 2 + 2.4, 0)
			merlon.Anchored = true
			merlon.Material = Enum.Material.Cobblestone
			merlon.Color = Color3.fromRGB(50, 40, 75)
			merlon.Parent = model
		end

		-- Energy channel: every 8th trim glows with witchfire veins.
		if n % 8 == 4 then
			trim.Material = Enum.Material.Neon
			trim.Color = Color3.fromRGB(120, 70, 200)
		end
	end

	-- Gate frame: two posts + lintel + rune strip across the top.
	do
		local postH = h + 4
		for _, side in { -1, 1 } do
			local ga = GATE_ANGLE + side * (GATE_HALF_STUDS / r)
			local post = Instance.new("Part")
			post.Name = `GatePost_W{wallIndex}_{side}`
			post.Size = Vector3.new(3, postH, 3)
			post.Position = Vector3.new(math.cos(ga) * r, postH / 2, math.sin(ga) * r)
			post.Anchored = true
			post.Material = Enum.Material.Cobblestone
			post.Color = Color3.fromRGB(40, 32, 62)
			post.Parent = model
			local cap = Instance.new("Part")
			cap.Name = `GateCap_W{wallIndex}_{side}`
			cap.Shape = Enum.PartType.Ball
			cap.Size = Vector3.new(2.5, 2.5, 2.5)
			cap.Position = post.Position + Vector3.new(0, postH / 2 + 1.5, 0)
			cap.Anchored = true
			cap.CanCollide = false
			cap.Material = Enum.Material.Neon
			cap.Color = ACCENT
			cap.Parent = model
		end
		local lintel = Instance.new("Part")
		lintel.Name = `GateLintel_W{wallIndex}`
		lintel.Size = Vector3.new(4, 3, GATE_HALF_STUDS * 2 + 10)
		lintel.CFrame = CFrame.new(math.cos(GATE_ANGLE) * r, h + 3.5, math.sin(GATE_ANGLE) * r)
			* CFrame.Angles(0, -GATE_ANGLE, 0)
		lintel.Anchored = true
		lintel.CanCollide = false
		lintel.Material = Enum.Material.Cobblestone
		lintel.Color = Color3.fromRGB(40, 32, 62)
		lintel.Parent = model

		-- Stepped pediment + crest crowning the gate (no more flat top).
		local ped1 = Instance.new("Part")
		ped1.Name = `GatePediment_W{wallIndex}_1`
		ped1.Size = Vector3.new(5, 1.6, GATE_HALF_STUDS * 2 + 6)
		ped1.CFrame = CFrame.new(math.cos(GATE_ANGLE) * r, h + 5.8, math.sin(GATE_ANGLE) * r)
			* CFrame.Angles(0, -GATE_ANGLE, 0)
		ped1.Anchored = true
		ped1.Material = Enum.Material.Slate
		ped1.Color = Color3.fromRGB(32, 25, 52)
		ped1.Parent = model
		local ped2 = Instance.new("Part")
		ped2.Name = `GatePediment_W{wallIndex}_2`
		ped2.Size = Vector3.new(4, 1.6, GATE_HALF_STUDS * 2 + 2)
		ped2.CFrame = CFrame.new(math.cos(GATE_ANGLE) * r, h + 7.2, math.sin(GATE_ANGLE) * r)
			* CFrame.Angles(0, -GATE_ANGLE, 0)
		ped2.Anchored = true
		ped2.Material = Enum.Material.Cobblestone
		ped2.Color = Color3.fromRGB(45, 36, 68)
		ped2.Parent = model
		local crest = Instance.new("Part")
		crest.Name = `GateCrest_W{wallIndex}`
		crest.Shape = Enum.PartType.Ball
		crest.Size = Vector3.new(2.2, 2.2, 2.2)
		crest.Position = Vector3.new(math.cos(GATE_ANGLE) * r, h + 8.8, math.sin(GATE_ANGLE) * r)
		crest.Anchored = true
		crest.CanCollide = false
		crest.Material = Enum.Material.Neon
		crest.Color = ACCENT
		crest.Parent = model

		-- Gate veil: shimmering barrier marking the breachable entrance.
		local veil = Instance.new("Part")
		veil.Name = `GateVeil_W{wallIndex}`
		veil.Size = Vector3.new(1.5, h - 2, GATE_HALF_STUDS * 2)
		veil.CFrame = CFrame.new(math.cos(GATE_ANGLE) * r, (h - 2) / 2 + 1, math.sin(GATE_ANGLE) * r)
			* CFrame.Angles(0, -GATE_ANGLE, 0)
		veil.Anchored = true
		veil.CanCollide = false
		veil.CanQuery = false
		veil.Transparency = 0.55
		veil.Material = Enum.Material.Neon
		veil.Color = ACCENT
		veil.Parent = model
	end
end

local function buildSockets(parent: Instance, wallIndex: number): ()
	-- Runic Obelisks every 45 degrees (Walls 2 & 3 only): stone base,
	-- rune-banded shaft, hovering ward orb, and a ground rune ring.
	-- The tagged base keeps the designer contract (WardSocket + attributes).
	if wallIndex == 1 then
		return
	end
	local spec = WallConfig[wallIndex]
	local topY = if wallIndex == 2 then 24 else 20
	for s = 0, 7 do
		local a = (s / 8) * math.pi * 2
		local x, z = math.cos(a) * spec.RadiusStuds, math.sin(a) * spec.RadiusStuds
		local base = Instance.new("Part")
		base.Name = `WardSocket_W{wallIndex}_{s + 1}`
		base.Size = Vector3.new(5, 1.5, 5)
		base.Position = Vector3.new(x, topY + 0.75, z)
		base.Anchored = true
		base.Material = Enum.Material.Cobblestone
		base.Color = Color3.fromRGB(35, 28, 55)
		base.Parent = parent
		base:SetAttribute("WallIndex", wallIndex)
		base:SetAttribute("SocketId", s + 1)
		addTag(base, "WardSocket")

		-- Stepped taper: three shrinking tiers read as an obelisk, not a box.
		local tiers = { { 3.0, 2.5 }, { 2.4, 2.5 }, { 1.8, 2.5 } }
		local tierY = topY + 1.5
		for t, tier in tiers do
			local step = Instance.new("Part")
			step.Name = `ObeliskTier_W{wallIndex}_{s + 1}_{t}`
			step.Size = Vector3.new(tier[1], tier[2], tier[1])
			step.Position = Vector3.new(x, tierY + tier[2] / 2, z)
			step.Anchored = true
			step.Material = Enum.Material.Slate
			step.Color = Color3.fromRGB(45, 36, 68)
			step.Parent = parent
			tierY += tier[2]
		end

		local band = Instance.new("Part")
		band.Name = `ObeliskBand_W{wallIndex}_{s + 1}`
		band.Size = Vector3.new(2.5, 1, 2.5)
		band.Position = Vector3.new(x, topY + 6, z)
		band.Anchored = true
		band.CanCollide = false
		band.Material = Enum.Material.Neon
		band.Color = ACCENT
		band.Parent = parent

		local orb = Instance.new("Part")
		orb.Name = `WardOrb_W{wallIndex}_{s + 1}`
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.new(2.4, 2.4, 2.4)
		orb.Position = Vector3.new(x, topY + 11, z)
		orb.Anchored = true
		orb.CanCollide = false
		orb.Material = Enum.Material.Neon
		orb.Color = if wallIndex == 2 then ACCENT else Color3.fromRGB(255, 140, 40)
		orb.Parent = parent

		local ring = Instance.new("Part")
		ring.Name = `WardRing_W{wallIndex}_{s + 1}`
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.3, 7, 7)
		ring.CFrame = CFrame.new(x, topY + 1, z) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Anchored = true
		ring.CanCollide = false
		ring.Transparency = 0.75
		ring.Material = Enum.Material.Neon
		ring.Color = ACCENT
		ring.Parent = parent
	end
end

local function buildStation(parent: Instance, stationType: string, offset: Vector3, color: Color3, size: Vector3): ()
	-- The tagged root keeps its name/attributes (systems depend on it);
	-- decoration parts are untagged dressing around it.
	local part = Instance.new("Part")
	part.Name = stationType
	part.Size = size
	part.Position = Vector3.new(offset.X, size.Y / 2, offset.Z)
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Parent = parent
	part:SetAttribute("StationType", stationType)
	addTag(part, "InteractiveStation")

	local function dress(name: string, dressSize: Vector3, dy: number, dressColor: Color3?, neon: boolean?): BasePart
		local d = Instance.new("Part")
		d.Name = name
		d.Size = dressSize
		d.Position = part.Position + Vector3.new(0, dy, 0)
		d.Anchored = true
		d.CanCollide = false
		d.Material = if neon then Enum.Material.Neon else Enum.Material.Cobblestone
		d.Color = dressColor or Color3.fromRGB(35, 28, 55)
		d.Parent = parent
		return d
	end

	if stationType == "Vault" then
		dress("VaultBase", Vector3.new(9, 1, 9), -size.Y / 2, nil, false)
		local spike = dress("VaultSpike", Vector3.new(2, 5, 2), size.Y / 2 + 2, GOLD, true)
		local glow = Instance.new("PointLight")
		glow.Name = "VaultLight"
		glow.Color = GOLD
		glow.Range = 35
		glow.Brightness = 2
		glow.Shadows = false
		glow.Parent = spike
	elseif stationType == "RitualAltar" then
		local fire = Instance.new("ParticleEmitter")
		fire.Rate = GraphicsConfig.ScaledRate(12)
		fire.Lifetime = NumberRange.new(0.6, 1.2)
		fire.Speed = NumberRange.new(4, 7)
		fire.Size = NumberSequence.new(1.5)
		fire.Color = ColorSequence.new(Color3.fromRGB(255, 80, 60))
		fire.LightEmission = 0.8
		fire.Parent = part
	elseif stationType == "Grimoire" then
		dress("GrimoireBase", Vector3.new(6, 1, 6), -size.Y / 2, nil, false)
		dress("GrimoireBook", Vector3.new(2.5, 0.6, 3.5), size.Y / 2 + 1.5, Color3.fromRGB(70, 140, 255), true)
	elseif stationType == "Anvil" then
		dress("AnvilTop", Vector3.new(5, 1, 2.5), size.Y / 2 + 0.5, Color3.fromRGB(200, 200, 215), false)
	elseif stationType == "RaidPortal" then
		for _, side in { -1, 1 } do
			local pillar = Instance.new("Part")
			pillar.Name = `PortalPillar_{side}`
			pillar.Shape = Enum.PartType.Cylinder
			pillar.Size = Vector3.new(10, 2, 2)
			pillar.CFrame = CFrame.new(offset.X + side * 4, 5, offset.Z) * CFrame.Angles(0, 0, math.pi / 2)
			pillar.Anchored = true
			pillar.Material = Enum.Material.Cobblestone
			pillar.Color = Color3.fromRGB(35, 28, 55)
			pillar.Parent = parent
		end
	end

	-- Station aura dressing: cheap statics + one light on each major hub.
	if stationType == "Vault" then
		for c = 0, 2 do
			local va = (c / 3) * math.pi * 2 + 0.5
			local crystal = Instance.new("Part")
			crystal.Name = `VaultCrystal_{c + 1}`
			crystal.Shape = Enum.PartType.Wedge
			crystal.Size = Vector3.new(1.2, 3 + c, 1.2)
			crystal.CFrame = CFrame.new(offset.X + math.cos(va) * 7, (3 + c) / 2, offset.Z + math.sin(va) * 7)
				* CFrame.Angles(0.2, va, 0.15)
			crystal.Anchored = true
			crystal.CanCollide = false
			crystal.Material = Enum.Material.Neon
			crystal.Color = GOLD
			crystal.Parent = parent
		end
	elseif stationType == "RitualAltar" then
		for s = 0, 7 do
			local sa = (s / 8) * math.pi * 2
			local stone = Instance.new("Part")
			stone.Name = `AltarStone_{s + 1}`
			stone.Size = Vector3.new(1.6, 1.2, 1.6)
			stone.Position = Vector3.new(offset.X + math.cos(sa) * 6.5, 0.6, offset.Z + math.sin(sa) * 6.5)
			stone.Anchored = true
			stone.Material = Enum.Material.Cobblestone
			stone.Color = Color3.fromRGB(45, 25, 35)
			stone.Parent = parent
		end
		local blood = Instance.new("PointLight")
		blood.Name = "AltarLight"
		blood.Color = Color3.fromRGB(220, 40, 60)
		blood.Range = 25
		blood.Brightness = 2
		blood.Shadows = false
		blood.Parent = part
	elseif stationType == "Grimoire" then
		local arcane = Instance.new("PointLight")
		arcane.Name = "GrimoireLight"
		arcane.Color = Color3.fromRGB(70, 140, 255)
		arcane.Range = 25
		arcane.Brightness = 2
		arcane.Shadows = false
		arcane.Parent = part
		for c = 0, 1 do
			local shard = Instance.new("Part")
			shard.Name = `GrimoireShard_{c + 1}`
			shard.Shape = Enum.PartType.Wedge
			shard.Size = Vector3.new(0.9, 2.4, 0.9)
			shard.CFrame = CFrame.new(offset.X + (c * 2 - 1) * 3.4, 3.4, offset.Z)
				* CFrame.Angles(0.25, c * 0.8, -0.2)
			shard.Anchored = true
			shard.CanCollide = false
			shard.Material = Enum.Material.Neon
			shard.Color = Color3.fromRGB(70, 140, 255)
			shard.Parent = parent
		end
	elseif stationType == "Anvil" then
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "AnvilSparks"
		sparks.Rate = GraphicsConfig.ScaledRate(8)
		sparks.Lifetime = NumberRange.new(0.4, 0.9)
		sparks.Speed = NumberRange.new(6, 12)
		sparks.SpreadAngle = Vector2.new(35, 35)
		sparks.Size = NumberSequence.new(0.6)
		sparks.Color = ColorSequence.new(Color3.fromRGB(255, 180, 80))
		sparks.LightEmission = 1
		sparks.Parent = part
	elseif stationType == "RaidPortal" then
		local disc = Instance.new("Part")
		disc.Name = "PortalDisc"
		disc.Shape = Enum.PartType.Ball
		disc.Size = Vector3.new(1.6, 9, 6)
		disc.Position = Vector3.new(offset.X, 5, offset.Z)
		disc.Anchored = true
		disc.CanCollide = false
		disc.CanQuery = false
		disc.Transparency = 0.35
		disc.Material = Enum.Material.Neon
		disc.Color = Color3.fromRGB(150, 60, 255)
		disc.Parent = parent
		local discRing = Instance.new("Part")
		discRing.Name = "PortalBaseRune"
		discRing.Shape = Enum.PartType.Cylinder
		discRing.Size = Vector3.new(0.3, 12, 12)
		discRing.CFrame = CFrame.new(offset.X, 0.2, offset.Z) * CFrame.Angles(0, 0, math.pi / 2)
		discRing.Anchored = true
		discRing.CanCollide = false
		discRing.Transparency = 0.6
		discRing.Material = Enum.Material.Neon
		discRing.Color = Color3.fromRGB(150, 60, 255)
		discRing.Parent = parent
		local mist = Instance.new("PointLight")
		mist.Name = "PortalLight"
		mist.Color = Color3.fromRGB(150, 60, 255)
		mist.Range = 30
		mist.Brightness = 2
		mist.Shadows = false
		mist.Parent = part
		for _, side in { -1, 1 } do
			local finial = Instance.new("Part")
			finial.Name = `PortalFinial_{side}`
			finial.Shape = Enum.PartType.Ball
			finial.Size = Vector3.new(2, 2, 2)
			finial.Position = Vector3.new(offset.X + side * 4, 11, offset.Z)
			finial.Anchored = true
			finial.CanCollide = false
			finial.Material = Enum.Material.Neon
			finial.Color = Color3.fromRGB(150, 60, 255)
			finial.Parent = parent
		end
	end
end

local function buildBraziers(parent: Instance): ()
	for i = 0, 3 do
		local a = (i / 4) * math.pi * 2 + math.pi / 4
		local pole = Instance.new("Part")
		pole.Name = `Brazier_{i + 1}`
		pole.Shape = Enum.PartType.Cylinder
		pole.Size = Vector3.new(6, 1.5, 1.5)
		pole.CFrame = CFrame.new(math.cos(a) * 30, 3, math.sin(a) * 30) * CFrame.Angles(0, 0, math.pi / 2)
		pole.Anchored = true
		pole.Material = Enum.Material.Cobblestone
		pole.Color = Color3.fromRGB(35, 28, 55)
		pole.Parent = parent
		local bowl = Instance.new("Part")
		bowl.Name = `BrazierBowl_{i + 1}`
		bowl.Shape = Enum.PartType.Cylinder
		bowl.Size = Vector3.new(1, 4, 4)
		bowl.Position = pole.Position + Vector3.new(0, 3.5, 0)
		bowl.Anchored = true
		bowl.CanCollide = false
		bowl.Material = Enum.Material.Cobblestone
		bowl.Color = Color3.fromRGB(35, 28, 55)
		bowl.Parent = parent
		local fire = Instance.new("ParticleEmitter")
		fire.Rate = GraphicsConfig.ScaledRate(20)
		fire.Lifetime = NumberRange.new(0.5, 1)
		fire.Speed = NumberRange.new(5, 8)
		fire.Size = NumberSequence.new(2)
		fire.Color = ColorSequence.new(Color3.fromRGB(170, 80, 255))
		fire.LightEmission = 1
		fire.Parent = bowl
		local glow = Instance.new("PointLight")
		glow.Name = "BrazierLight"
		glow.Color = Color3.fromRGB(170, 100, 255)
		glow.Range = 40
		glow.Brightness = 2
		glow.Shadows = false
		glow.Parent = bowl
	end
end

local function buildGround(parent: Instance): ()
	-- Cursed-earth disc + glowing rune ring per wall.
	local disc = Instance.new("Part")
	disc.Name = "CursedGround"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(2, 580, 580)
	disc.Position = Vector3.new(0, -1, 0)
	disc.Anchored = true
	disc.Material = Enum.Material.Slate
	disc.Color = Color3.fromRGB(22, 18, 34)
	disc.Parent = parent

	for i = 1, 3 do
		local spec = WallConfig[i]
		local ring = Instance.new("Part")
		ring.Name = `RuneRing_{i}`
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.2, (spec.RadiusStuds + 5) * 2, (spec.RadiusStuds + 5) * 2)
		ring.Position = Vector3.new(0, 0.15, 0)
		ring.Anchored = true
		ring.CanCollide = false
		ring.Transparency = 0.82 -- subtle glow line, not a glowing wall
		ring.Material = Enum.Material.Neon
		ring.Color = ACCENT
		ring.Parent = parent
	end
end

local function buildPath(parent: Instance): ()
	-- Moonlit causeway from the spawn plaza to the outer gate, with
	-- rune-etched guide slabs and two gate braziers (emissive, no lights).
	for i = 0, 12 do
		local z = 36 + i * 8
		local slab = Instance.new("Part")
		slab.Name = `Causeway_{i + 1}`
		slab.Size = Vector3.new(7, 0.5, 5)
		slab.Position = Vector3.new(0, 0.25, z)
		slab.Anchored = true
		slab.Material = Enum.Material.Slate
		slab.Color = Color3.fromRGB(48, 42, 66)
		slab.Parent = parent
		if i % 3 == 0 then
			local rune = Instance.new("Part")
			rune.Name = `CausewayRune_{i + 1}`
			rune.Size = Vector3.new(7, 0.15, 0.8)
			rune.Position = Vector3.new(0, 0.55, z)
			rune.Anchored = true
			rune.CanCollide = false
			rune.Material = Enum.Material.Neon
			rune.Color = ACCENT
			rune.Parent = parent
		end
	end
	for _, side in { -1, 1 } do
		local pole = Instance.new("Part")
		pole.Name = `GateBrazier_{side}`
		pole.Shape = Enum.PartType.Cylinder
		pole.Size = Vector3.new(6, 1.5, 1.5)
		pole.CFrame = CFrame.new(side * 13, 3, 146) * CFrame.Angles(0, 0, math.pi / 2)
		pole.Anchored = true
		pole.Material = Enum.Material.Cobblestone
		pole.Color = Color3.fromRGB(35, 28, 55)
		pole.Parent = parent
		local bowl = Instance.new("Part")
		bowl.Name = `GateBrazierBowl_{side}`
		bowl.Shape = Enum.PartType.Cylinder
		bowl.Size = Vector3.new(1, 4, 4)
		bowl.Position = pole.Position + Vector3.new(0, 3.5, 0)
		bowl.Anchored = true
		bowl.CanCollide = false
		bowl.Material = Enum.Material.Cobblestone
		bowl.Color = Color3.fromRGB(35, 28, 55)
		bowl.Parent = parent
		local fire = Instance.new("ParticleEmitter")
		fire.Rate = GraphicsConfig.ScaledRate(20)
		fire.Lifetime = NumberRange.new(0.5, 1)
		fire.Speed = NumberRange.new(5, 8)
		fire.Size = NumberSequence.new(2)
		fire.Color = ColorSequence.new(Color3.fromRGB(255, 140, 40))
		fire.LightEmission = 1
		fire.Parent = bowl
	end
end

local function buildCracks(parent: Instance): ()
	-- Glowing soul-cracks + scorch craters across the valley floor.
	for i = 1, 10 do
		local a = math.random() * math.pi * 2
		local r = 60 + math.random() * 120
		local len = 6 + math.random() * 9
		local crack = Instance.new("Part")
		crack.Name = `SoulCrack_{i}`
		crack.Size = Vector3.new(0.5, 0.15, len)
		crack.CFrame = CFrame.new(math.cos(a) * r, 0.1, math.sin(a) * r) * CFrame.Angles(0, math.random() * math.pi, 0)
		crack.Anchored = true
		crack.CanCollide = false
		crack.CanQuery = false
		crack.Material = Enum.Material.Neon
		crack.Color = if i % 2 == 0 then ACCENT else Color3.fromRGB(255, 80, 120)
		crack.Parent = parent
	end
	for i = 1, 5 do
		local a = math.random() * math.pi * 2
		local r = 150 + math.random() * 60
		local crater = Instance.new("Part")
		crater.Name = `Scorch_{i}`
		crater.Shape = Enum.PartType.Cylinder
		crater.Size = Vector3.new(0.3, 10 + i * 2, 10 + i * 2)
		crater.CFrame = CFrame.new(math.cos(a) * r, 0.1, math.sin(a) * r) * CFrame.Angles(0, 0, math.pi / 2)
		crater.Anchored = true
		crater.CanCollide = false
		crater.CanQuery = false
		crater.Material = Enum.Material.Slate
		crater.Color = Color3.fromRGB(12, 10, 18)
		crater.Parent = parent
	end
end

local function buildCore(parent: Instance): ()
	-- Verified heart mesh (if configured) + our light and ground halo.
	local heartTemplate = MeshLoader.Load(MeshConfig.MeshAssets.Heart, MeshConfig.MeshPartCap)
	if heartTemplate then
		local mesh = MeshLoader.PlaceClone(heartTemplate, 16, 0, 0, 0)
		if mesh then
			mesh.Name = "CitadelHeartMesh"
			mesh.Parent = parent
			MeshLoader.AttachLight(mesh, Color3.fromRGB(180, 100, 255), 45)
			local halo = Instance.new("Part")
			halo.Name = "HeartHalo"
			halo.Shape = Enum.PartType.Cylinder
			halo.Size = Vector3.new(0.3, 26, 26)
			halo.CFrame = CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.pi / 2)
			halo.Anchored = true
			halo.CanCollide = false
			halo.CanQuery = false
			halo.Transparency = 0.7
			halo.Material = Enum.Material.Neon
			halo.Color = Color3.fromRGB(150, 60, 255)
			halo.Parent = parent
			return
		end
	end
	-- The Citadel Heart: tiered round pedestal + great soul-crystal.
	-- Round tiers and wedge shards keep the centerpiece organic.
	local tiers = { { 9, 1 }, { 7, 1 }, { 5, 1 } }
	local y = 0
	for t, tier in tiers do
		local step = Instance.new("Part")
		step.Name = `HeartTier_{t}`
		step.Shape = Enum.PartType.Cylinder
		step.Size = Vector3.new(1, tier[1] * 2, tier[1] * 2)
		step.CFrame = CFrame.new(0, y + tier[2] / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		step.Anchored = true
		step.Material = Enum.Material.Slate
		step.Color = Color3.fromRGB(40, 32, 60)
		step.Parent = parent
		y += tier[2]
	end
	local heart = Instance.new("Part")
	heart.Name = "HeartCrystal"
	heart.Shape = Enum.PartType.Wedge
	heart.Size = Vector3.new(4, 11, 4)
	heart.CFrame = CFrame.new(0, y + 5.5, 0) * CFrame.Angles(0, 0.6, 0.08)
	heart.Anchored = true
	heart.CanCollide = false
	heart.Material = Enum.Material.Neon
	heart.Color = Color3.fromRGB(180, 80, 255)
	heart.Parent = parent
	for c = 0, 2 do
		local a = (c / 3) * math.pi * 2 + 0.9
		local shard = Instance.new("Part")
		shard.Name = `HeartShard_{c + 1}`
		shard.Shape = Enum.PartType.Wedge
		shard.Size = Vector3.new(1.6, 4.5 + c, 1.6)
		shard.CFrame = CFrame.new(math.cos(a) * 6, y + 2, math.sin(a) * 6) * CFrame.Angles(0.15, a, -0.12)
		shard.Anchored = true
		shard.CanCollide = false
		shard.Material = Enum.Material.Neon
		shard.Color = if c == 1 then GOLD else Color3.fromRGB(150, 60, 255)
		shard.Parent = parent
	end
	local halo = Instance.new("Part")
	halo.Name = "HeartHalo"
	halo.Shape = Enum.PartType.Cylinder
	halo.Size = Vector3.new(0.3, 26, 26)
	halo.CFrame = CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.pi / 2)
	halo.Anchored = true
	halo.CanCollide = false
	halo.CanQuery = false
	halo.Transparency = 0.7
	halo.Material = Enum.Material.Neon
	halo.Color = Color3.fromRGB(150, 60, 255)
	halo.Parent = parent
	local glow = Instance.new("PointLight")
	glow.Name = "HeartLight"
	glow.Color = Color3.fromRGB(180, 100, 255)
	glow.Range = 45
	glow.Brightness = 2
	glow.Shadows = false
	glow.Parent = heart
	local rise = Instance.new("ParticleEmitter")
	rise.Name = "HeartRise"
	rise.Rate = GraphicsConfig.ScaledRate(16)
	rise.Lifetime = NumberRange.new(1, 2)
	rise.Speed = NumberRange.new(4, 7)
	rise.Size = NumberSequence.new(1.2)
	rise.Color = ColorSequence.new(Color3.fromRGB(190, 120, 255))
	rise.LightEmission = 1
	rise.Parent = heart
end

local function buildTowers(parent: Instance): ()
	-- 4 watchtowers on the outer ring (dressing; fighting happens at sockets).
	local towerTemplate = MeshLoader.Load(MeshConfig.MeshAssets.Tower, MeshConfig.MeshPartCap)
	for i = 0, 3 do
		local a = (i / 4) * math.pi * 2 + math.pi / 4
		local x, z = math.cos(a) * 140, math.sin(a) * 140
		if towerTemplate then
			local mesh = MeshLoader.PlaceClone(towerTemplate, 34, x, z, -a)
			if mesh then
				mesh.Name = `Watchtower_{i + 1}`
				mesh.Parent = parent
				continue
			end
		end
		local tower = Instance.new("Model")
		tower.Name = `Watchtower_{i + 1}`
		tower.Parent = parent
		local function tpart(name: string, size: Vector3, y: number, mat: Enum.Material, color: Color3)
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size
			p.Position = Vector3.new(x, y, z)
			p.Anchored = true
			p.Material = mat
			p.Color = color
			p.Parent = tower
			return p
		end
		tpart("Shaft", Vector3.new(10, 26, 10), 13, Enum.Material.Cobblestone, Color3.fromRGB(55, 45, 80))
		tpart("Crown", Vector3.new(13, 3, 13), 27.5, Enum.Material.Cobblestone, Color3.fromRGB(45, 36, 68))
		tpart("Spire1", Vector3.new(9, 3, 9), 30.5, Enum.Material.Cobblestone, Color3.fromRGB(40, 32, 60))
		tpart("Spire2", Vector3.new(5, 3, 5), 33.5, Enum.Material.Cobblestone, Color3.fromRGB(40, 32, 60))
		local eye = tpart("Eye", Vector3.new(3, 3, 3), 24, Enum.Material.Neon, Color3.fromRGB(255, 140, 40))
		eye.Shape = Enum.PartType.Ball
		-- Lamplit window slits climbing the outward face.
		for w = 0, 2 do
			local wy = 10 + w * 6
			local win = Instance.new("Part")
			win.Name = `Window_{i + 1}_{w + 1}`
			win.Size = Vector3.new(0.6, 2.2, 1.8)
			win.CFrame = CFrame.new(x + math.cos(a) * 5.2, wy, z + math.sin(a) * 5.2) * CFrame.Angles(0, -a, 0)
			win.Anchored = true
			win.CanCollide = false
			win.Material = Enum.Material.Neon
			win.Color = Color3.fromRGB(255, 170, 60)
			win.Parent = tower
		end
		-- Beacon orb + witchfire crown so towers read from across the valley.
		local beacon = Instance.new("Part")
		beacon.Name = `Beacon_{i + 1}`
		beacon.Shape = Enum.PartType.Ball
		beacon.Size = Vector3.new(2.2, 2.2, 2.2)
		beacon.Position = Vector3.new(x, 36, z)
		beacon.Anchored = true
		beacon.CanCollide = false
		beacon.Material = Enum.Material.Neon
		beacon.Color = Color3.fromRGB(255, 140, 40)
		beacon.Parent = tower
		local flame = Instance.new("ParticleEmitter")
		flame.Name = "BeaconFire"
		flame.Rate = GraphicsConfig.ScaledRate(14)
		flame.Lifetime = NumberRange.new(0.5, 1)
		flame.Speed = NumberRange.new(4, 7)
		flame.Size = NumberSequence.new(1.6)
		flame.Color = ColorSequence.new(Color3.fromRGB(255, 150, 60))
		flame.LightEmission = 1
		flame.Parent = beacon
	end
end

local function buildWoods(parent: Instance): ()
	-- Dead trees + crystals + rocks: deterministic layout, same every server.
	math.randomseed(1337)
	local woods = Instance.new("Model")
	woods.Name = "CursedWoods"
	woods.Parent = parent
	-- One verified mesh download, cloned into a varied forest. Any single
	-- failure falls back to primitives so the ring is always full.
	local treeTemplate = MeshLoader.Load(MeshConfig.MeshAssets.DeadTree, MeshConfig.MeshPartCap)
	for i = 1, 45 do
		local a = math.random() * math.pi * 2
		local r = GraphicsConfig.WoodsRadiusMin + math.random() * GraphicsConfig.WoodsRadiusSpan
		local x, z = math.cos(a) * r, math.sin(a) * r
		if treeTemplate then
			local mesh = MeshLoader.PlaceClone(treeTemplate, 12 + math.random() * 6, x, z, math.random() * math.pi * 2)
			if mesh then
				mesh.Name = `DeadTree_{i}`
				mesh.Parent = woods
				continue
			end
		end
		local h = 10 + math.random() * 8
		local trunk = Instance.new("Part")
		trunk.Name = `DeadTree_{i}`
		trunk.Shape = Enum.PartType.Cylinder
		trunk.Size = Vector3.new(h, 2.6, 2.6)
		trunk.CFrame = CFrame.new(x, h / 2, z) * CFrame.Angles(0, 0, math.pi / 2)
		trunk.Anchored = true
		trunk.Material = Enum.Material.Wood
		trunk.Color = Color3.fromRGB(35, 25, 30)
		trunk.Parent = woods
		for b = 1, 2 do
			local ba = math.random() * math.pi * 2
			local bl = 3 + math.random() * 3
			local branch = Instance.new("Part")
			branch.Name = `Branch_{i}_{b}`
			branch.Shape = Enum.PartType.Cylinder
			branch.Size = Vector3.new(bl, 1.1, 1.1)
			branch.CFrame = CFrame.new(x, h * (0.55 + b * 0.12), z) * CFrame.Angles(0, ba, 1.0)
			branch.Anchored = true
			branch.CanCollide = false
			branch.Material = Enum.Material.Wood
			branch.Color = Color3.fromRGB(40, 28, 32)
			branch.Parent = woods
		end
		for b = 1, 2 do
			local crown = Instance.new("Part")
			crown.Name = `Crown_{i}_{b}`
			crown.Shape = Enum.PartType.Ball
			local s = 3 + math.random() * 3
			crown.Size = Vector3.new(s, s, s)
			crown.Position = Vector3.new(x + (math.random() - 0.5) * 4, h + b * 2, z + (math.random() - 0.5) * 4)
			crown.Anchored = true
			crown.CanCollide = false
			crown.Material = Enum.Material.Grass
			crown.Color = Color3.fromRGB(45, 20, 70)
			crown.Parent = woods
		end
	end
	for i = 1, 20 do
		local a = math.random() * math.pi * 2
		local r = 100 + math.random() * 120
		local cluster = 2 + math.floor(math.random() * 2)
		for c = 1, cluster do
			local h = 3 + math.random() * 6
			local crystal = Instance.new("Part")
			crystal.Name = `Crystal_{i}_{c}`
			crystal.Size = Vector3.new(1.2, h, 1.2)
			crystal.CFrame = CFrame.new(
				math.cos(a) * r + (math.random() - 0.5) * 6,
				h / 2,
				math.sin(a) * r + (math.random() - 0.5) * 6
			) * CFrame.Angles((math.random() - 0.5) * 0.5, math.random() * 3, (math.random() - 0.5) * 0.5)
			crystal.Anchored = true
			crystal.CanCollide = false
			crystal.Material = Enum.Material.Neon
			crystal.Color = if i % 2 == 0 then Color3.fromRGB(150, 60, 255) else Color3.fromRGB(80, 220, 255)
			crystal.Parent = woods
		end
	end
	for i = 1, 30 do
		local a = math.random() * math.pi * 2
		local r = 160 + math.random() * 110
		local s = 1.5 + math.random() * 3
		local rock = Instance.new("Part")
		rock.Name = `Rock_{i}`
		rock.Shape = Enum.PartType.Ball
		rock.Size = Vector3.new(s, s * 0.7, s)
		rock.Position = Vector3.new(math.cos(a) * r, s * 0.3, math.sin(a) * r)
		rock.Anchored = true
		rock.Material = Enum.Material.Slate
		rock.Color = Color3.fromRGB(40, 36, 52)
		rock.Parent = woods
	end
end

local function buildBattlements(parent: Instance): ()
	-- Crenellations on the home wall (Wall 1) + war banners.
	local wall1 = parent:FindFirstChild("Wall_1")
	if not wall1 then
		return
	end
	for _, seg in wall1:GetChildren() do
		if seg:IsA("BasePart") then
			local n = tonumber(string.match(seg.Name, "(%d+)$") or "0")
			if n % 3 == 0 then
				local merlon = Instance.new("Part")
				merlon.Name = `Merlon_{n}`
				merlon.Size = Vector3.new(6, 3, 4)
				merlon.CFrame = seg.CFrame * CFrame.new(0, seg.Size.Y / 2 + 1.5, 0)
				merlon.Anchored = true
				merlon.Material = Enum.Material.Cobblestone
				merlon.Color = Color3.fromRGB(50, 40, 75)
				merlon.Parent = wall1
			end
		end
	end
	for i = 0, 3 do
		local a = (i / 4) * math.pi * 2
		local banner = Instance.new("Part")
		banner.Name = `Banner_{i + 1}`
		banner.Size = Vector3.new(0.5, 8, 4)
		banner.Position = Vector3.new(math.cos(a) * 44, 24, math.sin(a) * 44)
		banner.Anchored = true
		banner.CanCollide = false
		banner.Material = Enum.Material.Neon
		banner.Color = Color3.fromRGB(200, 30, 60)
		banner.Parent = wall1
	end
end

local function buildSpawns(parent: Instance): ()
	local wraithFolder = Instance.new("Folder")
	wraithFolder.Name = "WraithSpawnNodes"
	wraithFolder.Parent = parent
	for i = 0, 11 do
		local a = (i / 12) * math.pi * 2
		local r = 200 + ((i * 37) % 60) -- deterministic spread 200..260
		local node = Instance.new("Part")
		node.Name = `WraithSpawn_{i + 1}`
		node.Shape = Enum.PartType.Cylinder
		node.Size = Vector3.new(0.4, 8, 8)
		node.Position = Vector3.new(math.cos(a) * r, 0.3, math.sin(a) * r)
		node.Anchored = true
		node.CanCollide = false
		node.Transparency = 0.5
		node.Material = Enum.Material.Neon
		node.Color = Color3.fromRGB(60, 255, 150)
		node.Parent = wraithFolder
	end

	local invaderFolder = Instance.new("Folder")
	invaderFolder.Name = "InvaderSpawnPads"
	invaderFolder.Parent = parent
	for i = 0, 5 do
		local a = (i / 6) * math.pi * 2 + 0.3
		local pad = Instance.new("Part")
		pad.Name = `InvaderSpawn_{i + 1}`
		pad.Shape = Enum.PartType.Cylinder
		pad.Size = Vector3.new(0.4, 9, 9)
		pad.Position = Vector3.new(math.cos(a) * 215, 0.3, math.sin(a) * 215)
		pad.Anchored = true
		pad.CanCollide = false
		pad.Transparency = 0.5
		pad.Material = Enum.Material.Neon
		pad.Color = Color3.fromRGB(255, 50, 60)
		pad.Parent = invaderFolder
		-- Jagged obsidian teeth ringing each landing pad.
		for t = 0, 3 do
			local ta = (t / 4) * math.pi * 2 + (i * 0.4)
			local fang = Instance.new("Part")
			fang.Name = `PadFang_{i + 1}_{t + 1}`
			fang.Shape = Enum.PartType.Wedge
			fang.Size = Vector3.new(1.4, 2.6, 1.4)
			fang.CFrame = CFrame.new(math.cos(a) * 215 + math.cos(ta) * 6.5, 1.3, math.sin(a) * 215 + math.sin(ta) * 6.5)
				* CFrame.Angles(0, ta, 0)
			fang.Anchored = true
			fang.CanCollide = false
			fang.Material = Enum.Material.Slate
			fang.Color = Color3.fromRGB(25, 18, 32)
			fang.Parent = parent
		end
	end
end

local function buildAtmosphere(): ()
	if not Lighting:FindFirstChild("CitadelAtmosphere") then
		local atmo = Instance.new("Atmosphere")
		atmo.Name = "CitadelAtmosphere"
		atmo.Density = 0.45
		atmo.Offset = 0.2
		atmo.Color = Color3.fromRGB(60, 40, 110)
		atmo.Decay = Color3.fromRGB(30, 15, 60)
		atmo.Parent = Lighting
	end
	if not Lighting:FindFirstChild("CitadelBloom") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "CitadelBloom"
		bloom.Intensity = 0.5
		bloom.Size = 24
		bloom.Threshold = 1.1
		bloom.Parent = Lighting
	end
	if not Lighting:FindFirstChild("CitadelGrade") then
		local grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "CitadelGrade"
		grade.TintColor = Color3.fromRGB(235, 220, 255)
		grade.Contrast = 0.08
		grade.Saturation = 0.15
		grade.Parent = Lighting
	end
	if not Lighting:FindFirstChild("CitadelRays") then
		local rays = Instance.new("SunRaysEffect")
		rays.Name = "CitadelRays"
		rays.Intensity = 0.06
		rays.Spread = 0.5
		rays.Parent = Lighting
	end
end

function WorldBuilder.Build(): Model
	local existing = Workspace:FindFirstChild("Citadel")
	if existing and existing:IsA("Model") then
		buildAtmosphere()
		return existing
	end

	local citadel = Instance.new("Model")
	citadel.Name = "Citadel"
	citadel.Parent = Workspace

	buildGround(citadel)
	buildPath(citadel)
	buildCracks(citadel)
	for i = 1, 3 do
		buildRing(citadel, i)
		buildSockets(citadel, i)
	end
	buildBattlements(citadel)
	if not hasOverride(MeshConfig.Slots.Towers) then
		buildTowers(citadel)
	end

	-- Inner Sanctum stations (2x2 grid around the core).
	buildStation(citadel, "Vault", Vector3.new(-8, 0, -8), GOLD, Vector3.new(5, 7, 5))
	buildStation(citadel, "RitualAltar", Vector3.new(8, 0, -8), Color3.fromRGB(200, 30, 50), Vector3.new(6, 2, 6))
	buildStation(citadel, "Grimoire", Vector3.new(-8, 0, 8), Color3.fromRGB(70, 140, 255), Vector3.new(4, 5, 4))
	buildStation(citadel, "Anvil", Vector3.new(8, 0, 8), Color3.fromRGB(160, 160, 175), Vector3.new(4, 3, 4))
	if not hasOverride(MeshConfig.Slots.Portal) then
		local portalTemplate = MeshLoader.Load(MeshConfig.MeshAssets.Portal, MeshConfig.MeshPartCap)
		local portalMesh = if portalTemplate then MeshLoader.PlaceClone(portalTemplate, 10, 0, 22, 0) else nil
		if portalMesh then
			portalMesh.Name = "RaidPortalMesh"
			portalMesh.Parent = citadel
			MeshLoader.AttachLight(portalMesh, Color3.fromRGB(150, 60, 255), 30)
		else
			buildStation(citadel, "RaidPortal", Vector3.new(0, 0, 22), Color3.fromRGB(150, 60, 255), Vector3.new(6, 8, 2))
		end
	end
	if not hasOverride(MeshConfig.Slots.Heart) then
		buildCore(citadel)
	end
	buildBraziers(citadel)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CitadelSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	-- Face the Citadel core on spawn instead of the portal.
	spawn.CFrame = CFrame.new(Vector3.new(0, 0.5, 32), Vector3.new(0, 4, 0))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = Color3.fromRGB(30, 25, 45)
	spawn.Parent = citadel

	buildSpawns(citadel)
	if not hasOverride(MeshConfig.Slots.Woods) then
		buildWoods(citadel)
	end

	-- Cursed Valley atmosphere: night mood, but readable (not pitch black).
	Lighting.FogEnd = GraphicsConfig.FogEnd
	Lighting.FogStart = GraphicsConfig.FogStart
	Lighting.FogColor = Color3.fromRGB(25, 15, 40)
	Lighting.ClockTime = 0
	Lighting.Ambient = Color3.fromRGB(95, 85, 135)
	Lighting.OutdoorAmbient = Color3.fromRGB(95, 85, 135)
	Lighting.Brightness = 3
	buildAtmosphere()

	return citadel
end

return WorldBuilder
