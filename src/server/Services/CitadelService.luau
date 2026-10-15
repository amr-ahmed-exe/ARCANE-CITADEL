--!strict
-- Arcane Citadel: authoritative citadel / elixir / breach logic. Part 3.6.
-- Pure functions over CitadelSession; wire to DataService + heartbeat in Milestone 2.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WallConfig = require(ReplicatedStorage.Shared.Configurations.WallConfig)
local WraithConfig = require(ReplicatedStorage.Shared.Configurations.WraithConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configurations.MonetizationConfig)

export type LiveWallState = {
	Unlocked: boolean,
	PermanentLevel: number,
	CurrentHP: number,
	MaxHP: number,
	IsCollapsedForSession: boolean,
	ElixirExpiresAt: number,
	AutoRenewElixir: boolean,
}

export type CitadelSession = {
	OwnerUserId: number,
	PermanentVaultSouls: number,
	SessionSoulPot: number,
	AscensionRank: number,
	HasAlchemistPass: boolean, -- Waives the 1.5x Auto-Renew surcharge if owned
	IsBloodPactActive: boolean,
	BloodPactLockedUntil: number,
	BloodPactStartedAt: number, -- os.time() when the pact began (intensity ramp)
	RepairReadyAt: number, -- os.time() cooldown gate for soul repairs (anti-spam)
	AwaitingBreachDecision: boolean,
	ShieldUntil: number, -- Milestone 5: Blood Insurance wall immunity timestamp
	WardJamUntil: number, -- Milestone 4: invader Ward-Jamming Hex silence timestamp
	Walls: { [number]: LiveWallState },
}

local CitadelService = {}

-- Gameplay: Blood Pact intensity ramp. The longer a pact runs, the hotter
-- it gets (push-your-luck pressure: repair, hold the inner line, or cash
-- out). Tuned in WraithConfig.Budgets, not here.
local REPAIR_FRACTION = 0.20 -- each repair restores 20% of wall MaxHP
local REPAIR_COOLDOWN = 3 -- seconds between soul repairs (anti-spam)

function CitadelService.IntensityBonus(session: CitadelSession, now: number): number
	if not session.IsBloodPactActive then
		return 0
	end
	local elapsedMin = math.max(0, (now - (session.BloodPactStartedAt or now)) / 60)
	return math.min(WraithConfig.Budgets.ThreatRampCap, elapsedMin * WraithConfig.Budgets.ThreatRampPerMinute)
end

function CitadelService.CurrentThreat(session: CitadelSession, now: number): number
	if not session.IsBloodPactActive then
		return WraithConfig.Budgets.ThreatSanctuary
	end
	return WraithConfig.Budgets.ThreatBloodPact + CitadelService.IntensityBonus(session, now)
end

-- Milestone 4: true while an invader's Ward-Jamming Hex silences the wards.
function CitadelService.IsWardJammed(session: CitadelSession, now: number): boolean
	return now < (session.WardJamUntil or 0)
end

-- Helper: Computes effective defense ratio for a given wall ring
function CitadelService.GetEffectiveDefenseRatio(session: CitadelSession, wallIndex: number, now: number): number
	local spec = WallConfig[wallIndex]
	local wall = session.Walls[wallIndex]
	if not wall or not wall.Unlocked or wall.IsCollapsedForSession then
		return 0
	end

	local permBonus = wall.PermanentLevel * spec.UpgradeDefenseStep
	local elixirBonus = if now < wall.ElixirExpiresAt then spec.ElixirDefenseBonus else 0
	local passBonus = if (now < wall.ElixirExpiresAt and session.HasAlchemistPass)
		then MonetizationConfig.PassBonuses.AlchemistElixirDefense
		else 0

	return spec.BaseDefenseRatio + permBonus + elixirBonus + passBonus
end

