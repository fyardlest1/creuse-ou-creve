--!strict
-- Test d'équilibrage, lancé à la main dans Studio (pendant un playtest, côté serveur) :
--   require(game.ServerScriptService.Server.Tests.EconomySimulation).run()
-- Simule un joueur qui creuse au rythme de SIM_SECONDS_PER_ITEM par objet, fait un aller-retour
-- de SIM_SELL_TRIP_SECONDS au Marchand quand le coffre est plein, et achète chaque pelle dès qu'il
-- peut (pendant ce même aller-retour, la Forge étant à côté du Marchand).
-- Deux variantes : "Tout vendre" seulement (les favoris automatiques restent dans le coffre),
-- ou vente de tout, favoris compris.
-- Les tirages passent par le vrai LootService.rollItem (raretés, mutations, couches, favoris).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local PlotConfig = require(Shared.Config.PlotConfig)
local Shovels = require(Shared.Config.Shovels)
local Strata = require(Shared.Config.Strata)
local LootService = require(script.Parent.Parent.Services.LootService)

type ChestEntry = { value: number, favorite: boolean, stratumId: Types.StratumId }

export type RunResult = {
	shovelTimes: { [string]: number? }, -- secondes de jeu à l'achat de chaque pelle
	rockTime: number?, -- secondes de jeu à l'entrée en Roche
	timeInStratum: { [string]: number },
	earnedInStratum: { [string]: number }, -- Pièces de vente, attribuées à la couche où l'objet a été creusé
	finalDepth: number,
}

local CELLS_PER_PLOT = PlotConfig.GRID_SIZE * PlotConfig.GRID_SIZE
local SECONDS_PER_MINUTE = 60
local RUNS_PER_YIELD = 10

local EconomySimulation = {}

local function owns(tier: number, shovelId: Types.ShovelId): boolean
	return Shovels.orderById[shovelId] <= tier
end

function EconomySimulation.runOnce(sellFavorites: boolean, maxSeconds: number): RunResult
	local rockDepth = Strata.byId.Rock.minDepth
	local time = 0
	local coins = EconomyConfig.STARTING_COINS
	local depth = 0
	local tier = 1 -- index de la meilleure pelle possédée dans Shovels.list
	local cellsLeft = CELLS_PER_PLOT
	local chest: { ChestEntry } = {}
	local result: RunResult = {
		shovelTimes = {},
		rockTime = nil,
		timeInStratum = {},
		earnedInStratum = {},
		finalDepth = 0,
	}
	for _, stratum in Strata.list do
		result.timeInStratum[stratum.id] = 0
		result.earnedInStratum[stratum.id] = 0
	end

	while time < maxSeconds do
		local stratum = Strata.fromDepth(depth)
		local shovel = Shovels.list[tier]

		-- Creuse un objet
		local item = LootService.rollItem(stratum.layer, shovel.luckBonus)
		time += EconomyConfig.SIM_SECONDS_PER_ITEM
		result.timeInStratum[stratum.id] += EconomyConfig.SIM_SECONDS_PER_ITEM
		table.insert(chest, { value = item.value, favorite = item.favorite, stratumId = stratum.id })

		-- Parcelle terminée : on descend si on a la pelle de la couche suivante
		cellsLeft -= 1
		if cellsLeft == 0 then
			cellsLeft = CELLS_PER_PLOT
			local nextDepth = depth + PlotConfig.DEPTH_PER_LAYER
			if owns(tier, Strata.fromDepth(nextDepth).requiredShovel) then
				depth = nextDepth
				if result.rockTime == nil and depth >= rockDepth then
					result.rockTime = time
				end
			end
		end

		-- Coffre plein : aller-retour au Marchand, vente, achats à la Forge
		if #chest >= PlayerConfig.INVENTORY_LIMIT then
			local current = Strata.fromDepth(depth)
			time += EconomyConfig.SIM_SELL_TRIP_SECONDS
			result.timeInStratum[current.id] += EconomyConfig.SIM_SELL_TRIP_SECONDS

			local kept: { ChestEntry } = {}
			for _, entry in chest do
				if entry.favorite and not sellFavorites then
					table.insert(kept, entry)
				else
					coins += entry.value
					result.earnedInStratum[entry.stratumId] += entry.value
				end
			end
			chest = kept

			while tier < #Shovels.list and coins >= Shovels.list[tier + 1].price do
				tier += 1
				coins -= Shovels.list[tier].price
				result.shovelTimes[Shovels.list[tier].id] = time
			end

			-- Coffre rempli de favoris : le joueur ne peut plus creuser en "Tout vendre" seul.
			if #chest >= PlayerConfig.INVENTORY_LIMIT then
				break
			end
		end
	end

	result.finalDepth = depth
	return result
