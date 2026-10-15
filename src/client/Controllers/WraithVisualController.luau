--!strict
-- Arcane Citadel: client-side wraith renderer (Milestone 3).
-- Server replicates compact {id, type, angle, radius, hp} arrays at 1 Hz;
-- we CFrame:Lerp + sine-wave bob every frame. No Humanoids, no physics.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WraithConfig = require(Shared.Configurations.WraithConfig)
local GraphicsConfig = require(Shared.Configurations.GraphicsConfig)

local WraithVisualController = {}

local APPEARANCE = {
	-- Hover heights clear the tallest rampart (Wall 1 = 28 studs) so the
	-- host glides OVER the walls instead of clipping through them.
	Wisp = { size = 3, color = Color3.fromRGB(120, 255, 170), hover = 30 },
	Banshee = { size = 4, color = Color3.fromRGB(120, 220, 255), hover = 32 },
	Revenant = { size = 5.5, color = Color3.fromRGB(255, 150, 60), hover = 30 },
	Lich = { size = 8, color = Color3.fromRGB(220, 40, 80), hover = 34 },
}
local CORE_COLOR = Color3.fromRGB(18, 10, 32) -- dark soul core inside each shell

local parts: { [number]: { shell: BasePart, core: BasePart, halo: BasePart, eyeL: BasePart, eyeR: BasePart, mouth: BasePart } } = {}
local latest: { [number]: any } = {}
local flashedUntil: { [number]: number } = {}
local folder: Folder? = nil

local function targetCFrame(entry: any, now: number): CFrame
	local spec = WraithConfig.Specs[entry.wraithType]
	local look = APPEARANCE[entry.wraithType] or APPEARANCE.Wisp
	local amp = if spec then spec.BobAmplitude else 1.5
	local freq = if spec then spec.BobFrequency else 1.0
	local x = math.cos(entry.angle) * entry.radius
	local z = math.sin(entry.angle) * entry.radius
	local y = look.hover + math.sin(now * math.pi * 2 * freq) * amp
	return CFrame.new(x, y, z)
end

-- Cosmetic hit flash around an impact point (called on every staff click).
-- Flat XZ check: wraiths render high above the ramparts, so height is ignored.
function WraithVisualController.FlashAt(center: Vector3, radius: number): ()
	local now = os.clock()
	for id, _ in parts do
		local entry = latest[id]
		if entry then
			local dx = math.cos(entry.angle) * entry.radius - center.X
			local dz = math.sin(entry.angle) * entry.radius - center.Z
			if dx * dx + dz * dz <= radius * radius then
				flashedUntil[id] = now + 0.12
			end
		end
	end
end

local function popFx(cf: CFrame, size: number, color: Color3): ()
	if not folder then
		return
	end
	local pop = Instance.new("Part")
	pop.Name = "WraithPopFX"
	pop.Shape = Enum.PartType.Ball
	pop.Size = Vector3.new(size, size, size)
	pop.CFrame = cf
	pop.Anchored = true
	pop.CanCollide = false
	pop.CanQuery = false
	pop.Transparency = 0.3
	pop.Material = Enum.Material.Neon
	pop.Color = color
	pop.Parent = folder
	task.spawn(function()
		for _ = 0, 1, 0.1 do
			task.wait(0.03)
			if pop.Parent then
				pop.Size += Vector3.new(size * 0.25, size * 0.25, size * 0.25)
				pop.Transparency = math.min(1, pop.Transparency + 0.08)
			end
		end
		pop:Destroy()
	end)
	-- Ground shockwave ring + white soul flash rising from the kill.
	local ring = Instance.new("Part")
	ring.Name = "WraithRingFX"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, size * 1.5, size * 1.5)
	ring.CFrame = CFrame.new(cf.X, 0.6, cf.Z) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Transparency = 0.4
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Parent = folder
	TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, size * 4.5, size * 4.5),
		Transparency = 1,
	}):Play()
	task.delay(0.45, function()
		if ring.Parent then
			ring:Destroy()
		end
	end)
	local soul = Instance.new("Part")
	soul.Name = "WraithSoulFX"
	soul.Shape = Enum.PartType.Ball
	soul.Size = Vector3.new(size * 0.5, size * 0.5, size * 0.5)
	soul.CFrame = cf
	soul.Anchored = true
	soul.CanCollide = false
	soul.CanQuery = false
	soul.Transparency = 0.1
	soul.Material = Enum.Material.Neon
	soul.Color = Color3.fromRGB(255, 255, 255)
	soul.Parent = folder
	TweenService:Create(soul, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = cf + Vector3.new(0, 6, 0),
		Transparency = 1,
	}):Play()
	task.delay(0.4, function()
		if soul.Parent then
			soul:Destroy()
		end
	end)