-- Helper: Attempts to purchase or auto-renew an Ephemeral Defense Elixir
-- In Blood Pact Mode -> Deducts from SessionSoulPot
-- In Sanctuary Mode  -> Deducts from PermanentVaultSouls
function CitadelService.TryPurchaseElixir(
	session: CitadelSession,
	wallIndex: number,
	isAutoRenewal: boolean,
	now: number
): boolean
	local spec = WallConfig[wallIndex]
	local wall = session.Walls[wallIndex]
	if not wall or not wall.Unlocked or wall.IsCollapsedForSession then
		return false
	end

	-- Calculate cost (1.0x manual, 1.5x auto-renew unless player owns Master Alchemist Pass)
	local surcharge = 1.0
	if isAutoRenewal and not session.HasAlchemistPass then
		surcharge = spec.ElixirAutoRenewMultiplier
	end
	local finalCost = math.round(spec.ElixirBaseCost * surcharge)

	if session.IsBloodPactActive then
		-- Blood Pact: Spend directly from Session Soul Pot
		if session.SessionSoulPot < finalCost then
			return false
		end
		session.SessionSoulPot -= finalCost
	else
		-- Sanctuary Mode (AFK): Bank any floating Session Pot first, then deduct from Permanent Vault
		if session.SessionSoulPot > 0 then
			session.PermanentVaultSouls += session.SessionSoulPot
			session.SessionSoulPot = 0
		end
		if session.PermanentVaultSouls < finalCost then
			return false
		end
		session.PermanentVaultSouls -= finalCost
	end

	wall.ElixirExpiresAt = now + spec.ElixirDurationSeconds
	return true
end

-- Mid-fight soul repair: spend Session Pot (pact) or Vault (sanctuary) to
-- restore 20% MaxHP on a damaged, standing wall. Greed-vs-survival sink.
-- Returns (ok, cost).
function CitadelService.TryRepairWall(session: CitadelSession, wallIndex: number, now: number): (boolean, number)
	local spec = WallConfig[wallIndex]
	local wall = session.Walls[wallIndex]
	if not wall or not wall.Unlocked or wall.IsCollapsedForSession then
		return false, 0
	end
	if wall.CurrentHP >= wall.MaxHP then
		return false, 0 -- already at full strength
	end
	if now < (session.RepairReadyAt or 0) then
		return false, 0 -- 3s anti-spam gate
	end
	local heal = math.floor(wall.MaxHP * REPAIR_FRACTION)
	heal = math.min(heal, wall.MaxHP - wall.CurrentHP)
	local cost = math.round(heal * (spec.RepairCostPerHP or 5))

	if session.IsBloodPactActive then
		if session.SessionSoulPot < cost then
			return false, cost
		end
		session.SessionSoulPot -= cost
	else
		if session.SessionSoulPot > 0 then
			session.PermanentVaultSouls += session.SessionSoulPot
			session.SessionSoulPot = 0
		end
		if session.PermanentVaultSouls < cost then
			return false, cost
		end
		session.PermanentVaultSouls -= cost
	end

	wall.CurrentHP += heal
	session.RepairReadyAt = now + REPAIR_COOLDOWN
	return true, cost
end

-- Triggered when the outermost active wall's HP reaches 0
-- `distributeRaiderLootCallback` is the single funnel every breach passes
-- through (decay tick, wraith tick and raider combat), so it receives the
-- wall index alongside the stolen amount. Consumers use that to arm the
-- Blood Insurance receipt without having to diff wall state a second later.
function CitadelService.HandleWallBreach(
	session: CitadelSession,
	wallIndex: number,
	distributeRaiderLootCallback: (wallIndex: number, stolenSouls: number) -> ()
)
	local spec = WallConfig[wallIndex]
	local wall = session.Walls[wallIndex]
	if not wall or wall.IsCollapsedForSession then
		return -- Already breached (double-breach guard: decay + wraiths tick together).
	end
	wall.CurrentHP = 0
	wall.IsCollapsedForSession = true
	wall.ElixirExpiresAt = 0 -- Active elixir is lost when the wall shatters

	if session.IsBloodPactActive then
		-- Calculate Raider Cut (33% on Wall 3, 50% of remaining on Wall 2, 100% on Wall 1)
		local stolenSouls = math.floor(session.SessionSoulPot * spec.BreachStealFraction)
		session.SessionSoulPot -= stolenSouls
		distributeRaiderLootCallback(wallIndex, stolenSouls)

		if wallIndex == 1 then
			-- Total Citadel Fall: Force exit Blood Pact and rebuild in Sanctuary Mode
			CitadelService.ExitBloodPactAndBank(session)
		else
			-- Wall 3 or Wall 2 fell: Prompt Defender with the "Cash Out 67% vs. Hold Inner Perimeter" modal
			session.AwaitingBreachDecision = true
		end
	else
		-- In Sanctuary Mode (PvE only): Wall stays down for 60s, no Vault Souls stolen
		task.delay(60, function()
			if not session.IsBloodPactActive then
				wall.IsCollapsedForSession = false
				wall.CurrentHP = wall.MaxHP
			end
		end)
	end
