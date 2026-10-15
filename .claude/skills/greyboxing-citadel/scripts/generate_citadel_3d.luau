local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
assert(RunService:IsEdit(), "ABORT: Must run in Roblox Studio Edit Mode (Stopped)!")

local existing = workspace:FindFirstChild("CitadelGeometry")
if existing then existing:Destroy() end

local root = Instance.new("Folder")
root.Name = "CitadelGeometry"
root.Parent = workspace

local WALL_SPECS = {
	{ Index = 1, Radius = 45, Height = 28, Thickness = 6, Sockets = 4, Color = Color3.fromRGB(45, 38, 56) },
	{ Index = 2, Radius = 90, Height = 24, Thickness = 6, Sockets = 8, Color = Color3.fromRGB(35, 30, 46) },
	{ Index = 3, Radius = 140, Height = 20, Thickness = 6, Sockets = 8, Color = Color3.fromRGB(28, 24, 36) },
}

for _, spec in WALL_SPECS do
	local wallModel = Instance.new("Model")
	wallModel.Name = "Wall_" .. spec.Index
	wallModel:SetAttribute("WallIndex", spec.Index)
	CollectionService:AddTag(wallModel, "CitadelWall")
	wallModel.Parent = root

	local segments = 24
	for s = 1, segments do
		local theta1 = (s - 1) * (2 * math.pi / segments)
		local theta2 = s * (2 * math.pi / segments)
		local midTheta = (theta1 + theta2) / 2
		local chordLen = 2 * spec.Radius * math.sin(math.pi / segments) + 1.2

		local part = Instance.new("Part")
		part.Name = "Segment_" .. s
		part.Anchored = true
		part.Material = Enum.Material.Slate
		part.Color = spec.Color
		part.Size = Vector3.new(chordLen, spec.Height, spec.Thickness)
		local pos = Vector3.new(math.cos(midTheta) * spec.Radius, spec.Height / 2, math.sin(midTheta) * spec.Radius)
		part.CFrame = CFrame.lookAt(pos, Vector3.new(0, spec.Height / 2, 0))
		part.Parent = wallModel
	end

	for k = 1, spec.Sockets do
		local angle = (k - 1) * (2 * math.pi / spec.Sockets)
		local socket = Instance.new("Part")
		socket.Name = string.format("WardSocket_%d_%d", spec.Index, k)
		socket.Anchored = true
		socket.Size = Vector3.new(8, 2, 8)
		socket.Color = Color3.fromRGB(138, 43, 226)
		socket.CFrame = CFrame.new(math.cos(angle) * spec.Radius, spec.Height + 1, math.sin(angle) * spec.Radius)
		socket:SetAttribute("WallIndex", spec.Index)
		socket:SetAttribute("SocketId", k)
		CollectionService:AddTag(socket, "WardSocket")
		socket.Parent = root
	end
end

local STATIONS = {
	{ Type = "PermanentVault", Offset = Vector3.new(0, 6, 0), Size = Vector3.new(10, 12, 10) },
	{ Type = "RitualAltar", Offset = Vector3.new(18, 4, 0), Size = Vector3.new(6, 8, 6) },
	{ Type = "Grimoire", Offset = Vector3.new(-18, 4, 12), Size = Vector3.new(5, 7, 5) },
	{ Type = "Anvil", Offset = Vector3.new(-18, 4, -12), Size = Vector3.new(6, 5, 6) },
	{ Type = "RaidPortal", Offset = Vector3.new(0, 7, -28), Size = Vector3.new(10, 14, 3) },
}

for _, st in STATIONS do
	local p = Instance.new("Part")
	p.Name = "Station_" .. st.Type
	p.Anchored = true
	p.Size = st.Size
	p.Position = st.Offset
	p:SetAttribute("StationType", st.Type)
	CollectionService:AddTag(p, "InteractiveStation")
	p.Parent = root
end

for i = 1, 12 do
	local angleDeg = (i - 1) * 30
	local rad = math.rad(angleDeg)
	local node = Instance.new("Part")
	node.Name = "WraithSpawnNode_" .. i
	node.Anchored = true
	node.CanCollide = false
	node.Transparency = 0.5
	node.Size = Vector3.new(4, 4, 4)
	node.Position = Vector3.new(math.cos(rad) * 220, 4, math.sin(rad) * 220)
	node:SetAttribute("LaneAngle", angleDeg)
	CollectionService:AddTag(node, "WraithSpawnNode")
	node.Parent = root
end

for i = 1, 6 do
	local rad = math.rad((i - 1) * 60 + 15)
	local pad = Instance.new("Part")
	pad.Name = "InvaderSpawnPad_" .. i
	pad.Anchored = true
	pad.Size = Vector3.new(8, 1, 8)
	pad.Position = Vector3.new(math.cos(rad) * 240, 0.5, math.sin(rad) * 240)
	pad:SetAttribute("PadIndex", i)
	CollectionService:AddTag(pad, "InvaderSpawnPad")
	pad.Parent = root
end

print("CitadelGeometry generated with all CollectionService tags and Attributes.")
