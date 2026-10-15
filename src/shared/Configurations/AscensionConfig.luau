--!strict
-- Arcane Citadel: Ascension (Rebirth) tuning.
-- When all 3 walls hit MaxPermanentLevel, the defender may Ascend:
-- Vault resets to 0, walls drop to the new Rank Floor (rank - 1),
-- permanent soul income rises by SoulStep per rank. MaxRank = 4.

local AscensionConfig = {
	MaxPermanentLevel = 5,
	MaxRank = 4,
	SoulStep = 0.25, -- +25% permanent Souls per rank above 1
	RankNames = { "Cursed Wood", "Runic Stone", "Obsidian", "Void Metal" },
}

function AscensionConfig.SoulMultiplier(rank: number): number
	return 1 + AscensionConfig.SoulStep * (math.clamp(rank, 1, AscensionConfig.MaxRank) - 1)
end

function AscensionConfig.RankName(rank: number): string
	return AscensionConfig.RankNames[math.clamp(rank, 1, AscensionConfig.MaxRank)]
end

return AscensionConfig
