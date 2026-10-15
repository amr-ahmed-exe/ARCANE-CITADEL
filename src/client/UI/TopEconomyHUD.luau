--!strict
-- Arcane Citadel: top economy HUD (blueprint package 1: TopEconomyHUD).
-- Vault (padlock when sealed) | Session Pot | Blood Shards | Multiplier.

local EconomyClient = require(script.Parent.Parent.Controllers.EconomyClient)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local NoticeBanner = require(script.Parent.NoticeBanner)
local ShopModal = require(script.Parent.ShopModal)
local UITheme = require(script.Parent.UITheme)

local TopEconomyHUD = {}

local vaultLabel: TextLabel? = nil
local potLabel: TextLabel? = nil
local shardLabel: TextLabel? = nil
local crownLabel: TextButton? = nil
local multLabel: TextLabel? = nil
local rankLabel: TextLabel? = nil
local pactButton: TextButton? = nil
local goalLabel: TextLabel? = nil
local lastStreakMilestone = 0

local function currentGoal(snap: any): string
	if not snap or not snap.walls then
		return ""
	end
	local w2 = snap.walls[2]
	if snap.awaitingDecision then
		return "⑤ Wall fell! Choose: BANK it or HOLD the line!"
	end
	if not w2.unlocked then
		if snap.vault >= w2.unlockCost then
			return "① Unlock Wall 2 (left panel) — you can afford it!"
		end
		return "① Earn souls: LEFT-CLICK the glowing wraiths!"
	end
	if not snap.isPact and (snap.maxLevel ~= nil) then
		local maxed = true
		for i = 1, 3 do
			local w = snap.walls[i]
			if not w.unlocked or (w.level or 0) < snap.maxLevel then
				maxed = false
				break
			end
		end
		if maxed and (snap.rank or 1) < 4 then
			return "☄ ASCEND to the next Rank! (left panel)"
		end
	end
	if not snap.isPact and w2.elixirRemaining <= 0 then
		return "② Brew a 15-min Elixir on Wall 2 (left panel)"
	end
	if not snap.isPact then
		return "③ Press ENTER BLOOD PACT for 2x+ souls!"
	end
	local heat = if (snap.intensityBonus or 0) > 0
		then ` Heat +{string.format("%.2f", snap.intensityBonus)}x — repair or hold!`
		else ""
	return `④ Survive! Kill wraiths & raiders, protect the walls!{heat}`
end

local function refresh(): ()
	local snap = EconomyClient.Get()
	if not snap then
		return
	end
	if vaultLabel then
		local lock = if snap.isPact then " 🔒" else ""
		vaultLabel.Text = `🏦 Vault: {UITheme.FormatSouls(snap.vault)}{lock}`
	end
	if potLabel then
		potLabel.Text = if snap.isPact
			then `🔥 Session Pot: {UITheme.FormatSouls(snap.pot)}`
			else `💤 Sanctuary (safe AFK 1.0x)`
	end
	if shardLabel then
		shardLabel.Text = `💎 Shards: {UITheme.FormatSouls(snap.shards)}`
	end
	if crownLabel then
		crownLabel.Text = `👑 {UITheme.FormatSouls(snap.crowns or 0)} [+1.3x]`
	end
	if multLabel then
		local streak = snap.streak or 0
		multLabel.Text = if streak >= 2
			then string.format("⚡ %.2fx 🔥x%d", snap.multiplier, streak)
			else string.format("⚡ %.2fx", snap.multiplier)
		multLabel.TextColor3 = if snap.isPact then UITheme.Gold else UITheme.Text
		-- Kill-streak milestones (edge-triggered fanfare).
		if streak >= 20 and lastStreakMilestone < 20 then
			lastStreakMilestone = 20
			SoundController.Cue("Streak")
			NoticeBanner.ShowLocal("🔥 RAMPAGE x20! +40% wraith souls!", { 255, 150, 60 })
		elseif streak >= 10 and lastStreakMilestone < 10 then
			lastStreakMilestone = 10
			SoundController.Cue("Streak")
			NoticeBanner.ShowLocal("🔥 Kill streak x10! +20% wraith souls!", { 255, 190, 60 })
		elseif streak < 2 then
			lastStreakMilestone = 0
		end
	end
	if rankLabel then
		rankLabel.Text = `★{snap.rank or 1} {snap.rankName or ""}`
	end
	if pactButton then
		if snap.isPact then
			pactButton.Text = `BLOOD PACT {UITheme.FormatTime(snap.lockRemaining)}`
			UITheme.SetButtonColor(pactButton, UITheme.Crimson)
			UITheme.SetGlow(pactButton, false)
		elseif not snap.isOwner then
			-- Raiders watch the multiplier but cannot open their own vault.
			pactButton.Text = "BLOOD PACT — DEFENDER ONLY"
			UITheme.SetButtonColor(pactButton, Color3.fromRGB(55, 45, 75))
			UITheme.SetGlow(pactButton, false)
		else
			pactButton.Text = "ENTER BLOOD PACT (2x+)"
			UITheme.SetButtonColor(pactButton, UITheme.Accent)
			UITheme.SetGlow(pactButton, true, UITheme.Gold)
		end
	end
	if goalLabel then
		goalLabel.Text = currentGoal(snap)
	end
