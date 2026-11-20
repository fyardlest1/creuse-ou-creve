--!strict
-- Règles du vol (la nuit) : crochetage, garde-fous anti-frustration, éjection, protection débutant.

local StudioTestMode = require(script.Parent.StudioTestMode)

local StealConfig = {
	-- Crochetage
	PICK_DURATION = 5, -- secondes de maintien du prompt "Crocheter"
	PICK_TIME_TOLERANCE = 0.25, -- secondes : marge de décalage réseau entre début et fin du maintien
	PICK_MAX_DISTANCE = 10, -- studs entre le voleur et le coffre

	-- Garde-fous (plan semaine 3, section 3)
	MAX_LOSSES_PER_NIGHT = 1, -- objets perdus au maximum par une victime, par nuit
	MAX_STEALS_PER_NIGHT = 2, -- vols réussis au maximum par un voleur, par nuit (victimes différentes)
	NON_STEALABLE_RARITIES = table.freeze({ Secret = true }),
	PROTECTION_SECONDS = if StudioTestMode.ACTIVE then StudioTestMode.PROTECTION_SECONDS else 20 * 60,

	-- Éjection
	EJECT_MAX_DISTANCE = 12, -- studs entre le propriétaire et le voleur
	STUN_SECONDS = 3,
	EJECT_DESTINATION = Vector3.new(0, 4, 0), -- centre de la carte (place centrale)

	-- Récompense
	THIEF_POINTS_PER_STEAL = 1,

	-- Temps de jeu compté pour la protection
	PLAYTIME_TICK = 1, -- secondes entre deux incréments de playTime
}

return table.freeze(StealConfig)
