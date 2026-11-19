--!strict
-- Mutations, tirées après la rareté. Une seule par objet. (Maudit arrivera avec la nuit.)

local Types = require(script.Parent.Parent.Types)

local list: { Types.MutationDef } = {
	{ id = "Golden", displayName = "Doré", chance = 2, multiplier = 3, color = Color3.fromRGB(255, 205, 60) },
	{ id = "Diamond", displayName = "Diamant", chance = 0.5, multiplier = 6, color = Color3.fromRGB(150, 230, 255) },
	{
		id = "Rainbow",
		displayName = "Arc-en-ciel",
		chance = 0.1,
		multiplier = 15,
		color = Color3.fromRGB(255, 120, 220),
	},
}

local byId: { [string]: Types.MutationDef } = {}
for _, mutation in list do
	byId[mutation.id] = table.freeze(mutation)
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
})
