--!strict
-- Arcane Citadel: dual-checkout shop + Crown Treasury (blueprint 1.7 / package 8).
-- Every row: [Raw Robux 1.0x (slow prompt)] | [Eclipse Crowns 1.3x INSTANT (0ms)].
-- Crown packs (99 R$ min) force bulk commitment; leftover Crowns = sunk-cost retention.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyClient = require(script.Parent.Parent.Controllers.EconomyClient)
local UITheme = require(script.Parent.UITheme)

local MonetizationConfig = require(Shared.Configurations.MonetizationConfig)

local ShopModal = {}

local modal: Frame? = nil
local box: ScrollingFrame? = nil
local msgLabel: TextLabel? = nil

local CROWN_ORDER = { "Crown_Pouch_100", "Crown_Coffer_265", "Crown_Treasury_550", "Crown_Sovereign_1500" }
local CATALOG_ORDER = {
	"Blood_Insurance",
	"Vengeance_Curse",
	"Emergency_Mercenaries",
	"Extra_Soul_Tethers",
	"Summon_Wraith_Colossus",
	"Royal_Decree",
	"Master_Alchemist_Pass",
	"Dual_Loadout_Pass",
	"Anvil_Reforge_1x",
	"Anvil_Reforge_10x",
	"BloodShards_150",
	"BloodShards_500",
	"BloodShards_2500",
}

local function invoke(name: string, ...: any): any
	local folder = Shared:WaitForChild("Remotes")
	local remote = folder:WaitForChild(name) :: RemoteFunction
	return remote:InvokeServer(...)
end

local function sectionLabel(y: number, text: string): number
	local lbl = Instance.new("TextLabel")
	lbl.Name = "Section"
	lbl.Size = UDim2.new(1, -8, 0, 22)
	lbl.Position = UDim2.new(0, 4, 0, y)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 13
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextColor3 = UITheme.Gold
	lbl.Text = text
	lbl.Parent = box
	return y + 24
end

local function crownPackRow(y: number, bundleKey: string): number
	local bundle = MonetizationConfig.CrownBundles[bundleKey]
	if not bundle then
		return y
	end
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -8, 0, 52)
	frame.Position = UDim2.new(0, 4, 0, y)
	frame.BackgroundColor3 = Color3.fromRGB(45, 32, 12)
	frame.BorderSizePixel = 0
	frame.Parent = box
	UITheme.MakeLabel(frame, "Title", `👑 {bundle.CrownsGranted} Crowns — {bundle.RobuxCost} R$`, UDim2.new(1, -110, 0, 20), UDim2.new(0, 6, 0, 2), 12)
	UITheme.MakeLabel(frame, "Desc", "Bulk 1.3x-1.5x value. Leftover Crowns keep you coming back.", UDim2.new(1, -110, 0, 26), UDim2.new(0, 6, 0, 22), 10).TextWrapped = true
	local btn = UITheme.MakeButton(frame, "Buy", `{bundle.RobuxCost} R$`, UDim2.new(0, 96, 0, 30), UDim2.new(1, -102, 0, 11), UITheme.Gold)
	btn.TextColor3 = Color3.fromRGB(30, 20, 10)
	btn.MouseButton1Click:Connect(function()
		local ok, msg = invoke("BuyCrownPack", bundleKey)
		if msgLabel then
			msgLabel.Text = if ok then "Opening Roblox checkout for Crowns…" else tostring(msg)
		end
	end)
	return y + 56
end

