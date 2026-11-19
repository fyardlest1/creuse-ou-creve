--!strict
-- Pelles, dans l'ordre d'achat : on ne peut acheter une pelle que si on possède la précédente.

local Types = require(script.Parent.Parent.Types)

local list: { Types.ShovelDef } = {
	{ id = "Wood", name = "Pelle en bois", price = 0, hitsPerCell = 3, luckBonus = 0, maxStratum = "Dirt" },
	{ id = "Iron", name = "Pelle en fer", price = 500, hitsPerCell = 2, luckBonus = 5, maxStratum = "Clay" },
	{ id = "Steel", name = "Pelle en acier", price = 25000, hitsPerCell = 2, luckBonus = 15, maxStratum = "Rock" },
}

local byId: { [string]: Types.ShovelDef } = {}
local orderById: { [string]: number } = {}
for index, shovel in list do
	byId[shovel.id] = table.freeze(shovel)
	orderById[shovel.id] = index
end

-- Pelle à posséder avant de pouvoir acheter celle-ci (nil pour la première).
local function getPrevious(shovelId: string): Types.ShovelDef?
	local order = orderById[shovelId]
	if order == nil or order <= 1 then
		return nil
	end
	return list[order - 1]
end

return table.freeze({
	DEFAULT_ID = "Wood" :: Types.ShovelId,
	list = table.freeze(list),
	byId = table.freeze(byId),
	orderById = table.freeze(orderById),
	getPrevious = getPrevious,
})
