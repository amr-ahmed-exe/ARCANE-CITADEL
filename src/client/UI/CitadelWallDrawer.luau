--!strict
-- Arcane Citadel: wall management drawer (blueprint package 2).
-- HP bars, defense ratio vs threat, upgrade / elixir / auto-renew / unlock.

local Players = game:GetService("Players")

local EconomyClient = require(script.Parent.Parent.Controllers.EconomyClient)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local NoticeBanner = require(script.Parent.NoticeBanner)
local UITheme = require(script.Parent.UITheme)

local CitadelWallDrawer = {}

-- Mirrors GameService's caps so the UI can explain a refusal instead of
-- silently doing nothing.
local SERVANT_MAX = 3
local TRAP_MAX = 5

local WALL_NAMES = { [1] = "Wall 1 · Inner Sanctum", [2] = "Wall 2 · Middle Ward", [3] = "Wall 3 · Outer Frontier" }
local WALL_SHORT = { [1] = "Wall 1", [2] = "Wall 2", [3] = "Wall 3" }

local cards: { [number]: Frame } = {}
local lastFrac: { [number]: number } = {}
-- Cached child references. The refresh loop runs 3x per second forever and
-- used to chain FindFirstChild("HPBack"):FindFirstChild("HPFill") unguarded.
local hpFills: { [number]: Frame } = {}
local statusLabels: { [number]: TextLabel } = {}
local upgradeBtns: { [number]: TextButton } = {}
local brewBtns: { [number]: TextButton } = {}
local autoBtns: { [number]: TextButton } = {}
local unlockBtns: { [number]: TextButton } = {}
local repairBtns: { [number]: TextButton } = {}

local function setAutoRenewVisual(button: TextButton, on: boolean): ()
	button.Text = if on then "[x] Auto-Renew (+50%)" else "[ ] Auto-Renew (+50%)"
	UITheme.SetButtonColor(button, if on then UITheme.SafeGreen else Color3.fromRGB(70, 60, 95))
end

