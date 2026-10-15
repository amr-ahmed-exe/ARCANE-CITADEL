--!strict
-- Arcane Citadel: invader HUD (blueprint package 6, invader half).
-- 5 Soul Tether skulls + live Contribution share meter + Sabotage Hex
-- consumables (WardJam / SoulLeech, Blood Shard sinks) + Coven ally oath.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SabotageConfig = require(Shared.Configurations.SabotageConfig)
local EconomyClient = require(script.Parent.Parent.Controllers.EconomyClient)
local UITheme = require(script.Parent.UITheme)

local InvaderHUD = {}

local bar: Frame? = nil
local livesLabel: TextLabel? = nil
local shareFill: Frame? = nil
local shareLabel: TextLabel? = nil
local hexMsg: TextLabel? = nil

local function targetPoint(): Vector3
	local mouse = Players.LocalPlayer:GetMouse()
	return mouse.Hit.Position
end

local function castHex(hexId: string): ()
	local spec = SabotageConfig.Get(hexId)
	if not spec then
		return
	end
	local ok, msg = EconomyClient.UseSabotage(hexId, targetPoint())
	if hexMsg then
		hexMsg.Text = if ok then `{spec.Name} cast!` else msg
	end
end

local function refresh(): ()
	local snap = EconomyClient.Get()
	if not snap or not bar then
		return
	end
	local isInvader = snap.role == "invader"
	bar.Visible = isInvader
	if not isInvader then
		return
	end
	local skulls = ""
	for i = 1, 5 do
		skulls ..= if i <= (snap.lives or 0) then "💀" else "🤍"
	end
	if livesLabel then
		livesLabel.Text = `{skulls}  {snap.lives}/5 Tethers`
	end
	if shareFill then
		shareFill.Size = UDim2.new(math.clamp(snap.share or 0, 0, 1), 0, 1, 0)
	end
	if shareLabel then
		shareLabel.Text = string.format("Loot share: %d%%", math.floor((snap.share or 0) * 100))
	end
end

function InvaderHUD.Build(parent: Instance): ()
	local gui = UITheme.MakeScreenGui("InvaderHUD")
	bar = UITheme.MakePanel(gui, "Bar", UDim2.new(0, 300, 0, 150), UDim2.new(0.5, -150, 1, -226))
	bar.Visible = false
	livesLabel = UITheme.MakeLabel(bar, "Lives", "", UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 4), 14)
	local back = Instance.new("Frame")
	back.Name = "ShareBack"
	back.Size = UDim2.new(1, -16, 0, 12)
	back.Position = UDim2.new(0, 8, 0, 30)
	back.BackgroundColor3 = Color3.fromRGB(40, 30, 55)
	back.BorderSizePixel = 0
	back.Parent = bar
	shareFill = Instance.new("Frame")
	shareFill.Name = "ShareFill"
	shareFill.Size = UDim2.new(0, 0, 1, 0)
	shareFill.BackgroundColor3 = UITheme.Gold
	shareFill.BorderSizePixel = 0
	shareFill.Parent = back
	shareLabel = UITheme.MakeLabel(bar, "Share", "", UDim2.new(1, -16, 0, 16), UDim2.new(0, 8, 0, 44), 11)

	-- Sabotage Hex row (aim with mouse, costs Blood Shards).
	local jamSpec = SabotageConfig.Get("WardJam")
	local leechSpec = SabotageConfig.Get("SoulLeech")
	local jamBtn = UITheme.MakeButton(bar, "WardJam", `🕯 Jam ({if jamSpec then jamSpec.BloodShardCost else 5}◆)`, UDim2.new(0, 136, 0, 30), UDim2.new(0, 8, 0, 64), UITheme.Accent)
	jamBtn.TextSize = 11
	jamBtn.MouseButton1Click:Connect(function()
		castHex("WardJam")
	end)
	local leechBtn = UITheme.MakeButton(bar, "SoulLeech", `🩸 Leech ({if leechSpec then leechSpec.BloodShardCost else 8}◆)`, UDim2.new(0, 136, 0, 30), UDim2.new(0, 156, 0, 64), UITheme.Crimson)
	leechBtn.TextSize = 11
	leechBtn.MouseButton1Click:Connect(function()
		castHex("SoulLeech")
	end)
	local allyBtn = UITheme.MakeButton(bar, "Coven", "🤝 Swear Coven Oath (defend)", UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 98), UITheme.SafeGreen)
	allyBtn.TextSize = 11
	allyBtn.MouseButton1Click:Connect(function()
		local ok, msg = EconomyClient.RequestAlly()
		if hexMsg then
			hexMsg.Text = if ok then "Oath sworn! Fight for the Citadel!" else msg
		end
	end)
	hexMsg = UITheme.MakeLabel(bar, "HexMsg", "", UDim2.new(1, -16, 0, 16), UDim2.new(0, 8, 0, 126), 10)
	gui.Parent = parent
	EconomyClient.OnChanged(refresh)
	refresh()
end

return InvaderHUD
