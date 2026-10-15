--!strict
-- Arcane Citadel: client-side economy cache (Milestone 2).
-- Fetches the authoritative snapshot, listens for 1s pushes,
-- and wraps all RemoteFunction actions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local EconomyClient = {}

local snapshot: any = nil
local listeners: { () -> () } = {}

-- Inventory is read by three screens (CombatInputController, SpellBar,
-- GrimoireAndAnvilModal). Fetching it per-screen per-push meant a
-- GetInventory round-trip every second per consumer. Cache it here instead.
local inventoryCache: any = nil
local inventoryFetchedAt: number? = nil
local INVENTORY_TTL = 1

local function remotes()
	return Shared:WaitForChild("Remotes")
end

local function callRemote(name: string, ...: any): any
	local folder = remotes()
	local remote = folder:WaitForChild(name) :: RemoteFunction
	return remote:InvokeServer(...)
end

function EconomyClient.Get()
	return snapshot
end

function EconomyClient.OnChanged(listener: () -> ()): () -> ()
	table.insert(listeners, listener)
	return function()
		for i, fn in listeners do
			if fn == listener then
				table.remove(listeners, i)
				break
			end
		end
	end
end

local function notify(): ()
	for _, listener in listeners do
		task.spawn(listener)
	end
end

-- Any action that can change gear, traits, levels or loadout presets drops
-- the cache so the next read refetches instead of showing stale gear.
local function invalidateInventory(): ()
	inventoryCache = nil
	inventoryFetchedAt = nil
end

function EconomyClient.Refresh(): ()
	local data = callRemote("EconomySnapshot")
	if data ~= nil then
		snapshot = data
		notify()
	end
end

function EconomyClient.PurchaseElixir(wallIndex: number, autoRenew: boolean): boolean
	return callRemote("PurchaseElixir", wallIndex, autoRenew) == true
end

-- Flips the auto-renew toggle on its own. Never spends souls.
function EconomyClient.SetAutoRenew(wallIndex: number, autoRenew: boolean): boolean
	return callRemote("SetAutoRenew", wallIndex, autoRenew) == true
end

function EconomyClient.UpgradeWall(wallIndex: number): boolean
	return callRemote("UpgradeWall", wallIndex) == true
end

function EconomyClient.UnlockWall(wallIndex: number): boolean
	return callRemote("UnlockWall", wallIndex) == true
end

function EconomyClient.EnableBloodPact(): boolean
	return callRemote("ToggleBloodPact", true) == true
end

function EconomyClient.RepairWall(wallIndex: number): (boolean, number)
	local ok, cost = callRemote("RepairWall", wallIndex)
	return ok == true, tonumber(cost) or 0
end

function EconomyClient.BreachDecision(choice: string): boolean
	return callRemote("BreachDecision", choice) == true
end

function EconomyClient.ClaimGift(giftIndex: number): boolean
	return callRemote("ClaimGift", giftIndex) == true
end

function EconomyClient.GrimoireRoll(): any
	local data = callRemote("GrimoireRoll")
	invalidateInventory()
	return data
end

function EconomyClient.MythicRoll(): any
	local data = callRemote("GrimoireMythicRoll")
	invalidateInventory()
	return data
end

function EconomyClient.ReforgeCredit(uid: string): boolean
	local ok = callRemote("ReforgeItemCredit", uid) == true
	invalidateInventory()
	return ok
end

function EconomyClient.ReforgeItem(uid: string): boolean
	local ok = callRemote("ReforgeItem", uid) == true
	invalidateInventory()
	return ok
end

function EconomyClient.ReforgeItemCrowns(uid: string): (boolean, string)
	local ok, msg = callRemote("ReforgeItemCrowns", uid)
	invalidateInventory()
	return ok == true, tostring(msg or "")
end

function EconomyClient.RepairItemCrowns(uid: string): (boolean, string)
	local ok, msg = callRemote("RepairItemCrowns", uid)
	invalidateInventory()
	return ok == true, tostring(msg or "")
end

function EconomyClient.SpendCrowns(catalogKey: string): (boolean, string)
	local ok, msg = callRemote("SpendCrowns", catalogKey)
	if ok ~= true then
		-- Fallback alias (MonetizationService name from the blueprint).
		ok, msg = callRemote("SpendEclipseCrowns", catalogKey)
	end
	return ok == true, tostring(msg or "")
end

function EconomyClient.BuyCrownPack(bundleKey: string): (boolean, string)
	local ok, msg = callRemote("BuyCrownPack", bundleKey)
	return ok == true, tostring(msg or "")
end

function EconomyClient.GetCrownCatalog(): any
	return callRemote("GetCrownCatalog")
end