local function buildCard(parent: Instance, wallIndex: number): Frame
	local card = UITheme.MakePanel(parent, `Card{wallIndex}`, UDim2.new(1, -16, 0, 172), UDim2.new(0, 8, 0, 8 + (wallIndex - 1) * 180))
	UITheme.MakeLabel(card, "Title", WALL_NAMES[wallIndex], UDim2.new(1, -16, 0, 20), UDim2.new(0, 8, 0, 4), 13)

	local hpBack = Instance.new("Frame")
	hpBack.Name = "HPBack"
	hpBack.Size = UDim2.new(1, -16, 0, 12)
	hpBack.Position = UDim2.new(0, 8, 0, 28)
	hpBack.BackgroundColor3 = Color3.fromRGB(40, 30, 55)
	hpBack.BorderSizePixel = 0
	hpBack.Parent = card

	local hpFill = Instance.new("Frame")
	hpFill.Name = "HPFill"
	hpFill.Size = UDim2.new(1, 0, 1, 0)
	hpFill.BackgroundColor3 = UITheme.SafeGreen
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBack
	hpFills[wallIndex] = hpFill

	statusLabels[wallIndex] = UITheme.MakeLabel(card, "Status", "", UDim2.new(1, -16, 0, 18), UDim2.new(0, 8, 0, 42), 12)

	local upgradeBtn = UITheme.MakeButton(card, "Upgrade", "Upgrade", UDim2.new(0, 150, 0, 28), UDim2.new(0, 8, 0, 64))
	upgradeBtns[wallIndex] = upgradeBtn
	upgradeBtn.MouseButton1Click:Connect(function()
		local snap = EconomyClient.Get()
		if not EconomyClient.UpgradeWall(wallIndex) then
			local why = "Not enough Vault Souls, or the wall is already maxed."
			if snap and snap.isPact then
				why = "The Vault is sealed during a Blood Pact."
			end
			NoticeBanner.ShowLocal(`⚠ Upgrade failed — {why}`, { 255, 150, 60 })
		end
		EconomyClient.Refresh()
	end)

	local brewBtn = UITheme.MakeButton(card, "Brew", "Brew 15m Elixir", UDim2.new(0, 150, 0, 28), UDim2.new(0, 166, 0, 64), UITheme.Gold)
	brewBtns[wallIndex] = brewBtn
	brewBtn.TextColor3 = Color3.fromRGB(30, 20, 10)
	brewBtn.MouseButton1Click:Connect(function()
		-- Carry the CURRENT server-side auto-renew intent, not a local flag.
		-- The old local `autoOn` was never synced, so pressing "Brew" turned
		-- auto-renew OFF on the server while the checkbox still read [x].
		local snap = EconomyClient.Get()
		local wall = snap and snap.walls and snap.walls[wallIndex]
		local autoOn = if wall then wall.autoRenew == true else false
		if not EconomyClient.PurchaseElixir(wallIndex, autoOn) then
			NoticeBanner.ShowLocal("⚠ Elixir failed — not enough Souls, or the wall has fallen.", { 255, 150, 60 })
		end
		EconomyClient.Refresh()
	end)

	local autoBtn = UITheme.MakeButton(card, "Auto", "[ ] Auto-Renew (+50%)", UDim2.new(0, 308, 0, 26), UDim2.new(0, 8, 0, 98), Color3.fromRGB(70, 60, 95))
	autoBtns[wallIndex] = autoBtn
	-- Dedicated endpoint: this used to call PurchaseElixir, so merely
	-- flipping the checkbox silently bought a 15-minute elixir.
	autoBtn.MouseButton1Click:Connect(function()
		local snap = EconomyClient.Get()
		local w = snap and snap.walls and snap.walls[wallIndex]
		local next = not (w and w.autoRenew == true)
		if EconomyClient.SetAutoRenew(wallIndex, next) then
			setAutoRenewVisual(autoBtn, next)
			NoticeBanner.ShowLocal(
				if next then "🔁 Auto-Renew ON (+50% surcharge)." else "🔁 Auto-Renew OFF.",
				{ 150, 220, 160 }
			)
		end
		EconomyClient.Refresh()
	end)
	setAutoRenewVisual(autoBtn, false)

	local unlockBtn = UITheme.MakeButton(card, "Unlock", "Unlock", UDim2.new(0, 308, 0, 28), UDim2.new(0, 8, 0, 130), UITheme.SafeGreen)
	unlockBtns[wallIndex] = unlockBtn
	unlockBtn.MouseButton1Click:Connect(function()
		if not EconomyClient.UnlockWall(wallIndex) then
			NoticeBanner.ShowLocal("⚠ Unlock failed — not enough Vault Souls, or already unlocked.", { 255, 150, 60 })
		end
		EconomyClient.Refresh()
	end)

	-- Mid-fight soul repair (shares the Unlock slot: mutually exclusive).
	local repairBtn = UITheme.MakeButton(card, "Repair", "Repair", UDim2.new(0, 308, 0, 28), UDim2.new(0, 8, 0, 130), Color3.fromRGB(200, 90, 60))
	repairBtns[wallIndex] = repairBtn
	repairBtn.MouseButton1Click:Connect(function()
		local ok = EconomyClient.RepairWall(wallIndex)
		if not ok then
			NoticeBanner.ShowLocal("⚠ Repair failed — not enough Souls, or on cooldown.", { 255, 150, 60 })
		end
		EconomyClient.Refresh()
	end)

	return card
end

