--!strict
-- Pelles. Semaine 1 : pelle en bois seulement, les suivantes viendront avec la boutique.

local Types = require(script.Parent.Parent.Types)

local list: { Types.ShovelDef } = {
	{ id = "wood", name = "Pelle en Bois", power = 1, luckBonus = 0, price = 0 },
}

local byId: { [string]: Types.ShovelDef } = {}
for _, shovel in list do
	byId[shovel.id] = table.freeze(shovel)
end

return table.freeze({
	DEFAULT_ID = "wood",
	list = table.freeze(list),
	byId = table.freeze(byId),
})
