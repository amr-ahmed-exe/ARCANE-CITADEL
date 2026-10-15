--!strict
-- Arcane Citadel: Base Grimoire rolls, Warden/Raider presets, Arcane Anvil
-- reforging / upgrades / repairs / salvage (Milestone 3).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GearConfig = require(Shared.Configurations.GearConfig)
local TraitConfig = require(Shared.Configurations.TraitConfig)

local GearAndAnvilService = {}

local ROLL_COST = 1000 -- Vault Souls, Sanctuary only (÷100 in Studio)
local MYTHIC_ROLL_SHARD_COST = 50 -- Blood Shards, Epic+ pool only
local UPGRADE_BASE = 500
local MAX_UPGRADE = 10

-- DEBUG ONLY: Studio costs ÷100 for fast loop testing. Live pays full.
local function div(): number
	return if RunService:IsStudio() then 100 else 1
end
local SHARD_VALUE = { Epic = 10, Legendary = 40, Mythic = 200 }

local function totalWeight<T>(map: { [string]: T }, field: string): number
	local total = 0
	for _, spec: any in map do
		total += (spec :: any)[field]
	end
	return total
end

local function rollItemId(rank: number, luckActive: boolean?): string
	-- Higher Ascension ranks weight Epic+ brackets (keeps the chase alive).
	-- Luck Elixir (playtime gifts) doubles Epic/Legendary/Mythic weights.
	local rarityBoost: { [string]: number } = { Common = 1, Rare = 1, Epic = rank, Legendary = rank, Mythic = rank }
	if luckActive then
		rarityBoost.Epic *= 2
		rarityBoost.Legendary *= 2
		rarityBoost.Mythic *= 3
	end
	local total = 0
	for _, spec in GearConfig do
		total += spec.RollWeight * (rarityBoost[spec.Rarity] or 1)
	end
	local roll = math.random() * total
	for id, spec in GearConfig do
		roll -= spec.RollWeight * (rarityBoost[spec.Rarity] or 1)
		if roll <= 0 then
			return id
		end
	end
	return "Apprentice_Branch"
end

local function rollTrait(): string
	local total = totalWeight(TraitConfig.Traits, "Weight")
	local roll = math.random() * total
	for name, spec in TraitConfig.Traits do
		roll -= spec.Weight
		if roll <= 0 then
			return name
		end
	end
	return "Sturdy"
end

local function viewItem(uid: string, item: any)
	local cfg = GearConfig[item.ItemId]
	return {
		uid = uid,
		itemId = item.ItemId,
		name = if cfg then cfg.Name else item.ItemId,
		rarity = if cfg then cfg.Rarity else "Common",
		slot = item.SlotType,
		level = item.UpgradeLevel,
		prefix = item.PrefixTrait,
		suffix = item.SuffixTrait,
		fractured = item.IsFractured,
		tradable = item.IsTradable,
	}
end

local function isEquipped(profile: any, uid: string): boolean
	for _, preset in { profile.Loadouts.Warden, profile.Loadouts.Raider } do
		if preset.WeaponUID == uid or preset.ArmorUID == uid or preset.Ring1UID == uid or preset.Ring2UID == uid then
			return true
		end
	end
	return false
end

function GearAndAnvilService.Roll(profile: any, session: any): any
	if session.IsBloodPactActive then
		return nil -- Vault sealed during Blood Pact.
	end
	if session.PermanentVaultSouls < math.max(1, math.round(ROLL_COST / div())) then
		return nil
	end
	session.PermanentVaultSouls -= math.max(1, math.round(ROLL_COST / div()))
	local luckActive = os.time() < (profile.LuckElixirUntil or 0)
	local itemId = rollItemId(profile.AscensionRank, luckActive)
	local cfg = GearConfig[itemId]
	local uid = HttpService:GenerateGUID(false)
	local item = {
		ItemUID = uid,
		ItemId = itemId,
		SlotType = cfg.Slot,
		UpgradeLevel = 0,
		PrefixTrait = rollTrait(),
		SuffixTrait = rollTrait(),
		IsFractured = false,
		IsTradable = true,
	}
	profile.Inventory[uid] = item
	return viewItem(uid, item)
end

