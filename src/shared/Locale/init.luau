--!strict
-- Module de traduction unique (plan semaine 5, section 11). Le français est la langue source, l'anglais
-- la traduction ; toute autre langue Roblox reçoit l'anglais.
--
-- Deux sortes de clés :
--   * textes d'interface : dans `fr.luau` et `en.luau` (mêmes clés des deux côtés) ;
--   * noms des données (objets, raretés, mutations, couches, pelles, passes, produits) : le français vient
--     des configs (`Items.luau`, `Rarities.luau`...), l'anglais de `en.luau`. Clés : "item.<id>",
--     "rarity.<id>", "mutation.<id>", "stratum.<id>", "stratum.<id>.the" (avec article), "shovel.<id>",
--     "pass.<clé>", "pass.<clé>.desc", "product.<clé>", "product.<clé>.desc", "title.index.<id de couche>".
--
-- Un texte localisable qui voyage (serveur -> client, attribut) est un LocText : { key, args }. Un argument
-- peut être un nombre, une chaîne affichée telle quelle (nom de joueur), ou un LocText traduit à son tour.
--
-- Textes posés par le serveur sur des instances visibles par tous (panneaux, prompts, nom du garde...) :
-- `Locale.bind` écrit le français et la clé en attribut ; le LocaleController de chaque client réécrit le
-- texte dans sa langue, localement.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = script.Parent:WaitForChild("Config")
local Items = require(Config.Items)
local Rarities = require(Config.Rarities)
local Mutations = require(Config.Mutations)
local Strata = require(Config.Strata)
local Shovels = require(Config.Shovels)
local MonetizationConfig = require(Config.MonetizationConfig)
local StudioTestMode = require(Config.StudioTestMode)

local fr = require(script.fr)
local en = require(script.en)

export type Language = "fr" | "en"
export type LocText = { key: string, args: { any }? }

local SOURCE: Language = "fr"
local BIND_TAG = "Localized"
local BIND_PREFIX = "Loc_"
local TITLE_INDEX_PREFIX = "title.index."

local Locale = {}

Locale.SOURCE = SOURCE
Locale.BIND_TAG = BIND_TAG
Locale.BIND_PREFIX = BIND_PREFIX
Locale.LANGUAGES = table.freeze({ "fr", "en" }) :: { Language }

local dictionaries: { [Language]: { [string]: string } } = { fr = fr, en = en }

------------------------------------------------------------------------------------------------
-- Langue
------------------------------------------------------------------------------------------------

-- "fr-fr", "fr-ca", "fr" -> français ; tout le reste -> anglais.
function Locale.languageFromLocaleId(localeId: string?): Language
	if typeof(localeId) == "string" and string.lower(string.sub(localeId, 1, 2)) == "fr" then
		return "fr"
	end
	return "en"
end

local function forcedLanguage(): Language?
	local forced = StudioTestMode.FORCED_LANGUAGE
	if RunService:IsStudio() and (forced == "fr" or forced == "en") then
		return forced
	end
	return nil
end

-- Langue d'un joueur, d'après la langue de son compte Roblox (lisible côté serveur et client).
function Locale.languageOf(player: Player): Language
	return forcedLanguage() or Locale.languageFromLocaleId(player.LocaleId)
end

local currentLanguage: Language? = nil

-- Langue courante : celle du joueur local côté client, le français côté serveur (logs, valeurs par défaut).
function Locale.getLanguage(): Language
	if currentLanguage ~= nil then
		return currentLanguage
	end
	local language: Language = SOURCE
	if RunService:IsClient() and Players.LocalPlayer ~= nil then
		language = Locale.languageOf(Players.LocalPlayer)
	end
	currentLanguage = language
	return language
end

-- Pour les tests uniquement : force la langue courante (nil = recalculer).
function Locale.setLanguage(language: Language?)
	currentLanguage = language
end

------------------------------------------------------------------------------------------------
-- Recherche des textes
------------------------------------------------------------------------------------------------

-- Nom français d'une donnée, lu dans les configs (nil si la clé n'est pas un nom de donnée).
local function sourceName(key: string): string?
	local kind, id, field = string.match(key, "^(%a+)%.([%w_]+)%.?(%a*)$")
	if kind == nil or id == nil then
		return nil
	end
	if kind == "item" and field == "" then
		local item = Items.byId[id]
		return if item ~= nil then item.name else nil
	elseif kind == "rarity" and field == "" then
		local rarity = Rarities.byId[id :: any]
		return if rarity ~= nil then rarity.displayName else nil
	elseif kind == "mutation" and field == "" then
		local mutation = Mutations.byId[id :: any]
		return if mutation ~= nil then mutation.displayName else nil
	elseif kind == "stratum" then
		local stratum = Strata.byId[id :: any]
		if stratum == nil then
			return nil
		end
		return if field == "the" then stratum.nameWithArticle elseif field == "" then stratum.name else nil
	elseif kind == "shovel" and field == "" then
		local shovel = Shovels.byId[id :: any]
		return if shovel ~= nil then shovel.name else nil
	elseif kind == "pass" or kind == "product" then
		local def: any = if kind == "pass"
			then MonetizationConfig.passByKey[id]
			else MonetizationConfig.productByKey[id]
		if def == nil then
			return nil
		end
		return if field == "desc" then def.description elseif field == "" then def.name else nil
	end
	return nil