end

type Summary = { mean: number, p10: number, p50: number, p90: number, reached: number }

local function summarize(values: { number }): Summary?
	if #values == 0 then
		return nil
	end
	table.sort(values)
	local sum = 0
	for _, value in values do
		sum += value
	end
	local function percentile(p: number): number
		return values[math.clamp(math.ceil(#values * p), 1, #values)]
	end
	return {
		mean = sum / #values,
		p10 = percentile(0.1),
		p50 = percentile(0.5),
		p90 = percentile(0.9),
		reached = #values,
	}
end

local function formatTime(seconds: number): string
	return string.format("%d min %02d s", seconds // SECONDS_PER_MINUTE, math.floor(seconds % SECONDS_PER_MINUTE))
end

local function formatSummary(label: string, summary: Summary?, runs: number): string
	if summary == nil then
		return string.format("  %s : jamais atteint en %d simulations", label, runs)
	end
	return string.format(
		"  %s : moyenne %s | médiane %s | 10 %% %s | 90 %% %s | atteint %d/%d",
		label,
		formatTime(summary.mean),
		formatTime(summary.p50),
		formatTime(summary.p10),
		formatTime(summary.p90),
		summary.reached,
		runs
	)
end

-- Lance `runs` simulations pour une variante et retourne le rapport texte.
function EconomySimulation.runVariant(sellFavorites: boolean, runs: number, maxSeconds: number): string
	local shovelTimes: { [string]: { number } } = {}
	for _, shovel in Shovels.list do
		shovelTimes[shovel.id] = {}
	end
	local rockTimes: { number } = {}
	local timeIn: { [string]: number } = {}
	local earnedIn: { [string]: number } = {}
	for _, stratum in Strata.list do
		timeIn[stratum.id] = 0
		earnedIn[stratum.id] = 0
	end

	for run = 1, runs do
		local result = EconomySimulation.runOnce(sellFavorites, maxSeconds)
		for id, value in result.shovelTimes do
			if value ~= nil then
				table.insert(shovelTimes[id], value)
			end
		end
		if result.rockTime ~= nil then
			table.insert(rockTimes, result.rockTime)
		end
		for id, seconds in result.timeInStratum do
			timeIn[id] += seconds
			earnedIn[id] += result.earnedInStratum[id]
		end
		if run % RUNS_PER_YIELD == 0 then
			task.wait()
		end
	end

	local lines = {
		string.format(
			"Variante : %s (%d simulations de %d min max)",
			if sellFavorites then "vend tout, favoris compris" else '"Tout vendre" seulement, favoris gardés',
			runs,
			maxSeconds // SECONDS_PER_MINUTE
		),
	}
	for _, stratum in Strata.list do
		local minutes = timeIn[stratum.id] / SECONDS_PER_MINUTE
		local rate = if minutes > 0 then earnedIn[stratum.id] / minutes else 0
		table.insert(
			lines,
			string.format("  Pièces/min en %s : %.0f (sur %.0f min cumulées)", stratum.name, rate, minutes)
		)
	end
	for index, shovel in Shovels.list do
		if index > 1 then
			table.insert(lines, formatSummary(shovel.name, summarize(shovelTimes[shovel.id]), runs))
		end
	end
	table.insert(lines, formatSummary("Entrée en Roche (50 m)", summarize(rockTimes), runs))
	return table.concat(lines, "\n")
end

-- Point d'entrée : les deux variantes, résultats dans l'Output.
function EconomySimulation.run(runs: number?, maxSeconds: number?): string
	local runCount = runs or EconomyConfig.SIM_RUNS
	local limit = maxSeconds or EconomyConfig.SIM_MAX_SECONDS
	local report = table.concat({
		"[EconomySimulation] Résultats bruts",
		string.format(
			"Hypothèses : %d s par objet, %d s par aller-retour quand le coffre (%d places) est plein, achat dès que possible",
			EconomyConfig.SIM_SECONDS_PER_ITEM,
			EconomyConfig.SIM_SELL_TRIP_SECONDS,
			PlayerConfig.INVENTORY_LIMIT
		),
		EconomySimulation.runVariant(false, runCount, limit),
		EconomySimulation.runVariant(true, runCount, limit),
	}, "\n")
	print(report)
	return report
end

return EconomySimulation
