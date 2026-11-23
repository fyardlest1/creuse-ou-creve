--!strict
-- Test d'équilibrage, lancé à la main dans Studio (pendant un playtest, côté serveur) :
--   require(game.ServerScriptService.Server.Tests.EconomySimulation).run()
-- Simule un joueur qui creuse au rythme de SIM_SECONDS_PER_ITEM par objet, fait un aller-retour
-- de SIM_SELL_TRIP_SECONDS au Marchand quand le coffre est plein, et achète chaque pelle dès qu'il
-- peut (pendant ce même aller-retour, la Forge étant à côté du Marchand).
-- Deux variantes : "Tout vendre" seulement (les favoris automatiques restent dans le coffre),
-- ou vente de tout, favoris compris.
-- Les tirages passent par le vrai LootService.rollItem (raretés, mutations, couches, favoris).
--
-- Semaine 5 : trois scénarios, chacun en variantes A et B.
--   "reference" : comme en semaine 2, sans cycle jour et nuit (aucune mutation Maudite).
--   "cycle"     : cycle jour et nuit réel (8 min / 2 min) : mutations Maudites la nuit.
--   "events"    : cycle, plus pluie de météorites (toutes les 30 min, 3 min, chance x2 dans la formule
--                 unique, plafond x10) et Nuit de sang (15 % des nuits, 4 min, Maudits x3).
-- Le joueur arrive à un moment quelconque du cycle et du calendrier des météorites (décalages au hasard).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local PlotConfig = require(Shared.Config.PlotConfig)
local Shovels = require(Shared.Config.Shovels)
local Strata = require(Shared.Config.Strata)
local DayNightConfig = require(Shared.Config.DayNightConfig)
local EventConfig = require(Shared.Config.EventConfig)
local StudioTestMode = require(Shared.Config.StudioTestMode)
local LootService = require(script.Parent.Parent.Services.LootService)
local DayNightService = require(script.Parent.Parent.Services.DayNightService)

export type Scenario = "reference" | "cycle" | "events"

type ChestEntry = { value: number, favorite: boolean, stratumId: Types.StratumId }

export type RunResult = {
	shovelTimes: { [string]: number? }, -- secondes de jeu à l'achat de chaque pelle
	rockTime: number?, -- secondes de jeu à l'entrée en Roche
	timeInStratum: { [string]: number },
	earnedInStratum: { [string]: number }, -- Pièces de vente, attribuées à la couche où l'objet a été creusé
	finalDepth: number,
	meteorSeconds: number, -- temps de jeu passé sous une pluie de météorites
	nightSeconds: number, -- temps de jeu passé la nuit
	bloodSeconds: number, -- temps de jeu passé en Nuit de sang
	digSeconds: number, -- temps passé à creuser (sans les allers-retours au Marchand)
}

local CELLS_PER_PLOT = PlotConfig.GRID_SIZE * PlotConfig.GRID_SIZE
local SECONDS_PER_MINUTE = 60
local RUNS_PER_YIELD = 10
-- En mode test Studio, le jour est raccourci : la simulation garde la vraie durée de 8 minutes.
local REAL_DAY_DURATION = if StudioTestMode.ACTIVE then 8 * 60 else DayNightConfig.DAY_DURATION
local SCENARIO_LABELS: { [Scenario]: string } = {
	reference = "Référence semaine 2 (sans cycle jour et nuit)",
	cycle = "Cycle jour et nuit, sans événements",
	events = "Cycle jour et nuit + pluie de météorites + Nuit de sang",
}

local EconomySimulation = {}

local function owns(tier: number, shovelId: Types.ShovelId): boolean
	return Shovels.orderById[shovelId] <= tier
end

-- Horloge du monde pour une partie : phase jour ou nuit (Nuit de sang tirée à chaque nuit) et
-- pluie de météorites, à partir d'un moment au hasard du cycle.
type WorldClock = {
	night: boolean,
	blood: boolean,
	phaseEndsAt: number,
	meteorOffset: number,
}

