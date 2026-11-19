--!strict
-- Pièces : lecture, gain, dépense, vente au Marchand, classement du serveur et analytique.
-- Toute variation de Pièces passe par addCoins ou trySpend.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local Remotes = require(Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local WorldService = require(script.Parent.WorldService)

local LEADERSTATS_NAME = "leaderstats" -- nom imposé par Roblox
local SKU_SELL_ALL = "SellAll"
local SKU_SELL_SELECTED = "SellSelected"
local IS_STUDIO = RunService:IsStudio()

local EconomyService = {}

local lastSellTime: { [Player]: number } = {}
local sellResultRemote: RemoteEvent

-- Les requêtes invalides sont ignorées, et loggées en Studio seulement.
local function reject(player: Player, reason: string)
	if IS_STUDIO then
		print(string.format("[EconomyService] Vente refusée (%s) : %s", player.Name, reason))
	end
end

local function getCharacterPosition(player: Player): Vector3?
	local character = player.Character
	if character == nil then
		return nil
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil
	end
	return rootPart.Position
end

-- Vérifie la forme du payload. Retourne la liste d'uids à vendre (sans doublon), "all", ou nil + raison.
local function parseSellRequest(payload: unknown): (({ string } | "all")?, string?)
	if typeof(payload) ~= "table" then
		return nil, "payload invalide"
	end
	local request = payload :: { [any]: any }
	if request.all == true then
		return "all", nil
	end
	local uids = request.uids
	if typeof(uids) ~= "table" then
		return nil, "uids manquants"
	end
	local list: { string } = {}
	local seen: { [string]: boolean } = {}
	for key, uid in uids do
		if typeof(key) ~= "number" or #list >= PlayerConfig.INVENTORY_LIMIT then
			return nil, "liste d'uids invalide"
		end
		if typeof(uid) ~= "string" or #uid == 0 or #uid > EconomyConfig.UID_MAX_LENGTH then
			return nil, "uid invalide"
		end
		if seen[uid] then
			return nil, "uid en double " .. uid
		end
		seen[uid] = true
		table.insert(list, uid)
	end
	if #list == 0 then
		return nil, "liste vide"
	end
	return list, nil
end

local function isValidAmount(amount: number): boolean
	return amount == amount and amount > 0 and amount % 1 == 0 and amount < math.huge
end

-- L'analytique ne doit jamais bloquer une transaction.
local function logEconomyEvent(
	player: Player,
	flowType: Enum.AnalyticsEconomyFlowType,
	amount: number,
	endingBalance: number,
	reason: Types.EconomyReason,
	itemSku: string?
)
	local ok, err = pcall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			flowType,
			EconomyConfig.ANALYTICS_CURRENCY,
			amount,
			endingBalance,
			EconomyConfig.ANALYTICS_TRANSACTION_TYPES[reason],
			itemSku or reason
		)
	end)
	if not ok then
		warn("[EconomyService] Analytique en échec : " .. tostring(err))
	end
end

-- Le classement recopie les attributs écrits par PlayerDataService.
local function createLeaderstats(player: Player)
	if player:FindFirstChild(LEADERSTATS_NAME) ~= nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = LEADERSTATS_NAME

	local coins = Instance.new("IntValue")
	coins.Name = EconomyConfig.LEADERSTAT_COINS
	coins.Parent = folder

	local depth = Instance.new("IntValue")
	depth.Name = EconomyConfig.LEADERSTAT_DEPTH
	depth.Parent = folder

	local function sync()
		local coinsValue = player:GetAttribute("Coins")
		local depthValue = player:GetAttribute("Depth")
		coins.Value = if typeof(coinsValue) == "number" then coinsValue else 0
		depth.Value = if typeof(depthValue) == "number" then depthValue else 0
	end
	player:GetAttributeChangedSignal("Coins"):Connect(sync)
	player:GetAttributeChangedSignal("Depth"):Connect(sync)
	sync()
	folder.Parent = player
end

function EconomyService.getCoins(player: Player): number
	local data = PlayerDataService.getData(player)
	return if data ~= nil then data.coins else 0
end

