--!strict
-- Les 6 raretés, de la plus commune à la plus rare. Chances en pourcentage.

local Types = require(script.Parent.Parent.Types)

local list: { Types.RarityDef } = {
	{
		id = "Common",
		displayName = "Commun",
		chance = 60,
		color = Color3.fromRGB(170, 170, 170),
		value = 10,
		isLuckBoosted = false,
		isSpectacular = false,
	},
	{
		id = "Uncommon",
		displayName = "Peu commun",
		chance = 25,
		color = Color3.fromRGB(85, 200, 85),
		value = 40,
		isLuckBoosted = false,
		isSpectacular = false,
	},
	{
		id = "Rare",
		displayName = "Rare",
		chance = 10,
		color = Color3.fromRGB(60, 140, 255),
		value = 150,
		isLuckBoosted = true,
		isSpectacular = false,
	},
	{
		id = "Epic",
		displayName = "Épique",
		chance = 4,
		color = Color3.fromRGB(170, 80, 230),
		value = 600,
		isLuckBoosted = true,
		isSpectacular = false,
	},
	{
		id = "Legendary",
		displayName = "Légendaire",
		chance = 0.9,
		color = Color3.fromRGB(255, 190, 40),
		value = 3000,
		isLuckBoosted = true,
		isSpectacular = true,
	},
	{
		id = "Secret",
		displayName = "Secret",
		chance = 0.1,
		color = Color3.fromRGB(255, 80, 200), -- arc-en-ciel animé côté client
		value = 25000,
		isLuckBoosted = true,
		isSpectacular = true,
	},
}

local byId: { [string]: Types.RarityDef } = {}
for _, rarity in list do
	byId[rarity.id] = table.freeze(rarity)
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
})