end

function WraithVisualController.Init(): ()
	folder = Workspace:FindFirstChild("Wraiths") :: Folder?
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Wraiths"
		folder.Parent = Workspace
	end

	local event = Shared:WaitForChild("Remotes"):WaitForChild("WraithSync") :: RemoteEvent
	event.OnClientEvent:Connect(function(list: any)
		local seen: { [number]: boolean } = {}
		if typeof(list) == "table" then
			for _, entry in list do
				if typeof(entry) == "table" and typeof(entry.id) == "number" then
					seen[entry.id] = true
					latest[entry.id] = entry
					if not parts[entry.id] then
						local look = APPEARANCE[entry.wraithType] or APPEARANCE.Wisp
						local cs = look.size * 0.5
						local haloSize = look.size * 1.9
						local shell = Instance.new("Part")
						shell.Name = `Wraith_{entry.id}`
						shell.Shape = Enum.PartType.Ball
						shell.Size = Vector3.new(0.5, 0.5, 0.5)
						shell.Material = Enum.Material.Neon
						shell.Color = look.color
						shell.Transparency = 0.35
						shell.Anchored = true
						shell.CanCollide = false
						shell.CanQuery = false
						shell.CFrame = targetCFrame(entry, os.clock())
						shell.Parent = folder
						local core = Instance.new("Part")
						core.Name = `WraithCore_{entry.id}`
						core.Shape = Enum.PartType.Ball
						core.Size = Vector3.new(0.2, 0.2, 0.2)
						core.Material = Enum.Material.SmoothPlastic
						core.Color = CORE_COLOR
						core.Anchored = true
						core.CanCollide = false
						core.CanQuery = false
						core.CFrame = shell.CFrame
						core.Parent = folder
						local halo = Instance.new("Part")
						halo.Name = `WraithHalo_{entry.id}`
						halo.Shape = Enum.PartType.Ball
						halo.Size = Vector3.new(0.5, 0.5, 0.5)
						halo.Material = Enum.Material.Neon
						halo.Color = look.color
						halo.Transparency = 0.85
						halo.Anchored = true
						halo.CanCollide = false
						halo.CanQuery = false
						halo.CFrame = shell.CFrame
						halo.Parent = folder
						-- Face: two burning eyes + a dark maw, always aimed
						-- at the citadel (the direction of travel).
						local eyeSize = look.size * 0.24
						local eyeL = Instance.new("Part")
						eyeL.Name = `WraithEyeL_{entry.id}`
						eyeL.Shape = Enum.PartType.Ball
						eyeL.Size = Vector3.new(0.2, 0.2, 0.2)
						eyeL.Material = Enum.Material.Neon
						eyeL.Color = Color3.fromRGB(255, 255, 255)
						eyeL.Anchored = true
						eyeL.CanCollide = false
						eyeL.CanQuery = false
						eyeL.CFrame = shell.CFrame
						eyeL.Parent = folder
						local eyeR = eyeL:Clone()
						eyeR.Name = `WraithEyeR_{entry.id}`
						eyeR.Parent = folder
						local mouth = Instance.new("Part")
						mouth.Name = `WraithMaw_{entry.id}`
						mouth.Size = Vector3.new(0.2, 0.2, 0.2)
						mouth.Material = Enum.Material.SmoothPlastic
						mouth.Color = Color3.fromRGB(25, 5, 15)
						mouth.Anchored = true
						mouth.CanCollide = false
						mouth.CanQuery = false
						mouth.CFrame = shell.CFrame
						mouth.Parent = folder
						-- Boss presence: Liches carry their own dread-light.
						if entry.wraithType == "Lich" then
							local dread = Instance.new("PointLight")
							dread.Name = "LichDread"
							dread.Color = Color3.fromRGB(220, 40, 80)
							dread.Range = 24
							dread.Brightness = 2
							dread.Shadows = false
							dread.Parent = shell
						end
						parts[entry.id] = { shell = shell, core = core, halo = halo, eyeL = eyeL, eyeR = eyeR, mouth = mouth }
						-- Materialize-in: grow from a spark instead of popping.
						local grow = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
						TweenService:Create(shell, grow, { Size = Vector3.new(look.size, look.size, look.size) }):Play()
						TweenService:Create(core, grow, { Size = Vector3.new(cs, cs, cs) }):Play()
						TweenService:Create(halo, grow, { Size = Vector3.new(haloSize, haloSize, haloSize) }):Play()
						TweenService:Create(eyeL, grow, { Size = Vector3.new(eyeSize, eyeSize, eyeSize) }):Play()
						TweenService:Create(eyeR, grow, { Size = Vector3.new(eyeSize, eyeSize, eyeSize) }):Play()
						TweenService:Create(mouth, grow, {
							Size = Vector3.new(look.size * 0.5, look.size * 0.14, 0.3),
						}):Play()
					end
				end
			end
		end
		for id, pair in parts do
			if not seen[id] then
				latest[id] = nil
				flashedUntil[id] = nil
				parts[id] = nil
				popFx(pair.shell.CFrame, pair.shell.Size.X, pair.shell.Color)
				pair.shell:Destroy()
				pair.core:Destroy()
				pair.halo:Destroy()
				pair.eyeL:Destroy()
				pair.eyeR:Destroy()
				pair.mouth:Destroy()
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local camera = Workspace.CurrentCamera
		local camPos = if camera then camera.CFrame.Position else Vector3.zero
		local cullDist = GraphicsConfig.WraithCullDistance
		local cullSq = cullDist * cullDist
		for id, pair in parts do
			local entry = latest[id]
			if entry then
				-- Distance culling: far wraiths hold their last pose.
				local wx = math.cos(entry.angle) * entry.radius
				local wz = math.sin(entry.angle) * entry.radius
				local dx, dz = wx - camPos.X, wz - camPos.Z
				if dx * dx + dz * dz > cullSq then
					continue
				end
				local cf = targetCFrame(entry, now)
				pair.shell.CFrame = pair.shell.CFrame:Lerp(cf, 0.2)
				pair.core.CFrame = pair.shell.CFrame
				pair.halo.CFrame = pair.shell.CFrame
				local flashed = (flashedUntil[id] or 0) > now
				pair.shell.Transparency = if flashed then 0 else 0.35
				pair.halo.Transparency = if flashed then 0.45 else 0.85
				-- Face tracks the march direction (inward, toward the walls).
				local look = APPEARANCE[entry.wraithType] or APPEARANCE.Wisp
				local dirX, dirZ = math.cos(entry.angle), math.sin(entry.angle)
				local center = pair.shell.CFrame.Position
				local fx, fz = -dirX, -dirZ
				local px, pz = -dirZ, dirX
				local s = look.size
				pair.eyeL.CFrame = CFrame.new(center + Vector3.new(fx * s * 0.4 + px * s * 0.2, s * 0.12, fz * s * 0.4 + pz * s * 0.2))
				pair.eyeR.CFrame = CFrame.new(center + Vector3.new(fx * s * 0.4 - px * s * 0.2, s * 0.12, fz * s * 0.4 - pz * s * 0.2))
				local mawPos = center + Vector3.new(fx * s * 0.42, -s * 0.14, fz * s * 0.42)
				pair.mouth.CFrame = CFrame.lookAt(mawPos, mawPos + Vector3.new(fx, -0.1, fz))
			end
		end
	end)
end

return WraithVisualController
