--!strict
-- Rétention (plan semaine 4, sections 6 et 7) : calendrier quotidien, quêtes, paliers de l'Index,
-- badges Roblox et étapes de l'entonnoir d'accueil. Identifiants de badges à 0 tant qu'ils ne sont
-- pas créés sur le Creator Hub (un badge à 0 n'est simplement pas décerné).

export type Reward = { coins: number?, luckPotion: number?, shield: number? }

export type QuestKind = "FindRare" | "DigCells" | "SellCoins" | "Steal" | "Eject" | "FindMutation" | "NewDepth"

export type QuestTemplate = {
	kind: QuestKind,
	text: string, -- %s reçoit l'objectif mis en forme
	targetByLayer: { number }, -- objectif selon la couche actuelle (Terre, Argile, Roche)
	rewardFactor: number, -- multiplie la récompense de base de la couche
	stealRelated: boolean, -- jamais tirée pour un joueur encore protégé
}

export type BadgeKey =
	"FirstDig"
	| "FirstSecret"
	| "FirstSteal"
	| "FirstEjection"
	| "EnterClay"
	| "EnterRock"
	| "DirtIndex"

local RetentionConfig = {
	-- Récompenses quotidiennes : un calendrier de 7 jours qui avance d'une case par jour de connexion
	-- (jour UTC). Manquer un jour ne remet pas à zéro ; après le jour 7, on recommence au jour 1.
	DAILY_REWARDS = table.freeze({
		table.freeze({ coins = 300 }),
		table.freeze({ coins = 600 }),
		table.freeze({ luckPotion = 1 }),
		table.freeze({ coins = 1500 }),
		table.freeze({ coins = 3000 }),
		table.freeze({ shield = 1 }),
		table.freeze({ luckPotion = 1, coins = 7500 }),
	}) :: { Reward },

	-- Quêtes : 3 par jour UTC, objectifs et récompenses adaptés à la couche du joueur.
	QUESTS_PER_DAY = 3,
	QUEST_BASE_COINS_BY_LAYER = table.freeze({ 400, 1200, 3000 }),
	QUEST_ALL_DONE_REWARD = table.freeze({ luckPotion = 1 }) :: Reward,
	QUEST_TEMPLATES = table.freeze({
		table.freeze({
			kind = "FindRare",
			text = "Trouve %s objets Rares ou mieux",
			targetByLayer = { 3, 4, 5 },
			rewardFactor = 1.5,
			stealRelated = false,
		}),
		table.freeze({
			kind = "DigCells",
			text = "Creuse %s cases",
			targetByLayer = { 40, 60, 80 },
			rewardFactor = 1,
			stealRelated = false,
		}),
		table.freeze({
			kind = "SellCoins",
			text = "Vends pour %s Pièces",
			targetByLayer = { 1500, 5000, 15000 },
			rewardFactor = 1,
			stealRelated = false,
		}),
		table.freeze({
			kind = "Steal",
			text = "Réussis %s vol",
			targetByLayer = { 1, 1, 1 },
			rewardFactor = 2,
			stealRelated = true,
		}),
		table.freeze({
			kind = "Eject",
			text = "Éjecte %s voleur",
			targetByLayer = { 1, 1, 1 },
			rewardFactor = 2,
			stealRelated = true,
		}),
		table.freeze({
			kind = "FindMutation",
			text = "Trouve %s objet muté",
			targetByLayer = { 1, 1, 1 },
			rewardFactor = 2,
			stealRelated = false,
		}),
		table.freeze({
			kind = "NewDepth",
			text = "Descends %s fois de 10 m",
			targetByLayer = { 1, 1, 1 },
			rewardFactor = 1.5,
			stealRelated = false,
		}),
	}) :: { QuestTemplate },

	-- Index de collection : paliers par couche (en % des objets de la couche trouvés).
	INDEX_TIERS = table.freeze({
		table.freeze({ percent = 25, reward = table.freeze({ coins = 1000 }) :: Reward }),
		table.freeze({ percent = 50, reward = table.freeze({ luckPotion = 1 }) :: Reward }),
		table.freeze({ percent = 75, reward = table.freeze({ shield = 1 }) :: Reward }),
		table.freeze({ percent = 100, title = true }),
	}),
	-- Titre affiché sous le nom à 100 % d'une couche ; %s = nom de la couche avec article ("l'Argile").
	INDEX_TITLE = "Archéologue de %s",
	INDEX_COIN_REWARD_MULTIPLIER_BY_LAYER = table.freeze({ 1, 3, 8 }), -- palier de 25 % selon la couche

	-- Badges Roblox
	BADGES = table.freeze({
		FirstDig = 0, -- Premier coup de pelle
		FirstSecret = 0, -- Premier Secret
		FirstSteal = 0, -- Voleur de l'ombre
		FirstEjection = 0, -- Gardien du coffre
		EnterClay = 0, -- Explorateur de l'Argile
		EnterRock = 0, -- Explorateur de la Roche
		DirtIndex = 0, -- Archéologue de la Terre
	}) :: { [BadgeKey]: number },

	-- Entonnoir d'accueil (AnalyticsService:LogOnboardingFunnelStepEvent), une seule fois par joueur.
	FUNNEL_STEPS = table.freeze({
		"Arrivee",
		"PremierCoupDePelle",
		"PremierObjet",
		"PremiereVente",
		"PelleEnFer",
		"PremiereNuit",
		"EntreeArgile",
		"RetourAutreJour",
	}),

	SECONDS_PER_DAY = 86400, -- jour UTC : floor(os.time() / SECONDS_PER_DAY)
}

return table.freeze(RetentionConfig)
