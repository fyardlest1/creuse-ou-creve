--!strict
-- Mini-jeu de crochetage (plan semaine 5, section 6) : règles pures, partagées par l'interface du client
-- et par la simulation des tests. Une barre, une zone verte, un curseur qui va et vient : il faut
-- toucher l'écran quand le curseur est dans la zone, PICK_HITS_REQUIRED fois de suite. Un échec fait
-- recommencer la série. Après chaque réussite, la zone change de place.
--
-- Le serveur n'utilise pas ces règles pour décider : il vérifie seulement la durée minimale réelle,
-- la distance et les règles du vol (StealService). Un client modifié ne gagne donc rien à tricher ici.

local StealConfig = require(script.Parent.Config.StealConfig)
local MonetizationConfig = require(script.Parent.Config.MonetizationConfig)

export type Settings = {
	zoneWidth: number, -- largeur de la zone verte, en fraction de la barre
	travelTime: number, -- secondes pour que le curseur traverse la barre (un aller)
	hitsRequired: number, -- réussites de suite
	minSeconds: number, -- durée minimale réelle, vérifiée par le serveur
}

local Lockpick = {}

-- Réglages du coffre visé : zone plus petite et durée minimale plus longue avec le Garde du corps.
function Lockpick.settings(hasBodyguard: boolean): Settings
	return {
		zoneWidth = if hasBodyguard then MonetizationConfig.BODYGUARD_PICK_ZONE_WIDTH else StealConfig.PICK_ZONE_WIDTH,
		travelTime = StealConfig.PICK_CURSOR_TRAVEL_TIME,
		hitsRequired = StealConfig.PICK_HITS_REQUIRED,
		minSeconds = if hasBodyguard
			then MonetizationConfig.BODYGUARD_PICK_MIN_SECONDS
			else StealConfig.PICK_MIN_SECONDS,
	}
end

-- Position du curseur (0 = gauche, 1 = droite) après elapsed secondes : aller-retour régulier.
function Lockpick.cursorAt(elapsed: number, travelTime: number): number
	local phase = (elapsed / travelTime) % 2
	return if phase <= 1 then phase else 2 - phase
end

-- Nouveau centre de zone, tiré au hasard sans toucher les bords de la barre.
function Lockpick.newZoneCenter(rng: Random, zoneWidth: number): number
	local half = zoneWidth / 2 + StealConfig.PICK_ZONE_EDGE_MARGIN
	return rng:NextNumber(half, 1 - half)
end

-- Le curseur est-il dans la zone verte ?
function Lockpick.isInZone(cursor: number, zoneCenter: number, zoneWidth: number): boolean
	return math.abs(cursor - zoneCenter) <= zoneWidth / 2
end

-- Le client attend cette durée (depuis le début du mini-jeu) avant d'envoyer « réussi » : avec la
-- latence, le serveur mesure toujours au moins autant, donc un joueur rapide n'est jamais refusé.
function Lockpick.sendDelay(settings: Settings): number
	return settings.minSeconds + StealConfig.PICK_CLIENT_MARGIN
end

return table.freeze(Lockpick)
