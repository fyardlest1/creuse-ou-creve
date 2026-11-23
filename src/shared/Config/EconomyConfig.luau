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

	-- Validation des requêtes de vente
	UID_MAX_LENGTH = 64, -- les uids sont des GUID de 36 caractères

	-- Raretés mises en favori automatiquement à la découverte
	AUTO_FAVORITE_RARITIES = table.freeze({ Legendary = true, Secret = true }),
	-- Mutations qui empêchent le favori automatique (Maudit : vendre vite ou défendre, au joueur de choisir)
	NO_AUTO_FAVORITE_MUTATIONS = table.freeze({ Cursed = true }),

	-- Monnaie
	STARTING_COINS = 0,

	-- Analytique (AnalyticsService:LogEconomyEvent)
	ANALYTICS_CURRENCY = "Coins",
	-- Raison d'un gain ou d'une dépense -> type de transaction Roblox (Enum.AnalyticsEconomyTransactionType)
	ANALYTICS_TRANSACTION_TYPES = table.freeze({
		Sell = "Gameplay",
		ShovelPurchase = "Shop",
		Purchase = "IAP", -- packs de Pièces achetés en Robux
		DailyReward = "TimedReward", -- calendrier quotidien
		Reward = "Gameplay", -- quêtes et paliers de l'Index
	}),

	-- Simulation d'équilibrage (EconomySimulation)
	SIM_SECONDS_PER_ITEM = 2,
	SIM_SELL_TRIP_SECONDS = 20, -- aller-retour au Marchand quand le coffre est plein
	SIM_RUNS = 1000,
	SIM_MAX_SECONDS = 3600, -- arrêt d'une simulation si les objectifs ne sont pas atteints
	SIM_TARGET_IRON_SECONDS = 180,
	SIM_TARGET_STEEL_MIN_SECONDS = 480,
	SIM_TARGET_STEEL_MAX_SECONDS = 900,
	SIM_TARGET_ROCK_SECONDS = 1800,
	SIM_TARGET_STEEL_B_MIN_SECONDS = 300, -- variante B : acier pas avant 5 min en moyenne
}

return table.freeze(EconomyConfig)