local function dualRow(y: number, catalogKey: string, owned: boolean): number
	local entry = MonetizationConfig.Catalog[catalogKey]
	if not entry then
		return y
	end
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -8, 0, 62)
	frame.Position = UDim2.new(0, 4, 0, y)
	frame.BackgroundColor3 = Color3.fromRGB(30, 24, 48)
	frame.BorderSizePixel = 0
	frame.Parent = box
	UITheme.MakeLabel(frame, "Title", entry.Name, UDim2.new(1, -8, 0, 20), UDim2.new(0, 6, 0, 2), 12)
	local sub = if entry.BloodShardGrant
		then `+{entry.BloodShardGrant} Shards · Anvil + Auction House`
		elseif string.find(catalogKey, "Pass") then "Permanent pass. Never resets."
		else "Panic / siege / reforge. 1.3x Crown = instant, no dialog."
	UITheme.MakeLabel(frame, "Desc", sub, UDim2.new(1, -8, 0, 16), UDim2.new(0, 6, 0, 22), 10).TextWrapped = true

	if owned then
		local ownedLbl = UITheme.MakeLabel(frame, "Owned", "OWNED", UDim2.new(0, 190, 0, 22), UDim2.new(1, -196, 0, 36), 12)
		ownedLbl.TextColor3 = Color3.fromRGB(140, 220, 160)
		return y + 66
	end

	-- Left: Raw Robux (1.0x, slow 2-step prompt).
	local robuxBtn = UITheme.MakeButton(frame, "Robux", `{entry.RawRobuxPrice} R$`, UDim2.new(0, 92, 0, 24), UDim2.new(1, -196, 0, 36), Color3.fromRGB(70, 60, 95))
	robuxBtn.TextSize = 12
	robuxBtn.MouseButton1Click:Connect(function()
		local ok, msg: any
		-- Passes prefer Game Pass checkout when configured, else catalog product.
		if catalogKey == "Master_Alchemist_Pass" then
			ok, msg = invoke("BuyPass", "Alchemist")
			if not ok and tostring(msg):find("coming soon") then
				ok, msg = invoke("BuyProduct", catalogKey)
			end
		elseif catalogKey == "Dual_Loadout_Pass" then
			ok, msg = invoke("BuyPass", "DualLoadout")
			if not ok and tostring(msg):find("coming soon") then
				ok, msg = invoke("BuyProduct", catalogKey)
			end
		else
			ok, msg = invoke("BuyProduct", catalogKey)
			-- Legacy fallback for panic items (ProductConfig keys) when catalog IDs are 0.
			if not ok and tostring(msg):find("coming soon") then
				local legacyFallback: { [string]: string } = {
					Blood_Insurance = "BloodInsurance",
					Vengeance_Curse = "VengeanceCurse",
					Emergency_Mercenaries = "MercenaryPact",
					Extra_Soul_Tethers = "ExtraTethers",
					Summon_Wraith_Colossus = "WraithColossus",
					Royal_Decree = "RoyalDecree",
					Anvil_Reforge_1x = "AnvilReforge1",
					Anvil_Reforge_10x = "AnvilReforge10",
				}
				local fb = legacyFallback[catalogKey]
				if fb then
					ok, msg = invoke("BuyProduct", fb)
				end
			end
		end
		if msgLabel then
			msgLabel.Text = if ok then "Opening Roblox checkout…" else tostring(msg)
		end
		if string.find(catalogKey, "Pass") then
			task.delay(7, function()
				invoke("RefreshPasses")
				EconomyClient.Refresh()
				ShopModal.Render()
			end)
		end
	end)

	-- Right: Eclipse Crowns (1.3x value, 1-click instant, 0ms).
	local crownBtn = UITheme.MakeButton(frame, "Crowns", `👑{entry.CrownPrice} INSTANT`, UDim2.new(0, 92, 0, 24), UDim2.new(1, -98, 0, 36), UITheme.Gold)
	crownBtn.TextSize = 12
	crownBtn.TextColor3 = Color3.fromRGB(30, 20, 10)
	crownBtn.MouseButton1Click:Connect(function()
		local ok, msg = EconomyClient.SpendCrowns(catalogKey)
		if msgLabel then
			msgLabel.Text = if ok then "⚡ Instant! Crowns spent (1.3x value)." else tostring(msg)
		end
		EconomyClient.Refresh()
		task.delay(0.5, function()
			ShopModal.Render()
		end)
	end)
	return y + 66
end

-- Signature of everything the rendered rows depend on. The server pushes a
-- snapshot every second, and the previous version rebuilt all 17 rows on
-- every push — which resets ScrollingFrame.CanvasPosition, so the list
-- snapped back to the top once per second and could never be scrolled.
local lastRenderKey: string? = nil

