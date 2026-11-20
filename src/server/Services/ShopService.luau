--!strict
-- Forge : achat et équipement des pelles. Achat dans l'ordre, la pelle achetée s'équipe
-- automatiquement et reste possédée pour toujours.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Shovels = require(Shared.Config.Shovels)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Remotes = require(Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local WorldService = require(script.Parent.WorldService)
local ShovelVisualService = require(script.Parent.ShovelVisualService)

local IS_STUDIO = RunService:IsStudio()

local ShopService = {}

local lastBuyTime: { [Player]: number } = {}
local shovelChangedRemote: RemoteEvent

local function reject(player: Player, reason: string)
	if IS_STUDIO then
		print(string.format("[ShopService] Achat refusé (%s) : %s", player.Name, reason))
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

local function owns(data: Types.PlayerData, shovelId: string): boolean
	return table.find(data.ownedShovels, shovelId :: Types.ShovelId) ~= nil
end

-- Pelle équipée du joueur (pelle par défaut si le joueur n'est pas chargé ou si la donnée est inconnue).
function ShopService.getEquippedShovel(player: Player): Types.ShovelDef
	local data = PlayerDataService.getData(player)
	local shovel = if data ~= nil then Shovels.byId[data.equippedShovel] else nil
	return shovel or Shovels.byId[Shovels.DEFAULT_ID]
end

local function onBuyShovel(player: Player, shovelId: unknown)
	if typeof(shovelId) ~= "string" then
		reject(player, "identifiant invalide")
		return
	end
	local shovel = Shovels.byId[shovelId]
	if shovel == nil then
		reject(player, "pelle inconnue " .. shovelId)
		return
	end

	local data = PlayerDataService.getData(player)
	if data == nil then
		reject(player, "données non chargées")
		return
	end

	local position = getCharacterPosition(player)
	if position == nil or (position - WorldService.getForgePosition()).Magnitude > EconomyConfig.FORGE_MAX_DISTANCE then
		reject(player, "trop loin de la Forge")
		return
	end

	local now = os.clock()
	local last = lastBuyTime[player]
	if last ~= nil and now - last < EconomyConfig.BUY_COOLDOWN then
		reject(player, "cadence trop rapide")
		return
	end
	lastBuyTime[player] = now

	if owns(data, shovel.id) then
		reject(player, "déjà possédée " .. shovel.id)
		return
	end
	local previous = Shovels.getPrevious(shovel.id)
	if previous ~= nil and not owns(data, previous.id) then
		reject(player, "pelle précédente requise " .. previous.id)
		return
	end

	-- Dépense puis attribution, sans yield entre les deux.
	if not EconomyService.trySpend(player, shovel.price, "ShovelPurchase", shovel.id) then
		reject(player, string.format("Pièces insuffisantes (%d / %d)", data.coins, shovel.price))
		return
	end
	table.insert(data.ownedShovels, shovel.id)
	data.equippedShovel = shovel.id
	PlayerDataService.refreshAttributes(player)
	ShovelVisualService.refresh(player)
	shovelChangedRemote:FireClient(player, shovel.id)
	print(string.format("[ShopService] %s achète la %s (%d Pièces)", player.Name, shovel.name, shovel.price))
end

function ShopService.init()
	shovelChangedRemote = Remotes.get(Remotes.Names.ShovelChanged)
end

function ShopService.start()
	Remotes.get(Remotes.Names.BuyShovel).OnServerEvent:Connect(onBuyShovel)
	Players.PlayerRemoving:Connect(function(player)
		lastBuyTime[player] = nil
	end)
end

return ShopService
