--!strict
-- Couches de terrain. La couche se déduit toujours de la profondeur du joueur.
-- Au-delà de la dernière couche, on reste dedans jusqu'aux mises à jour suivantes.

local Types = require(script.Parent.Parent.Types)

local list: { Types.StratumDef } = {
	{
		id = "Dirt",
		layer = 1,
		name = "Terre",
		nameWithArticle = "la Terre",
		minDepth = 0,
		maxDepth = 10,
		requiredShovel = "Wood",
		valueMultiplier = 1,
		cellColor = Color3.fromRGB(200, 150, 95), -- brun clair (la texture Ground assombrit)
	},
	{
		id = "Clay",
		layer = 2,
		name = "Argile",
		nameWithArticle = "l'Argile",
		minDepth = 10,
		maxDepth = 50,
		requiredShovel = "Iron",
		valueMultiplier = 2,
		cellColor = Color3.fromRGB(240, 120, 60), -- orange brique
	},
	{
		id = "Rock",
		layer = 3,
		name = "Roche",
		nameWithArticle = "la Roche",
		minDepth = 50,
		maxDepth = 200,
		requiredShovel = "Steel",
		valueMultiplier = 4,
		cellColor = Color3.fromRGB(175, 175, 185), -- gris
	},
}

local byId: { [Types.StratumId]: Types.StratumDef } = {}
local byLayer: { [number]: Types.StratumDef } = {}
for _, stratum in list do
	table.freeze(stratum)
	byId[stratum.id] = stratum
	byLayer[stratum.layer] = stratum
end

-- Couche correspondant à une profondeur (min inclus, max exclu). Bornée à la première et à la dernière.
local function fromDepth(depth: number): Types.StratumDef
	for index = #list, 1, -1 do
		if depth >= list[index].minDepth then
			return list[index]
		end
	end
	return list[1]
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
	byLayer = table.freeze(byLayer),
	fromDepth = fromDepth,
})
