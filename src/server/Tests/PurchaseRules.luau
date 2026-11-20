--!strict
-- Tests du traitement des achats (plan semaine 4, sections 2 et 5), sans vrais joueurs ni vrais reçus.
-- Lancement dans Studio (côté serveur, pendant un playtest) :
--   require(game.ServerScriptService.Server.Tests.PurchaseRules).run()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local PurchaseService = require(script.Parent.Parent.Services.PurchaseService)
local LootService = require(script.Parent.Parent.Services.LootService)

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

local function testLuckFormula()
	table.insert(results, "Formule unique de la chance et plafond x10 (section 4)")
	local function luck(shovel: number, pass: boolean, potion: boolean, event: boolean, group: boolean): number
		return LootService.computeLuckMultiplier({
			shovelBonus = shovel,
			luckPass = pass,
			potion = potion,
			serverEvent = event,
			groupMember = group,
		})
	end
	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 1e-9
	end
	check("sans bonus : x1", near(luck(0, false, false, false, false), 1))
	check("pelle en acier : x1,15", near(luck(15, false, false, false, false), 1.15))
	check("pelle en fer + Chance x2 : x2,1", near(luck(5, true, false, false, false), 2.1))
	check("Chance x2 + potion : x6", near(luck(0, true, true, false, false), 6))
	local all = luck(15, true, true, true, true)
	check("pass + potion + événement + acier : plafonné à x10 (x13,8 sans plafond)", near(all, 10), tostring(all))
	local worst = 0
	for _, shovel in { 0, 5, 15, 30, 60, 500 } do
		for mask = 0, 15 do
			local value = luck(shovel, mask % 2 == 1, mask // 2 % 2 == 1, mask // 4 % 2 == 1, mask // 8 % 2 == 1)
			worst = math.max(worst, value)
		end
	end
	check("aucune combinaison ne dépasse x10", worst <= MonetizationConfig.LUCK_CAP, tostring(worst))
	local groupOn = luck(0, false, false, false, true)
	check(
		"groupe : x1,05 si configuré, sinon x1",
		if MonetizationConfig.GROUP_ID == 0 then near(groupOn, 1) else near(groupOn, 1.05),
		tostring(groupOn)
	)

	-- Le tirage applique bien le multiplicateur, et ne dépasse jamais le plafond même si on lui en donne plus.
	local function shareBoosted(multiplier: number, count: number): number
		local boosted = 0
		for _ = 1, count do
			local rarity = LootService.rollRarity(multiplier)
			if rarity == "Rare" or rarity == "Epic" or rarity == "Legendary" or rarity == "Secret" then
				boosted += 1
			end
		end
		return boosted / count
	end
	local count = 40000
	-- Poids boostés : 15 % à x1. À x10 : 150 / (85 + 150) = 63,8 %.
	local atCap = shareBoosted(10, count)
	local overCap = shareBoosted(1000, count)
	check(
		string.format("tirage à x10 : %.1f %% de Rare ou mieux (attendu 63,8 %%)", atCap * 100),
		math.abs(atCap - 0.638) < 0.02
	)
	check(
		string.format("tirage avec x1000 demandé : ramené à x10 (%.1f %%)", overCap * 100),
		math.abs(overCap - 0.638) < 0.02
	)
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
	testLuckFormula()
	local report =
		string.format("[PurchaseRules] %d réussis, %d échoués\n%s", passed, failed, table.concat(results, "\n"))
	print(report)
	return report, passed, failed
end

return PurchaseRules
