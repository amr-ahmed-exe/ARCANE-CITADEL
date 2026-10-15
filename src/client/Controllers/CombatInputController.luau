--!strict
-- Arcane Citadel: staff primary fire + Q/E/R spell input (Milestone 3).
-- Server validates everything; the bolt here is cosmetic only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SpellConfig = require(Shared.Configurations.SpellConfig)
local EconomyClient = require(script.Parent.EconomyClient)
local WraithVisualController = require(script.Parent.WraithVisualController)

local CombatInputController = {}

local spells: { Q: string?, E: string?, R: string? } = { Q = nil, E = nil, R = nil }

local function remotes()
	return Shared:WaitForChild("Remotes")
end

local function invoke(name: string, ...: any): any
	local folder = remotes()
	local remote = folder:WaitForChild(name) :: RemoteFunction
	return remote:InvokeServer(...)
end

-- Pull the active preset's Q/E/R out of the cached inventory.
-- Returns true when every slot is resolved, so callers can tell the
-- difference between "profile not loaded yet" and "player has no spells".
function CombatInputController.Refresh(): boolean
	local data = EconomyClient.GetInventoryCached()
	if typeof(data) ~= "table" then
		return false
	end
	local preset = if data.active == "Raider" then data.raider else data.warden
	if typeof(preset) ~= "table" then
		return false
	end
	spells.Q = preset.spellQ
	spells.E = preset.spellE
	spells.R = preset.spellR
	return spells.Q ~= nil or spells.E ~= nil or spells.R ~= nil
end

function CombatInputController.GetSpells(): { Q: string?, E: string?, R: string? }
	return spells
end

local function fireBolt(from: Vector3, to: Vector3, color: Color3): ()
	local dir = to - from
	local dist = dir.Magnitude
	if dist < 1 then
		return
	end
	local bolt = Instance.new("Part")
	bolt.Name = "StaffBoltFX"
	bolt.Size = Vector3.new(0.4, 0.4, math.min(dist, 200))
	bolt.CFrame = CFrame.new(from + dir * 0.5, to)
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.CanQuery = false
	bolt.Material = Enum.Material.Neon
	bolt.Color = color
	bolt.Parent = workspace
	-- Light trail so volleys read as arcs of witchfire.
	local head = Instance.new("Attachment")
	head.Position = Vector3.new(0, 0, -bolt.Size.Z / 2)
	head.Parent = bolt
	local tail = Instance.new("Attachment")
	tail.Position = Vector3.new(0, 0, bolt.Size.Z / 2)
	tail.Parent = bolt
	local trail = Instance.new("Trail")
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Lifetime = 0.25
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Attachment0 = head
	trail.Attachment1 = tail
	trail.Parent = bolt
	task.delay(0.15, function()
		bolt:Destroy()
	end)
end

-- Expanding flash + white-hot core at a spell impact point.
local function impactFX(center: Vector3, color: Color3, radius: number): ()
	local flash = Instance.new("Part")
	flash.Name = "SpellImpactFX"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(radius * 0.5, radius * 0.5, radius * 0.5)
	flash.CFrame = CFrame.new(center)
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.Transparency = 0.25
	flash.Material = Enum.Material.Neon
	flash.Color = color
	flash.Parent = workspace
	TweenService:Create(flash, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius * 2, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	local core = Instance.new("Part")
	core.Name = "SpellCoreFX"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(radius * 0.3, radius * 0.3, radius * 0.3)
	core.CFrame = CFrame.new(center)
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.Transparency = 0.1
	core.Material = Enum.Material.Neon
	core.Color = Color3.fromRGB(255, 255, 255)
	core.Parent = workspace
	TweenService:Create(core, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
	}):Play()
	task.delay(0.32, function()
		flash:Destroy()
		core:Destroy()
	end)
end

local SPELL_FX = {
	Q = { color = Color3.fromRGB(70, 140, 255), radius = 8 },
	E = { color = Color3.fromRGB(255, 140, 40), radius = 15 },
	R = { color = Color3.fromRGB(220, 60, 160), radius = 20 },
}

-- Single source of truth for Q/E/R cooldowns, shared by the key handler and
-- the SpellBar buttons so keyboard and mouse can never bypass each other.
local cooldownUntil: { [string]: number } = {}
local REJECT_LOCKOUT = 0.4

function CombatInputController.GetCooldownRemaining(key: string): number
	return math.max(0, (cooldownUntil[key] or 0) - os.clock())
end

function CombatInputController.GetCooldownTotal(spellId: string?): number
	local spec = if spellId then SpellConfig[spellId] else nil
	return if spec then spec.CooldownSeconds else 5
end

-- Attempts a spell cast. Returns true only when the server accepted it, so
-- callers know whether to play the impact FX.
function CombatInputController.CastSpell(key: string, targetPos: Vector3): boolean
	local spellId = spells[key]
	if not spellId then
		return false
	end
	local now = os.clock()
	if now < (cooldownUntil[key] or 0) then
		return false
	end
	local ok = invoke("CastSpell", spellId, targetPos) == true
	local spec = SpellConfig[spellId]
	local cd = if spec then spec.CooldownSeconds else 5
	-- A rejected cast still locks briefly so holding the key cannot spam the
	-- remote, but it does not serve the full cooldown.
	cooldownUntil[key] = now + (if ok then cd else REJECT_LOCKOUT)
	return ok
end

function CombatInputController.Init(): ()
	CombatInputController.Refresh()
	-- The server returns nil from GetInventory until the profile finishes
	-- loading (up to ~5s). Without this, Q/E/R stayed nil for the whole
	-- session unless the player happened to open the Grimoire and swap loadouts.
	EconomyClient.OnChanged(function()
		CombatInputController.Refresh()
	end)

	local player = Players.LocalPlayer
	local mouse = player:GetMouse()

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local target = mouse.Hit.Position
			-- Fire-and-forget on the remote, but only spend the FX budget
			-- once the server confirms the shot actually happened.
			task.spawn(function()
				if invoke("FireStaff", target) ~= true then
					return
				end
				fireBolt(root.Position, target, Color3.fromRGB(150, 60, 255))
				WraithVisualController.FlashAt(target, 14)
				impactFX(target, Color3.fromRGB(150, 60, 255), 9)
			end)
		elseif input.KeyCode == Enum.KeyCode.Q then
			if CombatInputController.CastSpell("Q", mouse.Hit.Position) then
				impactFX(mouse.Hit.Position, SPELL_FX.Q.color, SPELL_FX.Q.radius)
			end
		elseif input.KeyCode == Enum.KeyCode.E then
			if CombatInputController.CastSpell("E", mouse.Hit.Position) then
				impactFX(mouse.Hit.Position, SPELL_FX.E.color, SPELL_FX.E.radius)
			end
		elseif input.KeyCode == Enum.KeyCode.R then
			if CombatInputController.CastSpell("R", mouse.Hit.Position) then
				impactFX(mouse.Hit.Position, SPELL_FX.R.color, SPELL_FX.R.radius)
			end
		end
	end)
end

return CombatInputController
