--!strict
-- Mutations, tirées après la rareté. Une seule par objet. Maudit ne se tire que la nuit.

local Types = require(script.Parent.Parent.Types)

local list: { Types.MutationDef } = {
	{
		id = "Golden",
		displayName = "Doré",
		chance = 2,
		multiplier = 3,
		color = Color3.fromRGB(255, 205, 60),
		nightOnly = false,
	},
	{
		id = "Diamond",
		displayName = "Diamant",
		chance = 0.5,
		multiplier = 6,
		color = Color3.fromRGB(150, 230, 255),
		nightOnly = false,
	},
	{
		id = "Rainbow",
		displayName = "Arc-en-ciel",
		chance = 0.1,
		multiplier = 15,
		color = Color3.fromRGB(255, 120, 220),
		nightOnly = false,
	},
	{
		id = "Cursed",
		displayName = "Maudit",
		chance = 1,
		multiplier = 5,
		color = Color3.fromRGB(120, 60, 160),
		nightOnly = true,
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
