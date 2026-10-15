--!strict
-- Arcane Citadel: monetization catalog (Milestone 5).
-- HOW TO CONFIGURE (required before launch):
--   1. Publish the game, open Creator Hub → Monetization.
--   2. Create 2 Game Passes + 11 Developer Products.
--   3. Paste their numeric IDs below (0 = disabled, buttons show "soon").
-- Until IDs are set, every purchase fails gracefully with a message.

export type ProductEntry = {
	id: number,
	name: string,
	shards: number?, -- Blood Shard packs only
}

local ProductConfig = {
	Passes = {
		-- Permanent: waives +50% auto-renew surcharge, +0.10 elixir defense.
		Alchemist = 0,
		-- Permanent: 1-click Warden/Raider swap + Grimoire auto-roll.
		DualLoadout = 0,
	},
	Products = {
		BloodInsurance = { id = 0, name = "Blood Insurance" } :: ProductEntry,
		VengeanceCurse = { id = 0, name = "Vengeance Curse" } :: ProductEntry,
		MercenaryPact = { id = 0, name = "Emergency Mercenary Pact" } :: ProductEntry,
		ExtraTethers = { id = 0, name = "+3 Soul Tethers" } :: ProductEntry,
		WraithColossus = { id = 0, name = "Summon Wraith Colossus" } :: ProductEntry,
		-- Early Blood Pact exit (bypasses the 30-minute lock, banks the pot).
		RoyalDecree = { id = 0, name = "Royal Decree (End Blood Pact)" } :: ProductEntry,
		-- Arcane Anvil instant trait rerolls (chasing 0.2% Cataclysmic).
		AnvilReforge1 = { id = 0, name = "Anvil Reforge x1" } :: ProductEntry,
		AnvilReforge10 = { id = 0, name = "Anvil Reforge x10" } :: ProductEntry,
		-- Blood Shard packs. Sizes/prices are defined once, in
		-- MonetizationConfig (65/195/845 R$ -> 50/150/650 Crowns), so this
		-- table only carries the Roblox Developer Product ID.
		Shards150 = { id = 0, name = "150 Blood Shards", shards = 150 } :: ProductEntry,
		Shards500 = { id = 0, name = "500 Blood Shards", shards = 500 } :: ProductEntry,
		Shards2500 = { id = 0, name = "2,500 Blood Shards", shards = 2500 } :: ProductEntry,
	} :: { [string]: ProductEntry },
}

return ProductConfig
