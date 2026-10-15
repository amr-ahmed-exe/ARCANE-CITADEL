--!strict
-- Arcane Citadel: Phase 2 Black Market Auction House (escrow backend).
-- Save-first escrow: the item leaves the seller's ProfileService inventory
-- BEFORE the listing is published, so Day-1 duplication is impossible.
-- Atomic purchase: MemoryStore UpdateAsync claims the listing (SoldTo);
-- only the claim winner transfers shards/item. 15% market tax is burned.
-- Dependency-light: profiles are passed in as `any` (no DataService
-- require, no circular deps). GameService wires remotes + payouts.

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AuctionConfig = require(Shared.Configurations.AuctionConfig)
local GearConfig = require(Shared.Configurations.GearConfig)

export type AuctionListing = {
	id: string,
	itemUID: string,
	item: any, -- full InventoryItem snapshot (escrowed, traceable by ItemUID)
	itemId: string,
	seller: number,
	price: number,
	createdAt: number,
	expiresAt: number,
	soldTo: number?,
}

export type AuctionView = {
	listingId: string,
	itemUID: string,
	itemId: string,
	itemName: string,
	rarity: string,
	slot: string,
	level: number,
	prefix: string?,
	suffix: string?,
	fractured: boolean,
	price: number,
	seller: number,
	endsIn: number,
}

local AuctionService = {}

-- Studio / API-less fallback (single-server truth when stores fail).
local fallback: { [string]: AuctionListing } = {}
local fallbackMailbox: { [number]: number } = {}
local fallbackItems: { [number]: { any } } = {}
local readCache: { at: number, views: { AuctionView } } = { at = 0, views = {} }

local function map(): MemoryStoreSortedMap?
	local ok, result = pcall(MemoryStoreService.GetSortedMap, MemoryStoreService, AuctionConfig.MapName)
	if ok then
		return result
	end
	return nil
end

local function mailboxStore(): DataStore?
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, AuctionConfig.MailboxStoreName)
	if ok then
		return result
	end
	return nil
end

local function itemStore(): DataStore?
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, AuctionConfig.ItemStoreName)
	if ok then
		return result
	end
	return nil
end

local function encode(listing: AuctionListing): string
	return HttpService:JSONEncode(listing)
end

local function decode(raw: string): AuctionListing?
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	if ok and typeof(data) == "table" then
		return data :: AuctionListing
	end
	return nil
end

local function isEquipped(profile: any, uid: string): boolean
	for _, preset in { profile.Loadouts.Warden, profile.Loadouts.Raider } do
		if preset.WeaponUID == uid or preset.ArmorUID == uid or preset.Ring1UID == uid or preset.Ring2UID == uid then
			return true
		end
	end
	return false
end

local function toView(listing: AuctionListing, now: number): AuctionView
	local cfg = GearConfig[listing.itemId]
	return {
		listingId = listing.id,
		itemUID = listing.itemUID,
		itemId = listing.itemId,
		itemName = if cfg then cfg.Name else listing.itemId,
		rarity = if cfg then cfg.Rarity else "Common",
		slot = if listing.item and listing.item.SlotType then listing.item.SlotType else "?",
		level = if listing.item and listing.item.UpgradeLevel then listing.item.UpgradeLevel else 0,
		prefix = if listing.item then listing.item.PrefixTrait else nil,
		suffix = if listing.item then listing.item.SuffixTrait else nil,
		fractured = if listing.item then listing.item.IsFractured == true else false,
		price = listing.price,
		seller = listing.seller,
		endsIn = math.max(0, listing.expiresAt - now),
	}
end

-- Raw scan (MemoryStore cheapest-first + fallback), expired/sold filtered.
local function scanRaw(): { AuctionListing }
	local now = os.time()
	local out: { AuctionListing } = {}
	local m = map()
	if m then
		local ok, pages = pcall(m.GetRangeAsync, m, Enum.SortDirection.Ascending, 100)
		if ok and pages then
			for _, entry in pages do
				local listing = decode(entry.value)
				if listing and listing.soldTo == nil and listing.expiresAt > now then
					table.insert(out, listing)
				end
			end
		end
	end
	for _, listing in fallback do
		if listing.soldTo == nil and listing.expiresAt > now then
			table.insert(out, listing)
		end
	end
	table.sort(out, function(a: AuctionListing, b: AuctionListing)
		return a.price < b.price
	end)
	return out
