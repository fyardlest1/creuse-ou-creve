--!strict
-- Événements de serveur (plan semaine 5, section 7) : pluie de météorites et Nuit de sang.
-- Les deux sont annoncés à tout le serveur WARNING_SECONDS avant leur début, avec un compte à rebours.

local EventConfig = {
	WARNING_SECONDS = 10, -- annonce et compte à rebours avant le début d'un événement

	-- Pluie de météorites : chances de Rare et mieux x2 pour tous, dans la formule unique (plafond x10)
	METEOR_INTERVAL = 30 * 60, -- secondes entre deux débuts (la première 30 min après l'ouverture du serveur)
	METEOR_DURATION = 3 * 60, -- secondes
	METEOR_LUCK_MULTIPLIER = 2,

	-- Nuit de sang : tirée WARNING_SECONDS avant chaque nuit
	BLOOD_NIGHT_CHANCE = 0.15,
	BLOOD_NIGHT_DURATION = 4 * 60, -- secondes, au lieu de DayNightConfig.NIGHT_DURATION
	BLOOD_NIGHT_CURSED_MULTIPLIER = 3, -- les mutations Maudites tombent 3 fois plus souvent

	-- Attributs publiés sur ReplicatedStorage pour les clients (horodatages GetServerTimeNow)
	ATTRIBUTE_METEOR_STARTS_AT = "MeteorStartsAt", -- début annoncé (0 si aucun)
	ATTRIBUTE_METEOR_ENDS_AT = "MeteorEndsAt", -- fin de la pluie annoncée ou en cours (0 si aucune)
	ATTRIBUTE_BLOOD_NIGHT = "BloodNight", -- vrai pendant une Nuit de sang
	ATTRIBUTE_BLOOD_NIGHT_STARTS_AT = "BloodNightStartsAt", -- début annoncé de la prochaine (0 si aucune)

	-- Nuit de sang : ciel rouge sombre, toujours lisible sur un téléphone
	BLOOD_NIGHT_LIGHTING = table.freeze({
		ClockTime = 19.6,
		Brightness = 1.6,
		Ambient = Color3.fromRGB(165, 95, 95),
		OutdoorAmbient = Color3.fromRGB(160, 90, 90),
	}),
	BLOOD_NIGHT_TINT = Color3.fromRGB(255, 200, 200), -- ColorCorrection pendant la Nuit de sang

	-- Météorites (visuel seulement, calculé par chaque client : rien ne tombe vraiment sur les cases)
	METEOR_SPAWN_INTERVAL = 0.45, -- secondes entre deux météorites
	METEOR_HEIGHT = 140, -- studs au-dessus du sol au départ
	METEOR_SIDE_OFFSET = 60, -- studs : la météorite arrive en biais
	METEOR_FALL_TIME = 1.4, -- secondes
	METEOR_SIZE = 3, -- studs
	METEOR_COLOR = Color3.fromRGB(255, 140, 40),
	METEOR_IMPACT_SIZE = 10, -- studs : flash d'impact au sol
	METEOR_IMPACT_TIME = 0.5, -- secondes
	METEOR_LIGHT_RANGE = 14,
	METEOR_MAX_ACTIVE = 8, -- plafond de météorites à l'écran (téléphones d'entrée de gamme)
}

return table.freeze(EventConfig)
