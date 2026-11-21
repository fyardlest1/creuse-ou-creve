--!strict
-- Tests des objets (plan semaine 5, section 4) : les objets d'inspiration anime s'ajoutent dans chaque
-- rareté sans changer les poids des raretés. La rareté est tirée d'abord (poids fixes), l'objet ensuite
-- parmi ceux de la couche : ajouter des objets ne change donc pas la chance d'une rareté.
-- Lancement dans Studio (côté serveur, pendant un playtest) :
--   require(game.ServerScriptService.Server.Tests.ItemRules).run()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Rarities = require(Shared.Config.Rarities)
local Strata = require(Shared.Config.Strata)
local LootService = require(script.Parent.Parent.Services.LootService)

-- Poids de référence des semaines 2 à 4 (en %), et valeurs de vente : ils ne doivent pas bouger.
local EXPECTED_CHANCES = { Common = 60, Uncommon = 25, Rare = 10, Epic = 4, Legendary = 0.9, Secret = 0.1 }
local EXPECTED_VALUES = { Common = 10, Uncommon = 40, Rare = 150, Epic = 600, Legendary = 3000, Secret = 25000 }
local ROLLS_PER_LAYER = 60000
-- Écart toléré entre la part tirée et la chance attendue, en points de % (selon la rareté).
local TOLERANCE = { Common = 1, Uncommon = 1, Rare = 0.6, Epic = 0.4, Legendary = 0.2, Secret = 0.08 }

-- Objets de la semaine 5 : identifiant, rareté, couche.
local NEW_ITEMS = {
	{ id = "rusty_ninja_mask", rarity = "Common", layer = 1 },
	{ id = "lost_captain_compass", rarity = "Uncommon", layer = 1 },
	{ id = "faded_pirate_map", rarity = "Rare", layer = 2 },
	{ id = "ghost_katana", rarity = "Epic", layer = 2 },
	{ id = "cracked_oni_mask", rarity = "Epic", layer = 3 },
	{ id = "sunken_ship_anchor", rarity = "Legendary", layer = 3 },
	{ id = "celestial_pearl", rarity = "Legendary", layer = 3 },
	{ id = "celestial_dragon_egg", rarity = "Secret", layer = 3 },
}

local ItemRules = {}

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

local function testRarityWeights()
	section("Poids et valeurs des raretés inchangés")
	local total = 0
	for _, rarity in Rarities.list do
		total += rarity.chance
		check(
			string.format("%s : %s %%", rarity.id, tostring(rarity.chance)),
			rarity.chance == EXPECTED_CHANCES[rarity.id],
			"attendu " .. tostring(EXPECTED_CHANCES[rarity.id])
		)
		check(
			string.format("%s : valeur %d", rarity.id, rarity.value),
			rarity.value == EXPECTED_VALUES[rarity.id],
			"attendu " .. tostring(EXPECTED_VALUES[rarity.id])
		)
	end
	check("total des chances : 100 %", math.abs(total - 100) < 1e-9, tostring(total))
end

local function testNewItems()
	section("Objets d'inspiration anime")
	for _, expected in NEW_ITEMS do
		local item = Items.byId[expected.id]
		check(
			string.format("%s : %s, couche %d", expected.id, expected.rarity, expected.layer),
			item ~= nil and item.rarity == expected.rarity and item.layer == expected.layer,
			if item == nil then "absent" else item.rarity .. ", couche " .. item.layer
		)
	end
	local hook = Items.byId.captain_hook
	check(
		"captain_hook garde son identifiant, renommé Crochet de Pirate",
		hook ~= nil and hook.name == "Crochet de Pirate" and hook.rarity == "Epic" and hook.layer == 3
	)
	local names: { [string]: boolean } = {}
	local duplicates = {}
	for _, item in Items.list do
		if names[item.name] then
			table.insert(duplicates, item.name)
		end
		names[item.name] = true
	end
	check("aucun nom en double", #duplicates == 0, table.concat(duplicates, ", "))
end

local function testLayerCoverage()
	section("Chaque couche a au moins 2 objets de chaque rareté")
	for _, stratum in Strata.list do
		local missing = {}
		for _, rarity in Rarities.list do
			local count = 0
			for _, item in Items.list do
				if item.layer == stratum.layer and item.rarity == rarity.id then
					count += 1
				end
			end
			if count < 2 then
				table.insert(missing, rarity.id .. " : " .. count)
			end
		end
		check(stratum.name, #missing == 0, table.concat(missing, ", "))
	end
end

local function testRolledDistribution()
	section(string.format("Raretés tirées : %d tirages par couche, sans bonus", ROLLS_PER_LAYER))
	for _, stratum in Strata.list do
		local counts: { [string]: number } = {}
		for _ = 1, ROLLS_PER_LAYER do
			local item = LootService.rollItem(stratum.layer, 1, false)
			counts[item.rarity] = (counts[item.rarity] or 0) + 1
		end
		local worst = ""
		local ok = true
		for _, rarity in Rarities.list do
			local share = (counts[rarity.id] or 0) / ROLLS_PER_LAYER * 100
			if math.abs(share - rarity.chance) > TOLERANCE[rarity.id] then
				ok = false
				worst ..= string.format("%s %.2f %% au lieu de %s ; ", rarity.id, share, tostring(rarity.chance))
			end
		end
		check(stratum.name .. " : parts conformes aux poids", ok, worst)
	end
end

local function testNewItemsRollable()
	section("Les nouveaux objets sortent bien au tirage")
	for _, expected in NEW_ITEMS do
		local seen = false
		for _ = 1, 400 do
			if LootService.pickItem(expected.layer, expected.rarity :: any).id == expected.id then
				seen = true
				break
			end
		end
		check(expected.id, seen)
	end
end

function ItemRules.run(): (string, number, number)
	results = {}
	passed = 0
	failed = 0
	testRarityWeights()
	testNewItems()
	testLayerCoverage()
	testRolledDistribution()
	testNewItemsRollable()
	local report =
		string.format("[ItemRules] %d réussis, %d échoués\n%s", passed, failed, table.concat(results, "\n"))
	print(report)
	return report, passed, failed
end

return ItemRules
