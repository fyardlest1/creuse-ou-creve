--!strict
-- Tests de la traduction (plan semaine 5, section 11) : aucune clé manquante en anglais, mêmes marqueurs de
-- formatage dans les deux langues, langue choisie d'après le compte Roblox, noms de toutes les données
-- traduits, textes des instances posés par le serveur.
-- Lancement dans Studio (côté serveur, pendant un playtest) :
--   require(game.ServerScriptService.Server.Tests.LocaleRules).run()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locale = require(Shared.Locale)
local Items = require(Shared.Config.Items)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Strata = require(Shared.Config.Strata)
local Shovels = require(Shared.Config.Shovels)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local RetentionConfig = require(Shared.Config.RetentionConfig)

local LocaleRules = {}

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

-- Marqueurs de formatage dans l'ordre ("%s", "%d", "%02d"...), sans les "%%".
local function placeholders(text: string): string
	local found = {}
	local cleaned = string.gsub(text, "%%%%", "")
	for marker in string.gmatch(cleaned, "%%[%-%d%.]*[sdfiqx]") do
		table.insert(found, marker)
	end
	return table.concat(found, " ")
end

-- Clés des noms de données attendues en anglais.
local function dataKeys(): { string }
	local keys = {}
	for _, item in Items.list do
		table.insert(keys, "item." .. item.id)
	end
	for _, rarity in Rarities.list do
		table.insert(keys, "rarity." .. rarity.id)
	end
	for _, mutation in Mutations.list do
		table.insert(keys, "mutation." .. mutation.id)
	end
	for _, stratum in Strata.list do
		table.insert(keys, "stratum." .. stratum.id)
		table.insert(keys, "stratum." .. stratum.id .. ".the")
	end
	for _, shovel in Shovels.list do
		table.insert(keys, "shovel." .. shovel.id)
	end
	for _, pass in MonetizationConfig.passes do
		table.insert(keys, "pass." .. pass.key)
		table.insert(keys, "pass." .. pass.key .. ".desc")
	end
	for _, product in MonetizationConfig.products do
		table.insert(keys, "product." .. product.key)
		table.insert(keys, "product." .. product.key .. ".desc")
	end
	for _, template in RetentionConfig.QUEST_TEMPLATES do
		table.insert(keys, "quest." .. template.kind)
	end
	return keys
end