end

-- Called when Defender clicks "Accept Defeat & Cash Out Remaining 67%" OR when 30-min Blood Pact ends cleanly
function CitadelService.ExitBloodPactAndBank(session: CitadelSession)
	session.IsBloodPactActive = false
	session.AwaitingBreachDecision = false
	session.BloodPactStartedAt = 0 -- intensity ramp resets for the next pact

	-- Transfer all surviving Session Pot Souls into the 100% Safe Permanent Vault
	session.PermanentVaultSouls += session.SessionSoulPot
	session.SessionSoulPot = 0

	-- Rebuild all collapsed walls for Sanctuary Mode
	for _, wall in pairs(session.Walls) do
		if wall.Unlocked then
			wall.IsCollapsedForSession = false
			wall.CurrentHP = wall.MaxHP
		end
	end
end

-- 1-Second Authoritative Heartbeat Tick
function CitadelService.StepEconomyAndDecay(
	session: CitadelSession,
	liveMultiplier: number,
	now: number,
	distributeRaiderLootCallback: (wallIndex: number, stolenSouls: number) -> ()
)
	-- 1. Generate Souls from all intact, unlocked walls
	local generatedThisTick = 0
	local outermostIntactIndex = 0

	for i = 3, 1, -1 do
		local wall = session.Walls[i]
		if wall and wall.Unlocked and not wall.IsCollapsedForSession then
			if outermostIntactIndex == 0 then
				outermostIntactIndex = i
			end

			-- Check Elixir expiration & Auto-Renewal before calculating defense
			if now >= wall.ElixirExpiresAt and wall.AutoRenewElixir then
				local renewed = CitadelService.TryPurchaseElixir(session, i, true, now)
				if not renewed then
					wall.AutoRenewElixir = false -- Disable toggle if out of funds
				end
			end

			generatedThisTick += (WallConfig[i].BaseSoulsPerSecond * liveMultiplier)
		end
	end

	-- Route generated Souls: In Sanctuary Mode, bank straight to Vault; in Blood Pact, lock in Session Pot
	if session.IsBloodPactActive then
		session.SessionSoulPot += math.round(generatedThisTick)
	else
		session.PermanentVaultSouls += math.round(generatedThisTick)
	end

	-- 2. Apply Automated Defense vs. Monster Threat on the Outermost Intact Wall
	if outermostIntactIndex > 0 then
		local outerWall = session.Walls[outermostIntactIndex]
		local shielded = now < (session.ShieldUntil or 0) -- Milestone 5: Blood Insurance immunity
		local effectiveDefense = CitadelService.GetEffectiveDefenseRatio(session, outermostIntactIndex, now)
		local incomingThreat = CitadelService.CurrentThreat(session, now)

		-- If automated defense is below threat, wall bleeds HP unless player kills Wraiths manually
		if effectiveDefense < incomingThreat and not shielded then
			local deficit = incomingThreat - effectiveDefense
			local bleedDamage = math.round(outerWall.MaxHP * (deficit * 0.015))
			outerWall.CurrentHP = math.max(0, outerWall.CurrentHP - bleedDamage)

			if outerWall.CurrentHP <= 0 then
				CitadelService.HandleWallBreach(session, outermostIntactIndex, distributeRaiderLootCallback)
			end
		end
	end
end

return CitadelService
