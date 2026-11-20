--!strict
-- Tests des règles du vol, sans vrais joueurs (plan semaine 3, sections 3 et 7).
-- Lancement dans Studio (côté serveur, pendant un playtest) :
--   require(game.ServerScriptService.Server.Tests.StealRules).run()
-- Chaque garde-fou de la section 3 a au moins un test. Les identifiants sont négatifs,
-- comme les joueurs d'un Local Server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local StealConfig = require(Shared.Config.StealConfig)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local StealService = require(script.Parent.Parent.Services.StealService)
local ProtectionService = require(script.Parent.Parent.Services.ProtectionService)

local NightState = StealService.NightState

local THIEF = -1
local VICTIM = -2
local OTHER_VICTIM = -3
local THIRD_VICTIM = -4
local OTHER_THIEF = -5

local StealRules = {}

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

local uidCounter = 0
local function item(rarity: Types.RarityId, favorite: boolean?): Types.ItemInstance
	uidCounter += 1
	return {
		uid = "test-" .. uidCounter,
		itemId = "lost_sock",
		rarity = rarity,
		mutation = nil,
		value = 10,
		favorite = favorite == true,
	}
end

local function inventory(count: number, rarity: Types.RarityId): { Types.ItemInstance }
	local list = {}
	for _ = 1, count do
		table.insert(list, item(rarity))
	end
	return list
end

