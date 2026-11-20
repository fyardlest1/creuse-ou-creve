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

	-- Geste de creusage (épaule droite). Durée totale = DIG_COOLDOWN, pour enchaîner les coups.
	SWING_AXIS = Vector3.new(1, 0, 0), -- axe de rotation de l'épaule
	SWING_RAISE_ANGLE = 70, -- degrés : la pelle se lève vers l'avant
	SWING_STRIKE_ANGLE = 5, -- degrés : la lame frappe le sol devant le personnage
	SWING_RAISE_TIME = 0.06,
	SWING_STRIKE_TIME = 0.06, -- l'impact (particules, son) arrive à la fin de la frappe
	SWING_RECOVER_TIME = 0.1,

	-- Prise en main du creusage
	DIG_HOLD_MARGIN = 0.03, -- secondes ajoutées à DIG_COOLDOWN entre deux coups enchaînés (appui maintenu)
	DIG_HIGHLIGHT_COLOR = Color3.fromRGB(255, 230, 120), -- surbrillance de la case visée
	DIG_HIGHLIGHT_THICKNESS = 0.08, -- studs
	DIG_HIGHLIGHT_SURFACE_TRANSPARENCY = 0.75,

	-- Indice de premier lancement
	DIG_HINT_LABEL_Y = 0.8, -- bas du texte, fraction de l'écran (au-dessus des commandes mobiles)
	DIG_HINT_HAND_SIZE = 64, -- pixels
	DIG_HINT_BOB_TIME = 0.5, -- secondes pour une descente de la main
	DIG_HINT_BOB_DISTANCE = 0.3, -- fraction de la taille de la main
	DIG_HINT_RETARGET_INTERVAL = 0.5, -- secondes entre deux choix de case

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
	TOUCH_TARGET_MIN = 44, -- pixels : taille minimale d'une zone tactile (recommandation mobile)
	CHEST_CARD_SIZE = Vector2.new(150, 175), -- pixels
	CHEST_CARD_SIZE_COMPACT = Vector2.new(140, 165), -- pixels, écrans bas (téléphone en paysage)
	CHEST_CARD_LINE_HEIGHT = 20, -- pixels : rareté, valeur
	CHEST_CARD_NAME_MAX_TEXT = 20, -- taille de texte maximale du nom, pour des cartes homogènes
	CHEST_CARD_BADGE_HEIGHT = 16, -- pixels : badge de mutation
	CHEST_CARD_GAP = 4, -- pixels entre la valeur et le bouton "Vendre"
	CHEST_CARD_STAR_INSET = 6, -- pixels : l'étoile déborde un peu dans le coin de la carte
	CHEST_CARD_STAR_PADDING = 7, -- pixels : marge du symbole dans sa zone tactile
	COMPACT_SCREEN_HEIGHT = 500, -- pixels : en dessous, interface compacte
	PANEL_SIZE_SCALE = Vector2.new(0.92, 0.94), -- fenêtres coffre et Forge, fraction de l'écran
	CHEST_CARD_PADDING = 8,
	CHEST_BUTTON_MIN_HEIGHT = 44, -- pixels, cible tactile (fermer, en-têtes, boutons de la Forge)
	HUD_CHEST_BUTTON_SIZE = 64, -- pixels

	-- Forge
	FORGE_PANEL_MAX_SIZE = Vector2.new(760, 440), -- pixels
	FORGE_ROW_HEIGHT = 96, -- pixels
	FORGE_ROW_MIN_HEIGHT = 56, -- pixels : bouton de 44 + marges ; les lignes rétrécissent jusque-là
	FORGE_ROW_PADDING = 6, -- pixels, marge verticale dans une ligne
	FORGE_LIST_SPACING = 8, -- pixels entre deux lignes

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
	HUD_TOP_MARGIN = 6, -- pixels depuis le haut de la zone d'interface
	HUD_SPACING = 8, -- pixels entre deux éléments empilés du HUD
	MERCHANT_ARROW_SIZE = 60, -- pixels, sous le compteur de Pièces
	DAY_NIGHT_TIMER_SIZE = Vector2.new(130, 30), -- pixels, minuteur en haut à gauche

	-- Vol (la nuit)
	STEAL_REFRESH_INTERVAL = 0.25, -- secondes entre deux mises à jour des prompts de coffre
	STEAL_LABEL_HEIGHT = 4.5, -- studs au-dessus du coffre
	STEAL_LABEL_SIZE = Vector2.new(220, 34), -- pixels
	STEAL_LABEL_MAX_DISTANCE = 30, -- studs
	STEAL_BLINK_FREQUENCY = 2, -- clignotements par seconde du coffre crocheté
	STEAL_ARROW_REACH = 8, -- studs : la flèche vers son coffre disparaît une fois arrivé
	STEAL_CARD_TIME = 3, -- secondes d'affichage de la carte "Tu as volé" / "On t'a volé"
	STUN_VEIL_COLOR = Color3.fromRGB(120, 120, 255), -- voile pendant l'étourdissement
	STUN_VEIL_TRANSPARENCY = 0.75,

	-- Sons
	SOUND_STEAL_ALARM = "rbxasset://sounds/electronicpingshort.wav", -- alarme temporaire
	VOLUME_STEAL_ALARM = 0.6,
	PITCH_STEAL_ALARM = 2,
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
