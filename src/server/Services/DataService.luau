--!strict
-- Arcane Citadel: ProfileService-backed save layer (Milestone 1).
-- Every RPG item carries a UUID ItemUID so the Phase 2 Auction House
-- can trace items atomically. Requires `wally install` (Packages/).

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProfileService: any = nil
do
	local ok, mod = pcall(require, ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ProfileService"))
	if ok then
		ProfileService = mod
	else
		warn("[DataService] ProfileService package missing. Run `wally install` and sync Packages. Data will be session-only.")
	end
end

export type InventoryItem = {
	ItemUID: string, -- Unique UUID via HttpService:GenerateGUID(false)
	ItemId: string, -- Maps to GearConfig (e.g., "Soulfire_Scepter")
	SlotType: "Weapon" | "Armor" | "Ring",
	UpgradeLevel: number, -- +0 to +10 upgrade level
	PrefixTrait: string?, -- Maps to TraitConfig (e.g., "Cataclysmic")
	SuffixTrait: string?, -- Maps to TraitConfig (e.g., "Siegebreaker")
	IsFractured: boolean, -- True if player lost all 5 Soul Tethers during an Invasion (-25% power)
	IsTradable: boolean, -- False for starter gear, True for rolled gear
}

export type LoadoutPreset = {
	WeaponUID: string,
	ArmorUID: string,
	Ring1UID: string?,
	Ring2UID: string?,
	SpellQ: string,
	SpellE: string,
	SpellR: string,
}

export type SavedWallData = {
	Unlocked: boolean,
	PermanentDefenseLevel: number,
	AutoRenewElixir: boolean,
}

export type PlayerProfileData = {
	PermanentVaultSouls: number, -- 100% safe from raids; resets on Ascension
	BloodShards: number, -- Permanent hard/RPG currency; never resets
	EclipseCrowns: number, -- Robux-tied bulk commitment currency (1.3x value); never resets
	AscensionRank: number, -- 1 = Wood, 2 = Runic Stone, 3 = Obsidian, 4 = Void Metal
	HasAlchemistPass: boolean, -- Waives +50% Auto-Renew Elixir surcharge
	HasDualLoadoutPass: boolean, -- Enables 1-click Warden/Raider swap & Auto-Roll
	AutoRollEnabled: boolean, -- Milestone 5: auto Grimoire rolls (needs DualLoadout pass)
	ActiveLoadoutType: "Warden" | "Raider",
	Loadouts: {
		Warden: LoadoutPreset,
		Raider: LoadoutPreset,
	},
	Inventory: { [string]: InventoryItem }, -- Keyed by ItemUID
	Walls: { [number]: SavedWallData }, -- Keys 1, 2, 3
	PendingOfflineTheft: number, -- Accumulated while owner was offline under attack (informational; pot already excludes it)
	ClaimedPlaytimeGifts: { [number]: boolean }, -- Session gift tracker (2m, 5m, 10m... 60m)
	ProcessedReceipts: { [string]: boolean },
	ReforgeCredits: number, -- Robux Anvil bundles (1x / 10x instant reforges)
	LuckElixirUntil: number, -- os.time() until which Grimoire luck is boosted
}

local DataService = {}

local profiles: { [number]: any } = {}
local profileStore: any = nil

local function defaultData(): PlayerProfileData
	-- Starter UUID gear: every item traceable from minute one.
	local weaponUID = HttpService:GenerateGUID(false)
	local armorUID = HttpService:GenerateGUID(false)
	-- The two presets ship genuinely different spells. They used to be an
	-- identical clone, which made the Warden/Raider swap a no-op for combat
	-- and left the whole "dual loadout" pitch meaningless on first join.
	local wardenLoadout: LoadoutPreset = {
		WeaponUID = weaponUID,
		ArmorUID = armorUID,
		Ring1UID = nil,
		Ring2UID = nil,
		SpellQ = "Aegis",
		SpellE = "Meteor",
		SpellR = "Bulwark",
	}
	local raiderLoadout: LoadoutPreset = {
		WeaponUID = weaponUID,
		ArmorUID = armorUID,
		Ring1UID = nil,
		Ring2UID = nil,
		SpellQ = "Blink",
		SpellE = "FrostNova",
		SpellR = "SiegeBeam",
	}
	return {
		PermanentVaultSouls = 0,
		BloodShards = 0,
		EclipseCrowns = 0,
		AscensionRank = 1,
		HasAlchemistPass = false,
		HasDualLoadoutPass = false,
		AutoRollEnabled = false,
		ActiveLoadoutType = "Warden",
		Loadouts = { Warden = wardenLoadout, Raider = raiderLoadout },
		Inventory = {
			[weaponUID] = {
				ItemUID = weaponUID,
				ItemId = "Apprentice_Branch",
				SlotType = "Weapon",
				UpgradeLevel = 0,
				PrefixTrait = nil,
				SuffixTrait = nil,
				IsFractured = false,
				IsTradable = false,
			},
			[armorUID] = {
				ItemUID = armorUID,
				ItemId = "Hexweave_Vestment",
				SlotType = "Armor",
				UpgradeLevel = 0,
				PrefixTrait = nil,
				SuffixTrait = nil,
				IsFractured = false,
				IsTradable = false,
			},
		},
		Walls = {
			[1] = { Unlocked = true, PermanentDefenseLevel = 0, AutoRenewElixir = false },
			[2] = { Unlocked = false, PermanentDefenseLevel = 0, AutoRenewElixir = false },
			[3] = { Unlocked = false, PermanentDefenseLevel = 0, AutoRenewElixir = false },
		},
		PendingOfflineTheft = 0,
		ClaimedPlaytimeGifts = {},
		ProcessedReceipts = {},
		ReforgeCredits = 0,
		LuckElixirUntil = 0,
	}
end

-- Minimal Studio mock so solo testing works without DataStore API access.
local function mockProfile(data: PlayerProfileData)
	local listeners: { () -> () } = {}
	local mock: any = {
		Data = data,
	}
	mock.AddUserId = function(_: any, _: number) end
	mock.Reconcile = function(_: any) end
	mock.ListenToRelease = function(_: any, fn: () -> ())
		table.insert(listeners, fn)
	end
	mock.Release = function(_: any)
		for _, fn in listeners do
			task.spawn(fn)
		end
	end
	return mock
end

function DataService.Init(profileStoreName: string?, _saveScope: string?)
	if ProfileService ~= nil then
		profileStore = ProfileService.GetProfileStore(profileStoreName or "ArcaneCitadel_01", defaultData())
	else
		warn("[DataService] ProfileService package missing. Run `wally install` and sync Packages. Studio plays session-only.")
	end

	local function onPlayerAdded(player: Player)
		-- Session-only path (no ProfileService package, or store init failed):
		-- mock profiles in Studio so the loop stays testable; live kicks
		-- because unsaved progress would silently vanish.
		if profileStore == nil then
			if RunService:IsStudio() then
				warn("[DataService] Studio mock profile (nothing persists).")
				profiles[player.UserId] = mockProfile(defaultData())
			else
				player:Kick("Data system unavailable. Rejoin to continue.")
			end
			return
		end
		local ok, profile = pcall(profileStore.LoadProfileAsync, profileStore, `Player_{player.UserId}`, "ForceLoad")
		if not ok or not profile then
			if RunService:IsStudio() then
				-- Studio without API access: play with a mock (nothing persists).
				warn("[DataService] Studio mock profile (DataStore unavailable). Progress will NOT save.")
				profiles[player.UserId] = mockProfile(defaultData())
				return
			end
			player:Kick("Profile load failed. Rejoin to continue.")
			return
		end
		profile:AddUserId(player.UserId)
		profile:Reconcile() -- Fill missing fields from defaultData().
		profile:ListenToRelease(function()
			profiles[player.UserId] = nil
			player:Kick("Profile released (loaded elsewhere). Rejoin to continue.")
		end)
		if player:IsDescendantOf(Players) then
			profiles[player.UserId] = profile
		else
			profile:Release()
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Studio Play Solo: the player may already exist before this script runs.
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- ProfileService session-lock safety: releasing on shutdown lets the
	-- next server ForceLoad immediately instead of waiting out a stale lock.
	game:BindToClose(function()
		for _, profile in profiles do
			pcall(function()
				(profile :: any):Release()
			end)
		end
	end)
end

-- Explicit release (GameService calls this AFTER banking / theft handling).
function DataService.Release(player: Player): ()
	DataService.ReleaseByUserId(player.UserId)
end

function DataService.ReleaseByUserId(userId: number): ()
	local profile = profiles[userId]
	profiles[userId] = nil
	if profile then
		profile:Release()
	end
end

function DataService.GetByUserId(userId: number): PlayerProfileData?
	local profile = profiles[userId]
	if profile then
		-- Backfill for profiles saved before Eclipse Crowns existed.
		if profile.Data.EclipseCrowns == nil then
			profile.Data.EclipseCrowns = 0
		end
		return profile.Data
	end
	return nil
end

-- Returns the live profile table (mutate + it auto-saves), or a
-- session-only default when ProfileService is unavailable.
function DataService.Get(player: Player): PlayerProfileData
	local profile = profiles[player.UserId]
	if profile then
		return profile.Data
	end
	return defaultData()
end

return DataService
