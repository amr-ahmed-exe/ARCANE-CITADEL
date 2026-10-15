--!strict
-- Arcane Citadel: bottom spell bar (blueprint package 6, combat half).
-- Q/E/R buttons mirror the active loadout. Cooldown state lives in
-- CombatInputController so the hotkeys and these buttons share one timer.

local Players = game:GetService("Players")

local EconomyClient = require(script.Parent.Parent.Controllers.EconomyClient)
local CombatInputController = require(script.Parent.Parent.Controllers.CombatInputController)
local UITheme = require(script.Parent.UITheme)

local SpellBar = {}

local buttons: { [string]: TextButton } = {}
local assigned: { [string]: string? } = { Q = nil, E = nil, R = nil }
local bars: { [string]: Frame } = {}

-- Slot identity: Q frost-blue, E witchfire-orange, R doom-purple.
local SLOT_COLORS: { [string]: Color3 } = {
	Q = Color3.fromRGB(70, 140, 255),
	E = Color3.fromRGB(255, 140, 40),
	R = Color3.fromRGB(200, 70, 255),
}

local function refresh(): ()
	local data = EconomyClient.GetInventoryCached()
	if typeof(data) ~= "table" then
		return
	end
	local preset = if data.active == "Raider" then data.raider else data.warden
	if typeof(preset) ~= "table" then
		return
	end
	assigned.Q = preset.spellQ
	assigned.E = preset.spellE
	assigned.R = preset.spellR
	for key, btn in buttons do
		-- Always write, including the empty case: unequipping a spell must
		-- clear the label instead of leaving the previous name stuck there.
		local spellId = assigned[key]
		btn.Text = if spellId then `{key}: {spellId}` else key
	end
end

function SpellBar.Build(parent: Instance): ()
	local gui = UITheme.MakeScreenGui("SpellBar")
	local keys = { "Q", "E", "R" }
	for i, key in keys do
		local btn = UITheme.MakeButton(gui, key, key, UDim2.new(0, 110, 0, 40), UDim2.new(0.5, -175 + (i - 1) * 118, 1, -60), UITheme.Panel)
		btn.TextSize = 12
		local tint = SLOT_COLORS[key] or UITheme.Panel
		UITheme.SetButtonColor(btn, UITheme.Panel:Lerp(tint, 0.35))
		local back = Instance.new("Frame")
		back.Name = "CooldownBack"
		back.Size = UDim2.new(1, -8, 0, 4)
		back.Position = UDim2.new(0, 4, 1, -8)
		back.BackgroundColor3 = Color3.fromRGB(10, 8, 16)
		back.BackgroundTransparency = 0.3
		back.BorderSizePixel = 0
		back.Parent = btn
		local fill = Instance.new("Frame")
		fill.Name = "CooldownFill"
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = tint
		fill.BorderSizePixel = 0
		fill.Visible = false
		fill.Parent = back
		bars[key] = fill
		local k = key
		btn.MouseButton1Click:Connect(function()
			CombatInputController.Refresh()
			local spellId = assigned[k]
			if spellId then
				CombatInputController.CastSpell(k, Players.LocalPlayer:GetMouse().Hit.Position)
			end
		end)
		buttons[key] = btn
	end

	task.spawn(function()
		while true do
			task.wait(0.1)
			for key, btn in buttons do
				local left = CombatInputController.GetCooldownRemaining(key)
				local total = CombatInputController.GetCooldownTotal(assigned[key])
				local frac = math.clamp(1 - left / total, 0, 1)
				local fill = bars[key]
				if fill then
					fill.Size = UDim2.fromScale(frac, 1)
					fill.Visible = left > 0
				end
				(btn :: TextButton).TextTransparency = if left > 0 then 0.5 else 0
			end
		end
	end)

	gui.Parent = parent
	EconomyClient.OnChanged(function()
		task.spawn(refresh)
	end)
	task.spawn(refresh)
end

return SpellBar
