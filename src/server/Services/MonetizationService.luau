--!strict
-- Arcane Citadel: dual-checkout monetization service (Milestone 5 + Blueprint 1.7).
-- Every item: Raw Robux (1.0x, slow 2-step prompt) OR Eclipse Crowns (1.3x, 1-click instant).
-- Crown packs (99 R$+) grant Crowns via ProcessReceipt; Crown spends are atomic
-- server deducts with 0ms grants (no Roblox dialog) for panic moments.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetworkRouter = require(Shared.Framework.NetworkRouter)
local ProductConfig = require(Shared.Configurations.ProductConfig)
local MonetizationConfig = require(Shared.Configurations.MonetizationConfig)
local DataService = require(script.Parent.DataService)
local GameService = require(script.Parent.GameService)

local MonetizationService = {}

-- Legacy Robux products (ProductConfig, IDs pasted from Creator Hub).
local idToLegacyKey: { [number]: string } = {}
for key, entry in ProductConfig.Products do
	if entry.id ~= 0 then
		idToLegacyKey[entry.id] = key
	end
end

-- Blueprint catalog Robux products (MonetizationConfig.Catalog DevProductIds).
local idToCatalogKey: { [number]: string } = {}
for key, entry in MonetizationConfig.Catalog do
	if entry.DevProductId ~= 0 then
		idToCatalogKey[entry.DevProductId] = key
	end
end

-- Crown bundle packs (Robux -> Crowns).
local idToBundleKey: { [number]: string } = {}
for key, bundle in MonetizationConfig.CrownBundles do
	if bundle.DevProductId ~= 0 then
		idToBundleKey[bundle.DevProductId] = key
	end
end

-- Catalog -> legacy mapping for Robux receipt grants (situational items reuse GameService).
local CATALOG_TO_LEGACY: { [string]: string } = {
	Blood_Insurance = "BloodInsurance",
	Vengeance_Curse = "VengeanceCurse",
	Emergency_Mercenaries = "MercenaryPact",
	Extra_Soul_Tethers = "ExtraTethers",
	Summon_Wraith_Colossus = "WraithColossus",
	Royal_Decree = "RoyalDecree",
	Anvil_Reforge_1x = "AnvilReforge1",
	Anvil_Reforge_10x = "AnvilReforge10",
}

local function passOwned(player: Player, passId: number): boolean
	if passId == 0 then
		return false
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
	return ok and owns == true
end

-- Re-checks pass ownership (join + after any pass purchase attempt).
-- Crown-bought passes set the flags directly, so never overwrite a true with false
-- from Roblox ownership alone (crowns bypass Game Passes).
function MonetizationService.SyncPasses(player: Player): ()
	local profile = DataService.GetByUserId(player.UserId)
	if not profile then
		return
	end
	local alch = passOwned(player, ProductConfig.Passes.Alchemist)
	local dual = passOwned(player, ProductConfig.Passes.DualLoadout)
	-- Note: catalog passes bought with Robux grant via ProcessReceipt;
	-- catalog passes bought with Crowns grant via ApplyCrownPurchase.
	-- Never overwrite a Crown-granted true with a false ownership check.
	if alch then
		profile.HasAlchemistPass = true
	end
	if dual then
		profile.HasDualLoadoutPass = true
	end
	GameService.SyncOwnerPasses(player.UserId, profile.HasAlchemistPass)
end

-- Atomic 1-click Crown spend (blueprint: SpendEclipseCrowns server endpoint).
-- Validates balance, deducts CrownPrice, grants Pass / Panic Save / Shards in 0ms.
function MonetizationService.SpendEclipseCrowns(player: Player, catalogKey: string): (boolean, string)
	local profile = DataService.GetByUserId(player.UserId)
	if not profile or typeof(catalogKey) ~= "string" then
		return false, "Invalid request."
	end
	return GameService.ApplyCrownPurchase(player, profile, catalogKey)
end

