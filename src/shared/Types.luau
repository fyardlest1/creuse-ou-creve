--!strict
-- Types partagés entre serveur et client.

export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Secret"
export type MutationId = "Golden" | "Diamond" | "Rainbow"

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
}

export type ItemDef = {
	id: string,
	name: string,
	rarity: RarityId,
	layer: number,
}

export type ShovelId = "Wood" | "Iron" | "Steel"
export type StratumId = "Dirt" | "Clay" | "Rock"

-- Raison d'un gain ou d'une dépense de Pièces (analytique).
export type EconomyReason = "Sell" | "ShovelPurchase"

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
	favorite: boolean, -- protégé de la vente
}

export type PlayerStats = {
	totalDigs: number,
	foundByRarity: { [string]: number },
	totalCoinsEarned: number,
	itemsSold: number,
}

-- Version 2. La couche n'est pas stockée : elle se déduit toujours de `depth` (Strata.fromDepth).
export type PlayerData = {
	version: number,
	coins: number,
	inventory: { ItemInstance }, -- le coffre
	depth: number,
	ownedShovels: { ShovelId },
	equippedShovel: ShovelId,
	stats: PlayerStats,
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
	itemId: string,
	name: string,
	rarity: RarityId,
	mutation: MutationId?,
	value: number,
	inventoryCount: number,
}

return nil
