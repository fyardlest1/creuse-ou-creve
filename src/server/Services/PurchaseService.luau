--!strict
-- Achats Robux (plan semaine 4, sections 2 et 5). Un seul ProcessReceipt ; une table associe chaque
-- produit à la fonction qui accorde son effet ; propriété des game passes vérifiée par le serveur.
--
-- Le cœur (handleReceipt) est pur : il reçoit ses dépendances, pour être testé par Tests/PurchaseRules.
-- Ordre strict : profil chargé (sinon NotProcessedYet), reçu déjà traité (PurchaseGranted sans rien
-- accorder), octroi (erreur ou refus : NotProcessedYet), enregistrement du PurchaseId, PurchaseGranted.
--
-- Dans Studio, un produit ou un pass dont l'identifiant vaut 0 est simulé : la demande passe par le même
-- traitement qu'un vrai reçu, avec un faux PurchaseId. En ligne, un identifiant à 0 est indisponible.

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Remotes = require(Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)

type PassKey = MonetizationConfig.PassKey
type ProductKey = MonetizationConfig.ProductKey

export type Receipt = { PlayerId: number, ProductId: number, PurchaseId: string }

-- Dépendances du cœur, fournies par le service (ou par les tests).
export type ReceiptContext = {
	resolveProduct: (productId: number) -> ProductKey?,
	waitForData: (userId: number) -> any?, -- peut attendre le chargement du profil ; nil = pas prêt
	grant: (productKey: ProductKey, userId: number, data: any) -> boolean,
	onGranted: ((productKey: ProductKey, userId: number) -> ())?,
}

-- Accorde l'effet d'un produit ; retourne false si l'effet ne peut pas être accordé (Roblox réessaiera).
export type GrantHandler = (player: Player, data: any) -> boolean
-- Peut-on afficher cet achat maintenant ? Retourne nil si oui, sinon la raison affichée.
export type Condition = (player: Player) -> string?

local IS_STUDIO = RunService:IsStudio()
local PROFILE_WAIT_TIMEOUT = 30 -- secondes d'attente du profil dans ProcessReceipt
local PROFILE_WAIT_STEP = 0.25
local TEXT_UNAVAILABLE = "Bientôt disponible"
local TEXT_RESTRICTED = "Indisponible dans ton pays"

local PurchaseService = {}

------------------------------------------------------------------------------------------------
-- Cœur pur
------------------------------------------------------------------------------------------------

local function isProcessed(data: any, purchaseId: string): boolean
	return table.find(data.processedPurchases, purchaseId) ~= nil
end

-- Garde les PROCESSED_PURCHASES_KEPT derniers PurchaseId (les plus anciens sortent en premier).
function PurchaseService.rememberPurchase(data: any, purchaseId: string)
	table.insert(data.processedPurchases, purchaseId)
	while #data.processedPurchases > MonetizationConfig.PROCESSED_PURCHASES_KEPT do
		table.remove(data.processedPurchases, 1)
	end
end