end

local lookup: (language: Language, key: string) -> string?

lookup = function(language: Language, key: string): string?
	local own = dictionaries[language][key]
	if own ~= nil then
		return own
	end
	-- Titre d'Index : "Archéologue de l'Argile" / "Clay Archaeologist", construit à partir de la couche.
	if string.sub(key, 1, #TITLE_INDEX_PREFIX) == TITLE_INDEX_PREFIX then
		local template = lookup(language, "title.index")
		local stratum = lookup(language, "stratum." .. string.sub(key, #TITLE_INDEX_PREFIX + 1) .. ".the")
		if template ~= nil and stratum ~= nil then
			return string.format(template, stratum)
		end
		return nil
	end
	if language == SOURCE then
		return sourceName(key)
	end
	-- Traduction manquante : on retombe sur le français (le test LocaleRules empêche ce cas).
	return lookup(SOURCE, key)
end

-- Vrai si la clé existe dans cette langue (sans repli sur le français).
function Locale.has(language: Language, key: string): boolean
	if dictionaries[language][key] ~= nil then
		return true
	end
	return language == SOURCE and sourceName(key) ~= nil
end

-- Clés des textes d'interface d'une langue (pour les tests).
function Locale.interfaceKeys(language: Language): { string }
	local keys = {}
	for key in dictionaries[language] do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

-- Texte brut (gabarit non formaté) d'une clé, dans une langue.
function Locale.raw(language: Language, key: string): string
	return lookup(language, key) or key
end

------------------------------------------------------------------------------------------------
-- Formatage
------------------------------------------------------------------------------------------------

local renderIn: (language: Language, text: LocText) -> string

local function formatIn(language: Language, key: string, args: { any }?): string
	local template = lookup(language, key)
	if template == nil then
		return key
	end
	if args == nil or #args == 0 then
		return template
	end
	local resolved = table.create(#args)
	for index, arg in args do
		if typeof(arg) == "table" and typeof(arg.key) == "string" then
			resolved[index] = renderIn(language, arg :: LocText)
		else
			resolved[index] = arg
		end
	end
	local ok, result = pcall(string.format, template, table.unpack(resolved))
	return if ok then result else template
end

renderIn = function(language: Language, text: LocText): string
	return formatIn(language, text.key, text.args)
end

-- Texte traduit dans la langue courante : Locale.t("hud.depth", 12).
function Locale.t(key: string, ...: any): string
	return formatIn(Locale.getLanguage(), key, { ... })
end

-- Texte traduit dans une langue donnée.
function Locale.tIn(language: Language, key: string, ...: any): string
	return formatIn(language, key, { ... })
end

-- LocText traduit dans la langue courante (ou une langue donnée).
function Locale.render(text: LocText, language: Language?): string
	return renderIn(language or Locale.getLanguage(), text)
end

-- Vrai si la valeur reçue (réseau, attribut) a la forme d'un LocText.
function Locale.isLocText(value: unknown): boolean
	return typeof(value) == "table" and typeof((value :: any).key) == "string"
end

-- Construit un LocText.
function Locale.text(key: string, ...: any): LocText
	local args = { ... }
	return if #args > 0 then { key = key, args = args } else { key = key }
end

------------------------------------------------------------------------------------------------
-- Raccourcis pour les données
------------------------------------------------------------------------------------------------

function Locale.item(id: string): string
	return Locale.t("item." .. id)
end

function Locale.rarity(id: string): string
	return Locale.t("rarity." .. id)
end

function Locale.mutation(id: string): string
	return Locale.t("mutation." .. id)
end

function Locale.stratum(id: string): string
	return Locale.t("stratum." .. id)
end

function Locale.shovel(id: string): string
	return Locale.t("shovel." .. id)
end

-- 12345 -> "12 345" en français, "12,345" en anglais.
function Locale.number(value: number): string
	local text = tostring(math.floor(value))
	local separator = Locale.t("format.thousands")
	local formatted = text:reverse():gsub("(%d%d%d)", "%1" .. separator):reverse()
	if string.sub(formatted, 1, #separator) == separator then
		formatted = string.sub(formatted, #separator + 1)
	end
	return formatted
end

------------------------------------------------------------------------------------------------
-- Textes posés par le serveur sur des instances (traduits par chaque client)
------------------------------------------------------------------------------------------------

-- Serveur : écrit le texte français dans `property` et la clé dans un attribut, que le LocaleController
-- de chaque client traduit localement. Rappeler bind pour changer le texte.
function Locale.bind(instance: Instance, property: string, text: LocText)
	(instance :: any)[property] = renderIn(SOURCE, text)
	instance:SetAttribute(BIND_PREFIX .. property, HttpService:JSONEncode(text))
	CollectionService:AddTag(instance, BIND_TAG)
end

-- Client : réécrit toutes les propriétés liées d'une instance dans la langue courante.
function Locale.applyBindings(instance: Instance)
	for name, value in instance:GetAttributes() do
		if string.sub(name, 1, #BIND_PREFIX) == BIND_PREFIX and typeof(value) == "string" then
			local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value)
			if ok and Locale.isLocText(decoded) then
				pcall(function()
					(instance :: any)[string.sub(name, #BIND_PREFIX + 1)] = Locale.render(decoded :: LocText)
				end)
			end
		end
	end
end

return Locale