end

function AuctionService.GetListings(): { AuctionView }
	if os.clock() - readCache.at < AuctionConfig.ReadCacheSeconds then
		return readCache.views
	end
	local now = os.time()
	local views: { AuctionView } = {}
	for i, listing in scanRaw() do
		if i > AuctionConfig.PageSize then
			break
		end
		table.insert(views, toView(listing, now))
	end
	readCache = { at = os.clock(), views = views }
	return views
end

function AuctionService.CountActiveListings(sellerUserId: number): number
	local n = 0
	for _, listing in scanRaw() do
		if listing.seller == sellerUserId then
			n += 1
		end
	end
	return n
end

-- Save-first escrow: item leaves the profile BEFORE publishing.
function AuctionService.ListItem(profile: any, sellerUserId: number, itemUID: string, priceShards: any): (boolean, string)
	if profile.AscensionRank < AuctionConfig.MinRankToTrade then
		return false, `Black Market requires Ascension Rank {AuctionConfig.MinRankToTrade} (Obsidian).`
	end
	if typeof(itemUID) ~= "string" or typeof(priceShards) ~= "number" then
		return false, ""
	end
	local price = math.floor(priceShards)
	if price < AuctionConfig.MinPriceShards or price > AuctionConfig.MaxPriceShards then
		return false, `Price must be {AuctionConfig.MinPriceShards}-{AuctionConfig.MaxPriceShards} Blood Shards.`
	end
	local item = profile.Inventory[itemUID]
	if not item then
		return false, "Item not found."
	end
	if not item.IsTradable then
		return false, "Starter gear cannot be traded."
	end
	if isEquipped(profile, itemUID) then
		return false, "Unequip the item from both loadouts first."
	end
	if AuctionService.CountActiveListings(sellerUserId) >= AuctionConfig.MaxActiveListingsPerSeller then
		return false, `Max {AuctionConfig.MaxActiveListingsPerSeller} active listings.`
	end

	-- 1. ESCROW: remove from inventory first (ProfileService auto-saves next).
	profile.Inventory[itemUID] = nil
	for _, preset in { profile.Loadouts.Warden, profile.Loadouts.Raider } do
		for _, slot in { "WeaponUID", "ArmorUID", "Ring1UID", "Ring2UID" } do
			if preset[slot] == itemUID then
				preset[slot] = nil
			end
		end
	end

	-- 2. PUBLISH: only after the save-first removal.
	local now = os.time()
	local listing: AuctionListing = {
		id = HttpService:GenerateGUID(false),
		itemUID = itemUID,
		item = item,
		itemId = item.ItemId,
		seller = sellerUserId,
		price = price,
		createdAt = now,
		expiresAt = now + AuctionConfig.ListingTTLSeconds,
		soldTo = nil,
	}
	local m = map()
	if m then
		local ok = pcall(m.SetAsync, m, listing.id, encode(listing), AuctionConfig.ListingTTLSeconds, price)
		if not ok then
			-- Publish failed: refund the item, never lose it.
			profile.Inventory[itemUID] = item
			return false, "Market unavailable, item kept. Try again."
		end
	else
		fallback[listing.id] = listing
	end
	readCache.at = 0 -- bust the read cache
	return true, ""
end

function AuctionService.CancelListing(profile: any, sellerUserId: number, listingId: string): (boolean, string)
	if typeof(listingId) ~= "string" then
		return false, ""
	end
	local m = map()
	local listing: AuctionListing? = nil
	if m then
		local ok, raw = pcall(m.GetAsync, m, listingId)
		if ok and typeof(raw) == "string" then
			listing = decode(raw)
		end
	end
	if not listing and fallback[listingId] then
		listing = fallback[listingId]
	end
	if not listing then
		return false, "Listing not found."
	end
	if listing.seller ~= sellerUserId then
		return false, "That is not your listing."
	end
	if listing.soldTo ~= nil then
		return false, "Already sold."
	end
	if m then
		pcall(m.RemoveAsync, m, listingId)
	end
	fallback[listingId] = nil
	-- Return the SAME ItemUID (traceability preserved).
	if profile.Inventory[listing.itemUID] == nil then
		profile.Inventory[listing.itemUID] = listing.item
	else
		AuctionService.DepositItemReturn(sellerUserId, listing.item)
	end
	readCache.at = 0
	return true, ""