function PurchaseService.handleReceipt(receipt: Receipt, context: ReceiptContext): Enum.ProductPurchaseDecision
	local productKey = context.resolveProduct(receipt.ProductId)
	if productKey == nil then
		warn(
			string.format(
				"[PurchaseService] Produit inconnu %s (reçu %s) : non traité",
				tostring(receipt.ProductId),
				receipt.PurchaseId
			)
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = context.waitForData(receipt.PlayerId)
	if data == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if isProcessed(data, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- déjà accordé : rien de nouveau
	end
	local ok, granted = pcall(context.grant, productKey, receipt.PlayerId, data)
	if not ok then
		warn(string.format("[PurchaseService] Erreur pendant l'octroi de %s : %s", productKey, tostring(granted)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if granted ~= true then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	PurchaseService.rememberPurchase(data, receipt.PurchaseId)
	if context.onGranted ~= nil then
		context.onGranted(productKey, receipt.PlayerId)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Revanche : si les conditions ne sont plus remplies à la réception du paiement, le joueur reçoit une
-- Potion de chance (39 Robux, plus que les 29 de la Revanche) dans sa réserve.
function PurchaseService.resolveRevenge(canRevenge: boolean): "Revenge" | "LuckPotionCompensation"
	return if canRevenge then "Revenge" else "LuckPotionCompensation"
end

------------------------------------------------------------------------------------------------
-- Partie vivante
------------------------------------------------------------------------------------------------

local grantHandlers: { [ProductKey]: GrantHandler } = {}
local conditions: { [string]: Condition } = {} -- par clé de pass ou de produit
local ownedPasses: { [Player]: { [PassKey]: boolean } } = {}
local luckRestricted: { [Player]: boolean } = {}
local lastRequest: { [Player]: number } = {}
local passCallbacks: { (player: Player, key: PassKey) -> () } = {}

local function log(message: string)
	print("[PurchaseService] " .. message)
end

local function reject(player: Player, reason: string)
	if IS_STUDIO then
		log(string.format("Demande d'achat refusée (%s) : %s", player.Name, reason))
	end
end

-- Enregistre la fonction qui accorde l'effet d'un produit.
function PurchaseService.registerProduct(key: ProductKey, handler: GrantHandler)
	grantHandlers[key] = handler
end

-- Enregistre la condition d'affichage d'un pass ou d'un produit (principe 3).
function PurchaseService.registerCondition(key: string, condition: Condition)
	conditions[key] = condition
end

function PurchaseService.ownsPass(player: Player, key: PassKey): boolean
	local owned = ownedPasses[player]
	return owned ~= nil and owned[key] == true
end

-- Appelé quand un joueur obtient un pass (au chargement ou après un achat).
function PurchaseService.onPassOwned(callback: (player: Player, key: PassKey) -> ())
	table.insert(passCallbacks, callback)
	for player, owned in ownedPasses do
		for key in owned do
			task.spawn(callback, player, key)
		end
	end
end

local function publishPasses(player: Player)
	local keys = {}
	for key in ownedPasses[player] or {} do
		table.insert(keys, key)
	end
	table.sort(keys)
	player:SetAttribute("OwnedPasses", table.concat(keys, ","))
end

local function setPassOwned(player: Player, key: PassKey)
	local owned = ownedPasses[player]
	if owned == nil or owned[key] then
		return
	end
	owned[key] = true
	publishPasses(player)
	log(string.format("%s possède le pass %s", player.Name, key))
	for _, callback in passCallbacks do
		task.spawn(callback, player, key)
	end
end

-- Propriété des passes au chargement : UserOwnsGamePassAsync, avec réessais.
local function loadPasses(player: Player)
	ownedPasses[player] = ownedPasses[player] or {}
	for _, pass in MonetizationConfig.passes do
		if pass.id ~= 0 then
			for attempt = 1, MonetizationConfig.PASS_CHECK_RETRIES do
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
				end)
				if ok then
					if owns then
						setPassOwned(player, pass.key)
					end
					break
				elseif attempt < MonetizationConfig.PASS_CHECK_RETRIES then
					task.wait(MonetizationConfig.PASS_CHECK_RETRY_DELAY)
				else
					warn(
						string.format(
							"[PurchaseService] Propriété du pass %s inconnue pour %s",
							pass.key,
							player.Name
						)
					)
				end
			end
		end
	end
	publishPasses(player)
end

-- Objets aléatoires payants restreints dans le pays du joueur (principe 4) : produits de chance masqués.
local function loadPolicy(player: Player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	-- En cas d'erreur, on restreint par prudence.
	local restricted = not ok or (info :: any).ArePaidRandomItemsRestricted == true
	luckRestricted[player] = restricted
	player:SetAttribute("PaidRandomItemsRestricted", restricted)
end

function PurchaseService.isLuckRestricted(player: Player): boolean
	return luckRestricted[player] ~= false
end

-- Raison pour laquelle cet achat ne peut pas être affiché maintenant (nil si possible).
function PurchaseService.getBlockReason(player: Player, key: string): string?
	local pass = MonetizationConfig.passByKey[key]
	local product = MonetizationConfig.productByKey[key]
	local def: any = pass or product
	if def == nil then
		return TEXT_UNAVAILABLE
	end
	if def.isLuck and PurchaseService.isLuckRestricted(player) then
		return TEXT_RESTRICTED
	end
	if def.id == 0 and not IS_STUDIO then
		return TEXT_UNAVAILABLE
	end
	if product ~= nil and grantHandlers[product.key] == nil then
		return TEXT_UNAVAILABLE
	end
	local condition = conditions[key]
	return if condition ~= nil then condition(player) else nil
end

local function liveContext(simulatedKey: ProductKey?): ReceiptContext
	return {
		resolveProduct = function(productId: number): ProductKey?
			return simulatedKey or MonetizationConfig.productKeyById[productId]
		end,
		waitForData = function(userId: number): any?
			local deadline = os.clock() + PROFILE_WAIT_TIMEOUT
			while true do
				local player = Players:GetPlayerByUserId(userId)
				if player == nil then
					return nil -- le joueur est parti : Roblox réessaiera à son retour
				end
				local data = PlayerDataService.getData(player)
				if data ~= nil then
					return data
				end
				if os.clock() > deadline then
					return nil
				end
				task.wait(PROFILE_WAIT_STEP)
			end
		end,
		grant = function(productKey: ProductKey, userId: number, data: any): boolean
			local player = Players:GetPlayerByUserId(userId)
			local handler = grantHandlers[productKey]
			if player == nil or handler == nil then
				return false
			end
			return handler(player, data)
		end,
		onGranted = function(productKey: ProductKey, userId: number)
			local player = Players:GetPlayerByUserId(userId)
			local product = MonetizationConfig.productByKey[productKey]
			if player ~= nil then
				PlayerDataService.refreshAttributes(player)
				pcall(function()
					AnalyticsService:LogCustomEvent(
						player,
						MonetizationConfig.ANALYTICS_PURCHASE_EVENT,
						product.price,
						{ [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = productKey }
					)
				end)
				log(string.format("%s : achat accordé (%s)", player.Name, productKey))
			end
		end,
	}
end

local function processReceipt(receipt: Receipt): Enum.ProductPurchaseDecision
	return PurchaseService.handleReceipt(receipt, liveContext(nil))
end

-- Studio seulement : simule l'achat d'un produit par le même traitement qu'un vrai reçu.
function PurchaseService.simulateProductPurchase(
	player: Player,
	key: ProductKey,
	purchaseId: string?
): Enum.ProductPurchaseDecision?
	if not IS_STUDIO then
		warn("[PurchaseService] Achat simulé réservé à Studio")
		return nil
	end
	local receipt: Receipt = {
		PlayerId = player.UserId,
		ProductId = MonetizationConfig.productByKey[key].id,
		PurchaseId = purchaseId or ("STUDIO-" .. HttpService:GenerateGUID(false)),
	}
	return PurchaseService.handleReceipt(receipt, liveContext(key))
end

-- Studio seulement : simule l'achat d'un game pass.
function PurchaseService.simulatePassPurchase(player: Player, key: PassKey)
	if not IS_STUDIO then
		warn("[PurchaseService] Achat simulé réservé à Studio")
		return
	end
	setPassOwned(player, key)
end

-- Le client demande un achat ; le serveur vérifie les conditions avant de l'afficher (principe 3).
local function onPurchaseRequest(player: Player, key: unknown)
	if typeof(key) ~= "string" or #key > 64 then
		reject(player, "clé invalide")
		return
	end
	local now = os.clock()
	local last = lastRequest[player]
	if last ~= nil and now - last < MonetizationConfig.PURCHASE_REQUEST_COOLDOWN then
		reject(player, "cadence trop rapide")
		return
	end
	lastRequest[player] = now

	local reason = PurchaseService.getBlockReason(player, key)
	if reason ~= nil then
		reject(player, key .. " : " .. reason)
		return
	end
	local pass = MonetizationConfig.passByKey[key]
	if pass ~= nil then
		if PurchaseService.ownsPass(player, pass.key) then
			reject(player, "pass déjà possédé " .. key)
		elseif pass.id == 0 then
			PurchaseService.simulatePassPurchase(player, pass.key)
		else
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end
		return
	end
	local product = MonetizationConfig.productByKey[key]
	if product.id == 0 then
		PurchaseService.simulateProductPurchase(player, product.key)
	else
		MarketplaceService:PromptProductPurchase(player, product.id)
	end
end

function PurchaseService.init() end

function PurchaseService.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			local key = MonetizationConfig.passKeyById[passId]
			if purchased and key ~= nil then
				setPassOwned(player, key)
			end
		end
	)
	Remotes.get(Remotes.Names.PurchaseRequest).OnServerEvent:Connect(onPurchaseRequest)
	PlayerDataService.onLoaded(function(player: Player)
		task.spawn(loadPolicy, player)
		loadPasses(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		ownedPasses[player] = nil
		luckRestricted[player] = nil
		lastRequest[player] = nil
	end)
end

return PurchaseService
