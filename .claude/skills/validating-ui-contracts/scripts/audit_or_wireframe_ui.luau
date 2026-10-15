local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
assert(RunService:IsEdit(), "ABORT: Must run in Roblox Studio Edit Mode!")

local REQUIRED_SCREENS = {
	TopEconomyHUD = {
		{ Name = "ToggleBloodPactBtn", Action = "ToggleBloodPact" },
		{ Name = "OpenCrownTreasuryBtn", Action = "OpenCrownTreasury" },
	},
	CitadelWallDrawer = {
		{ Name = "UpgradeWall1Btn", Action = "UpgradeWall", WallIndex = 1 },
		{ Name = "UpgradeWall2Btn", Action = "UpgradeWall", WallIndex = 2 },
		{ Name = "UpgradeWall3Btn", Action = "UpgradeWall", WallIndex = 3 },
		{ Name = "BuyElixir2Btn", Action = "PurchaseElixir", WallIndex = 2 },
		{ Name = "BuyElixir3Btn", Action = "PurchaseElixir", WallIndex = 3 },
		{ Name = "AutoRenew2Toggle", Action = "ToggleAutoRenewElixir", WallIndex = 2 },
		{ Name = "AutoRenew3Toggle", Action = "ToggleAutoRenewElixir", WallIndex = 3 },
	},
	BreachDecisionModal = {
		{ Name = "AcceptDefeatBank67Btn", Action = "BreachAcceptDefeat" },
		{ Name = "HoldInnerLineBtn", Action = "BreachHoldLine" },
		{ Name = "BloodInsuranceCrownsBtn", Action = "SpendEclipseCrowns", CatalogKey = "Blood_Insurance" },
		{ Name = "BloodInsuranceRobuxBtn", Action = "PromptRobuxProduct", CatalogKey = "Blood_Insurance" },
	},
	GlobalRaidBrowser = {
		{ Name = "RefreshRaidsBtn", Action = "RefreshRaidBrowser" },
		{ Name = "InvadeTarget1Btn", Action = "InvadeSelectedTarget" },
	},
	GrimoireAndAnvilModal = {
		{ Name = "RollGrimoireBtn", Action = "RollGrimoire" },
		{ Name = "ToggleAutoRollBtn", Action = "ToggleAutoRoll" },
		{ Name = "ReforgeShardsBtn", Action = "ReforgeWeaponTrait", Currency = "BloodShards" },
		{ Name = "ReforgeCrownsBtn", Action = "SpendEclipseCrowns", CatalogKey = "Anvil_Reforge_1x" },
		{ Name = "RepairFractureBtn", Action = "RepairWeaponFracture" },
		{ Name = "SwapLoadoutPresetBtn", Action = "SwapLoadoutPreset" },
	},
	CombatAndInvaderHUD = {
		{ Name = "CastSpellQBtn", Action = "CastSpell", SpellSlot = "Q" },
		{ Name = "CastSpellEBtn", Action = "CastSpell", SpellSlot = "E" },
		{ Name = "CastSpellRBtn", Action = "CastSpell", SpellSlot = "R" },
	},
	PlaytimeGiftGridModal = {
		{ Name = "ClaimGift10mBtn", Action = "ClaimPlaytimeGift", Minutes = 10 },
		{ Name = "ClaimGift30mBtn", Action = "ClaimPlaytimeGift", Minutes = 30 },
		{ Name = "ClaimGift60mBtn", Action = "ClaimPlaytimeGift", Minutes = 60 },
	},
	PanicAndCrownStoreModals = {
		{ Name = "ExtraTethersCrownsBtn", Action = "SpendEclipseCrowns", CatalogKey = "Extra_Soul_Tethers" },
		{ Name = "ExtraTethersRobuxBtn", Action = "PromptRobuxProduct", CatalogKey = "Extra_Soul_Tethers" },
		{ Name = "VengeanceCrownsBtn", Action = "SpendEclipseCrowns", CatalogKey = "Vengeance_Curse" },
	},
}

for screenName, buttons in REQUIRED_SCREENS do
	local screenGui = StarterGui:FindFirstChild(screenName)
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = screenName
		screenGui.ResetOnSpawn = false
		screenGui:SetAttribute("IsWireframePlaceholder", true)
		screenGui.Parent = StarterGui

		local container = Instance.new("Frame")
		container.Name = "WireframeContainer"
		container.Size = UDim2.fromOffset(320, 40 + #buttons * 36)
		container.Position = UDim2.fromScale(0.02, 0.15)
		container.BackgroundColor3 = Color3.fromRGB(18, 16, 22)
		container.Parent = screenGui

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 4)
		layout.Parent = container
	end

	local parentFrame = screenGui:FindFirstChild("WireframeContainer") or screenGui
	for _, spec in buttons do
		local existingBtn = screenGui:FindFirstChild(spec.Name, true)
		if not existingBtn then
			local btn = Instance.new("TextButton")
			btn.Name = spec.Name
			btn.Size = UDim2.new(1, -8, 0, 30)
			btn.BackgroundColor3 = Color3.fromRGB(45, 30, 68)
			btn.TextColor3 = Color3.fromRGB(255, 184, 0)
			btn.Text = string.format("[%s] (%s)", spec.Name, spec.Action)
			btn.Parent = parentFrame
			existingBtn = btn
		end

		existingBtn:SetAttribute("Action", spec.Action)
		if spec.WallIndex then existingBtn:SetAttribute("WallIndex", spec.WallIndex) end
		if spec.CatalogKey then existingBtn:SetAttribute("CatalogKey", spec.CatalogKey) end
		if spec.Currency then existingBtn:SetAttribute("Currency", spec.Currency) end
		if spec.SpellSlot then existingBtn:SetAttribute("SpellSlot", spec.SpellSlot) end
		if spec.Minutes then existingBtn:SetAttribute("Minutes", spec.Minutes) end
		CollectionService:AddTag(existingBtn, "UIActionButton")
	end
end

print("All 8 UI ScreenGuis verified with UIActionButton tags and Attributes.")