-- Contexte valide par défaut : la nuit, deux joueurs non protégés, à portée, coffre volable.
local function context(overrides: { [string]: any }?): StealService.AttemptContext
	local base: { [string]: any } = {
		isNight = true,
		thiefId = THIEF,
		victimId = VICTIM,
		thiefProtected = false,
		victimProtected = false,
		victimOnline = true,
		distance = 5,
		thiefInventoryCount = 0,
		thiefInventoryLimit = PlayerConfig.INVENTORY_LIMIT,
		victimInventory = inventory(3, "Common"),
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base :: any
end

local function expectReason(
	name: string,
	state: StealService.NightState,
	ctx: StealService.AttemptContext,
	expected: string?
)
	local ok, reason = state:checkStart(ctx)
	if expected == nil then
		check(name, ok, "refusé : " .. tostring(reason))
	else
		check(name, not ok and reason == expected, "obtenu : " .. tostring(reason))
	end
end

local function uidSet(...: { Types.ItemInstance }): ({ [string]: number }, number)
	local set: { [string]: number } = {}
	local total = 0
	for _, list in { ... } do
		for _, entry in list do
			set[entry.uid] = (set[entry.uid] or 0) + 1
			total += 1
		end
	end
	return set, total
end

local function testGuardrail1()
	table.insert(results, "Garde-fou 1 : une victime perd au maximum 1 objet par nuit")
	local state = NightState.new()
	expectReason("avant tout vol, la victime peut être visée", state, context(), nil)
	state:recordSuccess(THIEF, VICTIM)
	expectReason("après un vol, le même voleur est refusé", state, context(), "already_robbed")
	expectReason(
		"après un vol, un autre voleur est refusé aussi",
		state,
		context({ thiefId = OTHER_THIEF }),
		"already_robbed"
	)
	check("la victime est marquée « déjà pillée cette nuit »", state:isRobbed(VICTIM))
	state:reset()
	expectReason("au lever du jour, la victime peut de nouveau être visée", state, context(), nil)
end

local function testGuardrail2()
	table.insert(results, "Garde-fou 2 : un voleur réussit au maximum 2 vols par nuit, victimes différentes")
	local state = NightState.new()
	state:recordSuccess(THIEF, VICTIM)
	expectReason("2e vol sur une autre victime : autorisé", state, context({ victimId = OTHER_VICTIM }), nil)
	state:recordSuccess(THIEF, OTHER_VICTIM)
	check("le voleur compte 2 vols", state:countSteals(THIEF) == 2)
	expectReason("3e vol sur une 3e victime : refusé", state, context({ victimId = THIRD_VICTIM }), "thief_limit")
	expectReason(
		"un autre voleur n'est pas limité par les vols du premier",
		state,
		context({ thiefId = OTHER_THIEF, victimId = THIRD_VICTIM }),
		nil
	)
	state:reset()
	expectReason("au lever du jour, le compteur repart à zéro", state, context({ victimId = THIRD_VICTIM }), nil)
end

local function testGuardrail3()
	table.insert(results, "Garde-fou 3 : les Secrets ne sont jamais volables")
	local state = NightState.new()
	check("un Secret n'est pas volable", not StealService.isStealable(item("Secret")))
	check("un Légendaire favori est volable", StealService.isStealable(item("Legendary", true)))
	expectReason(
		"coffre ne contenant que des Secrets : rien à voler",
		state,
		context({ victimInventory = inventory(4, "Secret") }),
		"nothing_to_steal"
	)

	local secretsOnly = inventory(4, "Secret")
	local thiefList: { Types.ItemInstance } = {}
	local stolen = StealService.transferItem(secretsOnly, thiefList, "Victime", Random.new(1))
	check("transfert sur un coffre de Secrets : aucun objet", stolen == nil and #secretsOnly == 4 and #thiefList == 0)

	local rng = Random.new(42)
	local secretStolen = 0
	for _ = 1, 2000 do
		local mixed = { item("Secret"), item("Common"), item("Secret"), item("Legendary", true), item("Secret") }
		local loot = StealService.transferItem(mixed, {}, "Victime", rng)
		if loot ~= nil and loot.rarity == "Secret" then
			secretStolen += 1
		end
	end
	check("2 000 vols sur un coffre mélangé : aucun Secret volé", secretStolen == 0, secretStolen .. " Secrets")
end

local function testGuardrail4()
	table.insert(results, "Garde-fou 4 : protection débutant, symétrique")
	local state = NightState.new()
	expectReason("un voleur protégé ne peut pas voler", state, context({ thiefProtected = true }), "thief_protected")
	expectReason(
		"une victime protégée ne peut pas être volée",
		state,
		context({ victimProtected = true }),
		"victim_protected"
	)
	check(
		"protection pleine à 0 s de jeu",
		ProtectionService.remainingFor(0) == StealConfig.PROTECTION_SECONDS
			and (StealConfig.PROTECTION_SECONDS == 0 or ProtectionService.remainingFor(0) > 0)
	)
	check(
		"plus de protection une fois le temps écoulé",
		ProtectionService.remainingFor(StealConfig.PROTECTION_SECONDS) == 0
	)
	check("protection jamais négative", ProtectionService.remainingFor(StealConfig.PROTECTION_SECONDS * 2) == 0)
end

local function testGuardrail5()
	table.insert(results, "Garde-fou 5 : les joueurs hors ligne ne perdent rien")
	local state = NightState.new()
	expectReason("victime partie : refusé", state, context({ victimOnline = false }), "victim_offline")
end

local function testGuardrail6()
	table.insert(results, "Garde-fou 6 : le vol ne fait jamais disparaître (ni dupliquer) un objet")
	local rng = Random.new(7)

	local victimList = inventory(5, "Rare")
	local fullThief = inventory(PlayerConfig.INVENTORY_LIMIT, "Common")
	local beforeSet = uidSet(victimList)
	local loot = StealService.transferItem(victimList, fullThief, "Victime", rng)
	local afterSet = uidSet(victimList)
	local unchanged = #victimList == 5 and #fullThief == PlayerConfig.INVENTORY_LIMIT
	for uid in beforeSet do
		unchanged = unchanged and afterSet[uid] == 1
	end
	check("coffre du voleur plein : rien n'est retiré à la victime", loot == nil and unchanged)

	local victim2 = inventory(5, "Epic")
	local thief2 = inventory(2, "Common")
	local _, totalBefore = uidSet(victim2, thief2)
	local stolen = StealService.transferItem(victim2, thief2, "Yardley", rng)
	local set, totalAfter = uidSet(victim2, thief2)
	local noDuplicate = true
	for _, count in set do
		noDuplicate = noDuplicate and count == 1
	end
	check("un objet passe de la victime au voleur", stolen ~= nil and #victim2 == 4 and #thief2 == 3)
	check("aucun objet perdu ni dupliqué", totalBefore == totalAfter and noDuplicate)
	check(
		"l'objet garde son uid et reçoit stolenFrom",
		stolen ~= nil and set[stolen.uid] == 1 and stolen.stolenFrom == "Yardley"
	)
	check("l'objet volé est bien dans le coffre du voleur", stolen ~= nil and thief2[#thief2] == stolen)

	local state = NightState.new()
	expectReason(
		"coffre du voleur plein : crochetage refusé dès le début",
		state,
		context({ thiefInventoryCount = PlayerConfig.INVENTORY_LIMIT }),
		"thief_chest_full"
	)
	expectReason(
		"Coffre agrandi : 30 objets sur 60 places, le voleur peut encore voler",
		state,
		context({ thiefInventoryCount = PlayerConfig.INVENTORY_LIMIT, thiefInventoryLimit = 60 }),
		nil
	)
	local bigThief = inventory(PlayerConfig.INVENTORY_LIMIT, "Common")
	local loot60 = StealService.transferItem(inventory(3, "Rare"), bigThief, "Victime", rng, 60)
	check("transfert vers un coffre de 60 places à 30/60 : accepté", loot60 ~= nil and #bigThief == 31)
end

local function testOtherValidations()
	table.insert(results, "Validations du serveur (section 7)")
	local state = NightState.new()
	expectReason("le jour : refusé", state, context({ isNight = false }), "day")
	expectReason("son propre coffre : refusé", state, context({ victimId = THIEF }), "own_chest")
	expectReason("à 10 studs : autorisé", state, context({ distance = StealConfig.PICK_MAX_DISTANCE }), nil)
	expectReason(
		"à plus de 10 studs : refusé",
		state,
		context({ distance = StealConfig.PICK_MAX_DISTANCE + 0.1 }),
		"too_far"
	)
	state:ban(THIEF, VICTIM)
	expectReason("voleur éjecté de ce coffre : refusé pour la nuit", state, context(), "banned")
	expectReason("le bannissement ne vaut que pour ce coffre", state, context({ victimId = OTHER_VICTIM }), nil)
	state:reset()
	expectReason("au lever du jour, le bannissement est levé", state, context(), nil)

	local shortOk, shortReason = state:checkFinish(context(), 2)
	check("maintenu 2 s : refusé", not shortOk and shortReason == "hold_too_short", tostring(shortReason))
	local tooShortOk = state:checkFinish(context(), StealConfig.PICK_DURATION - StealConfig.PICK_TIME_TOLERANCE - 0.01)
	check("maintenu juste sous la marge : refusé", not tooShortOk)
	local fullOk = state:checkFinish(context(), StealConfig.PICK_DURATION)
	check("maintenu 5 s : autorisé", fullOk)
	local dayOk, dayReason = state:checkFinish(context({ isNight = false }), StealConfig.PICK_DURATION)
	check("5 s maintenues mais le jour s'est levé : refusé", not dayOk and dayReason == "day")
end

function StealRules.run(): (string, number, number)
	results = {}
	passed = 0
	failed = 0
	testGuardrail1()
	testGuardrail2()
	testGuardrail3()
	testGuardrail4()
	testGuardrail5()
	testGuardrail6()
	testOtherValidations()
	local report =
		string.format("[StealRules] %d réussis, %d échoués\n%s", passed, failed, table.concat(results, "\n"))
	print(report)
	return report, passed, failed
end

return StealRules
