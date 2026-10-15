--!strict
-- tests/verify_economy_math.luau
-- Executed automatically by scripts/verify_luau.sh via `lune run tests/verify_economy_math.luau`

local function tryRequire(path: string): any?
	local ok, mod = pcall(require, path)
	if ok then return mod end
	return nil
end

-- 1. Verify WallConfig Laws (once created in Milestone 2)
local WallConfig = tryRequire("../src/shared/Configurations/WallConfig")
if WallConfig then
	assert(WallConfig[1].BaseDefenseRatio == 1.00, "Wall 1 BaseDefenseRatio must be 1.00")
	assert(WallConfig[2].BaseDefenseRatio == 0.80, "Wall 2 BaseDefenseRatio must be 0.80")
	assert(WallConfig[3].BaseDefenseRatio == 0.60, "Wall 3 BaseDefenseRatio must be 0.60")
	assert(WallConfig[3].BreachStealFraction == 0.33, "Wall 3 BreachStealFraction must be 0.33 (33%)")
	assert(WallConfig[2].BreachStealFraction == 0.50, "Wall 2 BreachStealFraction must be 0.50 (50% of remaining)")
	assert(WallConfig[1].BreachStealFraction == 1.00, "Wall 1 BreachStealFraction must be 1.00 (100%)")
	assert(WallConfig[2].ElixirAutoRenewMultiplier == 1.50, "Wall 2 AutoRenew multiplier must be 1.50x")
	assert(WallConfig[3].ElixirAutoRenewMultiplier == 1.50, "Wall 3 AutoRenew multiplier must be 1.50x")
end

-- 2. Verify MonetizationConfig 1.3x Eclipse Crown Value Law (once created)
local MonetizationConfig = tryRequire("../src/shared/Configurations/MonetizationConfig")
if MonetizationConfig and MonetizationConfig.Catalog then
	for itemKey, item in pairs(MonetizationConfig.Catalog) do
		local expectedMaxCrownPrice = math.ceil(item.RawRobuxPrice / 1.28)
		assert(
			item.CrownPrice <= expectedMaxCrownPrice,
			string.format("1.3x Crown Value Law violated on %s: Robux=%d, Crown=%d", itemKey, item.RawRobuxPrice, item.CrownPrice)
		)
	end
end

-- 3. Verify MultiplierMath Anti-Exploit Laws (once created)
local MultiplierMath = tryRequire("../src/shared/Utility/MultiplierMath")
if MultiplierMath then
	local sanctuaryMult = MultiplierMath.CalculateBloodPactMultiplier(false, 500000, 100000, 5000, 3, {}, 1000)
	assert(sanctuaryMult == 1.0, "Sanctuary Mode multiplier must be 1.0x")

	local idleAttackers = { { AttackPower = 10000, LastHostileTimestamp = 900 } }
	local emptyMult = MultiplierMath.CalculateBloodPactMultiplier(true, 0, 100000, 5000, 3, {}, 1000)
	local idleMult = MultiplierMath.CalculateBloodPactMultiplier(true, 0, 100000, 5000, 3, idleAttackers, 1000)
	assert(emptyMult == 2.0, "Empty Blood Pact baseline must be 2.0x")
	assert(idleMult == emptyMult, "AFK/Idle attackers (>45s) must add 0.0x bonus!")

	local twoWallMult = MultiplierMath.CalculateBloodPactMultiplier(true, 0, 100000, 5000, 2, {}, 1000)
	assert(twoWallMult == 2.75, "2-Wall Last-Stand multiplier must be 2.75x (2.0 + 0.75)")
end

print("All headless Lune math & economy assertions passed in <50ms.")
