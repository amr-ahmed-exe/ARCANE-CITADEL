--!strict
-- Arcane Citadel: Black Market Auction House tuning (Phase 2, post-launch).
-- Escrow architecture: save-first listing, atomic UpdateAsync purchase,
-- 15% deflationary tax burn. Only Rank 3+ may list or buy (anti-bot gate).

local AuctionConfig = {
	MinRankToTrade = 3, -- Ascension Rank 3 (Obsidian) gate for listing AND buying
	MarketTaxRate = 0.15, -- 15% of every sale is burned; seller receives 85%
	MaxActiveListingsPerSeller = 5, -- anti-spam cap per seller
	ListingTTLSeconds = 24 * 3600, -- unsold listings expire after 24h, item returns
	MinPriceShards = 10,
	MaxPriceShards = 1000000,
	PageSize = 25, -- raid-browser style: top 25 cheapest first
	MapName = "ArcaneCitadel_Auction_v1",
	MailboxStoreName = "ArcaneCitadel_AuctionMailbox_v1",
	ItemStoreName = "ArcaneCitadel_AuctionItems_v1",
	ReadCacheSeconds = 10,
}

return AuctionConfig
