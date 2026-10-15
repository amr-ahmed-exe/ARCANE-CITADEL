--!strict
-- Arcane Citadel: safe runtime mesh loading (art pass).
-- Pipeline per asset: InsertService load (pcall) -> STRIP all Script /
-- LocalScript / ModuleScript + Decal / Texture instances WHILE DETACHED
-- (nothing executes before placement) -> part-count cap -> sanitize
-- physics (Anchored, no collide, no query) -> clone + auto-fit on demand.
-- Anything suspicious or heavy is rejected and the caller falls back to
-- code-built primitives, so the game never breaks on a bad asset.

local InsertService = game:GetService("InsertService")

local MeshLoader = {}

local cache: { [number]: Model } = {}
local failed: { [number]: boolean } = {}

-- Loads + sanitizes once per asset ID. Returns nil on any problem.
function MeshLoader.Load(assetId: number, partCap: number): Model?
	if assetId == 0 or failed[assetId] then
		return nil
	end
	if cache[assetId] then
		return cache[assetId]
	end
	local ok, result = pcall(InsertService.LoadAsset, InsertService, assetId)
	if not ok or typeof(result) ~= "Instance" then
		failed[assetId] = true
		warn(`[MeshLoader] load failed for asset {assetId} (request error); using primitives.`)
		return nil
	end
	-- Models arrive as Model; single meshes arrive as a lone MeshPart.
	-- Both are safe (a lone part cannot carry scripts); anything else is out.
	local model: Model? = nil
	if (result :: Instance):IsA("Model") then
		model = result :: Model
	elseif (result :: Instance):IsA("BasePart") then
		model = Instance.new("Model")
		local lonePart = result :: BasePart
		lonePart.Parent = model
	else
		failed[assetId] = true
		warn(`[MeshLoader] load failed for asset {assetId} (type {(result :: Instance).ClassName}); using primitives.`)
		return nil
	end
	assert(model, "mesh model missing")
	-- Strip executable + sticker content while still detached from the game.
	for _, d in model:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("Decal") or d:IsA("Texture") then
			d:Destroy()
		end
	end
	local parts = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	if parts == 0 or parts > partCap then
		failed[assetId] = true
		model:Destroy()
		warn(`[MeshLoader] rejected asset {assetId}: {parts} parts (cap {partCap}).`)
		return nil
	end
	cache[assetId] = model
	return model
end

-- Clones the sanitized template, auto-fits its longest axis to targetSize,
-- and grounds it at (x, z) with yaw. Returns nil if scaling fails.
function MeshLoader.PlaceClone(template: Model, targetSize: number, x: number, z: number, yaw: number): Model?
	local ok, clone = pcall(function(): Model
		local m = template:Clone()
		local _, size = m:GetBoundingBox()
		local longest = math.max(size.X, math.max(size.Y, size.Z))
		assert(longest > 0, "empty model")
		m:ScaleTo(targetSize / longest)
		local _, scaled = m:GetBoundingBox()
		m:PivotTo(CFrame.new(x, scaled.Y / 2, z) * CFrame.Angles(0, yaw, 0))
		return m
	end)
	if ok and typeof(clone) == "Instance" and (clone :: Instance):IsA("Model") then
		return clone :: Model
	end
	if typeof(clone) == "Instance" then
		pcall(function()
			(clone :: Instance):Destroy()
		end)
	end
	return nil
end

-- Hangs a light on the first part of a placed mesh (for portals/hearts).
function MeshLoader.AttachLight(model: Model, color: Color3, lightRange: number): ()
	local holder: BasePart? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			holder = d
			break
		end
	end
	if not holder then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = lightRange
	light.Brightness = 2
	light.Shadows = false
	light.Parent = holder
end

return MeshLoader
