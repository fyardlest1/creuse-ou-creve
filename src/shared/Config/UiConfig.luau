--!strict
-- Délais, tailles et sons de l'interface et des retours visuels.
-- Sons temporaires : sons intégrés à Roblox, à remplacer par de vrais assets plus tard.

local UiConfig = {
	-- Carte de révélation
	REVEAL_APPEAR_TIME = 0.3,
	REVEAL_HOLD_TIME = 1.5,
	REVEAL_FADE_TIME = 0.3,
	REVEAL_SPECTACULAR_SCALE = 1.35, -- carte plus grande pour Légendaire et Secret
	REVEAL_SPECTACULAR_HOLD_TIME = 2.5,
	REVEAL_FLASH_TIME = 0.6,
	RAINBOW_SPIN_SPEED = 180, -- degrés par seconde pour le dégradé arc-en-ciel

	-- Bandeaux du HUD
	BANNER_TIME = 2,
	BANNER_LONG_TIME = 4, -- messages à lire : pelle requise, coffre plein
	BANNER_FADE_TIME = 0.3,

	-- Retour local du coup de pelle
	CELL_SHAKE_DEPTH = 0.25, -- studs
	CELL_SHAKE_TIME = 0.08,
	DIRT_PARTICLES_PER_HIT = 6,
	DIRT_PARTICLES_ON_BREAK = 18,
	DIRT_COLOR = Color3.fromRGB(110, 75, 45),
	EFFECT_LIFETIME = 1.5, -- secondes avant de nettoyer les émetteurs

	-- Caméra tournée vers la parcelle à l'apparition
	CAMERA_DISTANCE = 14, -- studs derrière le personnage
	CAMERA_HEIGHT = 9, -- studs au-dessus du personnage
	CAMERA_ARRIVAL_RADIUS = 40, -- le personnage est considéré arrivé à cette distance de la parcelle
	CAMERA_WAIT_TIMEOUT = 3, -- secondes max à attendre la téléportation

	-- Coffre (grille de cartes)
	CHEST_PANEL_MAX_SIZE = Vector2.new(760, 560), -- pixels
	CHEST_CARD_SIZE = Vector2.new(150, 150), -- pixels, assez grand pour le toucher
	CHEST_CARD_SIZE_COMPACT = Vector2.new(135, 135), -- pixels, écrans bas (téléphone en paysage)
	CHEST_CARD_BUTTON_MIN_HEIGHT = 32, -- pixels, bouton "Vendre" d'une carte
	COMPACT_SCREEN_HEIGHT = 500, -- pixels : en dessous, interface compacte
	PANEL_SIZE_SCALE = Vector2.new(0.92, 0.88), -- fenêtres coffre et Forge, fraction de l'écran
	CHEST_CARD_PADDING = 8,
	CHEST_BUTTON_MIN_HEIGHT = 40, -- pixels, cible tactile
	CHEST_STAR_SIZE = 36, -- pixels, zone tactile de l'étoile de favori
	HUD_CHEST_BUTTON_SIZE = 64, -- pixels

	-- Forge
	FORGE_PANEL_MAX_SIZE = Vector2.new(760, 440), -- pixels
	FORGE_ROW_HEIGHT = 96, -- pixels
	FORGE_ROW_HEIGHT_COMPACT = 72, -- pixels, écrans bas : les 3 pelles tiennent sans défiler

	-- Vente au Marchand
	MERCHANT_CLOSE_CHECK_INTERVAL = 0.5, -- secondes entre deux vérifications de distance
	SELL_COIN_COUNT = 8, -- pièces animées après une vente
	SELL_COIN_FLIGHT_TIME = 0.6,
	SELL_COIN_STAGGER = 0.05, -- décalage entre deux pièces
	SELL_COIN_SIZE = 36, -- pixels
	SELL_COIN_SPREAD = Vector2.new(80, 40), -- dispersion au départ, pixels
	SELL_COIN_TARGET = UDim2.new(1, -80, 0, 26), -- centre du compteur de Pièces du HUD

	-- HUD
	HUD_COINS_SIZE = Vector2.new(150, 40), -- pixels, compteur de Pièces en haut à droite
	HUD_MARGIN = 12, -- pixels depuis le bord de l'écran
	MERCHANT_ARROW_SIZE = 72, -- pixels
	MERCHANT_ARROW_OFFSET = 0.2, -- position verticale de la flèche (fraction de l'écran)

	-- Sons
	SOUND_SELL = "rbxasset://sounds/electronicpingshort.wav", -- son de caisse temporaire
	PITCH_SELL = 1.6,
	VOLUME_SELL = 0.7,
	SOUND_DIG_HIT = "rbxasset://sounds/snap.wav",
	SOUND_REVEAL = "rbxasset://sounds/electronicpingshort.wav",
	SOUND_REVEAL_SPECTACULAR = "rbxasset://sounds/victory.wav",
	SOUND_INVENTORY_FULL = "rbxasset://sounds/button.wav",
	VOLUME_DIG_HIT = 0.4,
	VOLUME_REVEAL = 0.6,
	VOLUME_REVEAL_SPECTACULAR = 1,
	VOLUME_INVENTORY_FULL = 0.6,
}

return table.freeze(UiConfig)
