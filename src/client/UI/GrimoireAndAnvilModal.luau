--!strict
-- Arcane Citadel: Grimoire + Anvil + Loadouts modal (blueprint package 5).
-- Tab 1: weighted rolls. Tab 2: reforge / upgrade / repair / salvage.
-- Tab 3: Warden/Raider presets (click a slot to cycle owned gear).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SpellConfig = require(Shared.Configurations.SpellConfig)
local NoticeBanner = require(script.Parent.NoticeBanner)
local EconomyClient = require(script.Parent.Parent.Controllers.EconomyClient)
local CombatInputController = require(script.Parent.Parent.Controllers.CombatInputController)
local UITheme = require(script.Parent.UITheme)

local GrimoireAndAnvilModal = {}

-- Role-legal spell pools. Bulwark repairs YOUR walls and SiegeBeam melts
-- theirs, so each is only offered on the preset that can use it (the server
-- enforces the same gate on SetSpell).
local WARDEN_SPELLS = { "Aegis", "MendWard", "Blink", "Meteor", "Witchfire", "Bulwark" }
local RAIDER_SPELLS = { "Blink", "Aegis", "FrostNova", "Witchfire", "SiegeBeam" }

local RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 180),
	Rare = Color3.fromRGB(90, 160, 255),
	Epic = Color3.fromRGB(170, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 60),
	Mythic = Color3.fromRGB(230, 50, 90),
}

local modal: Frame? = nil
local pages: { [string]: Frame } = {}
local inventory: any = nil
local itemList: ScrollingFrame? = nil
local rollResult: TextLabel? = nil
local loadoutBox: Frame? = nil

local function invoke(name: string, ...: any): any
	local folder = Shared:WaitForChild("Remotes")
	local remote = folder:WaitForChild(name) :: RemoteFunction
	return remote:InvokeServer(...)
end

local function refreshAll(): ()
	inventory = invoke("GetInventory")
	EconomyClient.Refresh()
	GrimoireAndAnvilModal.Render()
end

local function traitText(item: any): string
	local parts = {}
	if item.prefix then
		table.insert(parts, item.prefix)
	end
	if item.suffix then
		table.insert(parts, item.suffix)
	end
	if #parts == 0 then
		return "no traits"
	end
	return table.concat(parts, " / ")
end

local function renderItems(): ()
	if not itemList then
		return
	end
	for _, child in itemList:GetChildren() do
		if child:IsA("TextButton") or child:IsA("Frame") then
			child:Destroy()
		end
	end
	if not inventory then
		return
	end
	local y = 0
	for _, item in inventory.items do
		local rowH = if item.fractured then 92 else 88
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, rowH)
		row.Position = UDim2.new(0, 4, 0, y)
		row.BackgroundColor3 = Color3.fromRGB(30, 24, 48)
		row.BorderSizePixel = 0
		row.Parent = itemList

		local nameLabel = UITheme.MakeLabel(row, "Name", item.name, UDim2.new(1, -8, 0, 20), UDim2.new(0, 4, 0, 2), 13)
		nameLabel.TextColor3 = RARITY_COLORS[item.rarity] or UITheme.Text
		local info = `{item.rarity} {item.slot} +{item.level} · {traitText(item)}`
		if item.fractured then
			info ..= " · 💔 FRACTURED"
		end
		UITheme.MakeLabel(row, "Info", info, UDim2.new(1, -8, 0, 16), UDim2.new(0, 4, 0, 22), 11)

		local bx = 4
		local by = 40
		local function nextSlot(w: number): (number, number)
			if bx + w > 440 then
				bx = 4
				by += 24
			end
			local x = bx
			local yy = by
			bx += w + 4
			return x, yy
		end
		local function action(text: string, remote: string)
			local x, yy = nextSlot(78)
			local btn = UITheme.MakeButton(row, text, text, UDim2.new(0, 78, 0, 22), UDim2.new(0, x, 0, yy), Color3.fromRGB(70, 60, 95))
			btn.TextSize = 11
			local uid = item.uid
			btn.MouseButton1Click:Connect(function()
				invoke(remote, uid)
				refreshAll()
			end)
		end
		action("Reforge\n25💎", "ReforgeItem")
		do
			local crownCost = if inventory then inventory.reforgeCrownCost or 15 else 15
			local x, yy = nextSlot(78)
			local btn = UITheme.MakeButton(row, "CrownReforge", `👑{crownCost}`, UDim2.new(0, 78, 0, 22), UDim2.new(0, x, 0, yy), UITheme.Gold)
			btn.TextSize = 11
			btn.TextColor3 = Color3.fromRGB(30, 20, 10)
			local uid = item.uid
			btn.MouseButton1Click:Connect(function()
				invoke("ReforgeItemCrowns", uid)
				refreshAll()
			end)
		end
		do
			local credits = if inventory then inventory.reforgeCredits or 0 else 0
			local x, yy = nextSlot(78)
			local btn = UITheme.MakeButton(row, "Credit", `🎟 ({credits})`, UDim2.new(0, 78, 0, 22), UDim2.new(0, x, 0, yy), Color3.fromRGB(70, 60, 95))
			btn.TextSize = 11
			local uid = item.uid
			btn.MouseButton1Click:Connect(function()
				invoke("ReforgeItemCredit", uid)
				refreshAll()
			end)
		end
		action("+Up", "UpgradeItem")
		if item.fractured then
			action("Repair\n15💎", "RepairItem")
			do
				local rcost = if inventory then inventory.repairCrownCost or 11 else 11
				local x, yy = nextSlot(78)
				local btn = UITheme.MakeButton(row, "CrownRepair", `👑{rcost}`, UDim2.new(0, 78, 0, 22), UDim2.new(0, x, 0, yy), UITheme.Gold)
				btn.TextSize = 11
				btn.TextColor3 = Color3.fromRGB(30, 20, 10)
				local uid = item.uid
				btn.MouseButton1Click:Connect(function()
					invoke("RepairItemCrowns", uid)
					refreshAll()
				end)
			end
		end
		action("Salvage", "SalvageItem")
		y += rowH + 4
	end
	itemList.CanvasSize = UDim2.new(0, 0, 0, y)
