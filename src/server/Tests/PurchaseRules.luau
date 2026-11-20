--!strict
-- Tests du traitement des achats (plan semaine 4, sections 2 et 5), sans vrais joueurs ni vrais reçus.
-- Lancement dans Studio (côté serveur, pendant un playtest) :
--   require(game.ServerScriptService.Server.Tests.PurchaseRules).run()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local PurchaseService = require(script.Parent.Parent.Services.PurchaseService)

local GRANTED = Enum.ProductPurchaseDecision.PurchaseGranted
local NOT_YET = Enum.ProductPurchaseDecision.NotProcessedYet
local PLAYER_ID = -1
local POTION_ID = 1001

local PurchaseRules = {}

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

local function newData(): any
	return { processedPurchases = {}, potions = 0 }
end

-- Contexte de test : un seul produit connu (POTION_ID), octroi qui ajoute une potion.
local function context(data: any?, overrides: { [string]: any }?): PurchaseService.ReceiptContext
	local ctx: { [string]: any } = {
		resolveProduct = function(productId: number)
			return if productId == POTION_ID then "LuckPotion" else nil
		end,
		waitForData = function(_userId: number)
			return data
		end,
		grant = function(_key, _userId, profile)
			profile.potions += 1
			return true
		end,
	}
	for key, value in overrides or {} do
		ctx[key] = value
	end
	return ctx :: any
end

local function receipt(purchaseId: string, productId: number?): PurchaseService.Receipt
	return { PlayerId = PLAYER_ID, ProductId = productId or POTION_ID, PurchaseId = purchaseId }
end

local function testIdempotence()
	table.insert(results, "Idempotence : un reçu n'est accordé qu'une fois")
	local data = newData()
	local first = PurchaseService.handleReceipt(receipt("R1"), context(data))
	local second = PurchaseService.handleReceipt(receipt("R1"), context(data))
	check("1er envoi : PurchaseGranted", first == GRANTED)
	check("2e envoi du même reçu : PurchaseGranted", second == GRANTED)
	check("l'effet n'est accordé qu'une seule fois", data.potions == 1, data.potions .. " potions")
	check("le PurchaseId est enregistré une seule fois", #data.processedPurchases == 1)
	PurchaseService.handleReceipt(receipt("R2"), context(data))
	check("un autre reçu est bien accordé", data.potions == 2)
end

local function testProfileNotLoaded()
	table.insert(results, "Profil pas encore chargé")
	local data = newData()
	local decision = PurchaseService.handleReceipt(receipt("R1"), context(nil))
	check("profil absent : NotProcessedYet", decision == NOT_YET)
	check("rien n'est accordé ni enregistré", data.potions == 0 and #data.processedPurchases == 0)

	-- Le profil arrive pendant l'attente : accordé dès qu'il est prêt.
	local ready = false
	task.delay(0.3, function()
		ready = true
	end)
	local waited = context(data, {
		waitForData = function(_userId: number)
			local deadline = os.clock() + 2
			while not ready and os.clock() < deadline do
				task.wait(0.05)
			end
			return if ready then data else nil
		end,
	})
	local started = os.clock()
	local late = PurchaseService.handleReceipt(receipt("R1"), waited)
	check(
		"achat pendant le chargement : accordé dès que le profil est prêt",
		late == GRANTED and data.potions == 1,
		string.format("%s après %.2f s", tostring(late), os.clock() - started)
	)
end

local function testGrantError()
	table.insert(results, "Erreur ou refus pendant l'octroi")
	local data = newData()
	local failing = context(data, {
		grant = function()
			error("panne simulée")
		end,
	})
	local decision = PurchaseService.handleReceipt(receipt("R1"), failing)
	check("erreur pendant l'octroi : NotProcessedYet", decision == NOT_YET)
	check("le PurchaseId n'est pas enregistré (Roblox réessaiera)", #data.processedPurchases == 0)
	local retry = PurchaseService.handleReceipt(receipt("R1"), context(data))
	check("le nouvel essai accorde l'effet une fois", retry == GRANTED and data.potions == 1)

	local refusing = context(newData(), {
		grant = function()
			return false
		end,
	})
	check("octroi refusé : NotProcessedYet", PurchaseService.handleReceipt(receipt("R2"), refusing) == NOT_YET)
end

local function testUnknownProduct()
	table.insert(results, "Produit inconnu")
	local data = newData()
	local decision = PurchaseService.handleReceipt(receipt("R1", 999999), context(data))
	check("produit inconnu : NotProcessedYet, rien accordé", decision == NOT_YET and data.potions == 0)
end

local function testHistoryLimit()
	table.insert(results, "Historique des 100 derniers achats")
	local data = newData()
	local total = MonetizationConfig.PROCESSED_PURCHASES_KEPT + 5
	for i = 1, total do
		PurchaseService.handleReceipt(receipt("R" .. i), context(data))
	end
	check("la liste garde 100 reçus", #data.processedPurchases == MonetizationConfig.PROCESSED_PURCHASES_KEPT)
	check("les plus anciens sortent en premier", data.processedPurchases[1] == "R6")
	PurchaseService.handleReceipt(receipt("R" .. total), context(data))
	check("un reçu récent renvoyé n'est pas accordé deux fois", data.potions == total)
end

local function testRevengeCompensation()
	table.insert(results, "Revanche et compensation")
	check("conditions remplies : téléportation", PurchaseService.resolveRevenge(true) == "Revenge")
	check(
		"conditions plus remplies : Potion de chance à la place",
		PurchaseService.resolveRevenge(false) == "LuckPotionCompensation"
	)
	local potion = MonetizationConfig.productByKey.LuckPotion
	local revenge = MonetizationConfig.productByKey.Revenge
	check(
		"la compensation vaut au moins le prix payé",
		potion.price >= revenge.price,
		potion.price .. " contre " .. revenge.price
	)
end

local function testCatalogPrinciples()
	table.insert(results, "Principes du catalogue (section 2)")
	local sellsItem = false
	for _, product in MonetizationConfig.products do
		sellsItem = sellsItem or (product :: any).itemId ~= nil or (product :: any).rarity ~= nil
	end
	check("aucun produit ne vend un objet", not sellsItem)
	local luckFlagged = MonetizationConfig.productByKey.LuckPotion.isLuck
		and MonetizationConfig.productByKey.ServerLuckEvent.isLuck
		and MonetizationConfig.passByKey.LuckX2.isLuck
	check("les produits de chance sont marqués (masqués si restreints)", luckFlagged)
end

function PurchaseRules.run(): (string, number, number)
	results = {}
	passed = 0
	failed = 0
	testIdempotence()
	testProfileNotLoaded()
	testGrantError()
	testUnknownProduct()
	testHistoryLimit()
	testRevengeCompensation()
	testCatalogPrinciples()
	local report =
		string.format("[PurchaseRules] %d réussis, %d échoués\n%s", passed, failed, table.concat(results, "\n"))
	print(report)
	return report, passed, failed
end

return PurchaseRules
