--!strict
-- Tests des événements de serveur (plan semaine 5, section 7) :
--   pluie de météorites : calendrier (annonce 10 s avant, toutes les 30 min, 3 min), chance x2 pour
--   Rare et mieux dans la formule unique, toujours plafonnée à x10 ;
--   Nuit de sang : 15 % des nuits, 4 min au lieu de 2, mutations Maudites x3, rien d'autre ne change.
-- Lancement dans Studio (côté serveur, pendant un playtest) :
--   require(game.ServerScriptService.Server.Tests.EventRules).run()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventConfig = require(Shared.Config.EventConfig)
local DayNightConfig = require(Shared.Config.DayNightConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Mutations = require(Shared.Config.Mutations)
local LuckOdds = require(Shared.LuckOdds)
local LootService = require(script.Parent.Parent.Services.LootService)
local DayNightService = require(script.Parent.Parent.Services.DayNightService)
local MeteorService = require(script.Parent.Parent.Services.MeteorService)

local Schedule = MeteorService.Schedule

local MUTATION_ROLLS = 300000
local BLOOD_ROLLS = 100000
local SEED = 20261123

local EventRules = {}

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

local function luck(overrides: { [string]: any }?): number
	local parts: { [string]: any } = {
		shovelBonus = 0,
		luckPass = false,
		potion = false,
		serverEvent = false,
		groupMember = false,
		meteorShower = false,
	}
	for key, value in overrides or {} do
		parts[key] = value
	end
	return LootService.computeLuckMultiplier(parts :: any)
end

local function contains(list: { string }, value: string): boolean
	return table.find(list, value) ~= nil
end

local function testMeteorSchedule()
	section("Pluie de météorites : calendrier")
	local opened = 1000
	local schedule = Schedule.new(opened)
	local first = opened + EventConfig.METEOR_INTERVAL
	check("rien à l'ouverture du serveur", #schedule:step(opened) == 0 and not schedule:isActive(opened))
	check("rien 11 s avant la première pluie", #schedule:step(first - EventConfig.WARNING_SECONDS - 1) == 0)
	local warning = schedule:step(first - EventConfig.WARNING_SECONDS)
	check("annonce 10 s avant la première pluie (30 min après l'ouverture)", contains(warning, "warning"))
	check("annoncée une seule fois", #schedule:step(first - 5) == 0)
	check("pas encore active pendant le compte à rebours", not schedule:isActive(first - 1))
	check("début à l'heure", contains(schedule:step(first), "start") and schedule:isActive(first))
	check("active pendant 3 min", schedule:isActive(first + EventConfig.METEOR_DURATION - 1))
	check(
		"fin après 3 min",
		contains(schedule:step(first + EventConfig.METEOR_DURATION), "end")
			and not schedule:isActive(first + EventConfig.METEOR_DURATION)
	)
	local second = first + EventConfig.METEOR_INTERVAL
	local secondWarning = schedule:step(second - EventConfig.WARNING_SECONDS)
	check("la suivante est annoncée 30 min après le début de la précédente", contains(secondWarning, "warning"))
	check("et commence à l'heure, sans dérive", contains(schedule:step(second), "start"))

	-- Serveur très chargé : un saut d'horloge franchit annonce et début d'un coup, dans l'ordre.
	local late = Schedule.new(0)
	local jumped = late:step(EventConfig.METEOR_INTERVAL + 1)
	check(
		"saut d'horloge : annonce puis début",
		jumped[1] == "warning" and jumped[2] == "start",
		table.concat(jumped, ", ")
	)
end

local function testMeteorLuck()
	section("Pluie de météorites : chance x2 dans la formule unique, plafond x10")
	check("sans bonus : x1", luck() == 1)
	check("pluie seule : x2", luck({ meteorShower = true }) == EventConfig.METEOR_LUCK_MULTIPLIER)
	check("pluie + Chance x2 : x4", math.abs(luck({ meteorShower = true, luckPass = true }) - 4) < 1e-9)
	local everything = luck({
		shovelBonus = 15,
		luckPass = true,
		potion = true,
		serverEvent = true,
		meteorShower = true,
	})
	check("tout cumulé : plafonné à x10", everything == MonetizationConfig.LUCK_CAP, tostring(everything))
	-- Seules les raretés Rare et mieux sont doublées (poids x2 puis renormalisation).
	local normal = LuckOdds.oddsFor(1)
	local meteor = LuckOdds.oddsFor(luck({ meteorShower = true }))
	local rarePlusNormal = normal.Rare + normal.Epic + normal.Legendary + normal.Secret
	local rarePlusMeteor = meteor.Rare + meteor.Epic + meteor.Legendary + meteor.Secret
	local expected = 2 * rarePlusNormal / (100 + rarePlusNormal)
	check(
		string.format("Rare et mieux : %.1f %% au lieu de %.1f %%", rarePlusMeteor, rarePlusNormal),
		math.abs(rarePlusMeteor / 100 - expected) < 1e-9
	)
	check(
		"le rapport Commun / Peu commun ne change pas",
		math.abs(meteor.Common / meteor.Uncommon - normal.Common / normal.Uncommon) < 1e-9
	)
end

local function cursedShare(isNight: boolean, bloodNight: boolean): number
	local cursed = 0
	for _ = 1, MUTATION_ROLLS do
		if LootService.rollMutation(isNight, bloodNight) == "Cursed" then
			cursed += 1
		end
	end
	return cursed / MUTATION_ROLLS * 100
end

local function testBloodNight()
	section("Nuit de sang")
	local rng = Random.new(SEED)
	local blood = 0
	for _ = 1, BLOOD_ROLLS do
		if DayNightService.rollBloodNight(rng) then
			blood += 1
		end
	end
	local share = blood / BLOOD_ROLLS
	check(
		string.format("%d nuits tirées : %.1f %% de Nuits de sang (attendu 15 %%)", BLOOD_ROLLS, share * 100),
		math.abs(share - EventConfig.BLOOD_NIGHT_CHANCE) < 0.005
	)
	check(
		"nuit normale : 2 min",
		DayNightService.getNightDuration(false) == DayNightConfig.NIGHT_DURATION
			and DayNightConfig.NIGHT_DURATION == 120
	)
	check("Nuit de sang : 4 min", DayNightService.getNightDuration(true) == 240)

	local cursedChance = Mutations.byId.Cursed.chance
	local day = cursedShare(false, false)
	local night = cursedShare(true, false)
	local bloodNight = cursedShare(true, true)
	check(string.format("le jour : aucun Maudit (%.2f %%)", day), day == 0)
	check(
		string.format("nuit normale : %.2f %% de Maudits (attendu %.1f %%)", night, cursedChance),
		math.abs(night - cursedChance) < 0.1
	)
	check(
		string.format(
			"Nuit de sang : %.2f %% de Maudits (attendu %.1f %%, x%d)",
			bloodNight,
			cursedChance * EventConfig.BLOOD_NIGHT_CURSED_MULTIPLIER,
			EventConfig.BLOOD_NIGHT_CURSED_MULTIPLIER
		),
		math.abs(bloodNight - cursedChance * EventConfig.BLOOD_NIGHT_CURSED_MULTIPLIER) < 0.15
	)
	-- Les autres mutations gardent leur chance pendant une Nuit de sang.
	local golden = 0
	for _ = 1, MUTATION_ROLLS do
		if LootService.rollMutation(true, true) == "Golden" then
			golden += 1
		end
	end
	local goldenShare = golden / MUTATION_ROLLS * 100
	check(
		string.format(
			"Nuit de sang : Doré inchangé (%.2f %%, attendu %.1f %%)",
			goldenShare,
			Mutations.byId.Golden.chance
		),
		math.abs(goldenShare - Mutations.byId.Golden.chance) < 0.15
	)
	-- Le vol ne dépend pas de la Nuit de sang : StealService ne lit pas cet état, et ses garde-fous
	-- restent vérifiés par StealRules.
end

function EventRules.run(): (string, number, number)
	results = {}
	passed = 0
	failed = 0
	testMeteorSchedule()
	testMeteorLuck()
	testBloodNight()
	local report =
		string.format("[EventRules] %d réussis, %d échoués\n%s", passed, failed, table.concat(results, "\n"))
	print(report)
	return report, passed, failed
end

return EventRules
