--!strict
-- Objets à déterrer. Couche 1 : la Terre.

local Types = require(script.Parent.Parent.Types)

local list: { Types.ItemDef } = {
	-- Commun
	{ id = "lost_sock", name = "Chaussette Perdue", rarity = "Common", layer = 1 },
	{ id = "rusty_can", name = "Canette Rouillée", rarity = "Common", layer = 1 },
	{ id = "chewed_pencil", name = "Crayon Mâchouillé", rarity = "Common", layer = 1 },
	-- Peu commun
	{ id = "lucky_button", name = "Bouton Porte-Bonheur", rarity = "Uncommon", layer = 1 },
	{ id = "grandma_spoon", name = "Cuillère de Mamie", rarity = "Uncommon", layer = 1 },
	-- Rare
	{ id = "dino_tooth", name = "Dent de Dinosaure", rarity = "Rare", layer = 1 },
	{ id = "pirate_coin", name = "Pièce de Pirate", rarity = "Rare", layer = 1 },
	-- Épique
	{ id = "gold_watch", name = "Montre en Or", rarity = "Epic", layer = 1 },
	{ id = "king_crown", name = "Couronne de Roi Oublié", rarity = "Epic", layer = 1 },
	-- Légendaire
	{ id = "dragon_bone", name = "Os de Dragon", rarity = "Legendary", layer = 1 },
	{ id = "mermaid_trident", name = "Trident de Sirène", rarity = "Legendary", layer = 1 },
	-- Secret
	{ id = "cosmic_egg", name = "Œuf Cosmique", rarity = "Secret", layer = 1 },
	{ id = "alien_remote", name = "Télécommande Extraterrestre", rarity = "Secret", layer = 1 },
}

local byId: { [string]: Types.ItemDef } = {}
for _, item in list do
	byId[item.id] = table.freeze(item)
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
})
