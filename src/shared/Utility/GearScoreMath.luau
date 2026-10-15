--!strict
-- Arcane Citadel: links equipped RPG items + traits + fracture into
-- Attacker Power (AP_i) and Defender Rating (DR_def). Part 3.3.

local GearConfig = require(script.Parent.Parent.Configurations.GearConfig)
local TraitConfig = require(script.Parent.Parent.Configurations.TraitConfig)

local GearScoreMath = {}

function GearScoreMath.CalculatePlayerGearScore(ascensionRank: number, equippedItems: { any }): number
	local baseRankPower = ascensionRank * 500
	local gearPower = 0

	for _, item in ipairs(equippedItems) do
		local cfg = GearConfig[item.ItemId]
		if cfg then
			local itemScore = cfg.GearScore * (1 + (item.UpgradeLevel or 0) * 0.08)

			if item.PrefixTrait and TraitConfig.Traits[item.PrefixTrait] then
				itemScore *= TraitConfig.Traits[item.PrefixTrait].PowerMultiplier
			end
			if item.SuffixTrait and TraitConfig.Traits[item.SuffixTrait] then
				itemScore *= TraitConfig.Traits[item.SuffixTrait].PowerMultiplier
			end
			if item.IsFractured then
				itemScore *= 0.75 -- 25% Albion-Lite Fracture penalty if killed 5 times in a raid
			end

			gearPower += itemScore
		end
	end

	return math.floor(baseRankPower + gearPower)
end

return GearScoreMath