end

local function slotButton(parent: Instance, preset: string, slotKey: string, label: string, y: number): TextButton
	local btn = UITheme.MakeButton(parent, preset .. slotKey, label, UDim2.new(1, -8, 0, 26), UDim2.new(0, 4, 0, y), Color3.fromRGB(70, 60, 95))
	btn.TextSize = 12
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.MouseButton1Click:Connect(function()
		invoke("CycleSlot", preset, slotKey)
		refreshAll()
	end)
	return btn
end

local function renderLoadouts(): ()
	if not loadoutBox or not inventory then
		return
	end
	for _, child in loadoutBox:GetChildren() do
		child:Destroy()
	end
	UITheme.MakeLabel(loadoutBox, "Active", `Active: {inventory.active} (click a slot to cycle gear)`, UDim2.new(1, -8, 0, 20), UDim2.new(0, 4, 0, 0), 12)

	local swap = UITheme.MakeButton(loadoutBox, "Swap", `SWAP TO {if inventory.active == "Warden" then "RAIDER" else "WARDEN"}`, UDim2.new(1, -8, 0, 30), UDim2.new(0, 4, 0, 22), UITheme.Accent)
	swap.MouseButton1Click:Connect(function()
		invoke("SwapLoadout", if inventory.active == "Warden" then "Raider" else "Warden")
		refreshAll()
		CombatInputController.Refresh()
	end)

	local y = 56
	for _, preset in { "Warden", "Raider" } do
		local data = if preset == "Warden" then inventory.warden else inventory.raider
		UITheme.MakeLabel(loadoutBox, preset, `— {preset} —`, UDim2.new(1, -8, 0, 20), UDim2.new(0, 4, 0, y), 13)
		y += 22
		for _, slot in { { "WeaponUID", "Weapon" }, { "ArmorUID", "Armor" }, { "Ring1UID", "Ring 1" }, { "Ring2UID", "Ring 2" } } do
			local key = slot[1] :: string
			local label = slot[2] :: string
			local value = if key == "WeaponUID"
				then data.weapon
				elseif key == "ArmorUID" then data.armor
				elseif key == "Ring1UID" then data.ring1
				else data.ring2
			slotButton(loadoutBox, preset, key, `{label}: {value}`, y)
			y += 30
		end
		-- Spell hotbar assignment. Without this there was no way to change
		-- SpellQ/E/R at all, so five of the eight SpellConfig spells could
		-- never be reached on either preset.
		local spells = data.spells or {}
		for _, key in { "Q", "E", "R" } do
			local k = key :: string
			local current = spells[k]
			local spec = if current then SpellConfig[current] else nil
			local label = if spec then spec.Name else "(empty)"
			local btn = UITheme.MakeButton(
				loadoutBox,
				`Spell{k}`,
				`{k}: {label}  ▸ change`,
				UDim2.new(1, -8, 0, 26),
				UDim2.new(0, 4, 0, y),
				Color3.fromRGB(60, 52, 92)
			)
			btn.TextSize = 11
			btn.MouseButton1Click:Connect(function()
				-- Cycle only through role-legal spells, so the button never
				-- offers an assignment the server will reject.
				local options = if preset == "Warden" then WARDEN_SPELLS else RAIDER_SPELLS
				local chosen = options[1]
				for idx, id in options do
					if id == current then
						chosen = options[idx % #options + 1]
						break
					end
				end
				if invoke("SetSpell", preset, k, chosen) ~= true then
					NoticeBanner.ShowLocal("⚠ Could not assign that spell.", { 255, 150, 60 })
				end
				refreshAll()
				CombatInputController.Refresh()
			end)
			y += 30
		end
		y += 6
	end
end

function GrimoireAndAnvilModal.Render(): ()
	renderItems()
	renderLoadouts()
end

function GrimoireAndAnvilModal.Build(parent: Instance): ()
	local gui = UITheme.MakeScreenGui("GrimoireAndAnvilModal")

	local toggle = UITheme.MakeButton(gui, "Toggle", "⚔ GRIMOIRE", UDim2.new(0, 150, 0, 34), UDim2.new(1, -160, 1, -44), UITheme.Panel)
	toggle.MouseButton1Click:Connect(function()
		if modal then
			if not modal.Visible then
				refreshAll()
			end
			modal.Visible = not modal.Visible
		end
	end)

	modal = UITheme.MakePanel(gui, "Modal", UDim2.new(0, 460, 0, 430), UDim2.new(0.5, -230, 0.5, -215))
	modal.Visible = false

	local tabBarY = 6
	local function tab(name: string, x: number)
		local btn = UITheme.MakeButton(modal, name, name, UDim2.new(0, 140, 0, 28), UDim2.new(0, 10 + x * 148, 0, tabBarY), Color3.fromRGB(70, 60, 95))
		btn.MouseButton1Click:Connect(function()
			for key, page in pages do
				page.Visible = key == name
			end
		end)
	end
	tab("Roll", 0)
	tab("Anvil", 1)
	tab("Loadouts", 2)

	-- Roll page.
	local rollPage = Instance.new("Frame")
	rollPage.Name = "Roll"
	rollPage.Size = UDim2.new(1, -20, 1, -50)
	rollPage.Position = UDim2.new(0, 10, 0, 40)
	rollPage.BackgroundTransparency = 1
	rollPage.Parent = modal
	pages.Roll = rollPage
	-- Live wallet header. This modal previously showed no Vault or Shard
	-- balance anywhere, so the player could not tell whether a roll was even
	-- affordable.
	local balanceLabel = UITheme.MakeLabel(rollPage, "Balance", "", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 0), 12)
	balanceLabel.TextColor3 = UITheme.Gold
	UITheme.MakeLabel(rollPage, "Info", "Roll the Base Grimoire for Staves, Vestments & Rings.\nCost: 1,000 Vault Souls (Sanctuary only).", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 22), 13)
	local rollBtn = UITheme.MakeButton(rollPage, "DoRoll", "🎲 ROLL GRIMOIRE", UDim2.new(0, 220, 0, 40), UDim2.new(0, 0, 0, 68), UITheme.Gold)
	rollBtn.TextColor3 = Color3.fromRGB(30, 20, 10)
	rollResult = UITheme.MakeLabel(rollPage, "Result", "", UDim2.new(1, 0, 0, 120), UDim2.new(0, 0, 0, 116), 13)
	rollResult.TextWrapped = true
	rollBtn.MouseButton1Click:Connect(function()
		local item = invoke("GrimoireRoll")
		if item ~= nil then
			rollResult.Text = `✨ {item.name} [{item.rarity}]\nTraits: {traitText(item)}`
		else
			rollResult.Text = "Roll failed (need 1,000 Vault Souls in Sanctuary)."
		end
		refreshAll()
	end)

	local mythicBtn = UITheme.MakeButton(rollPage, "MythicRoll", "💎 MYTHIC ROLL (50 Shards, Epic+)", UDim2.new(0, 260, 0, 34), UDim2.new(0, 0, 0, 206), Color3.fromRGB(170, 90, 255))
	mythicBtn.MouseButton1Click:Connect(function()
		local item = invoke("GrimoireMythicRoll")
		if item ~= nil then
			rollResult.Text = `💎 {item.name} [{item.rarity}]\nTraits: {traitText(item)}`
		else
			rollResult.Text = "Mythic roll failed (need 50 Blood Shards, Sanctuary only)."
		end
		refreshAll()
	end)

	local autoBtn = UITheme.MakeButton(rollPage, "AutoRoll", "[ ] Auto-roll (Dual Pass)", UDim2.new(0, 260, 0, 30), UDim2.new(0, 0, 0, 244), Color3.fromRGB(70, 60, 95))
	autoBtn.MouseButton1Click:Connect(function()
		local snap = EconomyClient.Get()
		if not snap or not snap.hasDual then
			rollResult.Text = "Auto-roll needs the Dual Loadout Pass (shop)."
			return
		end
		local enabled = invoke("ToggleAutoRoll", not snap.autoRoll)
		-- Sync the label from the server's answer, not from the requested
		-- value, so a rejected toggle cannot leave the button lying.
		autoBtn.Text = if enabled then "[x] Auto-roll ON" else "[ ] Auto-roll (Dual Pass)"
		UITheme.SetButtonColor(autoBtn, if enabled then UITheme.SafeGreen else Color3.fromRGB(70, 60, 95))
		refreshAll()
	end)

	-- Anvil page.
	local anvilPage = Instance.new("Frame")
	anvilPage.Name = "Anvil"
	anvilPage.Size = UDim2.new(1, -20, 1, -50)
	anvilPage.Position = UDim2.new(0, 10, 0, 40)
	anvilPage.BackgroundTransparency = 1
	anvilPage.Visible = false
	anvilPage.Parent = modal
	pages.Anvil = anvilPage
	itemList = Instance.new("ScrollingFrame")
	itemList.Name = "Items"
	itemList.Size = UDim2.new(1, 0, 1, 0)
	itemList.BackgroundTransparency = 1
	itemList.ScrollBarThickness = 6
	itemList.Parent = anvilPage

	-- Loadouts page.
	local loadPage = Instance.new("Frame")
	loadPage.Name = "Loadouts"
	loadPage.Size = UDim2.new(1, -20, 1, -50)
	loadPage.Position = UDim2.new(0, 10, 0, 40)
	loadPage.BackgroundTransparency = 1
	loadPage.Visible = false
	loadPage.Parent = modal
	pages.Loadouts = loadPage
	loadoutBox = Instance.new("Frame")
	loadoutBox.Name = "Box"
	loadoutBox.Size = UDim2.new(1, 0, 1, 0)
	loadoutBox.BackgroundTransparency = 1
	loadoutBox.Parent = loadPage

	gui.Parent = parent

	-- Live wallet + affordance feedback. This modal had NO
	-- EconomyClient.OnChanged subscription at all, so a purchase made
	-- elsewhere left the roll page showing stale affordability the whole
	-- time it was open.
	EconomyClient.OnChanged(function()
		if not modal or not modal.Visible then
			return
		end
		local snap = EconomyClient.Get()
		if not snap then
			return
		end
		if balanceLabel then
			balanceLabel.Text =
				`🏦 {UITheme.FormatSouls(snap.vault or 0)} Souls   💎 {UITheme.FormatSouls(snap.shards or 0)} Shards`
		end
		rollBtn.Text = if (snap.vault or 0) >= 1000 and not snap.isPact
			then "🎲 ROLL GRIMOIRE — 1,000"
			else "🎲 ROLL GRIMOIRE — need 1,000 Souls"
		mythicBtn.Text = if (snap.shards or 0) >= 50 and not snap.isPact
			then "💎 MYTHIC ROLL (50 Shards, Epic+)"
			else "💎 MYTHIC ROLL — need 50 Shards"
		autoBtn.Text = if snap.autoRoll then "[x] Auto-roll ON" else "[ ] Auto-roll (Dual Pass)"
		UITheme.SetButtonColor(autoBtn, if snap.autoRoll then UITheme.SafeGreen else Color3.fromRGB(70, 60, 95))
	end)
end

return GrimoireAndAnvilModal
