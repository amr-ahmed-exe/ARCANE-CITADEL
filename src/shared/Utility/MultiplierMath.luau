--!strict
-- Arcane Citadel: threat-weighted Blood Pact soul multiplier. Part 3.5.

export type AttackerSnapshot = {
	AttackPower: number,
	LastHostileTimestamp: number,
}

local MultiplierMath = {}

local ALPHA_THREAT_COEFF = 0.65
local HOSTILE_WINDOW_SECONDS = 45
local MAX_GREED_BONUS = 4.0
-- Blueprint headline: "Blood Pact Mode (2.0x to 15.0x+ Open Siege)". The
-- attacker term is a sum over every hostile raider, so without a ceiling a
-- crowded raid pushed the multiplier arbitrarily past the advertised max.
local MAX_TOTAL_MULTIPLIER = 15.0

function MultiplierMath.CalculateBloodPactMultiplier(
	isBloodPactActive: boolean,
	sessionSoulPot: number,
	rankVaultBenchmark: number,
	defenderRating: number,
	intactWallCount: number,
	attackers: { AttackerSnapshot },
	currentTime: number
): number
	if not isBloodPactActive then
		return 1.0
	end

	-- 1. Empty Blood Pact Baseline (2.0x)
	local baseMultiplier = 2.0

	-- 2. Session Pot Greed Bonus (0.0x to 4.0x)
	local safeBenchmark = math.max(1000, rankVaultBenchmark)
	local greedBonus = math.min(MAX_GREED_BONUS, sessionSoulPot / safeBenchmark)

	-- 3. Last-Stand Broken Wall Bonus (Rewards holding the tighter 2-Wall or 1-Wall perimeter)
	local lastStandBonus = 0.0
	if intactWallCount == 2 then
		lastStandBonus = 0.75 -- Wall 3 collapsed; holding Wall 2
	elseif intactWallCount == 1 then
		lastStandBonus = 1.75 -- Wall 3 & 2 collapsed; holding Inner Sanctum
	end

	-- 4. Active Hostile Attacker Power Ratio Sum
	local safeDefenderRating = math.max(100, defenderRating)
	local attackerBonus = 0.0

	for _, attacker in ipairs(attackers) do
		local isActivelyHostile = (currentTime - attacker.LastHostileTimestamp) <= HOSTILE_WINDOW_SECONDS
		if isActivelyHostile then
			local ratio = attacker.AttackPower / safeDefenderRating
			attackerBonus += (ALPHA_THREAT_COEFF * ratio)
		end
	end

	local total = baseMultiplier + greedBonus + lastStandBonus + attackerBonus
	return math.min(MAX_TOTAL_MULTIPLIER, math.round(total * 100) / 100)
end

return MultiplierMath