function EconomyClient.UpgradeItem(uid: string): boolean
	local ok = callRemote("UpgradeItem", uid) == true
	invalidateInventory()
	return ok
end

function EconomyClient.RepairItem(uid: string): boolean
	local ok = callRemote("RepairItem", uid) == true
	invalidateInventory()
	return ok
end

function EconomyClient.SalvageItem(uid: string): boolean
	local ok = callRemote("SalvageItem", uid) == true
	invalidateInventory()
	return ok
end

function EconomyClient.CycleSlot(preset: string, slot: string): boolean
	local ok = callRemote("CycleSlot", preset, slot) == true
	invalidateInventory()
	return ok
end

function EconomyClient.SwapLoadout(preset: string): boolean
	local ok = callRemote("SwapLoadout", preset) == true
	invalidateInventory()
	return ok
end

-- Force-refresh the inventory cache and return it. Safe to call often: the
-- server round-trip is throttled to one per INVENTORY_TTL seconds.
function EconomyClient.GetInventory(): any
	local data = callRemote("GetInventory")
	if typeof(data) == "table" then
		inventoryCache = data
	end
	return inventoryCache
end

-- Read the cache without forcing a round-trip. Returns nil until the first
-- successful fetch, so callers must nil-check (the server returns nil until
-- the player's profile finishes loading).
function EconomyClient.GetInventoryCached(): any
	local now = os.clock()
	if inventoryCache == nil or now - (inventoryFetchedAt or 0) >= INVENTORY_TTL then
		inventoryFetchedAt = now
		EconomyClient.GetInventory()
	end
	return inventoryCache
end

function EconomyClient.ToggleAutoRoll(enable: boolean): boolean
	return callRemote("ToggleAutoRoll", enable) == true
end

function EconomyClient.HireServant(): boolean
	return callRemote("HireServant") == true
end

function EconomyClient.Ascend(): (boolean, string)
	local ok, msg = callRemote("Ascend")
	return ok == true, tostring(msg or "")
end

function EconomyClient.InvaderForfeit(): boolean
	return callRemote("InvaderForfeit") == true
end

function EconomyClient.GetRaidTargets(): { any }
	local data = callRemote("GetRaidTargets")
	return if typeof(data) == "table" then data else {}
end

function EconomyClient.InvadeRealm(jobId: string): (boolean, string)
	local ok, msg = callRemote("InvadeRealm", jobId)
	return ok == true, tostring(msg or "")
end

function EconomyClient.BuyProduct(key: string): (boolean, string)
	local ok, msg = callRemote("BuyProduct", key)
	return ok == true, tostring(msg or "")
end

function EconomyClient.BuyPass(key: string): (boolean, string)
	local ok, msg = callRemote("BuyPass", key)
	return ok == true, tostring(msg or "")
end

function EconomyClient.RefreshPasses(): boolean
	return callRemote("RefreshPasses") == true
end

function EconomyClient.GetAuctionListings(): { any }
	local data = callRemote("AuctionListings")
	return if typeof(data) == "table" then data else {}
end

function EconomyClient.AuctionList(itemUID: string, price: number): (boolean, string)
	local ok, msg = callRemote("AuctionList", itemUID, price)
	return ok == true, tostring(msg or "")
end

function EconomyClient.AuctionCancel(listingId: string): (boolean, string)
	local ok, msg = callRemote("AuctionCancel", listingId)
	return ok == true, tostring(msg or "")
end

function EconomyClient.AuctionBuy(listingId: string): (boolean, string)
	local ok, msg = callRemote("AuctionBuy", listingId)
	invalidateInventory()
	return ok == true, tostring(msg or "")
end

function EconomyClient.ClaimAuctionMailbox(): any
	local data = callRemote("ClaimAuctionMailbox")
	invalidateInventory()
	return data
end

function EconomyClient.PlaceTrap(target: Vector3): boolean
	return callRemote("PlaceTrap", target) == true
end

function EconomyClient.UseSabotage(hexId: string, target: Vector3): (boolean, string)
	local ok, msg = callRemote("UseSabotage", hexId, target)
	return ok == true, tostring(msg or "")
end

function EconomyClient.RequestAlly(): (boolean, string)
	local ok, msg = callRemote("RequestAlly")
	return ok == true, tostring(msg or "")
end

function EconomyClient.Init(): ()
	remotes() -- wait for the server to publish remotes
	local folder = Shared:WaitForChild("Remotes")
	local event = folder:WaitForChild("EconomyChanged") :: RemoteEvent;
	(event :: RemoteEvent).OnClientEvent:Connect(function(data: any)
		snapshot = data
		notify()
	end)
	EconomyClient.Refresh()
end

return EconomyClient