local function refresh(): ()
	local snap = EconomyClient.Get()
	if not snap then
		return
	end
	local drawer = cards[1] and cards[1].Parent and cards[1].Parent.Parent
	local ascendBtn = if drawer then drawer:FindFirstChild("Ascend") :: TextButton? else nil
	if ascendBtn then
		local maxed = true
		for i = 1, 3 do
			local w = snap.walls[i]
			if not w.unlocked or (w.level or 0) < (snap.maxLevel or 5) then
				maxed = false
				break
			end
		end
		if (snap.rank or 1) >= 4 then
			ascendBtn.Text = "★ MAX RANK"
		elseif maxed and not snap.isPact then
			ascendBtn.Text = `☄ ASCEND TO {snap.rank + 1}!`
		else
			ascendBtn.Text = `☄ ASCEND (max all walls Lv{snap.maxLevel or 5})`
		end
	end
	for i = 1, 3 do
		local w = snap.walls and snap.walls[i]
		local hpFill = hpFills[i]
		if not w or not hpFill then
			continue
		end
		local frac = if (w.maxHP or 0) > 0 then math.clamp(w.hp / w.maxHP, 0, 1) else 0
		hpFill.Size = UDim2.new(frac, 0, 1, 0)
		hpFill.BackgroundColor3 = if w.collapsed then UITheme.Crimson
			elseif frac < 0.3 then UITheme.Crimson
			elseif frac < 0.7 then UITheme.Gold
			else UITheme.SafeGreen

		-- Wall-critical alarm (edge-triggered: crossing below 25% once).
		if w.unlocked and not w.collapsed and frac < 0.25 and (lastFrac[i] == nil or lastFrac[i] >= 0.25) then
			SoundController.Cue("Alarm")
			NoticeBanner.ShowLocal(`⚠ {WALL_SHORT[i]} CRITICAL — repair it from this panel!`, { 255, 60, 70 })
		end
		lastFrac[i] = frac

		local status = statusLabels[i]
		if status then
			if not w.unlocked then
				status.Text = `🔒 LOCKED — unlock for {UITheme.FormatSouls(w.unlockCost or 0)} Vault Souls`
			elseif w.collapsed then
				status.Text = "💀 COLLAPSED FOR SESSION"
			else
				local bleed = if w.ratio < w.threat then " — BLEEDING!" else " — HOLDING"
				local elixir = if w.elixirRemaining > 0 then ` · Elixir {UITheme.FormatTime(w.elixirRemaining)}` else ""
				status.Text = string.format("%.2fx / %.2fx%s · Lv %d%s", w.ratio or 0, w.threat or 0, bleed, w.level or 0, elixir)
			end
		end

		local upgradeBtn = upgradeBtns[i]
		if upgradeBtn then
			upgradeBtn.Text = `[ Upgrade Lv{w.level or 0} — {UITheme.FormatSouls(w.upgradeCost or 0)} ]`
			upgradeBtn.Visible = w.unlocked == true
		end
		local brewBtn = brewBtns[i]
		if brewBtn then
			-- The server already prices this for the wall's current mode
			-- (auto-renew surcharge, waived by the Alchemist Pass).
			brewBtn.Text = `[ Brew Elixir — {UITheme.FormatSouls(w.elixirCost or 0)} ]`
			brewBtn.Visible = w.unlocked == true
		end
		-- Server is the single source of truth for the toggle.
		local autoBtn = autoBtns[i]
		if autoBtn then
			autoBtn.Visible = w.unlocked == true
			setAutoRenewVisual(autoBtn, w.autoRenew == true)
		end
		local unlockBtn = unlockBtns[i]
		if unlockBtn then
			unlockBtn.Text = `[ Unlock — {UITheme.FormatSouls(w.unlockCost or 0)} Vault ]`
			unlockBtn.Visible = not w.unlocked
		end
		local repairBtn = repairBtns[i]
		if repairBtn then
			repairBtn.Text = `[ Repair +20% HP — {UITheme.FormatSouls(w.repairCost or 0)} ]`
			repairBtn.Visible = w.unlocked and not w.collapsed and w.hp < w.maxHP
		end
	end
end