local function testInterfaceKeys()
	section("Textes d'interface : mêmes clés en français et en anglais")
	local frKeys = Locale.interfaceKeys("fr")
	local missingEn = {}
	local badMarkers = {}
	for _, key in frKeys do
		if not Locale.has("en", key) then
			table.insert(missingEn, key)
		elseif placeholders(Locale.raw("fr", key)) ~= placeholders(Locale.raw("en", key)) then
			table.insert(badMarkers, key)
		end
	end
	check(
		string.format("%d clés françaises, toutes traduites", #frKeys),
		#missingEn == 0,
		table.concat(missingEn, ", ")
	)
	check("marqueurs %s / %d identiques et dans le même ordre", #badMarkers == 0, table.concat(badMarkers, ", "))

	-- Une clé anglaise sans équivalent français serait un texte que le français n'afficherait pas.
	local orphans = {}
	for _, key in Locale.interfaceKeys("en") do
		local isData = string.match(key, "^(%a+)%.") ~= nil
			and (
				string.sub(key, 1, 5) == "item."
				or string.sub(key, 1, 7) == "rarity."
				or string.sub(key, 1, 9) == "mutation."
				or string.sub(key, 1, 8) == "stratum."
				or string.sub(key, 1, 7) == "shovel."
				or string.sub(key, 1, 5) == "pass."
				or string.sub(key, 1, 8) == "product."
			)
		if not Locale.has("fr", key) and not isData then
			table.insert(orphans, key)
		end
	end
	check("aucune clé anglaise orpheline", #orphans == 0, table.concat(orphans, ", "))
end

local function testDataNames()
	section("Noms des données : tous traduits en anglais")
	local keys = dataKeys()
	local missing = {}
	local sameAsKey = {}
	for _, key in keys do
		if not Locale.has("en", key) then
			table.insert(missing, key)
		end
		if not Locale.has("fr", key) then
			table.insert(sameAsKey, key)
		end
	end
	check(string.format("%d noms de données traduits en anglais", #keys), #missing == 0, table.concat(missing, ", "))
	check("chaque nom de donnée existe en français (configs)", #sameAsKey == 0, table.concat(sameAsKey, ", "))
	check("objet en anglais", Locale.tIn("en", "item.lost_sock") == "Lost Sock", Locale.tIn("en", "item.lost_sock"))
	check(
		"objet en français (config)",
		Locale.tIn("fr", "item.lost_sock") == "Chaussette Perdue",
		Locale.tIn("fr", "item.lost_sock")
	)
end

local function testLanguageChoice()
	section("Langue du joueur")
	check("fr-fr : français", Locale.languageFromLocaleId("fr-fr") == "fr")
	check("fr-ca : français", Locale.languageFromLocaleId("fr-ca") == "fr")
	check("FR : français", Locale.languageFromLocaleId("FR") == "fr")
	check("en-us : anglais", Locale.languageFromLocaleId("en-us") == "en")
	check("es-es : anglais (toute autre langue)", Locale.languageFromLocaleId("es-es") == "en")
	check("pt-br : anglais", Locale.languageFromLocaleId("pt-br") == "en")
	check("vide : anglais", Locale.languageFromLocaleId("") == "en")
	check("nil : anglais", Locale.languageFromLocaleId(nil) == "en")
	check("serveur : langue courante = français (source)", Locale.getLanguage() == "fr")
	check("nom du jeu en français", Locale.tIn("fr", "game.title") == "Creuse ou Crève")
	check("sous-titre anglais : Dig or Die", Locale.tIn("en", "game.subtitle") == "Dig or Die")
end

local function testFormatting()
	section("Formatage")
	check("texte simple", Locale.tIn("en", "hud.depth", 12) == "Depth: 12 m", Locale.tIn("en", "hud.depth", 12))
	local notice = Locale.text("notice.questDone", Locale.text("quest.DigCells", "40"))
	check(
		"LocText imbriqué (fr)",
		Locale.render(notice, "fr") == "Quête réussie : Creuse 40 cases",
		Locale.render(notice, "fr")
	)
	check(
		"LocText imbriqué (en)",
		Locale.render(notice, "en") == "Quest complete: Dig 40 tiles",
		Locale.render(notice, "en")
	)
	local tier = Locale.text("notice.indexTier", Locale.text("stratum.Clay.the"), 25)
	check(
		"couche avec article (fr)",
		Locale.render(tier, "fr") == "Index de l'Argile : 25 % trouvés !",
		Locale.render(tier, "fr")
	)
	check("couche sans article (en)", Locale.render(tier, "en") == "Clay Index: 25% found!", Locale.render(tier, "en"))
	check(
		"titre d'Index (fr)",
		Locale.tIn("fr", "title.index.Clay") == "Archéologue de l'Argile",
		Locale.tIn("fr", "title.index.Clay")
	)
	check(
		"titre d'Index (en)",
		Locale.tIn("en", "title.index.Clay") == "Clay Archaeologist",
		Locale.tIn("en", "title.index.Clay")
	)
	check(
		"nom de joueur gardé tel quel",
		Locale.tIn("en", "plot.owned", "Yardley") == "Yardley's plot",
		Locale.tIn("en", "plot.owned", "Yardley")
	)
	check("clé inconnue : la clé est affichée, sans erreur", Locale.tIn("en", "nope.missing") == "nope.missing")
	check(
		"argument manquant : gabarit affiché, sans erreur",
		Locale.tIn("en", "hud.depth") == Locale.raw("en", "hud.depth")
	)
	check("description avec % sans argument", string.find(Locale.tIn("fr", "pass.VIP.desc"), "10 %%", 1) ~= nil)
	Locale.setLanguage("fr")
	check("nombres en français : 12 345", Locale.number(12345) == "12 345", Locale.number(12345))
	Locale.setLanguage("en")
	check("nombres en anglais : 12,345", Locale.number(12345) == "12,345", Locale.number(12345))
	check("petit nombre sans séparateur", Locale.number(999) == "999", Locale.number(999))
	check("million", Locale.number(1234567) == "1,234,567", Locale.number(1234567))
	Locale.setLanguage(nil)
end

local function testBindings()
	section("Textes posés par le serveur sur les instances")
	local label = Instance.new("TextLabel")
	Locale.bind(label, "Text", Locale.text("plot.owned", "Yardley"))
	check("le serveur écrit le français", label.Text == "Parcelle de Yardley", label.Text)
	Locale.setLanguage("en")
	Locale.applyBindings(label)
	check("le client réécrit dans sa langue", label.Text == "Yardley's plot", label.Text)
	Locale.setLanguage(nil)
	local prompt = Instance.new("ProximityPrompt")
	Locale.bind(prompt, "ObjectText", Locale.text("world.chest"))
	Locale.bind(prompt, "ActionText", Locale.text("world.pick"))
	Locale.setLanguage("en")
	Locale.applyBindings(prompt)
	check(
		"prompt : deux propriétés traduites",
		prompt.ObjectText == "Chest" and prompt.ActionText == "Pick lock",
		prompt.ObjectText .. " / " .. prompt.ActionText
	)
	Locale.setLanguage(nil)
	label:Destroy()
	prompt:Destroy()
end

function LocaleRules.run(): (string, number, number)
	results = {}
	passed = 0
	failed = 0
	testInterfaceKeys()
	testDataNames()
	testLanguageChoice()
	testFormatting()
	testBindings()
	local report =
		string.format("[LocaleRules] %d réussis, %d échoués\n%s", passed, failed, table.concat(results, "\n"))
	print(report)
	return report, passed, failed
end

return LocaleRules
