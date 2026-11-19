--!strict
-- Objets à déterrer, par couche. Chaque couche a au moins 2 objets de chaque rareté.

local Types = require(script.Parent.Parent.Types)

local list: { Types.ItemDef } = {
	-- Couche 1 : la Terre (déchets drôles, pièces anciennes)
	{ id = "lost_sock", name = "Chaussette Perdue", rarity = "Common", layer = 1 },
	{ id = "rusty_can", name = "Canette Rouillée", rarity = "Common", layer = 1 },
	{ id = "chewed_pencil", name = "Crayon Mâchouillé", rarity = "Common", layer = 1 },
	{ id = "lucky_button", name = "Bouton Porte-Bonheur", rarity = "Uncommon", layer = 1 },
	{ id = "grandma_spoon", name = "Cuillère de Mamie", rarity = "Uncommon", layer = 1 },
	{ id = "dino_tooth", name = "Dent de Dinosaure", rarity = "Rare", layer = 1 },
	{ id = "pirate_coin", name = "Pièce de Pirate", rarity = "Rare", layer = 1 },
	{ id = "gold_watch", name = "Montre en Or", rarity = "Epic", layer = 1 },
	{ id = "king_crown", name = "Couronne de Roi Oublié", rarity = "Epic", layer = 1 },
	{ id = "dragon_bone", name = "Os de Dragon", rarity = "Legendary", layer = 1 },
	{ id = "mermaid_trident", name = "Trident de Sirène", rarity = "Legendary", layer = 1 },
	{ id = "cosmic_egg", name = "Œuf Cosmique", rarity = "Secret", layer = 1 },
	{ id = "alien_remote", name = "Télécommande Extraterrestre", rarity = "Secret", layer = 1 },

	-- Couche 2 : l'Argile (fossiles, jouets perdus)
	{ id = "odd_marbles", name = "Billes Dépareillées", rarity = "Common", layer = 2 },
	{ id = "fossil_shell", name = "Coquillage Fossile", rarity = "Common", layer = 2 },
	{ id = "wheelless_car", name = "Petite Voiture Sans Roues", rarity = "Uncommon", layer = 2 },
	{ id = "round_ammonite", name = "Ammonite Toute Ronde", rarity = "Uncommon", layer = 2 },
	{ id = "fossil_teddy", name = "Doudou Fossilisé", rarity = "Rare", layer = 2 },
	{ id = "pterodactyl_egg", name = "Œuf de Ptérodactyle", rarity = "Rare", layer = 2 },
	{ id = "grumpy_robot", name = "Robot à Remonter Grincheux", rarity = "Epic", layer = 2 },
	{ id = "triceratops_skull", name = "Crâne de Tricératops", rarity = "Epic", layer = 2 },
	{ id = "mammoth_tusk", name = "Défense de Mammouth", rarity = "Legendary", layer = 2 },
	{ id = "ancient_console", name = "Console de Jeu Préhistorique", rarity = "Legendary", layer = 2 },
	{ id = "roaring_trex_plush", name = "T-Rex en Peluche Qui Rugit Vraiment", rarity = "Secret", layer = 2 },
	{ id = "unicorn_fossil", name = "Fossile de Licorne", rarity = "Secret", layer = 2 },

	-- Couche 3 : la Roche (cristaux, trésors de pirates)
	{ id = "shiny_pebble", name = "Caillou Qui Brille Un Peu", rarity = "Common", layer = 3 },
	{ id = "pirate_button", name = "Bouton de Veste de Pirate", rarity = "Common", layer = 3 },
	{ id = "candy_quartz", name = "Quartz Rose Bonbon", rarity = "Uncommon", layer = 3 },
	{ id = "cracked_spyglass", name = "Longue-Vue Fêlée", rarity = "Uncommon", layer = 3 },
	{ id = "sulky_amethyst", name = "Améthyste Boudeuse", rarity = "Rare", layer = 3 },
	{ id = "torn_treasure_map", name = "Carte au Trésor Déchirée", rarity = "Rare", layer = 3 },
	{ id = "starry_geode", name = "Géode Pleine d'Étoiles", rarity = "Epic", layer = 3 },
	{ id = "captain_hook", name = "Crochet du Capitaine", rarity = "Epic", layer = 3 },
	{ id = "storm_captain_chest", name = "Coffre du Capitaine Tempête", rarity = "Legendary", layer = 3 },
	{ id = "singing_crystal", name = "Cristal Qui Chante Faux", rarity = "Legendary", layer = 3 },
	{ id = "crystal_parrot", name = "Perroquet de Cristal Qui Parle", rarity = "Secret", layer = 3 },
	{ id = "earth_heart_diamond", name = "Diamant du Cœur de la Terre", rarity = "Secret", layer = 3 },
}

local byId: { [string]: Types.ItemDef } = {}
for _, item in list do
	assert(byId[item.id] == nil, "[Items] Identifiant en double : " .. item.id)
	byId[item.id] = table.freeze(item)
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
})
