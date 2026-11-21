--!strict
-- Tirage de rareté, de mutation et d'objet. Tout se décide ici, côté serveur.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Items = require(Shared.Config.Items)
local Strata = require(Shared.Config.Strata)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ShopService = require(script.Parent.ShopService)
local DayNightService = require(script.Parent.DayNightService)

local PERCENT = 100

local LootService = {}

local rng = Random.new()

export type LuckParts = {
	shovelBonus: number, -- bonus de la pelle en % (15 = +15 %)
	luckPass: boolean, -- game pass Chance x2
	potion: boolean, -- Potion de chance active
	serverEvent: boolean, -- Événement chance du serveur actif
	groupMember: boolean, -- membre du groupe Konbit Games (si le groupe est configuré)
}

-- LA formule de la chance (plan semaine 4, section 4). Seul endroit où elle existe.
--   (1 + bonus de la pelle) x (2 si Chance x2) x (3 si potion) x (2 si événement) x (1,05 si groupe)
-- plafonné à x10 pour protéger la valeur des Secrets.
function LootService.computeLuckMultiplier(parts: LuckParts): number
	local multiplier = 1 + math.max(parts.shovelBonus, 0) / PERCENT
	if parts.luckPass then
		multiplier *= MonetizationConfig.LUCK_PASS_MULTIPLIER
	end
	if parts.potion then
		multiplier *= MonetizationConfig.POTION_MULTIPLIER
	end
	if parts.serverEvent then
		multiplier *= MonetizationConfig.SERVER_EVENT_MULTIPLIER
	end
	if parts.groupMember and MonetizationConfig.GROUP_ID ~= 0 then
		multiplier *= MonetizationConfig.GROUP_MULTIPLIER
	end
	return math.min(multiplier, MonetizationConfig.LUCK_CAP)
end

-- Tire une rareté. Le multiplicateur de chance (déjà plafonné, au moins 1) multiplie le poids des raretés
-- boostées (Rare, Épique, Légendaire, Secret), puis on renormalise.
function LootService.rollRarity(luckMultiplier: number): Types.RarityId
	luckMultiplier = math.clamp(luckMultiplier, 1, MonetizationConfig.LUCK_CAP)
	local weights: { number } = {}
	local total = 0
	for index, rarity in Rarities.list do
		local weight = if rarity.isLuckBoosted then rarity.chance * luckMultiplier else rarity.chance
		weights[index] = weight
		total += weight
	end

	local roll = rng:NextNumber(0, total)
	for index, rarity in Rarities.list do
		roll -= weights[index]
		if roll < 0 then
			return rarity.id
		end
	end
	return Rarities.list[1].id
end

-- Tire au plus une mutation. Chaque mutation a sa propre chance en %, cumulées sur un seul tirage.
-- Les mutations de nuit (Maudit) ne sont possibles que si isNight est vrai.
function LootService.rollMutation(isNight: boolean?): Types.MutationId?
	local roll = rng:NextNumber(0, PERCENT)
	for _, mutation in Mutations.list do
		if not mutation.nightOnly or isNight == true then
			roll -= mutation.chance
			if roll < 0 then
				return mutation.id
			end
		end
	end
	return nil
end

-- Choisit un objet de la rareté donnée, parmi ceux de la couche (chaque couche a toutes les raretés).
function LootService.pickItem(layer: number, rarity: Types.RarityId): Types.ItemDef
	local candidates: { Types.ItemDef } = {}
	for _, item in Items.list do
		if item.rarity == rarity and item.layer == layer then
			table.insert(candidates, item)
		end
	end
	assert(#candidates > 0, "[LootService] Aucun objet " .. rarity .. " pour la couche " .. layer)
	return candidates[rng:NextInteger(1, #candidates)]
end

-- Valeur de vente : valeur de rareté x multiplicateur de mutation x multiplicateur de couche.
function LootService.computeValue(rarityId: Types.RarityId, mutationId: Types.MutationId?, layer: number): number
	local mutationMultiplier = if mutationId ~= nil then Mutations.byId[mutationId].multiplier else 1
	return Rarities.byId[rarityId].value * mutationMultiplier * Strata.byLayer[layer].valueMultiplier
end

-- Tirage complet, sans joueur : rareté, mutation, objet de la couche, valeur finale et uid.
-- Les Légendaires et Secrets sont mis en favori automatiquement, sauf s'ils sont Maudits :
-- le joueur doit choisir lui-même entre vendre vite un objet Maudit et le défendre.
function LootService.rollItem(layer: number, luckMultiplier: number, isNight: boolean?): Types.ItemInstance
	local rarityId = LootService.rollRarity(luckMultiplier)
	local mutationId = LootService.rollMutation(isNight)
	local item = LootService.pickItem(layer, rarityId)
	return LootService.makeItem(item, mutationId, layer)
end

-- Construit l'objet trouvé (sans tirage) : valeur finale, favori automatique et uid.
function LootService.makeItem(item: Types.ItemDef, mutationId: Types.MutationId?, layer: number): Types.ItemInstance
	return {
		uid = HttpService:GenerateGUID(false),
		itemId = item.id,
		rarity = item.rarity,
		mutation = mutationId,
		value = LootService.computeValue(item.rarity, mutationId, layer),
		favorite = EconomyConfig.AUTO_FAVORITE_RARITIES[item.rarity] == true
			and not (mutationId ~= nil and EconomyConfig.NO_AUTO_FAVORITE_MUTATIONS[mutationId] == true),
	}
end

-- Tirage pour un joueur : sa couche et son multiplicateur de chance (calculé par BoostService
-- avec computeLuckMultiplier), la nuit pour la mutation Maudite.
function LootService.roll(player: Player, luckMultiplier: number): Types.ItemInstance
	local data = PlayerDataService.getData(player)
	local layer = Strata.fromDepth(if data ~= nil then data.depth else 0).layer
	return LootService.rollItem(layer, luckMultiplier, DayNightService.isNight())
end

-- Vérification : fait `count` tirages de rareté et retourne la répartition en %.
function LootService.simulateRarities(count: number, luckMultiplier: number): { [string]: number }
	local counts: { [string]: number } = {}
	for _, rarity in Rarities.list do
		counts[rarity.id] = 0
	end
	for _ = 1, count do
		local id = LootService.rollRarity(luckMultiplier)
		counts[id] += 1
	end
	local percentages: { [string]: number } = {}
	for id, n in counts do
		percentages[id] = n / count * PERCENT
	end
	return percentages
end

function LootService.init() end

function LootService.start() end

return LootService