function CitadelWallDrawer.Build(parent: Instance): ()
	local gui = UITheme.MakeScreenGui("CitadelWallDrawer")
	local drawer = UITheme.MakePanel(gui, "Drawer", UDim2.new(0, 340, 0, 500), UDim2.new(0, 10, 0, 110))
	UITheme.MakeLabel(drawer, "Header", "🏰 CITADEL WALLS", UDim2.new(1, -56, 0, 22), UDim2.new(0, 8, 0, 4), 15)
	local collapsed = false
	local collapseBtn = UITheme.MakeButton(drawer, "Collapse", "—", UDim2.new(0, 32, 0, 22), UDim2.new(1, -40, 0, 4), Color3.fromRGB(70, 60, 95))
	collapseBtn.MouseButton1Click:Connect(function()
		collapsed = not collapsed
		collapseBtn.Text = if collapsed then "+" else "—"
		for _, child in drawer:GetChildren() do
			if child ~= collapseBtn and (child :: Instance).Name ~= "Header" then
				(child :: GuiObject).Visible = not collapsed
			end
		end
		drawer.Size = if collapsed then UDim2.new(0, 340, 0, 34) else UDim2.new(0, 340, 0, 500)
	end)
	local hireBtn = UITheme.MakeButton(drawer, "Hire", "👻 Hire Servant (2,000)", UDim2.new(1, -16, 0, 28), UDim2.new(0, 8, 0, 26), Color3.fromRGB(90, 70, 140))
	hireBtn.TextSize = 12
	hireBtn.MouseButton1Click:Connect(function()
		local snap = EconomyClient.Get()
		local count = (snap and snap.servants) or 0
		if count >= SERVANT_MAX then
			NoticeBanner.ShowLocal(`⚠ Servant cap reached ({SERVANT_MAX}).`, { 255, 150, 60 })
			return
		end
		if not EconomyClient.HireServant() then
			NoticeBanner.ShowLocal("⚠ Could not hire — not enough Souls.", { 255, 150, 60 })
		end
		EconomyClient.Refresh()
	end)

	-- Rune traps had a full server implementation (1,500 souls, cap 5) but
	-- no client UI at all, so the feature was unreachable in practice.
	local trapBtn = UITheme.MakeButton(drawer, "Trap", "🪤 Set Rune Trap (1,500)", UDim2.new(1, -16, 0, 28), UDim2.new(0, 8, 0, 56), Color3.fromRGB(120, 70, 60))
	trapBtn.TextSize = 12
	trapBtn.MouseButton1Click:Connect(function()
		local snap = EconomyClient.Get()
		local count = (snap and snap.traps) or 0
		if count >= TRAP_MAX then
			NoticeBanner.ShowLocal(`⚠ Trap cap reached ({TRAP_MAX}).`, { 255, 150, 60 })
			return
		end
		local mouse = Players.LocalPlayer:GetMouse()
		if not EconomyClient.PlaceTrap(mouse.Hit.Position) then
			NoticeBanner.ShowLocal("⚠ Could not place a trap — not enough Souls.", { 255, 150, 60 })
		end
		EconomyClient.Refresh()
	end)
	local ascendBtn = UITheme.MakeButton(drawer, "Ascend", "☄ ASCEND", UDim2.new(1, -16, 0, 28), UDim2.new(0, 8, 0, 88), UITheme.Gold)
	ascendBtn.TextColor3 = Color3.fromRGB(30, 20, 10)
	ascendBtn.TextSize = 12
	ascendBtn.MouseButton1Click:Connect(function()
		local ok, msg = EconomyClient.Ascend()
		if ok then
			NoticeBanner.ShowLocal("☄ ASCENDED! Your Citadel ranks up.", { 255, 220, 130 })
		else
			NoticeBanner.ShowLocal(`☄ Cannot ascend — {tostring(msg)}`, { 255, 150, 60 })
		end
		EconomyClient.Refresh()
	end)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Cards"
	scroll.Size = UDim2.new(1, -16, 1, -122)
	scroll.Position = UDim2.new(0, 8, 0, 122)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 3 * 180)
	scroll.Parent = drawer
	for i = 1, 3 do
		cards[i] = buildCard(scroll, i)
		-- stack cards inside the scroll canvas
		cards[i].Position = UDim2.new(0, 0, 0, (i - 1) * 180)
		cards[i].Size = UDim2.new(1, -4, 0, 172)
	end
	gui.Parent = parent
	EconomyClient.OnChanged(refresh)
	refresh()
end

return CitadelWallDrawer
