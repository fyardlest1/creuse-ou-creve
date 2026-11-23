--!strict
-- Tests du mini-jeu de crochetage (plan semaine 5, section 6) :
--   1. les règles du jeu (curseur, zone verte, réglages avec et sans Garde du corps) ;
--   2. la durée moyenne, avec un joueur modélisé : environ 5 s, et 8 s avec le Garde du corps ;
--   3. un client modifié qui envoie « réussi » trop tôt n'obtient rien (le serveur mesure la durée).
-- Lancement dans Studio (côté serveur, pendant un playtest) :
--   require(game.ServerScriptService.Server.Tests.LockpickRules).run()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Lockpick = require(Shared.Lockpick)
local StealConfig = require(Shared.Config.StealConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local StealService = require(script.Parent.Parent.Services.StealService)

local NightState = StealService.NightState

-- Joueur modélisé (hypothèses de la simulation, pas des règles du jeu) : il lui faut REACTION_TIME
-- après chaque touche pour viser la zone suivante, et il touche au moment où le curseur passe au
-- centre de la zone, avec une erreur de visée aléatoire (loi normale d'écart-type TAP_ERROR_SIGMA).
local REACTION_TIME = 0.35 -- secondes
local TAP_ERROR_SIGMA = 0.07 -- secondes
local SIMULATIONS = 4000
local SEED = 20261123
-- Moyennes visées (plan : proche de 5 s, 8 s avec le Garde du corps), avec leur marge acceptée.
local TARGET_RANGE = { min = 4.4, max = 5.6 }
local GUARD_TARGET_RANGE = { min = 7.0, max = 9.0 }

local THIEF = -1
local VICTIM = -2

local LockpickRules = {}

local results: { string } = {}
local passed = 0
local failed = 0

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		table.insert(results, "  OK    " .. name)
	else
		failed += 1
		table.insert(results, "  ÉCHEC " .. name .. (if detail then " (" .. detail .. ")" else ""))
	end
end

local function section(title: string)
	table.insert(results, title)
end

local function gaussian(rng: Random): number
	local u1 = math.max(rng:NextNumber(), 1e-12)
	local u2 = rng:NextNumber()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

-- Premier instant >= from où le curseur passe en position target.
local function nextCrossing(target: number, from: number, travelTime: number): number
	local period = 2 * travelTime
	local base = math.floor(from / period) * period
	local best = math.huge
	for cycle = 0, 1 do
		for _, offset in { target * travelTime, (2 - target) * travelTime } do
			local candidate = base + cycle * period + offset
			if candidate >= from and candidate < best then
				best = candidate
			end
		end
	end
	return best
end

-- Une partie du joueur modélisé ; retourne l'instant (client) où « réussi » est envoyé.
local function simulateOnce(settings: Lockpick.Settings, rng: Random): number
	local zone = Lockpick.newZoneCenter(rng, settings.zoneWidth)
	local streak = 0
	local now = 0
	local readyAt = REACTION_TIME
	while true do
		local tap = nextCrossing(zone, readyAt, settings.travelTime) + gaussian(rng) * TAP_ERROR_SIGMA
		now = math.max(tap, now)
		if Lockpick.isInZone(Lockpick.cursorAt(now, settings.travelTime), zone, settings.zoneWidth) then
			streak += 1
			if streak >= settings.hitsRequired then
				break
			end
			zone = Lockpick.newZoneCenter(rng, settings.zoneWidth)
		else
			streak = 0
		end
		readyAt = now + REACTION_TIME
	end
	-- Le client attend la durée minimale (plus sa marge) avant d'envoyer « réussi ».
	return math.max(now, Lockpick.sendDelay(settings))
end

local function context(minPickSeconds: number): StealService.AttemptContext
	local victimInventory: { Types.ItemInstance } = {
		{ uid = "lp-1", itemId = "lost_sock", rarity = "Common", value = 10, favorite = false },
	}
	return {
		isNight = true,
		thiefId = THIEF,
		victimId = VICTIM,
		thiefProtected = false,
		victimProtected = false,
		victimShielded = false,
		victimOnline = true,
		distance = 5,
		thiefInventoryCount = 0,
		thiefInventoryLimit = PlayerConfig.INVENTORY_LIMIT,
		victimInventory = victimInventory,
		minPickSeconds = minPickSeconds,
	}
end

local function testSettings()
	section("Réglages du mini-jeu")
	local normal = Lockpick.settings(false)
	local guard = Lockpick.settings(true)
	check("3 touches réussies de suite", normal.hitsRequired == 3 and guard.hitsRequired == 3)
	check("durée minimale : 4 s", normal.minSeconds == 4, tostring(normal.minSeconds))
	check("Garde du corps : durée minimale 6,5 s", guard.minSeconds == 6.5, tostring(guard.minSeconds))
	check(
		"Garde du corps : zone verte plus petite",
		guard.zoneWidth < normal.zoneWidth,
		string.format("%.2f contre %.2f", guard.zoneWidth, normal.zoneWidth)
	)
	check(
		"Garde du corps : réglages tirés de MonetizationConfig",
		guard.zoneWidth == MonetizationConfig.BODYGUARD_PICK_ZONE_WIDTH
			and guard.minSeconds == MonetizationConfig.BODYGUARD_PICK_MIN_SECONDS
	)
	check("le client envoie « réussi » après la durée minimale", Lockpick.sendDelay(normal) > normal.minSeconds)
end

local function testCursorAndZone()
	section("Curseur et zone verte")
	local travel = StealConfig.PICK_CURSOR_TRAVEL_TIME
	check("curseur à gauche au départ", Lockpick.cursorAt(0, travel) == 0)
	check("curseur à droite après une traversée", math.abs(Lockpick.cursorAt(travel, travel) - 1) < 1e-9)
	check("curseur revenu à gauche après un aller-retour", math.abs(Lockpick.cursorAt(2 * travel, travel)) < 1e-9)
	local inBar = true
	for step = 0, 1000 do
		local position = Lockpick.cursorAt(step * 0.0137, travel)
		inBar = inBar and position >= 0 and position <= 1
	end
	check("le curseur reste dans la barre", inBar)

	local rng = Random.new(SEED)
	local insideBar = true
	for _ = 1, 10000 do
		for _, width in { StealConfig.PICK_ZONE_WIDTH, MonetizationConfig.BODYGUARD_PICK_ZONE_WIDTH } do
			local center = Lockpick.newZoneCenter(rng, width)
			insideBar = insideBar
				and center - width / 2 >= StealConfig.PICK_ZONE_EDGE_MARGIN - 1e-9
				and center + width / 2 <= 1 - StealConfig.PICK_ZONE_EDGE_MARGIN + 1e-9
		end
	end
	check("la zone verte ne touche jamais les bords (10 000 tirages)", insideBar)
	check("curseur au centre de la zone : dans la zone", Lockpick.isInZone(0.5, 0.5, 0.2))
	check("curseur au bord de la zone : dans la zone", Lockpick.isInZone(0.6, 0.5, 0.2))
	check("curseur juste hors de la zone : raté", not Lockpick.isInZone(0.61, 0.5, 0.2))
end

local function summarize(durations: { number }): (number, number, number)
	table.sort(durations)
	local total = 0
	for _, value in durations do
		total += value
	end
	local count = #durations
	return total / count, durations[math.max(1, math.floor(count * 0.1))], durations[math.floor(count * 0.9)]
end

local function testAverageDuration()
	section(
		string.format(
			"Durée moyenne : %d parties d'un joueur modélisé (réaction %.2f s, erreur de visée %.2f s)",
			SIMULATIONS,
			REACTION_TIME,
			TAP_ERROR_SIGMA
		)
	)
	for _, case in
		{
			{ label = "sans Garde du corps", settings = Lockpick.settings(false), range = TARGET_RANGE },
			{ label = "avec le Garde du corps", settings = Lockpick.settings(true), range = GUARD_TARGET_RANGE },
		}
	do
		local rng = Random.new(SEED)
		local durations = {}
		local state = NightState.new()
		local allAccepted = true
		for _ = 1, SIMULATIONS do
			local sentAt = simulateOnce(case.settings, rng)
			table.insert(durations, sentAt)
			-- Le serveur mesure au moins le temps du client (la latence ne fait qu'ajouter).
			allAccepted = allAccepted and (state:checkFinish(context(case.settings.minSeconds), sentAt))
		end
		local mean, low, high = summarize(durations)
		check(
			string.format(
				"%s : moyenne %.2f s (visée %.1f à %.1f s ; 10 %% %.2f s, 90 %% %.2f s)",
				case.label,
				mean,
				case.range.min,
				case.range.max,
				low,
				high
			),
			mean >= case.range.min and mean <= case.range.max
		)
		check(case.label .. " : un joueur honnête n'est jamais refusé pour durée trop courte", allAccepted)
	end
end

local function testModifiedClient()
	section("Client modifié : « réussi » envoyé trop tôt")
	for _, case in
		{
			{ label = "sans Garde du corps", minimum = StealConfig.PICK_MIN_SECONDS },
			{ label = "avec le Garde du corps", minimum = MonetizationConfig.BODYGUARD_PICK_MIN_SECONDS },
		}
	do
		local state = NightState.new()
		local immediateOk, immediateReason = state:checkFinish(context(case.minimum), 0.05)
		check(
			case.label .. " : « réussi » immédiat refusé",
			not immediateOk and immediateReason == "too_early",
			tostring(immediateReason)
		)
		local almostOk = state:checkFinish(context(case.minimum), case.minimum - 0.01)
		check(case.label .. " : « réussi » 0,01 s avant le minimum refusé", not almostOk)
		check(
			case.label .. " : rien n'est compté (ni vol, ni victime pillée)",
			state:countSteals(THIEF) == 0 and not state:isRobbed(VICTIM)
		)
	end
	-- Un client qui prétend avoir une zone plus large ne gagne rien : la durée minimale ne dépend que
	-- du coffre visé, décidée par le serveur.
	local state = NightState.new()
	local guardOk =
		state:checkFinish(context(MonetizationConfig.BODYGUARD_PICK_MIN_SECONDS), StealConfig.PICK_MIN_SECONDS)
	check("coffre avec Garde du corps : « réussi » à 4 s refusé", not guardOk)
end

function LockpickRules.run(): (string, number, number)
	results = {}
	passed = 0
	failed = 0
	testSettings()
	testCursorAndZone()
	testAverageDuration()
	testModifiedClient()
	local report =
		string.format("[LockpickRules] %d réussis, %d échoués\n%s", passed, failed, table.concat(results, "\n"))
	print(report)
	return report, passed, failed
end

return LockpickRules
