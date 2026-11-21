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
	}),

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