function MonetizationService.Init(): ()
	local remotes = Shared:WaitForChild("Remotes");

	(NetworkRouter.RegisterFunction("BuyProduct", function(player: Player, key: string)
		if typeof(key) ~= "string" then
			return false, ""
		end
		-- Legacy path first (Creator Hub IDs).
		local entry = ProductConfig.Products[key]
		if entry and entry.id ~= 0 then
			local ok, err = pcall(
				MarketplaceService.PromptProductPurchase,
				MarketplaceService,
				player,
				entry.id
			)
			if not ok then
				return false, `Store unavailable: {tostring(err)}`
			end
			return true, ""
		end
		-- Blueprint catalog path (MonetizationConfig DevProductIds).
		local cat = MonetizationConfig.Catalog[key]
		if cat and cat.DevProductId ~= 0 then
			local ok, err = pcall(
				MarketplaceService.PromptProductPurchase,
				MarketplaceService,
				player,
				cat.DevProductId
			)
			if not ok then
				return false, `Store unavailable: {tostring(err)}`
			end
			return true, ""
		end
		-- Accept catalog keys with underscore-less legacy aliases too.
		return false, "Shop coming soon — products not configured yet."
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("BuyPass", function(player: Player, key: string)
		if typeof(key) ~= "string" then
			return false, ""
		end
		local passId = if key == "Alchemist"
			then ProductConfig.Passes.Alchemist
			elseif key == "DualLoadout" then ProductConfig.Passes.DualLoadout
			else 0
		if passId == 0 then
			return false, "Shop coming soon — passes not configured yet."
		end
		local ok, err = pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, passId)
		if not ok then
			return false, `Store unavailable: {tostring(err)}`
		end
		task.delay(5, function()
			if player.Parent then
				MonetizationService.SyncPasses(player)
			end
		end)
		return true, ""
	end) :: RemoteFunction).Parent = remotes;

	-- Bulk Crown packs: prompt the Robux purchase (99 R$ -> 1299 R$).
	(NetworkRouter.RegisterFunction("BuyCrownPack", function(player: Player, bundleKey: string)
		if typeof(bundleKey) ~= "string" then
			return false, "Invalid pack."
		end
		local bundle = MonetizationConfig.CrownBundles[bundleKey]
		if not bundle or bundle.DevProductId == 0 then
			return false, "Crown packs coming soon."
		end
		local ok, err = pcall(
			MarketplaceService.PromptProductPurchase,
			MarketplaceService,
			player,
			bundle.DevProductId
		)
		if not ok then
			return false, `Store unavailable: {tostring(err)}`
		end
		return true, ""
	end) :: RemoteFunction).Parent = remotes;

	-- 1-click instant Crown spend (0ms, no Roblox dialog). Alias: SpendCrowns lives
	-- in GameService; both names work so blueprint + client stay in sync.
	(NetworkRouter.RegisterFunction("SpendEclipseCrowns", function(player: Player, catalogKey: string)
		return MonetizationService.SpendEclipseCrowns(player, catalogKey)
	end) :: RemoteFunction).Parent = remotes;

	(NetworkRouter.RegisterFunction("RefreshPasses", function(player: Player)
		MonetizationService.SyncPasses(player)
		return true
	end) :: RemoteFunction).Parent = remotes;

	-- selene: allow(incorrect_standard_library_use)
	-- (Selene 0.31's stdlib omits Enum.ProductPurchaseDecision.Purchased;
	-- the member exists in Roblox: NotProcessedYet / Purchased.)
	MarketplaceService.ProcessReceipt = function(receiptInfo: any)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local profile = DataService.GetByUserId(player.UserId)
		if not profile then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		-- Idempotency: never grant the same purchase twice.
		local receiptId = tostring(receiptInfo.PurchaseId)
		if profile.ProcessedReceipts[receiptId] then
			return Enum.ProductPurchaseDecision.Purchased
		end
		-- 1. Crown bundles: Robux -> Crowns.
		local bundleKey = idToBundleKey[receiptInfo.ProductId]
		if bundleKey then
			local bundle = MonetizationConfig.CrownBundles[bundleKey]
			if bundle then
				if profile.EclipseCrowns == nil then
					profile.EclipseCrowns = 0
				end
				profile.EclipseCrowns += bundle.CrownsGranted;
				(profile :: any).ProcessedReceipts[receiptId] = true
				return Enum.ProductPurchaseDecision.Purchased
			end
		end
		-- 2. Legacy Robux products.
		local legacyKey = idToLegacyKey[receiptInfo.ProductId]
		if legacyKey then
			local granted = GameService.ApplyPurchase(player, profile, legacyKey)
			if granted then
				profile.ProcessedReceipts[receiptId] = true
				return Enum.ProductPurchaseDecision.Purchased
			end
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		-- 3. Blueprint catalog Robux products.
		local catalogKey = idToCatalogKey[receiptInfo.ProductId]
		if catalogKey then
			local entry = MonetizationConfig.Catalog[catalogKey]
			if entry and entry.BloodShardGrant then
				if profile.EclipseCrowns == nil then
					profile.EclipseCrowns = 0
				end
				profile.BloodShards += entry.BloodShardGrant
				profile.ProcessedReceipts[receiptId] = true
				return Enum.ProductPurchaseDecision.Purchased
			end
			if catalogKey == "Master_Alchemist_Pass" then
				profile.HasAlchemistPass = true
				GameService.SyncOwnerPasses(player.UserId, true)
				profile.ProcessedReceipts[receiptId] = true
				return Enum.ProductPurchaseDecision.Purchased
			end
			if catalogKey == "Dual_Loadout_Pass" then
				profile.HasDualLoadoutPass = true
				profile.ProcessedReceipts[receiptId] = true
				return Enum.ProductPurchaseDecision.Purchased
			end
			local mapped = CATALOG_TO_LEGACY[catalogKey]
			if mapped then
				local granted = GameService.ApplyPurchase(player, profile, mapped)
				if granted then
					profile.ProcessedReceipts[receiptId] = true
					return Enum.ProductPurchaseDecision.Purchased
				end
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
		end
		-- Unrecognised ProductId. Returning Purchased here means Roblox stops
		-- retrying AND the player is charged for nothing — which is exactly
		-- what happens the moment a real ID is pasted into ProductConfig for
		-- a key that is not mirrored in MonetizationConfig.
		warn(`[MonetizationService] Unmapped ProductId {receiptInfo.ProductId} (receipt {receiptId}). Not granted.`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Cover players who are already present. DataService and GameService both
	-- iterate Players:GetPlayers() for Studio Play Solo; without the same here,
	-- a solo tester's passes only synced because the shop poked RefreshPasses.
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			task.wait(3)
			if player.Parent then
				MonetizationService.SyncPasses(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(function()
			task.wait(3)
			if player.Parent then
				MonetizationService.SyncPasses(player)
			end
		end)
	end)

	print("[ArcaneCitadel] MonetizationService online (dual-checkout).")
end

return MonetizationService
