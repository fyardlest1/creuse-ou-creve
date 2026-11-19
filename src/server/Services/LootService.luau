--!strict
-- Tirage de rareté, de mutation et d'objet. Tout se décide ici, côté serveur.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Items = require(Shared.Config.Items)
local Shovels = require(Shared.Config.Shovels)
local PlayerDataService = require(script.Parent.PlayerDataService)

local PERCENT = 100

local LootService = {}

local rng = Random.new()

-- Tire une rareté. Le bonus de chance (en %) multiplie le poids des raretés boostées, puis on renormalise.
function LootService.rollRarity(luckBonus: number): Types.RarityId
	local luckMultiplier = 1 + math.max(luckBonus, 0) / PERCENT
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
function LootService.rollMutation(): Types.MutationId?
	local roll = rng:NextNumber(0, PERCENT)
	for _, mutation in Mutations.list do
		roll -= mutation.chance
		if roll < 0 then
			return mutation.id
		end
	end
	return nil
end

-- Choisit un objet de la rareté donnée. Si la couche n'a pas d'objet de cette rareté,
-- on prend la couche la plus profonde en dessous qui en a.
function LootService.pickItem(layer: number, rarity: Types.RarityId): Types.ItemDef
	local bestLayer = 0
	local candidates: { Types.ItemDef } = {}
	for _, item in Items.list do
		if item.rarity == rarity and item.layer <= layer then
			if item.layer > bestLayer then
				bestLayer = item.layer
				candidates = {}
			end
			if item.layer == bestLayer then
				table.insert(candidates, item)
			end
		end
	end
	assert(#candidates > 0, "[LootService] Aucun objet " .. rarity .. " pour la couche " .. layer)
	return candidates[rng:NextInteger(1, #candidates)]
end

-- Tirage complet, sans joueur : rareté, mutation, objet, valeur finale et uid.
function LootService.rollItem(layer: number, luckBonus: number): Types.ItemInstance
	local rarityId = LootService.rollRarity(luckBonus)
	local mutationId = LootService.rollMutation()
	local item = LootService.pickItem(layer, rarityId)

	local multiplier = if mutationId ~= nil then Mutations.byId[mutationId].multiplier else 1
	return {
		uid = HttpService:GenerateGUID(false),
		itemId = item.id,
		rarity = rarityId,
		mutation = mutationId,
		value = Rarities.byId[rarityId].value * multiplier,
	}
end

-- Tirage pour un joueur : utilise sa couche et le bonus de chance de sa pelle.
function LootService.roll(player: Player): Types.ItemInstance
	local data = PlayerDataService.getData(player)
	local layer = if data ~= nil then data.layer else 1
	local shovel = Shovels.byId[Shovels.DEFAULT_ID]
	return LootService.rollItem(layer, shovel.luckBonus)
end

-- Vérification : fait `count` tirages de rareté et retourne la répartition en %.
function LootService.simulateRarities(count: number, luckBonus: number): { [string]: number }
	local counts: { [string]: number } = {}
	for _, rarity in Rarities.list do
		counts[rarity.id] = 0
	end
	for _ = 1, count do
		local id = LootService.rollRarity(luckBonus)
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