end

-- Restores a claimed listing to the market when the post-claim transfer
-- check fails (shard race). The escrowed item is never swallowed: it is
-- republished for sale, and the seller can always cancel to reclaim it.
local function republish(listing: AuctionListing, m: MemoryStoreSortedMap?): ()
	listing.soldTo = nil
	if m then
		local ok = pcall(m.SetAsync, m, listing.id, encode(listing), AuctionConfig.ListingTTLSeconds, listing.price)
		if not ok then
			fallback[listing.id] = listing
		end
	else
		fallback[listing.id] = listing
	end
	readCache.at = 0 -- bust the read cache
end

-- Atomic purchase. Returns (ok, message, sellerUserId?, sellerCut?).
-- GameService routes the seller payout (direct credit if online, mailbox if not).
-- Validation runs BEFORE the atomic claim so a rejected purchase never
-- strands the escrowed item (previously: claim-then-validate removed the
-- listing even when the buyer was broke / buying their own listing).
function AuctionService.BuyListing(
	buyerProfile: any,
	buyerUserId: number,
	listingId: string
): (boolean, string, number?, number?)
	if buyerProfile.AscensionRank < AuctionConfig.MinRankToTrade then
		return false, `Black Market requires Ascension Rank {AuctionConfig.MinRankToTrade} (Obsidian).`, nil, nil
	end
	if typeof(listingId) ~= "string" then
		return false, "", nil, nil
	end
	local m = map()

	-- 1. PEEK: read the live listing and validate everything claimable
	-- before touching it (funds, ownership, rank, UID space).
	local function peek(): AuctionListing?
		if m then
			local okGet, raw = pcall(m.GetAsync, m, listingId)
			if okGet and typeof(raw) == "string" then
				return decode(raw)
			end
			return nil
		end
		return fallback[listingId]
	end
	local function validate(listing: AuctionListing?): (boolean, string)
		if not listing or listing.soldTo ~= nil or listing.expiresAt <= os.time() then
			return false, "Listing not found."
		end
		if listing.seller == buyerUserId then
			return false, "That is your own listing."
		end
		if buyerProfile.BloodShards < listing.price then
			return false, `Need {listing.price} Blood Shards.`
		end
		if buyerProfile.Inventory[listing.itemUID] ~= nil then
			return false, "UID collision (report this)."
		end
		return true, ""
	end
	local current = peek()
	local okPre, msgPre = validate(current)
	if not okPre then
		return false, msgPre, nil, nil
	end
	assert(current, "listing validated")

	-- 2. CLAIM: atomically stamp soldTo; only one buyer can win the race.
	if m then
		-- Atomic claim: only one buyer can stamp soldTo.
		local ok, _ = pcall(
			m.UpdateAsync,
			m,
			listingId,
			function(old: any)
				if typeof(old) ~= "string" then
					return nil -- abort: missing
				end
				local live = decode(old)
				if not live or live.soldTo ~= nil or live.expiresAt <= os.time() then
					return nil -- abort: sold or expired
				end
				live.soldTo = buyerUserId
				return encode(live)
			end,
			AuctionConfig.ListingTTLSeconds
		)
		if not ok then
			return false, "Market unavailable. Try again.", nil, nil
		end
		local claimed = peek()
		if claimed and claimed.soldTo == buyerUserId then
			current = claimed
		elseif claimed then
			return false, "Just sold to someone else.", nil, nil
		else
			-- Claim landed but the confirmation read failed: abort OUR claim
			-- (clear soldTo only if it is still ours) so the listing survives
			-- instead of stranding the escrowed item.
			pcall(
				m.UpdateAsync,
				m,
				listingId,
				function(old: any)
					if typeof(old) ~= "string" then
						return nil -- missing: leave it missing
					end
					local live = decode(old)
					if not live or live.soldTo ~= buyerUserId then
						return nil -- someone else's: hands off
					end
					live.soldTo = nil
					return encode(live)
				end,
				AuctionConfig.ListingTTLSeconds
			)
			return false, "Market unavailable. Try again.", nil, nil
		end
		pcall(m.RemoveAsync, m, listingId)
	else
		if not current or current.soldTo ~= nil or current.expiresAt <= os.time() then
			return false, "Listing not found.", nil, nil
		end
		current.soldTo = buyerUserId
		fallback[listingId] = nil
	end
	if not current or current.soldTo ~= buyerUserId then
		return false, "Just sold to someone else.", nil, nil
	end
	local listing: AuctionListing = current

	-- 3. TRANSFER: re-check funds (they may have moved during the claim
	-- race). On failure the listing is REPUBLISHED, never swallowed.
	if buyerProfile.BloodShards < listing.price then
		republish(listing, m)
		return false, `Need {listing.price} Blood Shards.`, nil, nil
	end
	if buyerProfile.Inventory[listing.itemUID] ~= nil then
		republish(listing, m)
		return false, "UID collision (report this).", nil, nil
	end

	-- Transfer: buyer pays, receives the SAME ItemUID.
	buyerProfile.BloodShards -= listing.price
	buyerProfile.Inventory[listing.itemUID] = listing.item

	-- 15% deflationary burn, 85% to the seller's payout route.
	local sellerCut = math.floor(listing.price * (1 - AuctionConfig.MarketTaxRate))
	readCache.at = 0
	return true, "", listing.seller, sellerCut
