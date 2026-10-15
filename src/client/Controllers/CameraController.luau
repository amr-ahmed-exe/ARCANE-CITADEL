--!strict
-- Arcane Citadel: client camera feel (blueprint 2.2).
-- Wall breaches slam the camera; Blood Pact pulses a subtle FOV widen.
-- Cosmetic only — never touches simulation.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CameraController = {}

local trauma = 0
local lastIntact = 3
local isPact = false
local flashFrame: Frame? = nil

local function addTrauma(amount: number): ()
	trauma = math.min(1, trauma + amount)
end

function CameraController.Shake(amount: number): ()
	addTrauma(amount)
end

function CameraController.Init(): ()
	local economyOk, EconomyClient = pcall(require, script.Parent.EconomyClient)
	if economyOk then
		(EconomyClient :: any).OnChanged(function()
			local snap = (EconomyClient :: any).Get()
			if typeof(snap) == "table" and typeof(snap.intactWalls) == "number" then
				isPact = snap.isPact == true
				if snap.intactWalls < lastIntact then
					addTrauma(0.7) -- a wall just fell: heavy slam
					if flashFrame then
						flashFrame.BackgroundTransparency = 0.35
						TweenService:Create(flashFrame, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
					end
				end
				lastIntact = snap.intactWalls
			end
		end)
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "BreachFlash"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = playerGui
	local overlay = Instance.new("Frame")
	overlay.Name = "Flash"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(200, 20, 40)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Active = false
	overlay.Parent = gui
	flashFrame = overlay

	local RunService = game:GetService("RunService")
	RunService.RenderStepped:Connect(function(dt: number)
		local camera = Workspace.CurrentCamera
		if camera then
			-- Blood Pact dread: subtle FOV widen while besieged.
			local target = if isPact then 78 else 70
			camera.FieldOfView += (target - camera.FieldOfView) * math.min(1, dt * 2.5)
		end
		trauma = math.max(0, trauma - dt * 1.2)
		if trauma <= 0 then
			return
		end
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not camera or not humanoid or humanoid.Health <= 0 then
			return
		end
		local s = trauma * trauma
		local offset = Vector3.new((math.random() - 0.5) * 2 * s, (math.random() - 0.5) * 2 * s, 0)
		camera.CFrame = camera.CFrame * CFrame.new(offset)
	end)
end

return CameraController
