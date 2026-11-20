--!strict
-- Probabilités de rareté affichées aux joueurs (boutique, Index). Même règle que le serveur
-- (LootService.rollRarity) : les poids des raretés boostées sont multipliés, puis renormalisés.

local Rarities = require(script.Parent.Config.Rarities)

local LuckOdds = {}

-- Pourcentage de chaque rareté pour un multiplicateur de chance donné.
function LuckOdds.oddsFor(multiplier: number): { [string]: number }
	local total = 0
	local weights: { [string]: number } = {}
	for _, rarity in Rarities.list do
		local weight = if rarity.isLuckBoosted then rarity.chance * multiplier else rarity.chance
		weights[rarity.id] = weight
		total += weight
	end
	local odds: { [string]: number } = {}
	for id, weight in weights do
		odds[id] = weight / total * 100
	end
	return odds
end

-- 59.6 -> "59,6" ; 0.94 -> "0,94"
function LuckOdds.formatPercent(value: number): string
	local text = if value >= 1 then string.format("%.1f", value) else string.format("%.2f", value)
	return (text:gsub("%.", ","))
end

-- Multiplicateur : jusqu'à 2 décimales, sans zéros inutiles (x1,05 ; x2,1 ; x10).
function LuckOdds.formatMultiplier(value: number): string
	local text = string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
	return (text:gsub("%.", ","))
end

return LuckOdds
