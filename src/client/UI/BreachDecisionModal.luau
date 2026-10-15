--!strict
-- Arcane Citadel: breach decision modal (blueprint package 3).
-- Cash Out 67% (safe) vs Hold the inner line (greedy + Last-Stand bonus).
-- Bottom dual-checkout panic bar: Blood Insurance [39 R$ slow] | [30 Crowns INSTANT].

local EconomyClient = require(script.Parent.Parent.Controllers.EconomyClient)
local UITheme = require(script.Parent.UITheme)

local BreachDecisionModal = {}

local modal: Frame? = nil
local infoLabel: TextLabel? = nil
local msgLabel: TextLabel? = nil
local cashBtn: TextButton? = nil
local holdBtn: TextButton? = nil
local closeBtn: TextButton? = nil
local wasVisible = false
local dismissed = false

local function shakeCamera(): ()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	task.spawn(function()
		local base = camera.CFrame
		for _ = 1, 12 do
			if not modal or not modal.Visible then
				break
			end
			camera.CFrame = base * CFrame.new(math.random(-2, 2), math.random(-1, 1), 0)
			task.wait(0.04)
		end
		if workspace.CurrentCamera == camera then
			camera.CFrame = base
		end
	end)
end

local function refresh(): ()
	local snap = EconomyClient.Get()
	if not snap or not modal then
		return
	end
	-- awaitingDecision is session-global, so invaders and Coven allies saw
	-- this panel too — but BreachDecision is owner-only, so both buttons
	-- silently failed and there was no way to close it. Non-owners now get a
	-- read-only spectator panel with a dismiss button.
	local isOwner = snap.isOwner == true
	if snap.awaitingDecision ~= true then
		-- New breach cycle: let the panel show again next time.
		dismissed = false
	end
	modal.Visible = snap.awaitingDecision == true and not dismissed
	if modal.Visible and not wasVisible then
		shakeCamera()
	end
	wasVisible = modal.Visible

	if not modal.Visible then
		return
	end

	if cashBtn then
		cashBtn.Visible = isOwner
	end
	if holdBtn then
		holdBtn.Visible = isOwner
	end
	if closeBtn then
		closeBtn.Visible = not isOwner
	end
	if infoLabel then
		if isOwner then
			infoLabel.Text =
				`A wall has fallen! {UITheme.FormatSouls(snap.pot)} Souls remain in the Session Pot.\nCash out safely, or hold the tighter {snap.intactWalls}-wall line for bonus multiplier (now {string.format("%.2f", snap.multiplier)}x)?`
		else
			infoLabel.Text =
				`The defender's wall has fallen! {UITheme.FormatSouls(snap.pot)} Souls remain in the Session Pot.\nThey choose: cash out safely, or hold the tighter {snap.intactWalls}-wall line for bonus multiplier (now {string.format("%.2f", snap.multiplier)}x).`
		end
	end
end

