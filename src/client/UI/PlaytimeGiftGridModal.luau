--!strict
-- Arcane Citadel: playtime gift grid (blueprint package 7, Creator Rewards).
-- 2m 5m [10m] 15m [30m] 45m [60m -- bracketed chests grant Blood Shards.

local EconomyClient = require(script.Parent.Parent.Controllers.EconomyClient)
local UITheme = require(script.Parent.UITheme)

local PlaytimeGiftGrid = {}

local modal: Frame? = nil
local toggleBtn: TextButton? = nil
local chestButtons: { [number]: TextButton } = {}
local luckLabel: TextLabel? = nil

local function refresh(): ()
	local snap = EconomyClient.Get()
	if not snap then
		return
	end
	local ready = 0
	for i = 1, 7 do
		local g = snap.gifts[i]
		local btn = chestButtons[i]
		if g and btn then
			if g.claimed then
				btn.Text = `{g.minute}m ✓`
				UITheme.SetButtonColor(btn, Color3.fromRGB(60, 60, 80))
			elseif g.claimable then
				btn.Text = `{g.minute}m CLAIM!`
				UITheme.SetButtonColor(btn, UITheme.Gold)
				ready += 1
			else
				btn.Text = `{g.minute}m ({UITheme.FormatTime(g.remaining)})`
				UITheme.SetButtonColor(btn, Color3.fromRGB(70, 60, 95))
			end
		end
	end
	if toggleBtn then
		toggleBtn.Text = if ready > 0 then `🎁 Gifts ({ready} ready!)` else "🎁 Gifts"
	end
	if luckLabel then
		local luck = snap.luckRemaining or 0
		luckLabel.Text = if luck > 0 then `🍀 Luck Elixir: {UITheme.FormatTime(luck)} (better rolls!)` else "10m / 30m / 60m chests grant 💎 + 🍀 Luck"
	end
end

function PlaytimeGiftGrid.Build(parent: Instance): ()
	local gui = UITheme.MakeScreenGui("PlaytimeGiftGrid")

	toggleBtn = UITheme.MakeButton(gui, "Toggle", "🎁 Gifts", UDim2.new(0, 130, 0, 34), UDim2.new(1, -290, 0, 50), UITheme.Panel)
	toggleBtn.MouseButton1Click:Connect(function()
		if modal then
			modal.Visible = not modal.Visible
		end
	end)

	modal = UITheme.MakePanel(gui, "Grid", UDim2.new(0, 300, 0, 330), UDim2.new(1, -310, 0, 50))
	modal.Visible = false
	UITheme.MakeLabel(modal, "Title", "⏳ PLAYTIME GIFTS", UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 6), 15)
	luckLabel = UITheme.MakeLabel(modal, "Luck", "", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 28), 11)

	for i = 1, 7 do
		local row = math.floor((i - 1) / 2)
		local col = (i - 1) % 2
		local btn = UITheme.MakeButton(
			modal,
			`Chest{i}`,
			"?",
			UDim2.new(0, 135, 0, 44),
			UDim2.new(0, 10 + col * 145, 0, 52 + row * 52),
			Color3.fromRGB(70, 60, 95)
		)
		local idx = i
		btn.MouseButton1Click:Connect(function()
			EconomyClient.ClaimGift(idx)
			EconomyClient.Refresh()
		end)
		chestButtons[i] = btn
	end

	gui.Parent = parent
	EconomyClient.OnChanged(refresh)
	refresh()
end

return PlaytimeGiftGrid
