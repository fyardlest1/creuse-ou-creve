--!strict
-- Décor interactif : stands du Marchand et de la Forge, coffres des parcelles, et leurs ProximityPrompt.

local WorldConfig = {
	-- Valeur de l'attribut "Interaction" posé sur chaque ProximityPrompt, lue par les contrôleurs client.
	INTERACTION_ATTRIBUTE = "Interaction",
	INTERACTIONS = table.freeze({
		Merchant = "Merchant",
		Forge = "Forge",
		Chest = "Chest",
		Pick = "Pick", -- crocheter le coffre d'un autre joueur (la nuit)
		ThiefShop = "ThiefShop", -- boutique de cosmétiques de voleur (Points de Voleur)
	}),
	-- Tag CollectionService des prompts réservés aux VIP (le client les masque aux autres joueurs).
	VIP_ONLY_TAG = "VipOnly",

	-- Salon VIP (plan semaine 5, section 9), derrière le Marchand, sur la place centrale.
	-- Taille intérieure : X (profondeur), hauteur des murs, Z (largeur). La porte est sur le mur côté
	-- Marchand (+X). Rangées de parcelles à 14 studs de l'axe : le salon en laisse 6 de chaque côté.
	VIP_LOUNGE_OFFSET = Vector3.new(-32, 0, 0),
	VIP_LOUNGE_SIZE = Vector3.new(16, 10, 14),
	VIP_WALL_THICKNESS = 1,
	VIP_DOOR_WIDTH = 6,
	VIP_FLOOR_HEIGHT = 0.4,
	VIP_WALL_COLOR = Color3.fromRGB(55, 35, 85), -- violet profond
	VIP_TRIM_COLOR = Color3.fromRGB(255, 200, 40), -- doré (même couleur que l'étiquette VIP)
	VIP_CARPET_COLOR = Color3.fromRGB(150, 30, 45), -- tapis rouge
	VIP_DOOR_TRANSPARENCY = 0.45,
	VIP_PILLAR_SIZE = Vector3.new(1.6, 11, 1.6),
	VIP_LIGHT_RANGE = 14,
	VIP_LIGHT_BRIGHTNESS = 1.5,
	VIP_SIGN_HEIGHT = 17.5, -- studs : au-dessus du panneau du Marchand VIP, pour ne pas le chevaucher
	-- Marchand VIP : même vente, mêmes prix (le +10 % VIP s'applique déjà partout).
	VIP_MERCHANT_OFFSET = Vector3.new(-4, 0, 0), -- depuis le centre du salon
	VIP_MERCHANT_COLOR = Color3.fromRGB(200, 160, 40),
	VIP_MERCHANT_ROOF_COLOR = Color3.fromRGB(120, 40, 140),
	VIP_PROMPT_MAX_DISTANCE = 8, -- plus court que les autres : pas de prompt à travers le mur
	-- Porte : les personnages VIP ne la heurtent pas (groupes de collision).
	VIP_DOOR_COLLISION_GROUP = "VipDoor",
	VIP_MEMBER_COLLISION_GROUP = "VipMember",
	-- Garde-fou côté serveur : un joueur non VIP trouvé dans le salon est replacé devant la porte.
	VIP_EVICT_CHECK_INTERVAL = 1, -- secondes
	VIP_EVICT_DISTANCE = 4, -- studs devant la porte

	-- Repaire des Voleurs : boutique de cosmétiques, derrière la Forge (symétrique du salon VIP).
	THIEF_SHOP_OFFSET = Vector3.new(30, 0, 0),
	THIEF_SHOP_COLOR = Color3.fromRGB(70, 45, 95),
	THIEF_SHOP_ROOF_COLOR = Color3.fromRGB(35, 35, 42),

	-- Stands, placés sur la place centrale (décalage depuis PlotConfig.PLOT_ORIGIN), tournés vers le centre
	MERCHANT_OFFSET = Vector3.new(-14, 0, 0),
	FORGE_OFFSET = Vector3.new(14, 0, 0),
	STAND_FLOOR_SIZE = Vector3.new(12, 1, 8),
	STAND_COUNTER_SIZE = Vector3.new(10, 3, 2),
	STAND_POST_SIZE = Vector3.new(1, 9, 1),
	STAND_ROOF_SIZE = Vector3.new(13, 1, 9),
	STAND_SIGN_HEIGHT = 13, -- studs au-dessus du sol
	STAND_SIGN_WIDTH = 14, -- studs
	STAND_SIGN_TEXT_HEIGHT = 3.5, -- studs
	STAND_SIGN_MAX_DISTANCE = 200,
	-- Tag CollectionService des panneaux du monde (parcelles, stands) : le client les garde sous le HUD.
	SIGN_TAG = "WorldSign",

	MERCHANT_COLOR = Color3.fromRGB(70, 160, 90),
	MERCHANT_ROOF_COLOR = Color3.fromRGB(240, 200, 70),

	FORGE_COLOR = Color3.fromRGB(85, 85, 95),
	FORGE_ROOF_COLOR = Color3.fromRGB(230, 110, 40),

	STAND_WOOD_COLOR = Color3.fromRGB(120, 80, 50),

	-- Coffre, au bord extérieur de chaque parcelle, à côté du point d'apparition
	CHEST_SIZE = Vector3.new(4, 3, 3),
	CHEST_LID_HEIGHT = 0.8,
	CHEST_SIDE_OFFSET = 10, -- studs sur le côté, depuis l'axe de la parcelle
	CHEST_EDGE_OFFSET = 3, -- studs au-delà du bord de la parcelle
	CHEST_COLOR = Color3.fromRGB(130, 85, 45),
	CHEST_TRIM_COLOR = Color3.fromRGB(240, 190, 60),
	-- Garde du corps (game pass) posté près du coffre
	BODYGUARD_COLOR = Color3.fromRGB(35, 45, 80), -- uniforme bleu nuit
	BODYGUARD_SKIN_COLOR = Color3.fromRGB(205, 160, 125),
	BODYGUARD_OFFSET = Vector3.new(-4.5, 1.5, 0), -- studs depuis le coffre ; la lanterne est du côté +X
	-- Attributs d'affichage du vol
	ATTRIBUTE_BEING_PICKED = "BeingPicked", -- sur le coffre : un crochetage est en cours (clignote)

	-- ProximityPrompt (portée inférieure à la distance validée par le serveur)
	PROMPT_MAX_DISTANCE = 10,
	PROMPT_KEY = Enum.KeyCode.E,
	PICK_PROMPT_OFFSET = Vector2.new(0, 70), -- pixels : décale "Crocheter" sous "Ouvrir le coffre"

	-- Fumée noire des coffres qui contiennent un objet Maudit (la nuit)
	-- Noir violacé : un noir pur disparaît dans la nuit, celui-ci se détache du ciel sans s'éclairer.
	CURSED_SMOKE_COLOR = Color3.fromRGB(45, 30, 60),
	CURSED_SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds",
	CURSED_SMOKE_SIZE_START = 3, -- studs
	CURSED_SMOKE_SIZE_END = 7,
	CURSED_SMOKE_TRANSPARENCY = 0.15, -- au départ ; la fumée s'estompe en montant
	CURSED_SMOKE_LIFETIME = 3, -- secondes
	CURSED_SMOKE_RATE = 20, -- particules par seconde
	CURSED_SMOKE_SPEED = 3, -- studs par seconde
	CURSED_SMOKE_REFRESH_INTERVAL = 1, -- secondes entre deux vérifications des coffres
}

return table.freeze(WorldConfig)
