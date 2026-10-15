--!strict
-- Arcane Citadel: 5th-death panic modal (blueprint package 8, attacker half).
-- 10s countdown: forfeit (fracture + banish) OR instant survive:
--   [29 R$ slow prompt] | [22 Crowns 1.3x INSTANT 0ms].

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyClient = require(script.Parent.Parent.Controllers.EconomyClient)
local UITheme = require(script.Parent.UITheme)

local FifthDeathModal = {}

local modal: Frame? = nil
local timerLabel: TextLabel? = nil
local msgLabel: TextLabel? = nil
local deadline = 0

local function invoke(name: string, ...: any): any
	local folder = Shared:WaitForChild("Remotes")
	local remote = folder:WaitForChild(name) :: RemoteFunction
	return remote:InvokeServer(...)
end

function FifthDeathModal.Build(parent: Instance): ()
	local gui = UITheme.MakeScreenGui("FifthDeathModal")
	modal = UITheme.MakePanel(gui, "Modal", UDim2.new(0, 420, 0, 250), UDim2.new(0.5, -210, 0.5, -125))
	modal.Visible = false;
	(modal :: Frame).BackgroundColor3 = Color3.fromRGB(40, 12, 20)

	UITheme.MakeLabel(modal, "Title", "💀 FINAL TETHER SEVERED", UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 6), 17)
	timerLabel = UITheme.MakeLabel(modal, "Timer", "", UDim2.new(1, -20, 0, 40), UDim2.new(0, 10, 0, 36), 13)
	timerLabel.TextWrapped = true
	msgLabel = UITheme.MakeLabel(modal, "Msg", "22 Crowns = instant (no dialog). 29 R$ = slow prompt.", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 78), 11)
	msgLabel.TextColor3 = UITheme.Gold

	local forfeit = UITheme.MakeButton(modal, "Forfeit", "FORFEIT & LEAVE (weapon fractures)", UDim2.new(1, -20, 0, 32), UDim2.new(0, 10, 0, 100), UITheme.Crimson)
	forfeit.MouseButton1Click:Connect(function()
		invoke("InvaderForfeit")
		if modal then
			modal.Visible = false
		end
	end)

	-- Dual checkout: Robux (slow) vs Crowns (1.3x instant).
	local robuxBtn = UITheme.MakeButton(modal, "TethersRobux", "+3 TETHERS — 29 R$", UDim2.new(0, 190, 0, 32), UDim2.new(0, 10, 0, 140), Color3.fromRGB(70, 60, 95))
	robuxBtn.TextSize = 12
	robuxBtn.MouseButton1Click:Connect(function()
		local ok, msg = invoke("BuyProduct", "ExtraTethers")
		if not ok and tostring(msg):find("coming soon") then
			ok, msg = invoke("BuyProduct", "Extra_Soul_Tethers")
		end
		if msgLabel then
			msgLabel.Text = if ok then "Opening Roblox checkout…" else tostring(msg)
		end
	end)

	local crownBtn = UITheme.MakeButton(modal, "TethersCrowns", "⚡ +3 — 👑22 INSTANT", UDim2.new(0, 190, 0, 32), UDim2.new(0, 210, 0, 140), UITheme.Gold)
	crownBtn.TextSize = 12
	crownBtn.TextColor3 = Color3.fromRGB(30, 20, 10)
	crownBtn.MouseButton1Click:Connect(function()
		local ok, msg = EconomyClient.SpendCrowns("Extra_Soul_Tethers")
		if msgLabel then
			msgLabel.Text = if ok then "⚡ Survived! (Crowns 1.3x)" else tostring(msg)
		end
		EconomyClient.Refresh()
	end)

	local note = UITheme.MakeLabel(modal, "Note", "Crowns save 30% + skip the 10s death timer.", UDim2.new(1, -20, 0, 30), UDim2.new(0, 10, 0, 180), 11)
	note.TextWrapped = true

	local event = Shared:WaitForChild("Remotes"):WaitForChild("FifthDeath") :: RemoteEvent
	event.OnClientEvent:Connect(function()
		deadline = os.clock() + 10
		if modal then
			modal.Visible = true
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			if modal and modal.Visible then
				local left = math.max(0, deadline - os.clock())
				if timerLabel then
					timerLabel.Text =
						`Banished in {string.format("%.0f", left)}s — loot cut lost, weapon fractures (-25%).`
				end
				if left <= 0 then
					modal.Visible = false
				end
			end
		end
	end)

	gui.Parent = parent
	EconomyClient.OnChanged(function()
		-- Granted tethers revive us: hide the countdown immediately.
		local snap = EconomyClient.Get()
		if modal and snap and (snap.lives or 0) > 0 then
			modal.Visible = false
		end
	end)
end

return FifthDeathModal
