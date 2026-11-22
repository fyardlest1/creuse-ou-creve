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

	-- Moments forts (plan semaine 5, section 3) : révélation par rareté, lisible en 1 seconde sur téléphone.
	REVEAL_EPIC_SCALE = 1.15, -- carte Épique plus grande
	REVEAL_HALO_SCALE = 1.18, -- halo derrière la carte, par rapport à la carte (Épique et mieux)
	REVEAL_HALO_TRANSPARENCY = 0.45,
	REVEAL_HALO_PULSE_SPEED = 4, -- radians par seconde (pulsation du halo)
	REVEAL_FREEZE_TIME = 0.3, -- Légendaire et Secret : l'écran se fige avant l'impact
	REVEAL_FREEZE_DARKNESS = 0.45, -- transparence du voile sombre pendant l'arrêt sur image
	SPEED_LINE_COUNT = 18, -- chaque ligne traverse l'écran : 36 traits visibles
	SPEED_LINE_THICKNESS = 5, -- pixels
	SPEED_LINE_LENGTH = 2.6, -- en hauteurs d'écran (couvre la diagonale d'un téléphone en paysage)
	SPEED_LINE_GAP = 0.36, -- part centrale de chaque ligne laissée vide (autour de la carte)
	SPEED_LINES_TIME = 1.1, -- secondes après l'impact
	SPEED_LINE_JITTER = 0.6, -- variation aléatoire de l'épaisseur (scintillement façon anime)
	CAMERA_SHAKE_TIME = 0.35,
	CAMERA_SHAKE_STRENGTH = 0.35, -- studs
	LEGENDARY_FLASH_COLOR = Color3.fromRGB(255, 200, 60), -- flash doré

	-- Aura du Secret (3 s, visible par les joueurs proches) et aura de collectionneur (Secret dans le coffre)
	SECRET_AURA_TIME = 3,
	SECRET_AURA_MAX_DISTANCE = 90, -- studs entre la caméra et le joueur qui a trouvé le Secret
	SECRET_AURA_RATE = 45, -- particules par seconde
	SECRET_AURA_LIFETIME = 1.2,
	SECRET_AURA_SPEED = 7, -- studs par seconde, vers le haut
	SECRET_AURA_SIZE = 1.4,
	COLLECTOR_AURA_RATE = 5, -- discrète
	COLLECTOR_AURA_LIFETIME = 1.6,
	COLLECTOR_AURA_SPEED = 1.5,
	COLLECTOR_AURA_SIZE = 0.6,
	COLLECTOR_AURA_MAX_COUNT = 8, -- auras affichées au plus (les plus proches)
	COLLECTOR_AURA_MAX_DISTANCE = 160, -- studs : visible de loin
	COLLECTOR_AURA_REFRESH = 1, -- secondes entre deux mises à jour (pas de boucle à chaque image)
	AURA_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds",

	-- Annonces à tout le serveur (Légendaire, Secret, Événement chance)
	ANNOUNCE_TIME = 4,
	ANNOUNCE_FADE_TIME = 0.4,
	ANNOUNCE_SIZE = Vector2.new(640, 50), -- pixels (taille maximale), placée par HudLayout sous les bandeaux
	ANNOUNCE_HEIGHT_COMPACT = 34, -- pixels, téléphone
	ANNOUNCE_LEGENDARY_COLOR = Color3.fromRGB(200, 140, 20),
	ANNOUNCE_SECRET_COLOR = Color3.fromRGB(150, 60, 200), -- recouvert d'un dégradé arc-en-ciel
	ANNOUNCE_EVENT_COLOR = Color3.fromRGB(220, 140, 30),

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

	-- Boutique
	SHOP_PANEL_MAX_SIZE = Vector2.new(760, 560), -- pixels
	SHOP_CARD_HEIGHT = 96, -- pixels
	SHOP_TITLE_HEIGHT = 26, -- pixels
	SHOP_DESCRIPTION_MAX_TEXT = 18,
	SHOP_ODDS_HEIGHT = 190, -- pixels
	SHOP_ODDS_LINE_HEIGHT = 21, -- pixels
	SHOP_REFRESH_INTERVAL = 2, -- secondes entre deux mises à jour de l'état pendant que la boutique est ouverte
	HUD_SHOP_BUTTON_SIZE = 64, -- pixels

	-- Rétention : fenêtres Aujourd'hui (calendrier, quêtes), Index et Réserve
	RETENTION_PANEL_MAX_SIZE = Vector2.new(760, 560), -- pixels
	RETENTION_SECTION_HEIGHT = 26, -- pixels : titres de section, ligne de progression
	RETENTION_SMALL_TEXT = 16, -- taille de texte maximale des cases (calendrier, paliers, Index)
	DAILY_CELL_HEIGHT = 74, -- pixels : cases du calendrier de 7 jours
	QUEST_ROW_HEIGHT = 62, -- pixels
	INDEX_TIERS_HEIGHT = 48, -- pixels : ligne des paliers 25/50/75/100 %
	INDEX_CELL_SIZE = Vector2.new(112, 72), -- pixels : case d'un objet de l'Index
	INDEX_MUTATION_DOT = 10, -- pixels : pastille d'une mutation trouvée
	RESERVE_PANEL_MAX_SIZE = Vector2.new(520, 300), -- pixels
	RESERVE_PANEL_SCALE = Vector2.new(0.8, 0.9), -- fraction de l'écran
	RESERVE_ROW_HEIGHT = 76, -- pixels
	HUD_NOTIFY_DOT_SIZE = 16, -- pixels : pastille rouge sur le bouton Quêtes
	HUD_COUNT_BADGE_SIZE = 22, -- pixels : nombre de bonus sur le bouton Réserve
	BOOST_CHIP_WIDTH = 86, -- pixels : indicateur de bonus actif (hauteur : celle des pastilles du HUD)
	BOOST_CHIP_WIDTH_COMPACT = 78,
	BOOST_REFRESH_INTERVAL = 0.25, -- secondes entre deux mises à jour des minuteurs de bonus

	-- Vente au Marchand
	MERCHANT_CLOSE_CHECK_INTERVAL = 0.5, -- secondes entre deux vérifications de distance
	SELL_COIN_COUNT = 8, -- pièces animées après une vente
	SELL_COIN_FLIGHT_TIME = 0.6,
	SELL_COIN_STAGGER = 0.05, -- décalage entre deux pièces
	SELL_COIN_SIZE = 36, -- pixels
	SELL_COIN_SPREAD = Vector2.new(80, 40), -- dispersion au départ, pixels

	-- HUD
	HUD_MARGIN = 12, -- pixels depuis le bord de l'écran
	HUD_TOP_MARGIN = 6, -- pixels depuis le haut de la zone d'interface
	HUD_SPACING = 8, -- pixels entre deux éléments empilés du HUD
	HUD_SIDE_BUTTONS_Y = 0.45, -- hauteur des boutons latéraux (Coffre, Boutique...), en fraction de l'écran
	-- Haut de l'écran (HudLayout) : minuteur, profondeur, couche, coffre et Pièces, rangés depuis la gauche,
	-- avec passage à la ligne avant la zone de la liste des joueurs de Roblox (en haut à droite).
	HUD_PILL_HEIGHT = 36, -- pixels
	HUD_PILL_HEIGHT_COMPACT = 28, -- pixels, téléphone
	HUD_SPACING_COMPACT = 6, -- pixels
	HUD_PILL_WIDTHS = table.freeze({ timer = 130, depth = 150, stratum = 100, chest = 130, coins = 150 }),
	HUD_PILL_WIDTHS_COMPACT = table.freeze({ timer = 104, depth = 96, stratum = 66, chest = 92, coins = 104 }),
	-- Largeur laissée libre en haut à droite pour la liste des joueurs : fixe sur grand écran, part de
	-- l'écran sur téléphone (la liste y prend plus de place en proportion).
	PLAYER_LIST_RESERVED_WIDTH = 300, -- pixels
	PLAYER_LIST_RESERVED_SCALE_COMPACT = 0.4, -- fraction de la largeur de l'écran
	PLAYER_LIST_RESERVED_MIN_COMPACT = 240, -- pixels
	BANNER_HEIGHT = 40, -- pixels, bandeaux d'information du HUD
	BANNER_HEIGHT_COMPACT = 28,
	BANNER_MAX_WIDTH = 620, -- pixels
	MERCHANT_ARROW_SIZE = 60, -- pixels, disque de la flèche
	MERCHANT_ARROW_SIZE_COMPACT = 46,
	MERCHANT_ARROW_WIDTH = 150, -- pixels, largeur du bloc flèche + légende
	MERCHANT_ARROW_WIDTH_COMPACT = 110,
	MERCHANT_ARROW_CAPTION_HEIGHT = 20, -- pixels
	-- Panneaux du monde (parcelles, stands) : jamais par-dessus le HUD, texte plafonné à l'écran.
	WORLD_SIGN_MAX_TEXT = 40, -- pixels
	WORLD_SIGN_MAX_TEXT_COMPACT = 22, -- pixels, téléphone
	WORLD_SIGN_HUD_GAP = 4, -- pixels entre le bas du HUD et le haut d'un panneau
	WORLD_SIGN_MAX_SHIFT = 3, -- au-delà de ce décalage (en hauteurs de texte), le panneau est masqué

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
	VOLUME_REVEAL_EPIC = 1, -- Épique : même son, plus fort et plus aigu
	PITCH_REVEAL_EPIC = 1.25,
	SOUND_REVEAL_IMPACT = "rbxasset://sounds/snap.wav", -- impact temporaire (Légendaire et Secret)
	VOLUME_REVEAL_IMPACT = 1,
	PITCH_REVEAL_IMPACT = 0.45,
	SOUND_ANNOUNCE = "rbxasset://sounds/electronicpingshort.wav", -- annonce temporaire, distincte du reste
	VOLUME_ANNOUNCE = 0.7,
	PITCH_ANNOUNCE = 0.75,
}

return table.freeze(UiConfig)
