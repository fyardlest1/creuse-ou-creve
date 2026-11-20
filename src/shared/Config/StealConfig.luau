--!strict
-- Règles du vol (la nuit) : crochetage, garde-fous anti-frustration, éjection, protection débutant.

local StudioTestMode = require(script.Parent.StudioTestMode)

local StealConfig = {
	-- Crochetage
	PICK_DURATION = 5, -- secondes de maintien du prompt "Crocheter"
	PICK_TIME_TOLERANCE = 0.25, -- secondes : marge de décalage réseau entre début et fin du maintien
	PICK_MAX_DISTANCE = 10, -- studs entre le voleur et le coffre
	PICK_DISTANCE_CHECK_INTERVAL = 0.25, -- secondes entre deux vérifications de distance pendant le maintien
	RELEASE_GRACE = 0.25, -- secondes laissées à Triggered après un relâchement, avant d'annuler

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
	TEXT_REVENGE_DAY = "Disponible la nuit",
	TEXT_REVENGE_NO_THIEF = "Personne ne t'a volé",
	TEXT_REVENGE_BLOCKED = "Ton voleur ne peut pas être visé",

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