-- Ajoute des Pièces (montant entier positif). Retourne false si le joueur n'est pas chargé.
function EconomyService.addCoins(player: Player, amount: number, reason: Types.EconomyReason, itemSku: string?): boolean
	local data = PlayerDataService.getData(player)
	if data == nil or not isValidAmount(amount) then
		return false
	end
	data.coins += amount
	data.stats.totalCoinsEarned += amount
	PlayerDataService.refreshAttributes(player)
	logEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Source, amount, data.coins, reason, itemSku)
	return true
end

-- Retire des Pièces si le solde suffit. Vérification et retrait se font sans yield entre les deux.
function EconomyService.trySpend(player: Player, amount: number, reason: Types.EconomyReason, itemSku: string?): boolean
	local data = PlayerDataService.getData(player)
	if data == nil or not isValidAmount(amount) or data.coins < amount then
		return false
	end
	data.coins -= amount
	PlayerDataService.refreshAttributes(player)
	logEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Sink, amount, data.coins, reason, itemSku)
	return true
end

-- Vend des objets du coffre. Les objets sont retirés et les Pièces créditées dans la même opération,
-- sans yield entre les deux : un objet ne peut jamais être vendu deux fois.
-- Les favoris ne sont jamais vendus : refusés à l'unité, épargnés par « Tout vendre ».
local function onSellRequest(player: Player, payload: unknown)
	local selection, parseError = parseSellRequest(payload)
	if selection == nil then
		reject(player, parseError or "payload invalide")
		return
	end

	local data = PlayerDataService.getData(player)
	if data == nil then
		reject(player, "données non chargées")
		return
	end

	local position = getCharacterPosition(player)
	if
		position == nil
		or (position - WorldService.getMerchantPosition()).Magnitude > EconomyConfig.MERCHANT_MAX_DISTANCE
	then
		reject(player, "trop loin du Marchand")
		return
	end

	local now = os.clock()
	local last = lastSellTime[player]
	if last ~= nil and now - last < EconomyConfig.SELL_COOLDOWN then
		reject(player, "cadence trop rapide")
		return
	end
	lastSellTime[player] = now

	local sellAll = selection == "all"
	local wanted: { [string]: boolean } = {}
	if not sellAll then
		for _, uid in selection :: { string } do
			wanted[uid] = true
		end
	end

	-- Construit le coffre restant. Une vente à l'unité est refusée en bloc si un uid manque ou est favori.
	local kept: { Types.ItemInstance } = {}
	local soldCount = 0
	local total = 0
	for _, item in data.inventory do
		local selected = if sellAll then not item.favorite else wanted[item.uid] == true
		if selected and item.favorite then
			reject(player, "favori " .. item.uid)
			return
		end
		if selected then
			soldCount += 1
			total += item.value
			wanted[item.uid] = nil
		else
			table.insert(kept, item)
		end
	end
	if not sellAll and next(wanted) ~= nil then
		reject(player, "uid absent du coffre " .. tostring(next(wanted)))
		return
	end

	if soldCount > 0 then
		-- Crédit d'abord : s'il échoue, le coffre n'est pas touché. Aucun yield jusqu'au retrait.
		if not EconomyService.addCoins(player, total, "Sell", if sellAll then SKU_SELL_ALL else SKU_SELL_SELECTED) then
			reject(player, "crédit impossible (" .. total .. ")")
			return
		end
		data.inventory = kept
		data.stats.itemsSold += soldCount
		PlayerDataService.refreshAttributes(player)
		PlayerDataService.pushInventory(player)
		print(string.format("[EconomyService] %s vend %d objet(s) pour %d Pièces", player.Name, soldCount, total))
	end

	local result: Types.SellResultPayload = {
		count = soldCount,
		coinsEarned = total,
		newBalance = data.coins,
	}
	sellResultRemote:FireClient(player, result)
end

function EconomyService.init()
	sellResultRemote = Remotes.get(Remotes.Names.SellResult)
end

function EconomyService.start()
	Remotes.get(Remotes.Names.SellRequest).OnServerEvent:Connect(onSellRequest)
	PlayerDataService.onLoaded(function(player: Player)
		createLeaderstats(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSellTime[player] = nil
	end)
end

return EconomyService