end

function TopEconomyHUD.Build(parent: Instance): ()
	local gui = UITheme.MakeScreenGui("TopEconomyHUD")
	local bar = UITheme.MakePanel(gui, "Bar", UDim2.new(0, 780, 0, 44), UDim2.new(0.5, -390, 0, 10))

	vaultLabel = UITheme.MakeLabel(bar, "Vault", "🏦 Vault: 0", UDim2.new(0, 155, 1, 0), UDim2.new(0, 12, 0, 0), 13)
	potLabel = UITheme.MakeLabel(bar, "Pot", "", UDim2.new(0, 165, 1, 0), UDim2.new(0, 167, 0, 0), 13)
	shardLabel = UITheme.MakeLabel(bar, "Shards", "", UDim2.new(0, 95, 1, 0), UDim2.new(0, 332, 0, 0), 13)
	multLabel = UITheme.MakeLabel(bar, "Mult", "", UDim2.new(0, 70, 1, 0), UDim2.new(0, 427, 0, 0), 13)
	rankLabel = UITheme.MakeLabel(bar, "Rank", "", UDim2.new(0, 125, 1, 0), UDim2.new(0, 497, 0, 0), 12)
	rankLabel.TextColor3 = UITheme.Gold
	-- Eclipse Crowns balance (1.3x commitment currency) + 1-click shop shortcut.
	crownLabel = UITheme.MakeButton(bar, "Crowns", "👑 0 [+1.3x]", UDim2.new(0, 135, 1, -8), UDim2.new(0, 627, 0, 4), UITheme.Gold)
	crownLabel.TextSize = 13;
	(crownLabel :: TextButton).TextColor3 = Color3.fromRGB(30, 20, 10)
	crownLabel.MouseButton1Click:Connect(function()
		-- Go through ShopModal.Toggle so the rows actually render. The old
		-- FindFirstChild("ShopModal")/("Shop") string coupling just flipped
		-- Visible on a panel that had never been drawn into.
		ShopModal.Toggle()
	end)

	pactButton = UITheme.MakeButton(gui, "PactToggle", "ENTER BLOOD PACT (2x+)", UDim2.new(0, 220, 0, 36), UDim2.new(0.5, -110, 0, 60), UITheme.Accent)
	pactButton.MouseButton1Click:Connect(function()
		local snap = EconomyClient.Get()
		if not snap then
			return
		end
		if snap.isPact then
			NoticeBanner.ShowLocal("The Blood Pact is already running.", { 255, 190, 60 })
			return
		end
		-- Only the Citadel owner may open their own vault for a raid. Without
		-- this check the glowing button stayed live for every invader in the
		-- server and did nothing when pressed.
		if not snap.isOwner then
			NoticeBanner.ShowLocal("Only the Citadel's owner can start a Blood Pact.", { 255, 150, 60 })
			return
		end
		if not EconomyClient.EnableBloodPact() then
			NoticeBanner.ShowLocal("Could not start the Blood Pact — try again.", { 255, 150, 60 })
		end
		EconomyClient.Refresh()
	end)
	UITheme.SetGlow(pactButton, true, UITheme.Gold)

	goalLabel = UITheme.MakeLabel(gui, "Goal", "", UDim2.new(0, 460, 0, 22), UDim2.new(0.5, -230, 0, 100), 14)
	goalLabel.TextXAlignment = Enum.TextXAlignment.Center
	goalLabel.TextColor3 = UITheme.Gold

	gui.Parent = parent
	EconomyClient.OnChanged(refresh)
	refresh()
end

return TopEconomyHUD