function GearAndAnvilService.RollMythic(profile: any, session: any): any
	-- Blood Shard sink (blueprint 1.7): Epic+ pool only, Sanctuary only.
	if session.IsBloodPactActive then
		return nil -- Vault sealed during Blood Pact.
	end
	if profile.BloodShards < MYTHIC_ROLL_SHARD_COST then
		return nil
	end
	profile.BloodShards -= MYTHIC_ROLL_SHARD_COST
	local luckActive = os.time() < (profile.LuckElixirUntil or 0)
	-- Epic+ pool: filter GearConfig, keep rank + luck boosts.
	local rarityBoost: { [string]: number } = {
		Epic = profile.AscensionRank * (if luckActive then 2 else 1),
		Legendary = profile.AscensionRank * (if luckActive then 2 else 1),
		Mythic = profile.AscensionRank * (if luckActive then 3 else 1),
	}
	local total = 0
	for _, spec in GearConfig do
		if rarityBoost[spec.Rarity] then
			total += spec.RollWeight * rarityBoost[spec.Rarity]
		end
	end
	local itemId = "Soulfire_Scepter"
	if total > 0 then
		local roll = math.random() * total
		for id, spec in GearConfig do
			if rarityBoost[spec.Rarity] then
				roll -= spec.RollWeight * rarityBoost[spec.Rarity]
				if roll <= 0 then
					itemId = id
					break
				end
			end
		end
	end
	local cfg = GearConfig[itemId]
	local uid = HttpService:GenerateGUID(false)
	local prefix = rollTrait()
	local suffix = rollTrait()
	if luckActive and (prefix == "Sturdy" and suffix == "Sturdy") then
		-- Luck pity: double-Common rerolls once.
		prefix = rollTrait()
		suffix = rollTrait()
	end
	local item = {
		ItemUID = uid,
		ItemId = itemId,
		SlotType = cfg.Slot,
		UpgradeLevel = 0,
		PrefixTrait = prefix,
		SuffixTrait = suffix,
		IsFractured = false,
		IsTradable = true,
	}
	profile.Inventory[uid] = item
	return viewItem(uid, item)
end

function GearAndAnvilService.ReforgeCredit(profile: any, uid: string): boolean
	-- Robux bundle path (19 / 149 R$ grants credits via GameService).
	local item = profile.Inventory[uid]
	if not item then
		return false
	end
	if (profile.ReforgeCredits or 0) < 1 then
		return false
	end
	profile.ReforgeCredits -= 1
	item.PrefixTrait = rollTrait()
	item.SuffixTrait = rollTrait()
	return true
end

function GearAndAnvilService.Reforge(profile: any, uid: string): boolean
	local item = profile.Inventory[uid]
	if not item then
		return false
	end
	if profile.BloodShards < TraitConfig.ReforgeCostBloodShards then
		return false
	end
	profile.BloodShards -= TraitConfig.ReforgeCostBloodShards
	item.PrefixTrait = rollTrait()
	item.SuffixTrait = rollTrait()
	return true
end

function GearAndAnvilService.ReforgeWithCrowns(profile: any, uid: string): (boolean, string)
	-- 1-click instant path: 14 Eclipse Crowns (1.3x better than 19 Raw Robux).
	local item = profile.Inventory[uid]
	if not item then
		return false, "Item not found."
	end
	local cost = TraitConfig.ReforgeCostEclipseCrowns or 15
	if (profile.EclipseCrowns or 0) < cost then
		return false, `Need {cost} Eclipse Crowns (1.3x value). Buy a Crown pack in the shop!`
	end
	profile.EclipseCrowns -= cost
	item.PrefixTrait = rollTrait()
	item.SuffixTrait = rollTrait()
	return true, ""
end

function GearAndAnvilService.Upgrade(profile: any, session: any, uid: string): boolean
	local item = profile.Inventory[uid]
	if not item or session.IsBloodPactActive then
		return false
	end
	if (item.UpgradeLevel or 0) >= MAX_UPGRADE then
		return false
	end
	local cost = math.max(1, math.round(UPGRADE_BASE * (2 ^ (item.UpgradeLevel or 0)) / div()))
	if session.PermanentVaultSouls < cost then
		return false
	end
	session.PermanentVaultSouls -= cost
	item.UpgradeLevel += 1
	return true
end

function GearAndAnvilService.Repair(profile: any, uid: string): boolean
	local item = profile.Inventory[uid]
	if not item or not item.IsFractured then
		return false
	end
	if profile.BloodShards < TraitConfig.RepairFractureCostBloodShards then
		return false
	end
	profile.BloodShards -= TraitConfig.RepairFractureCostBloodShards
	item.IsFractured = false
	return true