end

-- Expired (or stale sold-marker) cleanup. Returns escrowed items to route.
function AuctionService.SweepExpired(): { AuctionListing }
	local now = os.time()
	local expired: { AuctionListing } = {}
	local m = map()
	if m then
		local ok, pages = pcall(m.GetRangeAsync, m, Enum.SortDirection.Ascending, 100)
		if ok and pages then
			for _, entry in pages do
				local listing = decode(entry.value)
				if listing and (listing.expiresAt <= now or (listing.soldTo ~= nil and listing.expiresAt <= now)) then
					pcall(m.RemoveAsync, m, tostring(entry.key))
					if listing.soldTo == nil then
						table.insert(expired, listing)
					end
				end
			end
		end
	end
	for id, listing in fallback do
		if listing.expiresAt <= now then
			fallback[id] = nil
			if listing.soldTo == nil then
				table.insert(expired, listing)
			end
		end
	end
	if #expired > 0 then
		readCache.at = 0
	end
	return expired
end

-- Offline shard mailbox (seller cut while seller is on another server).
function AuctionService.AddMailboxShards(userId: number, amount: number): ()
	if amount <= 0 then
		return
	end
	local store = mailboxStore()
	if store then
		pcall(store.UpdateAsync, store, `shards_{userId}`, function(old: any)
			return (if typeof(old) == "number" then old else 0) + amount
		end)
	else
		fallbackMailbox[userId] = (fallbackMailbox[userId] or 0) + amount
	end
end

function AuctionService.ClaimMailboxShards(userId: number): number
	local store = mailboxStore()
	if store then
		local ok, value = pcall(store.GetAsync, store, `shards_{userId}`)
		if ok and typeof(value) == "number" and value > 0 then
			pcall(store.SetAsync, store, `shards_{userId}`, 0)
			return value
		end
		return 0
	end
	local amount = fallbackMailbox[userId] or 0
	fallbackMailbox[userId] = 0
	return amount
end

-- Offline item returns (expired listings while the seller is away).
function AuctionService.DepositItemReturn(userId: number, item: any): ()
	local store = itemStore()
	if store then
		pcall(store.UpdateAsync, store, `items_{userId}`, function(old: any)
			local list = if typeof(old) == "table" then old else {}
			table.insert(list, HttpService:JSONEncode(item))
			return list
		end)
	else
		fallbackItems[userId] = fallbackItems[userId] or {}
		table.insert(fallbackItems[userId], item)
	end
end

function AuctionService.ClaimItemReturns(userId: number): { any }
	local store = itemStore()
	if store then
		local ok, value = pcall(store.GetAsync, store, `items_{userId}`)
		if ok and typeof(value) == "table" then
			pcall(store.SetAsync, store, `items_{userId}`, {})
			local out: { any } = {}
			for _, raw in value do
				local okDec, item = pcall(HttpService.JSONDecode, HttpService, raw)
				if okDec then
					table.insert(out, item)
				end
			end
			return out
		end
		return {}
	end
	local out = fallbackItems[userId] or {}
	fallbackItems[userId] = {}
	return out
end

return AuctionService
