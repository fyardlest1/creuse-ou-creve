--!strict
-- Règles du vol (la nuit) : crochetage, garde-fous anti-frustration, éjection, protection débutant.

local StudioTestMode = require(script.Parent.StudioTestMode)

local StealConfig = {
	-- Crochetage : mini-jeu (plan semaine 5, section 6). Le serveur vérifie la durée réelle, pas le jeu.
	PICK_MIN_SECONDS = 4, -- durée minimale réelle (horloge serveur) entre le début et « réussi »
	PICK_MAX_SECONDS = 45, -- au-delà, le crochetage est abandonné (le coffre ne reste pas « crocheté »)
	PICK_HITS_REQUIRED = 3, -- touches réussies de suite
	PICK_ZONE_WIDTH = 0.22, -- largeur de la zone verte, en fraction de la barre
	PICK_ZONE_EDGE_MARGIN = 0.05, -- la zone ne touche jamais les bords de la barre
	PICK_CURSOR_TRAVEL_TIME = 0.9, -- secondes pour que le curseur traverse la barre (un aller)
	PICK_CLIENT_MARGIN = 0.15, -- secondes que le client ajoute à la durée minimale avant d'envoyer « réussi »
	PICK_RESULT_COOLDOWN = 0.3, -- secondes minimum entre deux messages du mini-jeu (anti-spam)
	PICK_MAX_DISTANCE = 10, -- studs entre le voleur et le coffre
	PICK_DISTANCE_CHECK_INTERVAL = 0.25, -- secondes entre deux vérifications de distance pendant le crochetage

	-- Garde-fous (plan semaine 3, section 3)
	MAX_LOSSES_PER_NIGHT = 1, -- objets perdus au maximum par une victime, par nuit
	MAX_STEALS_PER_NIGHT = 2, -- vols réussis au maximum par un voleur, par nuit (victimes différentes)
	NON_STEALABLE_RARITIES = table.freeze({ Secret = true }),
	PROTECTION_SECONDS = if StudioTestMode.ACTIVE then StudioTestMode.PROTECTION_SECONDS else 20 * 60,

	-- Éjection
	EJECT_MAX_DISTANCE = 12, -- studs entre le propriétaire et le voleur
	STUN_SECONDS = 3,
	EJECT_COOLDOWN = 0.5, -- secondes minimum entre deux demandes d'éjection
	EJECT_DESTINATION = Vector3.new(0, 4, 0), -- centre de la carte (place centrale)

	-- Revanche (developer product)
	REVENGE_TELEPORT_DISTANCE = 6, -- studs devant le coffre du voleur
	REVENGE_TELEPORT_HEIGHT = 3,

	-- Récompense
	THIEF_POINTS_PER_STEAL = 1,

	-- Analytique (AnalyticsService:LogCustomEvent)
	ANALYTICS_EVENTS = table.freeze({
		Attempt = "StealAttempt", -- le voleur commence à crocheter
		Success = "StealSuccess", -- valeur : valeur de l'objet volé
		Cancel = "StealCancel", -- champ : raison
		Ejection = "StealEjection", -- journalisé pour le propriétaire qui éjecte
	}),

	-- Temps de jeu compté pour la protection
	PLAYTIME_TICK = 1, -- secondes entre deux incréments de playTime
}

return table.freeze(StealConfig)
