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

export type ShovelDef = {
	id: string,
	name: string,
	power: number, -- coups retirés à une case par frappe
	luckBonus: number, -- en pourcentage (30 = +30 %)
	price: number,
}

export type ItemInstance = {
	uid: string,
	itemId: string,
	rarity: RarityId,
	mutation: MutationId?,
	value: number,
}

export type PlayerStats = {
	totalDigs: number,
	foundByRarity: { [string]: number },
}

export type PlayerData = {
	version: number,
	inventory: { ItemInstance },
	layer: number,
	depth: number,
	stats: PlayerStats,
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
