--!strict
-- Pièces : lecture, gain, dépense, classement du serveur et analytique.
-- Toute variation de Pièces passe par addCoins ou trySpend.

local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)

local LEADERSTATS_NAME = "leaderstats" -- nom imposé par Roblox

local EconomyService = {}

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

function EconomyService.init() end

function EconomyService.start()
	PlayerDataService.onLoaded(function(player: Player)
		createLeaderstats(player)
	end)
end

return EconomyService