function BreachDecisionModal.Build(parent: Instance): ()
	local gui = UITheme.MakeScreenGui("BreachDecisionModal")
	modal = UITheme.MakePanel(gui, "Modal", UDim2.new(0, 480, 0, 290), UDim2.new(0.5, -240, 0.5, -145))
	modal.Visible = false;
	(modal :: Frame).BackgroundColor3 = Color3.fromRGB(35, 15, 25)

	UITheme.MakeLabel(modal, "Title", "⚔ WALL BREACHED! ⚔", UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 6), 18)
	infoLabel = UITheme.MakeLabel(modal, "Info", "", UDim2.new(1, -20, 0, 66), UDim2.new(0, 10, 0, 36), 13)
	infoLabel.TextWrapped = true

	cashBtn = UITheme.MakeButton(modal, "CashOut", "ACCEPT DEFEAT & BANK REMAINING", UDim2.new(1, -20, 0, 34), UDim2.new(0, 10, 0, 108), UITheme.SafeGreen)
	cashBtn.MouseButton1Click:Connect(function()
		local ok = EconomyClient.BreachDecision("cashout")
		if not ok and msgLabel then
			msgLabel.Text = "Could not cash out — the pact state changed."
		end
		EconomyClient.Refresh()
	end)

	holdBtn = UITheme.MakeButton(modal, "Hold", "HOLD THE INNER LINE! (+bonus)", UDim2.new(1, -20, 0, 34), UDim2.new(0, 10, 0, 146), UITheme.Crimson)
	holdBtn.MouseButton1Click:Connect(function()
		local ok = EconomyClient.BreachDecision("hold")
		if not ok and msgLabel then
			msgLabel.Text = "Could not hold the line — the pact state changed."
		end
		EconomyClient.Refresh()
	end)

	-- Spectator-only dismiss. Owners get no dismiss: the decision is the
	-- whole point of the moment.
	closeBtn = UITheme.MakeButton(modal, "Close", "CONTINUE WATCHING", UDim2.new(1, -20, 0, 34), UDim2.new(0, 10, 0, 108), Color3.fromRGB(60, 48, 85))
	closeBtn.Visible = false
	closeBtn.MouseButton1Click:Connect(function()
		-- Must stick: refresh() runs every second and would otherwise
		-- re-open the panel the instant this handler hides it.
		dismissed = true
		if modal then
			modal.Visible = false
		end
	end)

	msgLabel = UITheme.MakeLabel(modal, "Msg", "Insurance: 30 Crowns instant vs 39 R$ slow.", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 184), 11)
	msgLabel.TextColor3 = UITheme.Gold

	-- Dual-checkout panic bar.
	local robuxBtn = UITheme.MakeButton(modal, "InsuranceRobux", "🛡 INSURE: 39 R$", UDim2.new(0, 220, 0, 28), UDim2.new(0, 10, 0, 206), Color3.fromRGB(70, 60, 95))
	robuxBtn.TextSize = 12
	robuxBtn.MouseButton1Click:Connect(function()
		local folder = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes")
		local remote = folder:WaitForChild("BuyProduct") :: RemoteFunction
		local ok, msg = remote:InvokeServer("BloodInsurance")
		if not ok and tostring(msg):find("coming soon") then
			ok, msg = remote:InvokeServer("Blood_Insurance")
		end
		if msgLabel then
			msgLabel.Text = if ok then "Opening Roblox checkout…" else tostring(msg)
		end
	end)

	local crownBtn = UITheme.MakeButton(modal, "InsuranceCrowns", "⚡ INSURE: 👑30 INSTANT", UDim2.new(0, 220, 0, 28), UDim2.new(0, 240, 0, 206), UITheme.Gold)
	crownBtn.TextSize = 12
	crownBtn.TextColor3 = Color3.fromRGB(30, 20, 10)
	crownBtn.MouseButton1Click:Connect(function()
		local ok, msg = EconomyClient.SpendCrowns("Blood_Insurance")
		if msgLabel then
			msgLabel.Text = if ok then "⚡ Insured! Wall + shield (1.3x)." else tostring(msg)
		end
		EconomyClient.Refresh()
	end)

	local decreeBtn = UITheme.MakeButton(modal, "Decree", "📜 Royal Decree: end pact early (39 R$ / 👑30)", UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 238), Color3.fromRGB(50, 40, 70))
	decreeBtn.TextSize = 11
	decreeBtn.MouseButton1Click:Connect(function()
		-- Prefer instant Crowns; fallback to Robux prompt.
		local ok, msg = EconomyClient.SpendCrowns("Royal_Decree")
		if not ok then
			local folder = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes")
			local remote = folder:WaitForChild("BuyProduct") :: RemoteFunction
			ok, msg = remote:InvokeServer("RoyalDecree")
		end
		if msgLabel then
			msgLabel.Text = if ok then "📜 Decree applied." else tostring(msg)
		end
		EconomyClient.Refresh()
	end)

	gui.Parent = parent
	EconomyClient.OnChanged(refresh)
	refresh()
end

return BreachDecisionModal