local function newWorldClock(rng: Random): WorldClock
	local cycle = REAL_DAY_DURATION + DayNightConfig.NIGHT_DURATION
	local position = rng:NextNumber(0, cycle)
	local night = position >= REAL_DAY_DURATION
	return {
		night = night,
		blood = false,
		phaseEndsAt = if night then cycle - position else REAL_DAY_DURATION - position,
		meteorOffset = rng:NextNumber(0, EventConfig.METEOR_INTERVAL),
	}
end

local function advanceClock(clock: WorldClock, time: number, events: boolean, rng: Random)
	while time >= clock.phaseEndsAt do
		if clock.night then
			clock.night = false
			clock.blood = false
			clock.phaseEndsAt += REAL_DAY_DURATION
		else
			clock.night = true
			clock.blood = events and DayNightService.rollBloodNight(rng)
			clock.phaseEndsAt += DayNightService.getNightDuration(clock.blood)
		end
	end
end

local function meteorActive(clock: WorldClock, time: number): boolean
	return (time + clock.meteorOffset) % EventConfig.METEOR_INTERVAL < EventConfig.METEOR_DURATION
end

function EconomySimulation.runOnce(sellFavorites: boolean, maxSeconds: number, scenario: Scenario?): RunResult
	local mode: Scenario = scenario or "reference"
	local useCycle = mode ~= "reference"
	local useEvents = mode == "events"
	local rng = Random.new()
	local clock = newWorldClock(rng)
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
		meteorSeconds = 0,
		nightSeconds = 0,
		bloodSeconds = 0,
		digSeconds = 0,
	}
	for _, stratum in Strata.list do
		result.timeInStratum[stratum.id] = 0
		result.earnedInStratum[stratum.id] = 0
	end

	while time < maxSeconds do
		local stratum = Strata.fromDepth(depth)
		local shovel = Shovels.list[tier]

		-- Creuse un objet (avec la phase et les événements du moment)
		advanceClock(clock, time, useEvents, rng)
		local isNight = useCycle and clock.night
		local bloodNight = isNight and clock.blood
		local meteor = useEvents and meteorActive(clock, time)
		local luck = LootService.computeLuckMultiplier({
			shovelBonus = shovel.luckBonus,
			luckPass = false,
			potion = false,
			serverEvent = false,
			groupMember = false,
			meteorShower = meteor,
		})
		local item = LootService.rollItem(stratum.layer, luck, isNight, bloodNight)
		local step = EconomyConfig.SIM_SECONDS_PER_ITEM
		result.meteorSeconds += if meteor then step else 0
		result.nightSeconds += if isNight then step else 0
		result.bloodSeconds += if bloodNight then step else 0
		result.digSeconds += step
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

export type VariantStats = { steelMean: number?, rockMean: number?, ironMean: number? }

