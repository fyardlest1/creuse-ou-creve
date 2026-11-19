--!strict
-- Règles de l'économie : distances, cadences, favoris automatiques et paramètres de simulation.
-- Les multiplicateurs de valeur par couche sont dans Strata.luau, les prix dans Shovels.luau.

local EconomyConfig = {
	-- Distances (studs) entre le joueur et le stand
	MERCHANT_MAX_DISTANCE = 15,
	FORGE_MAX_DISTANCE = 15,

	-- Cadences minimum entre deux requêtes (secondes)
	SELL_COOLDOWN = 0.5,
	FAVORITE_COOLDOWN = 0.1,
	BUY_COOLDOWN = 0.5,

	-- Raretés mises en favori automatiquement à la découverte
	AUTO_FAVORITE_RARITIES = table.freeze({ Legendary = true, Secret = true }),

	-- Monnaie
	CURRENCY_NAME = "Pièces",
	STARTING_COINS = 0,

	-- Simulation d'équilibrage (EconomySimulation)
	SIM_SECONDS_PER_ITEM = 2,
	SIM_SELL_TRIP_SECONDS = 20, -- aller-retour au Marchand quand le coffre est plein
	SIM_RUNS = 1000,
	SIM_MAX_SECONDS = 3600, -- arrêt d'une simulation si les objectifs ne sont pas atteints
	SIM_TARGET_IRON_SECONDS = 180,
	SIM_TARGET_STEEL_MIN_SECONDS = 480,
	SIM_TARGET_STEEL_MAX_SECONDS = 900,
	SIM_TARGET_ROCK_SECONDS = 1800,
}

return table.freeze(EconomyConfig)