end

function GearAndAnvilService.RepairWithCrowns(profile: any, uid: string): (boolean, string)
	local item = profile.Inventory[uid]
	if not item or not item.IsFractured then
		return false, "Item is not fractured."
	end
	local cost = TraitConfig.RepairFractureCostEclipseCrowns or 11
	if (profile.EclipseCrowns or 0) < cost then
		return false, `Need {cost} Eclipse Crowns.`
	end
	profile.EclipseCrowns -= cost
	item.IsFractured = false
	return true, ""
end

function GearAndAnvilService.Salvage(profile: any, uid: string): boolean
	local item = profile.Inventory[uid]
	if not item or not item.IsTradable or isEquipped(profile, uid) then
		return false
	end
	local cfg = GearConfig[item.ItemId]
	if not cfg or SHARD_VALUE[cfg.Rarity] == nil then
		return false -- Epic+ only.
	end
	profile.BloodShards += SHARD_VALUE[cfg.Rarity]
	profile.Inventory[uid] = nil
	-- Detach from any preset still referencing it.
	for _, preset in { profile.Loadouts.Warden, profile.Loadouts.Raider } do
		for _, slot in { "WeaponUID", "ArmorUID", "Ring1UID", "Ring2UID" } do
			if preset[slot] == uid then
				preset[slot] = nil
			end
		end
	end
	return true
end

-- 1-click equip cycling: each slot button rotates owned items of that slot.
function GearAndAnvilService.CycleSlot(profile: any, presetName: string, slot: string): boolean
	local preset = profile.Loadouts[presetName]
	if not preset then
		return false
	end
	local wantType = if slot == "WeaponUID" then "Weapon" elseif slot == "ArmorUID" then "Armor" else "Ring"
	local owned: { string } = {}
	for uid, item in profile.Inventory do
		if item.SlotType == wantType then
			table.insert(owned, uid)
		end
	end
	if #owned == 0 then
		return false
	end
	table.sort(owned)
	local current = preset[slot]
	local nextUid = owned[1]
	for i, uid in owned do
		if uid == current then
			nextUid = owned[(i % #owned) + 1]
			break
		end
	end
	preset[slot] = nextUid
	return true
end

function GearAndAnvilService.Swap(profile: any, presetName: string): boolean
	if presetName ~= "Warden" and presetName ~= "Raider" then
		return false
	end
	profile.ActiveLoadoutType = presetName
	return true
end

function GearAndAnvilService.View(profile: any): any
	local items = {}
	for uid, item in profile.Inventory do
		table.insert(items, viewItem(uid, item))
	end
	table.sort(items, function(a: any, b: any)
		return (a.name :: string) < (b.name :: string)
	end)
	local function presetView(preset: any)
		local function nameOf(uid: string?): string
			if not uid or not profile.Inventory[uid] then
				return "—"
			end
			local cfg = GearConfig[profile.Inventory[uid].ItemId]
			return if cfg then cfg.Name else uid
		end
		return {
			weapon = nameOf(preset.WeaponUID),
			armor = nameOf(preset.ArmorUID),
			ring1 = nameOf(preset.Ring1UID),
			ring2 = nameOf(preset.Ring2UID),
			spellQ = preset.SpellQ,
			spellE = preset.SpellE,
			spellR = preset.SpellR,
			-- Grouped view for the spell picker.
			spells = { Q = preset.SpellQ, E = preset.SpellE, R = preset.SpellR },
		}
	end
	return {
		items = items,
		warden = presetView(profile.Loadouts.Warden),
		raider = presetView(profile.Loadouts.Raider),
		active = profile.ActiveLoadoutType,
		rollCost = ROLL_COST,
		mythicCost = MYTHIC_ROLL_SHARD_COST,
		reforgeCost = TraitConfig.ReforgeCostBloodShards,
		reforgeCrownCost = TraitConfig.ReforgeCostEclipseCrowns or 15,
		repairCrownCost = TraitConfig.RepairFractureCostEclipseCrowns or 11,
		reforgeCredits = profile.ReforgeCredits or 0,
		luckRemaining = math.max(0, (profile.LuckElixirUntil or 0) - os.time()),
	}
end

return GearAndAnvilService
