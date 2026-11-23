--!strict
-- Types partagés entre serveur et client.

export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Secret"
export type MutationId = "Golden" | "Diamond" | "Rainbow" | "Cursed"

export type RarityDef = {
	id: RarityId,
	displayName: string,
	chance: number, -- en pourcentage (somme = 100)
	color: Color3,
	value: number, -- valeur de vente de base
	isLuckBoosted: boolean, -- le bonus de chance multiplie son poids
	isSpectacular: boolean, -- révélation renforcée (Légendaire, Secret)
}

export type MutationDef = {
	id: MutationId,
	displayName: string,
	chance: number, -- en pourcentage
	multiplier: number,
	color: Color3,
	nightOnly: boolean, -- ne peut être tirée que la nuit (Maudit)
}

export type ItemDef = {
	id: string,
	name: string,
	rarity: RarityId,
	layer: number,
	icon: string?, -- image de l'objet, "rbxassetid://<nombre>" ; absente : repli (initiale sur la couleur de rareté)
}

export type ShovelId = "Wood" | "Iron" | "Steel"
export type StratumId = "Dirt" | "Clay" | "Rock"

-- Raison d'un gain ou d'une dépense de Pièces (analytique).
export type EconomyReason = "Sell" | "ShovelPurchase" | "Purchase" | "DailyReward" | "Reward"

-- Apparence de la pelle tenue en main (version simple en Parts, remplacée en semaine 5).
export type ShovelAppearance = {
	handleColor: Color3,
	handleMaterial: Enum.Material,
	bladeColor: Color3,
	bladeMaterial: Enum.Material,
	bladeReflectance: number, -- 0 = mat, l'acier brille légèrement
}

export type ShovelDef = {
	id: ShovelId,
	name: string,
	price: number,
	hitsPerCell: number, -- coups nécessaires pour vider une case
	luckBonus: number, -- en pourcentage (30 = +30 %)
	maxStratum: StratumId, -- couche la plus profonde accessible
	appearance: ShovelAppearance,
}

export type StratumDef = {
	id: StratumId,
	layer: number, -- numéro de couche, utilisé par ItemDef.layer
	name: string,
	nameWithArticle: string, -- "l'Argile", pour les phrases affichées
	minDepth: number, -- mètres, inclus
	maxDepth: number, -- mètres, exclu
	requiredShovel: ShovelId,
	valueMultiplier: number,
	cellColor: Color3,
}

export type ItemInstance = {
	uid: string,
	itemId: string,
	rarity: RarityId,
	mutation: MutationId?,
	value: number,
	favorite: boolean, -- protégé de la vente (pas du vol)
	stolenFrom: string?, -- nom de la victime si l'objet a été volé : un trophée affiché sur la carte
}

export type PlayerStats = {
	totalDigs: number,
	foundByRarity: { [string]: number },
	totalCoinsEarned: number,
	itemsSold: number,
	stealsSucceeded: number,
	stealsAttempted: number,
	timesRobbed: number,
	ejections: number,
}

-- Réserve de bonus (gagnés en jouant, activés quand le joueur veut).
export type Boosts = { luckPotion: number, shield: number }
-- Réglages du joueur (menu Son), enregistrés avec ses données.
export type PlayerSettings = { musicMuted: boolean, effectsMuted: boolean }

-- Effets actifs : fin de la potion (os.time()), numéro de la nuit protégée par un Bouclier.
export type Effects = { luckUntil: number, shieldNightId: number }

export type RetentionStatePayload = {
	daily: { available: boolean, nextDay: number, lastDay: number },
	quests: { { kind: string, progress: number, target: number, reward: number, done: boolean } },
	questsBonusClaimed: boolean,
	index: { [string]: { [string]: boolean } },
	indexRewards: { [string]: boolean },
	title: string?, -- clé Locale du titre ("title.index.Clay")
}

export type DailyState = { lastClaimDay: number, calendarDay: number, firstSeenDay: number }

export type QuestState = { id: string, target: number, progress: number, claimed: boolean, reward: number }

-- Version 4. La couche n'est pas stockée : elle se déduit toujours de `depth` (Strata.fromDepth).
export type PlayerData = {
	version: number,
	coins: number,
	inventory: { ItemInstance }, -- le coffre
	depth: number,
	ownedShovels: { ShovelId },
	equippedShovel: ShovelId,
	stats: PlayerStats,
	digHintDone: boolean, -- l'indice "Clique sur une case pour creuser" ne s'affiche plus
	playTime: number, -- secondes de jeu cumulées, pour la protection débutant
	thiefPoints: number, -- Points de Voleur (comptés, pas encore dépensables)
	boosts: Boosts,
	effects: Effects,
	daily: DailyState,
	quests: { day: number, list: { QuestState }, bonusClaimed: boolean },
	index: { [string]: { [string]: boolean } }, -- [itemId] = { [mutationId ou "Normal"] = true }
	indexRewards: { [string]: boolean }, -- paliers réclamés, clé "couche:pourcentage"
	title: string?, -- clé Locale du titre affiché sous le nom ("title.index.Clay")
	funnelSteps: { [string]: boolean }, -- étapes de l'entonnoir déjà journalisées
	processedPurchases: { string }, -- 100 derniers PurchaseId traités (idempotence)
	settings: PlayerSettings,
}

-- Vente : soit une liste d'uids, soit tout le coffre (sauf favoris).
export type SellRequestPayload = {
	uids: { string }?,
	all: boolean?,
}

export type SellResultPayload = {
	count: number,
	coinsEarned: number,
	newBalance: number,
}

export type RevealPayload = {
	itemId: string, -- le client affiche le nom dans sa langue (Locale.item)
	rarity: RarityId,
	mutation: MutationId?,
	value: number,
	inventoryCount: number,
}

return nil