local function renderKey(): string
	local snap = EconomyClient.Get()
	if not snap then
		return "nil"
	end
	local ownedAlch = snap.hasAlchemist == true
	local ownedDual = snap.hasDual == true
	-- Crown packs are locked/unlocked by affordability, so the balance has to
	-- be part of the key.
	return table.concat({
		tostring(snap.crowns or 0),
		tostring(ownedAlch),
		tostring(ownedDual),
	}, "|")
end

function ShopModal.Render(force: boolean?): ()
	if not box then
		return
	end
	local key = renderKey()
	if not force and key == lastRenderKey then
		return
	end
	lastRenderKey = key

	for _, child in box:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") and child.Name == "Section" then
			child:Destroy()
		end
	end
	local snap = EconomyClient.Get()
	local hasAlch = snap and snap.hasAlchemist == true
	local hasDual = snap and snap.hasDual == true
	local crowns = if snap then snap.crowns or 0 else 0
	if msgLabel then
		msgLabel.Text = `👑 {crowns} Crowns (1.3x value, 1-click) · Robux = slow 2-step prompt`
	end
	local y = 0
	y = sectionLabel(y, "👑 CROWN TREASURY — buy bulk, save 30-50% (min 99 R$)")
	for _, bkey in CROWN_ORDER do
		y = crownPackRow(y, bkey)
	end
	y = sectionLabel(y, "⚔ DUAL CHECKOUT — R$ slow vs Crowns 1.3x INSTANT")
	for _, ckey in CATALOG_ORDER do
		local owned = (ckey == "Master_Alchemist_Pass" and hasAlch) or (ckey == "Dual_Loadout_Pass" and hasDual)
		y = dualRow(y, ckey, owned)
	end
	box.CanvasSize = UDim2.new(0, 0, 0, y)
end

-- Single entry point for opening/closing the shop, so the crown-balance
-- button in TopEconomyHUD does not have to reach in via FindFirstChild
-- string matching (which silently opened an EMPTY modal, because Render was
-- only ever called from this module's own toggle).
function ShopModal.Toggle(): ()
	if not modal then
		return
	end
	if modal.Visible then
		modal.Visible = false
		return
	end
	ShopModal.Render(true)
	modal.Visible = true
end

function ShopModal.Build(parent: Instance): ()
	local gui = UITheme.MakeScreenGui("ShopModal")

	-- Second toolbar row (y=50). The economy bar owns y=10..44 across the
	-- centre of the screen; at 1366px wide these used to land directly on
	-- top of the Crowns button and covered ~86% of it.
	local toggle = UITheme.MakeButton(gui, "Toggle", "+SHARDS 👑", UDim2.new(0, 130, 0, 34), UDim2.new(1, -150, 0, 50), UITheme.Gold)
	toggle.TextColor3 = Color3.fromRGB(30, 20, 10)
	toggle.MouseButton1Click:Connect(function()
		ShopModal.Toggle()
	end)

	modal = UITheme.MakePanel(gui, "Shop", UDim2.new(0, 430, 0, 420), UDim2.new(1, -440, 0, 50))
	modal.Visible = false
	UITheme.MakeLabel(modal, "Title", "💎 SHARD SHOP + 👑 CROWN TREASURY", UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 6), 14)
	msgLabel = UITheme.MakeLabel(modal, "Msg", "Crowns = 1.3x value, 1-click instant.", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 30), 11)

	box = Instance.new("ScrollingFrame")
	box.Name = "Items"
	box.Size = UDim2.new(1, -20, 1, -58)
	box.Position = UDim2.new(0, 10, 0, 50)
	box.BackgroundTransparency = 1
	box.ScrollBarThickness = 6
	box.Parent = modal

	gui.Parent = parent
	EconomyClient.OnChanged(function()
		if modal and modal.Visible then
			task.spawn(ShopModal.Render)
		end
	end)
end

return ShopModal