-- Lance `runs` simulations pour une variante et retourne le rapport texte (et les moyennes utiles).
function EconomySimulation.runVariant(
	sellFavorites: boolean,
	runs: number,
	maxSeconds: number,
	scenario: Scenario?
): (string, VariantStats)
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

	local meteorSeconds, nightSeconds, bloodSeconds, digSeconds = 0, 0, 0, 0
	for run = 1, runs do
		local result = EconomySimulation.runOnce(sellFavorites, maxSeconds, scenario)
		meteorSeconds += result.meteorSeconds
		nightSeconds += result.nightSeconds
		bloodSeconds += result.bloodSeconds
		digSeconds += result.digSeconds
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
			"Variante %s : %s (%d simulations de %d min max)",
			if sellFavorites then "B" else "A",
			if sellFavorites then "vend tout, favoris compris" else '"Tout vendre" seulement, favoris gardés',
			runs,
			maxSeconds // SECONDS_PER_MINUTE
		),
	}
	if scenario ~= nil and scenario ~= "reference" and digSeconds > 0 then
		table.insert(
			lines,
			string.format(
				"  Temps de creusage : %.1f %% la nuit, dont %.1f %% en Nuit de sang ; %.1f %% sous les météorites",
				nightSeconds / digSeconds * 100,
				bloodSeconds / digSeconds * 100,
				meteorSeconds / digSeconds * 100
			)
		)
	end
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
	local rockSummary = summarize(rockTimes)
	table.insert(lines, formatSummary("Entrée en Roche (50 m)", rockSummary, runs))
	local ironSummary = summarize(shovelTimes[Shovels.list[2].id])
	local steelSummary = summarize(shovelTimes[Shovels.list[#Shovels.list].id])
	return table.concat(lines, "\n"),
		{
			ironMean = if ironSummary ~= nil then ironSummary.mean else nil,
			steelMean = if steelSummary ~= nil then steelSummary.mean else nil,
			rockMean = if rockSummary ~= nil then rockSummary.mean else nil,
		}
end

-- Cibles de la section 7 du plan de la semaine 2.
local function targetLines(a: VariantStats, b: VariantStats): string
	local function mark(ok: boolean): string
		return if ok then "[x]" else "[ ]"
	end
	local function show(seconds: number?): string
		return if seconds ~= nil then formatTime(seconds) else "jamais"
	end
	local iron = a.ironMean
	local steel = a.steelMean
	local rock = a.rockMean
	local steelB = b.steelMean
	return table.concat({
		"  Cibles (plan semaine 2, section 7) :",
		string.format(
			"    %s A : Pelle en fer avant 3 min (%s)",
			mark(iron ~= nil and iron < EconomyConfig.SIM_TARGET_IRON_SECONDS),
			show(iron)
		),
		string.format(
			"    %s A : Pelle en acier entre 8 et 15 min en moyenne (%s)",
			mark(
				steel ~= nil
					and steel >= EconomyConfig.SIM_TARGET_STEEL_MIN_SECONDS
					and steel <= EconomyConfig.SIM_TARGET_STEEL_MAX_SECONDS
			),
			show(steel)
		),
		string.format(
			"    %s A : entrée en Roche avant 30 min (%s)",
			mark(rock ~= nil and rock < EconomyConfig.SIM_TARGET_ROCK_SECONDS),
			show(rock)
		),
		string.format(
			"    %s B : Pelle en acier pas avant 5 min en moyenne (%s)",
			mark(steelB ~= nil and steelB >= EconomyConfig.SIM_TARGET_STEEL_B_MIN_SECONDS),
			show(steelB)
		),
	}, "\n")
end

-- Point d'entrée : variantes A et B, pour un scénario ou pour les trois ; résultats dans l'Output.
function EconomySimulation.run(runs: number?, maxSeconds: number?, scenario: Scenario?): string
	local runCount = runs or EconomyConfig.SIM_RUNS
	local limit = maxSeconds or EconomyConfig.SIM_MAX_SECONDS
	local scenarios: { Scenario } = if scenario ~= nil then { scenario } else { "reference", "cycle", "events" }
	local parts = {
		"[EconomySimulation] Résultats bruts",
		string.format(
			"Hypothèses : %d s par objet, %d s par aller-retour quand le coffre (%d places) est plein, achat dès que possible",
			EconomyConfig.SIM_SECONDS_PER_ITEM,
			EconomyConfig.SIM_SELL_TRIP_SECONDS,
			PlayerConfig.INVENTORY_LIMIT
		),
	}
	for _, name in scenarios do
		table.insert(parts, "== " .. SCENARIO_LABELS[name])
		local reportA, statsA = EconomySimulation.runVariant(false, runCount, limit, name)
		local reportB, statsB = EconomySimulation.runVariant(true, runCount, limit, name)
		table.insert(parts, reportA)
		table.insert(parts, reportB)
		table.insert(parts, targetLines(statsA, statsB))
	end
	local report = table.concat(parts, "\n")
	print(report)
	return report
end

return EconomySimulation
